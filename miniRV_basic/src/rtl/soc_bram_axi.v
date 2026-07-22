`timescale 1ns / 1ps

// The Trace framework provides its own bram_axi model.  For FPGA synthesis,
// this compatible AXI4 slave wraps the initialized DRAM Block Memory IP that
// already belongs to the starter Vivado project.
`ifndef RUN_TRACE
module bram_axi #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 4
) (
    input  wire                    s_aclk,
    input  wire                    s_aresetn,

    input  wire [ID_WIDTH-1:0]     s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  wire [7:0]              s_axi_awlen,
    input  wire [2:0]              s_axi_awsize,
    input  wire [1:0]              s_axi_awburst,
    input  wire                    s_axi_awlock,
    input  wire [3:0]              s_axi_awcache,
    input  wire [2:0]              s_axi_awprot,
    input  wire                    s_axi_awvalid,
    output wire                    s_axi_awready,
    input  wire [DATA_WIDTH-1:0]   s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  wire                    s_axi_wlast,
    input  wire                    s_axi_wvalid,
    output wire                    s_axi_wready,
    output wire [ID_WIDTH-1:0]     s_axi_bid,
    output wire [1:0]              s_axi_bresp,
    output wire                    s_axi_bvalid,
    input  wire                    s_axi_bready,

    input  wire [ID_WIDTH-1:0]     s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  wire [7:0]              s_axi_arlen,
    input  wire [2:0]              s_axi_arsize,
    input  wire [1:0]              s_axi_arburst,
    input  wire                    s_axi_arlock,
    input  wire [3:0]              s_axi_arcache,
    input  wire [2:0]              s_axi_arprot,
    input  wire                    s_axi_arvalid,
    output wire                    s_axi_arready,
    output wire [ID_WIDTH-1:0]     s_axi_rid,
    output wire [DATA_WIDTH-1:0]   s_axi_rdata,
    output wire [1:0]              s_axi_rresp,
    output wire                    s_axi_rlast,
    output wire                    s_axi_rvalid,
    input  wire                    s_axi_rready
);

    localparam IDLE       = 3'd0;
    localparam WRITE_DATA = 3'd1;
    localparam WRITE_RESP = 3'd2;
    localparam READ_ISSUE = 3'd3;
    localparam READ_SEND  = 3'd4;

    reg [2:0] state;
    reg [ID_WIDTH-1:0] transaction_id;
    reg [31:0] transaction_addr;
    reg [7:0] beats_left;
    reg [2:0] transfer_size;
    reg [1:0] burst_type;

    wire write_fire = state == WRITE_DATA && s_axi_wvalid;
    wire [14:0] dram_addr = transaction_addr[16:2];
    wire [3:0] dram_we = write_fire ? s_axi_wstrb : 4'h0;
    wire [31:0] dram_rdata;

    assign s_axi_awready = state == IDLE;
    assign s_axi_wready  = state == WRITE_DATA;
    assign s_axi_bid     = transaction_id;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_bvalid  = state == WRITE_RESP;

    // A write address has priority if read and write requests arrive together.
    assign s_axi_arready = state == IDLE && !s_axi_awvalid;
    assign s_axi_rid     = transaction_id;
    assign s_axi_rdata   = dram_rdata;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rlast   = state == READ_SEND && beats_left == 0;
    assign s_axi_rvalid  = state == READ_SEND;

    DRAM U_memory (
        .clka  (s_aclk),
        .addra (dram_addr),
        .douta (dram_rdata),
        .wea   (dram_we),
        .dina  (s_axi_wdata)
    );

    always @(posedge s_aclk or negedge s_aresetn) begin
        if (!s_aresetn) begin
            state            <= IDLE;
            transaction_id   <= {ID_WIDTH{1'b0}};
            transaction_addr <= 32'h0;
            beats_left       <= 8'h0;
            transfer_size    <= 3'd2;
            burst_type       <= 2'b01;
        end else begin
            case (state)
                IDLE: begin
                    if (s_axi_awvalid) begin
                        transaction_id   <= s_axi_awid;
                        transaction_addr <= s_axi_awaddr;
                        beats_left       <= s_axi_awlen;
                        transfer_size    <= s_axi_awsize;
                        burst_type       <= s_axi_awburst;
                        state            <= WRITE_DATA;
                    end else if (s_axi_arvalid) begin
                        transaction_id   <= s_axi_arid;
                        transaction_addr <= s_axi_araddr;
                        beats_left       <= s_axi_arlen;
                        transfer_size    <= s_axi_arsize;
                        burst_type       <= s_axi_arburst;
                        state            <= READ_ISSUE;
                    end
                end

                WRITE_DATA: begin
                    if (s_axi_wvalid) begin
                        if (s_axi_wlast || beats_left == 0) begin
                            state <= WRITE_RESP;
                        end else begin
                            beats_left <= beats_left - 1'b1;
                            if (burst_type != 2'b00)
                                transaction_addr <= transaction_addr
                                                        + (32'd1 << transfer_size);
                        end
                    end
                end

                WRITE_RESP: begin
                    if (s_axi_bready)
                        state <= IDLE;
                end

                READ_ISSUE: begin
                    // The Block Memory output is valid after this clock edge.
                    state <= READ_SEND;
                end

                READ_SEND: begin
                    if (s_axi_rready) begin
                        if (beats_left == 0) begin
                            state <= IDLE;
                        end else begin
                            beats_left <= beats_left - 1'b1;
                            if (burst_type != 2'b00)
                                transaction_addr <= transaction_addr
                                                        + (32'd1 << transfer_size);
                            state <= READ_ISSUE;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    wire unused_axi_attributes = ^{s_axi_awlock, s_axi_awcache,
                                   s_axi_awprot, s_axi_arlock,
                                   s_axi_arcache, s_axi_arprot};

endmodule
`endif
