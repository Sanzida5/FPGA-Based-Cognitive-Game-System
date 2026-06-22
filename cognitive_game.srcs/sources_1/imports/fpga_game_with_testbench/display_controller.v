`timescale 1ns / 1ps

module display_controller(
    input  wire        clk,
    input  wire        rst,
    input  wire        clk_500hz_en,
    input  wire [2:0]  disp_mode,
    input  wire [15:0] reaction_time,
    input  wire [15:0] accuracy,
    input  wire [1:0]  player_id,
    input  wire [1:0]  player_rank,
    input  wire [1:0]  best_player,
    input  wire [3:0]  trial_num,
    output reg  [6:0]  seg,
    output reg  [3:0]  an,
    output wire        dp
);

    assign dp = 1'b1; // decimal point always OFF

    // Character codes:
    // 0-9 = digits, 10='-', 11='b', 12='E', 13='r', 14='S', 15='P'

    // Segment encoding function seg[6:0] = {G,F,E,D,C,B,A} active LOW
    function [6:0] seg7;
        input [4:0] char_code;
        begin
            case (char_code)
                5'd0:    seg7 = 7'b1000000;
                5'd1:    seg7 = 7'b1111001;
                5'd2:    seg7 = 7'b0100100;
                5'd3:    seg7 = 7'b0110000;
                5'd4:    seg7 = 7'b0011001;
                5'd5:    seg7 = 7'b0010010;
                5'd6:    seg7 = 7'b0000010;
                5'd7:    seg7 = 7'b1111000;
                5'd8:    seg7 = 7'b0000000;
                5'd9:    seg7 = 7'b0010000;
                5'd10:   seg7 = 7'b0111111; // dash '-'
                5'd11:   seg7 = 7'b0000011; // 'b'
                5'd12:   seg7 = 7'b0000110; // 'E'
                5'd13:   seg7 = 7'b0101111; // 'r'
                5'd14:   seg7 = 7'b0010010; // 'S'
                5'd15:   seg7 = 7'b0001100; // 'P'
                5'd16:   seg7 = 7'b0001000; // 'A'
                5'd17:   seg7 = 7'b0000111; // 't'
                5'd18:   seg7 = 7'b1000110; // 'C'
                5'd19:   seg7 = 7'b0001110; // 'F'
                5'd20:   seg7 = 7'b1111111; // blank
                default: seg7 = 7'b1111111;
            endcase
        end
    endfunction

    // Capping values to maximum of 999 to guarantee they fit in 3 digits alongside prefixes
    wire [15:0] safe_rt  = (reaction_time > 16'd999) ? 16'd999 : reaction_time;
    wire [15:0] safe_acc = (accuracy > 16'd999) ? 16'd999 : accuracy;

    // RAW components for live display
    wire [3:0] rt_thousands_raw = reaction_time / 16'd1000;
    wire [3:0] rt_hundreds_raw  = (reaction_time % 16'd1000) / 16'd100;
    wire [3:0] rt_tens_raw      = (reaction_time % 16'd100) / 16'd10;
    wire [3:0] rt_units_raw     = reaction_time % 16'd10;

    // SAFE components for prefixed capped display
    wire [3:0] rt_hundreds_safe = (safe_rt % 16'd1000) / 16'd100;
    wire [3:0] rt_tens_safe     = (safe_rt % 16'd100) / 16'd10;
    wire [3:0] rt_units_safe    = safe_rt % 16'd10;

    // BCD decomposition wires for accuracy (lower 3 digits)
    wire [3:0] ac_hundreds  = (safe_acc % 16'd1000) / 16'd100;
    wire [3:0] ac_tens      = (safe_acc % 16'd100) / 16'd10;
    wire [3:0] ac_units     = safe_acc % 16'd10;

    reg [1:0] digit_sel;

    // Compute digit values for all 4 positions based on disp_mode
    reg [4:0] char_d3, char_d2, char_d1, char_d0;

    always @(*) begin
        case (disp_mode)
            3'd0: begin // "----"
                char_d3 = 5'd10; char_d2 = 5'd10;
                char_d1 = 5'd10; char_d0 = 5'd10;
            end
            3'd1: begin // LIVE RT ms e.g. "0342"
                char_d3 = {1'b0, rt_thousands_raw};
                char_d2 = {1'b0, rt_hundreds_raw};
                char_d1 = {1'b0, rt_tens_raw};
                char_d0 = {1'b0, rt_units_raw};
            end
            3'd2: begin // "A" + 3-digit ACC
                char_d3 = 5'd16; // 'A'
                char_d2 = {1'b0, ac_hundreds};
                char_d1 = {1'b0, ac_tens};
                char_d0 = {1'b0, ac_units};
            end
            3'd3: begin // "P1r2" player_id+1 and rank+1
                char_d3 = 5'd15; // 'P'
                char_d2 = {3'b000, player_id} + 5'd1;
                char_d1 = 5'd13; // 'r'
                char_d0 = {3'b000, player_rank} + 5'd1;
            end
            3'd4: begin // "bES1" best player
                char_d3 = 5'd11; // 'b'
                char_d2 = 5'd12; // 'E'
                char_d1 = 5'd14; // 'S'
                char_d0 = {3'b000, best_player} + 5'd1;
            end
            3'd5: begin // "PrES"
                char_d3 = 5'd15; // 'P'
                char_d2 = 5'd13; // 'r'
                char_d1 = 5'd12; // 'E'
                char_d0 = 5'd14; // 'S'
            end
            3'd6: begin // "t" + 3-digit AVG RT
                char_d3 = 5'd17; // 't'
                char_d2 = {1'b0, rt_hundreds_safe};
                char_d1 = {1'b0, rt_tens_safe};
                char_d0 = {1'b0, rt_units_safe};
            end
            3'd7: begin // Attention Grade e.g. "At A"
                char_d3 = 5'd16; // 'A'
                char_d2 = 5'd17; // 't'
                char_d1 = 5'd20; // blank/dash
                
                if (accuracy >= 16'd80 && reaction_time <= 16'd500) begin
                    char_d0 = 5'd16; // 'A'
                end else if (accuracy >= 16'd60 && reaction_time <= 16'd800) begin
                    char_d0 = 5'd11; // 'b'
                end else if (accuracy >= 16'd40 && reaction_time <= 16'd1100) begin
                    char_d0 = 5'd18; // 'C'
                end else begin
                    char_d0 = 5'd19; // 'F'
                end
            end
            default: begin
                char_d3 = 5'd10; char_d2 = 5'd10;
                char_d1 = 5'd10; char_d0 = 5'd10;
            end
        endcase
    end

    // Pre-compute NEXT digit (Rule 8: anode and segment sync)
    reg [4:0] next_char;
    reg [3:0] an_next;
    wire [1:0] next_digit_sel = digit_sel + 2'd1;

    always @(*) begin
        case (next_digit_sel)
            2'd0: begin next_char = char_d0; an_next = 4'b1110; end
            2'd1: begin next_char = char_d1; an_next = 4'b1101; end
            2'd2: begin next_char = char_d2; an_next = 4'b1011; end
            2'd3: begin next_char = char_d3; an_next = 4'b0111; end
            default: begin next_char = char_d0; an_next = 4'b1110; end
        endcase
    end

    // Single clocked process (Rule 5, 6, 8)
    always @(posedge clk) begin
        if (rst) begin
            digit_sel <= 2'd0;
            an  <= 4'b1111;     // ALL digits OFF
            seg <= 7'b1111111;  // ALL segments OFF
        end else if (clk_500hz_en) begin
            digit_sel <= next_digit_sel;
            an  <= an_next;
            seg <= seg7(next_char);
        end
    end

endmodule
