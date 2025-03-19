`timescale 1ns/1ps
module Truncate #(
    parameter WIDTH_IN = 1088,
    parameter MAX_L    = 256
)(
    input  wire clk,
    input  wire reset,
    input  wire truncate_start,    // start signal from Control Unit
    input  wire [WIDTH_IN-1:0] Z,  // input from Squeeze module
    output reg  [MAX_L-1:0]   Y,   // final digest output
    output reg                truncate_done
);

  always @(posedge clk) begin
    if (reset) begin
      Y              <= {MAX_L{1'b0}};
      truncate_done  <= 1'b0;
    end 
    else if (truncate_start) begin
      // Instead of taking the lower bits [MAX_L-1:0],
      // we take the top slice [WIDTH_IN-1 : WIDTH_IN - MAX_L].
      Y             <= Z[WIDTH_IN-1 : WIDTH_IN - MAX_L];
      truncate_done <= 1'b1;
      $display("Truncate Module: Output digest = %h", 
                Z[WIDTH_IN-1 : WIDTH_IN - MAX_L]);
    end 
    else begin
      truncate_done <= 1'b0;
    end
  end

endmodule
