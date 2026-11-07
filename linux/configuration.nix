{ config, pkgs, lib, ... }:
let
  accel-test = pkgs.writeCBin "accel-test" (builtins.readFile ./accel-test.c);
in
{
  # no armv7l binary cache: cross build from x86_64
  nixpkgs.hostPlatform = "armv7l-linux";
  nixpkgs.buildPlatform = "x86_64-linux";

  # board/gendt is generated from the XSA by board/gendt.tcl (must be git-added)
  #   sdtDir -> FSBL, dtDir -> system.dtb, bitstream -> BOOT.BIN
  hardware.zynq = {
    xlnxVersion = "2025.1";
    platform = "zynq";
    bitstream = ../board/gendt/sdt/system.bit;
    sdtDir = ../board/gendt/sdt;
    dtDir = ../board/gendt/dt;
  };
  hardware.deviceTree.overlays = [
    {
      name = "system-user";
      dtsFile = ./system-user.dts;
    }
  ];

  boot.supportedFilesystems = lib.mkForce [ "vfat" "ext4" ];
  documentation.enable = false;

  # xilinx_zynq_defconfig only (has UIO_PDRV_GENIRQ=y); autoModules breaks on 32-bit staging drivers
  boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_zynq.override { autoModules = false; });
  boot.kernelPatches = [
    {
      name = "systemd-extras";
      patch = null;
      structuredExtraConfig.AUTOFS_FS = lib.kernel.yes;
    }
  ];
  boot.kernelParams = [
    "earlycon"
    "console=ttyPS0,115200n8"
    "uio_pdrv_genirq.of_id=generic-uio"
  ];
  boot.initrd.availableKernelModules = lib.mkForce [ ];
  boot.initrd.allowMissingModules = true;

  networking.hostName = "zybo";
  networking.firewall.enable = false;
  users.users.root.initialPassword = "nixos";
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  environment.systemPackages = [ accel-test ];

  system.build.bootBin = config.hardware.zynq.boot-bin;

  system.stateVersion = "25.11";
}
