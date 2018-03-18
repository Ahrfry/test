/* Copyright (C) 2016 Haggai Eran

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

#ifndef MEMCACHEDCACHE_HPP
#define MEMCACHEDCACHE_HPP

#include <boost/functional/hash.hpp>

template <unsigned Size>
struct memcached_key {
    char data[Size];

    bool operator==(const memcached_key<Size>& rhs) const {
         bool equal = true;

         for (int i = 0; i < Size; ++i) {
#pragma HLS unroll
              if (data[i] != rhs.data[i]) {
                   equal = false;
                   break;
              }
         }

         return equal;
    }
};

template <unsigned Size>
struct memcached_value {
    char data[Size];
};

template <typename Value>
class maybe {
public:
    maybe(bool valid, const Value& v) : _valid(valid), _value(v) {}
    maybe(const Value& v) : _valid(true), _value(v) {}
    maybe() : _valid(false) {}

    bool valid() const { return _valid; }
    const Value& value() const { return _value; }
private:
    bool _valid;
    Value _value;
};

template <unsigned KeySize, unsigned ValueSize, unsigned Size>
class memcached_cache
{
public:
    memcached_cache() : valid() {}

    void insert(const memcached_key<KeySize>& key, const memcached_value<ValueSize>& value)
    {
#pragma HLS inline
        size_t index = h(key);

        tags[index] = key;
        values[index] = value;
        valid[index] = true;
    }

    void erase(const memcached_key<KeySize>& k)
    {
#pragma HLS inline
        size_t index = h(k);

        if (tags[index] == k)
            valid[index] = false;
    }

    maybe<memcached_value<ValueSize> > find(const memcached_key<KeySize>& k) const
    {
#pragma HLS inline
        size_t index = h(k);
        memcached_key<KeySize> tag = tags[index];
        memcached_value<ValueSize> value = values[index];

        return maybe<memcached_value<ValueSize> >(valid[index] && tag == k, value);
    }
private:
    size_t h(const memcached_key<KeySize>& tag) const {
#pragma HLS inline
            return h_b(h_a(tag), tag) % Size;
    }

    size_t h_a(const memcached_key<KeySize>& tag) const {
#pragma HLS pipeline enable_flush ii=3
	    std::size_t seed = 5381;
	    for (int i = 0; i < KeySize / 2; ++i) {
#pragma HLS unroll
		    seed = ((seed << 5) + seed) + tag.data[i];
	    }

	    return seed;
    }

    size_t h_b(size_t seed, const memcached_key<KeySize>& tag) const {
#pragma HLS pipeline enable_flush ii=3
	    for (int i = KeySize / 2; i < KeySize; ++i) {
#pragma HLS unroll
		    seed = ((seed << 5) + seed) + tag.data[i];
	    }

	    return seed;
    }

    memcached_key<KeySize> tags[Size];
    memcached_value<ValueSize> values[Size];
    bool valid[Size];
};

#endif // MEMCACHEDCACHE_HPP
