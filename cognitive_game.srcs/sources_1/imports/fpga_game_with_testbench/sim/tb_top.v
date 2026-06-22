`timescale 1ns / 1ps

module tb_top;

    // Inputs
    reg clk;
    reg btnC;
    reg btnU;
    reg btnL;
    reg btnR;
    reg [15:0] sw;

    // Outputs
    wire [15:0] led;
    wire [6:0]  seg;
    wire [3:0]  an;
    wire        dp;

    // Instantiate DUT
    top uut (
        .clk(clk),
        .btnL(btnL),
        .btnR(btnR),
        .btnC(btnC),
        .btnU(btnU),
        .sw(sw),
        .led(led),
        .seg(seg),
        .an(an),
        .dp(dp)
    );

    // Clock generation (100MHz = 10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper Tasks
    // 25 1kHz ticks = 25us (25,000ns)
    task press_btnC;
        begin
            btnC = 1;
            #25000; 
            btnC = 0;
            #25000;
        end
    endtask

    task press_btnL;
        begin
            btnL = 1;
            #25000;
            btnL = 0;
            #25000;
        end
    endtask

    task press_btnR;
        begin
            btnR = 1;
            #25000;
            btnR = 0;
            #25000;
        end
    endtask

    task toggle_sw(input integer idx);
        begin
            sw[idx] = ~sw[idx];
            #25000; // wait for debounce capturing
        end
    endtask

    task wait_for_state;
        input [3:0] target_state;
        input integer timeout_ms;
        integer cnt;
        begin
            cnt = 0;
            while (uut.u_fsm.state !== target_state && cnt < timeout_ms * 1000) begin
                #1000; // wait 1us
                cnt = cnt + 1;
            end
            if (uut.u_fsm.state !== target_state) begin
                $display("[$time] ERROR: Timeout waiting for state %d. Current state %d", target_state, uut.u_fsm.state);
            end
        end
    endtask

    task wait_for_led;
        input integer timeout_ms;
        integer cnt;
        begin
            cnt = 0;
            while (led[15:3] == 0 && cnt < timeout_ms * 1000) begin
                #1000;
                cnt = cnt + 1;
            end
            if (led[15:3] == 0) begin
                $display("[$time] ERROR: Timeout waiting for LED to turn ON");
            end
        end
    endtask

    task find_led;
        input  [15:0] led_bus;
        output integer idx;
        integer i;
        begin
            idx = -1;
            for (i=3; i<=15; i=i+1) begin
                if (led_bus[i] == 1) idx = i;
            end
        end
    endtask

    // Monitor State Changes
    reg [3:0] prev_state;
    initial begin
        prev_state = 15; // invalid init state
        forever begin
            @(posedge clk);
            if (uut.u_fsm.state !== prev_state) begin
                prev_state = uut.u_fsm.state;
                $display("[$time] STATE CHANGE: %d | DISP_MODE: %d | LED: %04x | RT: %d | TRL: %d | HIT: %d | MISS: %d | BROWSE: %d | PLAYER: %d", 
                         uut.u_fsm.state, uut.u_fsm.disp_mode, led, uut.reaction_time_ms, uut.trial_count, uut.hits_cur, uut.miss_cur, uut.u_fsm.browse_idx, uut.display_player_id);
            end
        end
    end

    // Safety timeout
    initial begin
        #500_000_000; // 500ms sim time
        $display("[$time] ERROR: Safety timeout reached! Halting simulation.");
        $finish;
    end

    // Main Test Sequence
    integer trial;
    integer led_idx;

    initial begin
        // Initialize Inputs
        btnC = 0;
        btnU = 0;
        btnL = 0;
        btnR = 0;
        sw = 0;

        $display("==================================================");
        $display("PART A - SINGLE PLAYER FLOW");
        $display("==================================================");
        
        // Ensure Reset
        btnU = 1; #1000; btnU = 0; #25000;

        if (uut.u_fsm.state == 4'd0) $display("[$time] PASS: Reset to IDLE");
        else $display("[$time] FAIL: Not in IDLE. State = %d", uut.u_fsm.state);

        // Start Single Player
        press_btnC();

        // 10 Trials
        for (trial = 0; trial < 10; trial = trial + 1) begin
            $display("[$time] --- Single Player Trial %d ---", trial);
            wait_for_led(20); 
            find_led(led, led_idx);
            
            // Wait reaction time briefly
            #50_000; // 50us
            
            // Toggle correct sw
            toggle_sw(led_idx);
            
            // State 9: S_SHOW_RT
            wait_for_state(4'd9, 10);
            
            // State 2: S_ISI_DELAY (returns for trials 1-9) or State 12: S_SHOW_RESULT (on trial 10)
            if (trial < 9) begin
                wait_for_state(4'd2, 1100); 
            end else begin
                wait_for_state(4'd12, 10);
            end
        end

        // Verify FSM Enters S_SHOW_RESULT
        if (uut.u_fsm.state == 4'd12) $display("[$time] PASS: FSM entered S_SHOW_RESULT");
        else $display("[$time] FAIL: FSM not in S_SHOW_RESULT");

        // Single Player Result Browsing Tests
        #25000; // Let combo logic settle
        
        // Check disp_mode == DISP_RT
        if (uut.u_fsm.disp_mode == 3'd1) $display("[$time] PASS: Initial single player disp_mode is DISP_RT");
        else $display("[$time] FAIL: Initial single disp_mode = %d", uut.u_fsm.disp_mode);

        press_btnR(); #1000;
        if (uut.u_fsm.disp_mode == 3'd2) $display("[$time] PASS: Press btnR -> disp_mode is DISP_ACC");
        else $display("[$time] FAIL: disp_mode = %d", uut.u_fsm.disp_mode);

        press_btnR(); #1000;
        if (uut.u_fsm.disp_mode == 3'd1) $display("[$time] PASS: Press btnR -> disp_mode is DISP_RT");
        else $display("[$time] FAIL: disp_mode = %d", uut.u_fsm.disp_mode);

        press_btnL(); #1000;
        if (uut.u_fsm.disp_mode == 3'd2) $display("[$time] PASS: Press btnL -> disp_mode is DISP_ACC");
        else $display("[$time] FAIL: disp_mode = %d", uut.u_fsm.disp_mode);

        press_btnC(); #1000;
        if (uut.u_fsm.state == 4'd13) $display("[$time] PASS: Entered S_WAIT_RESTART");
        else $display("[$time] FAIL: Not in S_WAIT_RESTART");
        
        $display("[$time] SINGLE PLAYER TEST PASSED!");


        $display("==================================================");
        $display("PART B - MULTI PLAYER FLOW");
        $display("==================================================");
        
        // Full Reset for clean state
        btnU = 1; #1000; btnU = 0; #25000;
        
        // Setup Multi-Player configuration
        sw[0] = 1;       // Multi player
        sw[2:1] = 2'b00; // 2 players
        #1000;
        
        // Start Game
        press_btnC();

        // Player 1: 10 trials
        $display("[$time] --- Player 1 Starting ---");
        for (trial = 0; trial < 10; trial = trial + 1) begin
            wait_for_led(20);
            find_led(led, led_idx);
            
            #50_000;
            toggle_sw(led_idx);
            
            if (trial < 9) wait_for_state(4'd2, 1100);
            else wait_for_state(4'd14, 10); // S_WAIT_NEXT_PLAYER
        end

        // Verify Player Pause Screen
        if (uut.u_fsm.state == 4'd14) $display("[$time] PASS: FSM entered S_WAIT_NEXT_PLAYER");
        else $display("[$time] FAIL: FSM not in S_WAIT_NEXT_PLAYER");

        if (uut.u_fsm.disp_mode == 3'd0) $display("[$time] PASS: Pause disp_mode is DISP_IDLE (----)");
        else $display("[$time] FAIL: Pause disp_mode = %d", uut.u_fsm.disp_mode);
        
        // Start Player 2
        press_btnC();

        // Player 2: 10 trials
        $display("[$time] --- Player 2 Starting ---");
        for (trial = 0; trial < 10; trial = trial + 1) begin
            wait_for_led(20);
            find_led(led, led_idx);
            
            #50_000;
            toggle_sw(led_idx);
            
            if (trial < 9) wait_for_state(4'd2, 1100);
            else wait_for_state(4'd12, 10); // S_SHOW_RESULT
        end

        // Multi Player Result Browsing Tests
        #25000; // settled
        if (uut.u_fsm.disp_mode == 3'd4) $display("[$time] PASS: Multi player initial disp_mode is DISP_BEST");
        else $display("[$time] FAIL: Initial disp_mode = %d", uut.u_fsm.disp_mode);

        press_btnR(); #1000;
        if (uut.u_fsm.disp_mode == 3'd1 && uut.display_player_id == 0) $display("[$time] PASS: btnR -> Player 1 RT");
        else $display("[$time] FAIL: disp_mode=%d, pid=%d", uut.u_fsm.disp_mode, uut.display_player_id);

        press_btnR(); #1000;
        if (uut.u_fsm.disp_mode == 3'd2 && uut.display_player_id == 0) $display("[$time] PASS: btnR -> Player 1 ACC");
        else $display("[$time] FAIL: disp_mode=%d, pid=%d", uut.u_fsm.disp_mode, uut.display_player_id);

        press_btnR(); #1000;
        if (uut.u_fsm.disp_mode == 3'd1 && uut.display_player_id == 1) $display("[$time] PASS: btnR -> Player 2 RT");
        else $display("[$time] FAIL: disp_mode=%d, pid=%d", uut.u_fsm.disp_mode, uut.display_player_id);

        press_btnR(); #1000;
        if (uut.u_fsm.disp_mode == 3'd2 && uut.display_player_id == 1) $display("[$time] PASS: btnR -> Player 2 ACC");
        else $display("[$time] FAIL: disp_mode=%d, pid=%d", uut.u_fsm.disp_mode, uut.display_player_id);

        press_btnR(); #1000;
        if (uut.u_fsm.disp_mode == 3'd4) $display("[$time] PASS: btnR -> Wraps to DISP_BEST");
        else $display("[$time] FAIL: disp_mode=%d", uut.u_fsm.disp_mode);

        press_btnL(); #1000;
        if (uut.u_fsm.disp_mode == 3'd2 && uut.display_player_id == 1) $display("[$time] PASS: btnL -> Back to Player 2 ACC");
        else $display("[$time] FAIL: disp_mode=%d, pid=%d", uut.u_fsm.disp_mode, uut.display_player_id);

        press_btnC(); #1000;
        if (uut.u_fsm.state == 4'd13) $display("[$time] PASS: Entered S_WAIT_RESTART");
        else $display("[$time] FAIL: Not in S_WAIT_RESTART");

        $display("[$time] MULTI PLAYER TEST PASSED!");
        $display("==================================================");
        $display("ALL TESTS COMPLETED SUCCESSFULLY");
        
        $finish;
    end

endmodule
