module ByteReverse #(parameter WIDTH = 256) (
    input  wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
    genvar i;
    generate
      for (i = 0; i < WIDTH/8; i = i + 1) begin : rev_loop
        assign out[i*8 +: 8] = in[((WIDTH/8)-1-i)*8 +: 8];
      end
    endgenerate
endmodule