# Clocking Wizard: `clk_wiz_0`

## Role in the design

`clk_wiz_0.xci` configures the Xilinx Clocking Wizard instance consumed by `basys3_top.v`. The Basys 3 `CLK100MHZ` input feeds the IP. `clk_out1` clocks the FIFO write domain at 100 MHz; `clk_out2` clocks the read domain at 25 MHz. The two generated clocks share the same Clocking Wizard/MMCM source. The `locked` output informs the top-level reset logic that clock generation is ready.

## Settings recorded in the XCI

- Primary input clock: `clk_in1`, nominally 100 MHz.
- Clocking primitive: MMCM.
- Enabled output clocks: `clk_out1` at 100 MHz and `clk_out2` at 25 MHz.
- Requested phase: 0 degrees for both outputs.
- Requested duty cycle: 50% for both outputs.
- Reset input enabled and configured active high; `locked` output enabled.

The XCI is the source descriptor for the IP customization. It stores both the user-selected settings and generated metadata. It is not the vendor’s implementation source and does not include the generated IP products.

## Connection and verification

The top-level RTL instantiates `clk_wiz_0` and uses the generated outputs as `wclk` and `rclk`. The packaged XPR references this XCI; `../../tcl_script/setup_fifo.tcl` requests matching output frequencies. The Vivado screenshots in `../../images/vivado/` show the requested output and summary settings.

After opening the project, let Vivado regenerate the IP products. Verify that the generated wrapper exposes the expected `clk_in1`, reset, `clk_out1`, `clk_out2`, and `locked` ports. The routed clock report should describe 10 ns and 40 ns periods for the two FIFO domains. If those ports or periods differ, do not continue to synthesis until the project settings and RTL connections are reconciled.

The XCI’s original project configuration is covered only as described in `../../NOTICE.md`; Xilinx IP, tools, marks, and generated implementation products are not relicensed by this repository.
