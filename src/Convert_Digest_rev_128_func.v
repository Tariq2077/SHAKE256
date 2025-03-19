`timescale 1ns/1ps
module Convert_Digest_rev_128_always (
    input  wire [127:0] in_data,   // Lower 128 bits from squeezed output (little-endian per 64-bit lane)
    output reg  [127:0] out_data   // Converted digest (each 64-bit lane reversed to big-endian)
);
    always @* begin
        // Reverse the byte order in the lower 64-bit lane:
        out_data[63:0] = { in_data[7:0],
                           in_data[15:8],
                           in_data[23:16],
                           in_data[31:24],
                           in_data[39:32],
                           in_data[47:40],
                           in_data[55:48],
                           in_data[63:56] };
        // Reverse the byte order in the upper 64-bit lane:
        out_data[127:64] = { in_data[71:64],
                             in_data[79:72],
                             in_data[87:80],
                             in_data[95:88],
                             in_data[103:96],
                             in_data[111:104],
                             in_data[119:112],
                             in_data[127:120] };
    end
endmodule
