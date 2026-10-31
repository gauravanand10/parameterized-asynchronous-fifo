# Architecture and logic diagrams

These eight diagrams provide a visual route through the FIFO design: first the two clock domains and datapath, then how pointer state crosses between domains, and finally how the full and empty flags are derived. The diagrams are explanatory documentation. For exact port names, parameters, and reset behavior, use the canonical Verilog modules in `../../rtl/`.

## System and datapath

### Dual-clock architecture

![Dual-clock asynchronous FIFO architecture](dual_clock_async_fifo_architecture.png)

The write and read sides run on independent clocks. Each side owns its pointer and receives a synchronized Gray-coded copy of the other side’s pointer for local status generation.

### Basys 3 datapath

![Basys 3 asynchronous FIFO datapath](basys3_async_fifo_datapath_diagram.png)

Shows the board-level path from switches and clock/reset logic through the FIFO to LEDs, including the wrapper around the reusable FIFO core.

### Parameterized FIFO block

![Parameterized asynchronous FIFO block diagram](parameterised_async_fifo_block_diagram.png)

Shows the FIFO’s external write/read controls, two clocks and resets, status flags, acceptance signals, and data ports. The actual defaults are documented in `../../rtl/README.md`.

## Clock-domain crossing

### Two-flop synchronizer

![Two-flop synchronizer](two_flip_flop_synchronizer_diagram.png)

Illustrates a common synchronizer chain. A synchronizer reduces the chance that metastability propagates to downstream logic; it does not make the probability of metastability mathematically zero.

### Write pointer crossing

![Write pointer synchronization](write_pointer_synchronization_diagram.png)

Shows the write pointer converted to Gray code in the write domain and synchronized into the read domain.

### Read pointer crossing

![Read pointer synchronization](read_pointer_synchronization_diagram.png)

Shows the read pointer converted to Gray code in the read domain and synchronized into the write domain.

## Full and empty detection

### Full and empty logic, view 1

![FIFO full and empty detection logic](fifo_full_empty_detection_logic_01.png)

Highlights local next-pointer generation, Gray conversion, synchronized remote pointer inputs, and the full/empty comparisons.

### Full and empty logic, view 2

![Alternate FIFO full and empty logic](fifo_full_empty_detection_logic_03.png)

A second presentation of the same status-generation topic. The implemented core in `async_fifo.v` uses the standard Gray-pointer comparisons: full detection inverts the two most significant bits of the synchronized read pointer comparison; empty detection compares the next read Gray pointer with the synchronized write Gray pointer.

## Relating these images to the source

`async_fifo.v` implements storage, accepted-operation gating, binary and Gray pointers, synchronizers, and status flags. `sync_2ff.v` provides the configurable synchronizer; `reset_sync.v` handles reset release. `basys3_top.v` adds board controls and output mapping. See the root README for a signal-level overview and the RTL guide for module details.
