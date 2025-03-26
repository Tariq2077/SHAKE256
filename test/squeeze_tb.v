`timescale 1ns/1ps
module squeeze_tb;

  // Parameters 
  localparam RATE = 1088;
  localparam OUTPUT_WIDTH = RATE;  // Typically 1088 bits
  localparam STATE_WIDTH = 1600;

  // Testbench signals
  reg                      clk;
  reg                      reset;
  reg                      squeeze_start;
  reg  [STATE_WIDTH-1:0]   initial_state;
  wire [OUTPUT_WIDTH-1:0]  Squeezed_data;
  wire                     squeeze_done;

  // Instantiate the Squeeze_mod module
  Squeeze_mod #(
    .RATE(RATE),
    .OUTPUT_WIDTH(OUTPUT_WIDTH),
    .STATE_WIDTH(STATE_WIDTH)
  ) uut (
    .clk(clk),
    .reset(reset),
    .squeeze_start(squeeze_start),
    .initial_state(initial_state),
    .Squeezed_data(Squeezed_data),
    .squeeze_done(squeeze_done)
  );

  // Clock generation: 10 ns period (5 ns high, 5 ns low)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Declare loop variable at module scope.
  integer i;

  initial begin
    $display("Starting Squeeze module test");

    // Initialize signals
    clk = 0;
    reset = 1;
    squeeze_start = 0;

    // Wait a few cycles then release reset
    #20;
    reset = 0;

    // Set initial_state: For example, upper 512 bits are 0 and lower 1088 bits are all ones.
    // This is our known test vector.
    initial_state = {{512{1'b0}}, {1088{1'b1}}};

    // Display the full initial_state for verification.
    $display("Initial state (1600 bits): %h", initial_state);

    // Wait a little, then trigger squeeze_start.
    #10;
    squeeze_start = 1;
    #10;
    squeeze_start = 0;

    // Allow some time for the Squeeze module to complete.
    #50;
    
    // Display and check the result.
    $display("Test Squeeze: expected lower %0d bits = %h", OUTPUT_WIDTH, initial_state[OUTPUT_WIDTH-1:0]);
    $display("Test Squeeze: Squeezed_data = %h", Squeezed_data);
    if (Squeezed_data == initial_state[OUTPUT_WIDTH-1:0])
      $display("Squeeze Test Passed.");
    else
      $display("Squeeze Test Failed.");
      
    $finish;
  end

endmodule
