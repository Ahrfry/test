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

#include "echo-impl.hpp"
#include "hls_helper.h"

using namespace hls_helpers;

void echo_one_direction::echo_pipeline(hls_ik::pipeline_ports& in, hls_ik::pipeline_ports& out) {
#pragma HLS inline off
#pragma HLS pipeline enable_flush ii=1
    if (!respond_to_sockperf_update.empty())
        respond_to_sockperf = respond_to_sockperf_update.read();

    switch (state) {
        case METADATA:
            if (!in.metadata_input.empty()) {
                metadata = in.metadata_input.read();

                in.action.write(hls_ik::DROP);

                state = DATA;
                first = true;
            }
            break;

        case DATA: {
            if (in.data_input.empty())
                return;

            hls_ik::axi_data d = in.data_input.read();
            if (first) {
                first = false;

                if (respond_to_sockperf) {
                    short flags = d.data(255 - 8 * 8, 256 - 10 * 8);
                    bool pong_request = flags & 2;
                    // Turn off client bit on the response packet
                    flags &= ~1;
                    d.data(255 - 8 * 8, 256 - 10 * 8) = flags;

                    respond = pong_request;
                } else {
                    respond = true;
                }

                if (respond) {
                    out.action.write(hls_ik::GENERATE);
                    out.metadata_output.write(metadata.reply(metadata.length));
                }
            }

            if (respond)
                out.data_output.write(d);
            state = d.last ? METADATA : DATA;
            break;
        }
    }
}

void echo::step(hls_ik::ports& p) {
#pragma HLS dataflow
    net.echo_pipeline(p.net, p.host);

    // TODO: passthrough or drop the host traffic; merge with action stream
    // from the echo_pipeline.
    consume(p.host.metadata_input);
    consume(p.host.data_input);
    produce(p.net.metadata_output);
    produce(p.net.data_output);
}

int echo::reg_write(int address, int value)
{
    if (address == ECHO_RESPOND_TO_SOCKPERF) {
        if (net.respond_to_sockperf_update.full())
            return GW_BUSY;
	net.respond_to_sockperf_cache = value;
        net.respond_to_sockperf_update.write(value);
	return 0;
    }

    return -1;
}


int echo::reg_read(int address, int* value)
{
    if (address == ECHO_RESPOND_TO_SOCKPERF) {
	*value = net.respond_to_sockperf_cache;
	return 0;
    }

    *value = -1;
    return -1;
}


DEFINE_TOP_FUNCTION(echo_top, echo, ECHO_UUID)
