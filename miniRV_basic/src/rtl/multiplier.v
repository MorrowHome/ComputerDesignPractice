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

    localparam CNT_MAX = WIDTH / 2 - 1;
    localparam CNT_WID = $clog2(CNT_MAX + 1);
    localparam O_WID = 2 * WIDTH;

    // states
    localparam IDLE = 2'b00;
    localparam CALC = 2'b01;
    localparam DONE = 2'b10;

    reg  [1:0] state;
    reg  [1:0] next_state;

    // TODO

    reg  [O_WID-1:0] partial;
    reg  [WIDTH:0] booth_code;
    reg  [CNT_WID-1:0] cnt;

    wire [O_WID-1:0] x_ext = {{WIDTH{x[WIDTH-1]}}, x};
    wire [O_WID-1:0] x2_ext = x_ext << 1;
    wire [O_WID-1:0] neg_x = ~x_ext + 1;
    wire [O_WID-1:0] neg_x2 = ~x2_ext + 1;

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

    always @(*) begin
        next_state = state;

        case (state)
            IDLE: if (start) next_state = CALC;
            CALC: if (cnt == CNT_MAX) next_state = DONE;
            DONE: next_state = IDLE;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            partial <= 0;
            booth_code <= 0;
            cnt <= 0;
            z <= 0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        partial <= 0;
                        booth_code <= {y, 1'b0};  // 末尾补0
                        cnt <= 0;
                    end
                end
                
                CALC: begin
                    partial <= partial + (addend << (2 * cnt));
                    booth_code <= {{2{booth_code[WIDTH]}}, booth_code[WIDTH:2]};
                    cnt <= cnt + 1;
                end

                DONE: begin
                    z <= partial;
                end
            endcase
        end
    end

    assign busy = state != IDLE;
endmodule
