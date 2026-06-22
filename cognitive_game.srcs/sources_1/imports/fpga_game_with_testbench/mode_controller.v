`timescale 1ns / 1ps

module mode_controller(
    input  wire        clk,
    input  wire        rst,
    input  wire        latch_mode,
    input  wire        mode_sw,
    input  wire [1:0]  num_players_sw,
    output reg         multi_player_en,
    output reg  [1:0]  num_players_cfg
);

    always @(posedge clk) begin
        if (rst) begin
            multi_player_en <= 1'b0;
            num_players_cfg <= 2'b00;
        end else if (latch_mode) begin
            multi_player_en <= mode_sw;
            num_players_cfg <= num_players_sw;
        end
    end

endmodule
