// Zynq-7000 (QEMU, remote-port) <-> M_AXI_GP0 <-> AXI4-Lite <-> Verilated accel
#define SC_INCLUDE_DYNAMIC_PROCESSES

#include "systemc"
#include "tlm_utils/simple_initiator_socket.h"
#include "tlm_utils/simple_target_socket.h"
#include "tlm_utils/tlm_quantumkeeper.h"

using namespace sc_core;
using namespace sc_dt;
using namespace std;

#include "soc/interconnect/iconnect.h"
#include "soc/xilinx/zynq/xilinx-zynq.h"
#include "tlm-bridges/tlm2axilite-bridge.h"
#include "test-modules/signals-axilite.h"

#include "Vaccel.h"
#if VM_TRACE
#include <csignal>
#include <unistd.h>
#include "verilated_vcd_sc.h"

/* run.sh ends the sim with SIGTERM; flush the VCD before exiting */
static VerilatedVcdSc *tfp;
static void close_trace(void)
{
	if (tfp) {
		tfp->close();
		tfp = NULL;
	}
}
static void close_trace_sig(int sig)
{
	close_trace();
	_exit(0);
}
#endif

#define ADDR_W 8

SC_MODULE(Top)
{
	iconnect<1, 1> bus;
	xilinx_zynq zynq;
	sc_clock clk;
	sc_signal<bool> rst;	/* active high (zynq) */
	sc_signal<bool> rst_n;	/* active low (AXI) */
	tlm2axilite_bridge<ADDR_W, 32> bridge;
	AXILiteSignals<ADDR_W, 32> sigs;
	Vaccel accel;

	SC_HAS_PROCESS(Top);

	void pull_reset(void) {
		rst.write(true);
		rst_n.write(false);
		wait(1, SC_US);
		rst.write(false);
		rst_n.write(true);
	}

	Top(sc_module_name name, const char *sk_descr, sc_time quantum) :
		bus("bus"),
		zynq("zynq", sk_descr),
		clk("clk", sc_time(10, SC_NS)),
		rst("rst"),
		rst_n("rst_n"),
		bridge("bridge"),
		sigs("sigs"),
		accel("accel")
	{
		m_qk.set_global_quantum(quantum);

		zynq.rst(rst);

		/* M_AXI_GP0 0x40000000 -> accel */
		bus.memmap(0x40000000ULL, 0x100 - 1,
				ADDRMODE_RELATIVE, -1, bridge.tgt_socket);
		zynq.m_axi_gp[0]->bind(*(bus.t_sk[0]));

		bridge.clk(clk);
		bridge.resetn(rst_n);
		accel.aclk(clk);
		accel.aresetn(rst_n);
		sigs.connect(&bridge);
		sigs.connect(&accel);

		/* IRQ_F2P[0] -> GIC SPI 29 (ID 61) */
		accel.irq(zynq.pl2ps_irq[0]);

		zynq.tie_off();

		SC_THREAD(pull_reset);
	}

private:
	tlm_utils::tlm_quantumkeeper m_qk;
};

int sc_main(int argc, char *argv[])
{
	if (argc < 2) {
		cerr << "usage: " << argv[0] << " unix:<path> [sync-quantum-ns]" << endl;
		return 1;
	}
	uint64_t q = argc > 2 ? strtoull(argv[2], NULL, 10) : 10000;

	sc_set_time_resolution(1, SC_PS);
#if VM_TRACE
	Verilated::traceEverOn(true);
#endif
	Top *top = new Top("top", argv[1], sc_time((double) q, SC_NS));
#if VM_TRACE
	sc_start(SC_ZERO_TIME);
	tfp = new VerilatedVcdSc;
	top->accel.trace(tfp, 99);
	tfp->open("accel.vcd");
	atexit(close_trace);
	signal(SIGINT, close_trace_sig);
	signal(SIGTERM, close_trace_sig);

	/* QEMU keeps sim time running while idle; only dump the first VCD_US */
	const char *us = getenv("VCD_US");
	sc_start(sc_time(us ? atof(us) : 1000, SC_US));
	close_trace();
	cout << "VCD closed: accel.vcd" << endl;
#endif
	sc_start();
	return 0;
}
