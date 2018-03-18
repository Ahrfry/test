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

#include <hls_stream.h>
#include <functional>

#include "gateway.hpp"
#include "arbiter.hpp"
#include "maybe.hpp"
#include "nica-top.hpp"

class bucket
{
public:
    bucket() :
        cur_tokens(0),
        /* Tokens are divided every 4 cycles (latency is 3 and there is no
         * pipeline).
         * 40 Gbps / (216.25 MHz / 4) = 92.49 bytes
         * 92 bytes * (216.25 MHz / 4) = 39.79 Gbps
         * set to 128 to disable rate limiting altogether */
        tokens_per_round(128),
        log_period(0),
        /* 4096 byte burst */
        log_saturation(12)
    {}

    int cur_tokens;
    int tokens_per_round;
    ap_uint<5> log_period;
    ap_uint<5> log_saturation;

    void add_tokens()
    {
        cur_tokens = std::min(cur_tokens + tokens_per_round,
                              1 << log_saturation);
        assert(cur_tokens <= 1 << log_saturation);
    }

    void charge_tokens(int num_tokens)
    {
        cur_tokens -= num_tokens;
        assert(cur_tokens >= -(1 << 14)); // pass quota here
    }
};

template <unsigned num_ports, typename T>
class arbiter : public hls_ik::gateway_impl<arbiter<num_ports, T> >
{
public:
    static const unsigned num_streams_width = hls_helpers::log2(num_ports);
    typedef hls::stream<T> stream;
    typedef ap_uint<num_streams_width> stream_selector;

    arbiter() : state(IDLE), last_stream(0), stats(),
        /* With a 16384 byte quota the overhead of evicting a port would be 1% */
        log_quota(14),
        log_quota_cache(14),
        idle_timeout(32),
        idle_timeout_cache(32)
    {}

    void divide_tokens()
    {
#pragma HLS inline
        ++cycle_counter;

        divide_tokens_stats:
        for (int i = 0; i < num_ports; ++i)
#pragma HLS unroll
            stats.port[i].cur_tokens = buckets[i].cur_tokens;

        if (!charges.empty()) {
            charge c = charges.read();
            buckets[c.first].charge_tokens(c.second);
        }

        divide_tokens_update:
        for (int i = 0; i < num_ports; ++i) {
#pragma HLS unroll
            if ((cycle_counter & ((1 << buckets[i].log_period) - 1)) == 0)
                buckets[i].add_tokens();
        }
    }

    /* Accept a variable length list of arbiter_input_stream structs */
    template <typename ...Args>
    void arbiter_step(stream& out, arbiter_stats<num_ports>* s,
        hls_ik::gateway_registers& g, trace_event events[4],
        Args&... args)
    {
#pragma HLS inline
#pragma HLS array_partition variable=s->port complete
#pragma HLS array_partition variable=s->tx_port complete
        transmit(s, out, events, args...);
        pick_next_packet(s, g);
    }

