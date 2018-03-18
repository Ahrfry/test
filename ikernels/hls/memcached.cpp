#include "memcached-ik.hpp"

using namespace hls_ik;

memcached::memcached() :
    _action_stream(10),
    _kv_pairs_stream(10),
    _parsed_requests_stream(10)
{
#pragma HLS stream variable=_buffer_data depth=30
#pragma HLS stream variable=_parser_data depth=30
#pragma HLS stream variable=_buffer_metadata depth=30
#pragma HLS stream variable=_parser_metadata depth=30
#pragma HLS stream variable=_reply_data_stream depth=15
#pragma HLS stream variable=_reply_metadata_stream depth=15
#pragma HLS data_pack variable=_reply_data_stream
}

void memcached::parse_out_payload(const hls_ik::axi_data &d, int& offset, char key[MEMCACHED_KEY_SIZE], char value[MEMCACHED_VALUE_SIZE]) {
#pragma HLS inline
    for (int i = 0; i < 32; ++i) {
#pragma HLS unroll
        const int bottom = 255 - ((i + 1) * 8 - 1), top = 255 - (i * 8);

        if (32 * offset + i >= 14 && 32 * offset + i <= 14 + MEMCACHED_KEY_SIZE - 1) {
            key[32 * offset + i - 14] = d.data.range(top, bottom);
        }

        const int value_pos = 19 + MEMCACHED_KEY_SIZE + VALUE_BYTES_SIZE;
        if (32 * offset + i >= value_pos && 32 * offset + i <= value_pos + MEMCACHED_VALUE_SIZE - 1) {
            value[32 * offset + i - value_pos] = d.data.range(top, bottom);
        }
    }

    ++offset;
}

void memcached::parse_in_payload(const hls_ik::axi_data &d, int& offset, char udp_header[8], char key[MEMCACHED_KEY_SIZE]) {
#pragma HLS inline
    for (int i = 0; i < 32; ++i) {
#pragma HLS unroll
        const int bottom = 255 - ((i + 1) * 8 - 1), top = 255 - (i * 8);

        if (offset == 0 && i < 8) {
            udp_header[i] = d.data.range(top, bottom);
        }

        if (32 * offset + i >= 12 && 32 * offset + i <= 12 + MEMCACHED_KEY_SIZE - 1) {
            key[32 * offset + i - 12] = d.data.range(top, bottom);
        }
    }

    ++offset;
}

void memcached::reply_cached_value(hls_ik::pipeline_ports &out) {
#pragma HLS pipeline enable_flush ii=1
#pragma HLS array_partition variable=_current_response.data complete
    switch (_reply_state) {
        case REQUEST_METADATA:
            if (!_reply_metadata_stream.empty() && !h2n_arb.a2.full() && !h2n_arb.m2.full()) {
                h2n_arb.a2.write(GENERATE);
                h2n_arb.m2.write(_reply_metadata_stream.read());
                _reply_state = READ_REQUEST;
		goto read_request;
            }

	    break;

        case READ_REQUEST:
read_request:
            if (!_reply_data_stream.empty()) {
                _current_response = _reply_data_stream.read();
                _reply_state = GENERATE_RESPONSE;
            }

	    break;

        case GENERATE_RESPONSE:
	    if (h2n_arb.d2.full()) return;

            const int valid_bytes = std::min(32, REPLY_SIZE - _reply_offset);
            const bool last = _reply_offset + valid_bytes == REPLY_SIZE;
            hls_ik::axi_data d;
            d.set_data(_current_response.data + _reply_offset, valid_bytes);
            d.last = last;
            h2n_arb.d2.write(d);
            _reply_offset += 32;

            if (last) {
                _reply_state = REQUEST_METADATA;
                _reply_offset = 0;
            }

            break;
    }
}

void memcached::drop_or_pass(hls_ik::pipeline_ports& in) {
#pragma HLS pipeline enable_flush ii=1
    switch (_dropper_state) {
        case METADATA:
            if (!_action_stream.empty()
                && !_buffer_metadata.empty()) {
                hls_ik::metadata metadata = _buffer_metadata.read();
                _dropper_action = _action_stream.read();
                in.action.write(_dropper_action);

                if (_dropper_action == PASS) {
                    in.metadata_output.write(metadata);
                }

                _dropper_state = DATA;
            }

            break;

        case DATA:
            if (!_buffer_data.empty()) {
                axi_data d = _buffer_data.read();

                if (_dropper_action == PASS) {
                    in.data_output.write(d);
                }

                if (d.last) {
                    _dropper_state = METADATA;
                }
            }

            break;
    }
}

void memcached::intercept_out_metadata(hls_ik::pipeline_ports &out) {
#pragma HLS pipeline enable_flush ii=3
    if (!out.metadata_input.empty() && !h2n_arb.a1.full() && !h2n_arb.m1.full()) {
        hls_ik::metadata out_metadata = out.metadata_input.read();
        h2n_arb.a1.write(PASS);
        h2n_arb.m1.write(out_metadata);
    }
}

