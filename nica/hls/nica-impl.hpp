//
// Copyright (c) 2016-2018 Haggai Eran, Gabi Malka, Lior Zeno, Maroun Tork
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

#include "arbiter-impl.hpp"
#include "custom_rx_ring-impl.hpp"

#define IKERNEL_DELAY 64

class header_to_metadata_and_private
{
public:
    void split_udp_hdr_stream(udp::header_stream& hdr_in, result_stream& ft_results,
                              hls_ik::metadata_stream& metadata_out,
                              mlx::metadata_stream& out_private);
};

class data_and_private_to_udp {
public:
    void join_ik_data_and_private(
        hls_ik::metadata_stream& metadata_in,
        mlx::metadata_stream& priv_stream, hls_ik::action_stream& action, hls_ik::metadata_stream& metadata_fifo,
        udp::udp_builder_metadata_stream& header_out, nica_ikernel_stats& ik_stats);

private:
    enum { ACTION, ACTION_PASS, ACTION_DROP, HEADER } state;
    mlx::metadata priv;
    hls_ik::action cur_action;
    nica_ikernel_stats stats;
    /* Current packet is from a GENERATE action. Mark it as such. */
    bool generated;
};

/** Necessary logic to duplicate around each ikernel.
 *
 * pipeline points to the member variable in the ports structs of the desired
 * pipeline (host or net). */
template <hls_ik::pipeline_ports hls_ik::ports::* pipeline>
class ikernel_wrapper {
public:
    ikernel_wrapper();

    void wrapper(hls_ik::ports& ik, udp::header_stream& header_udp_to_ikernel,
                 result_stream& ft_results,
                 hls_ik::data_stream& data_udp_to_ikernel,
                 mlx::stream& builder_to_arbiter,
                 mlx::stream& builder_generated_to_arbiter,
                 nica_ikernel_stats& ik_stats,
                 hls_ik::gateway_registers& custom_ring_gateway);

#if !defined(__SYNTHESIS__)
    void verify();
#endif

private:
    header_to_metadata_and_private hdr_to_meta;
    hls_helpers::duplicator<1, ap_uint<hls_ik::metadata::width> > metadata_dup;
    data_and_private_to_udp join_data_and_private_to_udp;
    custom_rx_ring custom_ring;
    udp::udp_builder builder;

    mlx::metadata_stream internal_private_stream, internal_ikernel_to_builder;
    hls_ik::metadata_stream metadata_split_to_dup, metadata_dup_to_join;
    udp::bool_stream generated_ikernel_to_builder;
    udp::udp_builder_metadata_stream hdr_ikernel_to_custom_ring,
                                hdr_custom_ring_to_builder;
    hls_ik::data_stream data_ikernel_to_custom_ring, data_custom_ring_to_builder;
};

/** The full NICA pipeline of a single direction (host to net or net to host).
 *
 * pipeline points to the member variable in the ports structs of the desired
 * pipeline (host or net). */
template <hls_ik::pipeline_ports hls_ik::ports::* pipeline>
class nica_state {
public:
    nica_state();

    void nica_step(mlx::stream& port2sbu, mlx::stream& sbu2port,
                   udp::config& config, nica_pipeline_stats& s,
                   trace_event events[4],
                   DECL_IKERNEL_PARAMS());

#if !defined(__SYNTHESIS__)
    void verify();
#endif

private:
    enum { IDLE, DATA, CONSUME } state;

    udp::udp udp;
#define BOOST_PP_LOCAL_MACRO(i) \
    ikernel_wrapper<pipeline> wrapper ## i; \
    udp::header_stream header_udp_to_ikernel ## i; \
    result_stream ft_results_to_ik ## i; \
    hls_ik::data_stream data_udp_to_ikernel ## i; \
    mlx::stream builder_to_arbiter ## i, \
        builder_generated_to_arbiter ## i;
#define BOOST_PP_LOCAL_LIMITS (0, NUM_IKERNELS - 1)
%:include BOOST_PP_LOCAL_ITERATE()
    arbiter<2 * NUM_IKERNELS + 1, mlx::axi4s> arb;
    udp::ethernet_padding ethernet_pad;

    hls_helpers::duplicator<1, mlx::axi4s> raw_dup;
    mlx::dropper dropper;
    mlx::stream raw_in_to_udp, raw_in_to_dropper, dropper_to_arbiter,
        raw_arbiter_to_pad;
    udp::bool_stream bool_pass_raw, over_threshold,
           bool_pass_from_steering;
};

#if !defined(__SYNTHESIS__)
extern nica_state<&hls_ik::ports::net> n2h;
extern nica_state<&hls_ik::ports::host> h2n;
#endif
