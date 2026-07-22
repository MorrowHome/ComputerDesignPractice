`timescale 1ns / 1ps

module soc_peripherals_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    always #5 clk = !clk;

    reg [31:0] awaddr = 32'h0;
    reg awvalid = 1'b0;
    wire awready;
    reg [31:0] wdata = 32'h0;
    reg [3:0] wstrb = 4'h0;
    reg wvalid = 1'b0;
    wire wready;
    wire [1:0] bresp;
    wire bvalid;
    reg bready = 1'b1;

    reg [31:0] araddr = 32'h0;
    reg arvalid = 1'b0;
    wire arready;
    wire [31:0] rdata;
    wire [1:0] rresp;
    wire rlast;
    wire rvalid;
    reg rready = 1'b1;

    reg [15:0] sw = 16'hCAFE;
    wire [15:0] led;
    wire [7:0] dig_en;
    wire [7:0] dig_seg;
    wire [7:0] dig_seg1;
    reg rx = 1'b1;
    wire tx;

    soc_peripherals_axi DUT (
        .aclk          (clk),
        .areset        (rst),
        .s_axi_awaddr  (awaddr),
        .s_axi_awlen   (8'h0),
        .s_axi_awsize  (3'd2),
        .s_axi_awburst (2'b01),
        .s_axi_awvalid (awvalid),
        .s_axi_awready (awready),
        .s_axi_wdata   (wdata),
        .s_axi_wstrb   (wstrb),
        .s_axi_wlast   (1'b1),
        .s_axi_wvalid  (wvalid),
        .s_axi_wready  (wready),
        .s_axi_bresp   (bresp),
        .s_axi_bvalid  (bvalid),
        .s_axi_bready  (bready),
        .s_axi_araddr  (araddr),
        .s_axi_arlen   (8'h0),
        .s_axi_arsize  (3'd2),
        .s_axi_arburst (2'b01),
        .s_axi_arvalid (arvalid),
        .s_axi_arready (arready),
        .s_axi_rdata   (rdata),
        .s_axi_rresp   (rresp),
        .s_axi_rlast   (rlast),
        .s_axi_rvalid  (rvalid),
        .s_axi_rready  (rready),
        .sw            (sw),
        .led           (led),
        .dig_en        (dig_en),
        .dig_seg       (dig_seg),
        .dig_seg1      (dig_seg1),
        .rx            (rx),
        .tx            (tx)
    );

    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(negedge clk);
            awaddr  = addr;
            awvalid = 1'b1;
            wdata   = data;
            wstrb   = 4'hF;
            wvalid  = 1'b1;
            @(posedge clk);
            while (!(awready && wready))
                @(posedge clk);
            @(negedge clk);
            awvalid = 1'b0;
            wvalid  = 1'b0;
            while (!bvalid)
                @(posedge clk);
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task axi_read;
        input [31:0] addr;
        output [31:0] data;
        begin
            @(negedge clk);
            araddr  = addr;
            arvalid = 1'b1;
            @(posedge clk);
            while (!arready)
                @(posedge clk);
            @(negedge clk);
            arvalid = 1'b0;
            while (!rvalid)
                @(posedge clk);
            data = rdata;
            @(posedge clk);
        end
    endtask

    reg [31:0] value;
    integer i;
    initial begin
        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (3) @(posedge clk);

        axi_read(32'hFFFF_0000, value);
        if (value != 32'h0000_CAFE)
            $fatal(1, "switch read failed: %h", value);

        axi_write(32'hFFFF_1000, 32'h0000_A55A);
        if (led != 16'hA55A)
            $fatal(1, "LED write failed: %h", led);

        axi_write(32'hFFFF_2000, 32'h1234_ABCD);
        repeat (2) @(posedge clk);
        if (dig_en == 8'h0 || dig_seg == 8'h0 || dig_seg1 != dig_seg)
            $fatal(1, "seven-segment output failed");

        axi_read(32'hFFFF_4000, value);
        if (value == 32'h0)
            $fatal(1, "timer did not count");

        axi_read(32'hFFFF_3008, value);
        if (value[3:0] != 4'b0100)
            $fatal(1, "UART reset status failed: %h", value);

        axi_write(32'hFFFF_3004, 32'h0000_0041);
        axi_read(32'hFFFF_3008, value);
        if (!value[3])
            $fatal(1, "UART TX did not become busy: %h", value);

        for (i = 0; i < 4500; i = i + 1)
            @(posedge clk);
        axi_read(32'hFFFF_3008, value);
        if (value[3:0] != 4'b0100 || tx != 1'b1)
            $fatal(1, "UART TX did not finish: %h", value);

        $display("SOC_PERIPHERALS_TEST_PASS");
        $finish;
    end

endmodule