    template <typename ...Args>
    void pick_next_packet(arbiter_stats<num_ports>* s,
        hls_ik::gateway_registers& g)
    {
#pragma HLS latency max=3
#pragma HLS array_partition variable=buckets complete
#pragma HLS inline region
        arbiter_stats_output:
        for (int i = 0; i < num_ports; ++i)
#pragma HLS unroll
            s->port[i] = stats.port[i];

        hls_ik::gateway_impl<arbiter<num_ports, T> >::gateway(this, g);

        divide_tokens();

        if (tx_requests.empty() || selected_port_stream.full())
            return;

        auto req = tx_requests.read();

#pragma HLS array_partition variable=stats.port complete
        /* Each stream is considered empty (cannot or will not send) if either
         * its FIFO is empty or the outgoing port says it has no credit. */
        arbiter_evaluate_ports:
        for (int i = 0; i < num_ports; ++i) {
#pragma HLS unroll
            bool no_tokens = buckets[i].cur_tokens < 32;
            arbiter_per_port_stats& port_stats = stats.port[i];

            if (req(i, i))
                ++port_stats.not_empty;
            if (no_tokens)
                ++port_stats.no_tokens;

            req(i, i) = req(i, i) && !no_tokens;
        }

        maybe<stream_selector> selected_stream;

        arbiter_round_robin_select:
        for (int i = 0; i < num_ports; ++i) {
#pragma HLS unroll
            int cur = last_stream + i + 1;
            if (cur >= num_ports)
                cur -= num_ports;
            if (req(cur, cur)) {
                selected_stream = maybe<stream_selector>(cur);
                last_stream = cur;
                break;
            }
        }

        /* It would have been preferable to write only when we know
         * the chosen port is ready to transmit. However, that causes
         * Vivado HLS 2016.2 to crash, saying that this stream has no data
         * producer. This is fixed in 2016.4, so for that version it is
         * possible to move the write to happen only in the case of a
         * non-empty port. */
        selected_port_stream.write(selected_stream);
    }

    template <typename ...Args>
    void transmit(arbiter_stats<num_ports>* s, stream& out,
                  trace_event events[4],
                  Args&... args)
    {
#pragma HLS pipeline II=1 enable_flush
#pragma HLS array_partition variable=stats.tx_port complete
        for (int i = 0; i < num_ports; ++i)
            s->tx_port[i] = stats.tx_port[i];
        s->idle = state == IDLE;
        s->out_full = stats.out_full;
        for (int i = 0; i < 4; ++i)
            events[i] = 0;

        if (out.full()) {
            ++stats.out_full;
            goto end;
        }

        switch (state) {
        case IDLE: {
            if (tx_requests.full())
                break;

            bool my_stream_empty[] = { args.empty()... };
            tx_requests_t req;
            for (int i = 0; i < num_ports; ++i)
                req(i, i) = !my_stream_empty[i];

            if (req) {
                tx_requests.write(req);
                state = WAIT_FOR_ARBITER;
            }
            break;
        }
        case WAIT_FOR_ARBITER:
            if (selected_port_stream.empty())
                break;

            selected_port = selected_port_stream.read();
            assert(!selected_port.valid() || selected_port.value() < 3);
            if (selected_port.valid()) {
                // Make sure only 0-2 are accessed
                switch (selected_port.value()) {
                case 0:
                case 1:
                case 2:
                    events[selected_port.value()] = 1;
                    break;
                default:
                    break;
                }

                accumulated_charge = 0;
                state = STREAM;
                in_out(out, events[TRACE_ARBITER_EVICTED], args...);
            } else {
                state = IDLE;
            }
            break;

        case STREAM:
            in_out(out, events[TRACE_ARBITER_EVICTED], args...);
            break;
        }

end:
        if (!quota_update_stream.empty())
            log_quota = quota_update_stream.read();
        if (!idle_timeout_update_stream.empty())
            idle_timeout = idle_timeout_update_stream.read();
    }

    int reg_write(int address, int value)
    {
#pragma HLS inline
        int entry = address / ARBITER_PORT_STRIDE;
        int field = address & (ARBITER_PORT_STRIDE - 1);

        if (address == ARBITER_QUOTA) {
            if (quota_update_stream.full())
                return GW_BUSY;
            log_quota_cache = value;
            quota_update_stream.write(value);
            return 0;
        }

        if (address == ARBITER_IDLE_TIMEOUT) {
            if (idle_timeout_update_stream.full())
                return GW_BUSY;
            idle_timeout_cache = value;
            idle_timeout_update_stream.write(value);
            return 0;
        }

        switch (field) {
        case ARBITER_BUCKET_PERIOD:
            buckets[entry].log_period = value;
            break;
        case ARBITER_BUCKET_TOKENS:
            buckets[entry].tokens_per_round = value;
            break;
        case ARBITER_BUCKET_LOG_SATURATION:
            buckets[entry].log_saturation = value;
            break;
        default:
            return -1;
        }

        return 0;
    }

