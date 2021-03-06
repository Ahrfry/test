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

#include <ikernel.hpp>
#include <mlx.h>

/** Adds a suffix onto an existing stream */
template <unsigned suffix_length_bits>
class push_suffix
{
public:
    typedef ap_uint<suffix_length_bits> suffix_t;

    push_suffix() : state(IDLE) {}

    void reorder(hls_ik::data_stream& data_in, 
                 hls::stream<bool>& empty_packet,
		 hls::stream<bool>& enable_stream,
                 hls::stream<suffix_t>& suffix_in, hls_ik::data_stream& out)
    {
#pragma HLS pipeline enable_flush
        static_assert(suffix_length_bits < 256, "suffix size too large - not implemented");

        switch (state)
        {
        case IDLE: {
            if (empty_packet.empty() || enable_stream.empty() || suffix_in.empty())
                break;

            bool empty = empty_packet.read();
	    enable = enable_stream.read();
            suffix = suffix_in.read();

            if (!enable && empty) {
                // Nothing to do
                break;
            } else if (enable && empty) {
                last_flit_bytes = suffix_length_bits / 8;
                state = LAST;
                goto last;
            } else {
                // We have data
                state = DATA;
            }
            /* Fall through */
        }
        case DATA: {
            if (data_in.empty() || out.full())
                break;

            hls_ik::axi_data flit = data_in.read();
            if (!flit.last || !enable) {
                out.write(flit);
                state = flit.last ? IDLE : DATA;
                break;
            }

            if (!enable) {
                state = IDLE;
                break;
            }

            /* Check if the amount of remaining space in the last flit of the
             * data stream has enough room for the suffix */
	    int b;
            for (b = 0; b < 32; ++b) {
                if (!flit.keep(31 - b, 31 - b))
		    break;
	    }

	    /* Number of bits that fit in the current flit */
	    const int cur_flit_suffix = std::min((32u - b) * 8, suffix_length_bits);
	    const int shift = (32 - b) * 8 - cur_flit_suffix;
	    const ap_uint<256> mask = ((ap_uint<256>(1) << cur_flit_suffix) - 1) << shift;
	    const ap_uint<32> keep_mask = ((1u << cur_flit_suffix / 8) - 1) << (shift / 8);

	    ap_uint<256> suffix_shifted;

	    if (cur_flit_suffix >= suffix_length_bits) {
		suffix_shifted = ap_uint<256>(suffix) << shift;
		state = IDLE;
	    } else {
		suffix_shifted = ap_uint<256>(suffix) >> (suffix_length_bits - cur_flit_suffix);
		last_flit_bytes = (suffix_length_bits - cur_flit_suffix) / 8;
		flit.last = false;
		state = LAST;
	    }
	    flit.data &= ~mask;
	    flit.data |= suffix_shifted;
	    flit.keep |= keep_mask;
            out.write(flit);
            break;
        }
        case LAST: {
last:
            ap_uint<256> data = ap_uint<256>(suffix) << (256 - last_flit_bytes * 8);
            hls_ik::axi_data out_buf(data,
                hls_ik::axi_data::keep_bytes(last_flit_bytes), true);
            out.write(out_buf);
            state = IDLE;
	    break;
        }
	}
    }

protected:
    /** Reordering state:
     *  IDLE   waiting for header stream entry.
     *  DATA   reading and transmitting the data stream.
     *  LAST   output the suffix if it did not fit in the last data flit.
     */
    enum { IDLE, DATA, LAST } state;
    bool enable;
    suffix_t suffix;
    ap_uint<6> last_flit_bytes;
};

