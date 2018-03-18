//////////////////////////////////////////////////////////////////////////////////////////////////
//
// Signals monitoring: Events tracking & time_stamping a set of preselected events 
// Gabi Malka, Technion, TCE
// June-2017
//
// An event is a combination signal/signals_logic/function, assictated with its time of occurrence
// All tracked events are stored into a dedicated buffer (fifo), to be later read via AXI-Lite 
//
// A free running clock counter is used to time stamp a desired event.
// The counter will be cleared and then start counting once signal monitoring has been enabled.
//
// Up to 64 different events are supported. Each event is associated with its eventID. See the complete localparam list and its eventID's.
// To select a certain event for sampling, use its eventID as the event selector (see events selection in control registers below).
//
// Two event_counter modules are implemented, for more specific events generation.
// An event counter can be configured to count the occurrences of a specific event, within a specific counting window, then raise a count_event once the counter has reached a preprogrammed count limit.   
// To configure an event_counter, there are three inputs to define:
// 1. count_enable - this input will assert the internal count enable, from which the counter will start counting.
// 2. count_event - this input is the event to be counted. Whenever it is high (and the count_enable is high) the counter is counting.
// 3. count_limit - Tells the event_counter to raise a flag once its count reached the limit
// See the events list below for the specific events originated in the event_counters
//
//
// To facilitate concurrent sampling of multiple signals/events, which may occur at the same time, there are 8 sampling blocks.
// All 8 sampling blocks work independently. 
// Each sampling block can sample up to two different events. A sampled event is stored into a local fifo (1K x 32b)
// Each sampled event is selectable from the set of events mentioned above
// Note: When selecting two events to the same sampler, select two events which are time-orthogonal, such that won't occur at the same time
//
// Time stamping: Once a preselected event has been encountered, it is written to the local fifo, associated with its time stamp.
// A sample event entry, added to local fifo (1 event oer each fifo entry):
// 31...24 23.................0
// <eventID> <time_counter[23:0]>
//
// The 8 local fifos are then read and stored into a common, larger fifo, called sigmon_fifo. 
// Two sigmon fifo sizes are supported (in case of FPGA resoures problem): 128K x 32b and 64K x 32b,  selected by the verilog FIFO_128K parameter (see inside sigmon_top module).
// The default implemented fifo size is 128K x 32b.
//
// A dedicated state_machine constantly scans the 8 local fifos, and transfers the local fifos contents to the sigmon_fifo.
// To optimize the local fifos preemption (to minimize the chance of local fifos full and samples loss), the SM will scan & visit only the non empty fifos. 
//
// Finally, at the end of the signal monitoring session, the host may read the accumulated samples in sigmon_fifo via AXI-Lite .
//
//
// Verilog modification:
// All the signal monitoring logic is implemented in a single verilog module, named sigmon_top.
// sigmon_top is then instanciated inside the nica top level wrapper, ku060_all_exp_hls_wrapper.v
// The axi-lite crossbar inside the top level wrapper was also enhanced, to support the 'new' axi-lite slave
//
// sigmon_top axi-lite interface is attached to the nica wrapper, just like any other ikernel.
// sigmon_top axi-lite address space: h8000..h8fff.
// Inside sigmon_top, only the lease 13 axi-lite address bits are decoded.
//
// Non implemented addresses within the sigmon_top axi-lite address space will behave similarly as with other ikernels:

// Reading from a non existent register will return hdeadf00d as the read data.
// Writing a non existent register will write to sink.
// 
//
//
//========================================================================================================
// Confoguration registers:
//
// A set of contrl registers, written via AXI-Lite, controls the various aspects of signals monitoring:
// Control registers definition:
//
// sigmon_ctrl1:  signal_monitoring_enable, trigger definition
// AXI-Lite address: 'h8000
//    sigmon_ctrl1[11:0]   - Trigger position along the sampling window depth (sliding sampling window) 
//                           Resolution: 32 fifo entries
//                           To position the trigger 32 entries from fifo start, set sigmon_ctrl1[11:0] = 1
//                           Supported values: 0..128k.
//                           Default trigger position = 0: Sampling window begins after trigger occurrence
//    sigmon_ctrl1[15:12]  - Reserved  
//    sigmon_ctrl1[23:16]  - Trigger source. Select either of the input events/sampled signals
//                           Default: 0x3f, selecting SIGMON_ENABLED event (start monitoring immediately after enabling sigmon)
//    sigmon_ctrl1[30:24]  - Reserved  
//    sigmon_ctrl1[31]     - sigmon enable. Enables signals monitoring
//                           Upon assertion, the sigmon_fifo and free running counter are cleared.
//                           Note: Following a signal monitoring session, the sigmon fifo must be read before reasserting sigmon_ctrl[31], or otherwise, its contents will be lost 
//
// sigmon_ctrl2:   Selecting which signals will be monitored by event_mon0 & event_mon1 & event_mon2:
// AXI-Lite address: 'h8010
//    sigmon_ctrl2[7:0]    - event_mon0/event1 input.  Default setting: tbd
//    sigmon_ctrl2[15:8]   - event_mon0/event2 input.  Default setting: tbd
//    sigmon_ctrl2[23:16]  - event_mon1/event1 input.  Default setting: tbd
//    sigmon_ctrl2[31:24]  - event_mon1/event2 input.  Default setting: tbd.
//
// sigmon_ctrl3:
// AXI-Lite address: 'h8014
//    sigmon_ctrl3[7:0]    - event_mon2/event1 input.  Default setting: tbd
//    sigmon_ctrl3[15:8]   - event_mon2/event2 input.  Default setting: tbd
//    sigmon_ctrl3[23:16]  - event_mon3/event1 input.  Default setting: tbd
//    sigmon_ctrl3[31:24]  - event_mon3/event2 input.  Default setting: tbd.
//
// sigmon_ctrl4:
// AXI-Lite address: 'h8018
//    sigmon_ctrl4[7:0]    - event_mon4/event1 input.  Default setting: tbd
//    sigmon_ctrl4[15:8]   - event_mon4/event2 input.  Default setting: tbd
//    sigmon_ctrl4[23:16]  - event_mon5/event1 input.  Default setting: tbd
//    sigmon_ctrl4[31:24]  - event_mon5/event2 input.  Default setting: tbd.
//
// sigmon_ctrl5:
// AXI-Lite address: 'h801c
//    sigmon_ctrl5[7:0]    - event_mon6/event1 input.  Default setting: tbd
//    sigmon_ctrl5[15:8]   - event_mon6/event2 input.  Default setting: tbd
//    sigmon_ctrl5[23:16]  - event_mon7/event1 input.  Default setting: tbd
//    sigmon_ctrl5[31:24]  - event_mon7/event2 input.  Default setting: tbd.
//
// count events
// sigmon_ctrl6:
// AXI-Lite address: 'h8020
//    sigmon_ctrl6[7:0]    - count0/enable input.  Default setting: tbd
//    sigmon_ctrl6[15:8]   - count0/event input.  Default setting: tbd
//    sigmon_ctrl6[23:16]  - count1/enable input.  Default setting: tbd
//    sigmon_ctrl6[31:24]  - count1/event input.  Default setting: tbd.
//
// sigmon_ctrl7[31:0]: event_count0 count limit
// AXI-Lite address: 'h8024
//
// sigmon_ctrl8[31:0]: event_count1 count limit
// AXI-Lite address: 'h8028
//
// sigmon_status[31:0]:
// AXI-Lite address: 'h8004
//    sigmon_status[17:0]  - sigmon_fifo data count
//    sigmon_status[19:18] - reserved, read as zeros
//    sigmon_status[20]    - sigmon_fifo output valid, indicating non empty fifo
//    sigmon_status[21]    - the preprogrammed trigger has occurred
//    sigmon_status[23:22] - reserved, read as zeros
//    sigmon_status[31:24] - Latest events samples have lost, due to events fifos full.
//                           This indication mean that latest samples of some event were lost due to sigmon_fifo & event_fifo are both full.
//                           Notice that in such cases the sigmon_fifo & event_fifos contents are still valid. It means that the implemented fifos depth is not deep enough.
//                           Yet, if you are interested to see those lost samples, you may:
//                           1. delay the trigger source (sigmon_ctrl1[23:16]) by selecting another/later event.
//                              If you can't select a later event, you can still delay the existing trigger source by a specific time delay, by using either of the event_counters
//                              See the Sample Monitoring Session below, to learn how to.
//                           2. move the trigger position towards the bottom (exit) of the sigmon_fifo (lower values at sigmon_ctrl1[11:0])
//                           3. If the samples loss happened with the 64Kx32b sigmon_fifo, consider rebuilding the image with the 128Kx32b fifo. for how to, look for the FIFO_128K knob.
//
//
// Implemented monitored signals/events:
//
// End of a valid packet: tlast & valid & ready at either of the axi-stream interfaces
// eventID               Description/logic functioin
// ===================   ==================================================================
// SBU2CXPFIFO_EOP       sbu2cxpfifo_tlast & sbu2cxpfifo_vld & sbu2cxpfifo_rdy
// SBU2CXP_EOP           sbu2cxp_tlast & sbu2cxp_vld & sbu2cxp_rdy
// CXP2SBU_EOP           cxp2sbu_tlast & cxp2sbu_vld & cxp2sbu_rdy
// SBU2NWPFIFO_EOP       sbu2nwpfifo_tlast & sbu2nwpfifo_vld & sbu2nwpfifo_rdy
// SBU2NWP_EOP           sbu2nwp_tlast & sbu2nwp_vld & sbu2nwp_rdy
// NWP2SBU_EOP           nwp2sbu_tlast & nwp2sbu_vld & nwp2sbu_rdy
//
//
// Start of a valid packet: valid & ready following tlast_dropped:
// eventID               Description/logic functioin
// ===================   ==================================================================
// SBU2CXPFIFO_SOP       sbu2cxpfifo_sop & sbu2cxpfifo_vld & sbu2cxpfifo_rdy
// SBU2CXP_SOP           sbu2cxp_sop & sbu2cxp_vld & sbu2cxp_rdy
// CXP2SBU_SOP           cxp2sbu_sop & cxp2sbu_vld & cxp2sbu_rdy
// SBU2NWPFIFO_SOP       sbu2nwpfifo_sop & sbu2nwpfifo_vld & sbu2nwpfifo_rdy
// SBU2NWP_SOP           sbu2nwp_sop & sbu2nwp_vld & sbu2nwp_rdy
// NWP2SBU_SOP           nwp2sbu_sop & nwp2sbu_vld & nwp2sbu_rdy
//
//
// lossless credits assertion & deassertion on both nwp2sbu and cxp2sbu interfaces 
// eventID               Description/logic functioin
// ===================   ==================================================================
// NWP2SBU_CREDITS_ON    nwp2sbu_credits_asserted
// NWP2SBU_CREDITS_OFF   nwp2sbu_credits_deasserted
// CXP2SBU_CREDITS_ON    cxp2sbu_credits_asserted
// CXP2SBU_CREDITS_OFF   cxp2sbu_credits_deasserted
//
//
// Signals between nica and ikernels: A place holder for 8 signals/events. 
// sigmon_top module already implements 8 dedicated inputs: nica_events[7:0]
// Currently, those inputs are wired to 8'h00 (see under ku060_all_exp_hls_wrapper.v).
// Once available in nica, use nica_events[7:0] to wire the desired event/events from nica to sigmon_top
// nica events are associated with the following eventIDs. Use these IDs to choose a specific nica event for further sampling/monitoring:
// eventID               Description/logic functioin
// ===================   ==================================================================
// LOCAL_EVENT0          nica event0 (tbd)
// LOCAL_EVENT1          nica event1 (tbd)
// LOCAL_EVENT2          nica event2 (tbd)
// LOCAL_EVENT3          nica event3 (tbd)
// LOCAL_EVENT4          nica event4 (tbd)
// LOCAL_EVENT5          nica event5 (tbd)
// LOCAL_EVENT6          nica event6 (tbd)
// LOCAL_EVENT7          nica event7 (tbd)
//
//
// The event_counter modules generate the following events, Use these IDs to choose a specific counter event for further sampling/monitoring:
// eventID               Description/logic functioin
// =======               ==================================================================
// LOCAL_EVENT0          event_count0 has reached its count limit
// LOCAL_EVENT1          event_count1 has reached its count limit
// LOCAL_EVENT2          not implemented
// LOCAL_EVENT3          not implemented
// LOCAL_EVENT4          not implemented
// LOCAL_EVENT5          not implemented
// LOCAL_EVENT6          not implemented
// LOCAL_EVENT7          not implemented
//
//
// Some more useful events:
// eventID               Description/logic functioin
// =======               ==================================================================
// NO_EVENT              No event, in case you want to tie a certain event input to 'false'
// EVENT_TRUE            Always_on event, in case you want to tie a certain event input to 'true'. See Sample Sesion below for a usage example
// ENT_FALSE             Same as NO_EVENT
// SIGMON_ENABLED        The signal monitoring has been enabled. Useful to assert the trigger right from the start
//
//
//
//========================================================================================= 
// A typical monitoring session steps
//
// Configuring sigmon_top to invoke signals monitoring (see configuration registers definition below):
// 1. Configure the event samplers inputs with the desired events/signals to be sampled
// 2. If required, configure the event_counters, to generate a more specific event 
// 3. Determine the trigger source, as either of the event sources
// 4. Determine the trigger position along the sigmon_fifo depth
// 5. Enable signal monitoring
// 6. Potentially, poll sigmon_status, to verify the trigger was fired 
//    Or just wait for a while and read sigmon_status
// 7. Extract sigmon_fifo contents (by reading sigmon_status.number_of_entries (or less) from sigmon_fifo
// 8. If a finer sampling is required, adjust the trigger, and/or modify the sampled events and rerun
//
//
//========================================================================================= 
// Sample Monitoring test_bench Session:
//
////    Cascading event_count0 and event_count1 to generate a timed trigger.
////    Capturing the events NWP2SBU_SOP, NWP2SBU_EOP and CXP2SBU_CREDITS_OFF, once the trigger occurred.
//
//// This session assumes the default test bench stimulus files.
//// Append the following lines to ~/<netperf-workarea>/tb/exp_vlog/prj.sim/sim_1/behav/mlx_lite_file.txt
//
//
//// Writing to sigmon_ctrl2:
//// Configure event monitor #0 to capture both NWP2SBU_SOP (h0c) and NWP2SBU_EOP (h0d)
//// event monitor #1 is disabled.
// 1000: 0 8010 00000d0c
//
//// Writing to sigmon_ctrl3:
//// Configure event monitor #2 to capture CXP2SBU_CREDITS_OFF (x21)
//// event monitor #3 is disabled.
// 10: 0 8014 00000021
//
//// sigmon_ctrl4 & sigmon_ctrl5 are cleared, to disable event monitors #4 thru #7.
// 10: 0 8018 00000000
// 10: 0 801c 00000000
//
//// sigmon_ctrl6: Configuring both event_count0 and event_count1.
//
//// Configuring event_counter0 to count h200 clocks from signals monitoring enabled (asserting sigmon_ctrl1[31]):
//// The count_enable input is selected as SIGMON_ENABLED (x3f), to turn on the counter enable right from the start.
//// The count_event input is set to constant 'high' (EVENT_TRUE, x01).
//// Once this counter hits its limit, is asserts the event LOCAL_EVENT0 (used below to enable event_count1)
//
//// Configuring event_count1 to count h64 assertions of CXP2SBU_CREDITS, from the moment the previous counter (event_count0) has reached its limit:
//// The count_enable input is selected as the event_count0 output (LOCAL_EVENT0, x2c).
//// The count_event input is set to CXP2SBU_CREDITS_ON (x20)
//// Once this counter hits its limit, is asserts the event LOCAL_EVENT1 (used below to generate the trigger)
// 10: 0 8020 202c013f
//
//// Writing to sigmon_ctrl7:
//// Setting the event_count0 count limit to h200:
// 10: 0 8024 00000200
//
//
//// Writing to sigmon_ctrl8:
//// Setting the event_count1 count limit to h64:
// 10: 0 8028 00000064
//
//
//// Start monitoring
////=================
//// Configure sigmon_ctrl1 to:
//// trigger position = 2 * 32 entries from start
//// trigger source to 0x2d (LOCAL_EVENT1, output of event_count1)
//// Enable monitoring
// 1000: 0 8000 802d0002
//
//// Read sigmon_status
// 50000: 1 8004
//
//// read one entry from sigmon fifo
// 10: 1 8008
//
//// End of Sample Monitoring Session:
//
//
//
//========================================================================================= 
// Implementation Option: Add a time stamping compression mechanism, to optimize the sigmon fifo utilization
// This scheme is still not implemented.
//
// Rather than adding the full time stamp per each event, as currently implemented, only its difference vs. latter event sample will be written to the fifo.
// This scheme will be useful in a densed events scenario, in which the time-delta between the events is small, thus allowing more events to be captured by the fifo.
//
// Compressed time-stamed event format:
// 31...26 25............24 23.........16 15..........8 7...........0
// <event> <time_stamp_len> <time stamp1> <time stamp2> <time stamp3>
//
// For example, lets see how the following captured events will be written into the fifo:
//
// event1 @ t1 - the first event to be recorded
// event2 @ t1 - occurred at the same time as event1.
// event3 @ t2 - assuming t2-t1 < 2^8 (can be held within a byte)
// event4 @ t3 - assuming t3-t2 < 2^8 (can be held within a byte)
// event5 @ t4 - assuming t4-t3 < 2^16 (can be held within two bytes)
//
// fifo contents:
// entry #1: 31....26 25.24 23.......16 15.......8 7.......0
//           <event1> <  3> <t1[23:16]> <t1[15:8]> <t1[7:0]>  
//
// entry #2: 31....26 25.24 23....18 17.16 15...........8 7......2 1..0
//           <event2> <  0> <event3> <  1> <(t2-t1)[7:0]> <event4> < 1>
// 
// entry #3: 31..........24 23....18 17.16 15............8 7............0
//           <(t3-t2)[7:0]> <event5> <  2> <(t4-t3)[15:8]> <(t4-t3)[7:0]> 
//  
// Bottom line: In the anove example, only 3 fifo entries are used to hold 5 events.
//
// Compression formatting issues:
// Event identifier is limitted to 6 bits
// time_stamp_len is limitted to 2 bits: Max time_stamp is three bytes
//
//
// Another compression alternative: Use a running-length bit in time_stamp:
// For example, lets see how the following captured events will be written into the fifo:
// Note: A full time stamp occupies 3 bytes ([23:0])
//
// event1 @ t1 - the first event to be recorded.
// event2 @ t1 - occurred at the same time as event1.
// event3 @ t2 - assuming t2-t1 < 2^7
// event4 @ t3 - assuming t3-t2 < 2^7
// event5 @ t4 - assuming t4-t3 < 2^14
//
// fifo contents:
// entry #1: 31....24 23.22.......16 15.14........8  7.6........0
//           <event1> <1><t1[23:21]> <1><t1[20:14]> <1><t1[13:7]>
//           Since there is no prev. event, a full timestamp is recorded
//
// entry #2: 31.30.....24 23....16 15.14..8  7.....0
//           <0><t1[6:0]> <event2> <0><  0> <event3>
//
// entry #3: 31  30..........24 23....16 15  14...........8 7......0
//           <0> <(t2-t1)[6:0]> <event4> <0> <(t3-t2)[6:0]> <event5>
//
// entry #4: 30.30...........24 23.22..........16 15......0
//           <1><(t4-t3)[13:7]> <0><(t4-t3)[6:0]>
//
// 
//
module sigmon_top #(
parameter
    AXILITE_ADDR_WIDTH = 13,
    AXILITE_DATA_WIDTH = 32
)(
    input wire 				  clk,
    input wire 				  reset,

    // AXI_lites interface
    input wire [AXILITE_ADDR_WIDTH-1:0]   axi_AWADDR,
    input wire 				  axi_AWVALID,
    output wire 			  axi_AWREADY,
    input wire [AXILITE_DATA_WIDTH-1:0]   axi_WDATA,
    input wire [AXILITE_DATA_WIDTH/8-1:0] axi_WSTRB, // Not used by this AXILites slave. Assumed always all-1
    input wire 				  axi_WVALID,
    output wire 			  axi_WREADY,
    output wire [1:0] 			  axi_BRESP,
    output wire 			  axi_BVALID,
    input wire 				  axi_BREADY,
    input wire [AXILITE_ADDR_WIDTH-1:0]   axi_ARADDR,
    input wire 				  axi_ARVALID,
    output wire 			  axi_ARREADY,
    output wire [AXILITE_DATA_WIDTH-1:0]  axi_RDATA,
    output wire [1:0] 			  axi_RRESP,
    output wire 			  axi_RVALID,
    input wire 				  axi_RREADY,

    // monitored signals
    input 				  nwp2sbu_rdy,
    input 				  nwp2sbu_vld,
    input 				  nwp2sbu_tlast,
    input 				  sbu2nwp_rdy,
    input 				  sbu2nwp_vld,
    input 				  sbu2nwp_tlast,
    input 				  cxp2sbu_rdy,
    input 				  cxp2sbu_vld,
    input 				  cxp2sbu_tlast,
    input 				  sbu2cxp_rdy,
    input 				  sbu2cxp_vld,
    input 				  sbu2cxp_tlast,
    input 				  sbu2cxpfifo_vld,
    input 				  sbu2cxpfifo_rdy,
    input 				  sbu2cxpfifo_tlast,
    input 				  sbu2nwpfifo_vld,
    input 				  sbu2nwpfifo_rdy,
    input 				  sbu2nwpfifo_tlast,
    input 				  nwp2sbu_credits,
    input 				  cxp2sbu_credits,
    input [7:0] 			  nica_events
  
  );

