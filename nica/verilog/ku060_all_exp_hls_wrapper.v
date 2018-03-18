// nicap.v: Manually generated top level for nica & ikernel IPs
// 
// Wiring procdeure:
// nicap.v interface is same as ku060_all_exp_hls_wrapper.v.
// nica IP wiring borrowed from two sources:
// 1. example_hls instantiation within ku060_all_exp_hls_wrapper.v
// 2. nica instantiation within example_hls.v:
// threshold IP wiring was not available, so manually created, to match the threshold.v interface
//
// Notes:
// 1. All ik* signals curently match between the two IPs.
// 2. ik* signals are local within nicap, and not reflected in nicap interface.
// // 3. An AXIlite crossbar was added, to support single master to multiple slaves (currently up to 4). 
//
//
// Sources:
// ./netperf-verilog/sources/vlog/ku060_all_exp_hls_wrapper.v
// ./netperf-verilog/examples/exp_hls/xci/example_hls/create_xci/create_xci.srcs/sources_1/ip/example_hls/synth/example_hls.v
// ./netperf-verilog/examples/exp_hls/ip_repo/hls/hdl/verilog/nica.v
// ./netperf-verilog/hls/threshold/40Gbps/impl/ip/hdl/verilog/top.v
//
// Gabi Malka
//
//
// Status: All wiring is done (still not checked...)
// 26-Jan-2017


module ku060_all_exp_hls_wrapper(sbu2mlx_ieee_vendor_id, sbu2mlx_product_id, sbu2mlx_product_version, sbu2mlx_caps, sbu2mlx_caps_len,
                      sbu2mlx_caps_addr, mlx2sbu_clk, mlx2sbu_reset, sbu2mlx_leds_on, sbu2mlx_leds_blink, sbu2mlx_watchdog, mlx2sbu_axi4lite_aw_rdy, mlx2sbu_axi4lite_aw_vld, mlx2sbu_axi4lite_aw_addr, mlx2sbu_axi4lite_aw_prot,
                      mlx2sbu_axi4lite_w_rdy, mlx2sbu_axi4lite_w_vld, mlx2sbu_axi4lite_w_data, mlx2sbu_axi4lite_w_strobe, mlx2sbu_axi4lite_b_rdy, mlx2sbu_axi4lite_b_vld, mlx2sbu_axi4lite_b_resp, mlx2sbu_axi4lite_ar_rdy, mlx2sbu_axi4lite_ar_vld, mlx2sbu_axi4lite_ar_addr,
                      mlx2sbu_axi4lite_ar_prot, mlx2sbu_axi4lite_r_rdy, mlx2sbu_axi4lite_r_vld, mlx2sbu_axi4lite_r_data, mlx2sbu_axi4lite_r_resp, sbu2mlx_axi4mm_aw_rdy, sbu2mlx_axi4mm_aw_vld, sbu2mlx_axi4mm_aw_addr, sbu2mlx_axi4mm_aw_burst, sbu2mlx_axi4mm_aw_cache,
                      sbu2mlx_axi4mm_aw_id, sbu2mlx_axi4mm_aw_len, sbu2mlx_axi4mm_aw_lock, sbu2mlx_axi4mm_aw_prot, sbu2mlx_axi4mm_aw_qos, sbu2mlx_axi4mm_aw_region, sbu2mlx_axi4mm_aw_size, sbu2mlx_axi4mm_w_rdy, sbu2mlx_axi4mm_w_vld, sbu2mlx_axi4mm_w_data,
                      sbu2mlx_axi4mm_w_last, sbu2mlx_axi4mm_w_strobe, sbu2mlx_axi4mm_b_rdy, sbu2mlx_axi4mm_b_vld, sbu2mlx_axi4mm_b_id, sbu2mlx_axi4mm_b_resp, sbu2mlx_axi4mm_ar_rdy, sbu2mlx_axi4mm_ar_vld, sbu2mlx_axi4mm_ar_addr, sbu2mlx_axi4mm_ar_burst,
                      sbu2mlx_axi4mm_ar_cache, sbu2mlx_axi4mm_ar_id, sbu2mlx_axi4mm_ar_len, sbu2mlx_axi4mm_ar_lock, sbu2mlx_axi4mm_ar_prot, sbu2mlx_axi4mm_ar_qos, sbu2mlx_axi4mm_ar_region, sbu2mlx_axi4mm_ar_size, sbu2mlx_axi4mm_r_rdy, sbu2mlx_axi4mm_r_vld,
                      sbu2mlx_axi4mm_r_data, sbu2mlx_axi4mm_r_id, sbu2mlx_axi4mm_r_last, sbu2mlx_axi4mm_r_resp, mlx2sbu_axi4stream_rdy, mlx2sbu_axi4stream_vld, mlx2sbu_axi4stream_tdata, mlx2sbu_axi4stream_tkeep, mlx2sbu_axi4stream_tlast, mlx2sbu_axi4stream_tuser,
                      mlx2sbu_axi4stream_tid, sbu2mlx_axi4stream_rdy, sbu2mlx_axi4stream_vld, sbu2mlx_axi4stream_tdata, sbu2mlx_axi4stream_tkeep, sbu2mlx_axi4stream_tlast, sbu2mlx_axi4stream_tuser, sbu2mlx_axi4stream_tid, nwp2sbu_axi4stream_rdy, nwp2sbu_axi4stream_vld,
                      nwp2sbu_axi4stream_tdata, nwp2sbu_axi4stream_tkeep, nwp2sbu_axi4stream_tlast, nwp2sbu_axi4stream_tuser, nwp2sbu_axi4stream_tid, sbu2nwp_axi4stream_rdy, sbu2nwp_axi4stream_vld, sbu2nwp_axi4stream_tdata, sbu2nwp_axi4stream_tkeep, sbu2nwp_axi4stream_tlast,
                      sbu2nwp_axi4stream_tuser, sbu2nwp_axi4stream_tid, cxp2sbu_axi4stream_rdy, cxp2sbu_axi4stream_vld, cxp2sbu_axi4stream_tdata, cxp2sbu_axi4stream_tkeep, cxp2sbu_axi4stream_tlast, cxp2sbu_axi4stream_tuser, cxp2sbu_axi4stream_tid, sbu2cxp_axi4stream_rdy,
                      sbu2cxp_axi4stream_vld, sbu2cxp_axi4stream_tdata, sbu2cxp_axi4stream_tkeep, sbu2cxp_axi4stream_tlast, sbu2cxp_axi4stream_tuser, sbu2cxp_axi4stream_tid, nwp2sbu_lossy_has_credits, nwp2sbu_lossless_has_credits, cxp2sbu_lossy_has_credits, cxp2sbu_lossless_has_credits);

output [23:0] sbu2mlx_ieee_vendor_id;// N24
output [15:0] sbu2mlx_product_id;// N16
output [15:0] sbu2mlx_product_version;// N16
output [31:0] sbu2mlx_caps;// N32
output [15:0] sbu2mlx_caps_len;// N16
output [23:0] sbu2mlx_caps_addr;// N24

input         mlx2sbu_clk;// Working clock of 216.25MHz
input         mlx2sbu_reset;// Synchronous reset line to the clock named 'mlx2sbu_clk', active high.
output [7:0]  sbu2mlx_leds_on;// N8
output [7:0]  sbu2mlx_leds_blink;// N8
output        sbu2mlx_watchdog;// Watchdog signal (Should be toggled with freq > 1Hz)

output        mlx2sbu_axi4lite_aw_rdy;
input         mlx2sbu_axi4lite_aw_vld;
input [63:0]  mlx2sbu_axi4lite_aw_addr;// N64
input [2:0]   mlx2sbu_axi4lite_aw_prot;// N3

output        mlx2sbu_axi4lite_w_rdy;
input         mlx2sbu_axi4lite_w_vld;
input [31:0]  mlx2sbu_axi4lite_w_data;// N32
input [3:0]   mlx2sbu_axi4lite_w_strobe;// N4

input         mlx2sbu_axi4lite_b_rdy;
output        mlx2sbu_axi4lite_b_vld;
output [1:0]  mlx2sbu_axi4lite_b_resp;// N2

output        mlx2sbu_axi4lite_ar_rdy;
input         mlx2sbu_axi4lite_ar_vld;
input [63:0]  mlx2sbu_axi4lite_ar_addr;// N64
input [2:0]   mlx2sbu_axi4lite_ar_prot;// N3

input         mlx2sbu_axi4lite_r_rdy;
output        mlx2sbu_axi4lite_r_vld;
output [31:0] mlx2sbu_axi4lite_r_data;// N32
output [1:0]  mlx2sbu_axi4lite_r_resp;// N2

input         sbu2mlx_axi4mm_aw_rdy;
output        sbu2mlx_axi4mm_aw_vld;
output [63:0] sbu2mlx_axi4mm_aw_addr;// N64
output [1:0]  sbu2mlx_axi4mm_aw_burst;// N2
output [3:0]  sbu2mlx_axi4mm_aw_cache;// N4
output [2:0]  sbu2mlx_axi4mm_aw_id;// N3
output [7:0]  sbu2mlx_axi4mm_aw_len;// N8
output [0:0]  sbu2mlx_axi4mm_aw_lock;// N1
output [2:0]  sbu2mlx_axi4mm_aw_prot;// N3
output [3:0]  sbu2mlx_axi4mm_aw_qos;// N4
output [3:0]  sbu2mlx_axi4mm_aw_region;// N4
output [2:0]  sbu2mlx_axi4mm_aw_size;// N3

input         sbu2mlx_axi4mm_w_rdy;
output        sbu2mlx_axi4mm_w_vld;
output [511:0] sbu2mlx_axi4mm_w_data;// N512
output         sbu2mlx_axi4mm_w_last;
output [63:0]  sbu2mlx_axi4mm_w_strobe;// N64

output         sbu2mlx_axi4mm_b_rdy;
input          sbu2mlx_axi4mm_b_vld;
input [2:0]    sbu2mlx_axi4mm_b_id;// N3
input [1:0]    sbu2mlx_axi4mm_b_resp;// N2

