#!/usr/bin/env bash
# Run QEMU (Zynq-7000 firmware) + SystemC/Verilator accel co-simulation.
# Usage (inside `nix develop`): ./run.sh
set -euo pipefail
cd "$(dirname "$0")"

make -C fw
make -C sim

MP=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$MP"' EXIT

qemu-system-aarch64 -M arm-generic-fdt-7series -m 512M \
	-hw-dtb "$COSIM_DTB" \
	-device loader,file=fw/fw.elf,cpu-num=0 \
	-serial /dev/null -serial mon:stdio -display none \
	-machine-path "$MP" \
	-icount 0,sleep=off -rtc clock=vm -sync-quantum 10000 &

while [ ! -S "$MP/qemu-rport-_cosim@0" ]; do sleep 0.1; done
./sim/top "unix:$MP/qemu-rport-_cosim@0" 10000 &

wait -n
