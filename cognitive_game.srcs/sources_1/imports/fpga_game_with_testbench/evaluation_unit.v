`timescale 1ns / 1ps

module evaluation_unit(
    input  wire        clk,
    input  wire        rst,
    input  wire        start_eval,
    input  wire [1:0]  total_players,
    input  wire [15:0] acc_p0,
    input  wire [15:0] acc_p1,
    input  wire [15:0] acc_p2,
    input  wire [15:0] acc_p3,
    input  wire [15:0] avg_rt_p0,
    input  wire [15:0] avg_rt_p1,
    input  wire [15:0] avg_rt_p2,
    input  wire [15:0] avg_rt_p3,
    output reg  [1:0]  best_player_id,
    output reg  [1:0]  rank_p0,
    output reg  [1:0]  rank_p1,
    output reg  [1:0]  rank_p2,
    output reg  [1:0]  rank_p3,
    output reg         eval_done
);

    // beats_fn: returns 1 if player A beats player B
    // Higher accuracy wins; if tied, lower avg RT wins
    function beats_fn;
        input [15:0] a_acc, a_rt, b_acc, b_rt;
        begin
            beats_fn = (a_acc > b_acc) || ((a_acc == b_acc) && (a_rt < b_rt));
        end
    endfunction

    // Active player flags
    wire p1_active = (total_players >= 2'd1);
    wire p2_active = (total_players >= 2'd2);
    wire p3_active = (total_players >= 2'd3);

    // All 12 pairwise comparison wires - explicit, no loops (Rule 3)
    wire p0b1 = beats_fn(acc_p0, avg_rt_p0, acc_p1, avg_rt_p1) & p1_active;
    wire p0b2 = beats_fn(acc_p0, avg_rt_p0, acc_p2, avg_rt_p2) & p2_active;
    wire p0b3 = beats_fn(acc_p0, avg_rt_p0, acc_p3, avg_rt_p3) & p3_active;
    wire p1b0 = beats_fn(acc_p1, avg_rt_p1, acc_p0, avg_rt_p0);
    wire p1b2 = beats_fn(acc_p1, avg_rt_p1, acc_p2, avg_rt_p2) & p2_active;
    wire p1b3 = beats_fn(acc_p1, avg_rt_p1, acc_p3, avg_rt_p3) & p3_active;
    wire p2b0 = beats_fn(acc_p2, avg_rt_p2, acc_p0, avg_rt_p0);
    wire p2b1 = beats_fn(acc_p2, avg_rt_p2, acc_p1, avg_rt_p1);
    wire p2b3 = beats_fn(acc_p2, avg_rt_p2, acc_p3, avg_rt_p3) & p3_active;
    wire p3b0 = beats_fn(acc_p3, avg_rt_p3, acc_p0, avg_rt_p0);
    wire p3b1 = beats_fn(acc_p3, avg_rt_p3, acc_p1, avg_rt_p1);
    wire p3b2 = beats_fn(acc_p3, avg_rt_p3, acc_p2, avg_rt_p2);

    // Beat scores - no loops (Rule 3)
    wire [1:0] sc0 = {1'b0, p0b1} + {1'b0, p0b2} + {1'b0, p0b3};
    wire [1:0] sc1 = {1'b0, p1b0} + {1'b0, p1b2} + {1'b0, p1b3};
    wire [1:0] sc2 = {1'b0, p2b0} + {1'b0, p2b1} + {1'b0, p2b3};
    wire [1:0] sc3 = {1'b0, p3b0} + {1'b0, p3b1} + {1'b0, p3b2};

    // Best player - priority to lower index on tie
    reg [1:0] best_comb;
    always @(*) begin
        if (sc0 >= sc1 && sc0 >= sc2 && sc0 >= sc3)
            best_comb = 2'd0;
        else if (sc1 >= sc2 && sc1 >= sc3)
            best_comb = 2'd1;
        else if (sc2 >= sc3)
            best_comb = 2'd2;
        else
            best_comb = 2'd3;
    end

    // Ranks: score 3 = best = rank 0, score 0 = worst = rank 3
    wire [1:0] r0 = 2'd3 - sc0;
    wire [1:0] r1 = 2'd3 - sc1;
    wire [1:0] r2 = 2'd3 - sc2;
    wire [1:0] r3 = 2'd3 - sc3;

    always @(posedge clk) begin
        if (rst) begin
            best_player_id <= 2'd0;
            rank_p0        <= 2'd0;
            rank_p1        <= 2'd0;
            rank_p2        <= 2'd0;
            rank_p3        <= 2'd0;
            eval_done      <= 1'b0;
        end else begin
            eval_done <= 1'b0; // de-assert by default

            if (start_eval) begin
                best_player_id <= best_comb;
                rank_p0        <= r0;
                rank_p1        <= r1;
                rank_p2        <= r2;
                rank_p3        <= r3;
                eval_done      <= 1'b1;
            end
        end
    end

endmodule
