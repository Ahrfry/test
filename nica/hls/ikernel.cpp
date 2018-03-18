//
// Copyright (c) 2016-2018 Haggai Eran, Gabi Malka, Lior Zeno, Maroun Tork
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

#include "ikernel.hpp"

namespace hls_ik {

    bool ikernel::can_transmit(ikernel_id_t id, ring_id_t ring, pkt_len_t len, direction_t dir)
    {
        if (ring == 0)
            return true;
        if (dir == HOST)
            return host_credits[ring - 1].can_transmit();
        return true;
    }

    void ikernel::update(credit_update_registers& regs)
    {
        if (last_host_credit_regs != regs) {
            if (regs.reset)
                host_credits[regs.ring_id - 1].msn = 0;
            host_credits[regs.ring_id - 1].max_msn = regs.max_msn;
            last_host_credit_regs = regs;
        }
    }

    void ikernel::new_message(ring_id_t ring, direction_t dir)
    {
        if (dir == HOST)
            host_credits[ring - 1].inc_msn();
    }
}
