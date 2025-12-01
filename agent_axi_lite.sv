interface axi_if #(

	parameter integer DATA_WIDTH	= 32,
	parameter integer ADDR_WIDTH	= 32
);
	logic                           clk;
	logic                           nrst;

	logic [ADDR_WIDTH-1 : 0]        awaddr;
	logic [2 : 0]                   awprot;
	logic                           awvalid;
	logic                           awready;
	logic [DATA_WIDTH-1 : 0]        wdata;
	logic [(DATA_WIDTH/8)-1 : 0]    wstrb;
	logic                           wvalid;
	logic                           wready;
	logic [1 : 0]                   bresp;
	logic                           bvalid;
	logic                           bready;
	logic [ADDR_WIDTH-1 : 0]        araddr;
	logic [2 : 0]                   arprot;
	logic                           arvalid;
	logic                           arready;
	logic [DATA_WIDTH-1 : 0]        rdata;
	logic [1 : 0]                   rresp;
	logic                           rvalid;
	logic                           rready;



    //////////////////////////////////////////////////
    // Handshakes //
    //////////////////////////////////////////////////
    property handshake_occurs_before_valid_falls (logic valid, logic ready);
    @(posedge clk) disable iff (!nrst)
        $rose(valid) |-> valid until_with (valid && ready);
    endproperty

    property handshake_single_pulse (logic valid, logic ready);
    @(posedge clk) disable iff (!nrst)
        (valid && ready) |=> !(valid && ready);
    endproperty


    addr_r_handshake: assert property (handshake_occurs_before_valid_falls(arvalid, arready))
        else $error("Error: Read address handshake violation");
    addr_w_handshake: assert property (handshake_occurs_before_valid_falls(awvalid, awready))
        else $error("Error: Write address handshake violation");
    data_w_handshake: assert property (handshake_occurs_before_valid_falls(wvalid, wready))
        else $error("Error: Write data handshake violation");
    data_r_handshake: assert property (handshake_occurs_before_valid_falls(rvalid, rready))
        else $error("Error: Read data handshake violation");
    b_write_handshake: assert property (handshake_occurs_before_valid_falls(bvalid, bready))
        else $error("Error: bvalid response handshake violation");

    addr_r_1_clk: assert property (handshake_single_pulse(arvalid, arready))
        else $error("Error: Read address handshake did not complete in 1 clock");
    addr_w_1_clk: assert property (handshake_single_pulse(awvalid, awready))
        else $error("Error: Write address handshake did not complete in 1 clock");
    data_w_1_clk: assert property (handshake_single_pulse(wvalid, wready))
        else $error("Error: Write data handshake did not complete in 1 clock");
    data_r_1_clk: assert property (handshake_single_pulse(rvalid, rready))
        else $error("Error: Read data handshake did not complete in 1 clock");
    b_write_1_clk: assert property (handshake_single_pulse(bvalid, bready))
        else $error("Error: bvalid response handshake did not complete in 1 clock");


    //////////////////////////////////////////////////
    // Bvalid   channel   //
    //////////////////////////////////////////////////
    logic aw_hs, w_hs, b_hs;
    logic aw_seen, w_seen, complete_w, complete_w_ff;
    int wr_credits;
    assign aw_hs = awvalid && awready;
    assign w_hs  = wvalid  && wready;
    assign b_hs  = bvalid  && bready;
    assign complete_w = aw_seen && w_seen;

    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            aw_seen    <= 0;
            w_seen     <= 0;
            wr_credits <= 0;
            complete_w_ff <= 0;
        end else begin
            if (aw_hs) aw_seen <= 1;
            if (w_hs)  w_seen  <= 1;

            complete_w_ff <= complete_w;
            if (complete_w && !complete_w_ff) begin
                wr_credits <= wr_credits + 1;
            end

            if (b_hs) begin
                wr_credits <= wr_credits - 1;
                aw_seen    <= 0;
                w_seen     <= 0;
            end
        end
    end

    BVALID_simultaneous: assert property (@(posedge clk) disable iff (!nrst)
        $rose(b_hs) |-> !(aw_hs || w_hs))
        else $error("BVALID handshake simultaneous on AW or W handshake");

    BVALID_without_prior_AW_and_W: assert property (@(posedge clk) disable iff (!nrst)
        $rose(b_hs) |-> (complete_w))
        else $error("BVALID handshake without prior AW and W handshakes");

    parameter int MAX_LAT_B = 64;
    timeout_B: assert property (@(posedge clk) disable iff (!nrst)
        $rose(complete_w) |-> ##[1:MAX_LAT_B] $rose(bvalid))
        else $error("B did not arrive in %0d cycles after AW&W", MAX_LAT_B);

    Write_credits: assert property (@(posedge clk) disable iff (!nrst)
        wr_credits inside {[0:1]})
        else $error("Write credits exceeded maximum of 1");

    BVALID_fell_BREADY: assert property (@(posedge clk) disable iff (!nrst)
        bvalid && !bready |=> bvalid)
        else $error("BVALID fell before BREADY");

    stable_bresp: assert property (@(posedge clk) disable iff (!nrst)
        bvalid && !bready |=> $stable(bresp))
        else $error("BRESP changed without handshake");


    //////////////////////////////////////////////////
    // read   channel   //
    //////////////////////////////////////////////////

    property rdata_stable;
    @(posedge clk) disable iff (!nrst)
        (rvalid && !rready) |=> $stable(rdata);
    endproperty
    stable_rdata: assert property(rdata_stable)
        else $error("RDATA changed without handshake");


    // Directions
    assert property (@(posedge clk) disable iff (!nrst)
        (arvalid && !arready) |=> $stable(araddr) && $stable(arprot));

    assert property (@(posedge clk) disable iff (!nrst)
        (awvalid && !awready) |=> $stable(awaddr) && $stable(awprot));

    // Data and Strobes
    assert property (@(posedge clk) disable iff (!nrst)
        (wvalid && !wready) |=> $stable(wdata) && $stable(wstrb));

    // Responses
    assert property (@(posedge clk) disable iff (!nrst)
        (rvalid && !rready) |=> $stable(rdata) && $stable(rresp));
    assert property (@(posedge clk) disable iff (!nrst)
        (bvalid && !bready) |=> $stable(bresp));

    // Response values
    assert property (@(posedge clk) disable iff (!nrst)
        rvalid |-> (rresp inside {2'b00, 2'b10, 2'b11}));

    assert property (@(posedge clk) disable iff (!nrst)
     bvalid |-> (bresp inside {2'b00, 2'b10, 2'b11}));


     // unknown values
    assert property (@(posedge clk) disable iff (!nrst)
    !$isunknown({awaddr, awprot, awvalid, awready,
                wdata, wstrb, wvalid, wready,
                bresp, bvalid, bready,
                araddr, arprot, arvalid, arready,
                rdata, rresp, rvalid, rready,
                clk, nrst}))
    else $error("AXI-Lite interface contains X/Z values");

    //////////////////////////////////////////////////
    // RVALID channel (AXI-Lite read path)          //
    //////////////////////////////////////////////////
    logic ar_hs, r_hs;
    assign ar_hs = arvalid && arready;
    assign r_hs  = rvalid  && rready;

    // Créditos lectura: como mucho 1 en vuelo
    int rd_credits;
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            rd_credits <= 0;
        end else begin
            if (ar_hs) rd_credits <= rd_credits + 1;
            if (r_hs)  rd_credits <= rd_credits - 1;
        end
    end

    R_no_R_without_AR: assert property (@(posedge clk) disable iff (!nrst)
        $rose(rvalid) |-> $past(rd_credits) > 0)
        else $error("RVALID without prior AR");

    parameter int MAX_LAT_R = 64;
    R_timeout: assert property (@(posedge clk) disable iff (!nrst)
        $rose(ar_hs) |-> ##[1:MAX_LAT_R] $rose(rvalid))
        else $error("R did not arrive in %0d cycles after AR", MAX_LAT_R);

    R_hs_one_cycle: assert property (@(posedge clk) disable iff (!nrst)
        (rvalid && rready) |=> !(rvalid && rready))
        else $error("R handshake repeated on consecutive cycles");

    R_valid_holds: assert property (@(posedge clk) disable iff (!nrst)
        $rose(rvalid) |-> rvalid until_with (rvalid && rready))
        else $error("RVALID fell before RREADY");

    R_not_same_cycle_as_AR: assert property (@(posedge clk) disable iff (!nrst)
        $rose(r_hs) |-> !ar_hs)
        else $error("R handshake simultaneous with AR handshake");

    R_resp_stable: assert property (@(posedge clk) disable iff (!nrst)
        (rvalid && !rready) |=> $stable(rresp))
        else $error("RRESP changed without handshake");

    R_credits_range: assert property (@(posedge clk) disable iff (!nrst)
        rd_credits inside {[0:1]})
        else $error("More than one outstanding read in AXI-Lite");

    // Address alignment

    araddr_aligned: assert property (@(posedge clk) disable iff (!nrst)
    ar_hs |-> (araddr[($clog2(DATA_WIDTH/8)-1):0] == 0))
    else $error("ARADDR not aligned");

    awaddr_aligned: assert property (@(posedge clk) disable iff (!nrst)
    aw_hs |-> (awaddr[($clog2(DATA_WIDTH/8)-1):0] == 0))
    else $error("AWADDR not aligned");


    /////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////
    //                      COVER GROUPS                       //
    /////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////        


    parameter int MAX_LAT_C = 4;

    // Same cycle (AW and W handshakes in the same cycle)
    AW_W_same_cycle: cover property (@(posedge clk) disable iff (!nrst)
        aw_hs && w_hs);

    // AW before W (excluding same-cycle)
    AW_before_W_no_simul: cover property (@(posedge clk) disable iff (!nrst)
        aw_hs ##[1:MAX_LAT_C] w_hs);

    // W before AW (excluding same-cycle)
    W_before_AW_no_simul: cover property (@(posedge clk) disable iff (!nrst)
        w_hs ##[1:MAX_LAT_C] aw_hs);

    arvalid_rready_before: cover property (@(posedge clk) disable iff (!nrst)
        $rose(arvalid) ##[1:MAX_LAT_C] $rose(rready));

    arvalid_rready_after: cover property (@(posedge clk) disable iff (!nrst)
        $rose(rready) ##[1:MAX_LAT_C] $rose(arvalid));

    arvalid_rready_same_cycle: cover property (@(posedge clk) disable iff (!nrst)
        $rose(arvalid) && $rose(rready));

endinterface

class axi_lite_master #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
);

    virtual axi_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) vif;

    function new(virtual axi_if #(
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .DATA_WIDTH(DATA_WIDTH)
                ) vif = null);
        this.vif = vif;
    endfunction

    // UVM-like connect phase
    function void connect_if(virtual axi_if #(
                                .ADDR_WIDTH(ADDR_WIDTH),
                                .DATA_WIDTH(DATA_WIDTH)
                            ) vif);
        this.vif = vif;
    endfunction

    // Initialize interface signals
    task reset_if();
        vif.awaddr  = '0;
        vif.awprot  = '0;
        vif.awvalid = 0;
        vif.wdata   = '0;
        vif.wstrb   = '0;
        vif.wvalid  = 0;
        vif.bready  = 0;
        vif.araddr  = '0;
        vif.arprot  = '0;
        vif.arvalid = 0;
        vif.rready  = 0;
    endtask

    task init_read();
        int sel = $urandom_range(0, 2);
        vif.arprot = 0;

        if (sel == 0) begin
            vif.arvalid = 1;
            repeat ($urandom_range(0,4)) @(posedge vif.clk) #1step;
            vif.rready  = 1;
        end else if (sel == 1) begin
            vif.rready  = 1;
            repeat ($urandom_range(0,4)) @(posedge vif.clk) #1step;
            vif.arvalid = 1;
        end else begin
            vif.arvalid = 1;
            vif.rready  = 1;
        end
    endtask

    task hs_read(ref logic [DATA_WIDTH-1:0] data);
        fork
            begin
                @(posedge vif.clk iff vif.arready && vif.arvalid);
                vif.arvalid = 0;
            end
            begin
                @(posedge vif.clk iff vif.rvalid && vif.rready);
                data       = vif.rdata;
                vif.rready = 0;
            end
        join
    endtask

    task automatic read(ref logic [DATA_WIDTH-1:0] data,
                        input logic [ADDR_WIDTH-1:0] addr);
        vif.araddr = addr;

        fork
            init_read();
            hs_read(data);
        join

        if (vif.rresp != 0)
            $error("AXI read failed, RRESP=%0b", vif.rresp);

        @(posedge vif.clk);
    endtask

    task init_write();
        int sel = $urandom_range(0, 2);
        vif.awprot = 0;

        if (sel == 0) begin
            vif.awvalid = 1;
            repeat ($urandom_range(0, 3)) @(posedge vif.clk) #1step;
            vif.wvalid  = 1;
            repeat ($urandom_range(0, 3)) @(posedge vif.clk) #1step;
            vif.bready  = 1;
        end else if (sel == 1) begin
            vif.wvalid  = 1;
            repeat ($urandom_range(0, 3)) @(posedge vif.clk) #1step;
            vif.awvalid = 1;
            repeat ($urandom_range(0, 3)) @(posedge vif.clk) #1step;
            vif.bready  = 1;
        end else begin
            vif.awvalid = 1;
            vif.wvalid  = 1;
            vif.bready  = 1;
        end
    endtask

    task hs_write();
        fork
        begin
            @(posedge vif.clk iff vif.awready && vif.awvalid);
            vif.awvalid = 0;
        end
        begin
            @(posedge vif.clk iff vif.wready && vif.wvalid);
            vif.wvalid  = 0;
        end
        begin
            @(posedge vif.clk iff vif.bvalid && vif.bready);
            if (vif.bresp != 0)
            $error("AXI write failed, BRESP=%0b", vif.bresp);
            vif.bready = 0;
        end
        join
    endtask

    task automatic write(input  logic [DATA_WIDTH-1:0]      data,
                        input  logic [ADDR_WIDTH-1:0]      addr,
                        input  logic [DATA_WIDTH/8-1:0]    strobe);
        vif.awaddr = addr;
        vif.wdata  = data;
        vif.wstrb  = strobe;

        fork
        init_write();
        hs_write();
        join

        @(posedge vif.clk);
    endtask

endclass
