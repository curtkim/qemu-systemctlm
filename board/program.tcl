# JTAG: PL bitstream + PS init + firmware (volatile)
#   xsdb program.tcl <system.bit> <ps7_init.tcl> <fw.elf>
lassign $argv bit init elf

connect
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 1000

fpga -file $bit
source $init
ps7_init
ps7_post_config

targets -set -nocase -filter {name =~ "*A9*#0"}
rst -processor
dow $elf
con
puts "firmware running"
