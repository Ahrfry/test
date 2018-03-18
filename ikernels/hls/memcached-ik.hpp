#ifndef MEMCACHED_HPP
#define MEMCACHED_HPP

// d68adb30-4d19-4f3e-8542-fc184db75bf7
#define MEMCACHED_UUID { 0xd6,0x8a,0xdb,0x30,0x4d,0x19,0x4f,0x3e,0x85,0x42,0xfc,0x18,0x4d,0xb7,0x5b,0xf7 }

#include <ikernel.hpp>
#include <gateway.hpp>
#include <hls_helper.h>
#include <mlx.h>
#include "memcached_cache.hpp"
#include "programmable_fifo.hpp"

#ifndef MEMCACHED_CACHE_SIZE
#define MEMCACHED_CACHE_SIZE 4096
#endif
#define BUFFER_SIZE (20 + MEMCACHED_VALUE_SIZE + MEMCACHED_KEY_SIZE)
#define BUFFER_SIZE_WORDS ((BUFFER_SIZE + 31) / 32)
// Value size length. VALUE_BYTES_SIZE and MEMCACHED_VALUE_SIZE should be changed together.
#define VALUE_BYTES_SIZE 2
#ifndef MEMCACHED_VALUE_SIZE
#define MEMCACHED_VALUE_SIZE 10
#endif
#ifndef MEMCACHED_KEY_SIZE
#define MEMCACHED_KEY_SIZE 10
#endif
#define REPLY_SIZE (8 + 6 + MEMCACHED_KEY_SIZE + 3 + VALUE_BYTES_SIZE + 2 + MEMCACHED_VALUE_SIZE + 7)

DECLARE_TOP_FUNCTION(memcached_top);

#define STRINGIZE(x) #x
#define STRINGIZE_VALUE_OF(x) STRINGIZE(x)

static constexpr const char* ASCII_MEMCACHED_VALUE_SIZE = STRINGIZE_VALUE_OF(MEMCACHED_VALUE_SIZE);

struct memcached_response {
    char data[REPLY_SIZE];

    memcached_response() {
        data[8] = 'V';
        data[9] = 'A';
        data[10] = 'L';
        data[11] = 'U';
        data[12] = 'E';
        data[13] = ' ';
        data[14 + MEMCACHED_KEY_SIZE] = ' ';
        data[15 + MEMCACHED_KEY_SIZE] = '0'; // Flags
        data[16 + MEMCACHED_KEY_SIZE] = ' ';

        // Value size
        hls_helpers::memcpy<VALUE_BYTES_SIZE>(&data[17 + MEMCACHED_KEY_SIZE], &ASCII_MEMCACHED_VALUE_SIZE[0]);

        // Spaces
        data[17 + MEMCACHED_KEY_SIZE + VALUE_BYTES_SIZE] = '\r';
        data[18 + MEMCACHED_KEY_SIZE + VALUE_BYTES_SIZE] = '\n';
        data[19 + MEMCACHED_KEY_SIZE + VALUE_BYTES_SIZE + MEMCACHED_VALUE_SIZE] = '\r';
        data[20 + MEMCACHED_KEY_SIZE + VALUE_BYTES_SIZE + MEMCACHED_VALUE_SIZE] = '\n';
        data[21 + MEMCACHED_KEY_SIZE + VALUE_BYTES_SIZE + MEMCACHED_VALUE_SIZE] = 'E';
        data[22 + MEMCACHED_KEY_SIZE + VALUE_BYTES_SIZE + MEMCACHED_VALUE_SIZE] = 'N';
        data[23 + MEMCACHED_KEY_SIZE + VALUE_BYTES_SIZE + MEMCACHED_VALUE_SIZE] = 'D';
        data[24 + MEMCACHED_KEY_SIZE + VALUE_BYTES_SIZE + MEMCACHED_VALUE_SIZE] = '\r';
        data[25 + MEMCACHED_KEY_SIZE + VALUE_BYTES_SIZE + MEMCACHED_VALUE_SIZE] = '\n';
    }
};

enum request_type { GET, SET, OTHER };

struct memcached_parsed_request {
    char udp_header[8];
    memcached_key<MEMCACHED_KEY_SIZE> key;
    request_type type;
    hls_ik::metadata metadata;
};

