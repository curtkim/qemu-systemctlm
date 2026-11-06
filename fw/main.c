#include <stdint.h>

#define REG(addr) (*(volatile uint32_t *)(addr))

/* Accelerator on M_AXI_GP0 */
#define ACC_BASE   0x40000000u
#define ACC_A      REG(ACC_BASE + 0x00)
#define ACC_B      REG(ACC_BASE + 0x04)
#define ACC_KICK   REG(ACC_BASE + 0x08)
#define ACC_C      REG(ACC_BASE + 0x0C)
#define ACC_STATUS REG(ACC_BASE + 0x10)
#define ACC_IRQ_ID 61u /* IRQ_F2P[0] */

/* UART1 (Zybo console) */
#define UART_CR    REG(0xE0001000u)
#define UART_SR    REG(0xE000102Cu)
#define UART_FIFO  REG(0xE0001030u)

/* GIC (Cortex-A9 MPCore) */
#define GICC_BASE  0xF8F00100u
#define GICD_BASE  0xF8F01000u
#define GICC_CTLR  REG(GICC_BASE + 0x00)
#define GICC_PMR   REG(GICC_BASE + 0x04)
#define GICC_IAR   REG(GICC_BASE + 0x0C)
#define GICC_EOIR  REG(GICC_BASE + 0x10)
#define GICD_CTLR  REG(GICD_BASE + 0x000)
#define GICD_ISENABLER(n) REG(GICD_BASE + 0x100 + 4 * (n))
#define GICD_ICENABLER(n) REG(GICD_BASE + 0x180 + 4 * (n))
#define GICD_ICPENDR(n)   REG(GICD_BASE + 0x280 + 4 * (n))
#define GICD_IPRIORITYR8(n) (*(volatile uint8_t *)(GICD_BASE + 0x400 + (n)))
#define GICD_ITARGETSR8(n)  (*(volatile uint8_t *)(GICD_BASE + 0x800 + (n)))

static void putc_(char c)
{
	while (UART_SR & (1u << 4)) /* TX FIFO full */
		;
	UART_FIFO = (uint32_t)c;
}

static void puts_(const char *s)
{
	while (*s)
		putc_(*s++);
}

static void putd(int32_t v)
{
	char buf[12];
	int i = 0;
	uint32_t u = v < 0 ? -(uint32_t)v : (uint32_t)v;

	if (v < 0)
		putc_('-');
	do {
		buf[i++] = '0' + u % 10;
		u /= 10;
	} while (u);
	while (i)
		putc_(buf[--i]);
}

static volatile int irq_done;
static volatile int32_t result;

void irq_handler(void)
{
	uint32_t iar = GICC_IAR;

	if ((iar & 0x3ff) == ACC_IRQ_ID && (ACC_STATUS & 1)) {
		result = (int32_t)ACC_C;
		ACC_STATUS = 1; /* clear done/irq */
		irq_done = 1;
	}
	GICC_EOIR = iar;
}

static void gic_init(void)
{
	GICD_CTLR = 0;
	/* drop whatever an earlier boot (e.g. QSPI image) left enabled/pending */
	for (int n = 0; n < 3; n++) {
		GICD_ICENABLER(n) = ~0u;
		GICD_ICPENDR(n) = ~0u;
	}
	GICD_IPRIORITYR8(ACC_IRQ_ID) = 0xA0;
	GICD_ITARGETSR8(ACC_IRQ_ID) = 0x01;
	GICD_ISENABLER(ACC_IRQ_ID / 32) = 1u << (ACC_IRQ_ID % 32);
	GICD_CTLR = 1;
	GICC_PMR = 0xF0;
	GICC_CTLR = 1;
}

int main(void)
{
	static const int32_t tv[][2] = {
		{ 1, 2 }, { 100, -58 }, { -7, -8 }, { 0x12345678, 0x11111111 },
	};
	int fail = 0;

	UART_CR = 0x14; /* TX_EN | RX_EN */
	puts_("accel test start\r\n");

	gic_init();
	__asm__ volatile("cpsie i");

	for (unsigned i = 0; i < sizeof(tv) / sizeof(tv[0]); i++) {
		int32_t a = tv[i][0], b = tv[i][1];
		int32_t exp = (int32_t)((uint32_t)a + (uint32_t)b);

		irq_done = 0;
		ACC_A = (uint32_t)a;
		ACC_B = (uint32_t)b;
		ACC_KICK = 1;
		while (!irq_done)
			__asm__ volatile("wfi");

		putd(a); puts_(" + "); putd(b); puts_(" = "); putd(result);
		if (result == exp) {
			puts_("  OK\r\n");
		} else {
			puts_("  NG (expected "); putd(exp); puts_(")\r\n");
			fail++;
		}
	}
	puts_(fail ? "TEST FAIL\r\n" : "TEST PASS\r\n");
	return 0;
}