input          sbu2mlx_axi4mm_ar_rdy;
output         sbu2mlx_axi4mm_ar_vld;
output [63:0]  sbu2mlx_axi4mm_ar_addr;// N64
output [1:0]   sbu2mlx_axi4mm_ar_burst;// N2
output [3:0]   sbu2mlx_axi4mm_ar_cache;// N4
output [2:0]   sbu2mlx_axi4mm_ar_id;// N3
output [7:0]   sbu2mlx_axi4mm_ar_len;// N8
output [0:0]   sbu2mlx_axi4mm_ar_lock;// N1
output [2:0]   sbu2mlx_axi4mm_ar_prot;// N3
output [3:0]   sbu2mlx_axi4mm_ar_qos;// N4
output [3:0]   sbu2mlx_axi4mm_ar_region;// N4
output [2:0]   sbu2mlx_axi4mm_ar_size;// N3

output         sbu2mlx_axi4mm_r_rdy;
input          sbu2mlx_axi4mm_r_vld;
input [511:0]  sbu2mlx_axi4mm_r_data;// N512
input [2:0]    sbu2mlx_axi4mm_r_id;// N3
input          sbu2mlx_axi4mm_r_last;
input [1:0]    sbu2mlx_axi4mm_r_resp;// N2

output         mlx2sbu_axi4stream_rdy;
input          mlx2sbu_axi4stream_vld;
input [255:0]  mlx2sbu_axi4stream_tdata;// N256
input [31:0]   mlx2sbu_axi4stream_tkeep;// N32
input [0:0]    mlx2sbu_axi4stream_tlast;// N1
input [11:0]   mlx2sbu_axi4stream_tuser;// N12
input [2:0]    mlx2sbu_axi4stream_tid;// N3

input          sbu2mlx_axi4stream_rdy;
output         sbu2mlx_axi4stream_vld;
output [255:0] sbu2mlx_axi4stream_tdata;// N256
output [31:0]  sbu2mlx_axi4stream_tkeep;// N32
output [0:0]   sbu2mlx_axi4stream_tlast;// N1
output [11:0]  sbu2mlx_axi4stream_tuser;// N12
output [2:0]   sbu2mlx_axi4stream_tid;// N3

output         nwp2sbu_axi4stream_rdy;
input          nwp2sbu_axi4stream_vld;
input [255:0]  nwp2sbu_axi4stream_tdata;// N256
input [31:0]   nwp2sbu_axi4stream_tkeep;// N32
input [0:0]    nwp2sbu_axi4stream_tlast;// N1
input [11:0]   nwp2sbu_axi4stream_tuser;// N12
input [2:0]    nwp2sbu_axi4stream_tid;// N3

input          sbu2nwp_axi4stream_rdy;
output         sbu2nwp_axi4stream_vld;
output [255:0] sbu2nwp_axi4stream_tdata;// N256
output [31:0]  sbu2nwp_axi4stream_tkeep;// N32
output [0:0]   sbu2nwp_axi4stream_tlast;// N1
output [11:0]  sbu2nwp_axi4stream_tuser;// N12
output [2:0]   sbu2nwp_axi4stream_tid;// N3

output         cxp2sbu_axi4stream_rdy;
input          cxp2sbu_axi4stream_vld;
input [255:0]  cxp2sbu_axi4stream_tdata;// N256
input [31:0]   cxp2sbu_axi4stream_tkeep;// N32
input [0:0]    cxp2sbu_axi4stream_tlast;// N1
input [11:0]   cxp2sbu_axi4stream_tuser;// N12
input [2:0]    cxp2sbu_axi4stream_tid;// N3

input          sbu2cxp_axi4stream_rdy;
output         sbu2cxp_axi4stream_vld;
output [255:0] sbu2cxp_axi4stream_tdata;// N256
output [31:0]  sbu2cxp_axi4stream_tkeep;// N32
output [0:0]   sbu2cxp_axi4stream_tlast;// N1
output [11:0]  sbu2cxp_axi4stream_tuser;// N12
output [2:0]   sbu2cxp_axi4stream_tid;// N3

input          nwp2sbu_lossy_has_credits;
input          nwp2sbu_lossless_has_credits;
input          cxp2sbu_lossy_has_credits;
input          cxp2sbu_lossless_has_credits;

///////////////////////////////////////////////////////////////////////////////

// mvlint ignore: 11

