# Project notice and license scope

The project’s original source materials listed below are made available under the CERN Open Hardware Licence Version 2 - Permissive (`CERN-OHL-P-2.0`). The complete, unmodified license text is in [`LICENSE`](LICENSE). This is a permissive hardware-design license: it allows use, modification, and redistribution of covered source and products subject to the license terms.

## Covered project source

The license applies only to original project-authored material in these locations:

- `rtl/*.v` — FIFO core, board wrapper, reset synchronizer, and data synchronizer.
- `tb/*.v` — project simulation testbenches.
- `constraints/basys3_top.xdc` — board-specific pin and timing constraint source.
- `tcl_script/*.tcl` — project setup and recreation scripts.
- `vivado/parameterised_asynchronous_fifo.xpr` — project configuration, to the extent it is original project-authored material.
- `ip/clk_wiz_0/clk_wiz_0.xci` — project Clocking Wizard settings, not the Xilinx IP implementation.
- Original explanatory text in the project Markdown guides.

## Materials outside this license

This license does not grant rights to third-party or vendor-owned materials. In particular, it does not cover:

- Cropped timing diagrams in `images/timing/`, which are attributed to Texas Instruments and remain subject to TI’s rights and reuse terms.
- Vivado interface screenshots, vendor marks or logos, or Xilinx/AMD software and IP.
- Generated implementation reports in `reports/`, waveform screenshots/configuration files in `waveforms/`, or the prebuilt bitstream in `bitstream/`.
- Any other content not identified above as original project-authored source.

No endorsement by CERN, Xilinx/AMD, Digilent, or Texas Instruments is implied. The project license does not replace third-party permissions. For report interpretations and build-result limitations, see [`reports/README.md`](reports/README.md).
