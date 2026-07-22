`timescale 1ns / 1ps

`include "defines.vh"

module DCache (
    input  wire                         clk,
    input  wire                         rst,

    input  wire [3:0]                   cpu_ren,
    input  wire [31:0]                  cpu_addr,
    output reg                          cpu_rvalid,
    output reg  [31:0]                  cpu_rdata,
    input  wire [3:0]                   cpu_wen,
    input  wire [31:0]                  cpu_wdata,
    output reg                          cpu_wresp,

    input  wire                         dev_wrdy,
    output reg  [3:0]                   dev_wen,
    output reg  [31:0]                  dev_waddr,
    output reg  [31:0]                  dev_wdata,
    input  wire                         dev_rrdy,
    output reg                          dev_ren,
    output reg  [31:0]                  dev_raddr,
    input  wire                         dev_rvalid,
    input  wire [`DC_BLK_SIZE-1:0]      dev_rdata
);

    localparam IDLE      = 3'd0;
    localparam READ_REQ  = 3'd1;
    localparam READ_WAIT = 3'd2;
    localparam WRITE_REQ = 3'd3;
    localparam WRITE_WAIT= 3'd4;

    reg [2:0] state;
    reg [31:0] request_addr;

`ifdef ENABLE_DCACHE
    // 64 direct-mapped lines, 16 bytes per line: 1 KiB total.
    localparam INDEX_BITS = 6;
    localparam LINE_COUNT = 1 << INDEX_BITS;
    localparam TAG_BITS   = 32 - INDEX_BITS - 4;

    reg [TAG_BITS-1:0] tag_array  [0:LINE_COUNT-1];
    reg [127:0]        data_array [0:LINE_COUNT-1];
    reg                valid_array[0:LINE_COUNT-1];

    wire [INDEX_BITS-1:0] cpu_index = cpu_addr[INDEX_BITS+3:4];
    wire [TAG_BITS-1:0]   cpu_tag   = cpu_addr[31:INDEX_BITS+4];
    wire                  cacheable = cpu_addr[31:16] != 16'hFFFF;
    wire                  cpu_hit   = cacheable && valid_array[cpu_index]
                                           && tag_array[cpu_index] == cpu_tag;

    wire [INDEX_BITS-1:0] miss_index = request_addr[INDEX_BITS+3:4];
    wire [TAG_BITS-1:0]   miss_tag   = request_addr[31:INDEX_BITS+4];
    wire                  miss_cacheable = request_addr[31:16] != 16'hFFFF;

    integer i;
    integer b;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            request_addr <= 32'h0;
            cpu_rvalid   <= 1'b0;
            cpu_rdata    <= 32'h0;
            cpu_wresp    <= 1'b0;
            dev_wen      <= 4'h0;
            dev_waddr    <= 32'h0;
            dev_wdata    <= 32'h0;
            dev_ren      <= 1'b0;
            dev_raddr    <= 32'h0;
            for (i = 0; i < LINE_COUNT; i = i + 1)
                valid_array[i] <= 1'b0;
        end else begin
            cpu_rvalid <= 1'b0;
            cpu_wresp  <= 1'b0;

            case (state)
                IDLE: begin
                    dev_ren <= 1'b0;
                    dev_wen <= 4'h0;

                    if (|cpu_wen) begin
                        // Write-through, no-write-allocate.  A hit is updated
                        // locally so a following load observes the new bytes.
                        if (cpu_hit) begin
                            for (b = 0; b < 4; b = b + 1)
                                if (cpu_wen[b])
                                    data_array[cpu_index][cpu_addr[3:2]*32+b*8 +: 8]
                                        <= cpu_wdata[b*8 +: 8];
                        end
                        request_addr <= cpu_addr;
                        dev_waddr    <= {cpu_addr[31:2], 2'b0};
                        dev_wdata    <= cpu_wdata;
                        dev_wen      <= cpu_wen;
                        state        <= WRITE_REQ;
                    end else if (|cpu_ren) begin
                        if (cpu_hit) begin
                            case (cpu_addr[3:2])
                                2'd0: cpu_rdata <= data_array[cpu_index][31:0];
                                2'd1: cpu_rdata <= data_array[cpu_index][63:32];
                                2'd2: cpu_rdata <= data_array[cpu_index][95:64];
                                2'd3: cpu_rdata <= data_array[cpu_index][127:96];
                            endcase
                            cpu_rvalid <= 1'b1;
                        end else begin
                            request_addr <= cpu_addr;
                            dev_raddr    <= cacheable ? {cpu_addr[31:4], 4'b0}
                                                     : {cpu_addr[31:2], 2'b0};
                            dev_ren      <= 1'b1;
                            state        <= READ_REQ;
                        end
                    end
                end

                READ_REQ: if (dev_rrdy) begin
                    dev_ren <= 1'b0;
                    state   <= READ_WAIT;
                end

                READ_WAIT: if (dev_rvalid) begin
                    if (miss_cacheable) begin
                        data_array[miss_index]  <= dev_rdata;
                        tag_array[miss_index]   <= miss_tag;
                        valid_array[miss_index] <= 1'b1;
                        case (request_addr[3:2])
                            2'd0: cpu_rdata <= dev_rdata[31:0];
                            2'd1: cpu_rdata <= dev_rdata[63:32];
                            2'd2: cpu_rdata <= dev_rdata[95:64];
                            2'd3: cpu_rdata <= dev_rdata[127:96];
                        endcase
                    end else begin
                        cpu_rdata <= dev_rdata[31:0];
                    end
                    cpu_rvalid <= 1'b1;
                    state      <= IDLE;
                end

                WRITE_REQ: if (dev_wrdy) begin
                    dev_wen <= 4'h0;
                    state   <= WRITE_WAIT;
                end

                WRITE_WAIT: if (dev_wrdy) begin
                    cpu_wresp <= 1'b1;
                    state     <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
`else
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            request_addr <= 32'h0;
            cpu_rvalid   <= 1'b0;
            cpu_rdata    <= 32'h0;
            cpu_wresp    <= 1'b0;
            dev_wen      <= 4'h0;
            dev_waddr    <= 32'h0;
            dev_wdata    <= 32'h0;
            dev_ren      <= 1'b0;
            dev_raddr    <= 32'h0;
        end else begin
            cpu_rvalid <= 1'b0;
            cpu_wresp  <= 1'b0;
            case (state)
                IDLE: begin
                    dev_ren <= 1'b0;
                    dev_wen <= 4'h0;
                    if (|cpu_wen) begin
                        request_addr <= cpu_addr;
                        dev_waddr    <= {cpu_addr[31:2], 2'b0};
                        dev_wdata    <= cpu_wdata;
                        dev_wen      <= cpu_wen;
                        state        <= WRITE_REQ;
                    end else if (|cpu_ren) begin
                        request_addr <= cpu_addr;
                        dev_raddr    <= {cpu_addr[31:2], 2'b0};
                        dev_ren      <= 1'b1;
                        state        <= READ_REQ;
                    end
                end
                READ_REQ: if (dev_rrdy) begin
                    dev_ren <= 1'b0;
                    state   <= READ_WAIT;
                end
                READ_WAIT: if (dev_rvalid) begin
                    cpu_rdata  <= dev_rdata;
                    cpu_rvalid <= 1'b1;
                    state      <= IDLE;
                end
                WRITE_REQ: if (dev_wrdy) begin
                    dev_wen <= 4'h0;
                    state   <= WRITE_WAIT;
                end
                WRITE_WAIT: if (dev_wrdy) begin
                    cpu_wresp <= 1'b1;
                    state     <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
`endif

endmodule