// sigmon fifo size selection: 128Kx32b or 64Kx32b
// Default selection: 128Kx32b
// To select the 64Kx32b fifo, just comment out this line...
`define FIFO_128K 1
  
localparam
    WRIDLE                     = 2'd0,
    WRDATA                     = 2'd1,
    WRRESP                     = 2'd2,
    RDIDLE                     = 2'd0,
    RDDATA                     = 2'd1;

//AXI-lite address mapping of internal sigmon registers 
localparam	
  ADDR_SIGMON_CTRL1        = 13'h1000, // write only
  ADDR_SIGMON_FIFO_STATUS  = 13'h1004, // read only
  ADDR_SIGMON_FIFO_DATA    = 13'h1008, // read only
  ADDR_SIGMON_CTRL2        = 13'h1010, // write only
  ADDR_SIGMON_CTRL3        = 13'h1014, // write only
  ADDR_SIGMON_CTRL4        = 13'h1018, // write only
  ADDR_SIGMON_CTRL5        = 13'h101c, // write only
  ADDR_SIGMON_CTRL6        = 13'h1020, // write only
  ADDR_SIGMON_CTRL7        = 13'h1024, // write only
  ADDR_SIGMON_CTRL8        = 13'h1028; // write only

// Implemented events:
localparam	
  NO_EVENT = 0,
  EVENT_TRUE = 1,
  EVENT_FALSE = 2,

// axistream interfaces events:
  SBU2NWPFIFO_SOP = 4,
  SBU2NWPFIFO_EOP = 5,
  SBU2NWP_SOP = 8,
  SBU2NWP_EOP = 9,
  NWP2SBU_SOP = 12,
  NWP2SBU_EOP = 13,
  SBU2CXPFIFO_SOP = 16,
  SBU2CXPFIFO_EOP = 17,
  SBU2CXP_SOP = 20,
  SBU2CXP_EOP = 21,
  CXP2SBU_SOP = 24,
  CXP2SBU_EOP = 25,
  NWP2SBU_CREDITS_ON = 28,
  NWP2SBU_CREDITS_OFF = 29,
  CXP2SBU_CREDITS_ON = 32,
  CXP2SBU_CREDITS_OFF = 33,

// Place holder for events originated within nica. 
  NICA_EVENT0 = 36,
  NICA_EVENT1 = 37,
  NICA_EVENT2 = 38,
  NICA_EVENT3 = 39,
  NICA_EVENT4 = 40,
  NICA_EVENT5 = 41,
  NICA_EVENT6 = 42,
  NICA_EVENT7 = 43,

// Local events, generated out of other events/sampled signals
  LOCAL_EVENT0 = 44,
  LOCAL_EVENT1 = 45,
  LOCAL_EVENT2 = 46,
  LOCAL_EVENT3 = 47,
  LOCAL_EVENT4 = 48,
  LOCAL_EVENT5 = 49,
  LOCAL_EVENT6 = 50,
  LOCAL_EVENT7 = 51,

  SIGMON_ENABLED = 63
;
  
  reg [1:0]   axi_rstate;
  reg [1:0]   axi_rnext;
  reg [31:0]  axi_rdata;
  wire 	      axi_aw_hs;
  wire 	      axi_w_hs;
  reg [1:0]   axi_wstate;
  reg [1:0]   axi_wnext;
  reg [AXILITE_ADDR_WIDTH-1 : 0] axi_waddr;
  wire [AXILITE_ADDR_WIDTH-1 : 0] axi_raddr;
  wire [15:0] events_in;
  wire 	      nwp2sbu_credits_asserted;
  wire 	      nwp2sbu_credits_deasserted;
  wire 	      cxp2sbu_credits_asserted;
  wire 	      cxp2sbu_credits_deasserted;
  reg 	      nwp2sbu_creditsQ;
  reg 	      cxp2sbu_creditsQ;
  reg 	      events_mon0_in1;  
  reg 	      events_mon0_in1_en;
  reg 	      events_mon0_in2;  
  reg 	      events_mon0_in2_en;
  reg 	      events_mon1_in1;  
  reg 	      events_mon1_in1_en;
  reg 	      events_mon1_in2;  
  reg 	      events_mon1_in2_en;
  reg 	      events_mon2_in1;  
  reg 	      events_mon2_in1_en;
  reg 	      events_mon2_in2;  
  reg 	      events_mon2_in2_en;
  reg 	      events_mon3_in1;  
  reg 	      events_mon3_in1_en;
  reg 	      events_mon3_in2;  
  reg 	      events_mon3_in2_en;
  reg 	      events_mon4_in1;  
  reg 	      events_mon4_in1_en;
  reg 	      events_mon4_in2;  
  reg 	      events_mon4_in2_en;
  reg 	      events_mon5_in1;  
  reg 	      events_mon5_in1_en;
  reg 	      events_mon5_in2;  
  reg 	      events_mon5_in2_en;
  reg 	      events_mon6_in1;  
  reg 	      events_mon6_in1_en;
  reg 	      events_mon6_in2;  
  reg 	      events_mon6_in2_en;
  reg 	      events_mon7_in1;  
  reg 	      events_mon7_in1_en;
  reg 	      events_mon7_in2;  
  reg 	      events_mon7_in2_en;
  reg 	      count0_enable;
  reg 	      count0_event;
  reg 	      count1_enable;
  reg 	      count1_event;
  wire [7:0]  count_events;
  
  reg sigmon_fifo_wr;
  reg sigmon_fifo_rd2axi;
  wire sigmon_fifo_rd;
  wire [17:0] sigmon_fifo_data_count;
  wire [31:0] sigmon_fifo_din;
  wire [31:0] sigmon_fifo_dout;
  wire 	      sigmon_fifo_valid;
  wire 	      sigmon_fifo_full;
  wire 	      sigmon_fifo_empty;
  wire 	      almost_full,wr_ack,sigmon_fifo_overflow,almost_empty,sigmon_fifo_underflow,wr_rst_busy,rd_rst_busy;

  reg [31:0]  sigmon_ctrl1;
  reg [31:0]  sigmon_ctrl2;
  reg [31:0]  sigmon_ctrl3;
  reg [31:0]  sigmon_ctrl4;
  reg [31:0]  sigmon_ctrl5;
  reg [31:0]  sigmon_ctrl6;
  reg [31:0]  sigmon_ctrl7;
  reg [31:0]  sigmon_ctrl8;
  reg [47:0]  time_counter;
  reg [47:0]  trigger_counter; // Sampling the time_counter 
  wire [31:0]  sigmon_status;
  reg 	      counter_enable;
  reg 	      sigmon_enable_asserted;
  reg 	      sigmon_enable_assertedQ;
  reg 	      sigmon_enable_event;


//------------------------Local AXI read fsm------------------
//
assign axi_ARREADY = (axi_rstate == RDIDLE);
assign axi_RDATA   = axi_rdata;
assign axi_RRESP   = 2'b00;  // OKAY
assign axi_RVALID  = (axi_rstate == RDDATA);
assign axi_raddr = axi_ARADDR[AXILITE_ADDR_WIDTH-1 : 0];

// rstate
  always @(posedge clk) begin
    if (reset) begin
      axi_rstate <= RDIDLE;
    end
    else begin
      axi_rstate <= axi_rnext;
    end
  end
  
// rnext
always @(*) begin
    case (axi_rstate)
        RDIDLE:
            if (axi_ARVALID)
                axi_rnext = RDDATA;
            else
                axi_rnext = RDIDLE;
        RDDATA:
          if (axi_RREADY & axi_RVALID)
            axi_rnext = RDIDLE;
          else
            axi_rnext = RDDATA;
      default:
        axi_rnext = RDIDLE;
    endcase
end

// rdata
always @(posedge clk) begin
  if (reset)
      sigmon_fifo_rd2axi <= 1'b0;
  else if (axi_ARVALID & axi_ARREADY) begin
    axi_rdata <= 1'b0;

    if ((axi_raddr == ADDR_SIGMON_FIFO_DATA) & ~sigmon_fifo_empty) begin
      axi_rdata <= sigmon_fifo_dout;
      sigmon_fifo_rd2axi <= 1'b1;
    end
    else
// Attempt to read from an empty fifo: 
      axi_rdata <= 32'hdeadf00d;
      
    if (axi_raddr == ADDR_SIGMON_FIFO_STATUS) begin
      axi_rdata <= sigmon_status;
    end
  end
  else   //  if (sigmon_fifo_rd2axi)
      // sigmon_fifo_rd2xi is asserted to one clock only.
      sigmon_fifo_rd2axi <= 1'b0;
end

//------------------------Local AXI write fsm------------------
//
assign axi_AWREADY = (axi_wstate == WRIDLE);
assign axi_WREADY  = (axi_wstate == WRDATA);
assign axi_BRESP   = 2'b00;  // OKAY
assign axi_BVALID  = (axi_wstate == WRRESP);
assign axi_aw_hs   = axi_AWVALID & axi_AWREADY;
assign axi_w_hs    = axi_WVALID & axi_WREADY;

// wstate
always @(posedge clk) begin
    if (reset)
        axi_wstate <= WRIDLE;
    else
        axi_wstate <= axi_wnext;
end

// wnext
always @(*) begin
    case (axi_wstate)
        WRIDLE:
            if (axi_AWVALID)
                axi_wnext = WRDATA;
            else
                axi_wnext = WRIDLE;
        WRDATA:
            if (axi_WVALID)
                axi_wnext = WRRESP;
            else
                axi_wnext = WRDATA;
        WRRESP:
            if (axi_BREADY)
                axi_wnext = WRIDLE;
            else
                axi_wnext = WRRESP;
        default:
            axi_wnext = WRIDLE;
    endcase
end

// waddr
always @(posedge clk) begin
  if (axi_aw_hs)
    axi_waddr <= axi_AWADDR[AXILITE_ADDR_WIDTH-1 : 0];
end

// writing to sigmon contrl registers
always @(posedge clk) begin
  if (reset) begin
    sigmon_ctrl1 <= 32'h3f0000; // Trigger source: SIGMON_ENABLED, trigger position: 0

// Setting default selection of monitored signals: All events are disabled
    sigmon_ctrl2 <= 32'b0;
    sigmon_ctrl3 <= 32'b0;
    sigmon_ctrl4 <= 32'b0;
    sigmon_ctrl5 <= 32'b0;
    sigmon_ctrl6 <= 32'b0;
    sigmon_ctrl7 <= 32'b0;
    sigmon_ctrl8 <= 32'b0;
  end
  else begin
    if (axi_w_hs && axi_waddr == ADDR_SIGMON_CTRL1)
      sigmon_ctrl1[31:0] <= axi_WDATA[31:0];
    if (axi_w_hs && axi_waddr == ADDR_SIGMON_CTRL2)
      sigmon_ctrl2[31:0] <= axi_WDATA[31:0];
    if (axi_w_hs && axi_waddr == ADDR_SIGMON_CTRL3)
      sigmon_ctrl3[31:0] <= axi_WDATA[31:0];
    if (axi_w_hs && axi_waddr == ADDR_SIGMON_CTRL4)
      sigmon_ctrl4[31:0] <= axi_WDATA[31:0];
    if (axi_w_hs && axi_waddr == ADDR_SIGMON_CTRL5)
      sigmon_ctrl5[31:0] <= axi_WDATA[31:0];
    if (axi_w_hs && axi_waddr == ADDR_SIGMON_CTRL6)
      sigmon_ctrl6[31:0] <= axi_WDATA[31:0];
    if (axi_w_hs && axi_waddr == ADDR_SIGMON_CTRL7)
      sigmon_ctrl7[31:0] <= axi_WDATA[31:0];
    if (axi_w_hs && axi_waddr == ADDR_SIGMON_CTRL8)
      sigmon_ctrl8[31:0] <= axi_WDATA[31:0];
  end
end

// sigmon status:


`ifdef FIFO_128K
  assign sigmon_status[17:0] = sigmon_fifo_data_count[17:0];
