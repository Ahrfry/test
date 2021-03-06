#!/bin/bash
#
# Copyright (c) 2016-2017 Haggai Eran, Gabi Malka, Lior Zeno, Maroun Tork
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation and/or
# other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS''
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#[input] : base read/write(r/w) addr_hexa value_hexa

base="$1"
cmd="$2"
addr="$3"
value="$4"

cmd_reg=$[$base + 0x0]
data_i_reg=$[$base + 0x8]
data_o_reg=$[$base + 0x10]
done_reg=$[$base + 0x18]

device=/dev/mst/mt4117_pciconf0_fpga_i2c

if [[ "$cmd" == "w" ]]
then
	sudo mlx_fpga -d $device w $data_i_reg $value
	sudo mlx_fpga -d $device w $cmd_reg $[0xc0000000|$addr]
	# verify the command is done by reading 1 from the gateway_done register (0x102c):
	res=0
	while [[ "$res" == 0 ]]
	do
		res=`sudo mlx_fpga -d $device r $done_reg`
	done
	# finally resetting the gateway for the next command and verifying the reset is done:
	sudo mlx_fpga -d $device w $cmd_reg 0x0
	res=1
	while [[ "$res" == 1 ]]
	do
		res=`sudo mlx_fpga -d $device r $done_reg`
	done
else
	sudo mlx_fpga -d $device w $cmd_reg $[0x80000000|$addr]
	res=0
	while [[ "$res" == 0 ]]
	do
		res=`sudo mlx_fpga -d $device r $done_reg`
        done
	sudo mlx_fpga -d $device r $data_o_reg
	# finally resetting the gateway for the next command and verifying the reset is done:
        sudo mlx_fpga -d $device w $cmd_reg 0x0
	res=1
        while [[ "$res" == 1 ]]
	do
		res=`sudo mlx_fpga -d $device r $done_reg`
        done
fi
