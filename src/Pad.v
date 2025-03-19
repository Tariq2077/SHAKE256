`timescale 1ns/1ps
module pad #
(
    parameter RANGE = 1088 // 136 bytes total
)
(
    input  wire             clk,
    input  wire             reset,
    // Control signals:
    input  wire             pad_start,
    input  wire             next_block,    // (unused here)
    input  wire             enable,        // latch 2-bit chunk
    input  wire [1:0]       serial_in,
    input  wire             serial_end_signal,

    // Outputs:
    output wire [RANGE-1:0] message, // Flattened final 1088-bit block
    output reg              pad_done,

    // Debug
    output reg [2:0]        debug_pad_state,
    output reg [10:0]       debug_pad_bytecount
);

    //----------------------------------------------------------------
    // We'll store user data in msg_temp[0..135] => up to 136 bytes.
    // Then build the final block in msg_array:
    //   [0] = 0x80
    //   fill zeros
    //   domain_idx = 135 - data_count
    //   if domain_idx>0 => msg_array[domain_idx] = 0x1F
    //   reversed user data in [135..(135-data_count+1)]
    //----------------------------------------------------------------

    localparam BYTE_RANGE = RANGE / 8; // 136
    localparam MAX_DATA   = 136;       // store up to 136 bytes

    reg [7:0] msg_array [0:BYTE_RANGE-1];
    reg [7:0] msg_temp  [0:MAX_DATA-1];
    reg [7:0] data_count; // how many bytes actually collected

    // For building each byte from 4 x 2-bit chunks (MSB-first)
    reg [7:0] temp_byte;
    reg [1:0] chunk_count;

    // We'll declare domain_idx here at module scope (or we can do 'integer domain_idx;')
    // to avoid "reg" declarations inside an always block.
    integer domain_idx;

    // FSM
    localparam [2:0] STATE_IDLE     = 3'd0,
                     STATE_COLLECT  = 3'd1,
                     STATE_FINALIZE = 3'd2,
                     STATE_DONE     = 3'd3;
    reg [2:0] state, next_state;

    integer i;

    //--------------------------------------------------------------
    // Flatten so msg_array[0] => left nibble in the final hex
    //--------------------------------------------------------------
    genvar gi;
    generate
        for (gi=0; gi<BYTE_RANGE; gi=gi+1) begin : FLATTEN
            assign message[(BYTE_RANGE-1-gi)*8 +: 8] = msg_array[gi];
        end
    endgenerate

    //--------------------------------------------------------------
    // Next-state logic
    //--------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
        STATE_IDLE: begin
            if (pad_start)
                next_state = STATE_COLLECT;
        end
        STATE_COLLECT: begin
            // once user ends input => finalize
            if (serial_end_signal)
                next_state = STATE_FINALIZE;
        end
        STATE_FINALIZE: begin
            next_state = STATE_DONE;
        end
        STATE_DONE: begin
            next_state = STATE_DONE;
        end
        endcase
    end

    //--------------------------------------------------------------
    // FSM sequential
    //--------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_IDLE;
            pad_done <= 1'b0;
            debug_pad_bytecount <= 0;

            chunk_count <= 0;
            temp_byte   <= 8'h00;
            data_count  <= 0;

            for (i=0; i<BYTE_RANGE; i=i+1)
                msg_array[i] <= 8'h00;
            for (i=0; i<MAX_DATA; i=i+1)
                msg_temp[i] <= 8'h00;
        end
        else begin
            state <= next_state;

            case (state)

            //--------------------------------------------------
            // STATE_IDLE => wait for pad_start
            //--------------------------------------------------
            STATE_IDLE: begin
                pad_done <= 1'b0;
                if (pad_start) begin
                    chunk_count <= 0;
                    temp_byte   <= 8'h00;
                    data_count  <= 0;
                    for (i=0; i<BYTE_RANGE; i=i+1)
                        msg_array[i] <= 8'h00;
                    for (i=0; i<MAX_DATA; i=i+1)
                        msg_temp[i] <= 8'h00;
                    debug_pad_bytecount <= 0;
                end
            end

            //--------------------------------------------------
            // STATE_COLLECT => gather data in msg_temp
            //--------------------------------------------------
            STATE_COLLECT: begin
                if (enable) begin
                    // SHIFT LEFT 2, then OR
                    temp_byte <= (temp_byte << 2) | serial_in;
                    if (chunk_count == 3) begin
                        // completed one byte
                        if (data_count < MAX_DATA) begin
                            msg_temp[data_count] <= (temp_byte << 2) | serial_in;
                            data_count <= data_count + 1;
                        end
                        temp_byte   <= 8'h00;
                        chunk_count <= 0;
                    end
                    else begin
                        chunk_count <= chunk_count + 1;
                    end
                end

                // if user ends mid-byte
                if (serial_end_signal) begin
                    if (chunk_count != 0 && (data_count < MAX_DATA)) begin
                        msg_temp[data_count] <=
                            (temp_byte << (2*(3 - chunk_count)));
                        data_count <= data_count + 1;
                    end
                end
            end

            //--------------------------------------------------
            // STATE_FINALIZE => build final block
            //--------------------------------------------------
            STATE_FINALIZE: begin
                // 1) fill all with 0x00
                for (i=0; i<BYTE_RANGE; i=i+1) begin
                    msg_array[i] <= 8'h00;
                end

                // 2) msg_array[0] = 0x80
                msg_array[0] <= 8'h80;

                // 3) domain_idx = 135 - data_count
                domain_idx = (BYTE_RANGE-1) - data_count; // 135 - data_count

                // if domain_idx>0 => place 0x1F
                if (domain_idx > 0) begin
                    msg_array[domain_idx] <= 8'h1F;
                end

                // 4) reversed data in [135..(135-data_count+1)]
                for (i=0; i<MAX_DATA; i=i+1) begin
                    if (i < data_count) begin
                        msg_array[135 - i] <= msg_temp[i];
                    end
                end

                debug_pad_bytecount <= BYTE_RANGE; // 136
            end

            //--------------------------------------------------
            // STATE_DONE
            //--------------------------------------------------
            STATE_DONE: begin
                pad_done <= 1'b1;
                if (!pad_done) begin
                    $display("[PAD_REVERSED_DYNAMIC] Final padded message = %h", message);
                end
            end

            endcase
        end
    end

    always @(posedge clk) begin
        debug_pad_state <= state;
    end

endmodule
