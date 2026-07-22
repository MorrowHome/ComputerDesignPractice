`timescale 1ns / 1ps

`include "defines.vh"

module ICache (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         cpu_rreq,
    input  wire [31:0]                  cpu_raddr,
    output reg                          cpu_rvalid,
    output reg  [31:0]                  cpu_rdata,

    input  wire                         dev_rrdy,
    output reg                          dev_ren,
    output reg  [31:0]                  dev_raddr,
    input  wire                         dev_rvalid,
    input  wire [`IC_BLK_SIZE-1:0]      dev_rdata
);

    localparam IDLE     = 2'd0;
    localparam MISS_REQ = 2'd1;
    localparam MISS_WAIT= 2'd2;

    reg [1:0] state;
    reg [31:0] request_addr;

`ifdef ENABLE_ICACHE
    // 64 direct-mapped lines, 16 bytes per line: 1 KiB total.
    localparam INDEX_BITS = 6;
    localparam LINE_COUNT = 1 << INDEX_BITS;
    localparam TAG_BITS   = 32 - INDEX_BITS - 4;

    reg [TAG_BITS-1:0] tag_array  [0:LINE_COUNT-1];
    reg [127:0]        data_array [0:LINE_COUNT-1];
    reg                valid_array[0:LINE_COUNT-1];

    wire [INDEX_BITS-1:0] cpu_index = cpu_raddr[INDEX_BITS+3:4];
    wire [TAG_BITS-1:0]   cpu_tag   = cpu_raddr[31:INDEX_BITS+4];
    wire                  cpu_hit   = valid_array[cpu_index]
                                           && tag_array[cpu_index] == cpu_tag;

    wire [INDEX_BITS-1:0] miss_index = request_addr[INDEX_BITS+3:4];
    wire [TAG_BITS-1:0]   miss_tag   = request_addr[31:INDEX_BITS+4];

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            cpu_rvalid  <= 1'b0;
            cpu_rdata   <= 32'h0;
            dev_ren     <= 1'b0;
            dev_raddr   <= 32'h0;
            request_addr<= 32'h0;
            for (i = 0; i < LINE_COUNT; i = i + 1)
                valid_array[i] <= 1'b0;
        end else begin
            cpu_rvalid <= 1'b0;

            case (state)
                IDLE: begin
                    dev_ren <= 1'b0;
                    if (cpu_rreq) begin
                        if (cpu_hit) begin
                            case (cpu_raddr[3:2])
                                2'd0: cpu_rdata <= data_array[cpu_index][31:0];
                                2'd1: cpu_rdata <= data_array[cpu_index][63:32];
                                2'd2: cpu_rdata <= data_array[cpu_index][95:64];
                                2'd3: cpu_rdata <= data_array[cpu_index][127:96];
                            endcase
                            cpu_rvalid <= 1'b1;
                        end else begin
                            request_addr <= cpu_raddr;
                            dev_raddr    <= {cpu_raddr[31:4], 4'b0};
                            dev_ren      <= 1'b1;
                            state        <= MISS_REQ;
                        end
                    end
                end

                MISS_REQ: begin
                    if (dev_rrdy) begin
                        dev_ren <= 1'b0;
                        state   <= MISS_WAIT;
                    end
                end

                MISS_WAIT: begin
                    if (dev_rvalid) begin
                        data_array[miss_index]  <= dev_rdata;
                        tag_array[miss_index]   <= miss_tag;
                        valid_array[miss_index] <= 1'b1;
                        case (request_addr[3:2])
                            2'd0: cpu_rdata <= dev_rdata[31:0];
                            2'd1: cpu_rdata <= dev_rdata[63:32];
                            2'd2: cpu_rdata <= dev_rdata[95:64];
                            2'd3: cpu_rdata <= dev_rdata[127:96];
                        endcase
                        cpu_rvalid <= 1'b1;
                        state      <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
`else
    // With the cache disabled this module remains as a protocol adapter, so
    // the CPU/cache interface is unchanged while debugging the AXI bus.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            cpu_rvalid   <= 1'b0;
            cpu_rdata    <= 32'h0;
            dev_ren      <= 1'b0;
            dev_raddr    <= 32'h0;
            request_addr <= 32'h0;
        end else begin
            cpu_rvalid <= 1'b0;
            case (state)
                IDLE: begin
                    dev_ren <= 1'b0;
                    if (cpu_rreq) begin
                        request_addr <= cpu_raddr;
                        dev_raddr    <= {cpu_raddr[31:2], 2'b0};
                        dev_ren      <= 1'b1;
                        state        <= MISS_REQ;
                    end
                end
                MISS_REQ: if (dev_rrdy) begin
                    dev_ren <= 1'b0;
                    state   <= MISS_WAIT;
                end
                MISS_WAIT: if (dev_rvalid) begin
                    cpu_rdata  <= dev_rdata;
                    cpu_rvalid <= 1'b1;
                    state      <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
`endif

endmodule
