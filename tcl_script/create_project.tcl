# Recreate the FIFO Vivado project from the repository's canonical source folders.
# Run this file from the Vivado Tcl Console. Generated project files go under build/vivado.

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set project_dir [file join $repo_root build vivado]
set project_file [file join $project_dir parameterised_asynchronous_fifo.xpr]

if {[file exists $project_file]} {
    error "A generated project already exists at $project_file. Move it aside before recreating it."
}

file mkdir $project_dir
create_project parameterised_asynchronous_fifo $project_dir -part xc7a35tcpg236-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_files [glob -nocomplain [file join $repo_root rtl *.v]]
set tb_files [glob -nocomplain [file join $repo_root tb *.v]]
set xdc_file [file join $repo_root constraints basys3_top.xdc]
set xci_file [file join $repo_root ip clk_wiz_0 clk_wiz_0.xci]

if {[llength $rtl_files] == 0} {
    error "No RTL Verilog files were found in rtl/."
}
if {[llength $tb_files] == 0} {
    error "No testbench Verilog files were found in tb/."
}
if {![file exists $xdc_file]} {
    error "The Basys 3 constraints file is missing: $xdc_file"
}
if {![file exists $xci_file]} {
    error "The Clocking Wizard configuration is missing: $xci_file"
}

add_files -fileset sources_1 -norecurse $rtl_files
add_files -fileset sim_1 -norecurse $tb_files
add_files -fileset constrs_1 -norecurse $xdc_file
add_files -fileset sources_1 -norecurse $xci_file

set_property top basys3_top [get_filesets sources_1]
set_property top basys3_top_tb [get_filesets sim_1]

set clock_ip [get_ips -quiet clk_wiz_0]
if {[llength $clock_ip] == 0} {
    error "Vivado did not load clk_wiz_0 from the XCI configuration."
}
generate_target all $clock_ip
create_ip_run $clock_ip

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Created project: $project_file"
puts "Device: xc7a35tcpg236-1 (Basys 3)"
