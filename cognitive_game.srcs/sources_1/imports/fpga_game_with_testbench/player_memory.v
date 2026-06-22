`timescale 1ns / 1ps

module player_memory(
    input  wire        clk,
    input  wire        rst,
    input  wire        write_en,
    input  wire [1:0]  player_id,
    input  wire [15:0] hit_count_in,
    input  wire [15:0] miss_count_in,
    input  wire [15:0] total_attempts_in,
    input  wire [31:0] sum_rt_in,
    input  wire [15:0] best_rt_in,
    input  wire [15:0] accuracy_pct_in,
    input  wire [1:0]  read_player_id,
    output wire [15:0] hit_count_out,
    output wire [15:0] miss_count_out,
    output wire [15:0] total_attempts_out,
    output wire [31:0] sum_rt_out,
    output wire [15:0] best_rt_out,
    output wire [15:0] accuracy_pct_out
);

    reg [15:0] mem_hits    [0:3];
    reg [15:0] mem_miss    [0:3];
    reg [15:0] mem_total   [0:3];
    reg [31:0] mem_sum_rt  [0:3];
    reg [15:0] mem_best_rt [0:3];
    reg [15:0] mem_acc     [0:3];

    integer k;

    // Synchronous write
    always @(posedge clk) begin
        if (rst) begin
            for (k = 0; k < 4; k = k + 1) begin
                mem_hits[k]    <= 16'd0;
                mem_miss[k]    <= 16'd0;
                mem_total[k]   <= 16'd0;
                mem_sum_rt[k]  <= 32'd0;
                mem_best_rt[k] <= 16'hFFFF;
                mem_acc[k]     <= 16'd0;
            end
        end else if (write_en) begin
            mem_hits[player_id]    <= hit_count_in;
            mem_miss[player_id]    <= miss_count_in;
            mem_total[player_id]   <= total_attempts_in;
            mem_sum_rt[player_id]  <= sum_rt_in;
            mem_best_rt[player_id] <= best_rt_in;
            mem_acc[player_id]     <= accuracy_pct_in;
        end
    end

    // Asynchronous combinational read
    assign hit_count_out      = mem_hits[read_player_id];
    assign miss_count_out     = mem_miss[read_player_id];
    assign total_attempts_out = mem_total[read_player_id];
    assign sum_rt_out         = mem_sum_rt[read_player_id];
    assign best_rt_out        = mem_best_rt[read_player_id];
    assign accuracy_pct_out   = mem_acc[read_player_id];

endmodule
