# Vivado IP configuration

The `ip/` folder holds the source configuration for the Clocking Wizard used by `basys3_top`. It is configuration input to Vivado, not a generated HDL wrapper, simulation model, or implemented MMCM netlist.

## Files and roles

- [`clk_wiz_0/clk_wiz_0.xci`](clk_wiz_0/clk_wiz_0.xci) — Xilinx Clocking Wizard instance configuration, with the selected input/output frequencies and component settings.
- [`clk_wiz_0/README.md`](clk_wiz_0/README.md) — description of the component settings, ports, and regeneration workflow.

The XPR references the XCI as an IP source. `rtl/basys3_top.v` instantiates the generated IP module and uses its clock and lock outputs. `tcl_script/setup_fifo.tcl` configures the same requested frequencies during its setup flow. Keep the IP name, clock port names, and expected frequencies consistent across these three places.

## Clock configuration and design effect

The IP takes a nominal 100 MHz input and enables a 100 MHz output for the FIFO write side and a 25 MHz output for the read side. Both outputs request zero phase shift and 50% duty cycle. Reset is enabled as active high and the `locked` output is enabled. The top-level wrapper waits for clock lock before allowing its domain-specific reset synchronizers to release.

This makes the FIFO example exercise real independent clock edges while keeping both clocks derived from the board oscillator. The clock relationship is reflected in the timing/CDC reports; it does not eliminate the need for Gray-pointer synchronization in the FIFO RTL.

## Regeneration and compatibility

Open `vivado/parameterised_asynchronous_fifo.xpr` in a compatible Vivado installation and let Vivado generate the IP output products. The project may also require the matching Basys 3 board files. Generated caches, synthesis wrappers, and run products are local outputs and are intentionally not maintained copies in this folder.

If generated ports do not match `basys3_top.v`, compare the XCI with `tcl_script/setup_fifo.tcl`, inspect the generated wrapper, and resolve differences before synthesis. Do not hand-edit generated output products. Only the project-authored Clocking Wizard settings are considered under the scope in `../NOTICE.md`; Xilinx IP itself is not relicensed.
