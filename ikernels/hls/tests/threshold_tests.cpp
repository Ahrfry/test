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
#include "threshold.hpp"
#include "threshold-impl.hpp"
#include <vector>
#include <ctime> 
#include <ap_int.h>
#include <limits.h>


using namespace std;
using namespace hls_ik;

namespace {

    class threshold_test : public ikernel_test
    {
    };

    INSTANTIATE_TEST_CASE_P(ikernel_test_instance, all_ikernels_test,
            ::testing::Values(&threshold_top));

    //Test threshold register
    TEST_P(threshold_test, ThresholdValueReadWrite) {
        const int value = 0x5a5aff11;
        write(THRESHOLD_VALUE, value);
        int read_value = read(THRESHOLD_VALUE);
        EXPECT_EQ(value, read_value) << "threshold";
        EXPECT_EQ(0, read(THRESHOLD_DROPPED)) << "dropped packets";
        EXPECT_EQ(0, read(THRESHOLD_COUNT)) << "count";
        EXPECT_EQ(0, read(THRESHOLD_SUM_LO)) << "sum (low)";
        EXPECT_EQ(0, read(THRESHOLD_SUM_HI)) << "sum (high)";
        EXPECT_EQ(-1U, read(THRESHOLD_MIN)) << "min";
        EXPECT_EQ(0, read(THRESHOLD_MAX)) << "max";

    } 



    TEST_P(threshold_test, _100RandomPackets){
        metadata m;
        packet_metadata pkt = m.get_packet_metadata();
        pkt.eth_dst = 1;
        pkt.eth_src = 2;
        pkt.ip_dst = 3;
        pkt.ip_src = 4;
        pkt.udp_dst = 5;
        pkt.udp_src = 6;
        m.set_packet_metadata(pkt);
        m.length = 32;
        
        //srand(time(NULL));
        ap_uint<32> threshold_val = rand();//%101;
        write(THRESHOLD_VALUE, threshold_val);
	
        std::vector<action> vec;
        ap_uint<64> sum = 0;
        ap_uint<32> min_val = INT_MAX, max_val = 0;
        ap_uint<32> dropped_packets_num = 0;

        const int total = 100;

        for (int i = 0; i < total; ++i) {
            p.net.metadata_input.write(m);
    	    ap_uint<32> rand_val = rand();//(rand()%100);
            sum += rand_val;
            min_val = rand_val < min_val ? rand_val : min_val;
            max_val = rand_val > max_val ? rand_val : max_val;	  
            dropped_packets_num += rand_val < threshold_val ? 1 : 0;
            vec.push_back(rand_val < threshold_val ? DROP : PASS);		
            //   cout << "[" << i << "] : " << rand_val << "\n";	
            ap_uint<256> data = (ap_uint<14*8>(0),ap_uint<32>(rand_val), ap_uint<256 - 32 - 14*8>(0));
            axi_data d(data, 0xffffffff, true);
            p.net.data_input.write(d);
        }

        while (!p.net.data_input.empty())
            top();
        // Extra cycles to allow the RTL/C simulation to complete
        for (int i = 0; i < 64; ++i)
            top();

        for (int i = 0; i < total; ++i) {
            action a = action(int(p.net.action.read()));
            EXPECT_EQ(vec[i], a) << "action (i = " << i << ")";
            if (a == PASS) {
                p.net.metadata_output.read();
                p.net.data_output.read();
            }
        }

        cout << "threshold value is " << threshold_val << endl;
        cout << dropped_packets_num << "/100 packets were dropped." <<  endl;
        
        EXPECT_EQ(dropped_packets_num, read(THRESHOLD_DROPPED)) << "dropped packets";
        EXPECT_EQ(total, read(THRESHOLD_COUNT)) << "count";
        EXPECT_EQ((int)sum(31,0), read(THRESHOLD_SUM_LO)) << "sum (low)";
        EXPECT_EQ((int)sum(63,32), read(THRESHOLD_SUM_HI)) << "sum (high)";
        EXPECT_EQ(min_val, read(THRESHOLD_MIN)) << "min";
        EXPECT_EQ(max_val, read(THRESHOLD_MAX)) << "max";
    }

    TEST_P(threshold_test, custom_ring) {
        metadata m;
        packet_metadata pkt;
        pkt.eth_dst = 1;
        pkt.eth_src = 2;
        pkt.ip_dst = 3;
        pkt.ip_src = 4;
        pkt.udp_dst = 5;
        pkt.udp_src = 6;
        m.set_packet_metadata(pkt);
        m.length = 32;
        m.ikernel_id = 1;
        m.flow_id = 2;
        
        //srand(time(NULL));
        ap_uint<32> threshold_val = rand();//%101;
        write(THRESHOLD_VALUE, threshold_val);
        write(THRESHOLD_RING_ID + 2, 1);
        int dropped_packets_start = read(THRESHOLD_DROPPED);
        int count_start = read(THRESHOLD_COUNT);
	
        std::vector<action> vec;
        ap_uint<64> sum = 0;
        ap_uint<32> min_val = INT_MAX, max_val = 0;
        ap_uint<32> dropped_packets_num = 0;

        const int total = 100;
        update_credits(1, total);

        for (int i = 0; i < total; ++i) {
            p.net.metadata_input.write(m);
    	    ap_uint<32> rand_val = rand();//(rand()%100);
            sum += rand_val;
            min_val = rand_val < min_val ? rand_val : min_val;
            max_val = rand_val > max_val ? rand_val : max_val;	  
            dropped_packets_num += rand_val < threshold_val ? 1 : 0;
            vec.push_back(rand_val < threshold_val ? DROP : PASS);		
            //   cout << "[" << i << "] : " << rand_val << "\n";	
            ap_uint<256> data = (ap_uint<14*8>(0),ap_uint<32>(rand_val), ap_uint<256 - 32 - 14*8>(0));
            axi_data d(data, 0xffffffff, true);
            p.net.data_input.write(d);
        }

        while (!p.net.data_input.empty())
            top();
        // Extra cycles to allow the RTL/C simulation to complete
        for (int i = 0; i < 64; ++i)
            top();

        for (int i = 0; i < total; ++i) {
            action a = action(int(p.net.action.read()));
            EXPECT_EQ(vec[i], a) << "action (i = " << i << ")";
            if (a == PASS) {
                m = p.net.metadata_output.read();
                EXPECT_EQ(m.ring_id, 1);
                EXPECT_EQ(m.get_custom_ring_metadata().end_of_message, true);
                EXPECT_EQ(m.ikernel_id, 1);
                EXPECT_EQ(m.flow_id, 2);
                p.net.data_output.read();
            }
        }

        cout << "threshold value is " << threshold_val << endl;
        cout << dropped_packets_num << "/100 packets were dropped." <<  endl;
        
        EXPECT_EQ(dropped_packets_num, read(THRESHOLD_DROPPED) - dropped_packets_start) << "dropped packets";
        EXPECT_EQ(total, read(THRESHOLD_COUNT) - count_start) << "count";
    }

    INSTANTIATE_TEST_CASE_P(threshold_test_instance, threshold_test,
            ::testing::Values(&threshold_top));

} // namespace

int main(int argc, char **argv) {
  testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}


