`timescale 1ns / 1ps

`include "defines.vh"

module soc_peripherals_axi (
    input  wire        aclk,
    input  wire        areset,

    input  wire [31:0] s_axi_awaddr,
    input  wire [7:0]  s_axi_awlen,
    input  wire [2:0]  s_axi_awsize,
    input  wire [1:0]  s_axi_awburst,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wlast,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [31:0] s_axi_araddr,
    input  wire [7:0]  s_axi_arlen,
    input  wire [2:0]  s_axi_arsize,
    input  wire [1:0]  s_axi_arburst,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output reg  [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rlast,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    input  wire [15:0] sw,
    output wire [15:0] led,
    output wire [7:0]  dig_en,
    output wire [7:0]  dig_seg,
    output wire [7:0]  dig_seg1,
    input  wire        rx,
    output wire        tx
);

    reg        aw_pending;
    reg [31:0] awaddr_reg;
    reg        w_pending;
    reg [31:0] wdata_reg;
    reg [3:0]  wstrb_reg;

    reg led_write;
    reg digled_write;
    reg uart_tx_write;
    reg uart_ctrl_write;
    reg uart_rx_read;
    reg [31:0] peripheral_wdata;
    reg [3:0]  peripheral_wstrb;

    wire aw_fire = s_axi_awvalid && s_axi_awready;
    wire w_fire  = s_axi_wvalid  && s_axi_wready;
    wire have_aw = aw_pending || aw_fire;
    wire have_w  = w_pending  || w_fire;
    wire write_commit = have_aw && have_w && !s_axi_bvalid;

    wire [31:0] write_addr = aw_pending ? awaddr_reg : s_axi_awaddr;
    wire [31:0] write_data = w_pending  ? wdata_reg  : s_axi_wdata;
    wire [3:0]  write_strb = w_pending  ? wstrb_reg  : s_axi_wstrb;

    assign s_axi_awready = !aw_pending && !s_axi_bvalid;
    assign s_axi_wready  = !w_pending  && !s_axi_bvalid;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_arready = !s_axi_rvalid;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rlast   = s_axi_rvalid;

    wire [31:0] switch_data;
    wire [31:0] timer_low;
    wire [31:0] timer_high;
    wire [31:0] uart_rx_data;
    wire [31:0] uart_status;

    switch_io U_switch (
        .clk       (aclk),
        .rst       (areset),
        .sw        (sw),
        .read_data (switch_data)
    );

    led_io U_led (
        .clk        (aclk),
        .rst        (areset),
        .write_en   (led_write),
        .write_data (peripheral_wdata),
        .write_strb (peripheral_wstrb),
        .led        (led)
    );

    digled_io U_digled (
        .clk        (aclk),
        .rst        (areset),
        .write_en   (digled_write),
        .write_data (peripheral_wdata),
        .write_strb (peripheral_wstrb),
        .dig_en     (dig_en),
        .dig_seg    (dig_seg),
        .dig_seg1   (dig_seg1)
    );

    timer_io U_timer (
        .clk        (aclk),
        .rst        (areset),
        .timer_low  (timer_low),
        .timer_high (timer_high)
    );

    uart_io U_uart (
        .clk        (aclk),
        .rst        (areset),
        .rx         (rx),
        .tx         (tx),
        .tx_write   (uart_tx_write),
        .tx_data    (peripheral_wdata[7:0]),
        .rx_read    (uart_rx_read),
        .ctrl_write (uart_ctrl_write),
        .ctrl_data  (peripheral_wdata),
        .rx_data    (uart_rx_data),
        .status     (uart_status)
    );

    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            aw_pending     <= 1'b0;
            awaddr_reg     <= 32'h0;
            w_pending      <= 1'b0;
            wdata_reg      <= 32'h0;
            wstrb_reg      <= 4'h0;
            s_axi_bvalid   <= 1'b0;
            s_axi_rdata    <= 32'h0;
            s_axi_rvalid   <= 1'b0;
            led_write      <= 1'b0;
            digled_write   <= 1'b0;
            uart_tx_write  <= 1'b0;
            uart_ctrl_write<= 1'b0;
            uart_rx_read   <= 1'b0;
            peripheral_wdata <= 32'h0;
            peripheral_wstrb <= 4'h0;
        end else begin
            led_write       <= 1'b0;
            digled_write    <= 1'b0;
            uart_tx_write   <= 1'b0;
            uart_ctrl_write <= 1'b0;
            uart_rx_read    <= 1'b0;

            if (aw_fire) begin
                awaddr_reg <= s_axi_awaddr;
                aw_pending <= 1'b1;
            end
            if (w_fire) begin
                wdata_reg <= s_axi_wdata;
                wstrb_reg <= s_axi_wstrb;
                w_pending <= 1'b1;
            end

            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;

            if (write_commit) begin
                aw_pending   <= 1'b0;
                w_pending    <= 1'b0;
                s_axi_bvalid <= 1'b1;
                peripheral_wdata <= write_data;
                peripheral_wstrb <= write_strb;

                case (write_addr)
                    `PERI_ADDR_LED:
                        led_write <= 1'b1;
                    `PERI_ADDR_DIGLED:
                        digled_write <= 1'b1;
                    (`PERI_ADDR_UART + 32'h4):
                        uart_tx_write <= 1'b1;
                    (`PERI_ADDR_UART + 32'hC):
                        uart_ctrl_write <= 1'b1;
                    default: begin end
                endcase
            end

            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;

            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid <= 1'b1;
                case (s_axi_araddr)
                    `PERI_ADDR_SWITCH:
                        s_axi_rdata <= switch_data;
                    `PERI_ADDR_UART: begin
                        s_axi_rdata <= uart_rx_data;
                        uart_rx_read <= 1'b1;
                    end
                    (`PERI_ADDR_UART + 32'h8):
                        s_axi_rdata <= uart_status;
                    `PERI_ADDR_TIMER:
                        s_axi_rdata <= timer_low;
                    (`PERI_ADDR_TIMER + 32'h8):
                        s_axi_rdata <= timer_high;
                    default:
                        s_axi_rdata <= 32'h0;
                endcase
            end
        end
    end

    wire unused_burst_fields = ^{s_axi_awlen, s_axi_awsize,
                                 s_axi_awburst, s_axi_wlast,
                                 s_axi_arlen, s_axi_arsize,
                                 s_axi_arburst};

endmodule
