`timescale 1ns / 1ps

module timing_unit(
    input  wire        clk,
    input  wire        rst,
    input  wire        clk_1khz_en,
    input  wire        start_timer,
    input  wire        stop_timer,
    output reg  [15:0] reaction_time_ms,
    output reg         timer_running,
    output reg         timeout
);

    reg [15:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            counter          <= 16'd0;
            reaction_time_ms <= 16'd0;
            timer_running    <= 1'b0;
            timeout          <= 1'b0;
        end else begin
            timeout <= 1'b0; // Default de-assert to make it a 1-cycle pulse
            if (start_timer) begin
                counter          <= 16'd0;
                timer_running    <= 1'b1;
                timeout          <= 1'b0;
                reaction_time_ms <= 16'd0;
            end else if (timer_running) begin
                if (stop_timer) begin
                    reaction_time_ms <= counter;
                    timer_running    <= 1'b0;
                end else if (clk_1khz_en) begin
                    if (counter >= 16'd1499) begin
                        timeout          <= 1'b1;
                        timer_running    <= 1'b0;
                        reaction_time_ms <= 16'd1500;
                    end else begin
                        counter <= counter + 16'd1;
                    end
                end
            end
        end
    end

endmodule
