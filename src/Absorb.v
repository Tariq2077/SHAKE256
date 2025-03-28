`timescale 1ns/1ps
module Absorb(
    input  wire         clk,
    input  wire         reset,
    input  wire         absorb_start,
    input  wire [1599:0] state_in,
    input  wire [1599:0] Block,
    output reg  [1599:0] absorb_state_out,
    output reg          absorb_done,
    // Debug outputs:
    output reg          debug_absorb_state,
    output reg [10:0]   debug_absorb_i,
    output reg [1599:0] debug_pre_perm  // This signal captures the value before KeccakF1600
);

  // FSM states
  localparam [1:0] 
      STATE_IDLE         = 2'd0,
      STATE_ABSORB       = 2'd1,
      STATE_PERMUTE_WAIT = 2'd2,
      STATE_DONE         = 2'd3;
  
  reg [1:0] state, next_state;
  reg [1599:0] internal_state;  // Holds the value after XOR absorption, then updated by permutation.
  
  // Signal to trigger KeccakF1600
  reg         keccak_start_int;
  wire        keccak_done;
  wire [1599:0] permuted_state;
  
  // Instantiate KeccakF1600 (integrated within Absorb)
  KeccakF1600 keccak_inst (
      .clk(clk),
      .reset(reset),
      .keccak_start(keccak_start_int),
      .state_in(internal_state),
      .state_out(permuted_state),
      .done(keccak_done),
      .debug_kf_fsm(),  
      .debug_kf_round()
  );
  
  // FSM sequential logic.
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state              <= STATE_IDLE;
      internal_state     <= {1600{1'b0}};
      absorb_state_out   <= {1600{1'b0}};
      absorb_done        <= 1'b0;
      debug_absorb_i     <= 0;
      debug_pre_perm     <= {1600{1'b0}};
      keccak_start_int   <= 1'b0;
    end else begin
      state <= next_state;
      case (state)
        STATE_IDLE: begin
          absorb_done      <= 1'b0;
          keccak_start_int <= 1'b0;
          if (absorb_start) begin
            // Compute the XOR of state_in and Block.
            internal_state <= state_in ^ Block;
            // Capture the pre-permutation value for debugging.
            debug_pre_perm <= state_in ^ Block;
            debug_absorb_i <= 11'd1088;  //  debug value.
          end
        end
        
        STATE_ABSORB: begin
          // Trigger the KeccakF1600 permutation.
          keccak_start_int <= 1'b1;
        end
        
        STATE_PERMUTE_WAIT: begin
          keccak_start_int <= 1'b0; // Deassert after one cycle.
          if (keccak_done)
            internal_state <= permuted_state;
        end
        
        STATE_DONE: begin
          absorb_state_out <= internal_state;
          absorb_done      <= 1'b1;
			 //$display("[SQUEEZE] Absorbed Message Before Squeezing: %h", absorb_state_out);

        end
      endcase
    end
  end
  
  // FSM combinational logic.
  always @(*) begin
    next_state = state;
    case (state)
      STATE_IDLE: begin
        if (absorb_start)
          next_state = STATE_ABSORB;
        else
          next_state = STATE_IDLE;
      end
      STATE_ABSORB: begin
        next_state = STATE_PERMUTE_WAIT;
      end
      STATE_PERMUTE_WAIT: begin
        if (keccak_done)
          next_state = STATE_DONE;
        else
          next_state = STATE_PERMUTE_WAIT;
      end
      STATE_DONE: begin
        next_state = STATE_DONE;
      end
      default: next_state = STATE_IDLE;
    endcase
    debug_absorb_state = (state == STATE_DONE) ? 1'b1 : 1'b0;
  end

endmodule
