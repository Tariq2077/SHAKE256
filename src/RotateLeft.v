module RotateLeft(
    input wire [63:0] bits,
    input wire [5:0] shift,          // Shift amount that can cover bits numebr (64)
    input wire clk,
    input wire reset,
    output reg [63:0] rotateLeft
);
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            rotateLeft <= 0;
        end else begin
            rotateLeft <= (bits << shift) | (bits >> (64 - shift));
        end
    end
endmodule
