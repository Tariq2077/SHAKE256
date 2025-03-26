`timescale 1ns/1ps
module tb_shake256_zero_length;

  // -----------------------------------------------------
  // DUT I/O
  // -----------------------------------------------------
  reg  clk;
  reg  reset;
  reg  start;
  wire done;
  reg  enable;
  reg  serial_in;
  reg  serial_end_signal;
  wire [511:0] digest;
  
  
  SHAKE256 dut (
      .clk(clk),
      .reset(reset),
      .start(start),
      .enable(enable),
      .serial_in(serial_in),
      .serial_end_signal(serial_end_signal),
      .done(done),
      .digest(digest)
  );
  
  // -----------------------------------------------------
  // Clock: 10 ns period = 100 MHz
  // -----------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // Toggle every 5 ns
  end

  // -----------------------------------------------------
  // Test Stimulus
  // -----------------------------------------------------
  initial begin
    
    // 1) Power-on Reset
    reset = 1;
    start = 0;
    enable = 0;
    serial_in = 0;
    serial_end_signal = 0;
    #100;  // hold reset for 100 ns

    // 2) De-assert reset
    reset = 0;
    #10;
    
    // 3) Provide zero-length message
    //    We will set enable=1 briefly, but no bits come in (serial_in=0).
    //    Immediately set serial_end_signal=1 to say "We're done input."
    enable = 1;
    serial_in = 0;
    #10;
    serial_end_signal = 1;  // "no more bits"
    #10;
    enable = 0;
    
    // 4) Now actually trigger the operation with "start=1"
    start = 1;
    #10;
    start = 0;
    
    // 5) Wait until done=1
    wait (done == 1);
    #10;

    $display("Final Digest = %064x", digest);
    // Compare to official expected: 
    //  "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82..."
    
    // 6) Stop simulation
    $stop;
  end

endmodule
