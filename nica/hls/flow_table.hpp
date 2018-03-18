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

#ifndef FLOW_TABLE_HPP
#define FLOW_TABLE_HPP

enum flow_table_action {
    FT_PASSTHROUGH = 0,
    FT_DROP = 1,
    FT_IKERNEL = 2,
};

enum flow_table_fields {
    FT_FIELD_SRC_IP = 1 << 0,
    FT_FIELD_DST_IP = 1 << 1,
    FT_FIELD_SRC_PORT = 1 << 2,
    FT_FIELD_DST_PORT = 1 << 3,
};

#define FLOW_TABLE_SIZE 6

#define FT_FIELDS 0
#define FT_FLOWS_BASE 0x10

#define FT_KEY_SADDR 0
#define FT_KEY_DADDR 1
#define FT_KEY_SPORT 2
#define FT_KEY_DPORT 3
#define FT_RESULT_ACTION 8
#define FT_RESULT_IKERNEL 9
#define FT_RESULT_IKERNEL_ID 10
#define FT_STRIDE 0x10

#endif
