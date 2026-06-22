`timescale 1ns / 1ps

module top(
    input  wire        clk,
    input  wire        btnL,
    input  wire        btnR,
    input  wire        btnC,
    input  wire        btnU,
    input  wire [15:0] sw,
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire [3:0]  an,
    output wire        dp
);

    // ──────────────────────────────────────────────────────────
    // Reset: use raw btnU for synchronous reset of all modules.
    // btnU is directly wired (active HIGH). Since all FFs use
    // posedge clk, this is a synchronous reset and safe.
    // The debounced btn_reset_deb is used by FSM for mid-game reset.
    // ──────────────────────────────────────────────────────────
    wire rst = btnU;

    // Clock enable pulses
    wire clk_1khz_en, clk_500hz_en, clk_1hz_en;

    // Switch and button debounced / press events
    wire [15:0] sw_debounced;
    wire [15:0] press_event;
    wire [15:0] btn_debounced_bus;
    wire [15:0] btn_press_event_bus;

    wire btn_start_deb;
    wire btn_reset_deb;
    wire btn_right_deb;
    wire btn_left_deb;

    // Mode config
    wire multi_player_en;
    wire [1:0] num_players_cfg;
    wire latch_mode;

    // LFSR
    wire lfsr_en;
    wire [15:0] rand_val;

    // Stimulus
    wire trigger_stimulus, clear_stimulus;
    wire [15:0] led_out;
    wire [3:0]  active_led_idx;
    wire stimulus_active;

    // Timing
    wire start_timer, stop_timer;
    wire [15:0] reaction_time_ms;
    wire timer_running, timeout;

    // ALU
    wire [1:0]  alu_op;
    wire        alu_en;
    wire [15:0] alu_result;
    wire        hit_flag;
    wire        alu_result_valid;

    // Memory
    wire mem_write;

    // Player manager
    wire trial_done_pulse, next_player_pulse;
    wire [1:0] current_player;
    wire [3:0] trial_count;
    wire player_done, all_players_done;
    wire [1:0] total_players;

    // Evaluation
    wire start_eval, eval_done;
    wire [1:0] best_player_id;
    wire [1:0] rank_p0, rank_p1, rank_p2, rank_p3;

    // Display
    wire [2:0] disp_mode;
    wire response_valid;
    wire [3:0] captured_switch;

    // FSM Browse Output
    wire result_browsing;
    wire [1:0] display_player_id;

    // ─── Scratchpad registers ───
    reg [15:0] hits_cur;
    reg [15:0] miss_cur;
    reg [15:0] total_cur;
    reg [31:0] sum_rt_cur;
    reg [15:0] best_rt_cur;

    always @(posedge clk) begin
        if (rst || next_player_pulse || latch_mode) begin
            hits_cur    <= 16'd0;
            miss_cur    <= 16'd0;
            total_cur   <= 16'd0;
            sum_rt_cur  <= 32'd0;
            best_rt_cur <= 16'hFFFF;
        end else if (alu_result_valid && alu_op == 2'b00) begin
            total_cur  <= total_cur + 16'd1;
            sum_rt_cur <= sum_rt_cur + {16'd0, reaction_time_ms};
            if (hit_flag) begin
                hits_cur <= hits_cur + 16'd1;
                if (reaction_time_ms < best_rt_cur)
                    best_rt_cur <= reaction_time_ms;
            end else begin
                miss_cur <= miss_cur + 16'd1;
            end
        end
    end

    // ─── Accuracy and average RT (combinational — always up to date) ───
    wire [15:0] acc_write    = hits_cur * 16'd10;
    wire [15:0] avg_rt_write = sum_rt_cur / 32'd10;

    // ─── Snapshot arrays ───
    reg [15:0] acc_snap  [0:3];
    reg [15:0] avrt_snap [0:3];

    always @(posedge clk) begin
        if (rst) begin
            acc_snap[0]  <= 16'd0; acc_snap[1]  <= 16'd0;
            acc_snap[2]  <= 16'd0; acc_snap[3]  <= 16'd0;
            avrt_snap[0] <= 16'd0; avrt_snap[1] <= 16'd0;
            avrt_snap[2] <= 16'd0; avrt_snap[3] <= 16'd0;
        end else if (mem_write) begin
            acc_snap[current_player]  <= acc_write;
            avrt_snap[current_player] <= avg_rt_write;
        end
    end

    // Scalar wires from snapshot arrays (Rule 4: NO reg array direct port connections)
    wire [15:0] acc_snap_p0  = acc_snap[0];
    wire [15:0] acc_snap_p1  = acc_snap[1];
    wire [15:0] acc_snap_p2  = acc_snap[2];
    wire [15:0] acc_snap_p3  = acc_snap[3];
    wire [15:0] avrt_snap_p0 = avrt_snap[0];
    wire [15:0] avrt_snap_p1 = avrt_snap[1];
    wire [15:0] avrt_snap_p2 = avrt_snap[2];
    wire [15:0] avrt_snap_p3 = avrt_snap[3];

    // Button press events mapped to specific functions, filtered to only trigger on PRESS (rising edge)
    // Rule 9 states press_event fires on any direction change (XOR).
    assign btn_start_deb = btn_press_event_bus[0] & btn_debounced_bus[0]; // btnC
    assign btn_reset_deb = btn_press_event_bus[1] & btn_debounced_bus[1]; // btnU
    assign btn_right_deb = btn_press_event_bus[2] & btn_debounced_bus[2]; // btnR
    assign btn_left_deb  = btn_press_event_bus[3] & btn_debounced_bus[3]; // btnL

    // LED output
    assign led = led_out;

    // Memory read wires (Not directly fed to display during browse, but available for future use)
    wire [15:0] mem_hit_out, mem_miss_out, mem_total_out;
    wire [31:0] mem_sum_rt_out;
    wire [15:0] mem_best_rt_out, mem_acc_out;

    // ─── Display MUX specifically for browsing functionality ───
    reg [15:0] muxed_avg_rt;
    reg [15:0] muxed_acc;

    always @(*) begin
        case (display_player_id)
            2'd0: begin muxed_avg_rt = avrt_snap_p0; muxed_acc = acc_snap_p0; end
            2'd1: begin muxed_avg_rt = avrt_snap_p1; muxed_acc = acc_snap_p1; end
            2'd2: begin muxed_avg_rt = avrt_snap_p2; muxed_acc = acc_snap_p2; end
            2'd3: begin muxed_avg_rt = avrt_snap_p3; muxed_acc = acc_snap_p3; end
        endcase
    end

    wire [15:0] display_rt  = result_browsing ? muxed_avg_rt : reaction_time_ms;
    wire [15:0] display_acc = result_browsing ? muxed_acc    : acc_write;

    // ════════════════════════════════════════════════════════
    // Module instantiations
    // ════════════════════════════════════════════════════════

    clock_divider u_clk_div (
        .clk         (clk),
        .rst         (rst),
        .clk_1khz_en (clk_1khz_en),
        .clk_500hz_en(clk_500hz_en),
        .clk_1hz_en  (clk_1hz_en)
    );

    // Button debouncer (btnC=bit0, btnU=bit1, btnR=bit2, btnL=bit3)
    event_detector u_btn_deb (
        .clk         (clk),
        .rst         (rst),
        .clk_1khz_en (clk_1khz_en),
        .sw_in       ({12'b0, btnL, btnR, btnU, btnC}),
        .sw_debounced(btn_debounced_bus),
        .press_event (btn_press_event_bus)
    );

    // Switch debouncer
    event_detector u_sw_deb (
        .clk         (clk),
        .rst         (rst),
        .clk_1khz_en (clk_1khz_en),
        .sw_in       (sw),
        .sw_debounced(sw_debounced),
        .press_event (press_event)
    );

    mode_controller u_mode_ctrl (
        .clk             (clk),
        .rst             (rst),
        .latch_mode      (latch_mode),
        .mode_sw         (sw_debounced[0]),
        .num_players_sw  (sw_debounced[2:1]),
        .multi_player_en (multi_player_en),
        .num_players_cfg (num_players_cfg)
    );

    random_lfsr u_lfsr (
        .clk     (clk),
        .rst     (rst),
        .en      (lfsr_en),
        .rand_out(rand_val)
    );

    stimulus_generator u_stim (
        .clk            (clk),
        .rst            (rst),
        .trigger        (trigger_stimulus),
        .clear_stimulus (clear_stimulus),
        .rand_val       (rand_val),
        .led_out        (led_out),
        .active_led_idx (active_led_idx),
        .stimulus_active(stimulus_active)
    );

    timing_unit u_timer (
        .clk              (clk),
        .rst              (rst),
        .clk_1khz_en      (clk_1khz_en),
        .start_timer      (start_timer),
        .stop_timer       (stop_timer),
        .reaction_time_ms (reaction_time_ms),
        .timer_running    (timer_running),
        .timeout          (timeout)
    );

    alu u_alu (
        .clk               (clk),
        .rst               (rst),
        .op_sel            (alu_op),
        .en                (alu_en),
        .response_switch   (captured_switch),
        .active_led        (active_led_idx),
        .reaction_time_ms  (reaction_time_ms),
        .threshold_ms      (16'd1500),
        .hits              (hits_cur),
        .total_attempts    (total_cur),
        .sum_reaction_time ({16'd0, sum_rt_cur[15:0]}),
        .result            (alu_result),
        .hit_flag          (hit_flag),
        .result_valid      (alu_result_valid)
    );

    player_memory u_pmem (
        .clk              (clk),
        .rst              (rst),
        .write_en         (mem_write),
        .player_id        (current_player),
        .hit_count_in     (hits_cur),
        .miss_count_in    (miss_cur),
        .total_attempts_in(total_cur),
        .sum_rt_in        (sum_rt_cur),
        .best_rt_in       (best_rt_cur),
        .accuracy_pct_in  (acc_write),
        .read_player_id   (current_player),
        .hit_count_out    (mem_hit_out),
        .miss_count_out   (mem_miss_out),
        .total_attempts_out(mem_total_out),
        .sum_rt_out       (mem_sum_rt_out),
        .best_rt_out      (mem_best_rt_out),
        .accuracy_pct_out (mem_acc_out)
    );

    player_manager u_pmgr (
        .clk              (clk),
        .rst              (rst),
        .next_player      (next_player_pulse),
        .trial_done       (trial_done_pulse),
        .num_players_sel  (num_players_cfg),
        .current_player   (current_player),
        .trial_count      (trial_count),
        .player_done      (player_done),
        .all_players_done (all_players_done),
        .total_players    (total_players)
    );

    evaluation_unit u_eval (
        .clk            (clk),
        .rst            (rst),
        .start_eval     (start_eval),
        .total_players  (total_players),
        .acc_p0         (acc_snap_p0),
        .acc_p1         (acc_snap_p1),
        .acc_p2         (acc_snap_p2),
        .acc_p3         (acc_snap_p3),
        .avg_rt_p0      (avrt_snap_p0),
        .avg_rt_p1      (avrt_snap_p1),
        .avg_rt_p2      (avrt_snap_p2),
        .avg_rt_p3      (avrt_snap_p3),
        .best_player_id (best_player_id),
        .rank_p0        (rank_p0),
        .rank_p1        (rank_p1),
        .rank_p2        (rank_p2),
        .rank_p3        (rank_p3),
        .eval_done      (eval_done)
    );

    control_unit u_fsm (
        .clk              (clk),
        .rst              (rst),
        .btn_start        (btn_start_deb),
        .btn_reset        (btn_reset_deb),
        .btn_left         (btn_left_deb),
        .btn_right        (btn_right_deb),
        .total_players    (total_players),
        .clk_1khz_en      (clk_1khz_en),
        .press_event      (press_event),
        .timeout          (timeout),
        .player_done      (player_done),
        .all_players_done (all_players_done),
        .multi_player_en  (multi_player_en),
        .eval_done        (eval_done),
        .alu_result_valid (alu_result_valid),
        .rand_val         (rand_val),
        .latch_mode       (latch_mode),
        .lfsr_en          (lfsr_en),
        .trigger_stimulus (trigger_stimulus),
        .clear_stimulus   (clear_stimulus),
        .start_timer      (start_timer),
        .stop_timer       (stop_timer),
        .alu_op           (alu_op),
        .alu_en           (alu_en),
        .mem_write        (mem_write),
        .trial_done_pulse (trial_done_pulse),
        .next_player_pulse(next_player_pulse),
        .start_eval       (start_eval),
        .disp_mode        (disp_mode),
        .response_valid   (response_valid),
        .captured_switch  (captured_switch),
        .result_browsing  (result_browsing),
        .display_player_id(display_player_id)
    );

    display_controller u_disp (
        .clk           (clk),
        .rst           (rst),
        .clk_500hz_en  (clk_500hz_en),
        .disp_mode     (disp_mode),
        .reaction_time (display_rt),  // Fed from MUX
        .accuracy      (display_acc), // Fed from MUX
        .player_id     (current_player),
        .player_rank   (rank_p0),
        .best_player   (best_player_id),
        .trial_num     (trial_count),
        .seg           (seg),
        .an            (an),
        .dp            (dp)
    );

endmodule
