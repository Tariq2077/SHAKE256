`timescale 1ns/1ps
module SingleBlockAccumulator #(
    parameter RATE_BITS = 1088
)(
    input  wire             clk,
    input  wire             reset,

    // Control signals:
    //   accum_start       : 1-cycle pulse to begin collecting a new block
    //   enable_2bit       : if=1 each clock, read 2 bits from serial_in
    //   serial_in         : 2 bits of message data
    //   serial_end_signal : user signals no more data for this entire block
    input  wire             accum_start,
    input  wire             enable_2bit,
    input  wire [1:0]       serial_in,
    input  wire             serial_end_signal,

    // Outputs
    //   accum_done : 1 after we finalize the block
    //   block_out  : the final 1088-bit block with domain separation nibble
    output reg              accum_done,
    output reg [RATE_BITS-1:0] block_out
);

  // 1088 bits => 136 bytes
  localparam BYTES_PER_BLOCK = RATE_BITS / 8; // 136

  // We'll store the collected data in a small array of 136 bytes
  reg [7:0] buffer_mem [0:BYTES_PER_BLOCK-1];

  // Indices and partial accumulators
  reg [10:0] byte_index;  // 0..135
  reg [1:0]  chunk_count; // how many 2-bit lumps we have in temp_byte
  reg [7:0]  temp_byte;

  // Because older Verilog doesn't allow in-block integer declarations:
  integer i, j;

  // FSM states
  localparam [2:0]
    ST_IDLE   = 3'd0,
    ST_COLLECT= 3'd1,
    ST_PAD    = 3'd2,
    ST_DONE   = 3'd3;

  reg [2:0] state, next_state;

  //---------------------------------------------
  // 1) COMBINATIONAL: next_state logic
  //---------------------------------------------
  always @* begin
    // Default: remain in same state
    next_state = state;

    case (state)
      ST_IDLE: begin
        if (accum_start)
          next_state = ST_COLLECT;
      end

      ST_COLLECT: begin
        // If we have exactly filled the block or user ended => go to ST_PAD
        if ((byte_index == BYTES_PER_BLOCK) || serial_end_signal)
          next_state = ST_PAD;
      end

      ST_PAD: begin
        // Once we do the domain separation nibble & fill => go ST_DONE
        next_state = ST_DONE;
      end

      ST_DONE: begin
        // remain here until user triggers accum_start again
        // or the external control resets the module
      end

      default: next_state = ST_IDLE;
    endcase
  end


  //---------------------------------------------
  // 2) SEQUENTIAL: update state + regs
  //---------------------------------------------
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state       <= ST_IDLE;
      accum_done  <= 1'b0;
      block_out   <= {RATE_BITS{1'b0}};

      // Clear the buffer
      for(i=0; i<BYTES_PER_BLOCK; i=i+1) begin
        buffer_mem[i] <= 8'h00;
      end
      byte_index  <= 0;
      chunk_count <= 0;
      temp_byte   <= 8'h00;

    end else begin
      // Move to next state decided by combinational
      state <= next_state;

      case (state)

        //------------------------------------
        // ST_IDLE
        //------------------------------------
        ST_IDLE: begin
          accum_done <= 1'b0;
          if (accum_start) begin
            // The user starts a new block
            for(i=0; i<BYTES_PER_BLOCK; i=i+1) begin
              buffer_mem[i] <= 8'h00;
            end
            byte_index  <= 11'd0;
            chunk_count <= 2'd0;
            temp_byte   <= 8'h00;
          end
        end

        //------------------------------------
        // ST_COLLECT
        //------------------------------------
        ST_COLLECT: begin
          // If enable_2bit=1, read 2 bits from serial_in
          if (enable_2bit) begin
            // Place them LSB-first in temp_byte
            temp_byte[2*chunk_count +: 2] <= serial_in;
            chunk_count <= chunk_count + 1'b1;

            // Once chunk_count=3 => 4 sub-chunks => 8 bits
            if (chunk_count == 2'd3) begin
              if (byte_index < BYTES_PER_BLOCK) begin
                buffer_mem[byte_index] <= temp_byte;
                byte_index <= byte_index + 1'b1;
              end
              // If we exceed 136 bytes, we ignore further data
              temp_byte   <= 8'h00;
              chunk_count <= 2'd0;
            end
          end
        end

        //------------------------------------
        // ST_PAD
        //------------------------------------
        ST_PAD: begin
          // If we have leftover partial bits in temp_byte
          if ((chunk_count != 0) && (byte_index < BYTES_PER_BLOCK)) begin
            buffer_mem[byte_index] <= temp_byte;
            byte_index  <= byte_index + 1'b1;
            temp_byte   <= 8'h00;
            chunk_count <= 0;
          end

          // Domain separation nibble => 0x1F if there's still room
          if (byte_index < BYTES_PER_BLOCK) begin
            buffer_mem[byte_index] <= 8'h1F;
            byte_index <= byte_index + 1'b1;
          end

          // Fill up to last byte -1 with zeros (constant loop)
          for (j=0; j<(BYTES_PER_BLOCK -1); j=j+1) begin
            if (j >= byte_index) begin
              buffer_mem[j] <= 8'h00;
            end
          end

          // Last byte => 0x80
          buffer_mem[BYTES_PER_BLOCK - 1] <= 8'h80;
        end

        //------------------------------------
        // ST_DONE
        //------------------------------------
        ST_DONE: begin
          // Build the final 1088-bit block from buffer_mem
          for (j=0; j<BYTES_PER_BLOCK; j=j+1) begin
            block_out[8*j +: 8] <= buffer_mem[j];
          end
          accum_done <= 1'b1;
        end

      endcase
    end
  end

endmodule
