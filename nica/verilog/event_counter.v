// Event Monitor: Handling a single event
// Gabi Malka, Technion, TCE
// June-2017

module event_counter (
    input wire 	       clk,
    input wire 	       reset,
    input wire 	       event_enable,

// The event_monitor monitors the following events:
// These events are assumed mutex to each other: Such events, for instance, tlast and tfirst of same stream.
// Apply 0 to *_en, to disable. A disabled event will not generate any input to the local fifo
    input wire 	       event1,
    input wire 	       event2,
    input [31:0]       count_limit,

    output wire [31:0] data_out, 
    output wire        event_out
);

localparam
  NO_EVENT = 0,
  EVENT1   = 1,
  EVENT2   = 2;

  reg 		       event_enable_asserted;
  reg 		       event_enable_assertedQ;
  reg 		       event_counter_enabled;
  reg 		       event_outQ;
  reg [31:0] 	       event_counter;
  

  assign data_out = event_counter;
  assign event_out = event_outQ;

  
// Look for event_enable assertion
always @(posedge clk) begin
  if (reset) begin
    event_enable_asserted <= 0;
    event_enable_assertedQ <= 0;
  end
  else begin
    event_enable_assertedQ <= event_enable;

// event_ctrl1[31] assertion is used to reset both time stamp counter and the event_fifo
    if (event_enable & ~event_enable_assertedQ)
      event_enable_asserted <= 1;
    else 
      event_enable_asserted <= 0;
  end
end

always @(posedge clk) begin
  if (reset | event_enable_asserted) begin
    event_outQ <= 0;
    event_counter <= 0;
    event_counter_enabled <= 1'b0;
  end
  else begin
    if (event1)
      event_counter_enabled <= 1'b1;
    
    if (event_counter_enabled & event2)
      event_counter <= event_counter + 1;
    
    if (event_counter_enabled & (event_counter >= count_limit)) begin

// Once limit reached, the counter stops counting, and this event is reported with event_out
      event_outQ <= 1'b1;
      event_counter_enabled <= 1'b0;
    end

    if (event_outQ)
      event_outQ <= 1'b0;
    
  end
end
  
endmodule
