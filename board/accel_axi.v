// Verilog wrapper for the block design (module reference can't be SV top).
// s_axi_* prefix lets Vivado infer the AXI4-Lite interface.
module accel_axi (
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET aresetn" *)
    input  wire        aclk,
    input  wire        aresetn,

    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [11:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    output wire [1:0]  s_axi_bresp,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    input  wire [11:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,

    (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 irq INTERRUPT" *)
    (* X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    output wire        irq
);
    accel #(.ADDR_W(12)) u_accel (
        .aclk(aclk), .aresetn(aresetn),
        .awvalid(s_axi_awvalid), .awready(s_axi_awready), .awaddr(s_axi_awaddr), .awprot(s_axi_awprot),
        .wvalid(s_axi_wvalid), .wready(s_axi_wready), .wdata(s_axi_wdata), .wstrb(s_axi_wstrb),
        .bvalid(s_axi_bvalid), .bready(s_axi_bready), .bresp(s_axi_bresp),
        .arvalid(s_axi_arvalid), .arready(s_axi_arready), .araddr(s_axi_araddr), .arprot(s_axi_arprot),
        .rvalid(s_axi_rvalid), .rready(s_axi_rready), .rdata(s_axi_rdata), .rresp(s_axi_rresp),
        .irq(irq)
    );
endmodule
