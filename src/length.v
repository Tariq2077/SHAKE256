module Length #(parameter WIDTH = 8)(
    input clk,          // Clock signal
    input rst_n,        // Asynchronous reset, active low
    input serial_in,    // Serial input bit
    input enable,       // Enable counting
    output reg [11:0] count  // 12-bit counter (adjust size as needed)
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 0;      // Reset counter to 0
        else if (enable && serial_in)
            count <= count + 1;  // Increment counter on each bit received
    end
endmodule
