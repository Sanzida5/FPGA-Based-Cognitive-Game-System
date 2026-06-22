`timescale 1ns / 1ps

module alu(
    input  wire        clk,
    input  wire        rst,
    input  wire [1:0]  op_sel,
    input  wire        en,
    input  wire [3:0]  response_switch,
    input  wire [3:0]  active_led,
    input  wire [15:0] reaction_time_ms,
    input  wire [15:0] threshold_ms,
    input  wire [15:0] hits,
    input  wire [15:0] total_attempts,
    input  wire [31:0] sum_reaction_time,
    output reg  [15:0] result,
    output reg         hit_flag,
    output reg         result_valid
);

    always @(posedge clk) begin
        if (rst) begin
            result       <= 16'd0;
            hit_flag     <= 1'b0;
            result_valid <= 1'b0;
        end else begin
            result_valid <= 1'b0; // de-assert by default

            if (en) begin
                result_valid <= 1'b1;
                case (op_sel)
                    2'b00: begin
                        if (response_switch == active_led) begin
                            hit_flag <= 1'b1;
                            result   <= 16'd1;
                        end else begin
                            hit_flag <= 1'b0;
                            result   <= 16'd0;
                        end
                    end
                    2'b01: begin
                        result <= (reaction_time_ms <= threshold_ms) ? 16'd1 : 16'd0;
                    end
                    2'b10: begin
                        result <= hits;
                    end
                    2'b11: begin
                        result <= sum_reaction_time[15:0];
                    end
                endcase
            end
        end
    end

endmodule
