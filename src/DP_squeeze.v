module DP_squeeze(
    input  wire clk,
    input  wire start,
    input  wire [1599:0] Unsqueezed_data,
    output reg [511:0] Squeezed_data,  // changed from [1087:0] to 512 bits
    output reg squeeze_done
);
    always @(posedge clk) begin
        if (start) begin
            // Option: Extract the upper 512 bits (bits 1599 downto 1088)
            Squeezed_data <= Unsqueezed_data[1599:1088];
            squeeze_done  <= 1'b1;
        end else begin
            squeeze_done  <= 1'b0;
        end
    end
endmodule
