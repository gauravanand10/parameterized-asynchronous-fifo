
# ============================================================
# Parameterized Asynchronous FIFO CDC
# Target: Basys 3 / Artix-7
# Vivado: 2024.1
# ============================================================

puts "INFO: Starting FIFO project setup..."

# ------------------------------------------------------------
# 1. Check that a Vivado project is open
# ------------------------------------------------------------

if {[current_project -quiet] eq ""} {
    error "No Vivado project is open. Open the FIFO project first."
}

# ------------------------------------------------------------
# 2. Set the synthesis top module
# ------------------------------------------------------------

set_property top basys3_top [current_fileset]

update_compile_order -fileset sources_1

puts "INFO: basys3_top selected as synthesis top."

# ------------------------------------------------------------
# 3. Create the Clocking Wizard IP
# ------------------------------------------------------------

set existing_ip [get_ips -quiet clk_wiz_0]

if {[llength $existing_ip] == 0} {

    create_ip \
        -name clk_wiz \
        -vendor xilinx.com \
        -library ip \
        -module_name clk_wiz_0

} else {
    puts "INFO: clk_wiz_0 already exists; reconfiguring it."
}

# ------------------------------------------------------------
# 4. Configure input and output clocks
# ------------------------------------------------------------

set_property -dict [list \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKIN1_JITTER_PS {100.0} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {25.000} \
    CONFIG.CLKOUT1_REQUESTED_PHASE {0.000} \
    CONFIG.CLKOUT2_REQUESTED_PHASE {0.000} \
    CONFIG.CLKOUT1_REQUESTED_DUTY_CYCLE {50.000} \
    CONFIG.CLKOUT2_REQUESTED_DUTY_CYCLE {50.000} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
    CONFIG.USE_LOCKED {true} \
] [get_ips clk_wiz_0]

# ------------------------------------------------------------
# 5. Generate the IP output products
# ------------------------------------------------------------

generate_target all [get_ips clk_wiz_0]

# Create the IP synthesis run
create_ip_run [get_ips clk_wiz_0]

# ------------------------------------------------------------
# 6. Update source compile order
# ------------------------------------------------------------

update_compile_order -fileset sources_1

update_compile_order -fileset sim_1

puts "INFO: Clocking Wizard configured."
puts "INFO: Requested clocks: 100 MHz and 25 MHz."
puts "INFO: Check the generated IP ports before synthesis."

# ------------------------------------------------------------
# 7. Verify the IP exists
# ------------------------------------------------------------

report_property [get_ips clk_wiz_0]

# ------------------------------------------------------------
# 8. Launch synthesis
# ------------------------------------------------------------

launch_runs synth_1 -jobs 4

puts "INFO: Synthesis launched."