// ID
//assign         sbu2mlx_ieee_vendor_id = 24'h0002c9;// Mellanox
// Assigning a TCE specific ID, at AXI-lite address 0x900020
// Useful to verify that NICA bit file has been properly loaded into the FPGA
  assign         sbu2mlx_ieee_vendor_id  = sbu2mlx_ieee_vendor_id_r;        // Technion, TCE. read at address 0x900020
  assign         sbu2mlx_product_id      = 16'd4;                           // @address 0x900024
  assign         sbu2mlx_product_version = `BUILD_NUMBER;                   // @address 0x900024
  assign         sbu2mlx_caps            = 32'd0;                           // @address 0x900028
  assign         sbu2mlx_caps_len        = 16'd0;                           // @address 0x90002c
  assign         sbu2mlx_caps_addr       = 24'd0;                           // @address 0x900034

  wire 	       sbu2mlx_axi4mm_aw_user;
  wire 	       temp1;
  wire 	       temp2;
  
 
// AXIlite crossbar: single master ==> multiple slaves
// Local signals for AXIlite outputs
  localparam
    // AXIlite IO space zones, split between the various slaves:
    AXILITE_ADDR_WIDTH = 32,
    AXILITE_BASE0   = 32'h0000, // NICA
    AXILITE_BASE1   = 32'h1000, // ik0
    AXILITE_BASE2   = 32'h2000, // ik1
    AXILITE_BASE3   = 32'h3000, // ik2
    AXILITE_BASE4   = 32'h4000, // ik3
    AXILITE_BASE5   = 32'h5000, // ik4
    AXILITE_BASE6   = 32'h6000, // ik5
    AXILITE_BASE7   = 32'h7000, // ik6
    AXILITE_BASE8   = 32'h8000, // sigmon internal registers
    AXILITE_BASE9   = 32'h9000, // Reserved
    AXILITE_TIMEOUT = 32'd100;  // Max 100 clocks are allowed for an axilite slave to respond to read/write, after which the axilite_dummy_slave will respond
  
  wire [239:0] ik0_host_metadata_input_V_V_TDATA;
  wire [295:0] ik0_host_data_input_V_V_TDATA;
  wire [7:0]   ik0_host_action_V_V_TDATA;
  wire [239:0] ik0_host_metadata_output_V_V_TDATA;
  wire [295:0] ik0_host_data_output_V_V_TDATA;
  wire [239:0] ik0_net_metadata_input_V_V_TDATA;
  wire [295:0] ik0_net_data_input_V_V_TDATA;
  wire [7:0]   ik0_net_action_V_V_TDATA;
  wire [239:0] ik0_net_metadata_output_V_V_TDATA;
  wire [295:0] ik0_net_data_output_V_V_TDATA;
  wire [239:0] ik1_host_metadata_input_V_V_TDATA;
  wire [295:0] ik1_host_data_input_V_V_TDATA;
  wire [7:0]   ik1_host_action_V_V_TDATA;
  wire [239:0] ik1_host_metadata_output_V_V_TDATA;
  wire [295:0] ik1_host_data_output_V_V_TDATA;
  wire [239:0] ik1_net_metadata_input_V_V_TDATA;
  wire [295:0] ik1_net_data_input_V_V_TDATA;
  wire [7:0]   ik1_net_action_V_V_TDATA;
  wire [239:0] ik1_net_metadata_output_V_V_TDATA;
  wire [295:0] ik1_net_data_output_V_V_TDATA;
  wire [239:0] ik2_host_metadata_input_V_V_TDATA;
  wire [295:0] ik2_host_data_input_V_V_TDATA;
  wire [7:0]   ik2_host_action_V_V_TDATA;
  wire [239:0] ik2_host_metadata_output_V_V_TDATA;
  wire [295:0] ik2_host_data_output_V_V_TDATA;
  wire [239:0] ik2_net_metadata_input_V_V_TDATA;
  wire [295:0] ik2_net_data_input_V_V_TDATA;
  wire [7:0]   ik2_net_action_V_V_TDATA;
  wire [239:0] ik2_net_metadata_output_V_V_TDATA;
  wire [295:0] ik2_net_data_output_V_V_TDATA;
  wire [295:0] ik2_control_ikernel2host_V_V_TDATA;
  wire [295:0] ik2_control_host2ikernel_V_V_TDATA;
  wire [239:0] ik3_host_metadata_input_V_V_TDATA;
  wire [295:0] ik3_host_data_input_V_V_TDATA;
  wire [7:0]   ik3_host_action_V_V_TDATA;
  wire [239:0] ik3_host_metadata_output_V_V_TDATA;
  wire [295:0] ik3_host_data_output_V_V_TDATA;
  wire [239:0] ik3_net_metadata_input_V_V_TDATA;
  wire [295:0] ik3_net_data_input_V_V_TDATA;
  wire [7:0]   ik3_net_action_V_V_TDATA;
  wire [239:0] ik3_net_metadata_output_V_V_TDATA;
  wire [295:0] ik3_net_data_output_V_V_TDATA;
  wire [295:0] ik3_control_ikernel2host_V_V_TDATA;
  wire [295:0] ik3_control_host2ikernel_V_V_TDATA;
  wire [31:0]  waddr2ikernels;
  wire [31:0]  raddr2ikernels;

  reg  	       nica_AXILiteS_AWVALID;
  reg  	       nica_AXILiteS_ARVALID;
  wire 	       nica_AXILiteS_AWREADY;
  wire 	       nica_AXILiteS_ARREADY;
  wire 	       nica_AXILiteS_WREADY;
  wire 	       nica_AXILiteS_RVALID;
  wire [31:0]  nica_AXILiteS_RDATA;
  wire 	       nica_AXILiteS_BVALID;
  wire [1:0]   nica_AXILiteS_BRESP;
  wire [1:0]   nica_AXILiteS_RRESP;
  reg  	       ik0_AXILiteS_AWVALID;
  reg  	       ik0_AXILiteS_ARVALID;
  wire 	       ik0_AXILiteS_AWREADY;
  wire 	       ik0_AXILiteS_ARREADY;
  wire 	       ik0_AXILiteS_WREADY;
  wire 	       ik0_AXILiteS_RVALID;
  wire [31:0]  ik0_AXILiteS_RDATA;
  wire 	       ik0_AXILiteS_BVALID;
  wire [1:0]   ik0_AXILiteS_BRESP;
  wire [1:0]   ik0_AXILiteS_RRESP;
  reg  	       ik1_AXILiteS_AWVALID;
  reg  	       ik1_AXILiteS_ARVALID;
  wire 	       ik1_AXILiteS_AWREADY;
  wire 	       ik1_AXILiteS_ARREADY;
  wire 	       ik1_AXILiteS_WREADY;
  wire 	       ik1_AXILiteS_RVALID;
  wire [31:0]  ik1_AXILiteS_RDATA;
  wire 	       ik1_AXILiteS_BVALID;
  wire [1:0]   ik1_AXILiteS_BRESP;
  wire [1:0]   ik1_AXILiteS_RRESP;
  reg  	       ik2_AXILiteS_AWVALID;
  reg  	       ik2_AXILiteS_ARVALID;
  wire 	       ik2_AXILiteS_AWREADY;
  wire 	       ik2_AXILiteS_ARREADY;
  wire 	       ik2_AXILiteS_WREADY;
  wire 	       ik2_AXILiteS_RVALID;
  wire [31:0]  ik2_AXILiteS_RDATA;
  wire 	       ik2_AXILiteS_BVALID;
  wire [1:0]   ik2_AXILiteS_BRESP;
  wire [1:0]   ik2_AXILiteS_RRESP;
  reg  	       sigmon_AXILiteS_AWVALID;
  reg  	       sigmon_AXILiteS_ARVALID;
  wire 	       sigmon_AXILiteS_AWREADY;
  wire 	       sigmon_AXILiteS_ARREADY;
  wire 	       sigmon_AXILiteS_WREADY;
  wire 	       sigmon_AXILiteS_RVALID;
  wire [31:0]  sigmon_AXILiteS_RDATA;
  wire 	       sigmon_AXILiteS_BVALID;
  wire [1:0]   sigmon_AXILiteS_BRESP;
  wire [1:0]   sigmon_AXILiteS_RRESP;
  reg  	       dummy_AXILiteS_AWVALID;
  reg  	       dummy_AXILiteS_ARVALID;
  wire 	       dummy_AXILiteS_AWREADY;
  wire 	       dummy_AXILiteS_ARREADY;
  wire 	       dummy_AXILiteS_WREADY;
  wire 	       dummy_AXILiteS_RVALID;
  wire [31:0]  dummy_AXILiteS_RDATA;
  wire 	       dummy_AXILiteS_BVALID;
  wire [1:0]   dummy_AXILiteS_BRESP;
  wire [1:0]   dummy_AXILiteS_RRESP;

  wire [AXILITE_ADDR_WIDTH-1 : 0] waddr;
  wire [AXILITE_ADDR_WIDTH-1 : 0] raddr;

  reg  	       axilite_write_nica;
  reg  	       axilite_write_ik0;
  reg  	       axilite_write_ik1;
  reg  	       axilite_write_ik2;
  reg  	       axilite_write_sigmon;
  reg  	       axilite_read_nica;
  reg  	       axilite_read_ik0;
  reg  	       axilite_read_ik1;
  reg  	       axilite_read_ik2;
  reg  	       axilite_read_sigmon;
  wire         axilite_read_none;
  wire         axilite_write_none;
  reg  	       axilite_read_dummy;
  reg  	       axilite_write_dummy;
  reg [31:0]   axilite_read_timeout;
  reg [31:0]   axilite_write_timeout;

  reg [23:0]   sbu2mlx_ieee_vendor_id_r;

// sbu to cxp data fifo
  wire [255:0] sbu2cxpfifo_axi4stream_tdata;  
  wire         sbu2cxpfifo_axi4stream_vld;
  wire         sbu2cxpfifo_axi4stream_rdy;
  wire [31:0]  sbu2cxpfifo_axi4stream_tkeep;
  wire         sbu2cxpfifo_axi4stream_tlast;
  wire [2:0]   sbu2cxpfifo_axi4stream_tid;
  wire [11:0]  sbu2cxpfifo_axi4stream_tuser;
  wire [31:0]  sbu2cxpfifo_data_count;
  wire [31:0]  sbu2cxpfifo_wr_data_count;
  wire [31:0]  sbu2cxpfifo_rd_data_count;

  
// sbu to nwp data fifo
  wire [255:0] sbu2nwpfifo_axi4stream_tdata;  
  wire         sbu2nwpfifo_axi4stream_vld;
  wire         sbu2nwpfifo_axi4stream_rdy;
  wire [31:0]  sbu2nwpfifo_axi4stream_tkeep;
  wire         sbu2nwpfifo_axi4stream_tlast;
  wire [2:0]   sbu2nwpfifo_axi4stream_tid;
  wire [11:0]  sbu2nwpfifo_axi4stream_tuser;
  wire [31:0]  sbu2nwpfifo_data_count;
  wire [31:0]  sbu2nwpfifo_wr_data_count;
  wire [31:0]  sbu2nwpfifo_rd_data_count;

// {cxp,nwp} fifo to credit mask
  wire sbu2nwp_m_axis_tvalid;
  wire sbu2cxp_m_axis_tvalid;
// {cxp,nwp} fifo from credit mask
  wire sbu2nwp_m_axis_tready;
  wire sbu2cxp_m_axis_tready;
  
  reg  sbu2cxp_packet_in_flight;
  reg  sbu2nwp_packet_in_flight;

  wire nica_events0;
  wire nica_events1;
  wire nica_events2;
  wire nica_events3;
  wire nica_events4;
  wire nica_events5;
  wire nica_events6;
  wire nica_events7;

///////////////////////////////////////////////////////////////////////////////
// nica IP:
///////////////////////////////////////////////////////////////////////////////

  nica_nica #(
    .C_S_AXI_AXILITES_ADDR_WIDTH(32),
    .C_S_AXI_AXILITES_DATA_WIDTH(32)
  ) nica0 (

// nica wiring borrowed from example_hls instantiation within ku060_all_exp_hls_wrapper.v:
        .ap_clk(mlx2sbu_clk),
        .ap_rst_n(~mlx2sbu_reset),


        .prt_nw2sbu_TDATA(nwp2sbu_axi4stream_tdata),
        .prt_nw2sbu_TVALID(nwp2sbu_axi4stream_vld),
        .prt_nw2sbu_TREADY(nwp2sbu_axi4stream_rdy),
        .prt_nw2sbu_TKEEP(nwp2sbu_axi4stream_tkeep),
        .prt_nw2sbu_TLAST(nwp2sbu_axi4stream_tlast),
        .prt_nw2sbu_TID(nwp2sbu_axi4stream_tid),
        .prt_nw2sbu_TUSER(nwp2sbu_axi4stream_tuser),

        .prt_cx2sbu_TDATA(cxp2sbu_axi4stream_tdata),
        .prt_cx2sbu_TVALID(cxp2sbu_axi4stream_vld),
        .prt_cx2sbu_TREADY(cxp2sbu_axi4stream_rdy),
        .prt_cx2sbu_TKEEP(cxp2sbu_axi4stream_tkeep),
        .prt_cx2sbu_TLAST(cxp2sbu_axi4stream_tlast),
        .prt_cx2sbu_TID(cxp2sbu_axi4stream_tid),
        .prt_cx2sbu_TUSER(cxp2sbu_axi4stream_tuser),

        .sbu2prt_nw_TDATA(sbu2nwpfifo_axi4stream_tdata),
        .sbu2prt_nw_TVALID(sbu2nwpfifo_axi4stream_vld),
        .sbu2prt_nw_TREADY(sbu2nwpfifo_axi4stream_rdy),
        .sbu2prt_nw_TKEEP(sbu2nwpfifo_axi4stream_tkeep),
        .sbu2prt_nw_TLAST(sbu2nwpfifo_axi4stream_tlast),
        .sbu2prt_nw_TID(sbu2nwpfifo_axi4stream_tid),
        .sbu2prt_nw_TUSER(sbu2nwpfifo_axi4stream_tuser),

        .sbu2prt_cx_TDATA(sbu2cxpfifo_axi4stream_tdata),
        .sbu2prt_cx_TVALID(sbu2cxpfifo_axi4stream_vld),
        .sbu2prt_cx_TREADY(sbu2cxpfifo_axi4stream_rdy),
        .sbu2prt_cx_TKEEP(sbu2cxpfifo_axi4stream_tkeep),
        .sbu2prt_cx_TLAST(sbu2cxpfifo_axi4stream_tlast),
        .sbu2prt_cx_TID(sbu2cxpfifo_axi4stream_tid),
        .sbu2prt_cx_TUSER(sbu2cxpfifo_axi4stream_tuser),

        .s_axi_AXILiteS_AWREADY(nica_AXILiteS_AWREADY),
        .s_axi_AXILiteS_AWVALID(nica_AXILiteS_AWVALID),
        .s_axi_AXILiteS_AWADDR(waddr2ikernels),
        // .axi4lite_aw_prot(mlx2sbu_axi4lite_aw_prot),

        .s_axi_AXILiteS_WVALID(mlx2sbu_axi4lite_w_vld),
        .s_axi_AXILiteS_WREADY(nica_AXILiteS_WREADY),
        .s_axi_AXILiteS_WDATA(mlx2sbu_axi4lite_w_data),
        .s_axi_AXILiteS_WSTRB(mlx2sbu_axi4lite_w_strobe),

        .s_axi_AXILiteS_ARVALID(nica_AXILiteS_ARVALID),
        .s_axi_AXILiteS_ARREADY(nica_AXILiteS_ARREADY),
        .s_axi_AXILiteS_ARADDR(raddr2ikernels),
        // .axi4lite_ar_prot(mlx2sbu_axi4lite_ar_prot),

        .s_axi_AXILiteS_BVALID(nica_AXILiteS_BVALID),
        .s_axi_AXILiteS_BREADY(mlx2sbu_axi4lite_b_rdy),
        .s_axi_AXILiteS_BRESP(nica_AXILiteS_BRESP),

        .s_axi_AXILiteS_RVALID(nica_AXILiteS_RVALID),
        .s_axi_AXILiteS_RREADY(mlx2sbu_axi4lite_r_rdy),
        .s_axi_AXILiteS_RDATA(nica_AXILiteS_RDATA),
        .s_axi_AXILiteS_RRESP(nica_AXILiteS_RRESP),
// end of nica wiring borrowed from ku060_all_exp_hls_wrapper.v

    .events_0_V(nica_events0),
    .events_1_V(nica_events1),
    .events_2_V(nica_events2),
    .events_3_V(nica_events3),
    .events_4_V(nica_events4),
    .events_5_V(nica_events5),
    .events_6_V(nica_events6),
    .events_7_V(nica_events7),

// nica wiring borrowed from nica instantiation within example_hls.v:
// nica to/from first ikernel
    .ik0_host_metadata_input_V_V_TVALID(ik0_host_metadata_input_V_V_TVALID),
    .ik0_host_metadata_input_V_V_TREADY(ik0_host_metadata_input_V_V_TREADY),
    .ik0_host_metadata_input_V_V_TDATA(ik0_host_metadata_input_V_V_TDATA),
    .ik0_host_data_input_V_V_TVALID(ik0_host_data_input_V_V_TVALID),
    .ik0_host_data_input_V_V_TREADY(ik0_host_data_input_V_V_TREADY),
    .ik0_host_data_input_V_V_TDATA(ik0_host_data_input_V_V_TDATA),
    .ik0_host_action_V_V_TVALID(ik0_host_action_V_V_TVALID),
    .ik0_host_action_V_V_TREADY(ik0_host_action_V_V_TREADY),
    .ik0_host_action_V_V_TDATA(ik0_host_action_V_V_TDATA),
    .ik0_host_metadata_output_V_V_TVALID(ik0_host_metadata_output_V_V_TVALID),
    .ik0_host_metadata_output_V_V_TREADY(ik0_host_metadata_output_V_V_TREADY),
    .ik0_host_metadata_output_V_V_TDATA(ik0_host_metadata_output_V_V_TDATA),
    .ik0_host_data_output_V_V_TVALID(ik0_host_data_output_V_V_TVALID),
    .ik0_host_data_output_V_V_TREADY(ik0_host_data_output_V_V_TREADY),
    .ik0_host_data_output_V_V_TDATA(ik0_host_data_output_V_V_TDATA),
    .ik0_net_metadata_input_V_V_TVALID(ik0_net_metadata_input_V_V_TVALID),
    .ik0_net_metadata_input_V_V_TREADY(ik0_net_metadata_input_V_V_TREADY),
    .ik0_net_metadata_input_V_V_TDATA(ik0_net_metadata_input_V_V_TDATA),
    .ik0_net_data_input_V_V_TVALID(ik0_net_data_input_V_V_TVALID),
    .ik0_net_data_input_V_V_TREADY(ik0_net_data_input_V_V_TREADY),
    .ik0_net_data_input_V_V_TDATA(ik0_net_data_input_V_V_TDATA),
    .ik0_net_action_V_V_TVALID(ik0_net_action_V_V_TVALID),
    .ik0_net_action_V_V_TREADY(ik0_net_action_V_V_TREADY),
    .ik0_net_action_V_V_TDATA(ik0_net_action_V_V_TDATA),
    .ik0_net_metadata_output_V_V_TVALID(ik0_net_metadata_output_V_V_TVALID),
    .ik0_net_metadata_output_V_V_TREADY(ik0_net_metadata_output_V_V_TREADY),
    .ik0_net_metadata_output_V_V_TDATA(ik0_net_metadata_output_V_V_TDATA),
    .ik0_net_data_output_V_V_TVALID(ik0_net_data_output_V_V_TVALID),
    .ik0_net_data_output_V_V_TREADY(ik0_net_data_output_V_V_TREADY),
    .ik0_net_data_output_V_V_TDATA(ik0_net_data_output_V_V_TDATA)

// nica to/from second ikernel
`ifdef NUM_IKERNELS_GT_1
    ,
    .ik1_host_metadata_input_V_V_TVALID(ik1_host_metadata_input_V_V_TVALID),
    .ik1_host_metadata_input_V_V_TREADY(ik1_host_metadata_input_V_V_TREADY),
    .ik1_host_metadata_input_V_V_TDATA(ik1_host_metadata_input_V_V_TDATA),
    .ik1_host_data_input_V_V_TVALID(ik1_host_data_input_V_V_TVALID),
    .ik1_host_data_input_V_V_TREADY(ik1_host_data_input_V_V_TREADY),
    .ik1_host_data_input_V_V_TDATA(ik1_host_data_input_V_V_TDATA),
    .ik1_host_action_V_V_TVALID(ik1_host_action_V_V_TVALID),
    .ik1_host_action_V_V_TREADY(ik1_host_action_V_V_TREADY),
    .ik1_host_action_V_V_TDATA(ik1_host_action_V_V_TDATA),
    .ik1_host_metadata_output_V_V_TVALID(ik1_host_metadata_output_V_V_TVALID),
    .ik1_host_metadata_output_V_V_TREADY(ik1_host_metadata_output_V_V_TREADY),
    .ik1_host_metadata_output_V_V_TDATA(ik1_host_metadata_output_V_V_TDATA),
    .ik1_host_data_output_V_V_TVALID(ik1_host_data_output_V_V_TVALID),
    .ik1_host_data_output_V_V_TREADY(ik1_host_data_output_V_V_TREADY),
    .ik1_host_data_output_V_V_TDATA(ik1_host_data_output_V_V_TDATA),
    .ik1_net_metadata_input_V_V_TVALID(ik1_net_metadata_input_V_V_TVALID),
    .ik1_net_metadata_input_V_V_TREADY(ik1_net_metadata_input_V_V_TREADY),
    .ik1_net_metadata_input_V_V_TDATA(ik1_net_metadata_input_V_V_TDATA),
    .ik1_net_data_input_V_V_TVALID(ik1_net_data_input_V_V_TVALID),
    .ik1_net_data_input_V_V_TREADY(ik1_net_data_input_V_V_TREADY),
    .ik1_net_data_input_V_V_TDATA(ik1_net_data_input_V_V_TDATA),
    .ik1_net_action_V_V_TVALID(ik1_net_action_V_V_TVALID),
    .ik1_net_action_V_V_TREADY(ik1_net_action_V_V_TREADY),
    .ik1_net_action_V_V_TDATA(ik1_net_action_V_V_TDATA),
    .ik1_net_metadata_output_V_V_TVALID(ik1_net_metadata_output_V_V_TVALID),
    .ik1_net_metadata_output_V_V_TREADY(ik1_net_metadata_output_V_V_TREADY),
    .ik1_net_metadata_output_V_V_TDATA(ik1_net_metadata_output_V_V_TDATA),
    .ik1_net_data_output_V_V_TVALID(ik1_net_data_output_V_V_TVALID),
    .ik1_net_data_output_V_V_TREADY(ik1_net_data_output_V_V_TREADY),
    .ik1_net_data_output_V_V_TDATA(ik1_net_data_output_V_V_TDATA)
