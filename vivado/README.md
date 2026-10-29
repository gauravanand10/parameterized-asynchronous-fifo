# Packaged Vivado project

## Project descriptor and source organization

`parameterised_asynchronous_fifo.xpr` is the portable Vivado project descriptor. It points to the canonical synthesizable Verilog files in `../rtl/`, simulation sources in `../tb/`, board constraints in `../constraints/`, and Clocking Wizard configuration in `../ip/clk_wiz_0/`. The repository intentionally has one maintained RTL copy rather than a second copy in this directory.

The XPR stores project organization and tool settings; it is not a self-contained design archive. The source files it references must remain at their repository-relative locations. Keep those files together when copying or cloning the repository.

## Target, clocking, and top modules

The configured target is the Basys 3 Artix-7 device `xc7a35tcpg236-1`. `basys3_top` is the synthesis top. `basys3_top_tb` is the default simulation top. The wrapper takes the board’s 100 MHz clock and uses Clocking Wizard outputs at 100 MHz and 25 MHz for the FIFO write and read domains. The core defaults and interface are described in `../rtl/README.md`.

## Opening and checking the project

Open the XPR in a compatible Vivado release. If Vivado cannot resolve the Basys 3 board definition, install matching board files or inspect the selected part. Allow Vivado to generate Clocking Wizard output products locally. After opening, check that the Sources view resolves all canonical files and that the Clocking Wizard outputs and lock port match `basys3_top.v`.

## Simulation workflow

The simulation set contains the project testbenches. The XPR initially selects `basys3_top_tb`; to run a focused core test, change the simulation top to the desired module described in `../tb/README.md`, launch behavioral simulation, and inspect both the transcript and waveforms. A saved `.wcfg` from `../waveforms/` restores a signal view when loaded with the matching simulation database; it does not run the test itself.

## Synthesis and implementation workflow

For a clean project generated from source, use `../tcl_script/create_project.tcl`. For an already-open project that should be configured and sent to synthesis, use `../tcl_script/setup_fifo.tcl`. Run implementation separately in Vivado when physical placement, routing, timing reports, or a new `.bit` file are required. Generated run directories, caches, logs, and checkpoints are local build products and are excluded from the repository.

## Result interpretation

Opening the XPR does not prove that the current source passes simulation or implementation. The included `.bit`, Vivado screenshots, waveforms, and reports are saved artifacts. The report guide documents measured slack, FPGA resources, power estimate, and warnings; regenerate all relevant results from one completed build before presenting them as evidence for a changed revision. The project file’s license scope is described in `../NOTICE.md`.
