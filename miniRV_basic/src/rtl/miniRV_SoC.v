`timescale 1ns / 1ps

`include "defines.vh"

module miniRV_SoC (
    input  wire         fpga_clk,
    input  wire         fpga_rst,
    input  wire [15:0]  sw,
    output wire [15:0]  led,
    output wire [7:0]   dig_en,
    output wire [7:0]   dig_seg,
    output wire [7:0]   dig_seg1,
    input  wire         rx,
    output wire         tx
);

`ifdef RUN_TRACE
    // Trace drives an active-high reset directly.
    wire sys_clk = fpga_clk;
    wire sys_rst = fpga_rst;
`else
    // EGO1 board reset is active low.  Hold the SoC reset until the PLL locks.
    wire pll_clk1;
    wire pll_lock;
    wire sys_clk = pll_clk1;
    wire reset_async = !fpga_rst || !pll_lock;
    reg [1:0] reset_sync;
    always @(posedge sys_clk or posedge reset_async) begin
        if (reset_async)
            reset_sync <= 2'b11;
        else
            reset_sync <= {reset_sync[0], 1'b0};
    end
    wire sys_rst = reset_sync[1];

    clk_wiz_0 U_clkgen (
        .clk_in1  (fpga_clk),
        .locked   (pll_lock),
        .clk_out1 (pll_clk1)
    );
`endif

    wire [31:0] cpu_awaddr;
    wire [7:0]  cpu_awlen;
    wire [2:0]  cpu_awsize;
    wire [1:0]  cpu_awburst;
    wire        cpu_awvalid;
    wire        cpu_awready;
    wire [31:0] cpu_wdata;
    wire [3:0]  cpu_wstrb;
    wire        cpu_wlast;
    wire        cpu_wvalid;
    wire        cpu_wready;
    wire        cpu_bready;
    wire [1:0]  cpu_bresp;
    wire        cpu_bvalid;
    wire [31:0] cpu_araddr;
    wire [7:0]  cpu_arlen;
    wire [2:0]  cpu_arsize;
    wire [1:0]  cpu_arburst;
    wire        cpu_arvalid;
    wire        cpu_arready;
    wire [31:0] cpu_rdata;
    wire        cpu_rready;
    wire [1:0]  cpu_rresp;
    wire        cpu_rlast;
    wire        cpu_rvalid;

    cpu_top U_cpu (
        .cpu_clk       (sys_clk),
        .cpu_rst       (sys_rst),
        .m_axi_awaddr  (cpu_awaddr),
        .m_axi_awlen   (cpu_awlen),
        .m_axi_awsize  (cpu_awsize),
        .m_axi_awburst (cpu_awburst),
        .m_axi_awvalid (cpu_awvalid),
        .m_axi_awready (cpu_awready),
        .m_axi_wdata   (cpu_wdata),
        .m_axi_wstrb   (cpu_wstrb),
        .m_axi_wlast   (cpu_wlast),
        .m_axi_wvalid  (cpu_wvalid),
        .m_axi_wready  (cpu_wready),
        .m_axi_bready  (cpu_bready),
        .m_axi_bresp   (cpu_bresp),
        .m_axi_bvalid  (cpu_bvalid),
        .m_axi_araddr  (cpu_araddr),
        .m_axi_arlen   (cpu_arlen),
        .m_axi_arsize  (cpu_arsize),
        .m_axi_arburst (cpu_arburst),
        .m_axi_arvalid (cpu_arvalid),
        .m_axi_arready (cpu_arready),
        .m_axi_rdata   (cpu_rdata),
        .m_axi_rready  (cpu_rready),
        .m_axi_rresp   (cpu_rresp),
        .m_axi_rlast   (cpu_rlast),
        .m_axi_rvalid  (cpu_rvalid)
    );

    wire [31:0] bram_awaddr;
    wire [7:0]  bram_awlen;
    wire [2:0]  bram_awsize;
    wire [1:0]  bram_awburst;
    wire        bram_awvalid;
    wire        bram_awready;
    wire [31:0] bram_wdata;
    wire [3:0]  bram_wstrb;
    wire        bram_wlast;
    wire        bram_wvalid;
    wire        bram_wready;
    wire        bram_bready;
    wire [1:0]  bram_bresp;
    wire        bram_bvalid;
    wire [31:0] bram_araddr;
    wire [7:0]  bram_arlen;
    wire [2:0]  bram_arsize;
    wire [1:0]  bram_arburst;
    wire        bram_arvalid;
    wire        bram_arready;
    wire [31:0] bram_rdata;
    wire        bram_rready;
    wire [1:0]  bram_rresp;
    wire        bram_rlast;
    wire        bram_rvalid;

`ifdef RUN_TRACE
    // The Trace framework cannot simulate Vivado peripheral IP.  As required
    // by the guide, AXI Trace connects the CPU directly to the AXI RAM model.
    assign bram_awaddr  = cpu_awaddr;
    assign bram_awlen   = cpu_awlen;
    assign bram_awsize  = cpu_awsize;
    assign bram_awburst = cpu_awburst;
    assign bram_awvalid = cpu_awvalid;
    assign cpu_awready  = bram_awready;
    assign bram_wdata   = cpu_wdata;
    assign bram_wstrb   = cpu_wstrb;
    assign bram_wlast   = cpu_wlast;
    assign bram_wvalid  = cpu_wvalid;
    assign cpu_wready   = bram_wready;
    assign cpu_bresp    = bram_bresp;
    assign cpu_bvalid   = bram_bvalid;
    assign bram_bready  = cpu_bready;
    assign bram_araddr  = cpu_araddr;
    assign bram_arlen   = cpu_arlen;
    assign bram_arsize  = cpu_arsize;
    assign bram_arburst = cpu_arburst;
    assign bram_arvalid = cpu_arvalid;
    assign cpu_arready  = bram_arready;
    assign cpu_rdata    = bram_rdata;
    assign cpu_rresp    = bram_rresp;
    assign cpu_rlast    = bram_rlast;
    assign cpu_rvalid   = bram_rvalid;
    assign bram_rready  = cpu_rready;

    assign led      = 16'h0;
    assign dig_en   = 8'h0;
    assign dig_seg  = 8'h0;
    assign dig_seg1 = 8'h0;
    assign tx       = 1'b1;
`else
    wire [31:0] io_awaddr;
    wire [7:0]  io_awlen;
    wire [2:0]  io_awsize;
    wire [1:0]  io_awburst;
    wire        io_awvalid;
    wire        io_awready;
    wire [31:0] io_wdata;
    wire [3:0]  io_wstrb;
    wire        io_wlast;
    wire        io_wvalid;
    wire        io_wready;
    wire        io_bready;
    wire [1:0]  io_bresp;
    wire        io_bvalid;
    wire [31:0] io_araddr;
    wire [7:0]  io_arlen;
    wire [2:0]  io_arsize;
    wire [1:0]  io_arburst;
    wire        io_arvalid;
    wire        io_arready;
    wire [31:0] io_rdata;
    wire        io_rready;
    wire [1:0]  io_rresp;
    wire        io_rlast;
    wire        io_rvalid;

    soc_axi_bridge U_bridge (
        .aclk        (sys_clk),
        .areset      (sys_rst),
        .s_awaddr    (cpu_awaddr),
        .s_awlen     (cpu_awlen),
        .s_awsize    (cpu_awsize),
        .s_awburst   (cpu_awburst),
        .s_awvalid   (cpu_awvalid),
        .s_awready   (cpu_awready),
        .s_wdata     (cpu_wdata),
        .s_wstrb     (cpu_wstrb),
        .s_wlast     (cpu_wlast),
        .s_wvalid    (cpu_wvalid),
        .s_wready    (cpu_wready),
        .s_bresp     (cpu_bresp),
        .s_bvalid    (cpu_bvalid),
        .s_bready    (cpu_bready),
        .s_araddr    (cpu_araddr),
        .s_arlen     (cpu_arlen),
        .s_arsize    (cpu_arsize),
        .s_arburst   (cpu_arburst),
        .s_arvalid   (cpu_arvalid),
        .s_arready   (cpu_arready),
        .s_rdata     (cpu_rdata),
        .s_rresp     (cpu_rresp),
        .s_rlast     (cpu_rlast),
        .s_rvalid    (cpu_rvalid),
        .s_rready    (cpu_rready),
        .m0_awaddr   (bram_awaddr),
        .m0_awlen    (bram_awlen),
        .m0_awsize   (bram_awsize),
        .m0_awburst  (bram_awburst),
        .m0_awvalid  (bram_awvalid),
        .m0_awready  (bram_awready),
        .m0_wdata    (bram_wdata),
        .m0_wstrb    (bram_wstrb),
        .m0_wlast    (bram_wlast),
        .m0_wvalid   (bram_wvalid),
        .m0_wready   (bram_wready),
        .m0_bresp    (bram_bresp),
        .m0_bvalid   (bram_bvalid),
        .m0_bready   (bram_bready),
        .m0_araddr   (bram_araddr),
        .m0_arlen    (bram_arlen),
        .m0_arsize   (bram_arsize),
        .m0_arburst  (bram_arburst),
        .m0_arvalid  (bram_arvalid),
        .m0_arready  (bram_arready),
        .m0_rdata    (bram_rdata),
        .m0_rresp    (bram_rresp),
        .m0_rlast    (bram_rlast),
        .m0_rvalid   (bram_rvalid),
        .m0_rready   (bram_rready),
        .m1_awaddr   (io_awaddr),
        .m1_awlen    (io_awlen),
        .m1_awsize   (io_awsize),
        .m1_awburst  (io_awburst),
        .m1_awvalid  (io_awvalid),
        .m1_awready  (io_awready),
        .m1_wdata    (io_wdata),
        .m1_wstrb    (io_wstrb),
        .m1_wlast    (io_wlast),
        .m1_wvalid   (io_wvalid),
        .m1_wready   (io_wready),
        .m1_bresp    (io_bresp),
        .m1_bvalid   (io_bvalid),
        .m1_bready   (io_bready),
        .m1_araddr   (io_araddr),
        .m1_arlen    (io_arlen),
        .m1_arsize   (io_arsize),
        .m1_arburst  (io_arburst),
        .m1_arvalid  (io_arvalid),
        .m1_arready  (io_arready),
        .m1_rdata    (io_rdata),
        .m1_rresp    (io_rresp),
        .m1_rlast    (io_rlast),
        .m1_rvalid   (io_rvalid),
        .m1_rready   (io_rready)
    );

    soc_peripherals_axi U_peripherals (
        .aclk          (sys_clk),
        .areset        (sys_rst),
        .s_axi_awaddr  (io_awaddr),
        .s_axi_awlen   (io_awlen),
        .s_axi_awsize  (io_awsize),
        .s_axi_awburst (io_awburst),
        .s_axi_awvalid (io_awvalid),
        .s_axi_awready (io_awready),
        .s_axi_wdata   (io_wdata),
        .s_axi_wstrb   (io_wstrb),
        .s_axi_wlast   (io_wlast),
        .s_axi_wvalid  (io_wvalid),
        .s_axi_wready  (io_wready),
        .s_axi_bresp   (io_bresp),
        .s_axi_bvalid  (io_bvalid),
        .s_axi_bready  (io_bready),
        .s_axi_araddr  (io_araddr),
        .s_axi_arlen   (io_arlen),
        .s_axi_arsize  (io_arsize),
        .s_axi_arburst (io_arburst),
        .s_axi_arvalid (io_arvalid),
        .s_axi_arready (io_arready),
        .s_axi_rdata   (io_rdata),
        .s_axi_rresp   (io_rresp),
        .s_axi_rlast   (io_rlast),
        .s_axi_rvalid  (io_rvalid),
        .s_axi_rready  (io_rready),
        .sw            (sw),
        .led           (led),
        .dig_en        (dig_en),
        .dig_seg       (dig_seg),
        .dig_seg1      (dig_seg1),
        .rx            (rx),
        .tx            (tx)
    );
`endif

    wire [3:0] bram_bid;
    wire [3:0] bram_rid;

    bram_axi U_bram (
        .s_aclk         (sys_clk),
        .s_aresetn      (!sys_rst),
        .s_axi_awid     (4'h0),
        .s_axi_awaddr   (bram_awaddr),
        .s_axi_awlen    (bram_awlen),
        .s_axi_awsize   (bram_awsize),
        .s_axi_awburst  (bram_awburst),
        .s_axi_awlock   (1'b0),
        .s_axi_awcache  (4'h0),
        .s_axi_awprot   (3'h0),
        .s_axi_awvalid  (bram_awvalid),
        .s_axi_awready  (bram_awready),
        .s_axi_wdata    (bram_wdata),
        .s_axi_wstrb    (bram_wstrb),
        .s_axi_wlast    (bram_wlast),
        .s_axi_wvalid   (bram_wvalid),
        .s_axi_wready   (bram_wready),
        .s_axi_bid      (bram_bid),
        .s_axi_bresp    (bram_bresp),
        .s_axi_bvalid   (bram_bvalid),
        .s_axi_bready   (bram_bready),
        .s_axi_arid     (4'h0),
        .s_axi_araddr   (bram_araddr),
        .s_axi_arlen    (bram_arlen),
        .s_axi_arsize   (bram_arsize),
        .s_axi_arburst  (bram_arburst),
        .s_axi_arlock   (1'b0),
        .s_axi_arcache  (4'h0),
        .s_axi_arprot   (3'h0),
        .s_axi_arvalid  (bram_arvalid),
        .s_axi_arready  (bram_arready),
        .s_axi_rid      (bram_rid),
        .s_axi_rdata    (bram_rdata),
        .s_axi_rresp    (bram_rresp),
        .s_axi_rlast    (bram_rlast),
        .s_axi_rvalid   (bram_rvalid),
        .s_axi_rready   (bram_rready)
    );

    wire unused_bram_ids = ^{bram_bid, bram_rid};
`ifdef RUN_TRACE
    wire unused_trace_inputs = ^{sw, rx};
`endif

endmodule
