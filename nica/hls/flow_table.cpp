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

#include "flow_table_impl.hpp"
#include "udp.h"
using udp::header_stream;
using namespace hls_ik;

flow flow::create(ap_uint<16> source_port, ap_uint<16> dest_port, ap_uint<32> saddr, ap_uint<32> daddr)
{
    flow result = {
        source_port: source_port,
        dest_port: dest_port,
        saddr: saddr,
        daddr: daddr,
    };

    return result;
}

flow flow::from_header(const udp::header_parser& hdr)
{
    return create(hdr.udp.source, hdr.udp.dest, hdr.ip.saddr, hdr.ip.daddr);
}

flow flow::mask(int fields)
{
    return flow::create(
        (fields & FT_FIELD_SRC_PORT) ? 0xffff : 0,
        (fields & FT_FIELD_DST_PORT) ? 0xffff : 0,
        (fields & FT_FIELD_SRC_IP) ? 0xffffffff : 0,
        (fields & FT_FIELD_DST_IP) ? 0xffffffff : 0);
}

flow flow::operator &(const flow& mask) const
{
    return flow::create(
        source_port & mask.source_port,
        dest_port & mask.dest_port,
        saddr & mask.saddr,
        daddr & mask.daddr);
}

void flow_table::ft_step(header_stream& header, result_stream& result,
                         gateway_registers& g)
{
#pragma HLS pipeline enable_flush ii=3
#pragma HLS array_partition variable=table complete
    gateway(this, g);
    
    if (header.empty() || result.full())
        return;

    flow packet_flow_info = flow::from_header(header.read()) &
                            flow::mask(fields);

    for (int i = 0; i < FLOW_TABLE_SIZE; ++i) {
        bool match = packet_flow_info == table[i].key;
        if (match) {
            result.write(flow_table_result(i, table[i].result));
            return;
        }
    }

    result.write(flow_table_result(0, flow_table_value(FT_PASSTHROUGH)));
}

int flow_table::reg_write(int address, int value)
{
#pragma HLS inline
    if (address >= 0 && address < FT_FLOWS_BASE) {
        switch (address) {
        case FT_FIELDS:
            fields = value;
            return 0;
        default:
            return -1;
        }
    }

    int entry = (address - FT_FLOWS_BASE) / FT_STRIDE;
    int field = (address - FT_FLOWS_BASE) & (FT_STRIDE - 1);

    switch (field) {
    case FT_KEY_SADDR:
        table[entry].key.saddr = value;
        break;
    case FT_KEY_DADDR:
        table[entry].key.daddr = value;
        break;
    case FT_KEY_SPORT:
        table[entry].key.source_port = value;
        break;
    case FT_KEY_DPORT:
        table[entry].key.dest_port = value;
        break;
    case FT_RESULT_ACTION:
        table[entry].result.action = flow_table_action(value);
        break;
    case FT_RESULT_IKERNEL:
        table[entry].result.ikernel = value;
        break;
    default:
        return -1;
    }

    return 0;
}

int flow_table::reg_read(int address, int* value)
{
#pragma HLS inline
    int entry = (address - FT_FLOWS_BASE) / FT_STRIDE;
    int field = (address - FT_FLOWS_BASE) & (FT_STRIDE - 1);

    if (address >= 0 && address < FT_FLOWS_BASE) {
        switch (address) {
        case FT_FIELDS:
            *value = fields;
            return 0;
        default:
            goto err;
        }
    }

    switch (field) {
    case FT_KEY_SADDR:
        *value = table[entry].key.saddr;
        break;
    case FT_KEY_DADDR:
        *value = table[entry].key.daddr;
        break;
    case FT_KEY_SPORT:
        *value = table[entry].key.source_port;
        break;
    case FT_KEY_DPORT:
        *value = table[entry].key.dest_port;
        break;
    case FT_RESULT_ACTION:
        *value = table[entry].result.action;
        break;
    case FT_RESULT_IKERNEL:
        *value = table[entry].result.ikernel;
        break;
    default:
        goto err;
    }

    return 0;

err:
    *value = -1;
    return -1;
}

void flow_table::reset()
{
    fields = 0;

    for (int i = 0; i < FLOW_TABLE_SIZE; ++i) {
        table[i].key = flow();
        table[i].result.action = FT_PASSTHROUGH;
    }
}

void flow_table::gateway_update()
{
}

/* Just for testing synthesis results faster */
void flow_table_top(header_stream& header, result_stream& result,
                    gateway_registers& g)
{
    static flow_table ft;

    ft.ft_step(header, result, g);
}
