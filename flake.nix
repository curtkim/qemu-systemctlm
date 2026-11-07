{
  description = "Simple AXI4-Lite accelerator: Zynq-7000 QEMU + SystemC/Verilator co-simulation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    libsoc = {
      url = "github:Xilinx/libsystemctlm-soc";
      flake = false;
    };
    # Vivado/Vitis 2025.1 (installer must be in the store: see README)
    xlnx-utils.url = "github:DLR-FT/xilinx-nix-utils/570a1398611cf3203f98f83599a0e44e9ad5fc93";
    # Digilent board files (Zybo Z7-20 PS7 preset: DDR, MIO, UART1)
    digilent-boards = {
      url = "github:Digilent/vivado-boards";
      flake = false;
    };
    # XSA -> Linux device tree (hsi), matched to Vivado 2025.1
    device-tree-xlnx = {
      url = "github:Xilinx/device-tree-xlnx/xilinx_v2025.1";
      flake = false;
    };
    # NixOS for Zynq: FSBL + bitstream + u-boot -> BOOT.BIN, sdImage
    nixos-xlnx.url = "github:chuangzhu/nixos-xlnx/8bb30b706ad4f89ecc92f6ce6f5b19de86cc19d1";
  };

  outputs = { self, nixpkgs, libsoc, xlnx-utils, digilent-boards, device-tree-xlnx, nixos-xlnx }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # use xlnx-utils' own nixpkgs so the already-built Vivado is reused
      xilinx-unified = (import xlnx-utils.inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ xlnx-utils.overlays.xilinx-unified ];
      }).xilinx-unified;

      qemuSub = name: rev: hash: pkgs.fetchgit {
        url = "https://gitlab.com/qemu-project/${name}.git";
        inherit rev hash;
      };

      # Xilinx QEMU (provides arm-generic-fdt-7series + remote-port)
      qemu-xilinx = pkgs.stdenv.mkDerivation {
        pname = "qemu-xilinx";
        version = "2025.2";
        src = pkgs.fetchFromGitHub {
          owner = "Xilinx";
          repo = "qemu";
          rev = "xilinx_v2025.2";
          hash = "sha256-bwM8ponTQjI+NEd5StiEVvVU2DdV/V73nmIaPXl+pkc=";
        };
        nativeBuildInputs = with pkgs; [ (python312.withPackages (ps: [ ps.distlib ])) ninja pkg-config flex bison perl ];
        buildInputs = with pkgs; [ glib pixman zlib dtc libgcrypt ];
        dontUseNinjaBuild = true;
        dontUseNinjaInstall = true;
        dontUseNinjaCheck = true;
        # GitHub tarball lacks meson subprojects; provide them offline
        preConfigure = ''
          patchShebangs .
          cp -r ${qemuSub "keycodemapdb" "f5772a62ec52591ff6870b7e8ef32482371f22c6" "sha256-EQrnBAXQhllbVCHpOsgREzYGncMUPEIoWFGnjo+hrH4="} subprojects/keycodemapdb
          cp -r ${qemuSub "berkeley-softfloat-3" "b64af41c3276f97f0e181920400ee056b9c88037" "sha256-Yflpx+mjU8mD5biClNpdmon24EHg4aWBZszbOur5VEA="} subprojects/berkeley-softfloat-3
          cp -r ${qemuSub "berkeley-testfloat-3" "e7af9751d9f9fd3b47911f51a5cfd08af256a9ab" "sha256-inQAeYlmuiRtZm37xK9ypBltCJ+ycyvIeIYZK8a+RYU="} subprojects/berkeley-testfloat-3
          chmod -R u+w subprojects
          cp -r subprojects/packagefiles/berkeley-softfloat-3/. subprojects/berkeley-softfloat-3/
          cp -r subprojects/packagefiles/berkeley-testfloat-3/. subprojects/berkeley-testfloat-3/
        '';
        configureFlags = [
          "--target-list=aarch64-softmmu"
          "--enable-fdt=system"
          "--disable-download"
          "--disable-docs"
          "--disable-werror"
          "--disable-tools"
          "--disable-vnc"
          "--disable-gtk"
          "--disable-sdl"
          "--disable-kvm"
          "--disable-xen"
        ];
        enableParallelBuilding = true;
        # meson links glib/pixman by full path, so the ld wrapper adds no rpath
        postFixup = ''
          patchelf --add-rpath ${pkgs.lib.makeLibraryPath [ pkgs.glib pkgs.pixman ]} $out/bin/qemu-system-aarch64
        '';
      };

      # Zybo HW device tree + Zynq-7000 PL remote-port description
      dtsUrl = f: "https://raw.githubusercontent.com/Xilinx/linux-xlnx/xilinx-v2025.2/arch/arm/boot/dts/xilinx/${f}";
      cosim-dtb = pkgs.runCommand "zybo-cosim-dtb" {
        nativeBuildInputs = [ pkgs.dtc pkgs.stdenv.cc ];
        zynq7000 = pkgs.fetchurl { url = dtsUrl "zynq-7000.dtsi"; sha256 = "0ll25gz7p1qf6ni1vqm0kbx48ail4zvyysx0vlakw3yqknmslad5"; };
        zybo = pkgs.fetchurl { url = dtsUrl "zynq-zybo.dts"; sha256 = "0lcx997xx2jc9xfing8i21yi1q9s7cmvyjp0xfvzv8lmg9kiv7kk"; };
        rp = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/Xilinx/qemu-devicetrees/xilinx_v2025.2/zynq-pl-remoteport.dtsi";
          sha256 = "1czfy7i3i01vf8gvyh5vi8zlygnr7252c46sgpykq154vh2aln08";
        };
      } ''
        cp $zynq7000 zynq-7000.dtsi
        cp $rp zynq-pl-remoteport.dtsi
        { cat $zybo; echo '#include "zynq-pl-remoteport.dtsi"'; } > zybo-cosim.dts
        mkdir -p $out
        cpp -nostdinc -undef -x assembler-with-cpp -I. zybo-cosim.dts \
          | dtc -q -I dts -O dtb -o $out/zybo-cosim.dtb -
      '';
    in
    {
      packages.${system} = {
        inherit qemu-xilinx cosim-dtb xilinx-unified;
        sdImage = self.nixosConfigurations.zybo.config.system.build.sdImage;
        boot-bin = self.nixosConfigurations.zybo.config.system.build.bootBin;
      };

      # Zybo Z7-20 Linux (PL accel via UIO): nix build .#sdImage
      nixosConfigurations.zybo = nixos-xlnx.inputs.nixpkgs.lib.nixosSystem {
        modules = [
          nixos-xlnx.nixosModules.sd-image
          ./linux/configuration.nix
        ];
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          qemu-xilinx
          verilator
          systemc
          gcc-arm-embedded
          gnumake
          dtc
          gtkwave
          xilinx-unified  # last: its bin/ also ships dtc, ninja, ...
        ];
        LIBSOC = "${libsoc}";
        SYSTEMC_HOME = "${pkgs.systemc}";
        COSIM_DTB = "${cosim-dtb}/zybo-cosim.dtb";
        DIGILENT_BOARDS = "${digilent-boards}/new/board_files";
        DEVICE_TREE_XLNX = "${device-tree-xlnx}";
      };
    };
}
