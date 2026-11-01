/* Cortex-A9 bare-metal startup (Zynq-7000) */
	.syntax unified
	.arm

	.section .vectors, "ax"
	.global _start
_vectors:
	b	_start		/* reset */
	b	.		/* undef */
	b	.		/* svc */
	b	.		/* prefetch abort */
	b	.		/* data abort */
	b	.
	b	irq_entry	/* irq */
	b	.		/* fiq */

_start:
	/* only CPU0 runs */
	mrc	p15, 0, r0, c0, c0, 5
	ands	r0, r0, #3
	bne	hang

	/* VBAR = _vectors, low vectors */
	ldr	r0, =_vectors
	mcr	p15, 0, r0, c12, c0, 0
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #(1 << 13)
	mcr	p15, 0, r0, c1, c0, 0

	cps	#0x12			/* IRQ mode */
	ldr	sp, =_irq_stack_top
	cps	#0x13			/* SVC mode */
	ldr	sp, =_stack_top

	ldr	r0, =__bss_start
	ldr	r1, =__bss_end
	mov	r2, #0
1:	cmp	r0, r1
	strlo	r2, [r0], #4
	blo	1b

	bl	main
hang:
	wfi
	b	hang

irq_entry:
	sub	lr, lr, #4
	push	{r0-r5, r12, lr}
	bl	irq_handler
	pop	{r0-r5, r12, lr}
	movs	pc, lr
