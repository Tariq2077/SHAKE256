//=====================================================================
// Module: Squeeze_mod
// Description: Extracts the lower RATE bits from the state.
//=====================================================================
`timescale 1ns/1ps
module Squeeze_mod #(
  parameter RATE = 1088,
  parameter OUTPUT_WIDTH = RATE,
  parameter STATE_WIDTH = 1600
)(
  input  wire clk,
  input  wire reset,
  input  wire squeeze_start,
  input  wire [STATE_WIDTH-1:0] initial_state,
  output reg [OUTPUT_WIDTH-1:0] Squeezed_data,
  output reg squeeze_done
);

  always @(posedge clk) begin
    if (reset) begin
      Squeezed_data <= {OUTPUT_WIDTH{1'b0}};
      squeeze_done  <= 1'b0;
    end else if (squeeze_start) begin
      Squeezed_data <= initial_state[OUTPUT_WIDTH-1:0];
      squeeze_done  <= 1'b1;
      //$display("Squeeze Module: Extracted bits = %h", initial_state[OUTPUT_WIDTH-1:0]);
    end else begin
      squeeze_done <= 1'b0;
    end
  end

endmodule