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

#ifndef PKTGEN_HPP
#define PKTGEN_HPP

// 2f8e8996-1b5e-4c02-908c-0f2878b0d4e4
#define PKTGEN_UUID { 0x2f, 0x8e, 0x89, 0x96, 0x1b, 0x5e, 0x4c, 0x02, 0x90, 0x8c, 0x0f, 0x28, 0x78, 0xb0, 0xd4, 0xe4 }

/* Number of packets to send on each burst */
#define PKTGEN_BURST_SIZE 0x10
/* Current packet (R/O) (goes down from burst size to zero) */
#define PKTGEN_CUR_PACKET 0x11

#include <ikernel.hpp>
#include <gateway.hpp>

DECLARE_TOP_FUNCTION(pktgen_top);

class pktgen : public hls_ik::ikernel, public hls_ik::gateway_impl<pktgen> {
public:
    pktgen();

    void step(hls_ik::ports& p);

    int reg_write(int address, int value);
    int reg_read(int address, int* value);
    void gateway_update();

private:
    void pktgen_pipeline(hls_ik::pipeline_ports& p);

    enum { IDLE, INPUT_PACKET, DUPLICATE } state;
    /** Number of the current packet in its burst */
    size_t cur_packet;
    /** Gateway register for cur_packet. */
    size_t cur_packet_cache;
    /** Size of each burst in packets */
    size_t burst_size;
    /** Size of each burst in packets: value in gateway to be read */
    size_t burst_size_cache;
    /** Size of each burst in packets: stream to pass between gateway to pktgen */
    hls::stream<size_t> burst_sizes;
    /** Stream to pass current packet size to the gateway */
    hls::stream<size_t> cur_packet_to_gateway;
    /** The offset into the data array we are currently accessing */
    size_t data_offset;
    /** Length of data in the data array (in elements) */
    size_t data_length;
    /** Packet metadata */
    hls_ik::metadata metadata;
    /** Size of the data array (in elements) */
    static const int data_size = 2048 / 32;
    /** An array that holds the packet payload to duplicate */
    hls_ik::axi_data data[data_size];
};
#endif