`else
  assign sigmon_status[17:0] = {1'b0, sigmon_fifo_data_count[16:0]};
`endif

  assign sigmon_status[19:18] = 2'b00; // reserved
  assign sigmon_status[20] = sigmon_fifo_valid;
  assign sigmon_status[21] = trigger_occurred;
  assign sigmon_status[23:22] = 2'b00; // reserved
  assign sigmon_status[31:24] = events_data_loss;

  assign sigmon_reset = reset | sigmon_enable_asserted;
  assign sigmon_fifo_din = event_fifo_data[31:0];

// Look for sigmon_enable (sigmon_ctrl1[31]) assertion
always @(posedge clk) begin
  if (reset) begin
    sigmon_enable_asserted <= 0;
    sigmon_enable_assertedQ <= 0;
    sigmon_enable_event <= 0;
    counter_enable <= 0;    
  end
  else begin
    sigmon_enable_assertedQ <= sigmon_ctrl1[31];

// sigmon_ctrl1[31] assertion is used to reset both time stamp counter and the sigmon_fifo
    if (sigmon_ctrl1[31] & ~sigmon_enable_assertedQ)
      sigmon_enable_asserted <= 1;
    else 
      sigmon_enable_asserted <= 0;

// sigmon_enable_event: signalling start of monitoring, can be selected for monitoring/trigerring:
    if (sigmon_enable_asserted & sigmon_enable_assertedQ)
      sigmon_enable_event <= 1;
    else 
      sigmon_enable_event <= 0;

  end // else: !if(reset)
end

  wire sbu2cxpfifo_eop;
  wire sbu2cxp_eop;
  wire cxp2sbu_eop;
  wire sbu2nwpfifo_eop;
  wire sbu2nwp_eop;
  reg nwp2sbu_eop;
  reg  sbu2cxpfifo_eopQ;
  reg  sbu2cxp_eopQ;
  reg  cxp2sbu_eopQ;
  reg  sbu2nwpfifo_eopQ;
  reg  sbu2nwp_eopQ;
  reg  nwp2sbu_eopQ;
  wire sbu2cxpfifo_sop;
  wire sbu2cxp_sop;
  wire cxp2sbu_sop;
  wire sbu2nwpfifo_sop;
  wire sbu2nwp_sop;
  reg nwp2sbu_sop;
  wire no_event;

  assign sbu2cxpfifo_sop = sbu2cxpfifo_eopQ & sbu2cxpfifo_vld & sbu2cxpfifo_rdy;
  assign sbu2cxpfifo_eop = sbu2cxpfifo_tlast & sbu2cxpfifo_vld & sbu2cxpfifo_rdy;
  assign sbu2cxp_sop = sbu2cxp_eopQ & sbu2cxp_vld & sbu2cxp_rdy;
  assign sbu2cxp_eop = sbu2cxp_tlast & sbu2cxp_vld & sbu2cxp_rdy;
  assign cxp2sbu_sop = cxp2sbu_eopQ & cxp2sbu_vld & cxp2sbu_rdy;
  assign cxp2sbu_eop = cxp2sbu_tlast & cxp2sbu_vld & cxp2sbu_rdy;

  assign sbu2nwpfifo_sop = sbu2nwpfifo_eopQ & sbu2nwpfifo_vld & sbu2nwpfifo_rdy;
  assign sbu2nwpfifo_eop = sbu2nwpfifo_tlast & sbu2nwpfifo_vld & sbu2nwpfifo_rdy;
  assign sbu2nwp_sop = sbu2nwp_eopQ & sbu2nwp_vld & sbu2nwp_rdy;
  assign sbu2nwp_eop = sbu2nwp_tlast & sbu2nwp_vld & sbu2nwp_rdy;
//  assign nwp2sbu_sop = nwp2sbu_eopQ & nwp2sbu_vld & nwp2sbu_rdy;
//  assign nwp2sbu_eop = nwp2sbu_tlast & nwp2sbu_vld & nwp2sbu_rdy;

  assign nwp2sbu_credits_asserted  = ~nwp2sbu_creditsQ &  nwp2sbu_credits;
  assign nwp2sbu_credits_deasserted  =  nwp2sbu_creditsQ & ~nwp2sbu_credits;
  assign cxp2sbu_credits_asserted  = ~cxp2sbu_creditsQ &  cxp2sbu_credits;
  assign cxp2sbu_credits_deasserted  =  cxp2sbu_creditsQ & ~cxp2sbu_credits;


// Mark packets end at each axi-stream interface
// This indication is used to generate next packet start (*_sop) indication
always @(posedge clk) begin
  if (sigmon_reset) begin
    sbu2cxpfifo_eopQ <= 1'b0;
    sbu2cxp_eopQ <= 1'b0;
    cxp2sbu_eopQ <= 1'b0;
    sbu2nwpfifo_eopQ <= 1'b0;
    nwp2sbu_sop <= 1'b0;
    nwp2sbu_eop <= 1'b0;
    sbu2nwp_eopQ <= 1'b0;
    nwp2sbu_eopQ <= 1'b0;
    nwp2sbu_creditsQ <= 1'b0;
    cxp2sbu_creditsQ <= 1'b0;
  end
  else begin

// sbu2cxpfifo:
    if (sbu2cxpfifo_tlast) begin
       sbu2cxpfifo_eopQ <= 1;
    end
    if (sbu2cxpfifo_eopQ & sbu2cxpfifo_vld & sbu2cxpfifo_rdy) begin
//    // sop will be asserted IPG clocks after tlast
       sbu2cxpfifo_eopQ <= 0;
    end

// sbu2cxp:
    if (sbu2cxp_tlast) begin
       sbu2cxp_eopQ <= 1;
    end
    if (sbu2cxp_eopQ & sbu2cxp_vld & sbu2cxp_rdy) begin
//    // sop will be asserted IPG clocks after tlast
       sbu2cxp_eopQ <= 0;
    end

// cxp2sbu:
    if (cxp2sbu_tlast) begin
       cxp2sbu_eopQ <= 1;
    end
    if (cxp2sbu_eopQ & cxp2sbu_vld & cxp2sbu_rdy) begin
//    // sop will be asserted IPG clocks after tlast
       cxp2sbu_eopQ <= 0;
    end

// sbu2nwpfifo:
    if (sbu2nwpfifo_tlast) begin
       sbu2nwpfifo_eopQ <= 1;
    end
    if (sbu2nwpfifo_eopQ & sbu2nwpfifo_vld & sbu2nwpfifo_rdy) begin
//    // sop will be asserted IPG clocks after tlast
       sbu2nwpfifo_eopQ <= 0;
    end

// sbu2nwp:
    if (sbu2nwp_tlast) begin
       sbu2nwp_eopQ <= 1;
    end
    if (sbu2nwp_eopQ & sbu2nwp_vld & sbu2nwp_rdy) begin
//    // sop will be asserted IPG clocks after tlast
       sbu2nwp_eopQ <= 0;
    end

// nwp2sbu:
    if (nwp2sbu_tlast & nwp2sbu_vld & nwp2sbu_rdy) begin
       nwp2sbu_eopQ <= 1;
       nwp2sbu_eop <= 1;
    end
    if (nwp2sbu_eopQ & nwp2sbu_vld & nwp2sbu_rdy) begin
       nwp2sbu_eopQ <= 0;
       nwp2sbu_sop <= 1;
    end
    if (nwp2sbu_eop)
       nwp2sbu_eop <= 0;
    if (nwp2sbu_sop)
       nwp2sbu_sop <= 0;
    
// cxp2sbu & nwp2sbu credits:
       nwp2sbu_creditsQ <= nwp2sbu_credits;
       cxp2sbu_creditsQ <= cxp2sbu_credits;

  end
end

// event monitors:
  reg [7:0]   event_fifo_rd;
  wire [35:0] event0_fifo_data;
  wire [35:0] event1_fifo_data;
  wire [35:0] event2_fifo_data;
  wire [35:0] event3_fifo_data;
  wire [35:0] event4_fifo_data;
  wire [35:0] event5_fifo_data;
  wire [35:0] event6_fifo_data;
  wire [35:0] event7_fifo_data;
  wire [10:0] event0_fifo_data_count;
  wire [10:0] event1_fifo_data_count;
  wire [10:0] event2_fifo_data_count;
  wire [10:0] event3_fifo_data_count;
  wire [10:0] event4_fifo_data_count;
  wire [10:0] event5_fifo_data_count;
  wire [10:0] event6_fifo_data_count;
  wire [10:0] event7_fifo_data_count;
  wire [31:0] count0_data;
  wire [31:0] count1_data;

  reg [2:0]   event_index;      // pointer to the currently served event monitor.
  reg [2:0]   next_event_index;
  wire [7:0]  events_valid;
  wire [7:0]  events_data_loss;
  wire [15:0] events_valid_dup; // holds two consequtive duplicates of events_valid[7:0]
  reg 	      event_index_p1;
  reg 	      event_index_p2;
  reg 	      event_index_p3;
  reg 	      event_index_p4;
  reg 	      event_index_p5;
  reg 	      event_index_p6;
  reg 	      event_index_p7;
  reg 	      event_index_p8;
  reg	      no_events;
  reg 	      event_valid;
  reg [31:0] event_fifo_data;
  reg [10:0] event_fifo_data_count; 
  reg [7:0]  event_read;
  

  assign events_valid_dup[7:0] = events_valid[7:0];
  assign events_valid_dup[15:8] = events_valid[7:0];


////////////////////////////////////////////////////////////////////////////////
// Locate next event index to be served (out of the 8 implemented event monitors):
//
  always @(*) begin
//  always @(posedge clk) begin
//    if (reset | sigmon_enable_asserted) begin
//      event_valid <= 1'b0;	
//    end
    
//    else begin
    case (event_index)
//      if (event_index == 0)
     0: begin
//	begin
	  event_index_p1 <= events_valid_dup[1];
	  event_index_p2 <= events_valid_dup[2];
	  event_index_p3 <= events_valid_dup[3];
	  event_index_p4 <= events_valid_dup[4];
	  event_index_p5 <= events_valid_dup[5];
	  event_index_p6 <= events_valid_dup[6];
	  event_index_p7 <= events_valid_dup[7];
	  event_index_p8 <= events_valid_dup[8];
	  event_valid <= events_valid[0];	
	  event_fifo_data <= event0_fifo_data[31:0];
	  event_fifo_data_count <= event0_fifo_data_count;
	  event_read = 8'b00000001;
	end
//    else if (event_index == 1)
      1: begin
//	begin
	  event_index_p1 <= events_valid_dup[2];
	  event_index_p2 <= events_valid_dup[3];
	  event_index_p3 <= events_valid_dup[4];
	  event_index_p4 <= events_valid_dup[5];
	  event_index_p5 <= events_valid_dup[6];
	  event_index_p6 <= events_valid_dup[7];
	  event_index_p7 <= events_valid_dup[8];
     	  event_index_p8 <= events_valid_dup[9];
	  event_valid <= events_valid[1];	
	  event_fifo_data <= event1_fifo_data[31:0];
	  event_fifo_data_count <= event1_fifo_data_count;
	  event_read <= 8'b00000010;
	end
//      else if (event_index == 2)
      2: begin
//	begin
	  event_index_p1 <= events_valid_dup[3];
	  event_index_p2 <= events_valid_dup[4];
	  event_index_p3 <= events_valid_dup[5];
	  event_index_p4 <= events_valid_dup[6];
	  event_index_p5 <= events_valid_dup[7];
	  event_index_p6 <= events_valid_dup[8];
	  event_index_p7 <= events_valid_dup[9];
	  event_index_p8 <= events_valid_dup[10];
	  event_valid <= events_valid[2];	
	  event_fifo_data <= event2_fifo_data[31:0];
	  event_fifo_data_count <= event2_fifo_data_count;
	  event_read <= 8'b00000100;
	end
//      else if (event_index == 3)
      3: begin
