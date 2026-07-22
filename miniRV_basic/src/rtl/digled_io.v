`timescale 1ns / 1ps

module digled_io (
    input  wire        clk,
    input  wire        rst,
    input  wire        write_en,
    input  wire [31:0] write_data,
    input  wire [3:0]  write_strb,
    output reg  [7:0]  dig_en,
    output reg  [7:0]  dig_seg,
    output wire [7:0]  dig_seg1
);
    reg [31:0] value;
    reg [15:0] refresh_counter;
    wire [2:0] digit_index = refresh_counter[15:13];
    reg [3:0] digit_value;
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            value           <= 32'h0;
            refresh_counter <= 16'h0;
        end else begin
            refresh_counter <= refresh_counter + 1'b1;
            if (write_en)
                for (i = 0; i < 4; i = i + 1)
                    if (write_strb[i])
                        value[i*8 +: 8] <= write_data[i*8 +: 8];
        end
    end

    always @(*) begin
        case (digit_index)
            3'd0: digit_value = value[3:0];
            3'd1: digit_value = value[7:4];
            3'd2: digit_value = value[11:8];
            3'd3: digit_value = value[15:12];
            3'd4: digit_value = value[19:16];
            3'd5: digit_value = value[23:20];
            3'd6: digit_value = value[27:24];
            default: digit_value = value[31:28];
        endcase

        dig_en = 8'b0000_0001 << digit_index;

        // EGO1 segment outputs are active high: {A,B,C,D,E,F,G,DP}.
        case (digit_value)
            4'h0: dig_seg = 8'b11111100;
            4'h1: dig_seg = 8'b01100000;
            4'h2: dig_seg = 8'b11011010;
            4'h3: dig_seg = 8'b11110010;
            4'h4: dig_seg = 8'b01100110;
            4'h5: dig_seg = 8'b10110110;
            4'h6: dig_seg = 8'b10111110;
            4'h7: dig_seg = 8'b11100000;
            4'h8: dig_seg = 8'b11111110;
            4'h9: dig_seg = 8'b11110110;
            4'hA: dig_seg = 8'b11101110;
            4'hB: dig_seg = 8'b00111110;
            4'hC: dig_seg = 8'b10011100;
            4'hD: dig_seg = 8'b01111010;
            4'hE: dig_seg = 8'b10011110;
            default: dig_seg = 8'b10001110;
        endcase
    end

    // EGO1 has two four-digit groups; the guide requires both groups to use
    // the same segment pattern while dig_en chooses the active digit.
    assign dig_seg1 = dig_seg;
endmodule
