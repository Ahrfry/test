/* * Copyright (c) 2016-2018 Haggai Eran, Gabi Malka, Lior Zeno, Maroun Tork
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

#include <tuple>

template <typename context_t, uint8_t log_size>
class context_manager {
public:
    typedef ap_uint<log_size> index_t;
    static const size_t size = 1 << log_size;

    context_manager() : query_sent(false) {}

    bool gateway_set(index_t index)
    {
        if (updates.full())
            return false;
        updates.write(std::make_tuple(index, gateway_context));
        return true;
    }

    bool gateway_query(index_t index)
    {
        if (!query_sent) {
            if (queries.full())
                return false;
            queries.write(index);
            query_sent = true;
            return false;
        } else {
            if (responses.empty())
                return false;
            gateway_context = responses.read();
            query_sent = false;
            return true;
        }
    }

    context_t& operator[](index_t index)
    {
        return contexts[index];
    }

    const context_t& operator[](index_t index) const
    {
        return contexts[index];
    }

    void update()
    {
        if (!updates.empty()) {
            index_t index;
            context_t context;

            std::tie(index, context) =  updates.read();
            contexts[index] = context;
        }
        if (!queries.empty() && !responses.full()) {
            index_t index = queries.read();
            responses.write(contexts[index]);
        }
    }

    context_t gateway_context;
private:
    context_t contexts[size];
    bool query_sent;

    hls::stream<std::tuple<index_t, context_t> > updates;
    hls::stream<index_t> queries;
    hls::stream<context_t> responses;
};
