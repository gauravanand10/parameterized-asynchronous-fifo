# Basys 3 constraints

## Purpose and target

`basys3_top.xdc` maps the logical top-level ports to the Basys 3 FPGA package and assigns electrical standards. The project target is the Artix-7 part `xc7a35tcpg236-1` in the CPG236 package.

## Pin assignment groups

- **Clock input:** `CLK100MHZ` is assigned to package pin W5 with `LVCMOS33`.
- **Slide switches:** all 16 inputs `SW[15:0]` are assigned to their Basys 3 package pins with `LVCMOS33`.
- **LED outputs:** all 16 outputs `LED[15:0]` are assigned to their Basys 3 package pins with `LVCMOS33`.
- **Configuration voltage:** the XDC sets the configuration bank voltage properties for the board’s 3.3 V configuration.

The XDC does not define a duplicate clock period for `CLK100MHZ`: the Clocking Wizard IP contributes the input-clock constraint and generated-clock information. This keeps the project’s clock definitions consistent with the IP settings.

## Asynchronous inputs and timing coverage

The final XDC statement marks paths from `SW[*]` as false paths. The manual switches are asynchronous external inputs; the RTL synchronizes them before using them. The false-path exception excludes the external switch-to-first-stage paths from ordinary setup/hold analysis. It must not be interpreted as a claim that asynchronous switch signals can be used directly without synchronization.

The saved methodology report flags missing output-delay constraints on all 16 LEDs. The current timing report therefore describes constrained paths, not a full external timing contract for a display or downstream device. If the design is adapted to a system with defined LED/output timing requirements, add appropriate output-delay constraints and re-run timing analysis.

## Verification and reuse

`reports/io_impl.rpt` records the package locations and I/O standards from a saved build. Compare it with this XDC and the board pinout when reviewing the project. These pins are board-specific; do not reuse them for another FPGA/package or board revision without checking the manufacturer’s electrical and pin-assignment documentation. The XDC is included in the project license scope described by `../NOTICE.md`.
