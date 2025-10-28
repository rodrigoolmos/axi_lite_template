module axi_lite_template #(
    parameter integer C_ADDR_WIDTH = 9,
    parameter integer C_DATA_WIDTH = 32
)(
    input  logic                     clk,
    input  logic                     rst,

    // AXI4-Lite SLAVE
    input  logic [C_ADDR_WIDTH-1:0]  awaddr,
    input  logic [2:0]               awprot,
    input  logic                     awvalid,
    output logic                     awready,

    input  logic [C_DATA_WIDTH-1:0]  wdata,
    input  logic [C_DATA_WIDTH/8-1:0] wstrb,
    input  logic                     wvalid,
    output logic                     wready,

    output logic [1:0]               bresp,
    output logic                     bvalid,
    input  logic                     bready,

    input  logic [C_ADDR_WIDTH-1:0]  araddr,
    input  logic [2:0]               arprot,
    input  logic                     arvalid,
    output logic                     arready,

    output logic [C_DATA_WIDTH-1:0]  rdata,
    output logic [1:0]               rresp,
    output logic                     rvalid,
    input  logic                     rready

);

    localparam BYTES        = C_DATA_WIDTH/8;
    localparam ADDR_LSB     = $clog2(BYTES); 
    localparam IDX_WIDTH    = (C_ADDR_WIDTH>ADDR_LSB)? (C_ADDR_WIDTH-ADDR_LSB):1;

    logic [C_DATA_WIDTH-1:0]    reg_array [0:31];
    logic [C_ADDR_WIDTH-1:0]    araddr_reg;
    logic [C_ADDR_WIDTH-1:0]    awaddr_reg;
    logic [C_DATA_WIDTH-1:0]    wdata_reg;
    logic [C_DATA_WIDTH/8-1:0]  wstrb_reg;

    typedef enum logic {
        IDLE_READ,
        READ_DATA
    } state_read;
    state_read state_r;

    // READ CHANNEL
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            arready     <= 0;
            araddr_reg  <= 0;
            rdata       <= 0;
            rresp       <= 0;
            rvalid      <= 0;
            state_r     <= IDLE_READ;
        end else begin
            case (state_r)
                IDLE_READ: begin
                    arready     <= 1;
                    if (arvalid && arready) begin
                        araddr_reg  <= araddr;
                        state_r     <= READ_DATA;
                        arready <= 0;
                    end
                end

                READ_DATA: begin
                    rvalid  <= 1;
                    rresp   <= 0;
                    rdata   <= reg_array[ araddr_reg[C_ADDR_WIDTH-1:ADDR_LSB] ];
                    if (rready && rvalid) begin
                        rvalid  <= 0;
                        state_r <= IDLE_READ;
                    end
                end

                default: begin
                    state_r <= IDLE_READ;
                end
            endcase
        end
    end


    typedef enum logic [1:0] {
        IDLE_WRITE,
        HAVE_AW,
        HAVE_W,
        RESP
    } state_write;
    state_write state_w;


    // WRITE CHANNEL
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            awready     <= 0;
            wready      <= 0;
            bvalid      <= 0;
            bresp       <= 0;
            awaddr_reg  <= 0;
            wdata_reg   <= 0;
            wstrb_reg   <= 0;
            state_w     <= IDLE_WRITE;
        end else begin
            case (state_w)
                IDLE_WRITE: begin
                    awready <= 1;
                    wready  <= 1;
                    if ((wvalid && wready) && (awvalid && awready)) begin
                        wdata_reg   <= wdata;
                        wstrb_reg   <= wstrb;
                        awaddr_reg  <= awaddr;
                        wready      <= 0;
                        awready     <= 0;
                        state_w     <= RESP;
                    end else if (awvalid && awready) begin
                        awaddr_reg  <= awaddr;
                        awready     <= 0;
                        state_w     <= HAVE_AW;
                    end else if (wvalid && wready) begin
                        wdata_reg   <= wdata;
                        wstrb_reg   <= wstrb;
                        wready      <= 0;
                        state_w     <= HAVE_W;
                    end

                end

                HAVE_AW: begin
                    wready  <= 1;
                    if (wvalid && wready) begin
                        wdata_reg   <= wdata;
                        wstrb_reg   <= wstrb;
                        wready      <= 0;
                        state_w     <= RESP;
                    end
                end

                HAVE_W: begin
                    awready <= 1;
                    if (awvalid && awready) begin
                        awaddr_reg  <= awaddr;
                        awready     <= 0;
                        state_w     <= RESP;
                    end
                end

                RESP: begin
                    for (int i=0; i<BYTES; i++)
                        if (wstrb_reg[i])
                            reg_array[ awaddr_reg[C_ADDR_WIDTH-1:ADDR_LSB] ][i*8 +: 8] 
                                <= wdata_reg[i*8 +: 8];

                    bvalid  <= 1;
                    bresp   <= 0;
                    if (bready && bvalid) begin
                        bvalid  <= 0;
                        state_w <= IDLE_WRITE;
                    end
                end

                default: begin
                    state_w <= IDLE_WRITE;
                end
            endcase
        end
    end
    
endmodule