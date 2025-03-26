`timescale 1ns/1ps
module SHAKE256 #(
  parameter STATE_WIDTH    = 1600,
  parameter RATE_WIDTH     = 1088,
  parameter CAPACITY_WIDTH = 512,
  parameter OUT_BITS       = 256
)(
  input  wire clk,
  input  wire reset,
  input  wire start,           
  input  wire enable,          // for Pad module serial input
  input  wire [1:0] serial_in,       
  input  wire serial_end_signal,
  output wire done,            
  output wire [OUT_BITS-1:0] digest,
  
  // Debug outputs:
  output wire [3:0] debug_ctrl_state,
  output wire [2:0] debug_pad_state,
  output wire [10:0] debug_pad_bytecount,
  output wire [RATE_WIDTH-1:0] debug_pad_out,
  output wire debug_absorb_state,
  output wire [10:0] debug_absorb_i,
  output wire [STATE_WIDTH-1:0] debug_absorb_state_full,
  output wire [RATE_WIDTH-1:0] debug_squeeze_data,
  output wire [RATE_WIDTH-1:0] debug_converted_data,
  output wire [STATE_WIDTH-1:0] debug_pre_perm  // Absorb debug signal
);

  // Internal control signals from Control Unit.
  wire pad_start;
  wire absorb_start;
  wire squeeze_start;
  wire convert_start;
  wire truncate_start;
  wire encryption_done;
  
  // Done signals from each stage.
  wire pad_done;
  wire absorb_done;
  wire squeeze_done;
  wire convert_done;
  wire truncate_done;
  
  // Data paths between stages.
  wire [RATE_WIDTH-1:0] pad_out;
  wire [STATE_WIDTH-1:0] absorb_state; // Final state after Absorb (includes KeccakF1600)
  wire [RATE_WIDTH-1:0] squeeze_out;
  wire [RATE_WIDTH-1:0] converted_digest;
  wire [OUT_BITS-1:0] truncated_out;
  
  // Instantiate the Control Unit 
  Control_Unit cu (
    .clk(clk),
    .reset(reset),
    .start(start),
    .pad_done(pad_done),
    .absorb_done(absorb_done),
    .squeeze_done(squeeze_done),
	 .convert_done(convert_done),
    .truncate_done(truncate_done),
    .pad_start(pad_start),
    .absorb_start(absorb_start),
    .squeeze_start(squeeze_start),
	 .convert_start(convert_start),
    .truncate_start(truncate_start),
    .encryption_done(encryption_done),
    .debug_ctrl_state(debug_ctrl_state)
  );
  
  
pad #(.RANGE(1088)) pad_inst (
  .clk(clk),
  .reset(reset),
  .pad_start(pad_start),
  .next_block(1'b0),
  .enable(enable),
  .serial_in(serial_in),
  .serial_end_signal(serial_end_signal),
  .message(pad_out),
  .pad_done(pad_done),
  .debug_pad_state(debug_pad_state),
  .debug_pad_bytecount(debug_pad_bytecount)
);





  assign debug_pad_out = pad_out;
  
  // Latch the pad module's output.
  reg [RATE_WIDTH-1:0] pad_buffer;
  always @(posedge clk or posedge reset) begin
    if (reset)
      pad_buffer <= {RATE_WIDTH{1'b0}};
    else if (pad_done)
      pad_buffer <= pad_out;
  end
  
  // Instantiate the Absorb module (integrated with KeccakF1600)
  // It now provides a debug_pre_perm output that captures the state before permutation.
  Absorb absorb_inst (
    .clk(clk),
    .reset(reset),
    .absorb_start(absorb_start),
    .state_in({STATE_WIDTH{1'b0}}),  // initial sponge state is all zeros
    .Block({{(STATE_WIDTH - RATE_WIDTH){1'b0}}, pad_buffer}),
    .absorb_state_out(absorb_state),
    .absorb_done(absorb_done),
    .debug_absorb_state(debug_absorb_state),
    .debug_absorb_i(debug_absorb_i),
    .debug_pre_perm(debug_pre_perm)
  );
  assign debug_absorb_state_full = absorb_state;
  
  // Instantiate the Squeeze module.
  Squeeze_mod #(
    .RATE(RATE_WIDTH),
    .OUTPUT_WIDTH(RATE_WIDTH),
    .STATE_WIDTH(STATE_WIDTH)
  ) squeeze_inst (
    .clk(clk),
    .reset(reset),
    .squeeze_start(squeeze_start),
    .initial_state(absorb_state),
    .Squeezed_data(squeeze_out),
    .squeeze_done(squeeze_done)
  );
  assign debug_squeeze_data = squeeze_out;
  
   Convert_Digest #(
    .WIDTH_IN(RATE_WIDTH)  
    
  ) conv_inst (
    .clk(clk),
    .reset(reset),
    .convert_start(convert_start), // Triggered by the control unit.
    .Z(squeeze_out),
    .Y(converted_digest),
    .convert_done(convert_done)
  );

	assign debug_converted_data = converted_digest;
  
  // Instantiate the Truncate module.
  Truncate #(
    .WIDTH_IN(RATE_WIDTH),
    .MAX_L(OUT_BITS)
  ) truncate_inst (
    .clk(clk),
    .reset(reset),
    .truncate_start(truncate_start),
    .Z(converted_digest),
    .Y(truncated_out),
    .truncate_done(truncate_done)
  );
  
  // Final outputs.
  assign digest = truncated_out;
  assign done   = encryption_done;
  //always @(posedge clk) begin
  //$display("done is:", done, "       Trncate done is:", truncate_done, "      Convert done is:", convert_done, "     Squeeze done is:", squeeze_done, "    absorb done is:", absorb_done, "      pad done is:", pad_done);
  //end

endmodule