`timescale 1ns / 1ps

module event_detector(
    input  wire        clk,
    input  wire        rst,
    input  wire        clk_1khz_en,
    input  wire [15:0] sw_in,
    output wire [15:0] sw_debounced,
    output wire [15:0] press_event
);

    reg [15:0] db_state;
    reg [15:0] db_prev;

    assign sw_debounced = db_state;

    // Toggle detection: XOR fires on ANY direction change (Rule 9)
    // db_prev updates every clock, so XOR pulse is exactly 1 clock wide
    assign press_event = db_state ^ db_prev;

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : debounce_gen
            reg [4:0] cnt;
            reg       sync0, sync1;

            always @(posedge clk) begin
                if (rst) begin
                    sync0 <= 1'b0;
                    sync1 <= 1'b0;
                    cnt   <= 5'd0;
                    db_state[i] <= 1'b0;
                end else begin
                    sync0 <= sw_in[i];
                    sync1 <= sync0;

                    if (clk_1khz_en) begin
                        if (sync1 != db_state[i]) begin
                            if (cnt == 5'd19) begin
                                db_state[i] <= sync1;
                                cnt <= 5'd0;
                            end else begin
                                cnt <= cnt + 5'd1;
                            end
                        end else begin
                            cnt <= 5'd0;
                        end
                    end
                end
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            db_prev <= 16'd0;
        end else begin
            db_prev <= db_state;
        end
    end

endmodule
