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

#include "pktgen.hpp"
#include "hls_helper.h"

using namespace hls_helpers;
using namespace hls_ik;

pktgen::pktgen() :
    metadata()
{}

void pktgen::step(hls_ik::ports& p)
{
#pragma HLS inline
    pktgen_pipeline(p.host);
    pass_packets(p.net);
}

void pktgen::pktgen_pipeline(hls_ik::pipeline_ports& p)
{
#pragma HLS pipeline enable_flush ii=1
    if (!burst_sizes.empty())
        burst_size = burst_sizes.read();

    switch (state) {
    case IDLE:
        if (p.metadata_input.empty())
            break;

        metadata = p.metadata_input.read();
        p.action.write(PASS);
        p.metadata_output.write(metadata);

        state = INPUT_PACKET;
        data_offset = 0;
        goto input_packet;

    case INPUT_PACKET: {
input_packet:
        if (p.data_input.empty())
            break;

        hls_ik::axi_data d = p.data_input.read();
        /* TODO handle packet too large */
        data[data_offset++] = d;
        p.data_output.write(d);

        if (d.last) {
            state = burst_size ? DUPLICATE : IDLE;
            data_length = data_offset;
            data_offset = 0;
            cur_packet = burst_size;
            if (!cur_packet_to_gateway.full())
                cur_packet_to_gateway.write(cur_packet);
        }
        break;
    }
    case DUPLICATE:
        if (data_offset == 0) {
            p.action.write(GENERATE);
            hls_ik::metadata m(metadata);
            m.ip_identification = cur_packet;
            p.metadata_output.write(m);
        }

        p.data_output.write(data[data_offset]);
        if (++data_offset >= data_length) {
            if (--cur_packet == 0) {
                state = IDLE;
            } else {
                data_offset = 0;
            }
            if (!cur_packet_to_gateway.full())
                cur_packet_to_gateway.write(cur_packet);
        }
        break;
    }
}

int pktgen::reg_write(int address, int value)
{
    switch (address) {
    case PKTGEN_BURST_SIZE:
        burst_size_cache = value;
        burst_sizes.write(value);
        break;
    default:
        return -1;
    }
    return 0;
}

int pktgen::reg_read(int address, int* value)
{
    switch (address) {
    case PKTGEN_BURST_SIZE:
        *value = burst_size_cache;
        break;
    case PKTGEN_CUR_PACKET:
        *value = cur_packet_cache;
        break;
    default:
        *value = -1;
        return -1;
    }
    return 0;
}

void pktgen::gateway_update()
{
    if (!cur_packet_to_gateway.empty())
        cur_packet_cache = cur_packet_to_gateway.read();
}

DEFINE_TOP_FUNCTION(pktgen_top, pktgen, PKTGEN_UUID)
