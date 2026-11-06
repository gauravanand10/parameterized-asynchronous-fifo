# Project image library

The image library groups the visuals by the question they help answer. Architecture drawings explain how the FIFO is organized; timing references explain CDC and queue behavior; Vivado screenshots show selected tool views. Ten waveform captures live in the sibling `../waveforms/` directory. These assets support the written explanations; the RTL and reports remain the authoritative sources for implementation details and measured build results.

## Image groups

| Folder | Contents | Best used to understand |
|---|---|---|
| [`architecture/`](architecture/README.md) | Eight conceptual diagrams: system clocks, datapath, synchronization, pointer crossings, and status detection. | How independently clocked write/read sides exchange pointer state and generate flags. |
| [`timing/`](timing/README.md) | Three cropped reference figures about metastability, two-stage synchronization, and depth-four FIFO activity. | Why asynchronous crossings need synchronization and how FIFO status changes with transactions. |
| [`vivado/`](vivado/README.md) | Eight saved screenshots of Clocking Wizard, elaborated/synthesized logic, FPGA views, and timing summary. | What selected Vivado project and implementation views look like. |
| [`../waveforms/`](../waveforms/README.md) | Ten simulation screenshots, each paired with a Vivado `.wcfg`. | What signals did in the saved simulations for the individual testbenches. |

## How to use the visuals

The root README embeds selected architecture and timing diagrams next to the explanation they support. Open a category README to see its full image set with captions. For an exact interface or behavior, compare the picture with `../rtl/` and `../tb/`; a conceptual drawing may omit implementation details, and a screenshot only records a particular tool state.

## Provenance and maintenance

Filenames use lowercase snake_case and are referenced with relative Markdown paths so GitHub can display them from the repository. When replacing an image, preserve the descriptive filename when its subject is unchanged, revise the caption if the content changes, and refresh the screenshot from the corresponding source/run. Do not use a stale screenshot to imply that a newer RTL revision has already been rebuilt or re-simulated.

The timing figures are third-party material from a Texas Instruments application report. The Vivado captures include vendor interface content. Neither category is covered by the project source license; see [`../NOTICE.md`](../NOTICE.md) and the timing guide before redistributing those assets.
