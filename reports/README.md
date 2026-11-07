# Vivado implementation and synthesis results

## What these files are

This folder contains 18 text reports saved from Vivado 2024.1 for the `basys3_top` design targeting the Basys 3 Artix-7 `xc7a35tcpg236-1`. It includes synthesis-stage and routed implementation snapshots. They are evidence of what those saved runs reported; they are not a live result for the current checkout and not every report came from the same run. Compare values within one report snapshot and regenerate the full set from one completed build before making a new release claim.

The results below transcribe the reported values and explain their engineering meaning. In particular, “all specified timing constraints are met” applies only to paths that the XDC and IP constraints actually specify. This project has false-pathed external switch inputs and the methodology report flags missing LED output delays, so the timing report is not a complete board-level I/O sign-off.

## Headline timing result: routed implementation

The implementation timing summary reports positive setup and hold slack and no failing endpoints among the paths it analyzes:

| Check | Worst slack | Total negative slack | Failing endpoints | What the result means |
|---|---:|---:|---:|---|
| Setup | WNS **+6.587 ns** | TNS **0.000 ns** | **0 / 260** | The slowest analyzed setup path has 6.587 ns of margin against its required time. |
| Hold | WHS **+0.049 ns** | THS **0.000 ns** | **0 / 260** | The shortest analyzed hold margin is positive by 49 ps. This is a small, positive margin in this saved run. |
| Clock pulse width | WPWS **+3.000 ns** | TPWS **0.000 ns** | **0 / 128** | No analyzed clock pulse-width endpoint fails; the smallest reported pulse-width margin is 3 ns. |

`WNS`/`WHS` are the worst single-path slacks for setup/hold. `TNS`/`THS` accumulate negative slack across failing endpoints; zero means no negative-slack endpoints were reported for that check. Positive slack is a pass for the analyzed path and constraint. It does not prove behavior outside the constraint model.

### Clock and crossing detail

The reports identify a 100 MHz write clock (`clk_out1_clk_wiz_0`, 10 ns period) and a 25 MHz read clock (`clk_out2_clk_wiz_0`, 40 ns period). The routed intra-clock and inter-clock summaries report:

| Path group | Setup WNS | Hold WHS | Setup / hold failing endpoints |
|---|---:|---:|---:|
| Write clock to itself, 123 endpoints | +6.587 ns | +0.121 ns | 0 / 0 |
| Read clock to itself, 57 endpoints | +35.610 ns | +0.122 ns | 0 / 0 |
| Read clock to write clock, 5 endpoints | +7.531 ns | +0.160 ns | 0 / 0 |
| Write clock to read clock, 29 endpoints | +6.826 ns | +0.049 ns | 0 / 0 |

The smallest hold margin in this table is the write-to-read crossing at +0.049 ns. The CDC report classifies the 29 write-to-read and 5 read-to-write endpoints as safely timed, with zero unsafe endpoints in those rows. It also lists switch-input paths as false-pathed/no-common-primary-clock; synchronizing those inputs in RTL does not make the external switch-to-first-stage delay a timed path.

### Synthesis versus routed hold timing

The synthesis timing summary is not identical to the final routed result. At synthesis, it reports **WHS −0.082 ns**, **THS −0.800 ns**, and **10 failing hold endpoints out of 260**. The two inter-clock directions each show five hold failures at that stage. The routed implementation summaries report **WHS +0.049 ns**, **THS 0.000 ns**, and **zero failing hold endpoints**. This is why both stages are documented: the routed result is the relevant saved implementation snapshot, while the synthesis report records a hold issue before routing-stage optimization. Do not reuse one stage’s value as though it came from the other.

The same summaries report setup WNS of +6.587 ns and zero setup failures. The synthesis report states timing constraints are not met because of the hold failures; the routed summary states its user-specified timing constraints are met. That statement does not clear the separate missing-output-delay methodology warnings below.

## FPGA resource use

The routed utilization report targets the XC7A35T device and records this use:

| Resource | Used | Available | Utilization | Interpretation |
|---|---:|---:|---:|---|
| Slice LUTs | **44** | 20,800 | **0.21%** | 36 LUTs are reported as logic; 8 are LUT memory used as distributed RAM. |
| Slice registers / flip-flops | **104** | 41,600 | **0.25%** | 73 FDCE, 30 FDRE, and 1 FDPE primitive are listed. No latches are used. |
| Distributed RAM | **8 LUTs** | — | — | The small FIFO storage is mapped into LUT RAM in this build. |
| Block RAM tiles | **0** | 50 | **0.00%** | This implementation does not use the device block RAM. |
| DSP slices | **0** | 90 | **0.00%** | The FIFO logic does not infer DSP resources. |
| Bonded I/O | **33** | 106 | **31.13%** | The ports include the board clock, 16 switches, and 16 LEDs. |
| Clock buffers (`BUFGCTRL`) | **3** | 32 | **9.38%** | Clock distribution resources in the reported design. |
| MMCM (`MMCME2_ADV`) | **1** | 5 | **20.00%** | Clocking Wizard clock generation resource. |

