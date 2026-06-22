`timescale 1ns / 1ps

module random_lfsr(
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    output wire [15:0] rand_out
);

    reg [15:0] lfsr;

    // Galois LFSR: x^16 + x^14 + x^13 + x^11 + 1
    // Feedback taps on bits 15, 13, 12, 10
    always @(posedge clk) begin
        if (rst) begin
            lfsr <= 16'hACE1;
        end else if (en) begin
            lfsr <= {1'b0, lfsr[15:1]} ^ (lfsr[0] ? 16'hB400 : 16'h0000);
            // taps: bit15=1, bit13=1, bit12=1, bit10=1 -> 0xB400
        end
    end

    assign rand_out = lfsr;

endmodule
