# usage: vivado -mode batch -source timing.tcl -tclargs <period_ns> <trace_en 0|1> <repo_dir> <out_dir>
if {$argc != 4} { puts "usage: timing.tcl period trace repo out"; exit 1 }
lassign $argv period trace repo out
set here [file dirname [file normalize [info script]]]
set part xc7s50csga324-1
file mkdir $out

set srcs {}
foreach d {core decode memory} { lappend srcs {*}[glob $repo/rtl/$d/*.sv] }
read_verilog -sv $srcs
read_verilog -sv [list $here/timing_top.sv $here/timing_imem.sv]

synth_design -top timing_top -part $part -mode out_of_context -generic TRACE_EN=1'b$trace
create_clock -name clk -period $period [get_ports clk]
set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports clk]
report_utilization -file $out/util_synth.rpt

opt_design
place_design
phys_opt_design
route_design
phys_opt_design

proc ram_pins {inst pat} {
    return [get_pins -quiet -hierarchical -filter "NAME =~ *${inst}* && REF_PIN_NAME =~ ${pat}"]
}
proc rpt_to {name pins out} {
    if {[llength $pins] == 0} { puts "WARN: no pins found for $name"; return }
    report_timing -delay_type max -to $pins -max_paths 5 -nworst 1 \
        -sort_by slack -file $out/path_${name}.rpt
}

report_timing_summary -delay_type max -max_paths 10 -file $out/timing_summary.rpt
report_timing -delay_type max -max_paths 10 -nworst 1 -file $out/path_worst.rpt
report_utilization -file $out/util_route.rpt
rpt_to dmem_addr [ram_pins u_dmem ADDR*] $out
rpt_to dmem_ctrl [concat [ram_pins u_dmem EN*] [ram_pins u_dmem WE*]] $out
rpt_to imem_addr [ram_pins u_imem ADDR*] $out
rpt_to imem_ctrl [ram_pins u_imem EN*] $out
write_checkpoint -force $out/post_route.dcp

set wns [get_property SLACK [get_timing_paths -max_paths 1 -delay_type max]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -delay_type min]]
set lut [llength [get_cells -hierarchical -filter {REF_NAME =~ LUT*}]]
set ff  [llength [get_cells -hierarchical -filter {REF_NAME =~ FD*}]]
set ram [llength [get_cells -hierarchical -filter {REF_NAME =~ RAMB*}]]
set fh [open $out/../results.csv a]
puts $fh "$period,$trace,$wns,$whs,$lut,$ff,$ram"
close $fh
rpt_to fetch_pc [get_pins -quiet -hierarchical -filter {NAME =~ *fetch_pc_reg* && REF_PIN_NAME == D}] $out
