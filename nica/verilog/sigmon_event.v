// Event Monitor: Handling a single event
// Gabi Malka, Technion, TCE
// June-2017

module event_monitor (
    input wire 	       clk,
    input wire 	       reset,
    input wire 	       event_enable,

// The event_monitor monitors the following events:
// These events are assumed mutex to each other: Such events, for instance, tlast and tfirst of same stream.
// Apply 0 to *_en, to disable. A disabled event will not generate any input to the local fifo
    input wire 	       event1,
    input wire 	       event1_en,
    input wire 	       event2,
    input wire 	       event2_en,
    input wire [15:0]   events_id,

    input wire 	       data_read,
    output wire [35:0] data_out, 
    output wire [10:0] data_count, 
    output wire        data_valid,
    output wire        data_loss
//    output wire        trigger_out   // aimed for cascading with other events, to end with a more complex trigger
);

localparam
  NO_EVENT = 0,
  EVENT1   = 1,
  EVENT2   = 2;

  reg event_fifo_wr;
  reg [47:0] event_time_counter;
  wire [10:0] event_fifo_data_count;
  wire [35:0] event_fifo_din;
  reg [35:0] event_fifo_dinQ;
  wire [35:0] event_fifo_dout;
  wire 	      event_fifo_valid;
  reg 	      event_fifo_data_lost;
  wire 	      event_fifo_full;
  wire 	      event_fifo_empty;
  wire 	      almost_full,wr_ack,overflow,almost_empty,underflow,wr_rst_busy,rd_rst_busy;
  reg 	      event_counter_enable;
  wire 	      event_fifo_reset;
  reg 	      event_enable_asserted;
  reg 	      event_enable_assertedQ;
  
  assign data_out = event_fifo_dout;
  assign data_count = event_fifo_data_count;
  assign fifo_full = event_fifo_full;
  assign event_fifo_reset = reset | event_enable_asserted;
  assign event_fifo_din = event_fifo_dinQ;

// Hide fifo_valid while reading last word: (to eliminate an extra read by sigmon_top, causing underflow)
//  assign data_valid = (data_read & (event_fifo_data_count == 1)) ? 1'b0 : event_fifo_valid;
//  assign data_valid = (event_fifo_data_count >= 4) ? event_fifo_valid : 1'b0;
  assign data_valid = event_fifo_valid;

  // there is an event to be written to the fifo, but was not written due to fifo full	
  // data_loss indicates that at least one write to the fifo has been rejected due to fifo full
  // This indicatiion will be cleared only upon next sigmon restart
  assign data_loss = event_fifo_data_lost;
  
  
// Look for event_enable assertion
always @(posedge clk) begin
  if (reset) begin
    event_enable_asserted <= 0;
    event_enable_assertedQ <= 0;
    event_counter_enable <= 0;    
  end
  else begin
    event_enable_assertedQ <= event_enable;

// event_ctrl1[31] assertion is used to reset both time stamp counter and the event_fifo
    if (event_enable & ~event_enable_assertedQ)
      event_enable_asserted <= 1;
    else 
      event_enable_asserted <= 0;

// event_time_counter is enabled two clocks after event is enabled,
// and disabled once event_enable has been dropped
    if (event_enable_asserted & event_enable_assertedQ)
      event_counter_enable <= 1;    
    if (~event_enable & event_enable_assertedQ)
      event_counter_enable <= 0;    
  end
end

  
  // Time stamp counter:
always @(posedge clk) begin
  if (reset | event_enable_asserted) begin
    event_time_counter <= 0;
  end
  else begin
    if (event_counter_enable) begin
      // What to do upon counter overflow...
      event_time_counter <= event_time_counter + 1;
    end
  end
end

// Write the captured event into the fifo
always @(posedge clk) begin
  if (reset | event_enable_asserted) begin
    event_fifo_wr <= 1'b0;
    event_fifo_data_lost <= 1'b0;
  end
  else begin
    if (event_counter_enable) begin
      if (event1 & event1_en | event2 & event2_en) begin
	if (~event_fifo_full) begin	
	  event_fifo_dinQ[23:0] <= event_time_counter[23:0];
	  event_fifo_dinQ[25:24] <= 3'b00;   // Place holder for time_stamp number_of_bytes
	  event_fifo_dinQ[31:26] <= (event1) ? events_id[5:0] : events_id[13:8];
	  event_fifo_dinQ[35:32] <= 4'b0001;
	  event_fifo_wr <= 1'b1;
	end
	else begin
	  // there is an event to be written tothe fifo, but was not written due to fifo full	
	  // We record this indication, to be read by the host via sigmon_status register
	  // This indicatiion will be cleared only upon next sigmon restart
	  event_fifo_data_lost <= 1'b1;
	  event_fifo_wr <= 1'b0;
	end
      end
      
      else
	event_fifo_wr <= 1'b0;
    end

    else
      event_fifo_wr <= 1'b0;
  end
end

////////////////////////////////////////////////////////////////////////////////////////
// Local fifo: 1K x 36bit
//
event_fifo_1Kx36b fifo_1Kx36b (
  .clk(clk),                           // input wire clk
  .srst(event_fifo_reset),             // input wire srst
  .din(event_fifo_din),                // input wire [35 : 0] din
  .wr_en(event_fifo_wr),               // input wire wr_en
  .rd_en(data_read),                   // input wire rd_en
  .dout(event_fifo_dout),              // output wire [35 : 0] dout
  .full(event_fifo_full),              // output wire full
  .almost_full(almost_full),           // output wire almost_full
  .wr_ack(wr_ack),                     // output wire wr_ack
  .overflow(overflow),                 // output wire overflow
  .empty(event_fifo_empty),            // output wire empty
  .almost_empty(almost_empty),         // output wire almost_empty
  .valid(event_fifo_valid),            // output wire valid
  .underflow(underflow),               // output wire underflow
  .data_count(event_fifo_data_count),  // output wire [10 : 0] data_count
  .wr_rst_busy(wr_rst_busy),           // output wire wr_rst_busy
  .rd_rst_busy(rd_rst_busy)            // output wire rd_rst_busy
);

endmodule
