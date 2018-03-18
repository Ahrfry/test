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

#ifndef CACHE_HPP
#define CACHE_HPP

#include <boost/functional/hash.hpp>

#include "maybe.hpp"

template <typename Tag, typename Value, unsigned Size>
class cache
{
public:
    cache() : valid() {}

    bool insert(const Tag& key, const Value& value)
    {
        maybe<size_t> index = lookup(h(key), key);

        if (!index.valid()) {
            return false;
        }

        tags[index.value()] = key;
        values[index.value()] = value;
        valid[index.value()] = true;

        return true;
    }

    bool erase(const Tag& k)
    {
        maybe<size_t> index = lookup(h(k), k);

        if (!index.valid() || tags[index.value()] != k) {
            return false;
        }

        valid[index.value()] = false;

        // fill the hole if needed
        size_t count = 0;
        size_t hash = index.value();

        do {
            hash = (hash + 1) % Size;

            if (!valid[hash]) break;
            if (h(tags[hash]) <= index.value()) {
                tags[index.value()] = tags[hash];
                values[index.value()] = values[hash];
                valid[index.value()] = true;
                valid[hash] = false;
                break;
            }

        } while (++count < Size);

        return true;
    }

    maybe<Value> find(const Tag& k) const
    {
#pragma HLS inline
        maybe<size_t> index = lookup(h(k), k);

        if (!index.valid() || tags[index.value()] != k) {
            return maybe<Value>();
        }

        Value value = values[index.value()];
        return maybe<Value>(value);
    }
private:
    size_t h(const Tag& tag) const { return boost::hash<Tag>()(tag) % Size; }

    maybe<size_t> lookup(size_t hash, const Tag& tag) const {
        size_t count = 0;

        while(valid[hash] && tags[hash] != tag) {
            hash = (hash + 1) % Size;
            if(count++ == Size) {
                return maybe<size_t>();
            }
        }

        return maybe<size_t>(hash);
    }

    Tag tags[Size];
    Value values[Size];
    bool valid[Size];
};

#endif // CACHE_HPP