//	begin
	  event_index_p1 <= events_valid_dup[4];
	  event_index_p2 <= events_valid_dup[5];
	  event_index_p3 <= events_valid_dup[6];
	  event_index_p4 <= events_valid_dup[7];
	  event_index_p5 <= events_valid_dup[8];
	  event_index_p6 <= events_valid_dup[9];
	  event_index_p7 <= events_valid_dup[10];
	  event_index_p8 <= events_valid_dup[11];
	  event_valid <= events_valid[3];	
	  event_fifo_data <= event3_fifo_data[31:0];
	  event_fifo_data_count <= event3_fifo_data_count;
	  event_read <= 8'b00001000;
	end
//      else if (event_index == 4)
      4: begin
//	begin
	  event_index_p1 <= events_valid_dup[5];
	  event_index_p2 <= events_valid_dup[6];
	  event_index_p3 <= events_valid_dup[7];
	  event_index_p4 <= events_valid_dup[8];
	  event_index_p5 <= events_valid_dup[9];
	  event_index_p6 <= events_valid_dup[10];
	  event_index_p7 <= events_valid_dup[11];
	  event_index_p8 <= events_valid_dup[12];
	  event_valid <= events_valid[4];	
	  event_fifo_data <= event4_fifo_data[31:0];
	  event_fifo_data_count <= event4_fifo_data_count;
	  event_read <= 8'b00010000;
	end
//      else if (event_index == 5)
      5: begin
//	begin
	  event_index_p1 <= events_valid_dup[6];
	  event_index_p2 <= events_valid_dup[7];
	  event_index_p3 <= events_valid_dup[8];
	  event_index_p4 <= events_valid_dup[9];
	  event_index_p5 <= events_valid_dup[10];
	  event_index_p6 <= events_valid_dup[11];
	  event_index_p7 <= events_valid_dup[12];
	  event_index_p8 <= events_valid_dup[13];
	  event_valid <= events_valid[5];	
	  event_fifo_data <= event5_fifo_data[31:0];
	  event_fifo_data_count <= event5_fifo_data_count;
	  event_read <= 8'b00100000;
	end
//      else if (event_index == 6)
      6: begin
//	begin
	  event_index_p1 <= events_valid_dup[7];
	  event_index_p2 <= events_valid_dup[8];
	  event_index_p3 <= events_valid_dup[9];
	  event_index_p4 <= events_valid_dup[10];
	  event_index_p5 <= events_valid_dup[11];
	  event_index_p6 <= events_valid_dup[12];
	  event_index_p7 <= events_valid_dup[13];
	  event_index_p8 <= events_valid_dup[14];
	  event_valid <= events_valid[6];	
	  event_fifo_data <= event6_fifo_data[31:0];
	  event_fifo_data_count <= event6_fifo_data_count;
	  event_read <= 8'b01000000;
	end
//      else if (event_index == 7)
      7: begin
//	begin
	  event_index_p1 <= events_valid_dup[8];
	  event_index_p2 <= events_valid_dup[9];
	  event_index_p3 <= events_valid_dup[10];
	  event_index_p4 <= events_valid_dup[11];
	  event_index_p5 <= events_valid_dup[12];
	  event_index_p6 <= events_valid_dup[13];
	  event_index_p7 <= events_valid_dup[14];
	  event_index_p8 <= events_valid_dup[15];
	  event_valid <= events_valid[7];	
	  event_fifo_data <= event7_fifo_data[31:0];
	  event_fifo_data_count <= event7_fifo_data_count;
	  event_read <= 8'b10000000;
	end
      
//      else
      default: 
	begin
	  event_index_p1 <= events_valid_dup[1];
	  event_index_p2 <= events_valid_dup[2];
	  event_index_p3 <= events_valid_dup[3];
	  event_index_p4 <= events_valid_dup[4];
	  event_index_p5 <= events_valid_dup[5];
	  event_index_p6 <= events_valid_dup[6];
	  event_index_p7 <= events_valid_dup[7];
	  event_index_p8 <= events_valid_dup[8];
	  event_valid <= events_valid[0];	
	  event_fifo_data <= event0_fifo_data[31:0];
	  event_fifo_data_count <= event0_fifo_data_count;
	  event_read <= 8'b00000000;
	end
    endcase
//    end // else: !assert ed)
  end


  
//  always @(posedge clk) begin
//    if (reset | sigmon_enable_asserted) begin
//      events_valid <= 8'b00000000;
//      next_event_index <= 0;
//      no_events <=  1'b1;	
//    end  
//    else begin
   always @(*) begin

//      events_valid <= events_vld;
      
      if (event_index_p1) begin
	next_event_index = event_index + 1;
	no_events =  1'b0;	
      end
      else if (~event_index_p1 & event_index_p2) begin
	next_event_index = event_index + 2;
	no_events =  1'b0;	
      end
      else if (~event_index_p1 & ~event_index_p2 & event_index_p3) begin
	next_event_index = event_index + 3;
	no_events =  1'b0;	
      end
      else if (~event_index_p1 & ~event_index_p2 & ~event_index_p3 & event_index_p4) begin
	next_event_index = event_index + 4;
	no_events =  1'b0;	
      end
      else if (~event_index_p1 & ~event_index_p2 & ~event_index_p3 & ~event_index_p4 & event_index_p5) begin
	next_event_index = event_index + 5;
	no_events =  1'b0;	
      end
      else if (~event_index_p1 & ~event_index_p2 & ~event_index_p3 & ~event_index_p4 & ~event_index_p5 & event_index_p6) begin
	next_event_index = event_index + 6;
	no_events =  1'b0;	
      end
      else if (~event_index_p1 & ~event_index_p2 & ~event_index_p3 & ~event_index_p4 & ~event_index_p5 & ~event_index_p6 & event_index_p7) begin
	next_event_index = event_index + 7;
	no_events =  1'b0;	
      end
      else if (~event_index_p1 & ~event_index_p2 & ~event_index_p3 & ~event_index_p4 & ~event_index_p5 & ~event_index_p6 & ~event_index_p7 & event_index_p8) begin
	next_event_index = event_index + 8;  // This is a modulo 8 addition (actually adding 0)
	no_events =  1'b0;	
      end
      else
      // if (~event_index_p1 & ~event_index_p2 & ~event_index_p3 & ~event_index_p4 & ~event_index_p5 & ~event_index_p6 & ~event_index_p7 & ~event_index_p8) 
      begin
	next_event_index = event_index;
	no_events =  1'b1;	
      end
      
      // No more events to handle
//      else begin
//	no_events <=  1'b1;
//	next_event_index <= 0;
//      end
//    end
   end  


//////////////////////////////////////////////////////////////////////////////////
// Select which signals go to each event monitor:
//
//event_mon0
  always @(*) begin
    //event_mon0, first input:
    case (sigmon_ctrl2[5:0]) 
      NO_EVENT:
	begin
	  events_mon0_in1 = 1'b0;
	  events_mon0_in1_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon0_in1 = 1'b1;
	  events_mon0_in1_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon0_in1 = 1'b0;
	  events_mon0_in1_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon0_in1 = sbu2nwpfifo_sop;
	  events_mon0_in1_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon0_in1 = sbu2nwpfifo_eop;
	  events_mon0_in1_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon0_in1 = sbu2nwp_sop;
	  events_mon0_in1_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon0_in1 = sbu2nwp_eop;
	  events_mon0_in1_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon0_in1 = nwp2sbu_sop;
	  events_mon0_in1_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon0_in1 = nwp2sbu_eop;
	  events_mon0_in1_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon0_in1 = sbu2cxpfifo_sop;
	  events_mon0_in1_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon0_in1 = sbu2cxpfifo_eop;
	  events_mon0_in1_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon0_in1 = sbu2cxp_sop;
	  events_mon0_in1_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon0_in1 = sbu2cxp_eop;
	  events_mon0_in1_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon0_in1 = cxp2sbu_sop;
	  events_mon0_in1_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon0_in1 = cxp2sbu_eop;
	  events_mon0_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon0_in1 = nwp2sbu_credits_asserted;
	  events_mon0_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon0_in1 = nwp2sbu_credits_deasserted;
	  events_mon0_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon0_in1 = cxp2sbu_credits_asserted;
	  events_mon0_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon0_in1 = cxp2sbu_credits_deasserted;
	  events_mon0_in1_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon0_in1 = nica_events[0];
	  events_mon0_in1_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon0_in1 = nica_events[1];
	  events_mon0_in1_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon0_in1 = nica_events[2];
	  events_mon0_in1_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon0_in1 = nica_events[3];
	  events_mon0_in1_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon0_in1 = nica_events[4];
	  events_mon0_in1_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon0_in1 = nica_events[5];
	  events_mon0_in1_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon0_in1 = nica_events[6];
	  events_mon0_in1_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon0_in1 = nica_events[7];
	  events_mon0_in1_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon0_in1 = count_events[0];
	  events_mon0_in1_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon0_in1 = count_events[1];
	  events_mon0_in1_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon0_in1 = sigmon_enable_event;
	  events_mon0_in1_en = 1'b1;
	end
      default: begin
	events_mon0_in1 = 1'b0;;
	events_mon0_in1_en = 1'b0;
      end
    endcase

    //event_mon0, second input:
    case (sigmon_ctrl2[13:8]) 
      NO_EVENT:
	begin
	  events_mon0_in2 = 1'b0;
	  events_mon0_in2_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon0_in2 = 1'b1;
	  events_mon0_in2_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon0_in2 = 1'b0;
	  events_mon0_in2_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon0_in2 = sbu2nwpfifo_sop;
	  events_mon0_in2_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon0_in2 = sbu2nwpfifo_eop;
	  events_mon0_in2_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon0_in2 = sbu2nwp_sop;
	  events_mon0_in2_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon0_in2 = sbu2nwp_eop;
	  events_mon0_in2_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon0_in2 = nwp2sbu_sop;
	  events_mon0_in2_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon0_in2 = nwp2sbu_eop;
	  events_mon0_in2_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon0_in2 = sbu2cxpfifo_sop;
	  events_mon0_in2_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon0_in2 = sbu2cxpfifo_eop;
	  events_mon0_in2_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon0_in2 = sbu2cxp_sop;
	  events_mon0_in2_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon0_in2 = sbu2cxp_eop;
	  events_mon0_in2_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon0_in2 = cxp2sbu_sop;
	  events_mon0_in2_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon0_in2 = cxp2sbu_eop;
	  events_mon0_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon0_in2 = nwp2sbu_credits_asserted;
	  events_mon0_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon0_in2 = nwp2sbu_credits_deasserted;
	  events_mon0_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon0_in2 = cxp2sbu_credits_asserted;
	  events_mon0_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon0_in2 = cxp2sbu_credits_deasserted;
	  events_mon0_in2_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon0_in2 = nica_events[0];
	  events_mon0_in2_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon0_in2 = nica_events[1];
	  events_mon0_in2_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon0_in2 = nica_events[2];
	  events_mon0_in2_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon0_in2 = nica_events[3];
	  events_mon0_in2_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon0_in2 = nica_events[4];
	  events_mon0_in2_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon0_in2 = nica_events[5];
	  events_mon0_in2_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon0_in2 = nica_events[6];
	  events_mon0_in2_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon0_in2 = nica_events[7];
	  events_mon0_in2_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon0_in2 = count_events[0];
	  events_mon0_in2_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon0_in2 = count_events[1];
	  events_mon0_in2_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon0_in2 = sigmon_enable_event;
	  events_mon0_in2_en = 1'b1;
	end
      default: begin
	events_mon0_in2 = 1'b0;;
	events_mon0_in2_en = 1'b0;
      end
    endcase
  end

//event_mon1
  always @(*) begin
    //event_mon1, first input:
    case (sigmon_ctrl2[21:16]) 
      NO_EVENT:
	begin
	  events_mon1_in1 = 1'b0;
	  events_mon1_in1_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon1_in1 = 1'b1;
	  events_mon1_in1_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon1_in1 = 1'b0;
	  events_mon1_in1_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon1_in1 = sbu2nwpfifo_sop;
	  events_mon1_in1_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon1_in1 = sbu2nwpfifo_eop;
	  events_mon1_in1_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon1_in1 = sbu2nwp_sop;
	  events_mon1_in1_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon1_in1 = sbu2nwp_eop;
	  events_mon1_in1_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon1_in1 = nwp2sbu_sop;
	  events_mon1_in1_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon1_in1 = nwp2sbu_eop;
	  events_mon1_in1_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon1_in1 = sbu2cxpfifo_sop;
	  events_mon1_in1_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon1_in1 = sbu2cxpfifo_eop;
	  events_mon1_in1_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon1_in1 = sbu2cxp_sop;
	  events_mon1_in1_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon1_in1 = sbu2cxp_eop;
	  events_mon1_in1_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon1_in1 = cxp2sbu_sop;
	  events_mon1_in1_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon1_in1 = cxp2sbu_eop;
	  events_mon1_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon1_in1 = nwp2sbu_credits_asserted;
	  events_mon1_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon1_in1 = nwp2sbu_credits_deasserted;
	  events_mon1_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon1_in1 = cxp2sbu_credits_asserted;
	  events_mon1_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon1_in1 = cxp2sbu_credits_deasserted;
	  events_mon1_in1_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon1_in1 = nica_events[0];
	  events_mon1_in1_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon1_in1 = nica_events[1];
	  events_mon1_in1_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon1_in1 = nica_events[2];
	  events_mon1_in1_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon1_in1 = nica_events[3];
	  events_mon1_in1_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon1_in1 = nica_events[4];
	  events_mon1_in1_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon1_in1 = nica_events[5];
	  events_mon1_in1_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon1_in1 = nica_events[6];
	  events_mon1_in1_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon1_in1 = nica_events[7];
	  events_mon1_in1_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon1_in1 = count_events[0];
	  events_mon1_in1_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon1_in1 = count_events[1];
	  events_mon1_in1_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon1_in1 = sigmon_enable_event;
	  events_mon1_in1_en = 1'b1;
	end
      default: begin
	events_mon1_in1 = 1'b0;;
	events_mon1_in1_en = 1'b0;
      end
    endcase

    //event_mon1, second input:
    case (sigmon_ctrl2[29:24]) 
      NO_EVENT:
	begin
	  events_mon1_in2 = 1'b0;
	  events_mon1_in2_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon1_in2 = 1'b1;
	  events_mon1_in2_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon1_in2 = 1'b0;
	  events_mon1_in2_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon1_in2 = sbu2nwpfifo_sop;
	  events_mon1_in2_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon1_in2 = sbu2nwpfifo_eop;
	  events_mon1_in2_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon1_in2 = sbu2nwp_sop;
	  events_mon1_in2_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon1_in2 = sbu2nwp_eop;
	  events_mon1_in2_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon1_in2 = nwp2sbu_sop;
	  events_mon1_in2_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon1_in2 = nwp2sbu_eop;
	  events_mon1_in2_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon1_in2 = sbu2cxpfifo_sop;
	  events_mon1_in2_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon1_in2 = sbu2cxpfifo_eop;
	  events_mon1_in2_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon1_in2 = sbu2cxp_sop;
	  events_mon1_in2_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon1_in2 = sbu2cxp_eop;
	  events_mon1_in2_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon1_in2 = cxp2sbu_sop;
	  events_mon1_in2_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon1_in2 = cxp2sbu_eop;
	  events_mon1_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon1_in2 = nwp2sbu_credits_asserted;
	  events_mon1_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon1_in2 = nwp2sbu_credits_deasserted;
	  events_mon1_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon1_in2 = cxp2sbu_credits_asserted;
	  events_mon1_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon1_in2 = cxp2sbu_credits_deasserted;
	  events_mon1_in2_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon1_in2 = nica_events[0];
	  events_mon1_in2_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon1_in2 = nica_events[1];
	  events_mon1_in2_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon1_in2 = nica_events[2];
	  events_mon1_in2_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon1_in2 = nica_events[3];
	  events_mon1_in2_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon1_in2 = nica_events[4];
	  events_mon1_in2_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon1_in2 = nica_events[5];
	  events_mon1_in2_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon1_in2 = nica_events[6];
	  events_mon1_in2_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon1_in2 = nica_events[7];
	  events_mon1_in2_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon1_in2 = count_events[0];
	  events_mon1_in2_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon1_in2 = count_events[1];
	  events_mon1_in2_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon1_in2 = sigmon_enable_event;
	  events_mon1_in2_en = 1'b1;
	end
      default: begin
	events_mon1_in2 = 1'b0;;
	events_mon1_in2_en = 1'b0;
      end
    endcase
  end

