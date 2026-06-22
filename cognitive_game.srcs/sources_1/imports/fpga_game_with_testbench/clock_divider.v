`timescale 1ns / 1ps

module clock_divider(
    input  wire clk,
    input  wire rst,
    output reg  clk_1khz_en,
    output reg  clk_500hz_en,
    output reg  clk_1hz_en
);

    // 1kHz: 100MHz / 100000 = 1kHz
    reg [16:0] cnt_1khz;
    localparam [16:0] THRESH_1KHZ = 17'd99999;

    // 500Hz: 100MHz / 200000 = 500Hz
    reg [17:0] cnt_500hz;
    localparam [17:0] THRESH_500HZ = 18'd199999;

    // 1Hz: 100MHz / 100000000 = 1Hz
    reg [26:0] cnt_1hz;
    localparam [26:0] THRESH_1HZ = 27'd99999999;

    always @(posedge clk) begin
        if (rst) begin
            cnt_1khz   <= 17'd0;
            clk_1khz_en <= 1'b0;
            cnt_500hz  <= 18'd0;
            clk_500hz_en <= 1'b0;
            cnt_1hz    <= 27'd0;
            clk_1hz_en <= 1'b0;
        end else begin
            // 1kHz enable
            if (cnt_1khz == THRESH_1KHZ) begin
                cnt_1khz   <= 17'd0;
                clk_1khz_en <= 1'b1;
            end else begin
                cnt_1khz   <= cnt_1khz + 17'd1;
                clk_1khz_en <= 1'b0;
            end

            // 500Hz enable
            if (cnt_500hz == THRESH_500HZ) begin
                cnt_500hz   <= 18'd0;
                clk_500hz_en <= 1'b1;
            end else begin
                cnt_500hz   <= cnt_500hz + 18'd1;
                clk_500hz_en <= 1'b0;
            end

            // 1Hz enable
            if (cnt_1hz == THRESH_1HZ) begin
                cnt_1hz   <= 27'd0;
                clk_1hz_en <= 1'b1;
            end else begin
                cnt_1hz   <= cnt_1hz + 27'd1;
                clk_1hz_en <= 1'b0;
            end
        end
    end

endmodule
