`timescale 1ps/1ps
module DomainPad #(
    parameter RATE = 1088,       // Rate in bits for SHAKE256
    parameter [3:0] DOMAIN = 4'hF  // 4-bit domain separator (for SHAKE, 1111)
)(
    input  wire clk,
    input  wire reset,
    input  wire enable,             // When high, absorb serial_in
    input  wire serial_in,
    input  wire serial_end_signal,  // High when input is finished
    input  wire block_consumed,     // Signal from the sponge that the block was absorbed
    output reg  [RATE-1:0] message,
    output reg  valid_output,
    output reg  error_flag,
    output reg  pad_done,
    // Debug signals:
    output reg [2:0]  debug_pad_state,
    output reg [10:0] debug_pad_bitcount
);

    // FSM states for domain padding:
    localparam [2:0]
      STATE_INPUT  = 3'd0,  // Accumulate message bits
      STATE_DOMAIN = 3'd1,  // Append 4-bit domain separator
      STATE_PAD1   = 3'd2,  // Append the first '1'
      STATE_PAD0   = 3'd3,  // Append zeros
      STATE_PAD2   = 3'd4,  // Append final '1'
      STATE_DONE   = 3'd5,  // Padding complete
      STATE_WAIT   = 3'd6;  // Waiting for block to be consumed

    reg [2:0] state;
    reg [10:0] bit_count;    // Bit counter for the output block
    reg [1:0] domain_index;  // Counter for the 4 domain bits

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            message        <= {RATE{1'b0}};
            valid_output   <= 1'b0;
            error_flag     <= 1'b0;
            pad_done       <= 1'b0;
            bit_count      <= 0;
            domain_index   <= 0;
            state          <= STATE_INPUT;
        end else begin
            case (state)
                // -------------------------------
                // STATE_INPUT: Absorb incoming message bits.
                // -------------------------------
                STATE_INPUT: begin
                    if (enable && !serial_end_signal) begin
                        if (bit_count < RATE) begin
                            message[bit_count] <= serial_in;
                            bit_count <= bit_count + 1;
                        end else begin
                            error_flag <= 1'b1;
                            state <= STATE_DONE;
                        end
                    end
                    if (serial_end_signal) begin
                        state <= STATE_DOMAIN;
                        domain_index <= 0;
                    end
                end

                // -------------------------------
                // STATE_DOMAIN: Append the 4-bit domain separator, one bit per cycle.
                // -------------------------------
                STATE_DOMAIN: begin
                    if ((bit_count < RATE) && (domain_index < 4)) begin
                        message[bit_count] <= DOMAIN[domain_index];
                        bit_count <= bit_count + 1;
                        domain_index <= domain_index + 1;
                        if (domain_index == 3) begin
                            state <= STATE_PAD1;
                        end
                    end else if (bit_count + (4 - domain_index) > RATE) begin
                        error_flag <= 1'b1;
                        state <= STATE_DONE;
                    end
                end

                // -------------------------------
                // STATE_PAD1: Append a single '1' (the beginning of pad10*1).
                // -------------------------------
                STATE_PAD1: begin
                    if (bit_count < RATE) begin
                        message[bit_count] <= 1'b1;
                        bit_count <= bit_count + 1;
                        state <= STATE_PAD0;
                    end else begin
                        error_flag <= 1'b1;
                        state <= STATE_DONE;
                    end
                end

                // -------------------------------
                // STATE_PAD0: Append zeros until we reach the second-to-last bit.
                // -------------------------------
                STATE_PAD0: begin
                    if (bit_count < RATE - 1) begin
                        message[bit_count] <= 1'b0;
                        bit_count <= bit_count + 1;
                    end else begin
                        state <= STATE_PAD2;
                    end
                end

                // -------------------------------
                // STATE_PAD2: Append the final '1' to complete the pad.
                // -------------------------------
                STATE_PAD2: begin
                    if (bit_count == RATE - 1) begin
                        message[RATE-1] <= 1'b1;
                        bit_count <= bit_count + 1;
                        state <= STATE_DONE;
                    end else begin
                        error_flag <= 1'b1;
                        state <= STATE_DONE;
                    end
                end

                // -------------------------------
                // STATE_DONE: The padded block is ready.
                // -------------------------------
                STATE_DONE: begin
                    valid_output <= 1'b1;
                    pad_done <= 1'b1;
                    if (block_consumed) begin
                        valid_output <= 1'b0;
                        state <= STATE_WAIT;
                    end
                end

                // -------------------------------
                // STATE_WAIT: Wait until a new block is to be absorbed.
                // -------------------------------
                STATE_WAIT: begin
                    state <= STATE_WAIT;
                end

                default: state <= STATE_DONE;
            endcase
        end
    end

    // Drive the debug outputs.
    always @(*) begin
        debug_pad_state = state;
        debug_pad_bitcount = bit_count;
    end

endmodule