These values describe this routed design snapshot, not a general cost estimate for all parameter values. A larger FIFO depth or data width can change storage mapping and utilization. In particular, a small default FIFO fitting in distributed RAM does not imply that a much deeper parameter configuration will also avoid block RAM.

## Power estimate

`power_impl.rpt` reports **0.183 W total on-chip power**, split into **0.111 W dynamic** and **0.072 W device static**, with an estimated junction temperature of **25.9 °C**. The report is a Vivado estimate for its routed design state and modeled activity/environment, not a measurement from a Basys 3 board. It also records that no design power budget was specified, so it cannot be used to claim compliance with a project power target. Re-run power analysis with realistic switching activity and board conditions for a meaningful comparison.

## Design checks and warnings

- `drc_impl.rpt` reports **0 design-rule violations** in its saved fully routed design.
- `route_status_impl.rpt` reports **158 of 158 routable nets fully routed** and **0 nets with routing errors**. Sixty-five nets are marked as not needing routing, and four nets have no loads.
- `methodology_impl.rpt` reports **17 warnings**: one `LUTAR-1` and sixteen `TIMING-18` warnings.
- `LUTAR-1`: a LUT drives asynchronous clear pins in the write-domain reset synchronizer. This is a reset implementation warning that merits review; the report does not say the build failed.
- `TIMING-18`: output-delay constraints are missing for all 16 `LED[15:0]` outputs. The timing summary’s “constraints met” message is limited to paths constrained by the current project. Add board/interface output delays if an external timing requirement applies.
- The XDC declares switch inputs false paths because switches are asynchronous and are synchronized in RTL. This excludes those external input paths from normal setup/hold timing analysis; confirm this exception matches the intended design and review CDC handling.

## Complete file guide

### Clock and CDC reports

- `clocks_impl.rpt` — clocks recognized by Vivado, their periods/frequencies, sources, and generated-clock status. It shows the 100 MHz and 25 MHz domains.
- `clock_interaction_impl.rpt` — timing relationship and path classification between clock domains. Read it with the timing summary and CDC report to understand which crossings are timed.
- `cdc_impl.rpt` — CDC endpoint classification. In this snapshot, 29 write-to-read and 5 read-to-write endpoints are marked safely timed; the switch input paths appear separately as false paths.
- `exceptions_impl.rpt` — timing exceptions applied by the design constraints. This snapshot contains the switch-input false-path exception; exceptions affect what timing paths are analyzed.

### Timing reports

- `timing_synth.rpt` — synthesis timing summary, including the pre-route hold result and unconstrained timing checks.
- `timing_impl.rpt` — implementation timing summary with detailed path information and unconstrained-path reporting.
- `timing_summary_impl.rpt` — implementation timing summary with aggregate, per-clock, and inter-clock slack tables.
- `timing_summary_additional_impl.rpt` — an additional implementation timing summary from a separate report run. Use its values as a separate snapshot even where the headline metrics match.
- `input_timing_impl.rpt` — selected maximum-delay paths from top-level input ports.
- `output_timing_impl.rpt` — selected maximum-delay paths to top-level outputs. The missing LED output-delay warning limits what these paths can establish.
- `hold_paths_synth.rpt` — selected synthesis-stage minimum-delay paths with negative slack, useful for inspecting the hold issue before implementation.
- `hold_paths_impl.rpt` — selected routed minimum-delay paths for post-implementation hold inspection.

### Implementation and design reports

- `drc_impl.rpt` — design-rule check results; this snapshot lists zero violations.
- `methodology_impl.rpt` — Vivado methodology checks; this snapshot contains the reset and output-delay warnings described above.
- `route_status_impl.rpt` — completion counts for placement/routing nets and any routing errors.
- `utilization_impl.rpt` — resource count and percentage for LUTs, registers, memory, DSP, I/O, and clocking resources.
- `io_impl.rpt` — port-to-package-pin assignments, I/O standards, banks, and electrical properties.
- `power_impl.rpt` — estimated on-chip power and temperature with the run’s modeled activity assumptions.

## Using the reports responsibly

For a new revision, open the project in Vivado, confirm the current device and constraints, run synthesis and implementation to completion, and regenerate the timing, CDC, methodology, utilization, I/O, routing, DRC, and power reports from that same run. Review the actual paths behind a slack number and confirm unconstrained ports are intentional. The reports here are useful project evidence, but they are saved snapshots and are not a guarantee that changed RTL or a different Vivado environment will reproduce the same results.
