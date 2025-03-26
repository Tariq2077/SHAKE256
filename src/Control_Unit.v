`timescale 1ns/1ps
module Control_Unit #(
    // Maximum number of blocks to process we can adjust it based on our hardware power.
    parameter MAX_BLOCKS = 10  
)(
    input  wire clk,
    input  wire reset,
    input  wire start,             // External start signal
    input  wire pad_done,          // From Pad module: asserted when final block is padded
    input  wire block_ready,       // From Pad module: asserted when a full (nonfinal) block is ready
    input  wire absorb_done,       // From Absorb module
    input  wire squeeze_done,      // From Squeeze module
    input  wire convert_done,      // From Convert_Digest module
    input  wire truncate_done,     // From Truncate module
    output reg pad_start,          // One-cycle pulse to trigger Pad module
    output reg next_block,         // One-cycle pulse to tell Pad to clear and start next block
    output reg absorb_start,       // One-cycle pulse to trigger Absorb module
    output reg squeeze_start,      // One-cycle pulse to trigger Squeeze module
    output reg convert_start,      // One-cycle pulse to trigger Convert_Digest module
    output reg truncate_start,     // One-cycle pulse to trigger Truncate module
    output reg encryption_done,    // Held high when finished processing
    output reg overflow,           // Asserted if input exceeds MAX_BLOCKS (i.e. some blocks are dropped)
    output reg [3:0] debug_ctrl_state  // Current FSM state for debugging
);

  // FSM states for multi‐block operation.
  // (In our design, after a block is padded, we wait and then absorb it.
  //  If a full block is ready (block_ready) that means more input is available.)
  localparam [3:0]
    IDLE              = 4'd0,
    PAD_PULSE         = 4'd1,
    PAD_WAIT          = 4'd2,
    ABSORB_PULSE      = 4'd3,
    ABSORB_WAIT       = 4'd4,
    NEXT_BLOCK_PULSE  = 4'd5,
    NEXT_BLOCK_WAIT   = 4'd6,
    SQUEEZE_PULSE     = 4'd7,
    SQUEEZE_WAIT      = 4'd8,
    CONVERT_PULSE     = 4'd9,
    CONVERT_WAIT      = 4'd10,
    TRUNCATE_PULSE    = 4'd11,
    TRUNCATE_WAIT     = 4'd12,
    DONE              = 4'd13;

  reg [3:0] state, next_state;
  // "more_blocks" indicates that the current pad module has produced a full block,
  // and more input is coming.
  reg       more_blocks, next_more_blocks;
  // Count how many blocks have been absorbed so far.
  // The width is chosen to hold at least MAX_BLOCKS.
  reg [$clog2(MAX_BLOCKS+1)-1:0] block_count, next_block_count;

  // Sequential state update.
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= IDLE;
      more_blocks <= 1'b0;
      block_count <= 0;
      overflow <= 1'b0;
    end else begin
      state <= next_state;
      more_blocks <= next_more_blocks;
      block_count <= next_block_count;
      // Once block_count exceeds MAX_BLOCKS, set overflow flag.
      if (next_block_count > MAX_BLOCKS)
        overflow <= 1'b1;
    end
  end

  // Combinational logic for next state and control outputs.
  always @(*) begin
    // Default: deassert one-cycle pulses.
    pad_start      = 1'b0;
    next_block     = 1'b0;
    absorb_start   = 1'b0;
    squeeze_start  = 1'b0;
    convert_start  = 1'b0;
    truncate_start = 1'b0;
    encryption_done = 1'b0;
    next_state = state;
    // By default, keep the flag and block count unchanged.
    next_more_blocks = more_blocks;
    next_block_count = block_count;

    case (state)
      IDLE: begin
        if (start)
          next_state = PAD_PULSE;
        else
          next_state = IDLE;
      end

      PAD_PULSE: begin
        pad_start = 1'b1;
        next_state = PAD_WAIT;
      end

      PAD_WAIT: begin
        // Check the Pad module output:
        // - If pad_done is high then the current block is the final block.
        if (pad_done) begin
          next_more_blocks = 1'b0;
          next_state = ABSORB_PULSE;
        end 
        // - Else if block_ready is high then a full block is ready and more data follows.
        else if (block_ready) begin
          next_more_blocks = 1'b1;
          next_state = ABSORB_PULSE;
        end else begin
          next_state = PAD_WAIT;
        end
      end

      ABSORB_PULSE: begin
        absorb_start = 1'b1;
        next_state = ABSORB_WAIT;
      end

      ABSORB_WAIT: begin
        if (absorb_done) begin
          // Increment the block counter.
          next_block_count = block_count + 1;
          // If there are more blocks available and we have not reached our limit,
          // go to next_block pulse to clear the pad buffer.
          if (more_blocks && (block_count < MAX_BLOCKS))
            next_state = NEXT_BLOCK_PULSE;
          else
            next_state = SQUEEZE_PULSE;
        end else begin
          next_state = ABSORB_WAIT;
        end
      end

      NEXT_BLOCK_PULSE: begin
        next_block = 1'b1;
        next_state = NEXT_BLOCK_WAIT;
      end

      NEXT_BLOCK_WAIT: begin
        // Wait one cycle then return to PAD_PULSE for the next block.
        next_state = PAD_PULSE;
      end

      SQUEEZE_PULSE: begin
        squeeze_start = 1'b1;
        next_state = SQUEEZE_WAIT;
      end

      SQUEEZE_WAIT: begin
        if (squeeze_done)
          next_state = CONVERT_PULSE;
        else
          next_state = SQUEEZE_WAIT;
      end

      CONVERT_PULSE: begin
        convert_start = 1'b1;
        next_state = CONVERT_WAIT;
      end

      CONVERT_WAIT: begin
        if (convert_done)
          next_state = TRUNCATE_PULSE;
        else
          next_state = CONVERT_WAIT;
      end

      TRUNCATE_PULSE: begin
        truncate_start = 1'b1;
        next_state = TRUNCATE_WAIT;
      end

      TRUNCATE_WAIT: begin
        if (truncate_done)
          next_state = DONE;
        else
          next_state = TRUNCATE_WAIT;
      end

      DONE: begin
        encryption_done = 1'b1;
        next_state = DONE;
      end

      default: next_state = IDLE;
    endcase

    // Drive the debug output.
    debug_ctrl_state = state;
  end

endmodule
