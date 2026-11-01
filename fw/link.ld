ENTRY(_start)

SECTIONS
{
	. = 0x00100000;
	.text : { KEEP(*(.vectors)) *(.text*) *(.rodata*) }
	.data : { *(.data*) }
	. = ALIGN(4);
	__bss_start = .;
	.bss : { *(.bss*) *(COMMON) }
	. = ALIGN(4);
	__bss_end = .;
	. = ALIGN(8);
	. += 0x1000;
	_irq_stack_top = .;
	. += 0x4000;
	_stack_top = .;
}
