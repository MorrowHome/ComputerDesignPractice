`timescale 1ns / 1ps

module switch_io (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] sw,
    output wire [31:0] read_data
);
    reg [15:0] sw_meta;
    reg [15:0] sw_sync;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sw_meta <= 16'h0;
            sw_sync <= 16'h0;
        end else begin
            sw_meta <= sw;
            sw_sync <= sw_meta;
        end
    end

    assign read_data = {16'h0, sw_sync};
endmodule
