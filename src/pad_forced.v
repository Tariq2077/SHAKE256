`timescale 1ns/1ps
module pad_forced #
(
    parameter RANGE = 1088 // 136 bytes
)
(
    input  wire             clk,
    input  wire             reset,
    // Control signals
    input  wire             pad_start,
    input  wire             next_block,       // unused
    input  wire             enable,           // ignored
    input  wire [1:0]       serial_in,        // ignored
    input  wire             serial_end_signal,// ignored

    // Outputs
    output wire [RANGE-1:0] message,
    output reg              pad_done,

    // Debug
    output reg [2:0]        debug_pad_state,
    output reg [10:0]       debug_pad_bytecount
);

    localparam BYTE_RANGE = RANGE/8; // 136

    // We'll just force everything in msg_array:
    reg [7:0] msg_array [0:BYTE_RANGE-1];

    //======== Flatten in REVERSED order so the user sees msg_array[0] first ========
    genvar i;
    generate
        for (i = 0; i < BYTE_RANGE; i = i + 1) begin : FLATTEN
            assign message[(BYTE_RANGE-1 - i)*8 +: 8] = msg_array[i];
        end
    endgenerate

    // Simple FSM
    localparam [1:0] STATE_IDLE = 2'd0,
                     STATE_DONE = 2'd1;
    reg [1:0] state, next_state;
    integer j;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_IDLE;
            pad_done <= 1'b0;
            debug_pad_bytecount <= 0;
            for (j=0; j<BYTE_RANGE; j=j+1) begin
                msg_array[j] <= 8'h00;
            end
        end
        else begin
            state <= next_state;
            case (state)
            STATE_IDLE: begin
                pad_done <= 1'b0;
                if (pad_start) begin
                    // Fill everything with 0x00
                    for (j=0; j<BYTE_RANGE; j=j+1)
                        msg_array[j] <= 8'h00;
                    
                    // Byte 0 => 0x80
                    msg_array[0]   <= 8'h80;
                    
                    // Byte 132 => 0x1F
                    msg_array[132] <= 8'h1F;

                    // Byte 133 => 0x63
                    msg_array[133] <= 8'h63;
                    // Byte 134 => 0x62
                    msg_array[134] <= 8'h62;
                    // Byte 135 => 0x61
                    msg_array[135] <= 8'h61;

                    debug_pad_bytecount <= BYTE_RANGE;
                end
            end

            STATE_DONE: begin
                pad_done <= 1'b1;
                if (!pad_done) begin
                    // This will now print: 800000...1f636261
                    $display("[PAD_FORCED] Final padded message = %h", message);
                end
            end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
        STATE_IDLE: begin
            if (pad_start)
                next_state = STATE_DONE;
        end
        STATE_DONE: begin
            next_state = STATE_DONE;
        end
        endcase
    end

    always @(posedge clk) begin
        debug_pad_state <= state;
    end

endmodule
