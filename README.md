## Simulation: QEMUL - SystemC
```
QEMU(firmware) - remote_port - systemC(verilator)
```

## PS(firmware)-PL

## PS(linux)-PL
```
Vivado(board/build.tcl) → XSA → xsct(board/gendt.tcl) → board/gendt → nixos-xlnx → sdImage
accel: DT overlay(linux/system-user.dts)로 generic-uio → /dev/uio0 → accel-test
```
```sh
nix develop
(cd board && vivado -mode batch -source build.tcl)       # RTL 바꿨을 때만
(cd board && xsct gendt.tcl build/system.xsa gendt)
git add board/gendt                                       # flake는 git이 추적하는 파일만 봄
nix build .#sdImage -L -o result-sd
zstdcat result-sd/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```
JP5 → SD, UART `/dev/ttyUSB1` 115200, `root` / `nixos`
```sh
accel-test        # TEST PASS
```


