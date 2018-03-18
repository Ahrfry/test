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

#include <udp.h>
#include <mlx.h>

#include "arbiter-impl.hpp"

void arbiter_top(mlx::stream& out, mlx::stream& port0, mlx::stream& port1, mlx::stream port2,
                 arbiter_stats<3>* stats, hls_ik::gateway_registers& arbiter_gateway,
                 trace_event events[NUM_TRACE_EVENTS])
{
#pragma HLS INTERFACE axis port=out
#pragma HLS INTERFACE axis port=port0
#pragma HLS INTERFACE axis port=port1
#pragma HLS INTERFACE axis port=port2
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE s_axilite port=stats
    GATEWAY_OFFSET(arbiter_gateway, 0x58, 0x60, 0x70)
#pragma HLS array_partition variable=events complete
#pragma HLS interface ap_none port=events
#pragma HLS dataflow

    static arbiter<3, mlx::axi4s> arb;

    arb.arbiter_step(
        out,
        stats,
        arbiter_gateway, events,
        port0, port1, port2
    );
}
