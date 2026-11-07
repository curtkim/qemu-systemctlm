/* Linux userspace test for accel.ko: accel-ko-test [/dev/accel] */
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include "accel-ioctl.h"

int main(int argc, char **argv)
{
	static const int32_t tv[][2] = {
		{ 1, 2 }, { 100, -58 }, { -7, -8 }, { 0x12345678, 0x11111111 },
	};
	const char *dev = argc > 1 ? argv[1] : "/dev/accel";
	int fail = 0;

	int fd = open(dev, O_RDWR);
	if (fd < 0) {
		perror(dev);
		return 1;
	}

	for (unsigned i = 0; i < sizeof(tv) / sizeof(tv[0]); i++) {
		struct accel_op op = { .a = tv[i][0], .b = tv[i][1] };
		int32_t exp = (int32_t)((uint32_t)op.a + (uint32_t)op.b);

		if (ioctl(fd, ACCEL_IOC_ADD, &op) < 0) {
			perror("ACCEL_IOC_ADD");
			fail++;
			continue;
		}
		printf("%d + %d = %d  %s\n", op.a, op.b, op.c, op.c == exp ? "OK" : "NG");
		fail += op.c != exp;
	}
	puts(fail ? "TEST FAIL" : "TEST PASS");
	return fail != 0;
}
