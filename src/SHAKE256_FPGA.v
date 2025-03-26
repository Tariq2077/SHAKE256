`timescale 1ns/1ps
module SHAKE256_FPGA (
  input  wire clk,         // 50 MHz clock (Our FPGA support 50 Mhz maximum)
  input  wire rst_n,       // active-low reset
  input  wire sw_start,    // active-high start switch
  // Test–select buttons (active low on board; inverted below to be active high)
  input  wire btn1,
  input  wire btn2,
  input  wire btn3,
  input  wire btn4,
  // LED outputs (active high: LED on when signal is high)
  output reg led_idle,
  output reg led_processing,
  output reg led_correct,
  output reg led_incorrect
);

  //============================================================
  // FSM State Definitions
  //============================================================
  localparam [3:0] 
    S_IDLE      = 4'd0,
    S_INIT      = 4'd1,
    S_INIT2     = 4'd2, // extra state to let msg_len update
    S_FEED      = 4'd3,
    S_FEED_WAIT = 4'd4,
    S_FINAL     = 4'd5,
    S_WAIT      = 4'd6,
    S_COMPARE   = 4'd7,
    S_SHOW      = 4'd8;
    
  reg [3:0] state;
  // Use a counter to hold the result (S_SHOW) for a fixed period.
  parameter SHOW_LIMIT = 16'd500000;
  reg [15:0] show_counter;

  //============================================================
  // Aggregator (SHAKE256 core) interface signals
  //============================================================
  reg         core_start;
  reg         core_enable;
  reg  [1:0]  core_serial_in;
  reg         core_serial_end;
  wire        core_done;
  wire [255:0] core_digest;
  // The aggregator core uses an active-high reset.
  reg aggregator_reset_int;

  // Instantiate the aggregator core.
  SHAKE256 aggregator (
    .clk(clk),
    .reset(aggregator_reset_int),
    .start(core_start),
    .enable(core_enable),
    .serial_in(core_serial_in),
    .serial_end_signal(core_serial_end),
    .done(core_done),
    .digest(core_digest)
  );

  //============================================================
  // Test–select logic (active–high)
  //============================================================
  wire active_btn1 = ~btn1;
  wire active_btn2 = ~btn2;
  wire active_btn3 = ~btn3;
  wire active_btn4 = ~btn4;
  wire [3:0] test_btn = {active_btn4, active_btn3, active_btn2, active_btn1};
  reg [1:0] test_sel;
  reg [1:0] test_sel_reg;
  always @(*) begin
    case(test_btn)
      4'b0001: test_sel = 2'd0; // btn1 pressed -> Empty string
      4'b0010: test_sel = 2'd1; // btn2 pressed -> "abc"
      4'b0100: test_sel = 2'd2; // btn3 pressed -> "5abc"
      4'b1000: test_sel = 2'd3; // btn4 pressed -> Digital2 (will be fed incorrectly)
      default: test_sel = 2'd0; // Default to empty string
    endcase
  end

  //============================================================
  // Message memory and reference digest
  //============================================================
  reg [7:0] msg_mem [0:7]; // Supports up to 8 bytes.
  reg [3:0] msg_len;
  reg [255:0] ref_digest;

  localparam [255:0] 
    REF_EMPTY    = 256'h46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f,
    REF_ABC      = 256'h483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739,
    REF_5ABC     = 256'he237ed564232fa88f6e283b2be6e642c0fcc18804a53b227a1d3dbf2dd9e261e,
    REF_DIGITAL2 = 256'hddcb09a4cc414df7df1293d77eb8203fd9ad4ebbcbea08eda7412f8442745acd;

  //============================================================
  // Feeding: stream the message in 2-bit slices. This is important because the input needs to be fed in the order that FIPS 202 standard support
  // Total chunks = msg_len * 4.
  // Upper bits select the byte; lower bits select the 2-bit chunk.
  //============================================================
  reg [5:0] feed_cnt; // Maximum chunks = 8*4 = 32.
  wire [5:0] total_chunks = msg_len * 4;
  wire [3:0] current_byte = feed_cnt[5:2];   // feed_cnt / 4
  wire [1:0] current_chunk = feed_cnt[1:0];    // remainder

  //============================================================
  // FSM: Sequential Logic
  //============================================================
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      show_counter <= 0;
      aggregator_reset_int <= 1;
      core_start <= 0;
      core_enable <= 0;
      core_serial_end <= 0;
      core_serial_in <= 2'b00;
      msg_len <= 0;
      ref_digest <= 256'd0;
      feed_cnt <= 0;
      test_sel_reg <= 0;
      for (i = 0; i < 8; i = i + 1)
        msg_mem[i] <= 8'h00;
      led_idle <= 1;
      led_processing <= 0;
      led_correct <= 0;
      led_incorrect <= 0;
    end else begin
      case(state)
        S_IDLE: begin
          led_idle <= 1;
          led_processing <= 0;
          led_correct <= 0;
          led_incorrect <= 0;
          aggregator_reset_int <= 1; // Keep core in reset.
          feed_cnt <= 0;
          show_counter <= 0;
          // When sw_start is high and at least one test button is pressed,
          // latch the test selection.
          if (sw_start && (test_btn != 4'b0000)) begin
            test_sel_reg <= test_sel;
            state <= S_INIT;
          end else begin
            state <= S_IDLE;
          end
        end

        S_INIT: begin
          aggregator_reset_int <= 0; // Release core reset.
          led_idle <= 0;
          led_processing <= 1;
          // Load message and reference digest based on test_sel_reg.
          case(test_sel_reg)
            2'd0: begin // Empty string.
              msg_len <= 0;
              ref_digest <= REF_EMPTY;
            end
            2'd1: begin // "abc"
              msg_len <= 3;
              msg_mem[0] <= 8'h61;
              msg_mem[1] <= 8'h62;
              msg_mem[2] <= 8'h63;
              ref_digest <= REF_ABC;
            end
            2'd2: begin // "5abc"
              msg_len <= 4;
              msg_mem[0] <= 8'h35;
              msg_mem[1] <= 8'h61;
              msg_mem[2] <= 8'h62;
              msg_mem[3] <= 8'h63;
              ref_digest <= REF_5ABC;
            end
            2'd3: begin 
              // For Digital2, intentionally feed an incorrect message.
              // Instead of "Digital2" (44 69 67 69 74 61 6C 32),
              // we feed "WrongMsg" (57 72 6F 6E 67 4D 73 67).
				  // The reason is to prove that the checking works 
              msg_len <= 8;
              msg_mem[0] <= 8'h57; // W
              msg_mem[1] <= 8'h72; // r
              msg_mem[2] <= 8'h6F; // o
              msg_mem[3] <= 8'h6E; // n
              msg_mem[4] <= 8'h67; // g
              msg_mem[5] <= 8'h4D; // M
              msg_mem[6] <= 8'h73; // s
              msg_mem[7] <= 8'h67; // g
              // Reference digest remains Digital2's correct digest.
              ref_digest <= REF_DIGITAL2;
            end
          endcase
          core_start <= 1;
          feed_cnt <= 0;
          state <= S_INIT2;
        end

        S_INIT2: begin
          core_start <= 0; // Deassert core_start.
          state <= S_FEED;
        end

        S_FEED: begin
          if (feed_cnt < total_chunks) begin
            core_enable <= 1;
            // Send the current 2–bit slice from the current byte (MSB–first)
            core_serial_in <= msg_mem[current_byte][ (3 - current_chunk)*2 +: 2 ];
            state <= S_FEED_WAIT;
          end else begin
            state <= S_FINAL;
          end
        end

        S_FEED_WAIT: begin
          core_enable <= 0;
          feed_cnt <= feed_cnt + 1;
          state <= S_FEED;
        end

        S_FINAL: begin
          core_serial_end <= 1; // Signal end-of-feed so that core pads internally.
          state <= S_WAIT;
        end

        S_WAIT: begin
          core_serial_end <= 0;
          if (core_done)
            state <= S_COMPARE;
          else
            state <= S_WAIT;
        end

        S_COMPARE: begin
          led_processing <= 0;
          if (core_digest == ref_digest) begin
            led_correct <= 1;
            led_incorrect <= 0;
          end else begin
            led_correct <= 0;
            led_incorrect <= 1;
          end
          state <= S_SHOW;
          show_counter <= 0;
        end

        S_SHOW: begin
          if (show_counter < SHOW_LIMIT) begin
            show_counter <= show_counter + 1;
            state <= S_SHOW;
          end else begin
            state <= S_IDLE;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
