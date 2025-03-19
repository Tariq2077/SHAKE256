module CU_squeeze(
    input  wire opcode,
    output reg start
);
    always @(*) begin
        start = opcode;
    end
endmodule
