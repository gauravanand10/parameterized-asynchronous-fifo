# Simulation testbenches

The ten Verilog testbenches in this folder are behavioral simulations for the FIFO core, its CDC support modules, and the Basys 3 integration wrapper. Each testbench is self-checking: it reports pass/error messages, tracks failures, and uses a watchdog to stop a stalled run. The testbenches are separate simulation tops; choose one testbench at a time in Vivado.

## FIFO behavior tests

- `async_fifo_tb.v` — baseline FIFO scenario with independent 10 ns and 14 ns clocks. Checks reset flags, writes a sequence, fills the FIFO, confirms a write is blocked when full, reads the sequence back, drains to empty, and confirms a read is blocked when empty.
- `async_fifo_boundary_tb.v` — focused boundary and handshake checks. Fills to capacity, verifies full and rejected writes, drains in order, verifies empty and rejected reads, and exercises a simultaneous accepted read/write to check the old head data is observed.
- `async_fifo_concurrent_tb.v` — producer and consumer operate concurrently under independent clocks while transferring 64 words. Checks accepted write/read counts, ordering and final empty status.
- `async_fifo_stress_tb.v` — longer sequence of fill, drain, and repeated write/read bursts. An expected-data queue checks ordering and integrity across many operations; a watchdog bounds the run.
- `async_fifo_pointer_tb.v` — checks binary pointer increments, Gray-code conversion, one-bit Gray transitions, pointer wraparound, full/empty behavior, and readback across rollover phases.
- `async_fifo_reset_tb.v` — checks FIFO reset initialization and reset behavior across the independent write/read clock domains, including the flags and accepted operations after release.
- `async_fifo_param_tb.v` — runs four parameter configurations in parallel: width/depth 8/4, 8/16, 12/16, and 16/32, with different write/read clock periods. Each sub-checker fills, tests full rejection, drains, and tests empty rejection.

## CDC and board integration tests

- `reset_sync_tb.v` — verifies asynchronous reset assertion and synchronous release after destination-clock edges.
- `sync_2ff_tb.v` — checks the configurable synchronizer variants, stage propagation, and reset behavior.
- `basys3_top_tb.v` — drives the 100 MHz board input clock, waits for Clocking Wizard lock and both reset releases, and checks switch-generated FIFO operations and status/data on LEDs. It fills and drains the 12-bit, depth-16 wrapper instance.

## Running a simulation

Open `../vivado/parameterised_asynchronous_fifo.xpr`, select the desired testbench module as the simulation top, and launch behavioral simulation. The packaged XPR defaults to `basys3_top_tb`. For a fresh project, `../tcl_script/create_project.tcl` adds all ten testbenches to the simulation fileset and sets the wrapper testbench as the default simulation top.

The matching screenshots and `.wcfg` layouts are in `../waveforms/`. A PNG is a static saved view; the WCFG restores signal organization when loaded with a compatible simulation database. These files do not by themselves prove that a current test run passed. Check the simulator transcript for the testbench’s final PASS line and confirm that no ERROR or watchdog message occurred.