    int reg_read(int address, int* value)
    {
#pragma HLS inline
        int entry = address / ARBITER_PORT_STRIDE;
        int field = address & (ARBITER_PORT_STRIDE - 1);

        if (address == ARBITER_QUOTA) {
            *value = log_quota_cache;
            return 0;
        }

        if (address == ARBITER_IDLE_TIMEOUT) {
            *value = idle_timeout_cache;
            return 0;
        }

        switch (field) {
        case ARBITER_BUCKET_PERIOD:
            *value = buckets[entry].log_period;
            break;
        case ARBITER_BUCKET_TOKENS:
            *value = buckets[entry].tokens_per_round;
            break;
        case ARBITER_BUCKET_LOG_SATURATION:
            *value = buckets[entry].log_saturation;
            break;
        default:
            *value = -1;
            return -1;
        }

        return 0;
    }

    void gateway_update() {}

private:
    void in_out_helper(stream& out, trace_event& evicted_event, size_t index) {}

    template <typename ...Args>
    void in_out_helper(stream& out, trace_event& evicted_event, size_t index, stream& in, Args&... args) {
#pragma HLS inline
        if (index > 0)
            return in_out_helper(out, evicted_event, index - 1, args...);

        if (in.empty()) {
            if (--idle_counter == 0 && !tx_mid_packet) {
                // TODO close packet if ikernel is misbehaving even in middle of
                // a packet.
                evicted_event = 1;
                state = IDLE;
            }
        }

        if (in.empty() || charges.full() || !selected_port.valid()) {
            return;
        }

        tx_mid_packet = true;
        T word = in.read();
        out.write(word);
        accumulated_charge += 32;
        /* Reset idle counter */
        idle_counter = idle_timeout;

        stream_selector p = selected_port.value();
        ++stats.tx_port[p].words;
        if (word.last) {
            ++stats.tx_port[p].packets;
            stats.tx_port[p].last_pkt_id = word.id;
            stats.tx_port[p].last_user = word.user;
            tx_mid_packet = false;

            if (accumulated_charge >= 1 << log_quota) {
                selected_port = maybe<stream_selector>();
                evicted_event = 1;
                charges.write(std::make_pair(selected_port.value(), accumulated_charge));
                state = IDLE;
            }
        }
    }

    template <typename ...Args>
    void in_out(stream& out, trace_event& evicted_event, Args&... args)
    {
#pragma HLS inline
        if (selected_port.valid()) {
            in_out_helper(out, evicted_event, selected_port.value(), args...);
            return;
        }
    }

    enum { IDLE, WAIT_FOR_ARBITER, STREAM } state;
    typedef ap_uint<num_ports> tx_requests_t;
    hls::stream<tx_requests_t> tx_requests;
    stream_selector last_stream;
    maybe<stream_selector> selected_port;
    hls::stream<maybe<stream_selector> > selected_port_stream;
    arbiter_stats<num_ports> stats;
    ap_uint<32> cycle_counter;
    bucket buckets[num_ports];
    /* Number of bytes to charge this port when evicting it */
    int accumulated_charge;
    /* Number of bytes a port is allowed to send before it is evicted */
    uint8_t log_quota, log_quota_cache;
    /* updates to the quota configuration register from the gateway */
    hls::stream<uint8_t> quota_update_stream;
    /* Idle timeout - number of cycles a port can be idle before it is evicted */
    uint8_t idle_timeout, idle_timeout_cache;
    /* updates to the idle timeout configuration register from the gateway */
    hls::stream<uint8_t> idle_timeout_update_stream;
    uint8_t idle_counter;
    typedef std::pair<stream_selector, int> charge;
    hls::stream<charge> charges;
    /* Middle of a packet: prevent switching on idle input */
    bool tx_mid_packet;
};
