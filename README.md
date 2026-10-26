<div align="center">

# DOOM on a Kintex-7 FPGA

**Bare-metal DOOM on a MicroBlaze soft CPU, running on the Xilinx KC705 board with 1280×720p60 HDMI output and custom video RTL.**
**47.6 FPS in DOOM's own timedemo benchmark, measured on the board.**

![FPGA](https://img.shields.io/badge/FPGA-Kintex--7%20XC7K325T--2-4338ca)
![Board](https://img.shields.io/badge/board-Xilinx%20KC705-b91c1c)
![CPU](https://img.shields.io/badge/CPU-MicroBlaze%20v11%20%40%20100%20MHz-b45309)
![Video](https://img.shields.io/badge/video-1280x720p60%20HDMI-1d4ed8)
![FPS](https://img.shields.io/badge/timedemo-47.6%20FPS-15803d)
![Timing](https://img.shields.io/badge/timing-all%20constraints%20met-15803d)
![Tools](https://img.shields.io/badge/Vivado-2024.1-334155)

<img src="screenshots/doom_demo1_kc705.gif" alt="DOOM demo1 running on the KC705 firmware" width="640"/>

<sub>demo1 rendered by this firmware (bit-identical to the MicroBlaze build, see <a href="docs/VERIFICATION.md">verification</a>)</sub>

</div>

---

## Highlights

- **47.6 FPS** average in `-timedemo demo1` on real hardware (5-second windows range from 40 to 56 FPS). That's above DOOM's 35 Hz game tic rate, so gameplay runs at full speed. The original Doom-MicroBlaze port on an Arty A7 reached 3–4 FPS.
- **The CPU never touches a pixel after rendering.** A custom video pipeline scans 8-bit palette indices out of DDR3, applies a hardware palette, scales 3×, centres the image in 720p, converts to YCbCr 4:2:2 and drives the ADV7511 HDMI transmitter.
- **The renderer runs from on-chip memory.** DOOM's draw buffer, its column and span drawers, their state and the stack all live in single-cycle LMB BRAM.
- **No Vitis BSP, no XSA dependency.** Start-up code, linker script, drivers, RAM file system and syscalls are written from scratch. The firmware builds with a plain Makefile, using the open GCC toolchain script included here or Vitis' `mb-gcc`.
- **Verified before it touched the board:**
  - all **5,065** demo frames are bit-identical between the MicroBlaze build (in QEMU) and an x86 build;
  - a MicroBlaze-rendered frame pushed through the full 720p RTL pipeline matched a bit-exact model on **921,600 / 921,600** HDMI words;
  - **12** RTL testbenches pass.
- **Timing closed:** post-route WNS **+0.177 ns**, WHS **+0.041 ns**, with all user constraints met.

## Screenshots

These screenshots come from the firmware's built-in screenshot key (**Z**), captured while running the KC705 firmware in QEMU's MicroBlaze emulator, and from frames of the demo1 timedemo. The 720p images show exactly what the KC705 sends over HDMI, computed with the pipeline model that matched the RTL bit for bit. You can capture the same screenshots from your own board over the USB cable (see [Taking screenshots on the board](#taking-screenshots-on-the-board)).

<div align="center">

**What the monitor shows (1280×720, 3× scaled and centred)**

<img src="screenshots/hdmi_720p/02_imps_and_zombies_720p.png" width="860" alt="720p HDMI output"/>

| | | |
|:-:|:-:|:-:|
| <img src="screenshots/menus/01_title_screen.png" width="280"/><br/>Title screen | <img src="screenshots/menus/02_main_menu.png" width="280"/><br/>Main menu | <img src="screenshots/menus/04_skill_select.png" width="280"/><br/>Skill select |
| <img src="screenshots/gameplay/01_e1m1_hangar_start.png" width="280"/><br/>E1M1 Hangar | <img src="screenshots/gameplay/10_imps_and_zombies.png" width="280"/><br/>Imps and zombies | <img src="screenshots/gameplay/11_muzzle_flash.png" width="280"/><br/>Muzzle flash |
| <img src="screenshots/gameplay/08_armor_room.png" width="280"/><br/>Armor room | <img src="screenshots/gameplay/13_uac_door.png" width="280"/><br/>UAC door | <img src="screenshots/gameplay/03_e1m1_automap.png" width="280"/><br/>Automap |
| <img src="screenshots/gameplay/14_stairway_kill.png" width="280"/><br/>Stairway kill | <img src="screenshots/gameplay/07_candelabra_hall.png" width="280"/><br/>Candelabra hall | <img src="screenshots/gameplay/15_dark_hall_zombies.png" width="280"/><br/>Dark hall |

</div>

More are in [`screenshots/`](screenshots/).

## Architecture

<p align="center"><img src="docs/diagrams/system_architecture.png" alt="System architecture" width="100%"/></p>

| Block | Configuration |
|---|---|
| **FPGA** | Kintex-7 XC7K325T-2FFG900 (KC705 Rev 1.6 board files) |
| **CPU** | MicroBlaze v11, 5-stage, 100 MHz, 32 KiB I-cache, 64 KiB write-back D-cache, 8-word lines, branch target cache, MUL64, hardware divider, barrel shifter, pattern compare, reorder instructions |
| **On-chip memory** | 128 KiB LMB BRAM: draw buffer, renderer code and data, stack |
| **External memory** | MIG 7-series DDR3-1600, 64-bit, 1 GiB SODIMM, 512-bit AXI at 200 MHz |
| **Interconnect** | AXI SmartConnect (CPU I/D, scanout DMA, blitter → MIG); AXI4-Lite peripheral bus |
| **Video** | custom `kc705_video_system`: AXI burst DMA → async FIFO → line buffers → 3× scaler → 256-entry palette → BT.601 YCbCr 4:2:2 → ADV7511 → HDMI 1280×720p60 |
| **Peripherals** | UART Lite 115200, AXI IIC (PCA9548 + ADV7511), AXI Timer, GPIO buttons and LED, interrupt controller, custom 2D blitter |
| **Clocks** | 200 MHz SYSCLK → MIG (200 / 100 MHz) → Clocking Wizard 74.25 MHz pixel clock |

The full design write-up is in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), covering:
- [the memory map](docs/diagrams/memory_map.png)
- [clocks and resets](docs/diagrams/clocking_resets.png)
- [one frame, end to end](docs/diagrams/frame_pipeline.png)

The registers are documented in [`docs/REGISTER_MAP.md`](docs/REGISTER_MAP.md).

### Vivado block design

<p align="center"><a href="vivado/block_design/kc705_system.png"><img src="vivado/block_design/kc705_system.png" alt="Vivado IP Integrator block design kc705_system" width="100%"/></a></p>

The block design as Vivado draws it. Click it for full resolution (5133×3000), or see the [PDF](vivado/block_design/kc705_system.pdf). It is built by [`hw/tcl/create_bd.tcl`](hw/tcl/create_bd.tcl).

## Results on the board

| Measurement | Value |
|---|---|
| `-timedemo demo1` | **`timed 5026 gametics in 3698 realtics (47.6 fps)`** |
| Average over the run | 47.8 FPS (5,065 frames in 105.9 s) |
| Live FPS (5 s windows) | 39.7 – 55.8 |
| Present cost per frame (copy + cache flush + palette) | 0.93 ms |
| Waiting for vblank per frame | 0.13 ms |
| Stack high-water mark | 2,172 bytes |
| Post-route timing | WNS +0.177 ns · WHS +0.041 ns · 134,670 endpoints · all constraints met |
| HDMI transmitter | ADV7511 rev 0x14, 38/38 registers written, hot-plug detected |

Analysis and the speed-up techniques are in [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md).

### FPGA resources (post-route, XC7K325T)

| LUTs | Flip-flops | Block RAM | DSP | Power |
|:-:|:-:|:-:|:-:|:-:|
| 26,463 / 203,800 (**13.0 %**) | 28,179 / 407,600 (**6.9 %**) | 62 / 445 (**13.9 %**) | 4 / 840 (**0.5 %**) | **2.99 W** |

The custom video pipeline uses only about 1,500 LUTs and 2 BRAMs. Most of the logic is the DDR3 controller and the AXI interconnect. The per-block breakdown is in [`docs/HARDWARE.md`](docs/HARDWARE.md#implementation-results), and the full reports are in [`vivado/reports/`](vivado/reports/).

<p align="center"><img src="vivado/images/04_implemented_device_timing.png" alt="Vivado implemented design: device floorplan and timing summary" width="100%"/></p>
<p align="center"><sub>The implemented design in Vivado: placement on the XC7K325T and the timing summary. More screenshots are in <a href="vivado/images/"><code>vivado/images/</code></a>.</sub></p>

## Quick start

You need a Xilinx **KC705**, **Vivado/Vitis 2024.1** on Windows, and an HDMI monitor or an HDMI-to-USB capture card. A laptop's HDMI port is an output, so it can't display the board.

The prebuilt bitstream and firmware in [`release/`](release/) mean you can play without building anything:

```powershell
git clone <this repo> && cd final_github_doom
scripts\open_uart.bat COM5                                    # window 1: console + keyboard (your CP210x COM port)
scripts\run_doom.bat release\doom_kc705.elf release\kc705_doom.bit   # window 2: program FPGA + run DOOM
```

To rebuild the hardware yourself, run `scripts\build_hw.bat` (about 1–2 h). It writes `results\release\kc705_doom.bit`, which `scripts\run_doom.bat` uses by default.

Press **p** to play or **b** for the benchmark within 2 seconds of start-up. The full walk-through, including the Linux/WSL firmware build, is in [`docs/BUILD_AND_RUN.md`](docs/BUILD_AND_RUN.md).

### Controls (type in the console window)

| Keys | Action | | Keys | Action |
|---|---|---|---|---|
| **W/↑ S/↓** | forward / back | | **F** | fire |
| **A/← D/→** | turn | | **Space / E** | use (doors, switches) |
| **, .** | strafe | | **1–7** | weapons |
| **R** | toggle run | | **Tab** | automap |
| **Esc / Enter** | menu / select | | **Z** | screenshot over UART |
| **I** | redo the HDMI set-up | | **Y / N** | answer prompts |

KC705 buttons also work: **N/S** move forward/back, **W/E** turn, and **C** fires, uses and selects.

### Taking screenshots on the board

`scripts\open_uart.bat` logs everything it receives to `results\uart_log.txt`. Press **Z**: the next frame is sent as hex over the UART, which takes about 12 seconds at 115200 baud. Then run:

```powershell
python tools\frames_from_log.py results\uart_log.txt screenshots_board 3
```

## Repository layout

| Folder | Contents |
|---|---|
| [`hw/`](hw/) | hardware: [`rtl/`](hw/rtl/) SystemVerilog, [`tb/`](hw/tb/) testbenches, [`tcl/`](hw/tcl/) Vivado build scripts, [`constraints/`](hw/constraints/) XDC, [`ip_repo/`](hw/ip_repo/) packaged IP, [`board_files/`](hw/board_files/) KC705 board definition |
| [`sw/`](sw/) | firmware: [`engine/`](sw/engine/) doomgeneric, [`platform/`](sw/platform/) bare-metal KC705 platform, [`host/`](sw/host/) x86 reference, [`tests/`](sw/tests/) unit tests, `Makefile` |
| [`sim/`](sim/) | simulation and verification scripts (Icarus, Verilator, QEMU) |
| [`tools/`](tools/) | toolchain build, WAD extraction, frame comparison, screenshot and HDMI rendering tools |
| [`vivado/`](vivado/) | Vivado artefacts: reports, block design and diagram, GUI screenshots, routed checkpoint, GUI launcher |
| [`scripts/`](scripts/) | Windows board-day scripts (build, program, run, UART console) |
| [`release/`](release/) | prebuilt bitstream, XSA and firmware ELFs: ready to flash |
| [`screenshots/`](screenshots/) | game screenshots, 720p HDMI renders, verification images, demo GIF |
| [`docs/`](docs/) | architecture, hardware, firmware, performance, verification, registers, build guide, diagrams, Vivado reports, evidence logs |
| [`wad/`](wad/) | place for `doom1.wad` (not tracked) |

## Verification

```sh
sim/verify_all.sh      # Linux: RTL regression, driver test, MicroBlaze-vs-x86 frames, timing run, 720p RTL frame
```

| Check | Result |
|---|---|
| RTL testbenches (Icarus Verilog) | 12 / 12 pass |
| demo1 timedemo, MicroBlaze (QEMU) vs x86, virtual clock | 5,065 / 5,065 frames identical |
| MicroBlaze frame through the 1280×720 RTL pipeline | 921,600 / 921,600 HDMI words exact |
| KC705 drivers vs device models (video, AXI IIC/ADV7511, input) | pass |
| Vivado 2024.1 implementation | all timing constraints met |
| Board | DOOM runs, 47.6 FPS timedemo, HDMI transmitter configured |

Details are in [`docs/VERIFICATION.md`](docs/VERIFICATION.md).

## Credits and licence

- **DOOM** © id Software; the engine was released under the GPL-2.0. The shareware `doom1.wad` is freely distributable and is embedded only in the `release/` ELFs.
- **[doomgeneric](https://github.com/ozkl/doomgeneric)** by ozkl, GPL-2.0, commit `e257a09`. Local patches are in [`sw/engine/KC705_PATCHES.diff`](sw/engine/KC705_PATCHES.diff).
- **[Doom-MicroBlaze](https://github.com/antonangeloff/Doom-MicroBlaze)** by Anton Angeloff inspired this port. None of its HDL or BSP code is used here.
- Xilinx/AMD IP (MicroBlaze, MIG, SmartConnect, AXI peripherals) is generated by Vivado under AMD's licence terms.

The repository is distributed under the **GPL-2.0** ([`LICENSE`](LICENSE)), because the firmware links the GPL DOOM engine.
