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

#include "echo.hpp"

// 6d1efc9b-8655-42d7-8000-9e3e998dbd5c
#include <ikernel.hpp>
#include <gateway.hpp>

class echo_one_direction {
public:
    void echo_pipeline(hls_ik::pipeline_ports& in, hls_ik::pipeline_ports& out);

    /* By default, respond to all packets. When true, respond to sockperf
     * packets with "pong" requests. */
    bool respond_to_sockperf;
    /* A register with the gateway exposed value. */
    bool respond_to_sockperf_cache;
    /* Updates from the gateway */
    hls::stream<bool> respond_to_sockperf_update;
private:
    enum { METADATA, DATA } state;
    /* First data word */
    bool first;
    /* Respond to the current packet */
    bool respond;
    /* Metadata of the current packet */
    hls_ik::metadata metadata;
};

class echo : public hls_ik::ikernel, public hls_ik::gateway_impl<echo> {
public:
    virtual void step(hls_ik::ports& p);

    virtual int reg_write(int address, int value);
    virtual int reg_read(int address, int* value);

private:
    echo_one_direction net;
};

DECLARE_TOP_FUNCTION(echo_top);
