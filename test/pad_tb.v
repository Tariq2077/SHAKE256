`timescale 1ns/1ps
module pad_tb;

  localparam RANGE = 1088;         // Padded block width in bits
  localparam BYTE_RANGE = RANGE / 8; // For 1088 bits, 136 bytes

  // Testbench signals.
  reg clk;
  reg reset;
  reg pad_start;
  reg enable;
  reg [1:0] serial_in;
  reg serial_end_signal;
  wire [RANGE-1:0] message;
  wire pad_done;
  wire [2:0] debug_pad_state;
  wire [10:0] debug_pad_bytecount;

  // Instantiate the pad module.
  pad #(.RANGE(RANGE)) dut (
    .clk(clk),
    .reset(reset),
    .pad_start(pad_start),
    .next_block(1'b0), // single-block test; multi-block not used here
    .enable(enable),
    .serial_in(serial_in),
    .serial_end_signal(serial_end_signal),
    .message(message),
    .pad_done(pad_done),
    .debug_pad_state(debug_pad_state),
    .debug_pad_bytecount(debug_pad_bytecount)
  );

  // Clock generation: 10 ns period.
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Declare a loop variable.
  integer idx;

  // Helper task: send one byte as four 2-bit chunks (LSB-first).
  task send_byte_2bits(input [7:0] byte);
    integer j;
    begin
      for (j = 0; j < 4; j = j + 1) begin
        serial_in = byte[2*j +: 2];
        enable = 1'b1;
        @(posedge clk);
      end
      enable = 1'b0;
    end
  endtask

  // Test vector: "abc" (ASCII: 0x61, 0x62, 0x63).
  reg [7:0] test_msg [0:2];
  initial begin
    test_msg[0] = 8'h61; // 'a'
    test_msg[1] = 8'h62; // 'b'
    test_msg[2] = 8'h63; // 'c'
  end

  // MAIN TEST
  initial begin
    // Initialize signals.
    reset = 1;
    pad_start = 0;
    enable = 0;
    serial_in = 2'b00;
    serial_end_signal = 0;
    #20;
    reset = 0;
    repeat (2) @(posedge clk);

    // Kick off the pad collection.
    @(posedge clk);
    pad_start = 1;
    @(posedge clk);
    pad_start = 0;

    // Send "abc" as serial data.
    for (idx = 0; idx < 3; idx = idx + 1) begin
      send_byte_2bits(test_msg[idx]);
    end

    // Signal end-of-input.
    @(posedge clk);
    serial_end_signal = 1'b1;
    @(posedge clk);
    serial_end_signal = 1'b0;

    // Wait until pad_done is asserted.
    wait(pad_done == 1);
    #10;

    // Print out the padded message byte by byte.
    $display("Padded message (in bytes):");
    for (idx = 0; idx < BYTE_RANGE; idx = idx + 1) begin
      $write("%02h ", message[8*idx +: 8]);
    end
    $display("");

    $finish;
  end

endmodule
