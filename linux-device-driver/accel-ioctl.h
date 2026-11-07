/* userspace <-> accel.ko interface (/dev/accel) */
#ifndef ACCEL_IOCTL_H
#define ACCEL_IOCTL_H

#include <linux/ioctl.h>
#include <linux/types.h>

struct accel_op {
	__s32 a;
	__s32 b;
	__s32 c;	/* out: a + b */
};

/* write A, B, KICK; sleep until irq; return C */
#define ACCEL_IOC_ADD _IOWR('A', 1, struct accel_op)

#endif
