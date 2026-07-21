`timescale 1ns / 1ps

// 使用Radix-4 Booth算法，一次处理两位，更加高效
// 故32位只需处理16次
module multiplier #(
    parameter WIDTH = 32
) (
    input  wire             clk,
    input  wire             rst,
    input  wire [WIDTH-1:0] x,      // 31:0
    input  wire [WIDTH-1:0] y,      // 31:0
    input  wire             start,  // 乘法器开始计算
    output reg  [(2*WIDTH)-1:0] z,  // 63:0
    output wire             busy    // 乘法器是否正在计算
);

    localparam CNT_MAX = (WIDTH + 1) / 2 - 1;
    localparam CNT_WID = $clog2(CNT_MAX + 1);
    localparam O_WID = 2 * WIDTH;

    reg  [O_WID-1:0] partial;
    reg  [WIDTH-1:0] multiplicand;
    reg  [WIDTH:0]   booth_code;
    reg  [CNT_WID-1:0] cnt;
    reg               busy_r;

    // x/y are only valid during the one-cycle start pulse.  Latch both
    // operands so the iterative calculation is independent of later inputs.
    wire [O_WID-1:0] x_ext   = {{WIDTH{multiplicand[WIDTH-1]}}, multiplicand};
    wire [O_WID-1:0] x2_ext  = x_ext << 1;
    wire [O_WID-1:0] neg_x   = ~x_ext + 1;
    wire [O_WID-1:0] neg_x2  = ~x2_ext + 1;

    reg  [O_WID-1:0] addend;
    always @(*) begin
        case (booth_code[2:0])
            3'b000, 3'b111: addend = 0;
            3'b001, 3'b010: addend = x_ext;
            3'b011:         addend = x2_ext;
            3'b100:         addend = neg_x2;
            3'b101, 3'b110: addend = neg_x;
            default:        addend = 0;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy_r      <= 1'b0;
            partial     <= 0;
            multiplicand <= 0;
            booth_code  <= 0;
            cnt         <= 0;
            z           <= 0;
        end else if (start && !busy_r) begin
            partial     <= 0;
            multiplicand <= x;
            booth_code  <= {y, 1'b0};  // 末尾补0
            cnt         <= 0;
            busy_r      <= 1'b1;
        end else if (busy_r) begin
            if (cnt == CNT_MAX) begin
                z      <= partial + (addend << (2 * cnt));
                busy_r <= 1'b0;
            end else begin
                partial <= partial + (addend << (2 * cnt));
            end
            booth_code <= {{2{booth_code[WIDTH]}}, booth_code[WIDTH:2]};
            cnt        <= cnt + 1'b1;
        end
    end

    assign busy = busy_r;
endmodule
