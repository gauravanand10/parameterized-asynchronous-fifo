# FIFO and CDC timing references

This folder contains three cropped timing diagrams selected because they explain behaviors used by the asynchronous FIFO: setup/hold and metastability, staged synchronization, and FIFO operation with independent clocks. They are conceptual reference diagrams, not measured waveforms from this repository’s simulations or Vivado implementation.

## Metastability response

![Metastable-state timing diagram](metastable_state_timing.png)

The data transition occurs close to a clock edge and violates the setup or hold window. The first flip-flop may take longer than normal to resolve; the Q output can enter the indeterminate metastable region before settling. The diagram illustrates why asynchronous inputs are not used directly as control signals in the destination clock domain.

## Two-stage synchronization

![Two-level synchronizer timing diagram](two_level_synchronization_timing.png)

The first flip-flop samples the asynchronous signal; a later destination-clock edge samples its output into the second stage. The extra settling interval lowers the likelihood that the metastable behavior reaches downstream logic. This is the conceptual pattern used by the project’s pointer and switch synchronizers; it is not a guarantee of zero metastability risk.

## Asynchronous FIFO transaction example

![Asynchronous FIFO depth-four timing diagram](asynchronous_fifo_length4_timing.png)

This crop shows reset, separate write and read clocks, input/output data, and full/empty transitions for a depth-four example. It demonstrates that writes and reads occur on different clock edges and that the status flags respond to occupancy. It is an illustrative reference sequence, not this repository’s waveform capture; the RTL default FIFO depth is 16 and can be parameterized.

## Source and reuse status

The three crops are from Texas Instruments, *FIFO Architecture, Functions, and Applications*, application report SCAA042A. The images remain third-party material; the project’s license does not grant rights to redistribute them. Attribution is included here, but attribution alone is not permission. Check TI’s applicable reuse terms or obtain permission before publishing or redistributing the crops. See the root `LICENSE` and `NOTICE.md` for the exact scope of the project license.
