# Vivado Tcl workflow

The scripts use repository-relative paths and support two different tasks: create a new project from the canonical source tree, or configure an already-open project and launch synthesis. Both target the Basys 3 Artix-7 device and were written for Vivado 2024.1.

## Create a fresh project — `create_project.tcl`

Run this script from the Vivado Tcl Console when no project is open or when you want a fresh generated project. It creates `build/vivado/parameterised_asynchronous_fifo.xpr` and adds:

- all Verilog files from `rtl/` to the synthesis source set;
- all Verilog files from `tb/` to the simulation source set;
- `constraints/basys3_top.xdc` to the constraints set;
- `ip/clk_wiz_0/clk_wiz_0.xci` to the project IP sources.

It selects `basys3_top` as synthesis top, `basys3_top_tb` as simulation top, targets `xc7a35tcpg236-1`, generates the Clocking Wizard products, and updates compile order. Before creating the project, it checks that the required input files exist. It stops if the output XPR already exists so an existing generated project is not silently replaced. Generated data stay under `build/`, which `.gitignore` excludes.

## Configure an open project — `setup_fifo.tcl`

Open the desired Vivado project before running this script. It checks that a project is open, selects `basys3_top` as synthesis top, updates compile order, creates or reconfigures `clk_wiz_0`, requests the 100 MHz and 25 MHz outputs, generates IP products, creates the IP synthesis run, prints the IP properties, and launches `synth_1`.

This script mutates the open project and starts synthesis. It does not complete implementation, generate a bitstream, or refresh the archived report files. Check the Tcl Console and Vivado run status after launch; inspect the generated clock ports before proceeding if the IP configuration changed.

## Choosing a path

Use the packaged project at `../vivado/parameterised_asynchronous_fifo.xpr` for direct review. Choose `create_project.tcl` to make a clean project from the repository sources. Choose `setup_fifo.tcl` only when you intentionally want the open project configured and synthesis launched. Do not run both expecting them to update the same project: the create script targets a fresh output directory, while setup acts on the current open project.

If a setup run fails, check for an open project, the required board/device files, the XCI component name, and available Vivado IP generation support. The project-authored Tcl scripts are covered by the license scope in `../NOTICE.md`.
