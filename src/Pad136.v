`timescale 1ns/1ps
module pad136(
    input  wire clk,
    input  wire reset,
    input  wire enable,
    input  wire serial_in,
    input  wire serial_end_signal,
    // New inputs for domain separation:
    input  wire domain_sep_enable, // When high, output the domain separator byte
    input  wire [7:0] domain_sep,   // The 8-bit domain separator value

    output reg [1087:0] message,    // 1088-bit (136-byte) output
    output reg valid_output,
    output reg error_flag,
    // Debug outputs:
    output reg [2:0]  debug_pad_state,
    output reg [10:0] debug_pad_bitcount
);

    // We now use a five‐state machine:
    // STATE_INPUT: Receive serial bits of the “raw” input.
    // STATE_PAD_BIT: (No domain sep) Append a single ‘1’ bit.
    // STATE_DOMAIN_SEP: (With domain sep) Append the 8-bit domain_sep serially.
    // STATE_PADDING_ZERO: Append zeros until the block is complete.
    // STATE_DONE: Final state.
    localparam [2:0] 
       STATE_INPUT        = 3'd0,
       STATE_PAD_BIT      = 3'd1,
       STATE_DOMAIN_SEP   = 3'd2,
       STATE_PADDING_ZERO = 3'd3,
       STATE_DONE         = 3'd4;

    reg [2:0] state;
    reg [10:0] bit_counter;  // counts from 0 to 1087
    reg [2:0] ds_bit_counter; // counts bits (0 to 7) when sending domain_sep

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            message       <= {1088{1'b0}};
            valid_output  <= 1'b0;
            error_flag    <= 1'b0;
            bit_counter   <= 0;
            ds_bit_counter<= 0;
            state         <= STATE_INPUT;
        end else if (enable) begin
            case (state)
                STATE_INPUT: begin
                    if (serial_end_signal) begin
                        if (domain_sep_enable) begin
                            // Begin transmitting the 8-bit domain_sep (LSB first)
                            ds_bit_counter <= 0;
                            state <= STATE_DOMAIN_SEP;
                        end else begin
                            state <= STATE_PAD_BIT;
                        end
                    end else begin
                        if (bit_counter < 1088) begin
                            message[bit_counter] <= serial_in;
                            bit_counter <= bit_counter + 1;
                        end else begin
                            error_flag <= 1; // input too long
                            state <= STATE_DONE;
                        end
                    end
                end

                // For SHAKE-like padding when no domain separation is needed:
                STATE_PAD_BIT: begin
                    if (bit_counter < 1088) begin
                        message[bit_counter] <= 1'b1;
                        bit_counter <= bit_counter + 1;
                        state <= STATE_PADDING_ZERO;
                    end else begin
                        error_flag <= 1;
                        state <= STATE_DONE;
                    end
                end

                // When domain_sep_enable is asserted, output the 8-bit domain_sep serially.
                STATE_DOMAIN_SEP: begin
                    if (bit_counter < 1088) begin
                        message[bit_counter] <= domain_sep[ds_bit_counter];
                        bit_counter <= bit_counter + 1;
                        if (ds_bit_counter == 3'd7)
                            state <= STATE_PADDING_ZERO;
                        else
                            ds_bit_counter <= ds_bit_counter + 1;
                    end else begin
                        error_flag <= 1;
                        state <= STATE_DONE;
                    end
                end

                STATE_PADDING_ZERO: begin
                    if (bit_counter < 1088) begin
                        message[bit_counter] <= 1'b0;
                        bit_counter <= bit_counter + 1;
                    end else begin
                        valid_output <= 1;  // Block is complete
                        state <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    // Hold state.
                end

                default: state <= STATE_DONE;
            endcase
        end
    end

    always @(*) begin
        debug_pad_state    = state;
        debug_pad_bitcount = bit_counter;
    end

endmodule
