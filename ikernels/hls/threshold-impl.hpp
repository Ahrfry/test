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

#pragma once

#include <ikernel.hpp>
#include <gateway.hpp>
#include <flow_table.hpp>
#include <context_manager.hpp>

#include <tuple>

DECLARE_TOP_FUNCTION(threshold_top);

typedef ap_uint<32> value;

struct threshold_stats {
    value min, max, count, dropped, dropped_backpressure;
    ap_uint<64> sum;

    threshold_stats() : min(-1U), max(0), count(0), dropped(0), sum(0) {}
};

class flow_to_ring : public context_manager<hls_ik::ring_id_t, 3>
{
public:
    int write(int address, int value);
    int read(int address, int *value);

    hls_ik::ring_id_t find_ring(const hls_ik::flow_id_t& flow_id);
};

class threshold : public hls_ik::ikernel, public hls_ik::gateway_impl<threshold> {
public:
    virtual void step(hls_ik::ports& ports);
    virtual int reg_write(int address, int value);
    virtual int reg_read(int address, int* value);
    void gateway_update();

protected:
    threshold_stats stats;
    /** Used by net_ingress to determine whether packets should be passed or
     * dropped */
    value threshold_value;
    /** Pass threshold value from gateway to net_ingress. HLS would have
     * generated a stream anyway, and making it explicit allows us to configure its
     * depth and control its consumption. */
    hls::stream<value> threshold_values;
    /** Used only by reg_read/reg_write to be able to return the same value.
     * This cannot be the same as threshold_value, since that breaks the dataflow
     * optimization. */
    value threshold_cache;
    flow_to_ring ring_map;
    hls_ik::ring_id_t ring_id;
    hls_ik::metadata meta;
    bool drop;
    enum { METADATA, DATA, REST } state;

    void net_ingress(hls_ik::pipeline_ports& p, hls_ik::credit_update_registers& host_credit_regs);

    hls::stream<std::tuple<value, bool> > values_to_stats;
};
