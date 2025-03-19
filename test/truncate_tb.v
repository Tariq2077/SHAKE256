`timescale 1ns / 1ps

module truncate_tb;

  // Parameters must match those in your Truncate module.
  parameter WIDTH_IN = 1088;
  parameter MAX_L    = 512;

  // Clock and reset signals.
  reg clk;
  reg reset;
  
  // Control signal to start truncation.
  reg truncate_start;
  
  // Test input vector.
  reg [WIDTH_IN-1:0] Z;
  
  // Output from the truncate module.
  wire [MAX_L-1:0] Y;
  wire truncate_done;
  
  // Instantiate the Truncate module.
  Truncate #(
    .WIDTH_IN(WIDTH_IN),
    .MAX_L(MAX_L)
  ) uut (
    .clk(clk),
    .reset(reset),
    .truncate_start(truncate_start),
    .Z(Z),
    .Y(Y),
    .truncate_done(truncate_done)
  );
  
  // Clock generation: 10ns period.
  always #5 clk = ~clk;
  
  initial begin
    // Initialize signals.
    clk = 0;
    reset = 1;
    truncate_start = 0;
    Z = {WIDTH_IN{1'b0}};
    
    // Hold reset for 20ns.
    #20;
    reset = 0;
    
    // Wait a bit, then provide a test vector.
    // For example, let Z be a pattern that has a known lower MAX_L bits.
    // Here we set the lower MAX_L bits to a repeating pattern and the rest to 0.
    Z = { {(WIDTH_IN-MAX_L){1'b0}}, {MAX_L{1'b1}} }; // Z = 0...0 followed by MAX_L ones
    
    // Wait a few clock cycles.
    #10;
    
    // Trigger truncate_start.
    truncate_start = 1;
    #10;
    truncate_start = 0;
    
    // Wait until the module asserts truncate_done.
    wait(truncate_done);
    
    // Display the result.
    $display("Truncate Module: Output digest Y = %h", Y);
    
    // Check the output (the expected value is the lower MAX_L bits of Z).
    if (Y === {MAX_L{1'b1}})
      $display("Test Passed: Y is correct.");
    else
      $display("Test Failed: Y is incorrect.");
      
    #20;
    $finish;
  end

endmodule
