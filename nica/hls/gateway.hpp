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

#include "hls_macros.hpp"

#define GATEWAY_OFFSET(gateway, offset_cmd, offset_data, offset_done) \
    DO_PRAGMA_SYN(HLS interface s_axilite port=gateway.cmd offset=offset_cmd) \
    DO_PRAGMA_SYN(HLS interface s_axilite port=gateway.data offset=offset_data) \
    DO_PRAGMA_SYN(HLS interface s_axilite port=gateway.done offset=offset_done) \

#define GW_FAIL (-1)
#define GW_DONE 0
#define GW_BUSY 1

namespace hls_ik {
    struct gateway_registers {
        gateway_registers() : cmd({0, 0, 0}), data(0), done(0) {}

        struct {
            ap_uint<30> addr;
            ap_uint<1>  write; // Bit 30
            ap_uint<1>  go; // Bit 31
        } cmd;

        int data;

        ap_uint<1>  done;
    };

    template <typename derived>
    class gateway_impl {
    public:
        static void gateway(derived* instance, hls_ik::gateway_registers& r) {
#pragma HLS pipeline enable_flush ii=1
        _PragmaSyn("HLS data_pack variable=r.cmd")
            if (r.cmd.go && !instance->axilite_gateway_done) {
                int res;
                if (r.cmd.write) {
                    res = instance->reg_write(r.cmd.addr, r.data);
                } else {
                    res = instance->reg_read(r.cmd.addr, &r.data);
                }
                if (res != GW_BUSY) {
                    instance->axilite_gateway_done = true;
                    r.done = 1;
                }
            } else if (!r.cmd.go && instance->axilite_gateway_done) {
                instance->axilite_gateway_done = false;
                r.done = 0;
            }
            instance->gateway_update();
        }

    protected:
        bool axilite_gateway_done;
    };
}
