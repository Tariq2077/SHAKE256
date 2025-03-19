`timescale 1ns/1ps
module tb_Shake256;

  // SHAKE256 Parameters
  localparam STATE_WIDTH = 1600;
  localparam RATE_WIDTH  = 1088;
  localparam OUT_BITS    = 256;

  // Testbench signals
  reg         clk;
  reg         reset;
  reg         start;
  reg         enable;          
  reg  [1:0]  serial_in;
  reg         serial_end_signal;

  wire        done;
  wire [OUT_BITS-1:0] digest;

  // Debug signals (optional)
  wire [3:0]  debug_ctrl_state;
  wire [2:0]  debug_pad_state;
  wire [10:0] debug_pad_bytecount;
  wire [RATE_WIDTH-1:0] debug_pad_out;

  //------------------------------------------------------
  // Instantiate your SHAKE256 top-level
  //------------------------------------------------------
  SHAKE256 #(
    .STATE_WIDTH(STATE_WIDTH),
    .RATE_WIDTH(RATE_WIDTH),
    .OUT_BITS(OUT_BITS)
  ) uut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .enable(enable),
    .serial_in(serial_in),
    .serial_end_signal(serial_end_signal),
    .done(done),
    .digest(digest),
    .debug_ctrl_state(debug_ctrl_state),
    .debug_pad_state(debug_pad_state),
    .debug_pad_bytecount(debug_pad_bytecount),
    .debug_pad_out(debug_pad_out)
    // (other debug connections if needed)
  );

  //------------------------------------------------------
  // Clock generator: 10 ns period
  //------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  //------------------------------------------------------
  // Task: send one byte in MSB‐first 2‐bit chunks
  //------------------------------------------------------
  task send_byte_2bits(input [7:0] mybyte);
    integer i;
    reg [1:0] chunk;
  begin
    // 4 chunks, each for 1 cycle
    for (i = 3; i >= 0; i = i - 1) begin
      chunk = mybyte[(i*2) +: 2];
      $display("[TESTBENCH] Sending Serial Input Chunk: %02b (from byte %02h)", chunk, mybyte);

      serial_in = chunk;
      enable    = 1'b1;
      @(posedge clk);
    end
    // Disable 'enable' for a cycle
    enable = 0;
    @(posedge clk);
  end
  endtask

  //------------------------------------------------------
  // Common procedure to run one test
  //------------------------------------------------------
  task run_shake256_test(input [80*8-1:0] test_name); 
    // 'test_name' is a big reg bus that can hold a short string.
  begin
    // 1) Assert reset
    reset = 1;
    #20;
    @(posedge clk);
    reset = 0;

    // 2) Wait a couple cycles
    repeat (2) @(posedge clk);

    // 3) Pulse start
    @(posedge clk);
    start = 1;
    @(posedge clk);
    start = 0;

    // 4) Wait 2 cycles so pad sees pad_start -> COLLECT
    repeat (2) @(posedge clk);

    // (We do NOT send data here directly - each sub-task does that.)
  end
  endtask

  //------------------------------------------------------
  // 1) Test for Empty String
  //------------------------------------------------------
  task test_empty_string;
  begin
    run_shake256_test("Empty String");

    // Since it's empty, we do not send any bytes.
    @(posedge clk);
    serial_end_signal = 1;
    @(posedge clk);
    serial_end_signal = 0;

    wait(done);
    #10;
    $display("==== Final digest for Empty String = %h", digest);
    $display("");
  end
  endtask

  //------------------------------------------------------
  // 2) Test for "abc"
  //------------------------------------------------------
  task test_abc;
    reg [7:0] msg [0:2];
    integer i;
  begin
    // Fill "abc"
    msg[0] = 8'h61; // 'a'
    msg[1] = 8'h62; // 'b'
    msg[2] = 8'h63; // 'c'

    run_shake256_test("abc");

    // Now send 3 bytes
    for (i=0; i<3; i=i+1) begin
      send_byte_2bits(msg[i]);
    end

    // End of input
    @(posedge clk);
    serial_end_signal = 1;
    @(posedge clk);
    serial_end_signal = 0;

    wait(done);
    #10;
    $display("==== Final digest for abc = %h", digest);
    $display("");
  end
  endtask

  //------------------------------------------------------
  // 3) Test for "5abc"
  //------------------------------------------------------
  task test_5abc;
    reg [7:0] msg [0:3];
    integer i;
  begin
    // Fill "5abc"
    msg[0] = 8'h35; // '5'
    msg[1] = 8'h61; // 'a'
    msg[2] = 8'h62; // 'b'
    msg[3] = 8'h63; // 'c'

    run_shake256_test("5abc");

    // Now send 4 bytes
    for (i=0; i<4; i=i+1) begin
      send_byte_2bits(msg[i]);
    end

    // End of input
    @(posedge clk);
    serial_end_signal = 1;
    @(posedge clk);
    serial_end_signal = 0;

    wait(done);
    #10;
    $display("==== Final digest for 5abc = %h", digest);
    $display("");
  end
  endtask

  //------------------------------------------------------
  // 4) Test for "Digital2"
  //------------------------------------------------------
  task test_digital2;
    reg [7:0] msg [0:7];
    integer i;
  begin
    // Fill "Digital2"
    msg[0] = 8'h44; // 'D'
    msg[1] = 8'h69; // 'i'
    msg[2] = 8'h67; // 'g'
    msg[3] = 8'h69; // 'i'
    msg[4] = 8'h74; // 't'
    msg[5] = 8'h61; // 'a'
    msg[6] = 8'h6C; // 'l'
    msg[7] = 8'h32; // '2'

    run_shake256_test("Digital2");

    // Now send 8 bytes
    for (i=0; i<8; i=i+1) begin
      send_byte_2bits(msg[i]);
    end

    // End of input
    @(posedge clk);
    serial_end_signal = 1;
    @(posedge clk);
    serial_end_signal = 0;

    wait(done);
    #10;
    $display("==== Final digest for Digital2 = %h", digest);
    $display("");
  end
  endtask


  //------------------------------------------------------
  // Master initial block: run all tests in one sim
  //------------------------------------------------------
  initial begin
    // Initialize signals
    clk = 0; // clock started by always block
    reset = 1;
    start = 0;
    enable = 0;
    serial_in = 0;
    serial_end_signal = 0;

    #50;

    // Test #1: empty
    test_empty_string;

    // Test #2: abc
    test_abc;

    // Test #3: 5abc
    test_5abc;

    // Test #4: Digital2
    test_digital2;

    $display("All tests completed successfully.");
    $finish;
  end

endmodule