// end of nica wiring borrowed from example_hls.v
`endif

   );
  

///////////////////////////////////////////////////////////////////////////////
// ikernel IP:
///////////////////////////////////////////////////////////////////////////////

`define ADD_TOP(name) ``name``_``name``_top

`ADD_TOP(`IKERNEL0) #(
    .C_S_AXI_AXILITES_ADDR_WIDTH(32),
    .C_S_AXI_AXILITES_DATA_WIDTH(32)
) ikernel0 (

    .s_axi_AXILiteS_AWREADY(ik0_AXILiteS_AWREADY),
    .s_axi_AXILiteS_AWVALID(ik0_AXILiteS_AWVALID),
    .s_axi_AXILiteS_AWADDR(waddr2ikernels),
    // .axi4lite_aw_prot(mlx2sbu_axi4lite_aw_prot),
    
    .s_axi_AXILiteS_WVALID(mlx2sbu_axi4lite_w_vld),
    .s_axi_AXILiteS_WREADY(ik0_AXILiteS_WREADY),
    .s_axi_AXILiteS_WDATA(mlx2sbu_axi4lite_w_data),
    .s_axi_AXILiteS_WSTRB(mlx2sbu_axi4lite_w_strobe),
    
    .s_axi_AXILiteS_ARVALID(ik0_AXILiteS_ARVALID),
    .s_axi_AXILiteS_ARREADY(ik0_AXILiteS_ARREADY),
    .s_axi_AXILiteS_ARADDR(raddr2ikernels),
    // .axi4lite_ar_prot(mlx2sbu_axi4lite_ar_prot),
    
    .s_axi_AXILiteS_BVALID(ik0_AXILiteS_BVALID),
    .s_axi_AXILiteS_BREADY(mlx2sbu_axi4lite_b_rdy),
    .s_axi_AXILiteS_BRESP(ik0_AXILiteS_BRESP),
    
    .s_axi_AXILiteS_RVALID(ik0_AXILiteS_RVALID),
    .s_axi_AXILiteS_RREADY(mlx2sbu_axi4lite_r_rdy),
    .s_axi_AXILiteS_RDATA(ik0_AXILiteS_RDATA),
    .s_axi_AXILiteS_RRESP(ik0_AXILiteS_RRESP),

    .ap_clk(mlx2sbu_clk),
    .ap_rst_n(~mlx2sbu_reset),

    .ik_host_metadata_output_V_V_TDATA(ik0_host_metadata_output_V_V_TDATA),
    .ik_host_metadata_output_V_V_TVALID(ik0_host_metadata_output_V_V_TVALID),
    .ik_host_metadata_output_V_V_TREADY(ik0_host_metadata_output_V_V_TREADY),

    .ik_host_metadata_input_V_V_TDATA(ik0_host_metadata_input_V_V_TDATA),
    .ik_host_metadata_input_V_V_TVALID(ik0_host_metadata_input_V_V_TVALID),
    .ik_host_metadata_input_V_V_TREADY(ik0_host_metadata_input_V_V_TREADY),

    .ik_host_data_output_V_V_TDATA(ik0_host_data_output_V_V_TDATA),
    .ik_host_data_output_V_V_TVALID(ik0_host_data_output_V_V_TVALID),
    .ik_host_data_output_V_V_TREADY(ik0_host_data_output_V_V_TREADY),

    .ik_host_data_input_V_V_TDATA(ik0_host_data_input_V_V_TDATA),
    .ik_host_data_input_V_V_TVALID(ik0_host_data_input_V_V_TVALID),
    .ik_host_data_input_V_V_TREADY(ik0_host_data_input_V_V_TREADY),

    .ik_host_action_V_V_TDATA(ik0_host_action_V_V_TDATA),
    .ik_host_action_V_V_TVALID(ik0_host_action_V_V_TVALID),
    .ik_host_action_V_V_TREADY(ik0_host_action_V_V_TREADY),

    .ik_net_metadata_output_V_V_TDATA(ik0_net_metadata_output_V_V_TDATA),
    .ik_net_metadata_output_V_V_TVALID(ik0_net_metadata_output_V_V_TVALID),
    .ik_net_metadata_output_V_V_TREADY(ik0_net_metadata_output_V_V_TREADY),

    .ik_net_metadata_input_V_V_TDATA(ik0_net_metadata_input_V_V_TDATA),
    .ik_net_metadata_input_V_V_TVALID(ik0_net_metadata_input_V_V_TVALID),
    .ik_net_metadata_input_V_V_TREADY(ik0_net_metadata_input_V_V_TREADY),

    .ik_net_data_output_V_V_TDATA(ik0_net_data_output_V_V_TDATA),
    .ik_net_data_output_V_V_TVALID(ik0_net_data_output_V_V_TVALID),
    .ik_net_data_output_V_V_TREADY(ik0_net_data_output_V_V_TREADY),

    .ik_net_data_input_V_V_TDATA(ik0_net_data_input_V_V_TDATA),
    .ik_net_data_input_V_V_TVALID(ik0_net_data_input_V_V_TVALID),
    .ik_net_data_input_V_V_TREADY(ik0_net_data_input_V_V_TREADY),

    .ik_net_action_V_V_TDATA(ik0_net_action_V_V_TDATA),
    .ik_net_action_V_V_TVALID(ik0_net_action_V_V_TVALID),
    .ik_net_action_V_V_TREADY(ik0_net_action_V_V_TREADY)
);

