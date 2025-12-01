`timescale 1us/1ns

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "axi_lite_uvm.sv"

module tb_axi_lite_uvm;

    // Usa los mismos parámetros que tu DUT e interface
    localparam int DATA_WIDTH = 32;
    localparam int ADDR_WIDTH = 32;

    // Clock/reset
    logic clk;
    logic nrst;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        nrst = 0;
        repeat (5) @(posedge clk);
        nrst = 1;
    end

    // Interface física
    axi_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) axi_if_inst();

    // Conecta clk / reset
    assign axi_if_inst.clk  = clk;
    assign axi_if_inst.nrst = nrst;

    // DUT
    axi_lite_template #(
        .C_DATA_WIDTH(DATA_WIDTH),
        .C_ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk    (axi_if_inst.clk),
        .nrst   (axi_if_inst.nrst),

        // AXI4-Lite SLAVE
        .awaddr (axi_if_inst.awaddr),
        .awprot (axi_if_inst.awprot),
        .awvalid(axi_if_inst.awvalid),
        .awready(axi_if_inst.awready),

        .wdata  (axi_if_inst.wdata),
        .wstrb  (axi_if_inst.wstrb),
        .wvalid (axi_if_inst.wvalid),
        .wready (axi_if_inst.wready),

        .bresp  (axi_if_inst.bresp),
        .bvalid (axi_if_inst.bvalid),
        .bready (axi_if_inst.bready),

        .araddr (axi_if_inst.araddr),
        .arprot (axi_if_inst.arprot),
        .arvalid(axi_if_inst.arvalid),
        .arready(axi_if_inst.arready),

        .rdata  (axi_if_inst.rdata),
        .rresp  (axi_if_inst.rresp),
        .rvalid (axi_if_inst.rvalid),
        .rready (axi_if_inst.rready)
    );

    initial begin
        // Conecta el virtual interface al agente UVM
        uvm_config_db#(virtual axi_if#(DATA_WIDTH, ADDR_WIDTH))::set(
            null,
            "uvm_test_top.env.axi_ag.*", // o "uvm_test_top.env.axi_ag.drv"
            "vif",
            axi_if_inst
        );

        run_test("axi_lite_test");
    end

endmodule
