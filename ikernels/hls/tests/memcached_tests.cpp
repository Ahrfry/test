/* Copyright (C) 2017 Haggai Eran

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>. */

#include "ikernel_tests.hpp"
#include "memcached-ik.hpp"
#include "tb.h"

using namespace hls_ik;

namespace {

    class memcached_test : public ikernel_test, public udp_tb::testbench {
    protected:
        nica_config c;
        nica_stats s;

        void top()
        {
            ::nica(nwp2sbu, sbu2nwp, cxp2sbu, sbu2cxp,
                   &c, &s, events,
                   BOOST_PP_ENUM_PARAMS(NUM_IKERNELS, ports));
            memcached_top(p, id, gateway);
        }
    };

    TEST_P(memcached_test, pcap) {
        FILE* nwp_output = tmpfile();
        ASSERT_TRUE(nwp_output) << "cannot create temporary file for output.";
        FILE* cxp_output = tmpfile();
        ASSERT_TRUE(cxp_output) << "cannot create temporary file for output.";

        memset(&c, 0, sizeof(c));
        gateway_wrapper n2h_ft_gateway([&]() { top(); }, c.n2h.flow_table_gateway);
        gateway_wrapper h2n_ft_gateway([&]() { top(); }, c.h2n.flow_table_gateway);
        n2h_ft_gateway.write(FT_FLOWS_BASE + FT_RESULT_ACTION, FT_IKERNEL);
        h2n_ft_gateway.write(FT_FLOWS_BASE + FT_RESULT_ACTION, FT_IKERNEL);
        c.n2h.enable = true;
        c.h2n.enable = true;

        if (MEMCACHED_KEY_SIZE == 10 && MEMCACHED_VALUE_SIZE == 10)
            ASSERT_GE(read_pcap("memcached-responses.pcap", cxp2sbu), 0);
        run();
        if (MEMCACHED_KEY_SIZE == 10 && MEMCACHED_VALUE_SIZE == 10)
            ASSERT_GE(read_pcap("memcached-requests.pcap", nwp2sbu), 0);
        run();

        write_pcap(nwp_output, sbu2nwp, false);
        write_pcap(cxp_output, sbu2cxp, false);

        if (MEMCACHED_KEY_SIZE == 10 && MEMCACHED_VALUE_SIZE == 10)
            EXPECT_TRUE(compare_output(filename(nwp_output), "",
                                       "memcached-all-responses.pcap", ""));
        // cxp_output should be empty
        if (MEMCACHED_KEY_SIZE == 10 && MEMCACHED_VALUE_SIZE == 10)
            EXPECT_TRUE(compare_output(filename(cxp_output), "",
                                       "memcached-requests.pcap", "sctp"));
    }

    INSTANTIATE_TEST_CASE_P(memcached_test_instance, memcached_test,
            ::testing::Values(&memcached_top));

} // namespace

int main(int argc, char **argv) {
  testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
