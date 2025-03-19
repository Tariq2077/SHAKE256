`timescale 1ns/1ps
module Convert_Digest #(
    parameter WIDTH_IN = 1088  // Must be a multiple of 8.
)(
    input  wire clk,
    input  wire reset,
    input  wire convert_start,    // One-cycle pulse to trigger conversion
    input  wire [WIDTH_IN-1:0] Z,   // Input data (WIDTH_IN bits)
    output reg [WIDTH_IN-1:0] Y,    // Final output after conversion
    output reg convert_done       // One-cycle pulse when conversion is complete
);

  // Calculate number of bytes.
  localparam NUM_BYTES = WIDTH_IN / 8;
  
  // FSM states.
  localparam STATE_IDLE    = 3'd0,
             STATE_SWAP1   = 3'd1,
             STATE_REVERSE = 3'd2,
             STATE_SWAP2   = 3'd3,
             STATE_DONE    = 3'd4;
  
  reg [2:0] state, next_state;
  integer i;
  
  // Intermediate registers.
  reg [WIDTH_IN-1:0] swapped1;  // Result of first nibble swap
  reg [WIDTH_IN-1:0] reversed;  // Result after byte reversal
  reg [WIDTH_IN-1:0] swapped2;  // Result after second nibble swap

  // FSM sequential update.
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= STATE_IDLE;
      Y <= {WIDTH_IN{1'b0}};
     // convert_done <= 1'b0;
    end else begin
      state <= next_state;
      if (state == STATE_DONE)
        Y <= swapped2;
    end
  end
  
  // FSM combinational next-state logic.
  always @(*) begin
    case (state)
      STATE_IDLE: begin
        if (convert_start)
          next_state = STATE_SWAP1;
        else
          next_state = STATE_IDLE;
      end
      STATE_SWAP1: next_state = STATE_REVERSE;
      STATE_REVERSE: next_state = STATE_SWAP2;
      STATE_SWAP2: next_state = STATE_DONE;
      STATE_DONE: next_state = STATE_IDLE;
      default: next_state = STATE_IDLE;
    endcase
  end
  
  // Processing steps.
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      swapped1 <= {WIDTH_IN{1'b0}};
      reversed <= {WIDTH_IN{1'b0}};
      swapped2 <= {WIDTH_IN{1'b0}};
      convert_done <= 1'b0;
    end else begin
      case (state)
        STATE_SWAP1: begin
		  //$display("[CONVERT] Squeeze Output Before Conversion: %h", Z);

          // For each byte in Z, swap its nibbles.
          for (i = 0; i < NUM_BYTES; i = i + 1) begin
            swapped1[8*i +: 8] <= { Z[8*i+3 -: 4], Z[8*i+7 -: 4] };
          end
          //$display("DEBUG: [SWAP1] Nibble-swapped result = %h", swapped1);
        end
        
        STATE_REVERSE: begin
          // Reverse the order of the bytes in swapped1.
          for (i = 0; i < NUM_BYTES; i = i + 1) begin
            reversed[8*(NUM_BYTES-1-i) +: 8] <= swapped1[8*i +: 8];
          end
          //$display("DEBUG: [REVERSE] Byte-reversed result = %h", reversed);
        end
        
        STATE_SWAP2: begin
          // Swap the nibbles in each byte of the reversed result.
          for (i = 0; i < NUM_BYTES; i = i + 1) begin
            swapped2[8*i +: 8] <= { reversed[8*i+3 -: 4], reversed[8*i+7 -: 4] };
          end
          //$display("DEBUG: [SWAP2] Final nibble-swapped result = %h", swapped2);
        end
        
        STATE_DONE: begin
          convert_done <= 1'b1;
          $display("DEBUG: Final Converted Output = %h", swapped2);
        end
        
        default: ;
      endcase
    end
  end

endmodule
