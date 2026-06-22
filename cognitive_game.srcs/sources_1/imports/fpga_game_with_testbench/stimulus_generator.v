`timescale 1ns / 1ps

module stimulus_generator(
    input  wire        clk,
    input  wire        rst,
    input  wire        trigger,
    input  wire        clear_stimulus,
    input  wire [15:0] rand_val,
    output reg  [15:0] led_out,
    output reg  [3:0]  active_led_idx,
    output reg         stimulus_active
);

    // STIMULUS LED RANGE RESTRICTION:
    // LED 0, 1, 2 are NEVER used as stimulus because sw[0..2]
    // are reserved for mode selection.
    // Map rand_val[3:0] (0-15) into range 3-15 (13 possible LEDs):
    //   active_index = 3 + (rand_val[3:0] % 13)
    // 13 is a constant divisor — fully synthesizable (Rule 2).
    wire [3:0] active_index = 4'd3 + (rand_val[3:0] % 4'd13);

    always @(posedge clk) begin
        if (rst) begin
            led_out         <= 16'd0;
            active_led_idx  <= 4'd0;
            stimulus_active <= 1'b0;
        end else if (trigger) begin
            led_out         <= (16'd1 << active_index);
            active_led_idx  <= active_index;
            stimulus_active <= 1'b1;
        end else if (clear_stimulus) begin
            led_out         <= 16'd0;
            stimulus_active <= 1'b0;
        end
    end

endmodule
