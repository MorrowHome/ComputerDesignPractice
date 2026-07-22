`timescale 1ns / 1ps

// One-master/two-slave AXI4 address bridge.  Main memory occupies the normal
// address space; the highest 64 KiB (0xFFFF_0000-0xFFFF_FFFF) is routed to the
// memory-mapped peripheral block.
module soc_axi_bridge (
    input  wire        aclk,
    input  wire        areset,

    input  wire [31:0] s_awaddr,
    input  wire [7:0]  s_awlen,
    input  wire [2:0]  s_awsize,
    input  wire [1:0]  s_awburst,
    input  wire        s_awvalid,
    output wire        s_awready,
    input  wire [31:0] s_wdata,
    input  wire [3:0]  s_wstrb,
    input  wire        s_wlast,
    input  wire        s_wvalid,
    output wire        s_wready,
    output wire [1:0]  s_bresp,
    output wire        s_bvalid,
    input  wire        s_bready,

    input  wire [31:0] s_araddr,
    input  wire [7:0]  s_arlen,
    input  wire [2:0]  s_arsize,
    input  wire [1:0]  s_arburst,
    input  wire        s_arvalid,
    output wire        s_arready,
    output wire [31:0] s_rdata,
    output wire [1:0]  s_rresp,
    output wire        s_rlast,
    output wire        s_rvalid,
    input  wire        s_rready,

    output wire [31:0] m0_awaddr,
    output wire [7:0]  m0_awlen,
    output wire [2:0]  m0_awsize,
    output wire [1:0]  m0_awburst,
    output wire        m0_awvalid,
    input  wire        m0_awready,
    output wire [31:0] m0_wdata,
    output wire [3:0]  m0_wstrb,
    output wire        m0_wlast,
    output wire        m0_wvalid,
    input  wire        m0_wready,
    input  wire [1:0]  m0_bresp,
    input  wire        m0_bvalid,
    output wire        m0_bready,
    output wire [31:0] m0_araddr,
    output wire [7:0]  m0_arlen,
    output wire [2:0]  m0_arsize,
    output wire [1:0]  m0_arburst,
    output wire        m0_arvalid,
    input  wire        m0_arready,
    input  wire [31:0] m0_rdata,
    input  wire [1:0]  m0_rresp,
    input  wire        m0_rlast,
    input  wire        m0_rvalid,
    output wire        m0_rready,

    output wire [31:0] m1_awaddr,
    output wire [7:0]  m1_awlen,
    output wire [2:0]  m1_awsize,
    output wire [1:0]  m1_awburst,
    output wire        m1_awvalid,
    input  wire        m1_awready,
    output wire [31:0] m1_wdata,
    output wire [3:0]  m1_wstrb,
    output wire        m1_wlast,
    output wire        m1_wvalid,
    input  wire        m1_wready,
    input  wire [1:0]  m1_bresp,
    input  wire        m1_bvalid,
    output wire        m1_bready,
    output wire [31:0] m1_araddr,
    output wire [7:0]  m1_arlen,
    output wire [2:0]  m1_arsize,
    output wire [1:0]  m1_arburst,
    output wire        m1_arvalid,
    input  wire        m1_arready,
    input  wire [31:0] m1_rdata,
    input  wire [1:0]  m1_rresp,
    input  wire        m1_rlast,
    input  wire        m1_rvalid,
    output wire        m1_rready
);

    reg write_active;
    reg write_to_io;
    reg read_active;
    reg read_from_io;

    wire aw_select_io = s_awaddr[31:16] == 16'hFFFF;
    wire ar_select_io = s_araddr[31:16] == 16'hFFFF;
    wire current_write_io = write_active ? write_to_io : aw_select_io;
    wire current_read_io  = read_active  ? read_from_io : ar_select_io;

    assign s_awready = current_write_io ? m1_awready : m0_awready;
    assign s_wready  = current_write_io ? m1_wready  : m0_wready;
    assign s_bresp   = write_to_io ? m1_bresp  : m0_bresp;
    assign s_bvalid  = write_active && (write_to_io ? m1_bvalid : m0_bvalid);

    assign s_arready = current_read_io ? m1_arready : m0_arready;
    assign s_rdata   = read_from_io ? m1_rdata  : m0_rdata;
    assign s_rresp   = read_from_io ? m1_rresp  : m0_rresp;
    assign s_rlast   = read_from_io ? m1_rlast  : m0_rlast;
    assign s_rvalid  = read_active && (read_from_io ? m1_rvalid : m0_rvalid);

    assign m0_awaddr  = s_awaddr;
    assign m0_awlen   = s_awlen;
    assign m0_awsize  = s_awsize;
    assign m0_awburst = s_awburst;
    assign m0_awvalid = s_awvalid && !current_write_io;
    assign m0_wdata   = s_wdata;
    assign m0_wstrb   = s_wstrb;
    assign m0_wlast   = s_wlast;
    assign m0_wvalid  = s_wvalid && !current_write_io;
    assign m0_bready  = s_bready && write_active && !write_to_io;
    assign m0_araddr  = s_araddr;
    assign m0_arlen   = s_arlen;
    assign m0_arsize  = s_arsize;
    assign m0_arburst = s_arburst;
    assign m0_arvalid = s_arvalid && !current_read_io;
    assign m0_rready  = s_rready && read_active && !read_from_io;

    assign m1_awaddr  = s_awaddr;
    assign m1_awlen   = s_awlen;
    assign m1_awsize  = s_awsize;
    assign m1_awburst = s_awburst;
    assign m1_awvalid = s_awvalid && current_write_io;
    assign m1_wdata   = s_wdata;
    assign m1_wstrb   = s_wstrb;
    assign m1_wlast   = s_wlast;
    assign m1_wvalid  = s_wvalid && current_write_io;
    assign m1_bready  = s_bready && write_active && write_to_io;
    assign m1_araddr  = s_araddr;
    assign m1_arlen   = s_arlen;
    assign m1_arsize  = s_arsize;
    assign m1_arburst = s_arburst;
    assign m1_arvalid = s_arvalid && current_read_io;
    assign m1_rready  = s_rready && read_active && read_from_io;

    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            write_active <= 1'b0;
            write_to_io  <= 1'b0;
            read_active  <= 1'b0;
            read_from_io <= 1'b0;
        end else begin
            if (!write_active && s_awvalid && s_awready) begin
                write_active <= 1'b1;
                write_to_io  <= aw_select_io;
            end else if (write_active && s_bvalid && s_bready) begin
                write_active <= 1'b0;
            end

            if (!read_active && s_arvalid && s_arready) begin
                read_active  <= 1'b1;
                read_from_io <= ar_select_io;
            end else if (read_active && s_rvalid && s_rready && s_rlast) begin
                read_active <= 1'b0;
            end
        end
    end

endmodule
