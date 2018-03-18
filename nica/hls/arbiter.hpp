/* * Copyright (c) 2016-2017 Haggai Eran, Gabi Malka, Lior Zeno, Maroun Tork
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 *  * Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation and/or
 * other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#pragma once

struct arbiter_per_port_stats {
    arbiter_per_port_stats() :
        not_empty(),
        no_tokens(),
        cur_tokens()
    {}

    ap_uint<64> not_empty;
    ap_uint<64> no_tokens;
    int cur_tokens;
};

struct arbiter_tx_per_port_stats {
    arbiter_tx_per_port_stats() : words(), packets(), last_pkt_id(), last_user()
    {}

    ap_uint<64> words;
    ap_uint<64> packets;
    ap_uint<3> last_pkt_id;
    ap_uint<12> last_user;
};

template <unsigned num_ports>
struct arbiter_stats {
    arbiter_stats() : idle(), out_full() {}

    arbiter_per_port_stats port[num_ports];
    arbiter_tx_per_port_stats tx_port[num_ports];
    bool idle;
    ap_uint<64> out_full;
};

#define ARBITER_BUCKET_PERIOD 0x0
#define ARBITER_BUCKET_TOKENS 0x1
#define ARBITER_BUCKET_LOG_SATURATION 0x2
#define ARBITER_QUOTA 0x3
#define ARBITER_IDLE_TIMEOUT 0x4
#define ARBITER_PORT_STRIDE 0x10
