`timescale 1ns / 1ps

module control_unit(
    input  wire        clk,
    input  wire        rst,
    input  wire        btn_start,
    input  wire        btn_reset,
    input  wire        btn_left,
    input  wire        btn_right,
    input  wire [1:0]  total_players,
    input  wire        clk_1khz_en,
    input  wire [15:0] press_event,
    input  wire        timeout,
    input  wire        player_done,
    input  wire        all_players_done,
    input  wire        multi_player_en,
    input  wire        eval_done,
    input  wire        alu_result_valid,
    input  wire [15:0] rand_val,
    output reg         latch_mode,
    output reg         lfsr_en,
    output reg         trigger_stimulus,
    output reg         clear_stimulus,
    output reg         start_timer,
    output reg         stop_timer,
    output reg  [1:0]  alu_op,
    output reg         alu_en,
    output reg         mem_write,
    output reg         trial_done_pulse,
    output reg         next_player_pulse,
    output reg         start_eval,
    output reg  [2:0]  disp_mode,
    output reg         response_valid,
    output reg  [3:0]  captured_switch,
    output wire        result_browsing,
    output reg  [1:0]  display_player_id
);

    // ──────────────────────────────────────────────────────────
    // States — 4-bit, 15 states
    // ──────────────────────────────────────────────────────────
    localparam [3:0] S_IDLE             = 4'd0;
    localparam [3:0] S_PLAYER_SELECT    = 4'd1;
    localparam [3:0] S_ISI_DELAY        = 4'd2;
    localparam [3:0] S_STIMULUS_ON      = 4'd3;
    localparam [3:0] S_WAIT_RESPONSE    = 4'd4;
    localparam [3:0] S_EVALUATE         = 4'd5;
    localparam [3:0] S_ALU_DELAY1       = 4'd6;
    localparam [3:0] S_ALU_DELAY2       = 4'd7; 
    localparam [3:0] S_STORE_METRICS    = 4'd8; 
    localparam [3:0] S_SHOW_RT          = 4'd9; 
    localparam [3:0] S_NEXT_PLAYER      = 4'd10;
    localparam [3:0] S_FINAL_EVAL       = 4'd11;
    localparam [3:0] S_SHOW_RESULT      = 4'd12;
    localparam [3:0] S_WAIT_RESTART     = 4'd13;
    localparam [3:0] S_WAIT_NEXT_PLAYER = 4'd14;
    localparam [3:0] S_CHECK_TRIAL      = 4'd15;

    // Display mode constants
    localparam [2:0] DISP_IDLE  = 3'd0;
    localparam [2:0] DISP_RT    = 3'd1;
    localparam [2:0] DISP_ACC   = 3'd2;
    localparam [2:0] DISP_RANK  = 3'd3;
    localparam [2:0] DISP_BEST  = 3'd4;
    localparam [2:0] DISP_PRESS = 3'd5;
    localparam [2:0] DISP_AVG_RT = 3'd6; // Added for 't' prefixed average RT during results
    localparam [2:0] DISP_GRADE = 3'd7;  // Attention Measure Grade

    localparam [11:0] RT_HOLD = 12'd600;   // 0.6 second RT display for faster gameplay

    reg [3:0]  state;
    reg [11:0] isi_cnt;
    reg [11:0] isi_target;
    reg [11:0] result_cnt;
    reg [11:0] rt_hold_cnt;   
    reg        first_trial;   

    // Result browsing registers
    reg [3:0] browse_idx;

    // Response switch detection
    wire [12:0] resp_event = press_event[15:3];
    wire        any_response = (resp_event != 13'd0);

    // Continuous assignment to inform display datapath
    assign result_browsing = (state == S_SHOW_RESULT);

    // Browsing calculation logic
    // total_players represents (N-2) actively because sw=00 maps to 0 for 2 players.
    wire [3:0] total_p_count = {2'b00, total_players} + 4'd2;
    wire [3:0] max_idx = multi_player_en ? (total_p_count * 4'd3) : 4'd2; // 3 screens per player
    
    wire [3:0] next_idx_right = (browse_idx >= max_idx) ? 4'd0 : browse_idx + 4'd1;
    wire [3:0] next_idx_left  = (browse_idx == 4'd0)    ? max_idx : browse_idx - 4'd1;

    // Precalculate combinatorial screen types and player mappings to avoid syntax errors in sequential block
    wire [3:0] curr_stype   = (browse_idx - 4'd1) % 4'd3;
    wire [1:0] curr_player  = (browse_idx - 4'd1) / 4'd3;
    wire [3:0] right_stype  = (next_idx_right - 4'd1) % 4'd3;
    wire [1:0] right_player = (next_idx_right - 4'd1) / 4'd3;
    wire [3:0] left_stype   = (next_idx_left - 4'd1) % 4'd3;
    wire [1:0] left_player  = (next_idx_left - 4'd1) / 4'd3;

    // Single always block FSM (Rule 6)
    always @(posedge clk) begin
        // De-assert all pulse outputs every cycle
        latch_mode        <= 1'b0;
        lfsr_en           <= 1'b0;
        trigger_stimulus  <= 1'b0;
        clear_stimulus    <= 1'b0;
        start_timer       <= 1'b0;
        stop_timer        <= 1'b0;
        alu_en            <= 1'b0;
        mem_write         <= 1'b0;
        trial_done_pulse  <= 1'b0;
        next_player_pulse <= 1'b0;
        start_eval        <= 1'b0;

        if (rst || btn_reset) begin
            state             <= S_IDLE;
            disp_mode         <= DISP_IDLE;
            isi_cnt           <= 12'd0;
            isi_target        <= 12'd0;
            result_cnt        <= 12'd0;
            rt_hold_cnt       <= 12'd0;
            first_trial       <= 1'b1;
            response_valid    <= 1'b0;
            captured_switch   <= 4'd0;
            alu_op            <= 2'b00;
            browse_idx        <= 4'd0;
            display_player_id <= 2'd0;
        end else begin
            case (state)
                // ──────────────────────────────────────────
                S_IDLE: begin
                    disp_mode <= DISP_IDLE;
                    if (btn_start) begin
                        latch_mode <= 1'b1;
                        state <= S_PLAYER_SELECT;
                    end
                end

                // ──────────────────────────────────────────
                S_PLAYER_SELECT: begin
                    disp_mode   <= DISP_IDLE;
                    first_trial <= 1'b1;  // new game/player, no RT yet
                    lfsr_en     <= 1'b1;
                    isi_target  <= 12'd200 + {2'b00, rand_val[9:0]}; // 200ms setup up to ~1.2s random
                    isi_cnt     <= 12'd0;
                    state       <= S_ISI_DELAY;
                end

                // ──────────────────────────────────────────
                S_ISI_DELAY: begin
                    if (first_trial)
                        disp_mode <= DISP_IDLE;
                    else
                        disp_mode <= DISP_RT;
                    lfsr_en   <= 1'b1;
                    if (clk_1khz_en) begin
                        if (isi_cnt >= isi_target) begin
                            state <= S_STIMULUS_ON;
                        end else begin
                            isi_cnt <= isi_cnt + 12'd1;
                        end
                    end
                end

                // ──────────────────────────────────────────
                S_STIMULUS_ON: begin
                    trigger_stimulus <= 1'b1;
                    start_timer      <= 1'b1;
                    disp_mode        <= DISP_RT;
                    state            <= S_WAIT_RESPONSE;
                end

                // ──────────────────────────────────────────
                S_WAIT_RESPONSE: begin
                    disp_mode <= DISP_RT;
                    if (any_response) begin
                        stop_timer     <= 1'b1;
                        clear_stimulus <= 1'b1;
                        response_valid <= 1'b1;
                        casez (resp_event)
                            13'b????????????1: captured_switch <= 4'd3;
                            13'b???????????10: captured_switch <= 4'd4;
                            13'b??????????100: captured_switch <= 4'd5;
                            13'b?????????1000: captured_switch <= 4'd6;
                            13'b????????10000: captured_switch <= 4'd7;
                            13'b???????100000: captured_switch <= 4'd8;
                            13'b??????1000000: captured_switch <= 4'd9;
                            13'b?????10000000: captured_switch <= 4'd10;
                            13'b????100000000: captured_switch <= 4'd11;
                            13'b???1000000000: captured_switch <= 4'd12;
                            13'b??10000000000: captured_switch <= 4'd13;
                            13'b?100000000000: captured_switch <= 4'd14;
                            13'b1000000000000: captured_switch <= 4'd15;
                            default:           captured_switch <= 4'd3;
                        endcase
                        state <= S_EVALUATE;
                    end else if (timeout) begin
                        clear_stimulus <= 1'b1;
                        response_valid <= 1'b0;
                        captured_switch <= 4'd0;
                        state          <= S_EVALUATE;
                    end
                end

                // ──────────────────────────────────────────
                S_EVALUATE: begin
                    alu_op    <= 2'b00;
                    alu_en    <= 1'b1;
                    disp_mode <= DISP_RT;
                    state     <= S_ALU_DELAY1;
                end

                // ──────────────────────────────────────────
                S_ALU_DELAY1: begin
                    // ALU asserts result_valid THIS cycle.
                    disp_mode <= DISP_RT;
                    state     <= S_ALU_DELAY2;
                end

                // ──────────────────────────────────────────
                S_ALU_DELAY2: begin
                    // top.v updates hits_cur and sum_rt_cur THIS cycle based on result_valid.
                    trial_done_pulse <= 1'b1;  // Pulse manager early so player_done is ready next cycle
                    disp_mode <= DISP_RT;
                    state     <= S_STORE_METRICS;
                end

                // ──────────────────────────────────────────
                S_STORE_METRICS: begin
                    // hits_cur is now fully updated with the latest trial data!
                    mem_write        <= 1'b1;
                    first_trial      <= 1'b0; 
                    disp_mode        <= DISP_RT;
                    state            <= S_CHECK_TRIAL;
                end

                // ──────────────────────────────────────────
                S_CHECK_TRIAL: begin
                    // manager asserts player_done THIS cycle if 10th trial is done
                    disp_mode <= DISP_RT;
                    if (player_done) begin
                        result_cnt <= 12'd0;
                        if (multi_player_en) begin
                            state <= S_NEXT_PLAYER;
                        end else begin
                            state <= S_FINAL_EVAL;
                        end
                    end else begin
                        rt_hold_cnt <= 12'd0;
                        state       <= S_SHOW_RT;
                    end
                end

                // ──────────────────────────────────────────
                S_SHOW_RT: begin
                    disp_mode <= DISP_RT;
                    lfsr_en   <= 1'b1;
                    if (clk_1khz_en) begin
                        if (rt_hold_cnt >= RT_HOLD) begin
                            isi_target <= 12'd200 + {2'b00, rand_val[9:0]};
                            isi_cnt    <= 12'd0;
                            state      <= S_ISI_DELAY;
                        end else begin
                            rt_hold_cnt <= rt_hold_cnt + 12'd1;
                        end
                    end
                end

                // ──────────────────────────────────────────
                // S_NEXT_PLAYER pulses the manager
                // ──────────────────────────────────────────
                S_NEXT_PLAYER: begin
                    next_player_pulse <= 1'b1;
                    disp_mode         <= DISP_IDLE; // "----"
                    state             <= S_WAIT_NEXT_PLAYER;
                end

                // ──────────────────────────────────────────
                // S_WAIT_NEXT_PLAYER (pause between players)
                // ──────────────────────────────────────────
                S_WAIT_NEXT_PLAYER: begin
                    disp_mode <= DISP_IDLE;
                    if (all_players_done) begin
                        state <= S_FINAL_EVAL; // Exit pause seamlessly if no players left
                    end else if (btn_start) begin
                        state <= S_PLAYER_SELECT; // Triggers LFSR, isi delay etc.
                    end
                end

                // ──────────────────────────────────────────
                S_FINAL_EVAL: begin
                    start_eval <= 1'b1;
                    browse_idx <= 4'd0;
                    display_player_id <= 2'd0;

                    // Initialize the display pre-emptively
                    if (multi_player_en)
                        disp_mode <= DISP_BEST;
                    else
                        disp_mode <= DISP_AVG_RT;

                    if (eval_done) begin
                        result_cnt <= 12'd0;
                        state      <= S_SHOW_RESULT;
                    end
                end

                // ──────────────────────────────────────────
                // S_SHOW_RESULT: Mux values based on browse index
                // ──────────────────────────────────────────
                S_SHOW_RESULT: begin
                    if (btn_start) begin
                        disp_mode <= DISP_PRESS;
                        state <= S_WAIT_RESTART;
                    end else begin
                        if (btn_right) begin
                            browse_idx <= next_idx_right;
                            
                            if (!multi_player_en) begin
                                if (next_idx_right == 4'd0) disp_mode <= DISP_AVG_RT;
                                else if (next_idx_right == 4'd1) disp_mode <= DISP_ACC;
                                else disp_mode <= DISP_GRADE;
                                display_player_id <= 2'd0;
                            end else begin
                                if (next_idx_right == 4'd0) begin
                                    disp_mode <= DISP_BEST;
                                    display_player_id <= 2'd0;
                                end else begin
                                    if (right_stype == 4'd0) disp_mode <= DISP_AVG_RT;
                                    else if (right_stype == 4'd1) disp_mode <= DISP_ACC;
                                    else disp_mode <= DISP_GRADE;
                                    display_player_id <= right_player;
                                end
                            end
                            
                        end else if (btn_left) begin
                            browse_idx <= next_idx_left;
                            
                            if (!multi_player_en) begin
                                if (next_idx_left == 4'd0) disp_mode <= DISP_AVG_RT;
                                else if (next_idx_left == 4'd1) disp_mode <= DISP_ACC;
                                else disp_mode <= DISP_GRADE;
                                display_player_id <= 2'd0;
                            end else begin
                                if (next_idx_left == 4'd0) begin
                                    disp_mode <= DISP_BEST;
                                    display_player_id <= 2'd0;
                                end else begin
                                    if (left_stype == 4'd0) disp_mode <= DISP_AVG_RT;
                                    else if (left_stype == 4'd1) disp_mode <= DISP_ACC;
                                    else disp_mode <= DISP_GRADE;
                                    display_player_id <= left_player;
                                end
                            end
                            
                        end else begin
                            // Maintain currently evaluated state
                            if (!multi_player_en) begin
                                if (browse_idx == 4'd0) disp_mode <= DISP_AVG_RT;
                                else if (browse_idx == 4'd1) disp_mode <= DISP_ACC;
                                else disp_mode <= DISP_GRADE;
                                display_player_id <= 2'd0;
                            end else begin
                                if (browse_idx == 4'd0) begin
                                    disp_mode <= DISP_BEST;
                                    display_player_id <= 2'd0;
                                end else begin
                                    if (curr_stype == 4'd0) disp_mode <= DISP_AVG_RT;
                                    else if (curr_stype == 4'd1) disp_mode <= DISP_ACC;
                                    else disp_mode <= DISP_GRADE;
                                    display_player_id <= curr_player;
                                end
                            end
                        end
                    end
                end

                // ──────────────────────────────────────────
                S_WAIT_RESTART: begin
                    disp_mode <= DISP_PRESS;
                    if (btn_start) begin
                        latch_mode <= 1'b1;
                        isi_target <= 12'd200 + {2'b00, rand_val[9:0]};
                        isi_cnt    <= 12'd0;
                        state      <= S_PLAYER_SELECT;
                    end
                end

                // ──────────────────────────────────────────
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
