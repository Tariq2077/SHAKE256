`timescale 1ns/1ps
module Convert_Digest_rev_128_always (
    input  wire [127:0] in_data,  // lower 128 bits of squeezed data (little-endian)
    output reg  [127:0] out_data  // converted digest in big-endian byte order
);
    always @* begin
        // Reverse the byte order:
        // The most-significant 8 bits of out_data come from in_data[127:120], etc.
        out_data[7:0]    = in_data[127:120];
        out_data[15:8]   = in_data[119:112];
        out_data[23:16]  = in_data[111:104];
        out_data[31:24]  = in_data[103:96];
        out_data[39:32]  = in_data[95:88];
        out_data[47:40]  = in_data[87:80];
        out_data[55:48]  = in_data[79:72];
        out_data[63:56]  = in_data[71:64];
        out_data[71:64]  = in_data[63:56];
        out_data[79:72]  = in_data[55:48];
        out_data[87:80]  = in_data[47:40];
        out_data[95:88]  = in_data[39:32];
        out_data[103:96] = in_data[31:24];
        out_data[111:104]= in_data[23:16];
        out_data[119:112]= in_data[15:8];
        out_data[127:120]= in_data[7:0];
    end
endmodule