//event_mon2
  always @(*) begin
    //event_mon2, first input:
    case (sigmon_ctrl3[5:0]) 
      NO_EVENT:
	begin
	  events_mon2_in1 = 1'b0;
	  events_mon2_in1_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon2_in1 = 1'b1;
	  events_mon2_in1_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon2_in1 = 1'b0;
	  events_mon2_in1_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon2_in1 = sbu2nwpfifo_sop;
	  events_mon2_in1_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon2_in1 = sbu2nwpfifo_eop;
	  events_mon2_in1_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon2_in1 = sbu2nwp_sop;
	  events_mon2_in1_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon2_in1 = sbu2nwp_eop;
	  events_mon2_in1_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon2_in1 = nwp2sbu_sop;
	  events_mon2_in1_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon2_in1 = nwp2sbu_eop;
	  events_mon2_in1_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon2_in1 = sbu2cxpfifo_sop;
	  events_mon2_in1_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon2_in1 = sbu2cxpfifo_eop;
	  events_mon2_in1_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon2_in1 = sbu2cxp_sop;
	  events_mon2_in1_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon2_in1 = sbu2cxp_eop;
	  events_mon2_in1_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon2_in1 = cxp2sbu_sop;
	  events_mon2_in1_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon2_in1 = cxp2sbu_eop;
	  events_mon2_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon2_in1 = nwp2sbu_credits_asserted;
	  events_mon2_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon2_in1 = nwp2sbu_credits_deasserted;
	  events_mon2_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon2_in1 = cxp2sbu_credits_asserted;
	  events_mon2_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon2_in1 = cxp2sbu_credits_deasserted;
	  events_mon2_in1_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon2_in1 = nica_events[0];
	  events_mon2_in1_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon2_in1 = nica_events[1];
	  events_mon2_in1_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon2_in1 = nica_events[2];
	  events_mon2_in1_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon2_in1 = nica_events[3];
	  events_mon2_in1_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon2_in1 = nica_events[4];
	  events_mon2_in1_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon2_in1 = nica_events[5];
	  events_mon2_in1_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon2_in1 = nica_events[6];
	  events_mon2_in1_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon2_in1 = nica_events[7];
	  events_mon2_in1_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon2_in1 = count_events[0];
	  events_mon2_in1_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon2_in1 = count_events[1];
	  events_mon2_in1_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon2_in1 = sigmon_enable_event;
	  events_mon2_in1_en = 1'b1;
	end
      default: begin
	events_mon2_in1 = 1'b0;;
	events_mon2_in1_en = 1'b0;
      end
    endcase

    //event_mon2, second input:
    case (sigmon_ctrl3[13:8]) 
      NO_EVENT:
	begin
	  events_mon2_in2 = 1'b0;
	  events_mon2_in2_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon2_in2 = 1'b1;
	  events_mon2_in2_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon2_in2 = 1'b0;
	  events_mon2_in2_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon2_in2 = sbu2nwpfifo_sop;
	  events_mon2_in2_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon2_in2 = sbu2nwpfifo_eop;
	  events_mon2_in2_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon2_in2 = sbu2nwp_sop;
	  events_mon2_in2_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon2_in2 = sbu2nwp_eop;
	  events_mon2_in2_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon2_in2 = nwp2sbu_sop;
	  events_mon2_in2_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon2_in2 = nwp2sbu_eop;
	  events_mon2_in2_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon2_in2 = sbu2cxpfifo_sop;
	  events_mon2_in2_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon2_in2 = sbu2cxpfifo_eop;
	  events_mon2_in2_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon2_in2 = sbu2cxp_sop;
	  events_mon2_in2_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon2_in2 = sbu2cxp_eop;
	  events_mon2_in2_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon2_in2 = cxp2sbu_sop;
	  events_mon2_in2_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon2_in2 = cxp2sbu_eop;
	  events_mon2_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon2_in2 = nwp2sbu_credits_asserted;
	  events_mon2_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon2_in2 = nwp2sbu_credits_deasserted;
	  events_mon2_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon2_in2 = cxp2sbu_credits_asserted;
	  events_mon2_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon2_in2 = cxp2sbu_credits_deasserted;
	  events_mon2_in2_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon2_in2 = nica_events[0];
	  events_mon2_in2_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon2_in2 = nica_events[1];
	  events_mon2_in2_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon2_in2 = nica_events[2];
	  events_mon2_in2_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon2_in2 = nica_events[3];
	  events_mon2_in2_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon2_in2 = nica_events[4];
	  events_mon2_in2_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon2_in2 = nica_events[5];
	  events_mon2_in2_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon2_in2 = nica_events[6];
	  events_mon2_in2_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon2_in2 = nica_events[7];
	  events_mon2_in2_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon2_in2 = count_events[0];
	  events_mon2_in2_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon2_in2 = count_events[1];
	  events_mon2_in2_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon2_in2 = sigmon_enable_event;
	  events_mon2_in2_en = 1'b1;
	end
      default: begin
	events_mon2_in2 = 1'b0;;
	events_mon2_in2_en = 1'b0;
      end
    endcase
  end

//event_mon3
  always @(*) begin
    //event_mon3, first input:
    case (sigmon_ctrl3[21:16]) 
      NO_EVENT:
	begin
	  events_mon3_in1 = 1'b0;
	  events_mon3_in1_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon3_in1 = 1'b1;
	  events_mon3_in1_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon3_in1 = 1'b0;
	  events_mon3_in1_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon3_in1 = sbu2nwpfifo_sop;
	  events_mon3_in1_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon3_in1 = sbu2nwpfifo_eop;
	  events_mon3_in1_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon3_in1 = sbu2nwp_sop;
	  events_mon3_in1_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon3_in1 = sbu2nwp_eop;
	  events_mon3_in1_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon3_in1 = nwp2sbu_sop;
	  events_mon3_in1_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon3_in1 = nwp2sbu_eop;
	  events_mon3_in1_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon3_in1 = sbu2cxpfifo_sop;
	  events_mon3_in1_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon3_in1 = sbu2cxpfifo_eop;
	  events_mon3_in1_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon3_in1 = sbu2cxp_sop;
	  events_mon3_in1_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon3_in1 = sbu2cxp_eop;
	  events_mon3_in1_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon3_in1 = cxp2sbu_sop;
	  events_mon3_in1_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon3_in1 = cxp2sbu_eop;
	  events_mon3_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon3_in1 = nwp2sbu_credits_asserted;
	  events_mon3_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon3_in1 = nwp2sbu_credits_deasserted;
	  events_mon3_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon3_in1 = cxp2sbu_credits_asserted;
	  events_mon3_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon3_in1 = cxp2sbu_credits_deasserted;
	  events_mon3_in1_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon3_in1 = nica_events[0];
	  events_mon3_in1_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon3_in1 = nica_events[1];
	  events_mon3_in1_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon3_in1 = nica_events[2];
	  events_mon3_in1_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon3_in1 = nica_events[3];
	  events_mon3_in1_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon3_in1 = nica_events[4];
	  events_mon3_in1_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon3_in1 = nica_events[5];
	  events_mon3_in1_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon3_in1 = nica_events[6];
	  events_mon3_in1_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon3_in1 = nica_events[7];
	  events_mon3_in1_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon3_in1 = count_events[0];
	  events_mon3_in1_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon3_in1 = count_events[1];
	  events_mon3_in1_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon3_in1 = sigmon_enable_event;
	  events_mon3_in1_en = 1'b1;
	end
      default: begin
	events_mon3_in1 = 1'b0;;
	events_mon3_in1_en = 1'b0;
      end
    endcase

    //event_mon3, second input:
    case (sigmon_ctrl3[29:24]) 
      NO_EVENT:
	begin
	  events_mon3_in2 = 1'b0;
	  events_mon3_in2_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon3_in2 = 1'b1;
	  events_mon3_in2_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon3_in2 = 1'b0;
	  events_mon3_in2_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon3_in2 = sbu2nwpfifo_sop;
	  events_mon3_in2_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon3_in2 = sbu2nwpfifo_eop;
	  events_mon3_in2_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon3_in2 = sbu2nwp_sop;
	  events_mon3_in2_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon3_in2 = sbu2nwp_eop;
	  events_mon3_in2_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon3_in2 = nwp2sbu_sop;
	  events_mon3_in2_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon3_in2 = nwp2sbu_eop;
	  events_mon3_in2_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon3_in2 = sbu2cxpfifo_sop;
	  events_mon3_in2_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon3_in2 = sbu2cxpfifo_eop;
	  events_mon3_in2_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon3_in2 = sbu2cxp_sop;
	  events_mon3_in2_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon3_in2 = sbu2cxp_eop;
	  events_mon3_in2_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon3_in2 = cxp2sbu_sop;
	  events_mon3_in2_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon3_in2 = cxp2sbu_eop;
	  events_mon3_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon3_in2 = nwp2sbu_credits_asserted;
	  events_mon3_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon3_in2 = nwp2sbu_credits_deasserted;
	  events_mon3_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon3_in2 = cxp2sbu_credits_asserted;
	  events_mon3_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon3_in2 = cxp2sbu_credits_deasserted;
	  events_mon3_in2_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon3_in2 = nica_events[0];
	  events_mon3_in2_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon3_in2 = nica_events[1];
	  events_mon3_in2_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon3_in2 = nica_events[2];
	  events_mon3_in2_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon3_in2 = nica_events[3];
	  events_mon3_in2_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon3_in2 = nica_events[4];
	  events_mon3_in2_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon3_in2 = nica_events[5];
	  events_mon3_in2_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon3_in2 = nica_events[6];
	  events_mon3_in2_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon3_in2 = nica_events[7];
	  events_mon3_in2_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon3_in2 = count_events[0];
	  events_mon3_in2_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon3_in2 = count_events[1];
	  events_mon3_in2_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon3_in2 = sigmon_enable_event;
	  events_mon3_in2_en = 1'b1;
	end
      default: begin
	events_mon3_in2 = 1'b0;;
	events_mon3_in2_en = 1'b0;
      end
    endcase
  end

//event_mon4
  always @(*) begin
    //event_mon4, first input:
    case (sigmon_ctrl4[5:0]) 
      NO_EVENT:
	begin
	  events_mon4_in1 = 1'b0;
	  events_mon4_in1_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon4_in1 = 1'b1;
	  events_mon4_in1_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon4_in1 = 1'b0;
	  events_mon4_in1_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon4_in1 = sbu2nwpfifo_sop;
	  events_mon4_in1_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon4_in1 = sbu2nwpfifo_eop;
	  events_mon4_in1_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon4_in1 = sbu2nwp_sop;
	  events_mon4_in1_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon4_in1 = sbu2nwp_eop;
	  events_mon4_in1_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon4_in1 = nwp2sbu_sop;
	  events_mon4_in1_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon4_in1 = nwp2sbu_eop;
	  events_mon4_in1_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon4_in1 = sbu2cxpfifo_sop;
	  events_mon4_in1_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon4_in1 = sbu2cxpfifo_eop;
	  events_mon4_in1_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon4_in1 = sbu2cxp_sop;
	  events_mon4_in1_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon4_in1 = sbu2cxp_eop;
	  events_mon4_in1_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon4_in1 = cxp2sbu_sop;
	  events_mon4_in1_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon4_in1 = cxp2sbu_eop;
	  events_mon4_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon4_in1 = nwp2sbu_credits_asserted;
	  events_mon4_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon4_in1 = nwp2sbu_credits_deasserted;
	  events_mon4_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon4_in1 = cxp2sbu_credits_asserted;
	  events_mon4_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon4_in1 = cxp2sbu_credits_deasserted;
	  events_mon4_in1_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon4_in1 = nica_events[0];
	  events_mon4_in1_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon4_in1 = nica_events[1];
	  events_mon4_in1_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon4_in1 = nica_events[2];
	  events_mon4_in1_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon4_in1 = nica_events[3];
	  events_mon4_in1_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon4_in1 = nica_events[4];
	  events_mon4_in1_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon4_in1 = nica_events[5];
	  events_mon4_in1_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon4_in1 = nica_events[6];
	  events_mon4_in1_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon4_in1 = nica_events[7];
	  events_mon4_in1_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon4_in1 = count_events[0];
	  events_mon4_in1_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon4_in1 = count_events[1];
	  events_mon4_in1_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon4_in1 = sigmon_enable_event;
	  events_mon4_in1_en = 1'b1;
	end
      default: begin
	events_mon4_in1 = 1'b0;;
	events_mon4_in1_en = 1'b0;
      end
    endcase

    //event_mon4, second input:
    case (sigmon_ctrl4[13:8]) 
      NO_EVENT:
	begin
	  events_mon4_in2 = 1'b0;
	  events_mon4_in2_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon4_in2 = 1'b1;
	  events_mon4_in2_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon4_in2 = 1'b0;
	  events_mon4_in2_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon4_in2 = sbu2nwpfifo_sop;
	  events_mon4_in2_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon4_in2 = sbu2nwpfifo_eop;
	  events_mon4_in2_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon4_in2 = sbu2nwp_sop;
	  events_mon4_in2_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon4_in2 = sbu2nwp_eop;
	  events_mon4_in2_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon4_in2 = nwp2sbu_sop;
	  events_mon4_in2_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon4_in2 = nwp2sbu_eop;
	  events_mon4_in2_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon4_in2 = sbu2cxpfifo_sop;
	  events_mon4_in2_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon4_in2 = sbu2cxpfifo_eop;
	  events_mon4_in2_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon4_in2 = sbu2cxp_sop;
	  events_mon4_in2_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon4_in2 = sbu2cxp_eop;
	  events_mon4_in2_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon4_in2 = cxp2sbu_sop;
	  events_mon4_in2_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon4_in2 = cxp2sbu_eop;
	  events_mon4_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon4_in2 = nwp2sbu_credits_asserted;
	  events_mon4_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon4_in2 = nwp2sbu_credits_deasserted;
	  events_mon4_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon4_in2 = cxp2sbu_credits_asserted;
	  events_mon4_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon4_in2 = cxp2sbu_credits_deasserted;
	  events_mon4_in2_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon4_in2 = nica_events[0];
	  events_mon4_in2_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon4_in2 = nica_events[1];
	  events_mon4_in2_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon4_in2 = nica_events[2];
	  events_mon4_in2_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon4_in2 = nica_events[3];
	  events_mon4_in2_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon4_in2 = nica_events[4];
	  events_mon4_in2_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon4_in2 = nica_events[5];
	  events_mon4_in2_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon4_in2 = nica_events[6];
	  events_mon4_in2_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon4_in2 = nica_events[7];
	  events_mon4_in2_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon4_in2 = count_events[0];
	  events_mon4_in2_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon4_in2 = count_events[1];
	  events_mon4_in2_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon4_in2 = sigmon_enable_event;
	  events_mon4_in2_en = 1'b1;
	end
      default: begin
	events_mon4_in2 = 1'b0;;
	events_mon4_in2_en = 1'b0;
      end
    endcase
  end

