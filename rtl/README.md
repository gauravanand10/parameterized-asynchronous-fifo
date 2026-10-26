# RTL design

This folder contains the four canonical synthesizable Verilog modules used by the project. The Vivado XPR references these files directly, so there is one maintained RTL source rather than a second copy under `vivado/`.

## FIFO architecture

`async_fifo.v` is a dual-clock FIFO core with a parameterized word width, power-of-two depth, and pointer synchronizer length. The write and read domains each own a binary pointer for storage addressing and a Gray-coded pointer for crossing into the other domain. A binary-to-Gray conversion is applied to the pointer state; a configurable multi-stage synchronizer transfers the remote Gray pointer. The write side compares its next Gray pointer against the synchronized read pointer to detect full, and the read side compares its next Gray pointer against the synchronized write pointer to detect empty.

An operation is accepted only when requested and permitted: `w_accept` is `w_en && !w_full`; `r_accept` is `r_en && !r_empty`. Pointer movement and storage writes follow accepted operations. The read-data port is combinational from the current read address; its contents should be treated as valid only while the FIFO is not empty. The core uses separate active-low resets for the write and read domains, supplied by the wrapper or the testbench.

The default core parameters are `DATA_WIDTH=8`, `FIFO_DEPTH=16`, and `SYNC_STAGES=2`. Depth must be a power of two and at least two; width must be positive; synchronizer stages must be at least two. The Basys 3 wrapper default is 12-bit data and depth 16.

## Modules

- `async_fifo.v` — storage, write/read acceptance, binary and Gray pointers, pointer crossings, full/empty flags, and data output.
- `basys3_top.v` — board-level integration. It instantiates the Clocking Wizard, creates domain-specific resets, synchronizes switch data/control inputs, detects switch transitions as single requests, connects the FIFO, and maps status/data to LEDs.
- `reset_sync.v` — asynchronous active-low assertion and synchronous two-clock-edge release of reset in one destination domain. The wrapper uses separate instances for the write and read clocks.
- `sync_2ff.v` — parameterized multi-bit synchronizer with selectable stage count and optional asynchronous reset; the RTL marks the stages with `ASYNC_REG` for Vivado recognition.

## Interface and integration

The core interface is split into write-side signals (`wclk`, `wrst_n`, `w_en`, `w_data`, `w_full`, `w_accept`) and read-side signals (`rclk`, `rrst_n`, `r_en`, `r_data`, `r_empty`, `r_accept`). The board wrapper uses the 100 MHz input to produce a 100 MHz write clock and 25 MHz read clock. Its switch and LED mapping is documented in the root README and exercised by `tb/basys3_top_tb.v`.

## Verification and implementation notes

The ten testbenches in `../tb/` cover normal transactions, full/empty boundaries, independent-clock concurrency, reset sequencing, pointer/Gray-code behavior, parameter combinations, stress traffic, synchronizer behavior, and the board wrapper. The saved Vivado reports show the previously implemented design’s timing and resource results; they do not guarantee a future rebuild will match. In particular, see the report guide for the synthesis-stage hold violations, routed timing result, missing LED output delays, and reset methodology warning.
