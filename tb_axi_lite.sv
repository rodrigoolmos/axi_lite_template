`timescale 1us/1ns
`include "agent_axi_lite.sv"

module tb_axi_lite;

    const integer t_clk    = 10;    // Clock period 100MHz

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    logic [31:0] data;

    axi_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) axi_if();

    axi_lite_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) master;

    axi_lite_template #(
        .C_DATA_WIDTH(DATA_WIDTH),
        .C_ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk    (axi_if.clk),
        .rst    (axi_if.rst),

        // AXI4-Lite SLAVE
        .awaddr (axi_if.awaddr),
        .awprot (axi_if.awprot),
        .awvalid(axi_if.awvalid),
        .awready(axi_if.awready),

        .wdata  (axi_if.wdata),
        .wstrb  (axi_if.wstrb),
        .wvalid (axi_if.wvalid),
        .wready (axi_if.wready),

        .bresp  (axi_if.bresp),
        .bvalid (axi_if.bvalid),
        .bready (axi_if.bready),

        .araddr (axi_if.araddr),
        .arprot (axi_if.arprot),
        .arvalid(axi_if.arvalid),
        .arready(axi_if.arready),

        .rdata  (axi_if.rdata),
        .rresp  (axi_if.rresp),
        .rvalid (axi_if.rvalid),
        .rready (axi_if.rready)
    );

    // Clock generation 
    initial begin
        axi_if.clk = 0;
        forever #(t_clk/2) axi_if.clk = ~axi_if.clk;
    end

    // Reset generation and initialization
    initial begin
        axi_if.rst = 0;
        master = new(axi_if);
        #100 @(posedge axi_if.clk);
        axi_if.rst = 1;
        @(posedge axi_if.clk);
    end

    initial begin
        @(posedge axi_if.rst);
        @(posedge axi_if.clk);

        for (int i=0; i<32; ++i) begin
            // Write transaction
            master.write(i, 32'h0000_0004 * i, 4'b1111);
            @(posedge axi_if.clk);
            
            // Read transaction
            master.read(data, 32'h0000_0004 * i);
            $display("Read data: %h, sended data: %h", data, i);
            if (data !== i)
                $error("Data mismatch: expected %h, got %h", i, data);
        end

        @(posedge axi_if.clk);

        $stop;

    end

endmodule