//event_mon5
  always @(*) begin
    //event_mon5, first input:
    case (sigmon_ctrl4[21:16]) 
      NO_EVENT:
	begin
	  events_mon5_in1 = 1'b0;
	  events_mon5_in1_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon5_in1 = 1'b1;
	  events_mon5_in1_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon5_in1 = 1'b0;
	  events_mon5_in1_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon5_in1 = sbu2nwpfifo_sop;
	  events_mon5_in1_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon5_in1 = sbu2nwpfifo_eop;
	  events_mon5_in1_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon5_in1 = sbu2nwp_sop;
	  events_mon5_in1_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon5_in1 = sbu2nwp_eop;
	  events_mon5_in1_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon5_in1 = nwp2sbu_sop;
	  events_mon5_in1_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon5_in1 = nwp2sbu_eop;
	  events_mon5_in1_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon5_in1 = sbu2cxpfifo_sop;
	  events_mon5_in1_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon5_in1 = sbu2cxpfifo_eop;
	  events_mon5_in1_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon5_in1 = sbu2cxp_sop;
	  events_mon5_in1_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon5_in1 = sbu2cxp_eop;
	  events_mon5_in1_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon5_in1 = cxp2sbu_sop;
	  events_mon5_in1_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon5_in1 = cxp2sbu_eop;
	  events_mon5_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon5_in1 = nwp2sbu_credits_asserted;
	  events_mon5_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon5_in1 = nwp2sbu_credits_deasserted;
	  events_mon5_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon5_in1 = cxp2sbu_credits_asserted;
	  events_mon5_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon5_in1 = cxp2sbu_credits_deasserted;
	  events_mon5_in1_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon5_in1 = nica_events[0];
	  events_mon5_in1_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon5_in1 = nica_events[1];
	  events_mon5_in1_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon5_in1 = nica_events[2];
	  events_mon5_in1_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon5_in1 = nica_events[3];
	  events_mon5_in1_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon5_in1 = nica_events[4];
	  events_mon5_in1_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon5_in1 = nica_events[5];
	  events_mon5_in1_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon5_in1 = nica_events[6];
	  events_mon5_in1_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon5_in1 = nica_events[7];
	  events_mon5_in1_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon5_in1 = count_events[0];
	  events_mon5_in1_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon5_in1 = count_events[1];
	  events_mon5_in1_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon5_in1 = sigmon_enable_event;
	  events_mon5_in1_en = 1'b1;
	end
      default: begin
	events_mon5_in1 = 1'b0;;
	events_mon5_in1_en = 1'b0;
      end
    endcase

    //event_mon5, second input:
    case (sigmon_ctrl4[29:24]) 
      NO_EVENT:
	begin
	  events_mon5_in2 = 1'b0;
	  events_mon5_in2_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon5_in2 = 1'b1;
	  events_mon5_in2_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon5_in2 = 1'b0;
	  events_mon5_in2_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon5_in2 = sbu2nwpfifo_sop;
	  events_mon5_in2_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon5_in2 = sbu2nwpfifo_eop;
	  events_mon5_in2_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon5_in2 = sbu2nwp_sop;
	  events_mon5_in2_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon5_in2 = sbu2nwp_eop;
	  events_mon5_in2_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon5_in2 = nwp2sbu_sop;
	  events_mon5_in2_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon5_in2 = nwp2sbu_eop;
	  events_mon5_in2_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon5_in2 = sbu2cxpfifo_sop;
	  events_mon5_in2_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon5_in2 = sbu2cxpfifo_eop;
	  events_mon5_in2_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon5_in2 = sbu2cxp_sop;
	  events_mon5_in2_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon5_in2 = sbu2cxp_eop;
	  events_mon5_in2_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon5_in2 = cxp2sbu_sop;
	  events_mon5_in2_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon5_in2 = cxp2sbu_eop;
	  events_mon5_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon5_in2 = nwp2sbu_credits_asserted;
	  events_mon5_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon5_in2 = nwp2sbu_credits_deasserted;
	  events_mon5_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon5_in2 = cxp2sbu_credits_asserted;
	  events_mon5_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon5_in2 = cxp2sbu_credits_deasserted;
	  events_mon5_in2_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon5_in2 = nica_events[0];
	  events_mon5_in2_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon5_in2 = nica_events[1];
	  events_mon5_in2_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon5_in2 = nica_events[2];
	  events_mon5_in2_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon5_in2 = nica_events[3];
	  events_mon5_in2_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon5_in2 = nica_events[4];
	  events_mon5_in2_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon5_in2 = nica_events[5];
	  events_mon5_in2_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon5_in2 = nica_events[6];
	  events_mon5_in2_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon5_in2 = nica_events[7];
	  events_mon5_in2_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon5_in2 = count_events[0];
	  events_mon5_in2_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon5_in2 = count_events[1];
	  events_mon5_in2_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon5_in2 = sigmon_enable_event;
	  events_mon5_in2_en = 1'b1;
	end
      default: begin
	events_mon5_in2 = 1'b0;;
	events_mon5_in2_en = 1'b0;
      end
    endcase
  end

//event_mon6
  always @(*) begin
    //event_mon6, first input:
    case (sigmon_ctrl5[5:0]) 
      NO_EVENT:
	begin
	  events_mon6_in1 = 1'b0;
	  events_mon6_in1_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon6_in1 = 1'b1;
	  events_mon6_in1_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon6_in1 = 1'b0;
	  events_mon6_in1_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon6_in1 = sbu2nwpfifo_sop;
	  events_mon6_in1_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon6_in1 = sbu2nwpfifo_eop;
	  events_mon6_in1_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon6_in1 = sbu2nwp_sop;
	  events_mon6_in1_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon6_in1 = sbu2nwp_eop;
	  events_mon6_in1_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon6_in1 = nwp2sbu_sop;
	  events_mon6_in1_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon6_in1 = nwp2sbu_eop;
	  events_mon6_in1_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon6_in1 = sbu2cxpfifo_sop;
	  events_mon6_in1_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon6_in1 = sbu2cxpfifo_eop;
	  events_mon6_in1_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon6_in1 = sbu2cxp_sop;
	  events_mon6_in1_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon6_in1 = sbu2cxp_eop;
	  events_mon6_in1_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon6_in1 = cxp2sbu_sop;
	  events_mon6_in1_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon6_in1 = cxp2sbu_eop;
	  events_mon6_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon6_in1 = nwp2sbu_credits_asserted;
	  events_mon6_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon6_in1 = nwp2sbu_credits_deasserted;
	  events_mon6_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon6_in1 = cxp2sbu_credits_asserted;
	  events_mon6_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon6_in1 = cxp2sbu_credits_deasserted;
	  events_mon6_in1_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon6_in1 = nica_events[0];
	  events_mon6_in1_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon6_in1 = nica_events[1];
	  events_mon6_in1_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon6_in1 = nica_events[2];
	  events_mon6_in1_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon6_in1 = nica_events[3];
	  events_mon6_in1_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon6_in1 = nica_events[4];
	  events_mon6_in1_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon6_in1 = nica_events[5];
	  events_mon6_in1_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon6_in1 = nica_events[6];
	  events_mon6_in1_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon6_in1 = nica_events[7];
	  events_mon6_in1_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon6_in1 = count_events[0];
	  events_mon6_in1_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon6_in1 = count_events[1];
	  events_mon6_in1_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon6_in1 = sigmon_enable_event;
	  events_mon6_in1_en = 1'b1;
	end
      default: begin
	events_mon6_in1 = 1'b0;;
	events_mon6_in1_en = 1'b0;
      end
    endcase

    //event_mon6, second input:
    case (sigmon_ctrl5[13:8]) 
      NO_EVENT:
	begin
	  events_mon6_in2 = 1'b0;
	  events_mon6_in2_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon6_in2 = 1'b1;
	  events_mon6_in2_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon6_in2 = 1'b0;
	  events_mon6_in2_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon6_in2 = sbu2nwpfifo_sop;
	  events_mon6_in2_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon6_in2 = sbu2nwpfifo_eop;
	  events_mon6_in2_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon6_in2 = sbu2nwp_sop;
	  events_mon6_in2_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon6_in2 = sbu2nwp_eop;
	  events_mon6_in2_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon6_in2 = nwp2sbu_sop;
	  events_mon6_in2_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon6_in2 = nwp2sbu_eop;
	  events_mon6_in2_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon6_in2 = sbu2cxpfifo_sop;
	  events_mon6_in2_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon6_in2 = sbu2cxpfifo_eop;
	  events_mon6_in2_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon6_in2 = sbu2cxp_sop;
	  events_mon6_in2_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon6_in2 = sbu2cxp_eop;
	  events_mon6_in2_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon6_in2 = cxp2sbu_sop;
	  events_mon6_in2_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon6_in2 = cxp2sbu_eop;
	  events_mon6_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon6_in2 = nwp2sbu_credits_asserted;
	  events_mon6_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon6_in2 = nwp2sbu_credits_deasserted;
	  events_mon6_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon6_in2 = cxp2sbu_credits_asserted;
	  events_mon6_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon6_in2 = cxp2sbu_credits_deasserted;
	  events_mon6_in2_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon6_in2 = nica_events[0];
	  events_mon6_in2_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon6_in2 = nica_events[1];
	  events_mon6_in2_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon6_in2 = nica_events[2];
	  events_mon6_in2_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon6_in2 = nica_events[3];
	  events_mon6_in2_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon6_in2 = nica_events[4];
	  events_mon6_in2_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon6_in2 = nica_events[5];
	  events_mon6_in2_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon6_in2 = nica_events[6];
	  events_mon6_in2_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon6_in2 = nica_events[7];
	  events_mon6_in2_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon6_in2 = count_events[0];
	  events_mon6_in2_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon6_in2 = count_events[1];
	  events_mon6_in2_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon6_in2 = sigmon_enable_event;
	  events_mon6_in2_en = 1'b1;
	end
      default: begin
	events_mon6_in2 = 1'b0;;
	events_mon6_in2_en = 1'b0;
      end
    endcase
  end

//event_mon7
  always @(*) begin
    //event_mon7, first input:
    case (sigmon_ctrl5[21:16]) 
      NO_EVENT:
	begin
	  events_mon7_in1 = 1'b0;
	  events_mon7_in1_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon7_in1 = 1'b1;
	  events_mon7_in1_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon7_in1 = 1'b0;
	  events_mon7_in1_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon7_in1 = sbu2nwpfifo_sop;
	  events_mon7_in1_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon7_in1 = sbu2nwpfifo_eop;
	  events_mon7_in1_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon7_in1 = sbu2nwp_sop;
	  events_mon7_in1_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon7_in1 = sbu2nwp_eop;
	  events_mon7_in1_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon7_in1 = nwp2sbu_sop;
	  events_mon7_in1_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon7_in1 = nwp2sbu_eop;
	  events_mon7_in1_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon7_in1 = sbu2cxpfifo_sop;
	  events_mon7_in1_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon7_in1 = sbu2cxpfifo_eop;
	  events_mon7_in1_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon7_in1 = sbu2cxp_sop;
	  events_mon7_in1_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon7_in1 = sbu2cxp_eop;
	  events_mon7_in1_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon7_in1 = cxp2sbu_sop;
	  events_mon7_in1_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon7_in1 = cxp2sbu_eop;
	  events_mon7_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon7_in1 = nwp2sbu_credits_asserted;
	  events_mon7_in1_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon7_in1 = nwp2sbu_credits_deasserted;
	  events_mon7_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon7_in1 = cxp2sbu_credits_asserted;
	  events_mon7_in1_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon7_in1 = cxp2sbu_credits_deasserted;
	  events_mon7_in1_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon7_in1 = nica_events[0];
	  events_mon7_in1_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon7_in1 = nica_events[1];
	  events_mon7_in1_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon7_in1 = nica_events[2];
	  events_mon7_in1_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon7_in1 = nica_events[3];
	  events_mon7_in1_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon7_in1 = nica_events[4];
	  events_mon7_in1_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon7_in1 = nica_events[5];
	  events_mon7_in1_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon7_in1 = nica_events[6];
	  events_mon7_in1_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon7_in1 = nica_events[7];
	  events_mon7_in1_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon7_in1 = count_events[0];
	  events_mon7_in1_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon7_in1 = count_events[1];
	  events_mon7_in1_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon7_in1 = sigmon_enable_event;
	  events_mon7_in1_en = 1'b1;
	end
      default: begin
	events_mon7_in1 = 1'b0;;
	events_mon7_in1_en = 1'b0;
      end
    endcase

    //event_mon7, second input:
    case (sigmon_ctrl5[29:24]) 
      NO_EVENT:
	begin
	  events_mon7_in2 = 1'b0;
	  events_mon7_in2_en = 1'b0;
	end
      EVENT_TRUE:
	begin
	  events_mon7_in2 = 1'b1;
	  events_mon7_in2_en = 1'b1;
	end
      EVENT_FALSE:
	begin
	  events_mon7_in2 = 1'b0;
	  events_mon7_in2_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  events_mon7_in2 = sbu2nwpfifo_sop;
	  events_mon7_in2_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  events_mon7_in2 = sbu2nwpfifo_eop;
	  events_mon7_in2_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  events_mon7_in2 = sbu2nwp_sop;
	  events_mon7_in2_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  events_mon7_in2 = sbu2nwp_eop;
	  events_mon7_in2_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  events_mon7_in2 = nwp2sbu_sop;
	  events_mon7_in2_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  events_mon7_in2 = nwp2sbu_eop;
	  events_mon7_in2_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  events_mon7_in2 = sbu2cxpfifo_sop;
	  events_mon7_in2_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  events_mon7_in2 = sbu2cxpfifo_eop;
	  events_mon7_in2_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  events_mon7_in2 = sbu2cxp_sop;
	  events_mon7_in2_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  events_mon7_in2 = sbu2cxp_eop;
	  events_mon7_in2_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  events_mon7_in2 = cxp2sbu_sop;
	  events_mon7_in2_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  events_mon7_in2 = cxp2sbu_eop;
	  events_mon7_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  events_mon7_in2 = nwp2sbu_credits_asserted;
	  events_mon7_in2_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  events_mon7_in2 = nwp2sbu_credits_deasserted;
	  events_mon7_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  events_mon7_in2 = cxp2sbu_credits_asserted;
	  events_mon7_in2_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  events_mon7_in2 = cxp2sbu_credits_deasserted;
	  events_mon7_in2_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  events_mon7_in2 = nica_events[0];
	  events_mon7_in2_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  events_mon7_in2 = nica_events[1];
	  events_mon7_in2_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  events_mon7_in2 = nica_events[2];
	  events_mon7_in2_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  events_mon7_in2 = nica_events[3];
	  events_mon7_in2_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  events_mon7_in2 = nica_events[4];
	  events_mon7_in2_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  events_mon7_in2 = nica_events[5];
	  events_mon7_in2_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  events_mon7_in2 = nica_events[6];
	  events_mon7_in2_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  events_mon7_in2 = nica_events[7];
	  events_mon7_in2_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  events_mon7_in2 = count_events[0];
	  events_mon7_in2_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  events_mon7_in2 = count_events[1];
	  events_mon7_in2_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  events_mon7_in2 = sigmon_enable_event;
	  events_mon7_in2_en = 1'b1;
	end
      default: begin
	events_mon7_in2 = 1'b0;
	events_mon7_in2_en = 1'b0;
      end
    endcase
  end


  //count0:
  always @(*) begin
    //count0, enable input:
    case (sigmon_ctrl6[5:0]) 
      NO_EVENT:
	begin
	  count0_enable = 1'b0;
	end
      EVENT_TRUE:
	begin
	  count0_enable = 1'b1;
	end
      EVENT_FALSE:
	begin
	  count0_enable = 1'b0;
	end
      SBU2NWPFIFO_SOP:
	begin
	  count0_enable = sbu2nwpfifo_sop;
	end
      SBU2NWPFIFO_EOP:
	begin
	  count0_enable = sbu2nwpfifo_eop;
	end
      SBU2NWP_SOP:
	begin
	  count0_enable = sbu2nwp_sop;
	end
      SBU2NWP_EOP:
	begin
	  count0_enable = sbu2nwp_eop;
	end
      NWP2SBU_SOP:
	begin
	  count0_enable = nwp2sbu_sop;
	end
      NWP2SBU_EOP:
	begin
	  count0_enable = nwp2sbu_eop;
	end
      SBU2CXPFIFO_SOP:
	begin
	  count0_enable = sbu2cxpfifo_sop;
	end
      SBU2CXPFIFO_EOP:
	begin
	  count0_enable = sbu2cxpfifo_eop;
	end
      SBU2CXP_SOP:
	begin
	  count0_enable = sbu2cxp_sop;
	end
      SBU2CXP_EOP:
	begin
	  count0_enable = sbu2cxp_eop;
	end
      CXP2SBU_SOP:
	begin
	  count0_enable = cxp2sbu_sop;
	end
      CXP2SBU_EOP:
	begin
	  count0_enable = cxp2sbu_eop;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  count0_enable = nwp2sbu_credits_asserted;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  count0_enable = nwp2sbu_credits_deasserted;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  count0_enable = cxp2sbu_credits_asserted;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  count0_enable = cxp2sbu_credits_deasserted;
	end
      NICA_EVENT0:
	begin
	  count0_enable = nica_events[0];
	end
      NICA_EVENT1:
	begin
	  count0_enable = nica_events[1];
	end
      NICA_EVENT2:
	begin
	  count0_enable = nica_events[2];
	end
      NICA_EVENT3:
	begin
	  count0_enable = nica_events[3];
	end
      NICA_EVENT4:
	begin
	  count0_enable = nica_events[4];
	end
      NICA_EVENT5:
	begin
	  count0_enable = nica_events[5];
	end
      NICA_EVENT6:
	begin
	  count0_enable = nica_events[6];
	end
      NICA_EVENT7:
	begin
	  count0_enable = nica_events[7];
	end
