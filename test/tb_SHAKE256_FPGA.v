`timescale 1ns/1ps
module tb_SHAKE256_FPGA;

  reg clk;
  reg rst_n;
  reg sw_start;
  reg btn1, btn2, btn3, btn4;
  wire led_idle, led_processing, led_correct, led_incorrect;
  
  // Instantiate the DUT
  SHAKE256_FPGA dut (
    .clk(clk),
    .rst_n(rst_n),
    .sw_start(sw_start),
    .btn1(btn1),
    .btn2(btn2),
    .btn3(btn3),
    .btn4(btn4),
    .led_idle(led_idle),
    .led_processing(led_processing),
    .led_correct(led_correct),
    .led_incorrect(led_incorrect)
  );
  
  // Clock generation: 50 MHz (20 ns period)
  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end
  
  task reset_dut;
  begin
    rst_n = 0;
    sw_start = 0;
    btn1 = 0; btn2 = 0; btn3 = 0; btn4 = 0;
    #50;
    rst_n = 1;
    #20;
  end
  endtask
  
  // Test task: drive the appropriate button (active-high) and sw_start.
  // Button mapping: bit3=btn4, bit2=btn3, bit1=btn2, bit0=btn1.
  task run_test(input [3:0] btn_val, input [80*8:1] test_name);
  begin
    $display("\n=== Starting Test: %s ===", test_name);
    {btn4, btn3, btn2, btn1} = btn_val;
    @(posedge clk);
    sw_start = 1;
    @(posedge clk);
    sw_start = 0;
    // Wait for the FSM to return to idle (led_idle==1)
    wait (led_idle == 1);
    @(posedge clk);
    if (led_correct)
      $display("Test %s => CORRECT digest", test_name);
    else if (led_incorrect)
      $display("Test %s => INCORRECT digest", test_name);
    else
      $display("Test %s => ??? No LED ???", test_name);
    {btn4, btn3, btn2, btn1} = 4'b0000;
    $display("=== Test: %s completed ===", test_name);
    #50;
  end
  endtask
  
  initial begin
    reset_dut;
    run_test(4'b0001, "Empty String"); // btn1 high => empty string test
    run_test(4'b0010, "abc");          // btn2 high => "abc" test
    run_test(4'b0100, "5abc");         // btn3 high => "5abc" test
    run_test(4'b1000, "Digital2");     // btn4 high => "Digital2" test
    #100;
    $display("All tests done.");
    $finish;
  end

endmodule
