`timescale 1ns / 1ps

// ============================================================
// SIMULATION-ONLY clock_divider — thresholds reduced 1000x
// DO NOT use this for synthesis! Use the real clock_divider.v
// ============================================================
module clock_divider(
    input  wire clk,
    input  wire rst,
    output reg  clk_1khz_en,
    output reg  clk_500hz_en,
    output reg  clk_1hz_en
);

    // Real hardware: 99999 / 199999 / 99999999
    // Simulation:    99    / 199    / 99999 (1000x faster)
    reg [16:0] cnt_1khz;
    localparam [16:0] THRESH_1KHZ = 17'd99;

    reg [17:0] cnt_500hz;
    localparam [17:0] THRESH_500HZ = 18'd199;

    reg [26:0] cnt_1hz;
    localparam [26:0] THRESH_1HZ = 27'd99999;

    always @(posedge clk) begin
        if (rst) begin
            cnt_1khz     <= 17'd0;
            clk_1khz_en  <= 1'b0;
            cnt_500hz    <= 18'd0;
            clk_500hz_en <= 1'b0;
            cnt_1hz      <= 27'd0;
            clk_1hz_en   <= 1'b0;
        end else begin
            if (cnt_1khz == THRESH_1KHZ) begin
                cnt_1khz    <= 17'd0;
                clk_1khz_en <= 1'b1;
            end else begin
                cnt_1khz    <= cnt_1khz + 17'd1;
                clk_1khz_en <= 1'b0;
            end

            if (cnt_500hz == THRESH_500HZ) begin
                cnt_500hz    <= 18'd0;
                clk_500hz_en <= 1'b1;
            end else begin
                cnt_500hz    <= cnt_500hz + 18'd1;
                clk_500hz_en <= 1'b0;
            end

            if (cnt_1hz == THRESH_1HZ) begin
                cnt_1hz    <= 27'd0;
                clk_1hz_en <= 1'b1;
            end else begin
                cnt_1hz    <= cnt_1hz + 27'd1;
                clk_1hz_en <= 1'b0;
            end
        end
    end

endmodule
