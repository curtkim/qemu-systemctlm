# XSA → Linux device tree (dt/) + system device tree (sdt/)
#   cd board && xsct gendt.tcl build/system.xsa gendt
#
# nixos-xlnx/scripts/gendt.tcl 을 Zynq-7000 고정 + device-tree-xlnx 경로를
# $DEVICE_TREE_XLNX (flake 가 fetch 한 store path) 에서 읽도록 바꾼 것.
set xsa    [lindex $argv 0]
set outdir [expr {$argc > 1 ? [lindex $argv 1] : "gendt"}]

if {![info exists ::env(DEVICE_TREE_XLNX)]} {
    puts "DEVICE_TREE_XLNX not set — run inside `nix develop`"
    exit 2
}
set dtg $::env(DEVICE_TREE_XLNX)

file delete -force $outdir/dt $outdir/sdt
file mkdir $outdir/dt $outdir/sdt

# 기존 방식: hsi + device-tree-xlnx → Linux 용 DT (hardware.zynq.dtDir)
hsi open_hw_design $xsa
hsi set_repo_path $dtg
puts "processors: [hsi get_cells -hier -filter {IP_TYPE==PROCESSOR}]"
hsi create_sw_design device-tree -os device_tree -proc ps7_cortexa9_0
hsi generate_target -dir $outdir/dt
hsi close_hw_design [hsi current_hw_design]

# SDT: FSBL 빌드 입력 (hardware.zynq.sdtDir) — ps7_init, bitstream 도 여기 들어감
sdtgen set_dt_param -xsa $xsa -dir $outdir/sdt
sdtgen generate_sdt
