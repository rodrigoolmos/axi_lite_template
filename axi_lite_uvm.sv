`include "agent_axi_lite.sv"
`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_lite_seq_item #(
    int ADDR_WIDTH = 32,
    int DATA_WIDTH = 32
) extends uvm_sequence_item;

    rand logic                  is_write;   // 1 = write, 0 = read
    rand logic [ADDR_WIDTH-1:0] addr;
    rand logic [DATA_WIDTH-1:0] data;
    rand logic [DATA_WIDTH/8-1:0] strb;

    logic [1:0] resp;  // RRESP/BRESP opcional

    `uvm_object_param_utils_begin(axi_lite_seq_item#(ADDR_WIDTH, DATA_WIDTH))
        `uvm_field_int(is_write, UVM_ALL_ON)
        `uvm_field_int(addr,     UVM_ALL_ON)
        `uvm_field_int(data,     UVM_ALL_ON)
        `uvm_field_int(strb,     UVM_ALL_ON)
        `uvm_field_int(resp,     UVM_ALL_ON | UVM_NOPACK)
    `uvm_object_utils_end

    function new(string name = "axi_lite_seq_item");
        super.new(name);
    endfunction

endclass

class axi_lite_sequencer #(
    int ADDR_WIDTH = 32,
    int DATA_WIDTH = 32
) extends uvm_sequencer #(axi_lite_seq_item#(ADDR_WIDTH, DATA_WIDTH));

    `uvm_component_param_utils(axi_lite_sequencer#(ADDR_WIDTH, DATA_WIDTH))

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass

class axi_lite_driver_uvm #(int ADDR_WIDTH = 32,
                            int DATA_WIDTH = 32)
    extends uvm_driver #(axi_lite_seq_item#(ADDR_WIDTH, DATA_WIDTH));

    `uvm_component_param_utils(axi_lite_driver_uvm#(ADDR_WIDTH, DATA_WIDTH))

    virtual axi_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) vif;

    axi_lite_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) bfm;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual axi_if#(ADDR_WIDTH,DATA_WIDTH))::get(
            this, "", "vif", vif))
        `uvm_fatal("NOVIF", "virtual axi_if not set");

        bfm = new();
        bfm.connect_if(vif);
    endfunction

    task run_phase(uvm_phase phase);
        axi_lite_seq_item#(ADDR_WIDTH, DATA_WIDTH) tr;
        bfm.reset_if();
        forever begin
            seq_item_port.get_next_item(tr);
            if (tr.is_write)
                bfm.write(tr.data, tr.addr, tr.strb);
            else
                bfm.read(tr.data, tr.addr);
            seq_item_port.item_done();
        end
    endtask

endclass

class axi_lite_agent #(
    int ADDR_WIDTH = 32,
    int DATA_WIDTH = 32
) extends uvm_agent;

    `uvm_component_param_utils(axi_lite_agent#(ADDR_WIDTH, DATA_WIDTH))

    axi_lite_sequencer#(ADDR_WIDTH, DATA_WIDTH)  sqr;
    axi_lite_driver_uvm#(ADDR_WIDTH, DATA_WIDTH) drv;
    // futuramente: monitor

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = axi_lite_sequencer#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("sqr", this);
        drv = axi_lite_driver_uvm#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("drv", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass

class axi_lite_seq #(
    int ADDR_WIDTH = 32,
    int DATA_WIDTH = 32
) extends uvm_sequence #(axi_lite_seq_item#(ADDR_WIDTH, DATA_WIDTH));

    `uvm_object_param_utils(axi_lite_seq#(ADDR_WIDTH, DATA_WIDTH))

    function new(string name = "axi_lite_seq");
        super.new(name);
    endfunction

    task body();
        axi_lite_seq_item#(ADDR_WIDTH, DATA_WIDTH) tr;

        // WRITE
        tr = axi_lite_seq_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("wr_tr");
        tr.is_write = 1;
        tr.addr     = 'h0;
        tr.data     = 'hDEADBEEF;
        tr.strb     = '1; // todos los bytes
        start_item(tr);
        finish_item(tr);

        // READ
        tr = axi_lite_seq_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("rd_tr");
        tr.is_write = 0;
        tr.addr     = 'h0;
        start_item(tr);
        finish_item(tr);

        `uvm_info("SEQ", $sformatf("Read data = %h", tr.data), UVM_MEDIUM)
    endtask

endclass

class axi_lite_env #(
    int ADDR_WIDTH = 32,
    int DATA_WIDTH = 32
) extends uvm_env;

    `uvm_component_param_utils(axi_lite_env#(ADDR_WIDTH, DATA_WIDTH))

    axi_lite_agent#(ADDR_WIDTH, DATA_WIDTH) axi_ag;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        axi_ag = axi_lite_agent#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("axi_ag", this);
    endfunction

endclass


class axi_lite_test extends uvm_test;
    `uvm_component_utils(axi_lite_test)

    localparam int ADDR_WIDTH = 32;
    localparam int DATA_WIDTH = 32;

    axi_lite_env#(ADDR_WIDTH, DATA_WIDTH) env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axi_lite_env#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi_lite_seq#(ADDR_WIDTH, DATA_WIDTH) seq;

        phase.raise_objection(this);

        seq = axi_lite_seq#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("seq");
        seq.start(env.axi_ag.sqr);

        #1000;
        phase.drop_objection(this);
    endtask
endclass