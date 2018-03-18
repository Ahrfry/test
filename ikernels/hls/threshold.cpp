//
// Copyright (c) 2016-2017 Haggai Eran, Gabi Malka, Lior Zeno, Maroun Tork
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS''
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
// ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#include "threshold.hpp"
#include "threshold-impl.hpp"
#include "hls_helper.h"

#include <algorithm>
using std::min;
using std::max;

using namespace hls_ik;

ring_id_t flow_to_ring::find_ring(const flow_id_t& flow_id)
{
    return (*this)[flow_id];
}

int flow_to_ring::write(int address, int value)
{
    if (address > FLOW_TABLE_SIZE || address < 0)
        return GW_FAIL;

    gateway_context = value;
    if (!gateway_set(address))
        return GW_BUSY;

    return GW_DONE;
}

int flow_to_ring::read(int address, int *value)
{
    if (address > FLOW_TABLE_SIZE || address < 0) {
        *value = 0xffffffff;
        return GW_FAIL;
    }
        
    if (!gateway_query(address))
        return GW_BUSY;

    *value = gateway_context;
    return GW_DONE;
}

void threshold::net_ingress(hls_ik::pipeline_ports& p, credit_update_registers& host_credit_regs)
{
#pragma HLS pipeline enable_flush ii=1
    axi_data d;

    update(host_credit_regs);
    if (!threshold_values.empty())
        threshold_value = threshold_values.read();
    ring_map.update();

    switch (state) {
    case METADATA:
        if (p.metadata_input.empty())
            return;

        meta = p.metadata_input.read();
        ring_id = ring_map.find_ring(meta.flow_id);
        state = DATA;
        break;

    case DATA: {
        if (p.data_input.empty() || values_to_stats.full())
            return;

        d = p.data_input.read();
        value v = d.data(255-14*8, 256 - value::width-14*8);
        const bool backpressure = !can_transmit(meta.ikernel_id, ring_id, 4, HOST);
//        std::cout << "value: " << d.data(255-14*8, 256 - value::width-14*8) << "\n";
        values_to_stats.write(std::make_tuple(v, backpressure));

        drop = v < threshold_value || backpressure;
        if (!drop) {
            if (ring_id != 0) {
                new_message(ring_id, HOST);
                meta.ring_id = ring_id;
                custom_ring_metadata cr;
                cr.end_of_message = 1;
                meta.var = cr;
                meta.length = 4;
                meta.verify();
                d.data(255, 256 - value::width) = v;
                d.keep = 0xf0000000;
                d.last = 1;
            }
            p.metadata_output.write(meta);
            p.data_output.write(d);
        }

        p.action.write(drop ? DROP : PASS);
        state = d.last ? METADATA : REST;
        break;
    }
    case REST:
        if (p.data_input.empty())
            return;

        d = p.data_input.read();
        if (!drop && ring_id == 0)
	     p.data_output.write(d);
        state = d.last ? METADATA : REST;
        break;
    }
}

void threshold::gateway_update()
{
#pragma HLS inline
    if (values_to_stats.empty())
        return;

    value v;
    bool backpressure;
    std::tie(v, backpressure) = values_to_stats.read();

    stats.min = std::min(stats.min, v);
    stats.max = std::max(stats.max, v);
    stats.sum += v;
    ++stats.count;
    bool drop = v < threshold_cache || backpressure;
    if (drop)
        ++stats.dropped;
    if (backpressure) {
        ++stats.dropped_backpressure;
    }
}

void threshold::step(hls_ik::ports& p)
{
#pragma HLS inline
    pass_packets(p.host);
    net_ingress(p.net, p.host_credit_regs);
}

int threshold::reg_write(int address, int value)
{
#pragma HLS inline
    if (address >= THRESHOLD_RING_ID && address < THRESHOLD_RING_ID + FLOW_TABLE_SIZE)
        return ring_map.write(address - THRESHOLD_RING_ID, value);

    switch (address) {
    case THRESHOLD_VALUE:
        threshold_values.write(value);
        threshold_cache = value;
        break;
    default:
        return -1;
    }
    return 0;
}

int threshold::reg_read(int address, int* value)
{
#pragma HLS inline
    if (address >= THRESHOLD_RING_ID && address < THRESHOLD_RING_ID + FLOW_TABLE_SIZE)
        return ring_map.read(address - THRESHOLD_RING_ID, value);

/* Ignore dependency since these are statistics and we don't really care if they
 * are exactly up-to-date. */
    switch (address) {
    case THRESHOLD_MIN:
        *value = stats.min;
        break;
    case THRESHOLD_MAX:
        *value = stats.max;
        break;
    case THRESHOLD_COUNT:
        *value = stats.count;
        break;
    case THRESHOLD_SUM_LO:
        *value = stats.sum(31, 0);
        break;
    case THRESHOLD_SUM_HI:
        *value = stats.sum(63, 32);
        break;
    case THRESHOLD_VALUE:
        *value = threshold_cache;
        break;
    case THRESHOLD_DROPPED:
        *value = stats.dropped;
        break;
    case THRESHOLD_DROPPED_BACKPRESSURE:
        *value = stats.dropped_backpressure;
        break;
    default:
        *value = -1;
        return -1;
    }
    return 0;
}

DEFINE_TOP_FUNCTION(threshold_top, threshold, THRESHOLD_UUID)
