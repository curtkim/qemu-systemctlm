// Minimal AXI4-Lite accelerator: c = a + b
//
// 0x00 A      (RW)
// 0x04 B      (RW)
// 0x08 KICK   (W)   write any value -> c = a + b, done=1, irq=1
// 0x0C C      (RO)
// 0x10 STATUS (R: bit0 done, W1C: bit0 clears done/irq)
module accel #(
    parameter int ADDR_W = 8
) (
    input  logic              aclk,
    input  logic              aresetn,

    input  logic              awvalid,
    output logic              awready,
    input  logic [ADDR_W-1:0] awaddr,
    input  logic [2:0]        awprot,

    input  logic              wvalid,
    output logic              wready,
    input  logic [31:0]       wdata,
    input  logic [3:0]        wstrb,

    output logic              bvalid,
    input  logic              bready,
    output logic [1:0]        bresp,

    input  logic              arvalid,
    output logic              arready,
    input  logic [ADDR_W-1:0] araddr,
    input  logic [2:0]        arprot,

    output logic              rvalid,
    input  logic              rready,
    output logic [31:0]       rdata,
    output logic [1:0]        rresp,

    output logic              irq
);
    logic [31:0] a, b, c;
    logic        done;

    assign bresp = 2'b00;
    assign rresp = 2'b00;
    assign irq   = done;

    // write: accept AW and W together, one at a time
    wire do_write = awvalid && wvalid && !bvalid;
    assign awready = do_write;
    assign wready  = do_write;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            a <= '0; b <= '0; c <= '0; done <= 1'b0; bvalid <= 1'b0;
        end else begin
            if (bvalid && bready) bvalid <= 1'b0;
            if (do_write) begin
                bvalid <= 1'b1;
                case (awaddr[4:2])
                    3'd0: a <= wdata;
                    3'd1: b <= wdata;
                    3'd2: begin c <= a + b; done <= 1'b1; end
                    3'd4: if (wdata[0]) done <= 1'b0;
                    default: ;
                endcase
            end
        end
    end

    // read
    assign arready = arvalid && !rvalid;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            rvalid <= 1'b0; rdata <= '0;
        end else begin
            if (rvalid && rready) rvalid <= 1'b0;
            if (arready) begin
                rvalid <= 1'b1;
                case (araddr[4:2])
                    3'd0: rdata <= a;
                    3'd1: rdata <= b;
                    3'd3: rdata <= c;
                    3'd4: rdata <= {31'b0, done};
                    default: rdata <= '0;
                endcase
            end
        end
    end

    wire unused = &{1'b0, awprot, arprot, wstrb, awaddr[1:0], araddr[1:0]};
endmodule
