`timescale 1ns / 1ps

module multiplier #(
    parameter WIDTH = 32
)(
    input  wire            clk,
    input  wire            rst,
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire            start,
    output reg  [O_WID-1:0] z,
    output wire            busy
);

    localparam O_WID   = 2 * WIDTH;                     // 乘积位宽 64
    localparam CNT_WID = $clog2(WIDTH / 2);             // 计数器位宽 4
    localparam CNT_MAX = WIDTH / 2 - 1;                 // 循环次数 15

    // ====================================================================
    // 状态定义
    // ====================================================================
    localparam IDLE = 2'b00;
    localparam CALC = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [1:0] next_state;

    // ====================================================================
    // 数据通路
    // ====================================================================
    reg [O_WID-1:0]     partial;        // 部分积累加器（全精度 64 位）
    reg [WIDTH:0]       booth_code;     // {y, 1'b0}，每周期右移 2 位
    reg [CNT_WID-1:0]   cnt;            // 循环计数

    // ====================================================================
    // Booth 译码
    // ====================================================================
    //  x 符号扩展至 64 位
    wire [O_WID-1:0] x_ext    = {{WIDTH{x[WIDTH-1]}}, x};
    wire [O_WID-1:0] x2_ext   = x_ext << 1;
    wire [O_WID-1:0] neg_x    = ~x_ext + 1;
    wire [O_WID-1:0] neg_x2   = ~x2_ext + 1;

    reg [O_WID-1:0] addend;
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

    // ====================================================================
    // 二段式FSM — 组合逻辑
    // ====================================================================
    always @(*) begin
        next_state = state;

        case (state)
            IDLE: if (start)    next_state = CALC;
            CALC: if (cnt == CNT_MAX) next_state = DONE;
            DONE:               next_state = IDLE;
        endcase
    end

    // ====================================================================
    // 二段式FSM — 时序逻辑
    // ====================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            partial    <= 0;
            booth_code <= 0;
            cnt        <= 0;
            z          <= 0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        partial    <= 0;
                        booth_code <= {y, 1'b0};
                        cnt        <= 0;
                    end
                end

                CALC: begin
                    // 将 Booth 译码后的 addend 对齐到当前步的位置，累加
                    partial    <= partial + (addend << (2 * cnt));
                    booth_code <= {2'b0, booth_code[WIDTH:2]};
                    cnt        <= cnt + 1;
                end

                DONE: begin
                    z <= partial;
                end
            endcase
        end
    end

    // ====================================================================
    // 输出
    // ====================================================================
    assign busy = (state != IDLE);

endmodule
