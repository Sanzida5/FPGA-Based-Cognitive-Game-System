`timescale 1ns / 1ps

module player_manager(
    input  wire        clk,
    input  wire        rst,
    input  wire        next_player,
    input  wire        trial_done,
    input  wire [1:0]  num_players_sel,
    output reg  [1:0]  current_player,
    output reg  [3:0]  trial_count,
    output reg         player_done,
    output reg         all_players_done,
    output wire [1:0]  total_players
);

    localparam [3:0] TRIALS_PER_PLAYER = 4'd10;

    reg [1:0] total_players_r;
    always @(*) begin
        case (num_players_sel)
            2'b00:   total_players_r = 2'd0;
            2'b01:   total_players_r = 2'd1;
            2'b10:   total_players_r = 2'd2;
            default: total_players_r = 2'd3;
        endcase
    end
    assign total_players = total_players_r;

    always @(posedge clk) begin
        if (rst) begin
            current_player   <= 2'd0;
            trial_count      <= 4'd0;
            player_done      <= 1'b0;
            all_players_done <= 1'b0;
        end else begin
            player_done <= 1'b0;

            if (trial_done) begin
                all_players_done <= 1'b0; // Always clear game done flag so next game can start without hardware reset
                if (trial_count == TRIALS_PER_PLAYER - 1) begin
                    trial_count <= 4'd0;
                    player_done <= 1'b1;
                end else begin
                    trial_count <= trial_count + 4'd1;
                end
            end

            if (next_player) begin
                trial_count <= 4'd0;
                if (current_player >= total_players_r + 2'd1) begin
                    all_players_done <= 1'b1;
                    current_player <= 2'd0; // Wrap back to Player 1 for next game
                end else begin
                    current_player <= current_player + 2'd1;
                end
            end
        end
    end

endmodule
