/* Linux userspace test for the PL accelerator via UIO (generic-uio).
 *   accel-test [/dev/uioN]
 */
#include <fcntl.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/mman.h>
#include <unistd.h>

enum { ACC_A, ACC_B, ACC_KICK, ACC_C, ACC_STATUS };

int main(int argc, char **argv)
{
	static const int32_t tv[][2] = {
		{ 1, 2 }, { 100, -58 }, { -7, -8 }, { 0x12345678, 0x11111111 },
	};
	const char *dev = argc > 1 ? argv[1] : "/dev/uio0";
	int fail = 0;

	int fd = open(dev, O_RDWR);
	if (fd < 0) {
		perror(dev);
		return 1;
	}
	volatile uint32_t *r = mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (r == MAP_FAILED) {
		perror("mmap");
		return 1;
	}

	for (unsigned i = 0; i < sizeof(tv) / sizeof(tv[0]); i++) {
		int32_t a = tv[i][0], b = tv[i][1];
		int32_t exp = (int32_t)((uint32_t)a + (uint32_t)b);
		uint32_t on = 1, cnt;
		struct pollfd p = { .fd = fd, .events = POLLIN };

		write(fd, &on, sizeof(on)); /* (re)enable irq */
		r[ACC_A] = (uint32_t)a;
		r[ACC_B] = (uint32_t)b;
		r[ACC_KICK] = 1;

		if (poll(&p, 1, 1000) <= 0) {
			printf("%d + %d: irq timeout\n", a, b);
			fail++;
			continue;
		}
		read(fd, &cnt, sizeof(cnt));
		int32_t c = (int32_t)r[ACC_C];
		r[ACC_STATUS] = 1; /* clear done/irq */

		printf("%d + %d = %d  %s\n", a, b, c, c == exp ? "OK" : "NG");
		fail += c != exp;
	}
	puts(fail ? "TEST FAIL" : "TEST PASS");
	return fail != 0;
}