void memcached::intercept_out(hls_ik::pipeline_ports &out) {
#pragma HLS pipeline enable_flush ii=1
#pragma HLS array_partition variable=_parsed_response.key.data complete
#pragma HLS array_partition variable=_parsed_response.value.data complete
    if (_kv_pairs_stream.full()) return;

    if (!out.data_input.empty() && !h2n_arb.d1.full()) {
        axi_data d = out.data_input.read();

        if (_out_offset == 0) {
            const int bottom = 255 - ((8 + 1) * 8 - 1), top = 255 - (8 * 8);
            _response_type_char = d.data.range(top, bottom);
        }

        parse_out_payload(d, _out_offset, _parsed_response.key.data, _parsed_response.value.data);

        // We parse get responses.
        // On get response: cache the key.
        if (d.last) {
            if (_response_type_char == 'V') {
                _kv_pairs_stream.write(_parsed_response);
            }

            _out_offset = 0;
        }

        h2n_arb.d1.write(d);
    }
}

void memcached::parse_packet() {
#pragma HLS pipeline enable_flush ii=1
#pragma HLS array_partition variable=_parsed_request.udp_header complete
#pragma HLS array_partition variable=_parsed_request.key.data complete
    switch (_in_state) {
        case METADATA:
            if (!_parser_metadata.empty()) {
                _in_metadata = _parser_metadata.read();
                _parsed_request.metadata = _in_metadata;
                _in_state = DATA;
            }
            break;

        case DATA:
            if (!_parser_data.empty() && !_parsed_requests_stream.full()) {
                axi_data d = _parser_data.read();

                if (_in_offset == 0) {
                    const int bottom = 255 - ((8 + 1) * 8 - 1), top = 255 - (8 * 8);
                    _request_type_char = d.data.range(top, bottom);

                    if (_request_type_char == 'g') {
                        _parsed_request.type = GET;
                    } else if (_request_type_char == 's') {
                        _parsed_request.type = SET;
                    } else {
                        _parsed_request.type = OTHER;
                    }
                }

                parse_in_payload(d, _in_offset, _parsed_request.udp_header, _parsed_request.key.data);

                if (d.last) {
                    _parsed_requests_stream.write(_parsed_request);
                    _in_offset = 0;
                    _in_state = METADATA;
                }

            }
            break;
    }
}

void memcached::handle_parsed_packet() {
#pragma HLS pipeline enable_flush ii=3
    if (!_kv_pairs_stream.empty()) {
        memcached_key_value_pair kv = _kv_pairs_stream.read();
        _index.insert(kv.key, kv.value);
    }

    if (_parsed_requests_stream.empty() || _action_stream.full()) return;

    memcached_parsed_request parsed_request = _parsed_requests_stream.read();
#pragma HLS array_partition variable=parsed_request.key.data complete

    bool pass_to_host = true;

    if (parsed_request.type == GET) {
        maybe<memcached_value<MEMCACHED_VALUE_SIZE> > found = _index.find(parsed_request.key);
        // Pass the request to the host if the reply streams are full (even upon a cache hit)
        if (found.valid() && !_reply_metadata_stream.full() && !_reply_data_stream.full()) {
            _reply_metadata_stream.write(parsed_request.metadata.reply(REPLY_SIZE));
            _reply_data_stream.write(generate_response(parsed_request, found.value()));
            pass_to_host = false;
        }
    } else if (parsed_request.type == SET) {
        _index.erase(parsed_request.key);
    }

    _action_stream.write(pass_to_host ? PASS : DROP);
}

memcached_response memcached::generate_response(const memcached_parsed_request& parsed_request, const memcached_value<MEMCACHED_VALUE_SIZE> &value) {
    memcached_response response;
#pragma HLS array_partition variable=response.data complete
#pragma HLS array_partition variable=parsed_request.udp_header complete
#pragma HLS array_partition variable=parsed_request.key.data complete
#pragma HLS array_partition variable=value.data complete

    hls_helpers::memcpy<8>(&response.data[0], &parsed_request.udp_header[0]);
    hls_helpers::memcpy<MEMCACHED_KEY_SIZE>(&response.data[14], &parsed_request.key.data[0]);
    hls_helpers::memcpy<MEMCACHED_VALUE_SIZE>(&response.data[19 + MEMCACHED_KEY_SIZE + VALUE_BYTES_SIZE], &value.data[0]);

    return response;
}

void memcached::step(hls_ik::ports& p)
{
#pragma HLS inline
    _raw_dup.dup2(p.net.data_input, _parser_data, _buffer_data);
    _metadata_dup.dup2(p.net.metadata_input, _parser_metadata, _buffer_metadata);
    drop_or_pass(p.net);
    handle_parsed_packet();
    parse_packet();
    reply_cached_value(p.host);
    intercept_out_metadata(p.host);
    intercept_out(p.host);
    h2n_arb.arbitrate(p.host.metadata_output, p.host.data_output, p.host.action);
}

DEFINE_TOP_FUNCTION(memcached_top, memcached, MEMCACHED_UUID)