// No sense to feed back its own event:
//      LOCAL_EVENT0:
//	begin
//	  count0_enable = count_events[0];
//	end
      LOCAL_EVENT1:
	begin
	  count0_enable = count_events[1];
	end
      SIGMON_ENABLED:
	begin
	  count0_enable = sigmon_enable_event;
	end
      default: begin
	count0_enable = 1'b0;;
      end
    endcase

    //count0, event input:
    case (sigmon_ctrl6[13:8]) 
      NO_EVENT:
	begin
	  count0_event = 1'b0;
	end
      EVENT_TRUE:
	begin
	  count0_event = 1'b1;
	end
      EVENT_FALSE:
	begin
	  count0_event = 1'b0;
	end
      SBU2NWPFIFO_SOP:
	begin
	  count0_event = sbu2nwpfifo_sop;
	end
      SBU2NWPFIFO_EOP:
	begin
	  count0_event = sbu2nwpfifo_eop;
	end
      SBU2NWP_SOP:
	begin
	  count0_event = sbu2nwp_sop;
	end
      SBU2NWP_EOP:
	begin
	  count0_event = sbu2nwp_eop;
	end
      NWP2SBU_SOP:
	begin
	  count0_event = nwp2sbu_sop;
	end
      NWP2SBU_EOP:
	begin
	  count0_event = nwp2sbu_eop;
	end
      SBU2CXPFIFO_SOP:
	begin
	  count0_event = sbu2cxpfifo_sop;
	end
      SBU2CXPFIFO_EOP:
	begin
	  count0_event = sbu2cxpfifo_eop;
	end
      SBU2CXP_SOP:
	begin
	  count0_event = sbu2cxp_sop;
	end
      SBU2CXP_EOP:
	begin
	  count0_event = sbu2cxp_eop;
	end
      CXP2SBU_SOP:
	begin
	  count0_event = cxp2sbu_sop;
	end
      CXP2SBU_EOP:
	begin
	  count0_event = cxp2sbu_eop;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  count0_event = nwp2sbu_credits_asserted;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  count0_event = nwp2sbu_credits_deasserted;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  count0_event = cxp2sbu_credits_asserted;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  count0_event = cxp2sbu_credits_deasserted;
	end
      NICA_EVENT0:
	begin
	  count0_event = nica_events[0];
	end
      NICA_EVENT1:
	begin
	  count0_event = nica_events[1];
	end
      NICA_EVENT2:
	begin
	  count0_event = nica_events[2];
	end
      NICA_EVENT3:
	begin
	  count0_event = nica_events[3];
	end
      NICA_EVENT4:
	begin
	  count0_event = nica_events[4];
	end
      NICA_EVENT5:
	begin
	  count0_event = nica_events[5];
	end
      NICA_EVENT6:
	begin
	  count0_event = nica_events[6];
	end
      NICA_EVENT7:
	begin
	  count0_event = nica_events[7];
	end
// No sense to feed back its own event:
//      LOCAL_EVENT0:
//	begin
//	  count0_event = count_events[0];
//	end
      LOCAL_EVENT1:
	begin
	  count0_event = count_events[1];
	end
      SIGMON_ENABLED:
	begin
	  count0_event = sigmon_enable_event;
	end
      default: begin
	count0_event = 1'b0;
      end
    endcase
  end


  //count1:
  always @(*) begin
    //count1, enable input:
    case (sigmon_ctrl6[21:16]) 
      NO_EVENT:
	begin
	  count1_enable = 1'b0;
	end
      EVENT_TRUE:
	begin
	  count1_enable = 1'b1;
	end
      EVENT_FALSE:
	begin
	  count1_enable = 1'b0;
	end
      SBU2NWPFIFO_SOP:
	begin
	  count1_enable = sbu2nwpfifo_sop;
	end
      SBU2NWPFIFO_EOP:
	begin
	  count1_enable = sbu2nwpfifo_eop;
	end
      SBU2NWP_SOP:
	begin
	  count1_enable = sbu2nwp_sop;
	end
      SBU2NWP_EOP:
	begin
	  count1_enable = sbu2nwp_eop;
	end
      NWP2SBU_SOP:
	begin
	  count1_enable = nwp2sbu_sop;
	end
      NWP2SBU_EOP:
	begin
	  count1_enable = nwp2sbu_eop;
	end
      SBU2CXPFIFO_SOP:
	begin
	  count1_enable = sbu2cxpfifo_sop;
	end
      SBU2CXPFIFO_EOP:
	begin
	  count1_enable = sbu2cxpfifo_eop;
	end
      SBU2CXP_SOP:
	begin
	  count1_enable = sbu2cxp_sop;
	end
      SBU2CXP_EOP:
	begin
	  count1_enable = sbu2cxp_eop;
	end
      CXP2SBU_SOP:
	begin
	  count1_enable = cxp2sbu_sop;
	end
      CXP2SBU_EOP:
	begin
	  count1_enable = cxp2sbu_eop;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  count1_enable = nwp2sbu_credits_asserted;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  count1_enable = nwp2sbu_credits_deasserted;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  count1_enable = cxp2sbu_credits_asserted;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  count1_enable = cxp2sbu_credits_deasserted;
	end
      NICA_EVENT0:
	begin
	  count1_enable = nica_events[0];
	end
      NICA_EVENT1:
	begin
	  count1_enable = nica_events[1];
	end
      NICA_EVENT2:
	begin
	  count1_enable = nica_events[2];
	end
      NICA_EVENT3:
	begin
	  count1_enable = nica_events[3];
	end
      NICA_EVENT4:
	begin
	  count1_enable = nica_events[4];
	end
      NICA_EVENT5:
	begin
	  count1_enable = nica_events[5];
	end
      NICA_EVENT6:
	begin
	  count1_enable = nica_events[6];
	end
      NICA_EVENT7:
	begin
	  count1_enable = nica_events[7];
	end
      LOCAL_EVENT0:
	begin
	  count1_enable = count_events[0];
	end
// No sense to feed back its own event:
//      LOCAL_EVENT1:
//	begin
//	  count1_enable = count_events[1];
//	end
      SIGMON_ENABLED:
	begin
	  count1_enable = sigmon_enable_event;
	end
      default: begin
	count1_enable = 1'b0;;
      end
    endcase

    //count1, event input:
    case (sigmon_ctrl6[29:24]) 
      NO_EVENT:
	begin
	  count1_event = 1'b0;
	end
      EVENT_TRUE:
	begin
	  count1_event = 1'b1;
	end
      EVENT_FALSE:
	begin
	  count1_event = 1'b0;
	end
      SBU2NWPFIFO_SOP:
	begin
	  count1_event = sbu2nwpfifo_sop;
	end
      SBU2NWPFIFO_EOP:
	begin
	  count1_event = sbu2nwpfifo_eop;
	end
      SBU2NWP_SOP:
	begin
	  count1_event = sbu2nwp_sop;
	end
      SBU2NWP_EOP:
	begin
	  count1_event = sbu2nwp_eop;
	end
      NWP2SBU_SOP:
	begin
	  count1_event = nwp2sbu_sop;
	end
      NWP2SBU_EOP:
	begin
	  count1_event = nwp2sbu_eop;
	end
      SBU2CXPFIFO_SOP:
	begin
	  count1_event = sbu2cxpfifo_sop;
	end
      SBU2CXPFIFO_EOP:
	begin
	  count1_event = sbu2cxpfifo_eop;
	end
      SBU2CXP_SOP:
	begin
	  count1_event = sbu2cxp_sop;
	end
      SBU2CXP_EOP:
	begin
	  count1_event = sbu2cxp_eop;
	end
      CXP2SBU_SOP:
	begin
	  count1_event = cxp2sbu_sop;
	end
      CXP2SBU_EOP:
	begin
	  count1_event = cxp2sbu_eop;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  count1_event = nwp2sbu_credits_asserted;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  count1_event = nwp2sbu_credits_deasserted;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  count1_event = cxp2sbu_credits_asserted;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  count1_event = cxp2sbu_credits_deasserted;
	end
      NICA_EVENT0:
	begin
	  count1_event = nica_events[0];
	end
      NICA_EVENT1:
	begin
	  count1_event = nica_events[1];
	end
      NICA_EVENT2:
	begin
	  count1_event = nica_events[2];
	end
      NICA_EVENT3:
	begin
	  count1_event = nica_events[3];
	end
      NICA_EVENT4:
	begin
	  count1_event = nica_events[4];
	end
      NICA_EVENT5:
	begin
	  count1_event = nica_events[5];
	end
      NICA_EVENT6:
	begin
	  count1_event = nica_events[6];
	end
      NICA_EVENT7:
	begin
	  count1_event = nica_events[7];
	end
      LOCAL_EVENT0:
	begin
	  count1_event = count_events[0];
	end
// No sense to feed back its own event:
//      LOCAL_EVENT1:
//	begin
//	  count1_event = count_events[1];
//	end
      SIGMON_ENABLED:
	begin
	  count1_event = sigmon_enable_event;
	end
      default: begin
	count1_event = 1'b0;
      end
    endcase
  end

  
////////////////////////////////////////////////////////////////////////////////////////
// Event monitors: 
//
// Currently only 8 event monitors are implemented. 
// Each event monitor captures up to 2 events. However, these events must be mutually exclusive, such that will never trigger at the same time
// An example for such events: eop & sop of same axistream interface.  
// Another example: assert and deassert of a signal, such as lossless_has_credits
//
event_monitor  event_mon0 (
.clk(clk),
.reset(reset),
.event_enable(sigmon_ctrl1[31]),
.event1(events_mon0_in1),
.event1_en(events_mon0_in1_en),
.event2(events_mon0_in2),
.event2_en(events_mon0_in2_en),
.events_id(sigmon_ctrl2[15:0]),
.data_read(event_fifo_rd[0]),
.data_out(event0_fifo_data), 
.data_count(event0_fifo_data_count), 
.data_valid(events_valid[0]),
.data_loss(events_data_loss[0])
 );

event_monitor  event_mon1 (
.clk(clk),
.reset(reset),
.event_enable(sigmon_ctrl1[31]),
.event1(events_mon1_in1),
.event1_en(events_mon1_in1_en),
.event2(events_mon1_in2),
.event2_en(events_mon1_in2_en),
.events_id(sigmon_ctrl2[31:16]),
.data_read(event_fifo_rd[1]),
.data_out(event1_fifo_data), 
.data_count(event1_fifo_data_count), 
.data_valid(events_valid[1]),
.data_loss(events_data_loss[1])
 );

event_monitor  event_mon2 (
.clk(clk),
.reset(reset),
.event_enable(sigmon_ctrl1[31]),
.event1(events_mon2_in1),
.event1_en(events_mon2_in1_en),
.event2(events_mon2_in2),
.event2_en(events_mon2_in2_en),
.events_id(sigmon_ctrl3[15:0]),
.data_read(event_fifo_rd[2]),
.data_out(event2_fifo_data), 
.data_count(event2_fifo_data_count), 
.data_valid(events_valid[2]),
.data_loss(events_data_loss[2])
 );

event_monitor  event_mon3 (
.clk(clk),
.reset(reset),
.event_enable(sigmon_ctrl1[31]),
.event1(events_mon3_in1),
.event1_en(events_mon3_in1_en),
.event2(events_mon3_in2),
.event2_en(events_mon3_in2_en),
.events_id(sigmon_ctrl3[31:16]),
.data_read(event_fifo_rd[3]),
.data_out(event3_fifo_data), 
.data_count(event3_fifo_data_count), 
.data_valid(events_valid[3]),
.data_loss(events_data_loss[3])

 );

