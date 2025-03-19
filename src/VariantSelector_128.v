`timescale 1ns/1ps
module VariantSelector_128 #(
    parameter VARIANT = 0  // Choose conversion variant: 0, 1, 2, or 3.
)(
    input  wire [127:0] in_data,   // Lower 128 bits from squeezed output (little-endian)
    output reg  [127:0] out_data   // Converted 128-bit digest candidate
);
    always @* begin
        case (VARIANT)
            0: begin
                // Variant 0: No conversion.
                out_data = in_data;
            end
            1: begin
                // Variant 1: Byte-swap each 64-bit lane individually.
                out_data = { 
                    { in_data[7:0],   in_data[15:8],  in_data[23:16],  in_data[31:24],
                      in_data[39:32], in_data[47:40], in_data[55:48],  in_data[63:56] },
                    { in_data[71:64], in_data[79:72], in_data[87:80],  in_data[95:88],
                      in_data[103:96],in_data[111:104],in_data[119:112], in_data[127:120] }
                };
            end
            2: begin
                // Variant 2: Full byte reversal of the 128-bit word.
                out_data = { 
                    in_data[7:0],
                    in_data[15:8],
                    in_data[23:16],
                    in_data[31:24],
                    in_data[39:32],
                    in_data[47:40],
                    in_data[55:48],
                    in_data[63:56],
                    in_data[71:64],
                    in_data[79:72],
                    in_data[87:80],
                    in_data[95:88],
                    in_data[103:96],
                    in_data[111:104],
                    in_data[119:112],
                    in_data[127:120]
                };
            end
            3: begin
                // Variant 3: Swap the two 64-bit lanes.
                out_data = { in_data[127:64], in_data[63:0] };
            end
            default: begin
                out_data = in_data;
            end
        endcase
    end
endmodule
