# Basys 3 bitstream

## Deliverable

`basys3_top.bit` is the FPGA configuration image included with this repository. Vivado generated it for the Basys 3 Artix-7 target `xc7a35tcpg236-1`. Programming the file loads the implemented FIFO demonstration onto a compatible board; it does not provide editable RTL or a reproducible build by itself.

## What is configured

The image contains the top-level `basys3_top` design: the Clocking Wizard, FIFO core, reset and input synchronizers, and Basys 3 switch/LED connections. The files needed to inspect and rebuild that design are stored separately in `rtl/`, `tb/`, `constraints/`, `ip/`, `vivado/`, and `tcl_script/`.

## Programming the board

1. Connect a compatible Basys 3 board and power it.
2. Open Vivado Hardware Manager and connect to the board through the programming cable.
3. Select `basys3_top.bit` as the configuration file and program the FPGA.
4. Exercise the controls described in the root README and check the status/data LEDs.

Programming the FPGA is volatile. The design must be loaded again after power cycling unless the board’s configuration flash is separately programmed. Confirm the target part and board before programming; this file is not intended for other FPGA devices.

## Build provenance and limitations

This is a previously generated output artifact. It may not correspond to later edits to the RTL, XDC, IP configuration, or project file. Rebuild from the current sources before treating it as the bitstream for a new source revision. The root report summary and `../reports/README.md` describe the saved timing/resource data, but those reports are not proof that this binary matches a later source revision.

The bitstream is delivered for demonstration and reference. It is not source code, a current Vivado run, or a substitute for testing the design on the actual board. Its license status is listed in the root `NOTICE.md`.
