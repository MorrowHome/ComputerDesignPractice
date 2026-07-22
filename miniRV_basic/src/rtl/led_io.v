`timescale 1ns / 1ps

module led_io (
    input  wire        clk,
    input  wire        rst,
    input  wire        write_en,
    input  wire [31:0] write_data,
    input  wire [3:0]  write_strb,
    output wire [15:0] led
);
    reg [31:0] value;
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            value <= 32'h0;
        end else if (write_en) begin
            for (i = 0; i < 4; i = i + 1)
                if (write_strb[i])
                    value[i*8 +: 8] <= write_data[i*8 +: 8];
        end
    end

    assign led = value[15:0];
endmodule
