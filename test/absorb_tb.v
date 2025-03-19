`timescale 1ns/1ps
module absorb_tb;

  localparam STATE_WIDTH = 1600;
  localparam RATE_WIDTH  = 1088;

  // Expected pre-permutation state: lower RATE bits are ones, capacity bits zeros.
  localparam [STATE_WIDTH-1:0] EXPECTED_PRE = { {(STATE_WIDTH - RATE_WIDTH){1'b0}}, {RATE_WIDTH{1'b1}} };

  reg clk;
  reg reset;
  reg absorb_start;
  reg [STATE_WIDTH-1:0] state_in;
  reg [STATE_WIDTH-1:0] Block;
  wire [STATE_WIDTH-1:0] absorb_state_out;
  wire absorb_done;
  wire debug_absorb_state;
  wire [10:0] debug_absorb_i;
  wire [STATE_WIDTH-1:0] debug_pre_perm;  // New debug signal from Absorb

  // Instantiate the updated Absorb module.
  Absorb dut (
    .clk(clk),
    .reset(reset),
    .absorb_start(absorb_start),
    .state_in(state_in),
    .Block(Block),
    .absorb_state_out(absorb_state_out),
    .absorb_done(absorb_done),
    .debug_absorb_state(debug_absorb_state),
    .debug_absorb_i(debug_absorb_i),
    .debug_pre_perm(debug_pre_perm)
  );

  // Clock generation: 10 ns period.
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Test sequence.
  initial begin
    // Initialize signals.
    reset = 1;
    absorb_start = 0;
    state_in = {STATE_WIDTH{1'b0}};  // Initial sponge state: all zeros.
    // Force Block to have ones in the rate portion and zeros in the capacity.
    Block = { {(STATE_WIDTH - RATE_WIDTH){1'b0}}, {RATE_WIDTH{1'b1}} };
    
    #20;
    reset = 0;
    #10;
    
    // Trigger the absorb operation.
    absorb_start = 1;
    #10;
    absorb_start = 0;
    
    // Wait until absorb_done is asserted.
    wait (absorb_done);
    #10;
    
    // Display the pre-permutation state.
    $display("Pre-permutation state (debug_pre_perm): %h", debug_pre_perm);
    
    // Check if it matches the expected value.
    if (debug_pre_perm === EXPECTED_PRE)
      $display("Test PASSED: Pre-permutation state matches expected value.");
    else begin
      $display("Test FAILED: Pre-permutation state does not match expected.");
      $display("Expected: %h", EXPECTED_PRE);
    end
    
    $finish;
  end

endmodule
