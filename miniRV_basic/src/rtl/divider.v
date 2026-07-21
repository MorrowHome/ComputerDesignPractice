`timescale 1ns / 1ps

module divider #(
    parameter WIDTH = 32
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire       start,
    output reg  [WIDTH-1:0] z,
    output reg  [WIDTH-1:0] r,
    output reg        busy     
);

    localparam CNT_WID = $clog2(WIDTH);

    reg [WIDTH-1:0] divisor;
    reg [WIDTH-1:0] quotient;
    reg [WIDTH:0]   remainder;
    reg [WIDTH-1:0] dividend;
    reg [CNT_WID-1:0] count;
    reg div_by_zero;

    wire [WIDTH:0] shifted_remainder =
        {remainder[WIDTH-1:0], quotient[WIDTH-1]};

    // Traditional restoring division: subtract first, then restore the
    // partial remainder by adding the divisor back if the result is negative.
    wire [WIDTH:0] trial_remainder =
        shifted_remainder - {1'b0, divisor};
    wire trial_negative = trial_remainder[WIDTH];
    wire [WIDTH:0] restored_remainder =
        trial_remainder + {1'b0, divisor};
    wire [WIDTH:0] next_remainder = trial_negative
                                  ? restored_remainder
                                  : trial_remainder;
    wire [WIDTH-1:0] next_quotient =
        {quotient[WIDTH-2:0], ~trial_negative};

    // Unsigned restoring division.  Signed division is built around this
    // module in ALU.v by taking operand magnitudes and restoring the signs.
    // No Verilog division/remainder operator or vendor IP is used.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            z           <= {WIDTH{1'b0}};
            r           <= {WIDTH{1'b0}};
            busy        <= 1'b0;
            divisor     <= {WIDTH{1'b0}};
            quotient    <= {WIDTH{1'b0}};
            remainder   <= {(WIDTH+1){1'b0}};
            dividend    <= {WIDTH{1'b0}};
            count       <= {CNT_WID{1'b0}};
            div_by_zero <= 1'b0;
        end else if (start && !busy) begin
            divisor     <= y;
            quotient    <= x;
            remainder   <= {(WIDTH+1){1'b0}};
            dividend    <= x;
            count       <= {CNT_WID{1'b0}};
            div_by_zero <= (y == {WIDTH{1'b0}});
            busy        <= 1'b1;
        end else if (busy) begin
            if (div_by_zero) begin
                // RISC-V: quotient is all ones and remainder is dividend.
                z    <= {WIDTH{1'b1}};
                r    <= dividend;
                busy <= 1'b0;
            end else begin
                quotient  <= next_quotient;
                remainder <= next_remainder;

                if (count == WIDTH - 1) begin
                    z    <= next_quotient;
                    r    <= next_remainder[WIDTH-1:0];
                    busy <= 1'b0;
                end else begin
                    count <= count + 1'b1;
                end
            end
        end
    end

endmodule
