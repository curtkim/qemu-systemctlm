CROSS  ?= arm-none-eabi-
CC     := $(CROSS)gcc
CFLAGS := -mcpu=cortex-a9 -marm -mfloat-abi=soft -O2 -g -Wall -ffreestanding -nostdlib -Wl,--no-warn-rwx-segments

fw.elf: start.S main.c link.ld
	$(CC) $(CFLAGS) -T link.ld -o $@ start.S main.c -lgcc

clean:
	rm -f fw.elf

.PHONY: clean