`ifdef NUM_IKERNELS_GT_1
`ADD_TOP(`IKERNEL1) #(
    .C_S_AXI_AXILITES_ADDR_WIDTH(32),
    .C_S_AXI_AXILITES_DATA_WIDTH(32)
) ikernel1 (

    .s_axi_AXILiteS_AWREADY(ik1_AXILiteS_AWREADY),
    .s_axi_AXILiteS_AWVALID(ik1_AXILiteS_AWVALID),
    .s_axi_AXILiteS_AWADDR(waddr2ikernels),
    // .axi4lite_aw_prot(mlx2sbu_axi4lite_aw_prot),
    
    .s_axi_AXILiteS_WVALID(mlx2sbu_axi4lite_w_vld),
    .s_axi_AXILiteS_WREADY(ik1_AXILiteS_WREADY),
    .s_axi_AXILiteS_WDATA(mlx2sbu_axi4lite_w_data),
    .s_axi_AXILiteS_WSTRB(mlx2sbu_axi4lite_w_strobe),
    
    .s_axi_AXILiteS_ARVALID(ik1_AXILiteS_ARVALID),
    .s_axi_AXILiteS_ARREADY(ik1_AXILiteS_ARREADY),
    .s_axi_AXILiteS_ARADDR(raddr2ikernels),
    // .axi4lite_ar_prot(mlx2sbu_axi4lite_ar_prot),
    
    .s_axi_AXILiteS_BVALID(ik1_AXILiteS_BVALID),
    .s_axi_AXILiteS_BREADY(mlx2sbu_axi4lite_b_rdy),
    .s_axi_AXILiteS_BRESP(ik1_AXILiteS_BRESP),
    
    .s_axi_AXILiteS_RVALID(ik1_AXILiteS_RVALID),
    .s_axi_AXILiteS_RREADY(mlx2sbu_axi4lite_r_rdy),
    .s_axi_AXILiteS_RDATA(ik1_AXILiteS_RDATA),
    .s_axi_AXILiteS_RRESP(ik1_AXILiteS_RRESP),

    .ap_clk(mlx2sbu_clk),
    .ap_rst_n(~mlx2sbu_reset),

    .ik_host_metadata_output_V_V_TDATA(ik1_host_metadata_output_V_V_TDATA),
    .ik_host_metadata_output_V_V_TVALID(ik1_host_metadata_output_V_V_TVALID),
    .ik_host_metadata_output_V_V_TREADY(ik1_host_metadata_output_V_V_TREADY),

    .ik_host_metadata_input_V_V_TDATA(ik1_host_metadata_input_V_V_TDATA),
    .ik_host_metadata_input_V_V_TVALID(ik1_host_metadata_input_V_V_TVALID),
    .ik_host_metadata_input_V_V_TREADY(ik1_host_metadata_input_V_V_TREADY),

    .ik_host_data_output_V_V_TDATA(ik1_host_data_output_V_V_TDATA),
    .ik_host_data_output_V_V_TVALID(ik1_host_data_output_V_V_TVALID),
    .ik_host_data_output_V_V_TREADY(ik1_host_data_output_V_V_TREADY),

    .ik_host_data_input_V_V_TDATA(ik1_host_data_input_V_V_TDATA),
    .ik_host_data_input_V_V_TVALID(ik1_host_data_input_V_V_TVALID),
    .ik_host_data_input_V_V_TREADY(ik1_host_data_input_V_V_TREADY),

    .ik_host_action_V_V_TDATA(ik1_host_action_V_V_TDATA),
    .ik_host_action_V_V_TVALID(ik1_host_action_V_V_TVALID),
    .ik_host_action_V_V_TREADY(ik1_host_action_V_V_TREADY),

    .ik_net_metadata_output_V_V_TDATA(ik1_net_metadata_output_V_V_TDATA),
    .ik_net_metadata_output_V_V_TVALID(ik1_net_metadata_output_V_V_TVALID),
    .ik_net_metadata_output_V_V_TREADY(ik1_net_metadata_output_V_V_TREADY),

    .ik_net_metadata_input_V_V_TDATA(ik1_net_metadata_input_V_V_TDATA),
    .ik_net_metadata_input_V_V_TVALID(ik1_net_metadata_input_V_V_TVALID),
    .ik_net_metadata_input_V_V_TREADY(ik1_net_metadata_input_V_V_TREADY),

    .ik_net_data_output_V_V_TDATA(ik1_net_data_output_V_V_TDATA),
    .ik_net_data_output_V_V_TVALID(ik1_net_data_output_V_V_TVALID),
    .ik_net_data_output_V_V_TREADY(ik1_net_data_output_V_V_TREADY),

    .ik_net_data_input_V_V_TDATA(ik1_net_data_input_V_V_TDATA),
    .ik_net_data_input_V_V_TVALID(ik1_net_data_input_V_V_TVALID),
    .ik_net_data_input_V_V_TREADY(ik1_net_data_input_V_V_TREADY),

    .ik_net_action_V_V_TDATA(ik1_net_action_V_V_TDATA),
    .ik_net_action_V_V_TVALID(ik1_net_action_V_V_TVALID),
    .ik_net_action_V_V_TREADY(ik1_net_action_V_V_TREADY)
);
`endif

// Put next ikernel here... Till then, we need to clear axilite signals that supposed to be driven by the ikernel
  assign ik2_AXILiteS_AWREADY = 1'b0;
  assign ik2_AXILiteS_WREADY = 1'b0;
  assign ik2_AXILiteS_BVALID = 1'b0;
  assign ik2_AXILiteS_BRESP = 2'b0;
  assign ik2_AXILiteS_ARREADY = 1'b0;
  assign ik2_AXILiteS_RVALID = 1'b0;
  assign ik2_AXILiteS_RDATA = 32'b0;
  assign ik2_AXILiteS_RRESP = 2'b0;
// end of ikernel axilite signals  


   assign sbu2mlx_axi4mm_aw_id = 3'd0;
   assign sbu2mlx_axi4mm_ar_id = 3'd0;

   /* TODO move to a module */
   reg [0:20] watchdog_counter;
   always @(posedge mlx2sbu_clk)
   if (mlx2sbu_reset) begin
     watchdog_counter <= 21'b0;
   end else begin
        watchdog_counter <= watchdog_counter + 1;
   end
   assign sbu2mlx_watchdog = watchdog_counter[0];

   assign sbu2mlx_leds_on =8'd23;
   assign sbu2mlx_leds_blink = 8'd0;

   wire        unconnected_sbu2mlx_axi4mm           = 
	       sbu2mlx_axi4mm_aw_user | 
               sbu2mlx_axi4mm_w_rdy |
               sbu2mlx_axi4mm_aw_rdy | 
               sbu2mlx_axi4mm_aw_lock |
               sbu2mlx_axi4mm_r_vld |
               sbu2mlx_axi4mm_r_last
               ;

   /************************************************************/
   wire        unconnect_axi = |{sbu2mlx_axi4mm_ar_rdy,sbu2mlx_axi4mm_r_data,sbu2mlx_axi4mm_r_resp,sbu2mlx_axi4mm_b_vld,sbu2mlx_axi4mm_b_resp,sbu2mlx_axi4mm_b_id,sbu2mlx_axi4mm_r_id};


   assign sbu2mlx_axi4mm_w_data = 512'd0; 
   assign sbu2mlx_axi4mm_w_strobe = 64'd0;
   assign sbu2mlx_axi4mm_w_last = 1'b0;
   assign sbu2mlx_axi4mm_w_vld = 1'd0;

   assign sbu2mlx_axi4mm_aw_vld = 1'b0;       
   assign sbu2mlx_axi4mm_aw_addr = 64'd0;
   assign sbu2mlx_axi4mm_aw_len = 8'd0;
   assign sbu2mlx_axi4mm_aw_size = 3'd0;
   assign sbu2mlx_axi4mm_aw_burst = 2'd0;
   assign sbu2mlx_axi4mm_aw_cache = 4'd0;  
   assign sbu2mlx_axi4mm_aw_prot = 3'd0; 
   assign sbu2mlx_axi4mm_aw_qos = 4'd0;
   assign sbu2mlx_axi4mm_aw_region = 4'd0;
   assign sbu2mlx_axi4mm_aw_user = 1'd0;
   
	      
   assign sbu2mlx_axi4mm_ar_vld    = 1'b0;   
   assign sbu2mlx_axi4mm_ar_addr   = 64'd0;
   assign sbu2mlx_axi4mm_ar_len    = 8'd0;
   assign sbu2mlx_axi4mm_ar_size   = 3'd0;
   assign sbu2mlx_axi4mm_ar_burst  = 2'd0;
   assign sbu2mlx_axi4mm_ar_lock   = 1'b0;
   assign sbu2mlx_axi4mm_ar_cache  = 4'd0;
   assign sbu2mlx_axi4mm_ar_prot   = 3'd0;
   assign sbu2mlx_axi4mm_ar_qos    = 4'd0;
   assign sbu2mlx_axi4mm_ar_region = 4'd0;
        
   assign sbu2mlx_axi4mm_r_rdy = 1'b0;
   assign sbu2mlx_axi4mm_b_rdy = 1'd0;



// AXI4-Lite crossbar: single master ==> multiple slaves
//
// AXIlite write:

// Actual write addres to nica & ikernels
  assign waddr2ikernels = {19'b0,
                           mlx2sbu_axi4lite_aw_addr[15] | mlx2sbu_axi4lite_aw_addr[14] | mlx2sbu_axi4lite_aw_addr[13] | mlx2sbu_axi4lite_aw_addr[12],
                           mlx2sbu_axi4lite_aw_addr[11:0]};
  assign waddr = mlx2sbu_axi4lite_aw_addr[AXILITE_ADDR_WIDTH-1:0];
  assign axilite_write_none = !axilite_write_nica & !axilite_write_ik0 & !axilite_write_ik1 & !axilite_write_ik2 & !axilite_write_sigmon & !axilite_write_dummy;
  assign mlx2sbu_axi4lite_aw_rdy = axilite_write_nica & nica_AXILiteS_AWREADY |
				    axilite_write_ik0  &  ik0_AXILiteS_AWREADY |
				    axilite_write_ik1  &  ik1_AXILiteS_AWREADY |
				    axilite_write_ik2  &  ik2_AXILiteS_AWREADY |
				    axilite_write_sigmon  &  sigmon_AXILiteS_AWREADY |
				    axilite_write_dummy  &  dummy_AXILiteS_AWREADY;

  assign  mlx2sbu_axi4lite_w_rdy = (axilite_write_nica) & nica_AXILiteS_WREADY | 
			       	   (axilite_write_ik0) & ik0_AXILiteS_WREADY   |
			       	   (axilite_write_ik1) & ik1_AXILiteS_WREADY   |
			       	   (axilite_write_ik2) & ik2_AXILiteS_WREADY   |
			       	   (axilite_write_sigmon) & sigmon_AXILiteS_WREADY   |
			       	   (axilite_write_dummy) & dummy_AXILiteS_WREADY;

  assign  mlx2sbu_axi4lite_b_vld = (axilite_write_nica) & nica_AXILiteS_BVALID | 
			       	   (axilite_write_ik0) & ik0_AXILiteS_BVALID   |
			       	   (axilite_write_ik1) & ik1_AXILiteS_BVALID   |
			       	   (axilite_write_ik2) & ik2_AXILiteS_BVALID   |
			       	   (axilite_write_sigmon) & sigmon_AXILiteS_BVALID   |
			       	   (axilite_write_dummy) & dummy_AXILiteS_BVALID;

  assign  mlx2sbu_axi4lite_b_resp = (axilite_write_dummy) ? dummy_AXILiteS_BRESP :
                                    (axilite_write_nica) ? nica_AXILiteS_BRESP : 
			       	    (axilite_write_ik0) ? ik0_AXILiteS_BRESP   :
			       	    (axilite_write_ik1) ? ik1_AXILiteS_BRESP   :
			       	    (axilite_write_ik2) ? ik2_AXILiteS_BRESP   :
			       	    (axilite_write_sigmon) ? sigmon_AXILiteS_BRESP   : 2'b0;

//AXIlite read:
  assign raddr2ikernels = {19'b0,
                           mlx2sbu_axi4lite_ar_addr[15] | mlx2sbu_axi4lite_ar_addr[14] | mlx2sbu_axi4lite_ar_addr[13] | mlx2sbu_axi4lite_ar_addr[12],
                           mlx2sbu_axi4lite_ar_addr[11:0]};
  assign raddr = mlx2sbu_axi4lite_ar_addr[AXILITE_ADDR_WIDTH-1:0];
  assign axilite_read_none = !axilite_read_nica & !axilite_read_ik0 & !axilite_read_ik1 & !axilite_read_ik2 & !axilite_read_sigmon & !axilite_read_dummy;
  assign mlx2sbu_axi4lite_ar_rdy = axilite_read_nica & nica_AXILiteS_ARREADY |
				    axilite_read_ik0  &  ik0_AXILiteS_ARREADY |
				    axilite_read_ik1  &  ik1_AXILiteS_ARREADY |
				    axilite_read_ik2  &  ik2_AXILiteS_ARREADY |
				    axilite_read_sigmon  &  sigmon_AXILiteS_ARREADY |
                                    axilite_read_dummy & dummy_AXILiteS_ARREADY;

  assign  mlx2sbu_axi4lite_r_vld = (axilite_read_nica) & nica_AXILiteS_RVALID | 
			       	   (axilite_read_ik0) & ik0_AXILiteS_RVALID   |
			       	   (axilite_read_ik1) & ik1_AXILiteS_RVALID   |
			       	   (axilite_read_ik2) & ik2_AXILiteS_RVALID   |
			       	   (axilite_read_sigmon) & sigmon_AXILiteS_RVALID   |
			       	   (axilite_read_dummy) & dummy_AXILiteS_RVALID;

  assign  mlx2sbu_axi4lite_r_data = (axilite_read_dummy) ? dummy_AXILiteS_RDATA :
                                    (axilite_read_nica) ? nica_AXILiteS_RDATA : 
			       	    (axilite_read_ik0) ? ik0_AXILiteS_RDATA   :
			       	    (axilite_read_ik1) ? ik1_AXILiteS_RDATA   :
			       	    (axilite_read_ik2) ? ik2_AXILiteS_RDATA   :
			       	    (axilite_read_sigmon) ? sigmon_AXILiteS_RDATA   : 32'b0;

  assign  mlx2sbu_axi4lite_r_resp = (axilite_read_dummy) ? dummy_AXILiteS_RRESP :
                                    (axilite_read_nica) ? nica_AXILiteS_RRESP : 
			       	    (axilite_read_ik0) ? ik0_AXILiteS_RRESP   :
			       	    (axilite_read_ik1) ? ik1_AXILiteS_RRESP   :
			       	    (axilite_read_ik2) ? ik2_AXILiteS_RRESP   :
			       	    (axilite_read_sigmon) ? sigmon_AXILiteS_RRESP   : 2'b0;
  


// Check which slave IO space is being addressed
  always @(posedge mlx2sbu_clk) begin
    if (mlx2sbu_reset) begin
      nica_AXILiteS_AWVALID <= 1'b0;
      ik0_AXILiteS_AWVALID <= 1'b0;
      ik1_AXILiteS_AWVALID <= 1'b0;
      ik2_AXILiteS_AWVALID <= 1'b0;
      sigmon_AXILiteS_AWVALID <= 1'b0;
      dummy_AXILiteS_AWVALID <= 1'b0;
      nica_AXILiteS_ARVALID <= 1'b0;
      ik0_AXILiteS_ARVALID <= 1'b0;
      ik1_AXILiteS_ARVALID <= 1'b0;
      ik2_AXILiteS_ARVALID <= 1'b0;
      sigmon_AXILiteS_ARVALID <= 1'b0;
      dummy_AXILiteS_ARVALID <= 1'b0;
      axilite_write_nica <= 1'b0;
      axilite_write_ik0 <= 1'b0;
      axilite_write_ik1 <= 1'b0;
      axilite_write_ik2 <= 1'b0;
      axilite_write_sigmon <= 1'b0;
      axilite_read_nica <= 1'b0;
      axilite_read_ik0 <= 1'b0;
      axilite_read_ik1 <= 1'b0;
      axilite_read_ik2 <= 1'b0;
      axilite_read_sigmon <= 1'b0;
      axilite_read_dummy <= 1'b0;
      axilite_write_dummy <= 1'b0;
      axilite_read_timeout <= 32'b0;
      axilite_write_timeout <= 32'b0;
      

// Setting a unique NICA ID, readable from AXI-lite address 0x900020.
      sbu2mlx_ieee_vendor_id_r <= 24'hace2ce;
    end
    else begin       

// Check & register the accessed AXI-lite slave:
// nica_write
      if (mlx2sbu_axi4lite_aw_vld & (waddr >= AXILITE_BASE0 && waddr < AXILITE_BASE1) & axilite_write_none) begin
	axilite_write_nica <= 1'b1;
	nica_AXILiteS_AWVALID <= 1'b1;
      end
      if (nica_AXILiteS_AWVALID & axilite_write_nica & nica_AXILiteS_AWREADY)
	nica_AXILiteS_AWVALID <= 1'b0;

// ik0_write
      if (mlx2sbu_axi4lite_aw_vld & (waddr >= AXILITE_BASE1 && waddr < AXILITE_BASE2) & axilite_write_none) begin
	axilite_write_ik0 <= 1'b1;
	ik0_AXILiteS_AWVALID <= 1'b1;
      end
      if (ik0_AXILiteS_AWVALID & axilite_write_ik0 & ik0_AXILiteS_AWREADY)
	ik0_AXILiteS_AWVALID <= 1'b0;

// ik1_write
      if (mlx2sbu_axi4lite_aw_vld & (waddr >= AXILITE_BASE2 && waddr < AXILITE_BASE3) & axilite_write_none) begin
	axilite_write_ik1 <= 1'b1;
	ik1_AXILiteS_AWVALID <= 1'b1;
      end
      if (ik1_AXILiteS_AWVALID & axilite_write_ik1 & ik1_AXILiteS_AWREADY)
	ik1_AXILiteS_AWVALID <= 1'b0;

// ik2_write
      if (mlx2sbu_axi4lite_aw_vld & (waddr >= AXILITE_BASE3 && waddr < AXILITE_BASE4) & axilite_write_none) begin
	axilite_write_ik2 <= 1'b1;
	ik2_AXILiteS_AWVALID <= 1'b1;
      end
      if (ik2_AXILiteS_AWVALID & axilite_write_ik2 & ik2_AXILiteS_AWREADY)
	ik2_AXILiteS_AWVALID <= 1'b0;
      
// sigmon_write
      if (mlx2sbu_axi4lite_aw_vld & (waddr >= AXILITE_BASE8 && waddr < AXILITE_BASE9) & axilite_write_none) begin
	axilite_write_sigmon <= 1'b1;
	sigmon_AXILiteS_AWVALID <= 1'b1;
      end
      if (sigmon_AXILiteS_AWVALID & axilite_write_sigmon & sigmon_AXILiteS_AWREADY)
	sigmon_AXILiteS_AWVALID <= 1'b0;
      
// dummy_write
      if (mlx2sbu_axi4lite_aw_vld & (axilite_write_timeout >= AXILITE_TIMEOUT)) begin
	axilite_write_dummy <= 1'b1;
	dummy_AXILiteS_AWVALID <= 1'b1;
      end
      if (dummy_AXILiteS_AWVALID & axilite_write_dummy & dummy_AXILiteS_AWREADY)
	dummy_AXILiteS_AWVALID <= 1'b0;

      
// nica_read
      if (mlx2sbu_axi4lite_ar_vld & (raddr >= AXILITE_BASE0 && raddr < AXILITE_BASE1) & axilite_read_none) begin
	axilite_read_nica <= 1'b1;
	nica_AXILiteS_ARVALID <= 1'b1;
      end
      if (nica_AXILiteS_ARVALID & axilite_read_nica & nica_AXILiteS_ARREADY)
	nica_AXILiteS_ARVALID <= 1'b0;

// ik0_read
      if (mlx2sbu_axi4lite_ar_vld & (raddr >= AXILITE_BASE1 && raddr < AXILITE_BASE2) & axilite_read_none) begin
	axilite_read_ik0 <= 1'b1;
	ik0_AXILiteS_ARVALID <= 1'b1;
      end
      if (ik0_AXILiteS_ARVALID & axilite_read_ik0 & ik0_AXILiteS_ARREADY)
	ik0_AXILiteS_ARVALID <= 1'b0;

// ik1_read
      if (mlx2sbu_axi4lite_ar_vld & (raddr >= AXILITE_BASE2 && raddr < AXILITE_BASE3) & axilite_read_none) begin
	axilite_read_ik1 <= 1'b1;
	ik1_AXILiteS_ARVALID <= 1'b1;
      end
      if (ik1_AXILiteS_ARVALID & axilite_read_ik1 & ik1_AXILiteS_ARREADY)
	ik1_AXILiteS_ARVALID <= 1'b0;

// ik2_read
      if (mlx2sbu_axi4lite_ar_vld & (raddr >= AXILITE_BASE3 && raddr < AXILITE_BASE4) & axilite_read_none) begin
	axilite_read_ik2 <= 1'b1;
	ik2_AXILiteS_ARVALID <= 1'b1;
      end
      if (ik2_AXILiteS_ARVALID & axilite_read_ik2 & ik2_AXILiteS_ARREADY)
	ik2_AXILiteS_ARVALID <= 1'b0;

// sigmon_read
      if (mlx2sbu_axi4lite_ar_vld & (raddr >= AXILITE_BASE8 && raddr < AXILITE_BASE9) & axilite_read_none) begin
	axilite_read_sigmon <= 1'b1;
	sigmon_AXILiteS_ARVALID <= 1'b1;
      end
      if (sigmon_AXILiteS_ARVALID & axilite_read_sigmon & sigmon_AXILiteS_ARREADY)
	sigmon_AXILiteS_ARVALID <= 1'b0;

// dummy_read
      if (mlx2sbu_axi4lite_ar_vld & (axilite_read_timeout >= AXILITE_TIMEOUT)) begin
	axilite_read_dummy <= 1'b1;
	dummy_AXILiteS_ARVALID <= 1'b1;
      end
      if (dummy_AXILiteS_ARVALID & axilite_read_dummy & dummy_AXILiteS_ARREADY)
	dummy_AXILiteS_ARVALID <= 1'b0;


// AXIlite timeout counters
// As long as ar_vld, aw_vld, the counters are ticking.
// Will be cleared once a read/write operation ended normally.
      if (mlx2sbu_axi4lite_ar_vld) begin
	axilite_read_timeout <= axilite_read_timeout +1;
      end
      if (mlx2sbu_axi4lite_aw_vld) begin
	axilite_write_timeout <= axilite_write_timeout +1;
      end
      

// Clear all write_select signals if a write to either of the slaves is on going and BVALID & BREADY.
// Since all write_select signals are mutex, it does not matter which slave drove the BVALID.
	if (!axilite_write_none & mlx2sbu_axi4lite_b_vld & mlx2sbu_axi4lite_b_rdy) begin
	  axilite_write_nica <= 1'b0;
	  axilite_write_ik0 <= 1'b0;
	  axilite_write_ik1 <= 1'b0;
	  axilite_write_ik2 <= 1'b0;
	  axilite_write_sigmon <= 1'b0;
	  axilite_write_dummy <= 1'b0;
	  axilite_write_timeout <= 32'b0;;
	end

// Clear all read_select signals if a read from either of the slaves is on going and RVALID & RREADY.
// Since all read_select signals are mutex, it does not matter which slave drove the RVALID.
	if (!axilite_read_none & mlx2sbu_axi4lite_r_vld & mlx2sbu_axi4lite_r_rdy) begin
	  axilite_read_nica <= 1'b0;
	  axilite_read_ik0 <= 1'b0;
	  axilite_read_ik1 <= 1'b0;
	  axilite_read_ik2 <= 1'b0;
	  axilite_read_sigmon <= 1'b0;
	  axilite_read_dummy <= 1'b0;
	  axilite_read_timeout <= 32'b0;;
	end
      
    end
  end


  // 64 deep store & forward fifos.
  // For more fifo details, see <netperf-verilog_workarea>/sources/xci/axis_data_fifo_0/axis_data_fifo_0.xci
  axis_data_fifo_0 sbu2cxp_data_fifo (
  .s_axis_aresetn(~mlx2sbu_reset),          // input wire s_axis_aresetn
  .s_axis_aclk(mlx2sbu_clk),                // input wire s_axis_aclk
  .s_axis_tvalid(sbu2cxpfifo_axi4stream_vld),            // input wire s_axis_tvalid
  .s_axis_tready(sbu2cxpfifo_axi4stream_rdy),            // output wire s_axis_tready
  .s_axis_tdata(sbu2cxpfifo_axi4stream_tdata),              // input wire [255 : 0] s_axis_tdata
  .s_axis_tkeep(sbu2cxpfifo_axi4stream_tkeep),              // input wire [31 : 0] s_axis_tkeep
  .s_axis_tlast(sbu2cxpfifo_axi4stream_tlast),              // input wire s_axis_tlast
  .s_axis_tid(sbu2cxpfifo_axi4stream_tid),                  // input wire [2 : 0] s_axis_tid
  .s_axis_tuser(sbu2cxpfifo_axi4stream_tuser),              // input wire [11 : 0] s_axis_tuser
  .m_axis_tvalid(sbu2cxp_m_axis_tvalid),   // output wire m_axis_tvalid
  .m_axis_tready(sbu2cxp_m_axis_tready),   // input wire m_axis_tready
  .m_axis_tdata(sbu2cxp_axi4stream_tdata),  // output wire [255 : 0] m_axis_tdata
  .m_axis_tkeep(sbu2cxp_axi4stream_tkeep),  // output wire [31 : 0] m_axis_tkeep
  .m_axis_tlast(sbu2cxp_axi4stream_tlast),  // output wire m_axis_tlast
  .m_axis_tid(sbu2cxp_axi4stream_tid),      // output wire [2 : 0] m_axis_tid
  .m_axis_tuser(sbu2cxp_axi4stream_tuser),  // output wire [11 : 0] m_axis_tuser
  .axis_data_count(sbu2cxpfifo_data_count),        // output wire [31 : 0] axis_data_count
  .axis_wr_data_count(sbu2cxpfifo_wr_data_count),  // output wire [31 : 0] axis_wr_data_count
  .axis_rd_data_count(sbu2cxpfifo_rd_data_count)   // output wire [31 : 0] axis_rd_data_count
);

  axis_data_fifo_0 sbu2nwp_data_fifo (
  .s_axis_aresetn(~mlx2sbu_reset),          // input wire s_axis_aresetn
  .s_axis_aclk(mlx2sbu_clk),                // input wire s_axis_aclk
  .s_axis_tvalid(sbu2nwpfifo_axi4stream_vld),            // input wire s_axis_tvalid
  .s_axis_tready(sbu2nwpfifo_axi4stream_rdy),            // output wire s_axis_tready
  .s_axis_tdata(sbu2nwpfifo_axi4stream_tdata),              // input wire [255 : 0] s_axis_tdata
  .s_axis_tkeep(sbu2nwpfifo_axi4stream_tkeep),              // input wire [31 : 0] s_axis_tkeep
  .s_axis_tlast(sbu2nwpfifo_axi4stream_tlast),              // input wire s_axis_tlast
  .s_axis_tid(sbu2nwpfifo_axi4stream_tid),                  // input wire [2 : 0] s_axis_tid
  .s_axis_tuser(sbu2nwpfifo_axi4stream_tuser),              // input wire [11 : 0] s_axis_tuser
  .m_axis_tvalid(sbu2nwp_m_axis_tvalid),   // output wire m_axis_tvalid
  .m_axis_tready(sbu2nwp_m_axis_tready),   // input wire m_axis_tready
  .m_axis_tdata(sbu2nwp_axi4stream_tdata),  // output wire [255 : 0] m_axis_tdata
  .m_axis_tkeep(sbu2nwp_axi4stream_tkeep),  // output wire [31 : 0] m_axis_tkeep
  .m_axis_tlast(sbu2nwp_axi4stream_tlast),  // output wire m_axis_tlast
  .m_axis_tid(sbu2nwp_axi4stream_tid),      // output wire [2 : 0] m_axis_tid
  .m_axis_tuser(sbu2nwp_axi4stream_tuser),  // output wire [11 : 0] m_axis_tuser
  .axis_data_count(sbu2nwpfifo_data_count),        // output wire [31 : 0] axis_data_count
  .axis_wr_data_count(sbu2nwpfifo_wr_data_count),  // output wire [31 : 0] axis_wr_data_count
  .axis_rd_data_count(sbu2nwpfifo_rd_data_count)   // output wire [31 : 0] axis_rd_data_count
);

// Mark packets end at each axi-stream interface
// This indication is used to generate next packet start (*_sop) indication
always @(posedge mlx2sbu_clk) begin
  if (mlx2sbu_reset) begin
    sbu2cxp_packet_in_flight <= 1'b0;
    sbu2nwp_packet_in_flight <= 1'b0;
  end
  else begin
// sbu2cxp:
    if (sbu2cxp_axi4stream_vld & sbu2cxp_axi4stream_rdy) begin
       sbu2cxp_packet_in_flight <= ~sbu2cxp_axi4stream_tlast;
    end
// sbu2nwp:
    if (sbu2nwp_axi4stream_vld & sbu2nwp_axi4stream_rdy) begin
       sbu2nwp_packet_in_flight <= ~sbu2nwp_axi4stream_tlast;
    end
  end
end

// TODO separate generated and passthrough packets
wire sbu2nwp_allowed = nwp2sbu_lossless_has_credits | sbu2nwp_packet_in_flight;
wire sbu2cxp_allowed = cxp2sbu_lossless_has_credits | sbu2cxp_packet_in_flight;
assign sbu2nwp_axi4stream_vld = sbu2nwp_m_axis_tvalid & sbu2nwp_allowed;
assign sbu2nwp_m_axis_tready = sbu2nwp_axi4stream_rdy & sbu2nwp_allowed;
assign sbu2cxp_axi4stream_vld = sbu2cxp_m_axis_tvalid & sbu2cxp_allowed;
assign sbu2cxp_m_axis_tready = sbu2cxp_axi4stream_rdy & sbu2cxp_allowed;

// sbu2mlx
assign sbu2mlx_axi4stream_tdata = 256'h0;
assign sbu2mlx_axi4stream_vld = 1'b0;
assign sbu2mlx_axi4stream_tkeep = 32'h0;
assign sbu2mlx_axi4stream_tlast = 1'b0;
assign sbu2mlx_axi4stream_tid = 3'h0;
assign sbu2mlx_axi4stream_tuser = 12'h0;

// mlx2sbu
assign mlx2sbu_axi4stream_rdy = 1'b0;


///////////////////////////////////////////////////////////////////////////////////////
//   
// Dummy axilite slave, to respond in case no other slave responded, to avoid host hang  
// Write operation will write to sink
// Read operation will be responded with 32'hdeadf00d
//
localparam
    WRIDLE                     = 2'd0,
    WRDATA                     = 2'd1,
    WRRESP                     = 2'd2,
    RDIDLE                     = 2'd0,
    RDDATA                     = 2'd1;

  reg [1:0]                    dummy_wstate;
  reg [1:0] 		       dummy_wnext;
  reg [1:0] 		       dummy_rstate;
  reg [1:0] 		       dummy_rnext;
  reg [31:0] 		       dummy_rdata;
  wire 			       dummy_ar_hs;
  
//------------------------Dummy AXI write fsm------------------
assign dummy_AXILiteS_AWREADY = (dummy_wstate == WRIDLE);
assign dummy_AXILiteS_WREADY  = (dummy_wstate == WRDATA);
assign dummy_AXILiteS_BRESP   = 2'b00;  // OKAY
assign dummy_AXILiteS_BVALID  = (dummy_wstate == WRRESP);

// wstate
always @(posedge mlx2sbu_clk) begin
    if (mlx2sbu_reset)
        dummy_wstate <= WRIDLE;
    else
        dummy_wstate <= dummy_wnext;
end

// wnext
always @(*) begin
    case (dummy_wstate)
        WRIDLE:
            if (dummy_AXILiteS_AWVALID)
                dummy_wnext = WRDATA;
            else
                dummy_wnext = WRIDLE;
        WRDATA:
            if (mlx2sbu_axi4lite_w_vld)
                dummy_wnext = WRRESP;
            else
                dummy_wnext = WRDATA;
        WRRESP:
            if (mlx2sbu_axi4lite_b_rdy)
                dummy_wnext = WRIDLE;
            else
                dummy_wnext = WRRESP;
        default:
            dummy_wnext = WRIDLE;
    endcase
end

//------------------------Dummy AXI read fsm-------------------
assign dummy_AXILiteS_ARREADY = (dummy_rstate == RDIDLE);
assign dummy_AXILiteS_RDATA   = dummy_rdata;
assign dummy_AXILiteS_RRESP   = 2'b00;  // OKAY
assign dummy_AXILiteS_RVALID  = (dummy_rstate == RDDATA);
assign dummy_ar_hs   = dummy_AXILiteS_ARVALID & dummy_AXILiteS_ARREADY;

// rstate
always @(posedge mlx2sbu_clk) begin
    if (mlx2sbu_reset)
        dummy_rstate <= RDIDLE;
    else
        dummy_rstate <= dummy_rnext;
end

// rnext
always @(*) begin
    case (dummy_rstate)
        RDIDLE:
            if (dummy_AXILiteS_ARVALID)
                dummy_rnext = RDDATA;
            else
                dummy_rnext = RDIDLE;
        RDDATA:
            if (mlx2sbu_axi4lite_r_rdy & dummy_AXILiteS_RVALID)
                dummy_rnext = RDIDLE;
            else
                dummy_rnext = RDDATA;
        default:
            dummy_rnext = RDIDLE;
    endcase
end

// rdata
always @(posedge mlx2sbu_clk) begin
        if (dummy_ar_hs) begin
            dummy_rdata <= 32'hdeadf00d;
        end
end

  
//////////////////////////////////////////////////////////////////////////////////////////////
//
// Signals monitoring
//
// For sigmon configuration options, see sigmon_top.v
//
// Assign the desired nica event(s) to nica_events[]
// Configure sigmon_ctrl to monitor these events.
  wire [7:0] nica_events = {nica_events7, nica_events6, nica_events5,
                            nica_events4, nica_events3, nica_events2,
                            nica_events1, nica_events0};
  
  
sigmon_top #(
    .AXILITE_ADDR_WIDTH(32),
    .AXILITE_DATA_WIDTH(32)
) sigmon (

    .clk(mlx2sbu_clk),
    .reset(mlx2sbu_reset),
// AXI-Lite interface:
    .axi_AWREADY(sigmon_AXILiteS_AWREADY),
    .axi_AWVALID(sigmon_AXILiteS_AWVALID),
    .axi_AWADDR(waddr2ikernels),
    .axi_WVALID(mlx2sbu_axi4lite_w_vld),
    .axi_WREADY(sigmon_AXILiteS_WREADY),
    .axi_WDATA(mlx2sbu_axi4lite_w_data),
    .axi_WSTRB(mlx2sbu_axi4lite_w_strobe),
    .axi_ARVALID(sigmon_AXILiteS_ARVALID),
    .axi_ARREADY(sigmon_AXILiteS_ARREADY),
    .axi_ARADDR(raddr2ikernels),
    .axi_BVALID(sigmon_AXILiteS_BVALID),
    .axi_BREADY(mlx2sbu_axi4lite_b_rdy),
    .axi_BRESP(sigmon_AXILiteS_BRESP),
    .axi_RVALID(sigmon_AXILiteS_RVALID),
    .axi_RREADY(mlx2sbu_axi4lite_r_rdy),
    .axi_RDATA(sigmon_AXILiteS_RDATA),
    .axi_RRESP(sigmon_AXILiteS_RRESP),

// Monitored signals (can be selected/deselected, enabled/disabled via sigmon_ctrl):
// Notice that the ready & valid signals of each axistream interface are not monitored. Instead these signals are used to generate the trigger for sampling tlast
    .nwp2sbu_rdy(nwp2sbu_axi4stream_rdy),
    .nwp2sbu_vld(nwp2sbu_axi4stream_vld),
    .nwp2sbu_tlast(nwp2sbu_axi4stream_tlast),
    .sbu2nwp_rdy(sbu2nwp_axi4stream_rdy),
    .sbu2nwp_vld(sbu2nwp_axi4stream_vld),
    .sbu2nwp_tlast(sbu2nwp_axi4stream_tlast),
    .cxp2sbu_rdy(cxp2sbu_axi4stream_rdy),
    .cxp2sbu_vld(cxp2sbu_axi4stream_vld),
    .cxp2sbu_tlast(cxp2sbu_axi4stream_tlast),
    .sbu2cxp_rdy(sbu2cxp_axi4stream_rdy),
    .sbu2cxp_vld(sbu2cxp_axi4stream_vld),
    .sbu2cxp_tlast(sbu2cxp_axi4stream_tlast),
    .sbu2cxpfifo_vld(sbu2cxpfifo_axi4stream_vld),
    .sbu2cxpfifo_rdy(sbu2cxpfifo_axi4stream_rdy),
    .sbu2cxpfifo_tlast(sbu2cxpfifo_axi4stream_tlast),
    .sbu2nwpfifo_vld(sbu2nwpfifo_axi4stream_vld),
    .sbu2nwpfifo_rdy(sbu2nwpfifo_axi4stream_rdy),
    .sbu2nwpfifo_tlast(sbu2nwpfifo_axi4stream_tlast),
    .nwp2sbu_credits(nwp2sbu_lossless_has_credits),
    .cxp2sbu_credits(cxp2sbu_lossless_has_credits),

// events originated in nica
    .nica_events(nica_events)

);

endmodule
