# accel.ko (out-of-tree) + accel-ko-test, built against the board kernel
#   used from linux/configuration.nix via kernelPackages.callPackage
{ lib, stdenv, kernel, kernelModuleMakeFlags, writeShellApplication, kmod }:
let
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./Makefile ./accel.c ./accel-ioctl.h ./accel-test.c ];
  };

  module = stdenv.mkDerivation {
    pname = "accel-module";
    version = "0.1";
    inherit src;
    nativeBuildInputs = kernel.moduleBuildDependencies;
    makeFlags = kernelModuleMakeFlags ++ [
      "-C" "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "M=$(PWD)"
      "INSTALL_MOD_PATH=${placeholder "out"}"
    ];
    buildFlags = [ "modules" ];
    installTargets = [ "modules_install" ];
  };

  test-bin = stdenv.mkDerivation {
    pname = "accel-ko-test-bin";
    version = "0.1";
    inherit src;
    buildPhase = "$CC -O2 -Wall -o accel-ko-test accel-test.c";
    installPhase = "install -Dm755 accel-ko-test $out/bin/accel-ko-test-bin";
  };

  # boot binds the node to uio_pdrv_genirq; move it to accel.ko, then test
  test = writeShellApplication {
    name = "accel-ko-test";
    runtimeInputs = [ kmod ];
    text = ''
      dev=$(basename /sys/bus/platform/devices/*.accel_axi)
      if [ -e /sys/bus/platform/drivers/uio_pdrv_genirq/"$dev" ]; then
        echo "$dev" > /sys/bus/platform/drivers/uio_pdrv_genirq/unbind
      fi
      modprobe accel  # usually already autoloaded by udev at boot
      # bind explicitly: drivers_probe would pick uio_pdrv_genirq again
      [ -e /sys/bus/platform/drivers/accel/"$dev" ] || echo "$dev" > /sys/bus/platform/drivers/accel/bind
      exec ${test-bin}/bin/accel-ko-test-bin "$@"
    '';
  };
in
{
  inherit module test;
}
