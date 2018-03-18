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

#ifndef IKERNEL_TESTS_HPP
#define IKERNEL_TESTS_HPP

#include "ikernel.hpp"
#include "gtest/gtest.h"
#include <functional>
#include "nica-top.hpp"

typedef void (* top_function)(hls_ik::ports &, hls_ik::ikernel_id &, hls_ik::gateway_registers&);

class gateway_wrapper {
public:
    gateway_wrapper(std::function<void(void)> top, hls_ik::gateway_registers& gateway) :
        top(top), gateway(gateway) {}

    int read(int address) {
        gateway.cmd.addr = address;
        gateway.cmd.write = 0;
        gateway.cmd.go = 1;
        gateway.done = 0;

        while (!gateway.done) {
            top();
        }

        int result = gateway.data;

        gateway.cmd.go = 0;
        top();

        return result;
    }

    void write(int address, int data) {
        gateway.cmd.addr = address;
        gateway.data = data;
        gateway.cmd.write = 1;
        gateway.cmd.go = 1;
        gateway.done = 0;

        while (!gateway.done) {
            top();
        }

        gateway.cmd.go = 0;
        top();
    }
protected:
    std::function<void(void)> top;
    hls_ik::gateway_registers& gateway;
};

class ikernel_test :
    public ::testing::TestWithParam<top_function> {
protected:
#define BOOST_PP_LOCAL_MACRO(n) \
    hls_ik::ports ports ## n;
#define BOOST_PP_LOCAL_LIMITS (0, NUM_IKERNELS - 1)
%:include BOOST_PP_LOCAL_ITERATE()
    hls_ik::ports& p;
    hls_ik::ikernel_id id;
    hls_ik::gateway_registers gateway;
    int top_call_count;

    void top() {
        GetParam()(p, id, gateway);
        ++top_call_count;
    }

    ikernel_test() : p(ports0), top_call_count() {}

    virtual ~ikernel_test() {
    }

    virtual void SetUp() {
    }

    virtual void TearDown() {
    }

    int read(int address) {
        return gateway_wrapper([&] () { top(); }, gateway).read(address);
    }

    void write(int address, int data) {
        gateway_wrapper([&] () { top(); }, gateway).write(address, data);
    }

    void update_credits(hls_ik::ring_id_t ring_id, hls_ik::msn_t max_msn)
    {
        p.host_credit_regs.ring_id = ring_id;
        p.host_credit_regs.max_msn = max_msn;
    }

    void test_passthrough(hls_ik::pipeline_ports& in, hls_ik::pipeline_ports& out,
                          hls_ik::metadata& m, hls_ik::axi_data& d) {
        hls_ik::packet_metadata pkt = m.get_packet_metadata();
        pkt.eth_dst = 1;
        pkt.eth_src = 2;
        pkt.ip_dst = 3;
        pkt.ip_src = 4;
        pkt.udp_dst = 5;
        pkt.udp_src = 6;
        m.set_packet_metadata(pkt);
        m.length = 32;
        in.metadata_input.write(m);

        d = hls_ik::axi_data(1, 0xffffffff, true);
        in.data_input.write(d);

        for (int i = 0; i < 10; ++i)
            top();
    }
};

class all_ikernels_test : public ikernel_test
{
};

// Test that host to net passthrough works
TEST_P(all_ikernels_test, test_passthrough) {
    hls_ik::metadata m;
    hls_ik::axi_data d;

    test_passthrough(p.host, p.host, m, d);

    EXPECT_EQ(p.host.action.empty(), false);
    EXPECT_EQ(p.host.action.read(), hls_ik::PASS);

    hls_ik::metadata metadata_output = p.host.metadata_output.read();
    hls_ik::axi_data data_output = p.host.data_output.read();

    EXPECT_EQ(d, data_output);
    EXPECT_EQ(m, metadata_output);

    EXPECT_EQ(p.host.action.empty(), true);
    EXPECT_EQ(p.host.metadata_output.empty(), true);
    EXPECT_EQ(p.host.data_output.empty(), true);
}

#endif
