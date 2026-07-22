`timescale 1ns / 1ps

`include "defines.vh"

module axi_master (
    input  wire                         aclk,
    input  wire                         areset,

    // ICache read interface
    output reg                          ic_dev_rrdy,
    input  wire                         ic_cpu_ren,
    input  wire [31:0]                  ic_cpu_raddr,
    output reg                          ic_dev_rvalid,
    output reg  [`IC_BLK_SIZE-1:0]      ic_dev_rdata,

    // DCache write interface
    output reg                          dc_dev_wrdy,
    input  wire [3:0]                   dc_cpu_wen,
    input  wire [31:0]                  dc_cpu_waddr,
    input  wire [31:0]                  dc_cpu_wdata,

    // DCache read interface
    output reg                          dc_dev_rrdy,
    input  wire                         dc_cpu_ren,
    input  wire [31:0]                  dc_cpu_raddr,
    output reg                          dc_dev_rvalid,
    output reg  [`DC_BLK_SIZE-1:0]      dc_dev_rdata,

    // AXI4 master write address channel
    output reg  [31:0]                  m_axi_awaddr,
    output reg  [7:0]                   m_axi_awlen,
    output reg  [2:0]                   m_axi_awsize,
    output reg  [1:0]                   m_axi_awburst,
    output reg                          m_axi_awvalid,
    input  wire                         m_axi_awready,

    // AXI4 master write data channel
    output reg  [31:0]                  m_axi_wdata,
    output reg  [3:0]                   m_axi_wstrb,
    output wire                         m_axi_wlast,
    output reg                          m_axi_wvalid,
    input  wire                         m_axi_wready,

    // AXI4 master write response channel
    output wire                         m_axi_bready,
    input  wire [1:0]                   m_axi_bresp,
    input  wire                         m_axi_bvalid,

    // AXI4 master read address channel
    output reg  [31:0]                  m_axi_araddr,
    output reg  [7:0]                   m_axi_arlen,
    output reg  [2:0]                   m_axi_arsize,
    output reg  [1:0]                   m_axi_arburst,
    output reg                          m_axi_arvalid,
    input  wire                         m_axi_arready,

    // AXI4 master read data channel
    input  wire [31:0]                  m_axi_rdata,
    output wire                         m_axi_rready,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,
    input  wire                         m_axi_rvalid
);

    localparam IDLE       = 3'd0;
    localparam WRITE_SEND = 3'd1;
    localparam WRITE_RESP = 3'd2;
    localparam READ_ADDR  = 3'd3;
    localparam READ_DATA  = 3'd4;

    localparam READ_ICACHE = 1'b0;
    localparam READ_DCACHE = 1'b1;

    reg [2:0] state;
    reg       read_target;
    reg [7:0] read_beat;
    reg [127:0] read_buffer;
    reg [127:0] completed_buffer;

    wire dc_uncached = dc_cpu_raddr[31:16] == 16'hFFFF;

    assign m_axi_wlast  = 1'b1;
    assign m_axi_bready = 1'b1;
    assign m_axi_rready = 1'b1;

    // Only one cache request is accepted in a cycle.  Data writes have the
    // highest priority, followed by data reads and instruction reads.
    always @(*) begin
        dc_dev_wrdy = (state == IDLE);
        dc_dev_rrdy = (state == IDLE) && !(|dc_cpu_wen);
        ic_dev_rrdy = (state == IDLE) && !(|dc_cpu_wen) && !dc_cpu_ren;

        completed_buffer = read_buffer;
        completed_buffer[read_beat*32 +: 32] = m_axi_rdata;
    end

    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            state          <= IDLE;
            read_target    <= READ_ICACHE;
            read_beat      <= 8'h0;
            read_buffer    <= 128'h0;
            ic_dev_rvalid  <= 1'b0;
            ic_dev_rdata   <= {`IC_BLK_SIZE{1'b0}};
            dc_dev_rvalid  <= 1'b0;
            dc_dev_rdata   <= {`DC_BLK_SIZE{1'b0}};
            m_axi_awaddr   <= 32'h0;
            m_axi_awlen    <= 8'h0;
            m_axi_awsize   <= 3'd2;
            m_axi_awburst  <= 2'b01;
            m_axi_awvalid  <= 1'b0;
            m_axi_wdata    <= 32'h0;
            m_axi_wstrb    <= 4'h0;
            m_axi_wvalid   <= 1'b0;
            m_axi_araddr   <= 32'h0;
            m_axi_arlen    <= 8'h0;
            m_axi_arsize   <= 3'd2;
            m_axi_arburst  <= 2'b01;
            m_axi_arvalid  <= 1'b0;
        end else begin
            ic_dev_rvalid <= 1'b0;
            dc_dev_rvalid <= 1'b0;

            case (state)
                IDLE: begin
                    if (|dc_cpu_wen) begin
                        m_axi_awaddr  <= {dc_cpu_waddr[31:2], 2'b0};
                        m_axi_awlen   <= 8'd0;
                        m_axi_awsize  <= 3'd2;
                        m_axi_awburst <= 2'b01;
                        m_axi_awvalid <= 1'b1;
                        m_axi_wdata   <= dc_cpu_wdata;
                        m_axi_wstrb   <= dc_cpu_wen;
                        m_axi_wvalid  <= 1'b1;
                        state         <= WRITE_SEND;
                    end else if (dc_cpu_ren) begin
                        read_target   <= READ_DCACHE;
                        read_beat     <= 8'h0;
                        read_buffer   <= 128'h0;
`ifdef ENABLE_DCACHE
                        m_axi_araddr  <= dc_uncached
                                           ? {dc_cpu_raddr[31:2], 2'b0}
                                           : {dc_cpu_raddr[31:4], 4'b0};
`else
                        m_axi_araddr  <= {dc_cpu_raddr[31:2], 2'b0};
`endif
                        m_axi_arlen   <= dc_uncached ? 8'd0 : (`DC_BLK_LEN - 1);
                        m_axi_arsize  <= 3'd2;
                        m_axi_arburst <= 2'b01;
                        m_axi_arvalid <= 1'b1;
                        state         <= READ_ADDR;
                    end else if (ic_cpu_ren) begin
                        read_target   <= READ_ICACHE;
                        read_beat     <= 8'h0;
                        read_buffer   <= 128'h0;
`ifdef ENABLE_ICACHE
                        m_axi_araddr  <= {ic_cpu_raddr[31:4], 4'b0};
`else
                        m_axi_araddr  <= {ic_cpu_raddr[31:2], 2'b0};
`endif
                        m_axi_arlen   <= `IC_BLK_LEN - 1;
                        m_axi_arsize  <= 3'd2;
                        m_axi_arburst <= 2'b01;
                        m_axi_arvalid <= 1'b1;
                        state         <= READ_ADDR;
                    end
                end

                WRITE_SEND: begin
                    if (m_axi_awvalid && m_axi_awready)
                        m_axi_awvalid <= 1'b0;
                    if (m_axi_wvalid && m_axi_wready)
                        m_axi_wvalid <= 1'b0;

                    if ((!m_axi_awvalid || m_axi_awready)
                            && (!m_axi_wvalid || m_axi_wready))
                        state <= WRITE_RESP;
                end

                WRITE_RESP: begin
                    if (m_axi_bvalid)
                        state <= IDLE;
                end

                READ_ADDR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        state         <= READ_DATA;
                    end
                end

                READ_DATA: begin
                    if (m_axi_rvalid) begin
                        read_buffer <= completed_buffer;
                        if (m_axi_rlast || read_beat == m_axi_arlen) begin
                            if (read_target == READ_ICACHE) begin
                                ic_dev_rdata  <= completed_buffer[`IC_BLK_SIZE-1:0];
                                ic_dev_rvalid <= 1'b1;
                            end else begin
                                dc_dev_rdata  <= completed_buffer[`DC_BLK_SIZE-1:0];
                                dc_dev_rvalid <= 1'b1;
                            end
                            state <= IDLE;
                        end else begin
                            read_beat <= read_beat + 1'b1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Responses are currently not used, but keeping the ports makes the
    // controller compatible with the full AXI4 interface required by Trace.
    wire unused_response = ^{m_axi_bresp, m_axi_rresp};

endmodule
