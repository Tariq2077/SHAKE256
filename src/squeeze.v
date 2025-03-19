`timescale 1ns/1ps
module squeeze #(
    parameter RATE         = 1088,   // number of rate bits (from state)
    parameter OUTPUT_WIDTH = 512,    // total desired output bits
    parameter STATE_WIDTH  = 1600    // full state width
)(
    input  wire clk,
    input  wire reset,
    input  wire start,                   // signal to start squeeze process
    input  wire [STATE_WIDTH-1:0] initial_state, // input state (after pad/absorb)
    output reg [OUTPUT_WIDTH-1:0] Squeezed_data, // final output bits
    output reg squeeze_done              // asserted when finished
);

    // Define a simple FSM:
    localparam IDLE    = 2'd0,
               EXTRACT = 2'd1,
               UPDATE  = 2'd2,
               DONE    = 2'd3;
    reg [1:0] state, next_state;
    // Register for current state (the Keccak state)
    reg [STATE_WIDTH-1:0] state_reg;
    // Count how many output bits have been produced so far
    reg [$clog2(OUTPUT_WIDTH+1)-1:0] bit_count;
    // Internal output buffer
    reg [OUTPUT_WIDTH-1:0] out_buffer;

    // Instance of your KeccakF1600 permutation (assumed one-cycle update)
    wire [STATE_WIDTH-1:0] new_state;
    KeccakF1600 keccak_inst (
       .clk(clk),
       .reset(reset),
       .in_state(state_reg),
       .out_state(new_state)
    );

    // Sequential logic for the state machine and registers.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            state_reg     <= {STATE_WIDTH{1'b0}};
            bit_count     <= 0;
            out_buffer    <= {OUTPUT_WIDTH{1'b0}};
            squeeze_done  <= 1'b0;
            Squeezed_data <= {OUTPUT_WIDTH{1'b0}};
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    squeeze_done <= 1'b0;
                    if (start) begin
                        state_reg  <= initial_state;
                        bit_count  <= 0;
                        out_buffer <= {OUTPUT_WIDTH{1'b0}};
                    end
                end

                EXTRACT: begin
                    // Here we unroll the copying of bits from state_reg to out_buffer.
                    // (We use generate loops below to do this in parallel.)
                    // We update bit_count here:
                    if (OUTPUT_WIDTH - bit_count >= RATE)
                        bit_count <= bit_count + RATE;
                    else
                        bit_count <= OUTPUT_WIDTH;
                end

                UPDATE: begin
                    // Apply permutation to update state
                    state_reg <= new_state;
                end

                DONE: begin
                    squeeze_done  <= 1'b1;
                    Squeezed_data <= out_buffer;
                end

                default: ;
            endcase
        end
    end

    // Next-state combinational logic.
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = EXTRACT;
                else
                    next_state = IDLE;
            end
            EXTRACT: begin
                if (bit_count < OUTPUT_WIDTH)
                    next_state = UPDATE;
                else
                    next_state = DONE;
            end
            UPDATE: next_state = EXTRACT;
            DONE:   next_state = DONE;
            default: next_state = DONE;
        endcase
    end

    // ----------------------------------------------------------------
    // Unrolled bit copy: Copy bits from state_reg[0:RATE-1] into out_buffer
    // at positions determined by bit_count. Since OUTPUT_WIDTH may be larger
    // than 250, we split the generate loop into two loops.
    // (If OUTPUT_WIDTH is less than or equal to 250, one loop would suffice.)
    // ----------------------------------------------------------------

    // First 256 bits
    genvar i;
    generate
        for (i = 0; i < 256; i = i + 1) begin : copy_loop_low
            always @(posedge clk) begin
                if (state == EXTRACT) begin
                    if ((bit_count + i) < OUTPUT_WIDTH && (bit_count + i) < RATE)
                        out_buffer[bit_count + i] <= state_reg[i];
                end
            end
        end
    endgenerate

    // Next part: from 256 to OUTPUT_WIDTH-1 (if OUTPUT_WIDTH > 256)
    generate
        if (OUTPUT_WIDTH > 256) begin: copy_loop_high
            for (i = 256; i < OUTPUT_WIDTH; i = i + 1) begin : copy_loop_high_inner
                always @(posedge clk) begin
                    if (state == EXTRACT) begin
                        if ((bit_count + i) < OUTPUT_WIDTH && (bit_count + i) < RATE)
                            out_buffer[bit_count + i] <= state_reg[i];
                    end
                end
            end
        end
    endgenerate

endmodule
