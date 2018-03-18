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

/* A FIFO that provides backpressure when it has X elements left. */
template <typename T, size_t stream_depth = 15, size_t index_width = hls_helpers::log2(stream_depth)>
class programmmable_fifo
{
public:
    typedef ap_uint<index_width> index_t;
    programmmable_fifo(index_t full_threshold, index_t empty_threshold = 0) :
        _pi(0), _ci(0), _full_threshold(full_threshold),
        _empty_threshold(empty_threshold), _stream()
    {
#pragma HLS stream variable=_stream depth=stream_depth
    }

    void write(const T& t) {
        ++_pi;
        _stream.write(t);
        if (!_pi_updates.full())
            _pi_updates.write(_pi);
    }

    T read() {
        ++_ci;
        if (!_ci_updates.full())
            _ci_updates.write(_ci);
        return _stream.read();
    }

    bool empty() {
        if (!_pi_updates.empty())
            _empty_local_pi = _pi_updates.read();

        return _empty_threshold ? _empty_local_pi - _ci <= _empty_threshold :
               _stream.empty();
    }
    bool full() {
#pragma HLS inline
        if (!_ci_updates.empty())
            _full_local_ci = _ci_updates.read();

        return _pi - _full_local_ci >= _full_threshold;
    }

private:
    index_t _pi, _ci, _full_threshold, _empty_threshold;
    index_t _empty_local_pi, _full_local_ci;
    hls::stream<index_t> _pi_updates, _ci_updates;
    hls::stream<T> _stream;
};
