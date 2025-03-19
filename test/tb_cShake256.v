`timescale 1ns/1ps
module tb_cShake256;
  reg clk;
  reg reset;
  reg start;
  reg enable;
  reg serial_in;
  reg serial_end_signal;
  reg [7:0] N;
  reg [7:0] S;
  wire done;
  wire [511:0] digest;
  wire [3:0] debug_cshake_fsm;
  wire [2:0] debug_pad_state;
  wire [10:0] debug_pad_bitcount;
  wire [10:0] debug_absorb_i;
  wire [1087:0] debug_domain_block;
  wire [1:0] debug_kf_fsm;
  wire [4:0] debug_kf_round;
  wire [2:0] debug_ctrl_state;
  
  // Instantiate cShake256
  cShake256 uut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .enable(enable),
    .serial_in(serial_in),
    .serial_end_signal(serial_end_signal),
    .N(N),
    .S(S),
    .done(done),
    .digest(digest),
    .debug_cshake_fsm(debug_cshake_fsm),
    .debug_pad_state(debug_pad_state),
    .debug_pad_bitcount(debug_pad_bitcount),
    .debug_absorb_i(debug_absorb_i),
    .debug_domain_block(debug_domain_block),
    .debug_kf_fsm(debug_kf_fsm),
    .debug_kf_round(debug_kf_round),
    .debug_ctrl_state(debug_ctrl_state)
  );
  
  // Clock generation (100 MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Monitor signals
  initial begin
    $monitor("Time: %t | reset: %b | start: %b | done: %b | digest: %h", 
             $time, reset, start, done, digest);
    $monitor("cSHAKE FSM: %b | Pad State: %b (BitCount: %d) | Absorb_i: %d | Keccak FSM: %b (Round: %d) | Ctrl: %b", 
             debug_cshake_fsm, debug_pad_state, debug_pad_bitcount, debug_absorb_i, debug_kf_fsm, debug_kf_round, debug_ctrl_state);
  end
  
  // Stimulus
  initial begin
    // Initialize signals
    reset = 1;
    start = 0;
    enable = 0;           // For an empty message, no serial data is needed.
    serial_in = 256'h508eef6956f3a1f414d5e1c72c27650c26183206509410afc80e3ca0d77d5e32;
    serial_end_signal = 0;
    N = 8'd0;
    S = 8'd0;
    
    // Hold reset for 20 ns then deassert permanently
    #20;
    reset = 0;
    #20;
    
    // For an empty message, trigger the chain:
    start = 1;
    serial_end_signal = 1; // Indicate no serial input
    #40;
    start = 0;
    serial_end_signal = 0;
    
    // Wait until the entire encryption chain is done
    wait (done == 1);
    #10;
    $display("Final Digest: %h", digest);
    $stop;
  end
endmodule
