#!/usr/bin/env bash
# Load bitstream + firmware to Zybo Z7-20 over JTAG and check UART output.
# Usage (inside `nix develop`, after `vivado -mode batch -source build.tcl`):
#   ./board/run.sh
set -euo pipefail
cd "$(dirname "$0")"

TTY=${TTY:-$(ls /dev/serial/by-id/usb-Digilent*-if01-port0 2>/dev/null | head -1)}
[ -e "$TTY" ] || { echo "Zybo UART not found (USB connected and powered on?)"; exit 1; }
LOG=build/uart.log

[ -f build/system.bit ] || { echo "build/system.bit missing: run 'vivado -mode batch -source build.tcl' in board/"; exit 1; }
make -C ../fw

stty -F "$TTY" 115200 raw -echo
cat "$TTY" > "$LOG" &
trap 'kill $! 2>/dev/null' EXIT

xsdb program.tcl build/system.bit build/ps7_init.tcl ../fw/fw.elf

for _ in $(seq 50); do
	grep -q "TEST \(PASS\|FAIL\)" "$LOG" && break
	sleep 0.2
done
cat "$LOG"
grep -q "TEST PASS" "$LOG"
