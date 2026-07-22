`timescale 1ns / 1ps

module timer_io (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] timer_low,
    output wire [31:0] timer_high
);
    reg [63:0] timer;

    always @(posedge clk or posedge rst)
        timer <= rst ? 64'h0 : timer + 1'b1;

    assign timer_low  = timer[31:0];
    assign timer_high = timer[63:32];
endmodule
