`timescale 1ns/1ps
module tb_Keccak;

  localparam STATE_WIDTH    = 1600;
  localparam RATE_WIDTH     = 1088;
  localparam CAPACITY_WIDTH = 512;
  localparam OUT_BITS       = 256;
  localparam NUM_BLOCKS     = 2;  // Test with 2 blocks

  // Testbench signals
  reg clk;
  reg reset;
  reg start;
  wire done;
  wire [OUT_BITS-1:0] digest;
  
  // Debug outputs
  wire [3:0] debug_keccak_fsm;
  wire [$clog2(NUM_BLOCKS+1)-1:0] debug_block_index;
  wire [4:0] debug_kf_round;
  
  // Concatenated padded input (NUM_BLOCKS blocks, each RATE_WIDTH bits)
  reg [NUM_BLOCKS*RATE_WIDTH-1:0] padded_input;
  
  // Instantiate the KECCAK module
  KECCAK #(
    .STATE_WIDTH(STATE_WIDTH),
    .RATE_WIDTH(RATE_WIDTH),
    .CAPACITY_WIDTH(CAPACITY_WIDTH),
    .OUT_BITS(OUT_BITS),
    .NUM_BLOCKS(NUM_BLOCKS)
  ) dut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .padded_input(padded_input),
    .done(done),
    .digest(digest),
    .debug_keccak_fsm(debug_keccak_fsm),
    .debug_block_index(debug_block_index),
    .debug_kf_round(debug_kf_round)
  );
  
  // Clock generation: 10 ns period
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Test stimulus
  initial begin
    // Initialize signals
    reset = 1;
    start = 0;
    #15;
    reset = 0;
    
    // Prepare multi‑block padded input.
    // Here we form two blocks:
    // Block 0 (most-significant block): all ones.
    // Block 1 (least-significant block): all zeros.
    // Note: The KECCAK module uses the expression:
    // padded_input[((NUM_BLOCKS-1 - blk_index)*RATE_WIDTH) +: RATE_WIDTH]
    // so block 0 is taken from the upper RATE_WIDTH bits.
    padded_input = { {RATE_WIDTH{1'b1}}, {RATE_WIDTH{1'b0}} };
    
    #10;
    start = 1;
    #10;
    start = 0;
    
    // Wait until the KECCAK FSM indicates completion.
    wait(done == 1);
    #10;
    $display("Final digest: %h", digest);
    $display("Debug FSM state: %h, Block index: %h, Debug Kf round: %h", 
             debug_keccak_fsm, debug_block_index, debug_kf_round);
    $stop;
  end

endmodule