struct memcached_key_value_pair {
    memcached_key<MEMCACHED_KEY_SIZE> key;
    memcached_value<MEMCACHED_VALUE_SIZE> value;
};

/* Arbiter between two sets of actions/metadata_output/data_output competing
 * over an ikernel's egress interface. */
class ikernel_arbiter
{
public:
    ikernel_arbiter() {}

    hls_ik::metadata_stream m1;
    hls_ik::metadata_stream m2;

    hls_ik::data_stream d1;
    hls_ik::data_stream d2;

    hls_ik::action_stream a1;
    hls_ik::action_stream a2;

    void arbitrate(hls_ik::metadata_stream& mout,
                   hls_ik::data_stream& dout,
                   hls_ik::action_stream& aout)
    {
#pragma HLS pipeline enable_flush ii=1
#pragma HLS stream variable=m1 depth=15
#pragma HLS stream variable=m2 depth=15
#pragma HLS stream variable=d1 depth=15
#pragma HLS stream variable=d2 depth=15
#pragma HLS stream variable=a1 depth=15
#pragma HLS stream variable=a2 depth=15
        hls_ik::axi_data data;

        switch (state) {
        case IDLE:
            /* First port has priority */
            if (!m1.empty() && !a1.empty()) {
                cur = 0;
                mout.write(m1.read());
                aout.write(a1.read());
            } else if (!m2.empty() && !a2.empty()) {
                cur = 1;
                mout.write(m2.read());
                aout.write(a2.read());
            } else {
                return;
            }
            state = STREAM;
            /* Fallthrough */
        case STREAM:
            if (cur == 0) {
                if (d1.empty())
                    return;
                data = d1.read();
            } else {
                if (d2.empty())
                    return;
                data = d2.read();
            }
            dout.write(data);
            state = data.last ? IDLE : STREAM;
            break;
        }
    }

    enum { IDLE, STREAM } state;
    ap_uint<1> cur;
};

class memcached : public hls_ik::ikernel, public hls_ik::gateway_impl<memcached> {
public:
    virtual void step(hls_ik::ports& p);
    memcached();

private:
    memcached_response generate_response(const memcached_parsed_request &parsed_request, const memcached_value<MEMCACHED_VALUE_SIZE> &value);
    void parse_packet();
    void drop_or_pass(hls_ik::pipeline_ports& in);
    void reply_cached_value(hls_ik::pipeline_ports &out);
    void intercept_out_metadata(hls_ik::pipeline_ports &out);
    void intercept_out(hls_ik::pipeline_ports &out);
    void handle_parsed_packet();
    void parse_out_payload(const hls_ik::axi_data &d, int& offset, char key[MEMCACHED_KEY_SIZE], char value[MEMCACHED_VALUE_SIZE]);
    void parse_in_payload(const hls_ik::axi_data &d, int& offset, char udp_header[8], char key[MEMCACHED_KEY_SIZE]);

    enum state { METADATA, DATA };
    enum reply_state { REQUEST_METADATA, READ_REQUEST, GENERATE_RESPONSE };

    state _in_state, _dropper_state;
    reply_state _reply_state;
    hls_ik::action _dropper_action;
    char _request_type_char, _response_type_char;
    int _in_offset, _out_offset, _reply_offset;
    memcached_response _current_response;
    memcached_cache<MEMCACHED_KEY_SIZE, MEMCACHED_VALUE_SIZE, MEMCACHED_CACHE_SIZE> _index;
    memcached_parsed_request _parsed_request;
    memcached_key_value_pair _parsed_response;
    hls_ik::metadata _in_metadata;
    programmmable_fifo<hls_ik::action> _action_stream;
    programmmable_fifo<memcached_key_value_pair> _kv_pairs_stream;
    programmmable_fifo<memcached_parsed_request> _parsed_requests_stream;
    hls_ik::metadata_stream _reply_metadata_stream, _parser_metadata, _buffer_metadata;
    hls_ik::data_stream _parser_data, _buffer_data;
    hls_helpers::duplicator<1, ap_uint<hls_ik::axi_data::width> > _raw_dup;
    hls_helpers::duplicator<1, ap_uint<hls_ik::metadata::width> > _metadata_dup;
    hls::stream<memcached_response> _reply_data_stream;

    /* port 1 is for passthrough, 2 is for generated */
    ikernel_arbiter h2n_arb;
};

#endif //MEMCACHED_HPP
