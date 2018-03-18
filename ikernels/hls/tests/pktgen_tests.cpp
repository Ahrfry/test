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

#include "ikernel_tests.hpp"
#include "pktgen.hpp"

using namespace hls_ik;

namespace {

    class pktgen_test : public ikernel_test
    {
    };

    INSTANTIATE_TEST_CASE_P(ikernel_test_instance, all_ikernels_test,
            ::testing::Values(&pktgen_top));

    // Test pktgen burst size register
    TEST_P(pktgen_test, BurstSizeValueReadWrite) {
        const int value = 0x5a5aff11;
        write(PKTGEN_BURST_SIZE, value);
        int read_value = read(PKTGEN_BURST_SIZE);
        EXPECT_EQ(value, read_value) << "pktgen burst size";
    }

    // Test pktgen
    TEST_P(pktgen_test, PktgenCountPackets) {
        metadata m = metadata();
        axi_data d;

        packet_metadata pkt = m.get_packet_metadata();
        pkt.eth_dst = 1;
        pkt.eth_src = 2;
        pkt.ip_dst = 3;
        pkt.ip_src = 4;
        pkt.udp_dst = 5;
        pkt.udp_src = 6;
        m.set_packet_metadata(pkt);
        m.ip_identification = 0x8000;
        m.length = 32;
        m.flow_id = 1;
        m.ikernel_id = 2;
        p.host.metadata_input.write(m);

        write(PKTGEN_BURST_SIZE, 2);
        int read_value = read(PKTGEN_BURST_SIZE);
        EXPECT_EQ(2, read_value) << "pktgen burst size";

        for (int i = 0; i < 2; ++i) {
            ap_uint<256> data = (ap_uint<32>(i), ap_uint<256 - 32>(0));
            d = axi_data(data, 0xffffffff, 1);
            d.last = (i == 1);
            p.host.data_input.write(d);
        }

        for (int j = 0; j < 64; ++j)
            top();

        for (int i = 0; i < 3; ++i) {
            action a = action(int(p.host.action.read()));
            EXPECT_EQ(i == 0 ? PASS : GENERATE, a) << "action (i = " << i << ")";
            hls_ik::metadata read_metadata = p.host.metadata_output.read();
            m.ip_identification = i == 0 ? 0x8000 : 3 - i;
            EXPECT_EQ(read_metadata, m);
            
            do {
                ASSERT_FALSE(p.host.data_output.empty());
                d = p.host.data_output.read();
            } while (!d.last);
        }
    }

    INSTANTIATE_TEST_CASE_P(pktgen_test_instance, pktgen_test,
            ::testing::Values(&pktgen_top));

} // namespace

int main(int argc, char **argv) {
  testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}


