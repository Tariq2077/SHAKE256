//=====================================================================
// Module: cShake256 (Top-Level)
// Description: Instantiates pad, absorb, keccak, squeeze, and control unit.
//=====================================================================
module cShake256 #(
    parameter STATE_WIDTH    = 1600,
    parameter RATE_WIDTH     = 1088,
    parameter CAPACITY_WIDTH = 512,
    parameter OUT_BITS       = 512
)(
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire enable,
    input  wire serial_in,
    input  wire serial_end_signal,
    input  wire [7:0] N,
    input  wire [7:0] S,
    output wire done,
    output wire [OUT_BITS-1:0] digest,
    output wire [3:0] debug_cshake_fsm, // mapped from Control_Unit state
    output wire [2:0] debug_pad_state,
    output wire [10:0] debug_pad_bitcount,
    output wire [10:0] debug_absorb_i,
    output wire [RATE_WIDTH-1:0] debug_domain_block, // pad output
    output wire [1:0] debug_kf_fsm,
    output wire [4:0] debug_kf_round,
    output wire [2:0] debug_ctrl_state
);

    wire pad_start, pad_done;
    wire absorb_start, absorb_done;
    wire keccak_start, keccak_done;
    wire squeeze_start, squeeze_done;
    wire truncate_start, truncate_done;
    wire encryption_done;
    
    wire [RATE_WIDTH-1:0] pad_out;
    wire [STATE_WIDTH-1:0] absorb_out, keccak_out;
    wire [OUT_BITS-1:0] squeeze_out, truncate_out;
    
    // Instantiate the Control Unit
    Control_Unit ctrl (
      .clk(clk),
      .reset(reset),
      .start(start),
      .pad_done(pad_done),
      .absorb_done(absorb_done),
      .keccak_done(keccak_done),
      .squeeze_done(squeeze_done),
      .truncate_done(truncate_done),
      .pad_start(pad_start),
      .absorb_start(absorb_start),
      .keccak_start(keccak_start),
      .squeeze_start(squeeze_start),
      .truncate_start(truncate_start),
      .encryption_done(encryption_done),
      .debug_ctrl_state(debug_ctrl_state)
    );
    
    // Instantiate the Pad module
    pad #(.RANGE(RATE_WIDTH)) pad_inst (
      .clk(clk),
      .reset(reset),
      .pad_start(pad_start),
      .enable(enable),
      .serial_in(serial_in),
      .serial_end_signal(serial_end_signal),
      .block_consumed(1'b0),
      .message(pad_out),
      .pad_done(pad_done),
      .debug_pad_state(debug_pad_state),
      .debug_pad_bitcount(debug_pad_bitcount)
    );
    // Expose pad_out as debug_domain_block
    assign debug_domain_block = pad_out;
    
    // Build the absorb block: lower RATE_WIDTH bits are from pad, upper bits zero.
    wire [STATE_WIDTH-1:0] absorb_block = { {(STATE_WIDTH - RATE_WIDTH){1'b0}}, pad_out };
    
    // Instantiate the Absorb module
    Absorb absorb_inst (
      .clk(clk),
      .reset(reset),
      .absorb_start(absorb_start),
      .state_in({STATE_WIDTH{1'b0}}),
      .Block(absorb_block),
      .absorb_state_out(absorb_out),
      .absorb_done(absorb_done),
      .debug_absorb_i(debug_absorb_i)
    );
    
    // Instantiate the KeccakF1600 module
    KeccakF1600 keccak_inst (
      .clk(clk),
      .reset(reset),
      .keccak_start(keccak_start),
      .state_in(absorb_out),
      .state_out(keccak_out),
      .done(keccak_done),
      .debug_kf_fsm(debug_kf_fsm),
      .debug_kf_round(debug_kf_round)
    );
    
    // Instantiate the Squeeze module
    Squeeze_mod #(
      .RATE(RATE_WIDTH),
      .OUTPUT_WIDTH(OUT_BITS),
      .STATE_WIDTH(STATE_WIDTH)
    ) squeeze_inst (
      .clk(clk),
      .reset(reset),
      .squeeze_start(squeeze_start),
      .initial_state(keccak_out),
      .Squeezed_data(squeeze_out),
      .squeeze_done(squeeze_done)
    );
    
    // For this example, we simply pass the squeeze output to the final digest.
    assign truncate_out = squeeze_out;
    assign truncate_done = 1'b1; // combinational
    
    assign digest = truncate_out;
    assign done = encryption_done;
    // Map debug_cshake_fsm from the control unit state (pad state can be extended to 4 bits)
    assign debug_cshake_fsm = {1'b0, debug_ctrl_state};
endmodule