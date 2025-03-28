`timescale 1ns/1ps
module KECCAK #(
    parameter STATE_WIDTH    = 1600,
    parameter RATE_WIDTH     = 1088,
    parameter CAPACITY_WIDTH = 512,
    parameter OUT_BITS       = 256,
    parameter NUM_BLOCKS     = 1    // Adjust as needed for multi‑block padded input
)(
    input  wire clk,
    input  wire reset,
    input  wire start,
    // Padded input: concatenation of NUM_BLOCKS blocks (each RATE_WIDTH bits)
    input  wire [NUM_BLOCKS*RATE_WIDTH-1:0] padded_input,
    output reg done,
    output reg [OUT_BITS-1:0] digest,
    // Debug outputs:
    output reg [3:0] debug_keccak_fsm,   // KECCAK FSM state
    output reg [$clog2(NUM_BLOCKS+1)-1:0] debug_block_index,
    output wire [4:0] debug_kf_round      // from the KeccakF1600 permutation
);

    // Internal state and FSM registers.
    reg [STATE_WIDTH-1:0] state;
    reg [3:0] fsm;
    localparam [3:0] 
        IDLE     = 4'd0,
        ABSORB   = 4'd1,
        PERMUTE  = 4'd2,
        TRUNCATE = 4'd3,
        DONE_S   = 4'd4;

    // Block counter.
    reg [$clog2(NUM_BLOCKS+1)-1:0] blk_index;

    // --- Instantiate the KeccakF1600 Permutation Module ---
    // It is assumed that KeccakF1600 has the following ports:
    // clk, rst_n (active low reset), start, state_in, state_out, done, debug_kf_fsm, debug_kf_round.
    reg kf_start;
    wire [STATE_WIDTH-1:0] kf_state_out;
    wire kf_done;
    // Here, we leave debug_kf_fsm unconnected (optional), and connect debug_kf_round to our output.
    KeccakF1600 kf_inst (
        .clk(clk),
        .rst_n(~reset),
        .start(kf_start),
        .state_in(state),
        .state_out(kf_state_out),
        .done(kf_done),
        .debug_kf_fsm(),              // Not used externally.
        .debug_kf_round(debug_kf_round)
    );

    // --- Instantiate the Truncate Module ---
    // Truncate extracts the top OUT_BITS from the RATE portion of the state.
    // We assume that state[STATE_WIDTH-1:CAPACITY_WIDTH] is RATE_WIDTH bits.
    wire [OUT_BITS-1:0] truncated;
    reg [$clog2(OUT_BITS+1)-1:0] L_sel;
    Truncate #(.WIDTH_IN(RATE_WIDTH), .MAX_L(OUT_BITS)) trunc_inst (
        .Z(state[STATE_WIDTH-1:CAPACITY_WIDTH]),
        .L_sel(L_sel),
        .Y(truncated)
    );

    // --- Multi-block KECCAK FSM ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            fsm         <= IDLE;
            state       <= {STATE_WIDTH{1'b0}}; // initialize state to zero
            blk_index   <= 0;
            done        <= 1'b0;
            digest      <= {OUT_BITS{1'b0}};
            kf_start    <= 1'b0;
            L_sel       <= OUT_BITS; // take full OUT_BITS from the rate portion
        end else begin
            case (fsm)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= {STATE_WIDTH{1'b0}};  // clear state
                        blk_index <= 0;
                        fsm <= ABSORB;
                    end
                end

                ABSORB: begin
                    // Absorb the current block into the rate portion of the state.
                    // We assume padded_input is arranged such that block0 occupies the most-significant RATE_WIDTH bits.
                    state[CAPACITY_WIDTH +: RATE_WIDTH] <= 
                        state[CAPACITY_WIDTH +: RATE_WIDTH] ^ 
                        padded_input[((NUM_BLOCKS-1 - blk_index)*RATE_WIDTH) +: RATE_WIDTH];
                    fsm <= PERMUTE;
                end

                PERMUTE: begin
                    kf_start <= 1'b1;
                    if (kf_done) begin
                        state <= kf_state_out;
                        kf_start <= 1'b0;
                        if (blk_index < NUM_BLOCKS - 1) begin
                            blk_index <= blk_index + 1;
                            fsm <= ABSORB;
                        end else begin
                            fsm <= TRUNCATE;
                        end
                    end
                end

                TRUNCATE: begin
                    digest <= truncated;
                    fsm <= DONE_S;
                end

                DONE_S: begin
                    done <= 1'b1;
                    // Remain in DONE_S state.
                end

                default: fsm <= IDLE;
            endcase
        end
    end

    // Debug assignments.
    always @(*) begin
        debug_keccak_fsm = fsm;
        debug_block_index = blk_index;
    end

endmodule
