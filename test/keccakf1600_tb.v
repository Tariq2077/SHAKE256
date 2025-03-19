`timescale 1ns/1ps
module keccakf1600_tb;

  reg         clk;
  reg         reset;        
  reg         keccak_start;
  reg  [1599:0] state_in;
  wire [1599:0] state_out;
  wire         done;
  wire [2:0]   debug_kf_fsm;
  wire [4:0]   debug_kf_round;

  // Instantiate the final "KeccakF1600" module
  KeccakF1600 dut (
      .clk(clk),
      .reset(reset),
      .keccak_start(keccak_start),
      .state_in(state_in),
      .state_out(state_out),
      .done(done),
      .debug_kf_fsm(debug_kf_fsm),
      .debug_kf_round(debug_kf_round)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  integer i;
  initial begin
    state_in = 1600'b0; // all-zero
    reset    = 0;
    keccak_start = 0;

    @(posedge clk);
    reset = 1;
    @(posedge clk);
    @(posedge clk);
    reset = 0;

    @(posedge clk);
    @(posedge clk);

    $display("Starting FIPS202 logic with all-zero input at time=%0t", $time);
    @(posedge clk);
    keccak_start = 1;
    @(posedge clk);
    keccak_start = 0;

    // Wait for done
    wait(done);
    #10;

    $display("Permutation done at time=%0t. Final 25 lanes:", $time);
    for(i=0; i<25; i=i+1) begin
      $display("Lane[%0d] = 0x%h", i, state_out[64*i +: 64]);
    end

    #20;
    $finish;
  end

endmodule
