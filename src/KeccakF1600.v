`timescale 1ns/1ps
module KeccakF1600 (
    input  wire         clk,
    input  wire         reset,         // synchronous active-high reset
    input  wire         keccak_start,  // 1-cycle pulse triggers the permutation
    input  wire [1599:0] state_in,     // 25 lanes x 64 bits, Lane0 in [63:0], Lane1 in [127:64], etc.
    output reg  [1599:0] state_out,    // final 25 lanes x 64 bits, same flattening as input order
    output reg          done,
    // Debug signals
    output reg [2:0]    debug_kf_fsm,  
    output reg [4:0]    debug_kf_round
);

  // --- FSM Definitions ---
  localparam FSM_IDLE  = 2'd0,
             FSM_ROUND = 2'd1,
             FSM_DONE  = 2'd2;

  reg [1:0]  fsm;
  reg [4:0]  round_idx;
  wire       last_round = (round_idx == 5'd23);

  // --- Internal State (25 lanes) ---
  reg [63:0] A    [0:24];
  reg [63:0] nextA[0:24];

  // --- Temporary Arrays ---
  reg [63:0] C[0:4], D[0:4];
  reg [63:0] Btmp[0:24];
  reg [63:0] Ttmp[0:24];

  // Loop variables.
  integer i, x, y;

  // --- Round Constants (FIPS 202 order) ---
  wire [63:0] RC [0:23];
  assign RC[ 0] = 64'h0000000000000001;
  assign RC[ 1] = 64'h0000000000008082;
  assign RC[ 2] = 64'h800000000000808A;
  assign RC[ 3] = 64'h8000000080008000;
  assign RC[ 4] = 64'h000000000000808B;
  assign RC[ 5] = 64'h0000000080000001;
  assign RC[ 6] = 64'h8000000080008081;
  assign RC[ 7] = 64'h8000000000008009;
  assign RC[ 8] = 64'h000000000000008A;
  assign RC[ 9] = 64'h0000000000000088;
  assign RC[10] = 64'h0000000080008009;
  assign RC[11] = 64'h000000008000000A;
  assign RC[12] = 64'h000000008000808B;
  assign RC[13] = 64'h800000000000008B;
  assign RC[14] = 64'h8000000000008089;
  assign RC[15] = 64'h8000000000008003;
  assign RC[16] = 64'h8000000000008002;
  assign RC[17] = 64'h8000000000000080;
  assign RC[18] = 64'h000000000000800A;
  assign RC[19] = 64'h800000008000000A;
  assign RC[20] = 64'h8000000080008081;
  assign RC[21] = 64'h8000000000008080;
  assign RC[22] = 64'h0000000080000001;
  assign RC[23] = 64'h8000000080008008;

  // --- Rho Offsets ---
  wire [5:0] RHO [0:24];
  assign RHO[ 0] = 6'd0;
  assign RHO[ 1] = 6'd1;
  assign RHO[ 2] = 6'd62;
  assign RHO[ 3] = 6'd28;
  assign RHO[ 4] = 6'd27;
  assign RHO[ 5] = 6'd36;
  assign RHO[ 6] = 6'd44;
  assign RHO[ 7] = 6'd6;
  assign RHO[ 8] = 6'd55;
  assign RHO[ 9] = 6'd20;
  assign RHO[10] = 6'd3;
  assign RHO[11] = 6'd10;
  assign RHO[12] = 6'd43;
  assign RHO[13] = 6'd25;
  assign RHO[14] = 6'd39;
  assign RHO[15] = 6'd41;
  assign RHO[16] = 6'd45;
  assign RHO[17] = 6'd15;
  assign RHO[18] = 6'd21;
  assign RHO[19] = 6'd8;
  assign RHO[20] = 6'd18;
  assign RHO[21] = 6'd2;
  assign RHO[22] = 6'd61;
  assign RHO[23] = 6'd56;
  assign RHO[24] = 6'd14;

  // --- 64-bit rotate-left function ---
  function [63:0] ROL64(input [63:0] val, input [5:0] shift);
    begin
      ROL64 = (val << shift) | (val >> (64 - shift));
    end
  endfunction

  // --- Combinational Round Logic: Theta -> Rho+Pi -> Chi -> Iota ---
  always @* begin : ROUND_COMB_LOGIC
    integer cx, cy, idx;
    for(idx=0; idx<25; idx=idx+1)
      nextA[idx] = A[idx];
    // Theta
    for(cx=0; cx<5; cx=cx+1) begin
      C[cx] = A[cx+0] ^ A[cx+5] ^ A[cx+10] ^ A[cx+15] ^ A[cx+20];
    end
    for(cx=0; cx<5; cx=cx+1) begin
      D[cx] = C[(cx+4)%5] ^ ROL64(C[(cx+1)%5],1);
    end
    for(cx=0; cx<5; cx=cx+1) begin
      for(cy=0; cy<5; cy=cy+1) begin
        nextA[cx+5*cy] = A[cx+5*cy] ^ D[cx];
      end
    end
    // Rho + Pi
    for(idx=0; idx<25; idx=idx+1)
      Btmp[idx] = 64'h0;
    for(cx=0; cx<5; cx=cx+1) begin
      for(cy=0; cy<5; cy=cy+1) begin
        Btmp[5*((2*cx+3*cy)%5)+cy] = ROL64(nextA[cx+5*cy], RHO[cx+5*cy]);
      end
    end
    for(idx=0; idx<25; idx=idx+1)
      nextA[idx] = Btmp[idx];
    // Chi
    for(idx=0; idx<25; idx=idx+1)
      Ttmp[idx] = nextA[idx];
    for(cy=0; cy<5; cy=cy+1) begin
      for(cx=0; cx<5; cx=cx+1) begin
        nextA[cx+5*cy] = Ttmp[cx+5*cy] ^ ((~Ttmp[((cx+1)%5)+5*cy]) & Ttmp[((cx+2)%5)+5*cy]);
      end
    end
    // Iota
    nextA[0] = nextA[0] ^ RC[round_idx];
  end

  // --- FSM and Registers ---
  always @(posedge clk) begin : FSM_REG
    if (reset) begin
      for(i=0; i<25; i=i+1) begin
        A[i] <= 64'h0;
      end
      round_idx   <= 5'd0;
      done        <= 1'b0;
      fsm         <= FSM_IDLE;
    end else begin
      case(fsm)
        FSM_IDLE: begin
          done <= 1'b0;
          if (keccak_start) begin
            for(i=0; i<25; i=i+1) begin
              A[i] <= state_in[64*i +: 64];
            end
            round_idx <= 5'd0;
            fsm <= FSM_ROUND;
          end
        end
        FSM_ROUND: begin
          for(i=0; i<25; i=i+1) begin
            A[i] <= nextA[i];
          end
          round_idx <= round_idx + 1;
          if (last_round)
            fsm <= FSM_DONE;
        end
        FSM_DONE: begin
          done <= 1'b1;
          fsm <= FSM_IDLE;
        end
      endcase
      debug_kf_fsm   <= {1'b0, fsm}; // 3-bit output.
      debug_kf_round <= round_idx;
    end
  end

  // --- Flatten the Final Lanes into state_out in Standard Order ---
  // Each lane A[i] becomes bits [64*i +: 64].
  genvar gi;
  generate
    for (gi = 0; gi < 25; gi = gi + 1) begin : LANE_PACK
      always @* begin
        state_out[64*gi +: 64] = A[gi];
      end
    end
  endgenerate

endmodule
