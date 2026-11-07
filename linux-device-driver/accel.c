// SPDX-License-Identifier: GPL-2.0
/*
 * PL accelerator (rtl/accel.sv) driver: /dev/accel, ACCEL_IOC_ADD
 *
 * 0x00 A, 0x04 B, 0x08 KICK, 0x0C C, 0x10 STATUS (bit0 done, W1C)
 */
#include <linux/completion.h>
#include <linux/fs.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/uaccess.h>

#include "accel-ioctl.h"

#define ACC_A		0x00
#define ACC_B		0x04
#define ACC_KICK	0x08
#define ACC_C		0x0C
#define ACC_STATUS	0x10

struct accel {
	void __iomem *base;
	struct miscdevice misc;
	struct mutex lock;		/* one operation at a time */
	struct completion done;
	s32 c;
};

static irqreturn_t accel_irq(int irq, void *data)
{
	struct accel *acc = data;

	if (!(readl(acc->base + ACC_STATUS) & 1))
		return IRQ_NONE;
	acc->c = readl(acc->base + ACC_C);
	writel(1, acc->base + ACC_STATUS);	/* clear done/irq */
	complete(&acc->done);
	return IRQ_HANDLED;
}

static long accel_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{
	struct accel *acc = container_of(f->private_data, struct accel, misc);
	struct accel_op op;
	long ret = 0;

	if (cmd != ACCEL_IOC_ADD)
		return -ENOTTY;
	if (copy_from_user(&op, (void __user *)arg, sizeof(op)))
		return -EFAULT;

	mutex_lock(&acc->lock);
	reinit_completion(&acc->done);
	writel(op.a, acc->base + ACC_A);
	writel(op.b, acc->base + ACC_B);
	writel(1, acc->base + ACC_KICK);
	if (!wait_for_completion_timeout(&acc->done, msecs_to_jiffies(1000)))
		ret = -ETIMEDOUT;
	op.c = acc->c;
	mutex_unlock(&acc->lock);

	if (!ret && copy_to_user((void __user *)arg, &op, sizeof(op)))
		ret = -EFAULT;
	return ret;
}

static const struct file_operations accel_fops = {
	.owner		= THIS_MODULE,
	.unlocked_ioctl	= accel_ioctl,
};

static int accel_probe(struct platform_device *pdev)
{
	struct accel *acc;
	int irq, ret;

	acc = devm_kzalloc(&pdev->dev, sizeof(*acc), GFP_KERNEL);
	if (!acc)
		return -ENOMEM;
	mutex_init(&acc->lock);
	init_completion(&acc->done);

	acc->base = devm_platform_ioremap_resource(pdev, 0);
	if (IS_ERR(acc->base))
		return PTR_ERR(acc->base);
	irq = platform_get_irq(pdev, 0);
	if (irq < 0)
		return irq;

	writel(1, acc->base + ACC_STATUS);	/* drop stale done/irq */
	ret = devm_request_irq(&pdev->dev, irq, accel_irq, 0, "accel", acc);
	if (ret)
		return ret;

	acc->misc.minor = MISC_DYNAMIC_MINOR;
	acc->misc.name = "accel";
	acc->misc.fops = &accel_fops;
	acc->misc.parent = &pdev->dev;
	ret = misc_register(&acc->misc);
	if (ret)
		return ret;

	platform_set_drvdata(pdev, acc);
	dev_info(&pdev->dev, "/dev/accel, irq %d\n", irq);
	return 0;
}

static void accel_remove(struct platform_device *pdev)
{
	struct accel *acc = platform_get_drvdata(pdev);

	misc_deregister(&acc->misc);
}

static const struct of_device_id accel_of_match[] = {
	{ .compatible = "xlnx,accel-axi-1.0" },
	{ }
};
MODULE_DEVICE_TABLE(of, accel_of_match);

static struct platform_driver accel_driver = {
	.probe	= accel_probe,
	.remove	= accel_remove,
	.driver	= {
		.name		= "accel",
		.of_match_table	= accel_of_match,
	},
};
module_platform_driver(accel_driver);

MODULE_DESCRIPTION("PL a+b accelerator");
MODULE_LICENSE("GPL");
