`timescale 1ns/1ps
module Message_Accumulator #(
    parameter RATE_BITS = 1088
)(
    input  wire              clk,
    input  wire              reset,
    
    // Control signals
    input  wire              accumulate_start,  // from control: begin collecting next block
    input  wire              enable_2bit,       // each cycle we read 2 bits
    input  wire [1:0]        serial_in,
    input  wire              serial_end_signal, // user says no more data in message
    input  wire              is_final_chunk,    // if it's the final block for entire message

    // Outputs
    output wire              block_ready,       // 1 if we have a complete block or final partial
    output wire [RATE_BITS-1:0] block_data,     // the final 1088-bit block
    output wire              partial_block      // 1 if it's a partial block (didn't fill the full 1088 bits)
);

  // We store up to RATE_BITS in an array. 1088 bits => 136 bytes
  localparam BYTES_PER_BLOCK = RATE_BITS / 8; // 136

  // FSM states
  localparam [2:0]
    ST_IDLE   = 3'd0,
    ST_COLLECT= 3'd1,
    ST_ENDING = 3'd2,
    ST_DONE   = 3'd3;

  reg [2:0] state, next_state;

  // We keep the data in a small memory buffer or array
  // "buffer_mem[i]" holds the i-th byte
  reg [7:0] buffer_mem [0:BYTES_PER_BLOCK-1];

  // Indices and partial accumulators
  reg [10:0] byte_index;    // which byte we're writing (0..135)
  reg [1:0]  chunk_count;   // how many 2-bit chunks are in temp_byte
  reg [7:0]  temp_byte;     // accumulate 2 bits at a time

  // We'll build final outputs in "block_data_reg" at the end
  reg                       block_ready_reg;
  reg [RATE_BITS-1:0]       block_data_reg;
  reg                       partial_block_reg;

  // -------------------------
  //   Declare loop variables here (not inline)
  // -------------------------
  integer i, j;

  // ========================
  //   FSM Sequential
  // ========================
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= ST_IDLE;

      // Clear outputs
      block_ready_reg   <= 1'b0;
      block_data_reg    <= {RATE_BITS{1'b0}};
      partial_block_reg <= 1'b0;

      // Clear memory
      for (i=0; i<BYTES_PER_BLOCK; i=i+1)
        buffer_mem[i] <= 8'h00;

      byte_index  <= 11'd0;
      chunk_count <= 2'd0;
      temp_byte   <= 8'h00;

    end else begin
      state <= next_state;

      case (state)

        ST_IDLE: begin
          block_ready_reg   <= 1'b0;
          if (accumulate_start) begin
            // Clear memory
            for (i=0; i<BYTES_PER_BLOCK; i=i+1)
              buffer_mem[i] <= 8'h00;
            byte_index  <= 0;
            chunk_count <= 0;
            temp_byte   <= 8'h00;
          end
        end

        ST_COLLECT: begin
          // If enable_2bit=1, latch 2 bits
          if (enable_2bit) begin
            // LSB-first approach: place serial_in in the chunk_count'th 2-bit region
            temp_byte[2*chunk_count +: 2] <= serial_in;
            chunk_count <= chunk_count + 1'b1;
            
            // Once chunk_count=3 => we have 4 sub-chunks => 8 bits
            if (chunk_count == 2'd3) begin
              buffer_mem[byte_index] <= temp_byte;
              byte_index  <= byte_index + 1'b1;
              temp_byte   <= 8'h00;
              chunk_count <= 2'd0;
            end
          end

          // If we have filled 136 bytes => the block is full
          if (byte_index == BYTES_PER_BLOCK) begin
            // We'll finalize in ST_ENDING or ST_DONE
          end

          // If user says "no more data in entire message," 
          // we must finalize this block with domain separation nibble
          if (serial_end_signal) begin
            // Maybe partial leftover
          end
        end

        ST_ENDING: begin
          // If chunk_count != 0, store partial leftover
          if (chunk_count != 0) begin
            buffer_mem[byte_index] <= temp_byte;
            byte_index  <= byte_index + 1'b1;
            temp_byte   <= 8'h00;
            chunk_count <= 0;
          end
          
          // If "is_final_chunk=1", we do domain separation nibble 0x1F
          // fill up with 00..00, last byte => 0x80
          if (is_final_chunk) begin
            // Place 0x1F if there's room
            if (byte_index < BYTES_PER_BLOCK) begin
              buffer_mem[byte_index] <= 8'h1F;
              byte_index = byte_index + 1;
            end

            // zero fill until last byte
            for (j = byte_index; j < (BYTES_PER_BLOCK -1); j=j+1) begin
              buffer_mem[j] <= 8'h00;
            end

            // last byte => 0x80
            buffer_mem[BYTES_PER_BLOCK-1] <= 8'h80;
          end
        end

        ST_DONE: begin
          // Construct final 1088-bit block from buffer_mem
          // (If we try to do it in the same clock as ST_ENDING, 
          //  old quartus might complain about for-loops. 
          //  So we do it here in ST_DONE or in a separate always block.)
          for (j=0; j<BYTES_PER_BLOCK; j=j+1) begin
            block_data_reg[8*j +: 8] <= buffer_mem[j];
          end
          partial_block_reg <= (byte_index < BYTES_PER_BLOCK);
          block_ready_reg   <= 1'b1; // next cycle the control sees it
        end

      endcase
    end
  end

  // ========================
  //   Next-state Logic
  // ========================
  always @* begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        if (accumulate_start)
          next_state = ST_COLLECT;
      end
      ST_COLLECT: begin
        // If the block is full => move on
        if (byte_index == BYTES_PER_BLOCK)
          next_state = ST_DONE;
        // If user ended => go finalize => then ST_DONE
        else if (serial_end_signal)
          next_state = ST_ENDING;
      end
      ST_ENDING: begin
        next_state = ST_DONE;
      end
      ST_DONE: begin
        // Usually we remain here until control picks up block_ready,
        // or we can do some handshake to move back to IDLE
        // For simplicity, just stay in ST_DONE. The control
        // will go "accumulate_start" next time => ST_IDLE.
      end
      default: next_state = ST_IDLE;
    endcase
  end

  // ========================
  //   Assign outputs
  // ========================
  assign block_ready   = block_ready_reg;
  assign block_data    = block_data_reg;
  assign partial_block = partial_block_reg;

endmodule
