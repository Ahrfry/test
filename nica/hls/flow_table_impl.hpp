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

#pragma once

#include <ap_int.h>
#include <hls_stream.h>
#include "gateway.hpp"

#include "flow_table.hpp"
#include "ikernel.hpp"

namespace udp {
    struct header_parser;
    struct header_buffer;
    typedef hls::stream<header_buffer> header_stream;
}

struct flow {
    ap_uint<16> source_port;
    ap_uint<16> dest_port;
    ap_uint<32> saddr;
    ap_uint<32> daddr;

    static flow create(ap_uint<16> source_port, ap_uint<16> dest_port, ap_uint<32> saddr, ap_uint<32> daddr);
    static flow from_header(const udp::header_parser& hdr);

    static flow mask(int fields);
    flow operator& (const flow& mask) const;

    bool operator== (const flow& other) const
    {
        return source_port == other.source_port && dest_port == other.dest_port &&
               saddr == other.saddr && daddr == other.daddr;
    }

    bool operator!= (const flow& other) const
    {
        return source_port != other.source_port || dest_port != other.dest_port ||
               saddr != other.saddr || daddr != other.daddr;
    }

    flow& operator&= (const flow& other)
    {
        *this = *this & other;
        return *this;
    }
};

std::size_t hash_value(flow const& f);

struct flow_table_value {
    flow_table_action action;
    int ikernel;
    hls_ik::ikernel_id_t ikernel_id;

    explicit flow_table_value(flow_table_action action = FT_PASSTHROUGH, int ikernel = 0, hls_ik::ikernel_id_t ikernel_id = 0) :
        action(action), ikernel(ikernel), ikernel_id(ikernel_id)
    {}
};

struct flow_table_result {
    flow_table_value v;
    hls_ik::flow_id_t flow_id;

    explicit flow_table_result(hls_ik::flow_id_t flow_id = 0, const flow_table_value& v = flow_table_value()) :
        v(v), flow_id(flow_id)
    {}
};

struct match {
    struct flow key;
    flow_table_value result;
};

typedef hls::stream<flow_table_result> result_stream;

class flow_table : public hls_ik::gateway_impl<flow_table> {
public:
    flow_table() { reset(); }
    void ft_step(udp::header_stream& header, result_stream& result,
                 hls_ik::gateway_registers& gateway);

    int reg_write(int address, int value);
    int reg_read(int address, int* value);
    void gateway_update();
    void reset();
private:
    bool reset_done;
    match table[FLOW_TABLE_SIZE];
    int fields;
};
