`timescale 1ns / 1ps

module uart_io #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115_200
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        rx,
    output wire        tx,

    input  wire        tx_write,
    input  wire [7:0]  tx_data,
    input  wire        rx_read,
    input  wire        ctrl_write,
    input  wire [31:0] ctrl_data,
    output wire [31:0] rx_data,
    output wire [31:0] status
);

    localparam CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE;
    localparam HALF_BIT_CLKS = CLKS_PER_BIT / 2;
    localparam [15:0] BIT_COUNT_MAX = CLKS_PER_BIT - 1;
    localparam [15:0] HALF_COUNT_MAX = HALF_BIT_CLKS - 1;

    reg        tx_busy;
    reg [15:0] tx_counter;
    reg [3:0]  tx_bit_index;
    reg [9:0]  tx_shift;

    assign tx = tx_busy ? tx_shift[0] : 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_busy      <= 1'b0;
            tx_counter   <= 16'h0;
            tx_bit_index <= 4'h0;
            tx_shift     <= 10'h3FF;
        end else begin
            if (tx_write && !tx_busy) begin
                // 8N1 frame: start bit, 8 data bits (LSB first), stop bit.
                tx_shift     <= {1'b1, tx_data, 1'b0};
                tx_busy      <= 1'b1;
                tx_counter   <= 16'h0;
                tx_bit_index <= 4'h0;
            end else if (tx_busy) begin
                if (tx_counter == BIT_COUNT_MAX) begin
                    tx_counter <= 16'h0;
                    if (tx_bit_index == 4'd9) begin
                        tx_busy  <= 1'b0;
                        tx_shift <= 10'h3FF;
                    end else begin
                        tx_bit_index <= tx_bit_index + 1'b1;
                        tx_shift     <= {1'b1, tx_shift[9:1]};
                    end
                end else begin
                    tx_counter <= tx_counter + 1'b1;
                end
            end

            // AXI UART Lite control bit 0 resets the TX FIFO.
            if (ctrl_write && ctrl_data[0]) begin
                tx_busy      <= 1'b0;
                tx_counter   <= 16'h0;
                tx_bit_index <= 4'h0;
                tx_shift     <= 10'h3FF;
            end
        end
    end

    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA  = 2'd2;
    localparam RX_STOP  = 2'd3;

    reg        rx_meta;
    reg        rx_sync;
    reg [1:0]  rx_state;
    reg [15:0] rx_counter;
    reg [2:0]  rx_bit_index;
    reg [7:0]  rx_shift;
    reg [7:0]  rx_byte;
    reg        rx_valid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_meta      <= 1'b1;
            rx_sync      <= 1'b1;
            rx_state     <= RX_IDLE;
            rx_counter   <= 16'h0;
            rx_bit_index <= 3'h0;
            rx_shift     <= 8'h0;
            rx_byte      <= 8'h0;
            rx_valid     <= 1'b0;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;

            if (rx_read)
                rx_valid <= 1'b0;

            case (rx_state)
                RX_IDLE: begin
                    rx_counter <= 16'h0;
                    if (!rx_sync)
                        rx_state <= RX_START;
                end

                RX_START: begin
                    if (rx_counter == HALF_COUNT_MAX) begin
                        rx_counter <= 16'h0;
                        if (!rx_sync) begin
                            rx_bit_index <= 3'h0;
                            rx_state     <= RX_DATA;
                        end else begin
                            rx_state <= RX_IDLE;
                        end
                    end else begin
                        rx_counter <= rx_counter + 1'b1;
                    end
                end

                RX_DATA: begin
                    if (rx_counter == BIT_COUNT_MAX) begin
                        rx_counter <= 16'h0;
                        rx_shift[rx_bit_index] <= rx_sync;
                        if (rx_bit_index == 3'd7)
                            rx_state <= RX_STOP;
                        else
                            rx_bit_index <= rx_bit_index + 1'b1;
                    end else begin
                        rx_counter <= rx_counter + 1'b1;
                    end
                end

                RX_STOP: begin
                    if (rx_counter == BIT_COUNT_MAX) begin
                        rx_counter <= 16'h0;
                        rx_state   <= RX_IDLE;
                        if (rx_sync) begin
                            rx_byte  <= rx_shift;
                            rx_valid <= 1'b1;
                        end
                    end else begin
                        rx_counter <= rx_counter + 1'b1;
                    end
                end
            endcase

            // AXI UART Lite control bit 1 resets the RX FIFO.
            if (ctrl_write && ctrl_data[1]) begin
                rx_state   <= RX_IDLE;
                rx_counter <= 16'h0;
                rx_valid   <= 1'b0;
            end
        end
    end

    assign rx_data = {24'h0, rx_byte};
    // [3] TX full, [2] TX empty, [1] RX full, [0] RX data valid.
    assign status  = {28'h0, tx_busy, !tx_busy, rx_valid, rx_valid};

endmodule