event_monitor  event_mon4 (
.clk(clk),
.reset(reset),
.event_enable(sigmon_ctrl1[31]),
.event1(events_mon4_in1),
.event1_en(events_mon4_in1_en),
.event2(events_mon4_in2),
.event2_en(events_mon4_in2_en),
.events_id(sigmon_ctrl4[15:0]),
.data_read(event_fifo_rd[4]),
.data_out(event4_fifo_data), 
.data_count(event4_fifo_data_count), 
.data_valid(events_valid[4]),
.data_loss(events_data_loss[4])
 );

event_monitor  event_mon5 (
.clk(clk),
.reset(reset),
.event_enable(sigmon_ctrl1[31]),
.event1(events_mon5_in1),
.event1_en(events_mon5_in1_en),
.event2(events_mon5_in2),
.event2_en(events_mon5_in2_en),
.events_id(sigmon_ctrl4[31:16]),
.data_read(event_fifo_rd[5]),
.data_out(event5_fifo_data), 
.data_count(event5_fifo_data_count), 
.data_valid(events_valid[5]),
.data_loss(events_data_loss[5])
 );

event_monitor  event_mon6 (
.clk(clk),
.reset(reset),
.event_enable(sigmon_ctrl1[31]),
.event1(events_mon6_in1),
.event1_en(events_mon6_in1_en),
.event2(events_mon6_in2),
.event2_en(events_mon6_in2_en),
.events_id(sigmon_ctrl5[15:0]),
.data_read(event_fifo_rd[6]),
.data_out(event6_fifo_data), 
.data_count(event6_fifo_data_count), 
.data_valid(events_valid[6]),
.data_loss(events_data_loss[6])
 );

event_monitor  event_mon7 (
.clk(clk),
.reset(reset),
.event_enable(sigmon_ctrl1[31]),
.event1(events_mon7_in1),
.event1_en(events_mon7_in1_en),
.event2(events_mon7_in2),
.event2_en(events_mon7_in2_en),
.events_id(sigmon_ctrl5[31:16]),
.data_read(event_fifo_rd[7]),
.data_out(event7_fifo_data), 
.data_count(event7_fifo_data_count), 
.data_valid(events_valid[7]),
.data_loss(events_data_loss[7])
 );


////////////////////////////////////////////////////////////////////////
// Load from the various events fifos to main sigmon fifo:
//

  localparam
    RW_IDLE                    = 2'd0,
    RW_SELECT                  = 2'd1,
    RW_DATA                    = 2'd2;

  reg [10:0] current_transfer_count;  
  reg [2:0]  rw_state;
//  reg [2:0]  rw_next;
  wire 	     more_events_valid;
  
  assign more_events_valid = (events_valid[7:0] > 0) ? 1'b1 : 1'b0;
  
	     
  always @(posedge clk) begin
    if (reset) begin
      sigmon_fifo_wr <= 1'b0;
      event_fifo_rd <= 8'b00000000;
      event_index <= 3'b000;
      rw_state <= RW_IDLE;
//      rw_next <= RW_IDLE;
    end
    else begin
//      rw_state <= rw_next;
      
      case (rw_state)
	RW_IDLE:
	  begin
	    sigmon_fifo_wr <= 1'b0;
	    event_fifo_rd <= 8'b00000000;
	    
	    if (more_events_valid) begin
	      event_index[2:0] <= next_event_index[2:0];
	      rw_state <= RW_SELECT;
	    end
	    else
	      rw_state <= RW_IDLE;
	  end
	
	RW_SELECT:
	  begin
	    sigmon_fifo_wr <= 1'b0;
	    event_fifo_rd <= 8'b00000000;
	    
	    // Limit transfer burst to 128 transfers max:
	    current_transfer_count[10:0] <= (event_fifo_data_count[10:0] > 128) ? 128 : event_fifo_data_count[10:0];
	    rw_state <= RW_DATA;
	  end
	
	RW_DATA:
	  begin
	    
	    //  read/write exactly current_transfer_count from selected event fifo 
	    if (~sigmon_fifo_full & (current_transfer_count[10:0] > 0)) begin
	      sigmon_fifo_wr <= 1'b1;
	      event_fifo_rd <= event_read;
	      current_transfer_count[10:0] <= current_transfer_count[10:0] - 1;
	      if (current_transfer_count[10:0] > 1)
		rw_state <= RW_DATA;
	      else
		rw_state <= RW_IDLE;
	    end
	    
//	    else if (more_events_valid)
//	      rw_state <= RW_SELECT;
//	    else
	    else
	      rw_state <= RW_IDLE;

	  end // case: RW_DATA
	
	default:
	  begin
	    sigmon_fifo_wr <= 1'b0;
	    event_fifo_rd <= 8'b00000000;
	    rw_state <= RW_IDLE;
	  end
	
      endcase

/*
      if (~sigmon_fifo_full) begin
	if (event_valid) begin
	  sigmon_fifo_wr <= 1'b1;
	  event_fifo_rd <= no_events ? 8'b00000000 : event_read;
	end
	else begin
	  event_fifo_rd <= 8'b00000000;
	  sigmon_fifo_wr <= 1'b0;
	end
	// The fifo_read state_machine always swith to handle next availabe event_mon data_valid
	event_index <= next_event_index;
      end
*/

    end
  end


// Main sigmon fifo: 64k x 32bit 
`ifdef FIFO_128K

sigmon_fifo_128Kx32b fifo_128Kx32b (
  .clk(clk),                           // input wire clk
  .srst(sigmon_reset),                 // input wire srst
  .din(sigmon_fifo_din),               // input wire [31 : 0] din
  .wr_en(sigmon_fifo_wr),              // input wire wr_en
  .rd_en(sigmon_fifo_rd),              // input wire rd_en
  .dout(sigmon_fifo_dout),             // output wire [31 : 0] dout
  .full(sigmon_fifo_full),             // output wire full
  .almost_full(almost_full),           // output wire almost_full
  .wr_ack(wr_ack),                     // output wire wr_ack
  .overflow(sigmon_fifo_overflow),     // output wire overflow
  .empty(sigmon_fifo_empty),           // output wire empty
  .almost_empty(almost_empty),         // output wire almost_empty
  .valid(sigmon_fifo_valid),           // output wire valid
  .underflow(sigmon_fifo_underflow),   // output wire underflow
  .data_count(sigmon_fifo_data_count[17:0]), // output wire [17 : 0] data_count
  .wr_rst_busy(wr_rst_busy),           // output wire wr_rst_busy
  .rd_rst_busy(rd_rst_busy)            // output wire rd_rst_busy
);
  
`else

sigmon_fifo_64Kx32b fifo_64Kx32b (
  .clk(clk),                           // input wire clk
  .srst(sigmon_reset),                 // input wire srst
  .din(sigmon_fifo_din),               // input wire [31 : 0] din
  .wr_en(sigmon_fifo_wr),              // input wire wr_en
  .rd_en(sigmon_fifo_rd),              // input wire rd_en
  .dout(sigmon_fifo_dout),             // output wire [31 : 0] dout
  .full(sigmon_fifo_full),             // output wire full
  .almost_full(almost_full),           // output wire almost_full
  .wr_ack(wr_ack),                     // output wire wr_ack
  .overflow(sigmon_fifo_overflow),     // output wire overflow
  .empty(sigmon_fifo_empty),           // output wire empty
  .almost_empty(almost_empty),         // output wire almost_empty
  .valid(sigmon_fifo_valid),           // output wire valid
  .underflow(sigmon_fifo_underflow),   // output wire underflow
  .data_count(sigmon_fifo_data_count[16:0]), // output wire [16 : 0] data_count
  .wr_rst_busy(wr_rst_busy),           // output wire wr_rst_busy
  .rd_rst_busy(rd_rst_busy)            // output wire rd_rst_busy
);

`endif

///////////////////////////////////////////////////////////////////////////
// Events & trigger:
//
// An event is a function of other events and/or other samples signals.
// A trigger is a selected event, to control the sliding sampling window
// A sliding sampling window is supported, to allow positioning the trigger at any point along the sampling window depth
//
// Sliding sampling window examples:
// Example 1: Trigger is at middle of the sampling window
//            Useful to see the activity before and after the trigger
// Sampling window depth: 0, 1, 2, ..., 32k, ..., 64k
//                                      ^
//                                      |
//                                      trigger           
//
// Example2: Trigger at the end of the sampling window
//           Useful to capture the sequence of events that led to the trigger event
//  Sampling window depth: 0, 1, 2, ..., 32k, ..., 64k
//                                                 ^
//                                                 |
//                                                 trigger           
//
// The trigger position along the sampling window is controlled via sigmon_ctrl1
// Accepted values: 0..64k 
  

// Select the desired trigger source. It can be either of the sampled signals, or any of the programmed events
  reg sigmon_trigger;
  reg sigmon_trigger_en;

  always @(*) begin
    case (sigmon_ctrl1[21:16]) 
      NO_EVENT:
	// trigger source selection is cleared
	// trigger source is set to sigmon enabled event (same as default setting)
	begin
	  sigmon_trigger = sigmon_enable_event;
	  sigmon_trigger_en = 1'b1;
	end
      SBU2NWPFIFO_SOP:
	begin
	  sigmon_trigger = sbu2nwpfifo_sop;
	  sigmon_trigger_en = 1'b1;
	end
      SBU2NWPFIFO_EOP:
	begin
	  sigmon_trigger = sbu2nwpfifo_eop;
	  sigmon_trigger_en = 1'b1;
	end
      SBU2NWP_SOP:
	begin
	  sigmon_trigger = sbu2nwp_sop;
	  sigmon_trigger_en = 1'b1;
	end
      SBU2NWP_EOP:
	begin
	  sigmon_trigger = sbu2nwp_eop;
	  sigmon_trigger_en = 1'b1;
	end
      NWP2SBU_SOP:
	begin
	  sigmon_trigger = nwp2sbu_sop;
	  sigmon_trigger_en = 1'b1;
	end
      NWP2SBU_EOP:
	begin
	  sigmon_trigger = nwp2sbu_eop;
	  sigmon_trigger_en = 1'b1;
	end
      SBU2CXPFIFO_SOP:
	begin
	  sigmon_trigger = sbu2cxpfifo_sop;
	  sigmon_trigger_en = 1'b1;
	end
      SBU2CXPFIFO_EOP:
	begin
	  sigmon_trigger = sbu2cxpfifo_eop;
	  sigmon_trigger_en = 1'b1;
	end
      SBU2CXP_SOP:
	begin
	  sigmon_trigger = sbu2cxp_sop;
	  sigmon_trigger_en = 1'b1;
	end
      SBU2CXP_EOP:
	begin
	  sigmon_trigger = sbu2cxp_eop;
	  sigmon_trigger_en = 1'b1;
	end
      CXP2SBU_SOP:
	begin
	  sigmon_trigger = cxp2sbu_sop;
	  sigmon_trigger_en = 1'b1;
	end
      CXP2SBU_EOP:
	begin
	  sigmon_trigger = cxp2sbu_eop;
	  sigmon_trigger_en = 1'b1;
	end
      NWP2SBU_CREDITS_ON:
	begin
	  sigmon_trigger = nwp2sbu_credits_asserted;
	  sigmon_trigger_en = 1'b1;
	end
      NWP2SBU_CREDITS_OFF:
	begin
	  sigmon_trigger = nwp2sbu_credits_deasserted;
	  sigmon_trigger_en = 1'b1;
	end
      CXP2SBU_CREDITS_ON:
	begin
	  sigmon_trigger = cxp2sbu_credits_asserted;
	  sigmon_trigger_en = 1'b1;
	end
      CXP2SBU_CREDITS_OFF:
	begin
	  sigmon_trigger = cxp2sbu_credits_deasserted;
	  sigmon_trigger_en = 1'b1;
	end
      NICA_EVENT0:
	begin
	  sigmon_trigger = nica_events[0];
	  sigmon_trigger_en = 1'b1;
	end
      NICA_EVENT1:
	begin
	  sigmon_trigger = nica_events[1];
	  sigmon_trigger_en = 1'b1;
	end
      NICA_EVENT2:
	begin
	  sigmon_trigger = nica_events[2];
	  sigmon_trigger_en = 1'b1;
	end
      NICA_EVENT3:
	begin
	  sigmon_trigger = nica_events[3];
	  sigmon_trigger_en = 1'b1;
	end
      NICA_EVENT4:
	begin
	  sigmon_trigger = nica_events[4];
	  sigmon_trigger_en = 1'b1;
	end
      NICA_EVENT5:
	begin
	  sigmon_trigger = nica_events[5];
	  sigmon_trigger_en = 1'b1;
	end
      NICA_EVENT6:
	begin
	  sigmon_trigger = nica_events[6];
	  sigmon_trigger_en = 1'b1;
	end
      NICA_EVENT7:
	begin
	  sigmon_trigger = nica_events[7];
	  sigmon_trigger_en = 1'b1;
	end
      LOCAL_EVENT0:
	begin
	  sigmon_trigger = count_events[0];
	  sigmon_trigger_en = 1'b1;
	end
      LOCAL_EVENT1:
	begin
	  sigmon_trigger = count_events[1];
	  sigmon_trigger_en = 1'b1;
	end
      SIGMON_ENABLED:
	begin
	  sigmon_trigger = sigmon_enable_event;
	  sigmon_trigger_en = 1'b1;
	end

      default: begin
	sigmon_trigger = sigmon_enable_event;
	sigmon_trigger_en = 1'b1;
      end
    endcase
  end // always @ begin

  
// sigmon_fifo_drop is used to drop entries from sigmon fifo, while waiting for the trigger
  reg sigmon_fifo_drop;
  reg trigger_occurred;
  assign sigmon_fifo_rd = sigmon_fifo_rd2axi | sigmon_fifo_drop;
  
  always @(posedge clk) begin
    if (reset) begin
      sigmon_fifo_drop <= 1'b0;
      trigger_occurred <= 1'b0;
    end
    else begin
      if (sigmon_ctrl1[31]) begin
	if (sigmon_trigger & sigmon_trigger_en)
	  // Will be cleared only at monitoring restart
	  trigger_occurred <= 1'b1;
	
`ifdef FIFO_128K
	if  (~trigger_occurred & (sigmon_fifo_data_count[16:0] > {sigmon_ctrl1[11:0], 5'b00000}))
`else
	if  (~trigger_occurred & (sigmon_fifo_data_count[15:0] > {sigmon_ctrl1[10:0], 5'b00000}))
`endif
	    // As long as trigger not occurred, keep dropping the fifo, to match the requested trigger position
	    sigmon_fifo_drop <= 1'b1;
	  else
	    sigmon_fifo_drop <= 1'b0;	
      end
    end
  end


//////////////////////////////////////////////////////////////////////////////////////////////////////
// Local Events
//

event_counter  event_counter0 (
.clk(clk),
.reset(reset),
.event_enable(sigmon_ctrl1[31]),
.event1(count0_enable),
.event2(count0_event),
.count_limit(sigmon_ctrl7[31:0]),
.data_out(count0_data), 
.event_out(count_events[0])
 );

event_counter  event_counter1 (
.clk(clk),
.reset(reset),
.event_enable(sigmon_ctrl1[31]),
.event1(count1_enable),
.event2(count1_event),
.count_limit(sigmon_ctrl8[31:0]),
.data_out(count1_data), 
.event_out(count_events[1])
 );
  
endmodule
