# PS7 + accel block design -> bitstream + ps7_init.tcl
#   cd board && vivado -mode batch -source build.tcl
set part   xc7z020clg400-1
set board  digilentinc.com:zybo-z7-20:part0:1.2
set outdir build

set_param board.repoPaths [list $::env(DIGILENT_BOARDS)]
create_project -force accel $outdir/prj -part $part
set_property board_part $board [current_project]
add_files [list ../rtl/accel.sv accel_axi.v]
update_compile_order -fileset sources_1

create_bd_design system

# PS7 with Zybo Z7-20 preset (DDR, MIO, UART1 115200)
set ps7 [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7 ps7]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} $ps7
set_property -dict {
    CONFIG.PCW_USE_M_AXI_GP0 1
    CONFIG.PCW_USE_FABRIC_INTERRUPT 1
    CONFIG.PCW_IRQ_F2P_INTR 1
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 100
} $ps7

# accel on M_AXI_GP0 @ 0x40000000, irq -> IRQ_F2P[0] (GIC ID 61)
set acc [create_bd_cell -type module -reference accel_axi accel]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Master /ps7/M_AXI_GP0 Clk_master Auto Clk_slave Auto Clk_xbar Auto} \
    [get_bd_intf_pins accel/s_axi]
connect_bd_net [get_bd_pins accel/irq] [get_bd_pins ps7/IRQ_F2P]
foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces ps7/Data]] {
    set_property offset 0x40000000 $seg
    set_property range 4K $seg
}

validate_bd_design
save_bd_design

set bd [get_files system.bd]
make_wrapper -files $bd -top
add_files -norecurse [glob $outdir/prj/accel.gen/sources_1/bd/system/hdl/system_wrapper.v]
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "implementation failed"
}

file copy -force $outdir/prj/accel.runs/impl_1/system_wrapper.bit $outdir/system.bit
write_hw_platform -fixed -include_bit -force $outdir/system.xsa
file copy -force [glob $outdir/prj/accel.gen/sources_1/bd/system/ip/system_ps7_0/ps7_init.tcl] $outdir/ps7_init.tcl
puts "OK: $outdir/system.bit $outdir/ps7_init.tcl $outdir/system.xsa"
