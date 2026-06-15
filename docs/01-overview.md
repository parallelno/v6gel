# 1. Project Overview

## What is v6gel?

**v6gel** is a game engine library for the **Vector-06c**, a Soviet-era 8-bit home
computer based on the i8080 CPU. It gives newcomers a practical, well-factored
foundation for writing **performant** games in classic 8080/Z80-style assembly —
and, where convenient, in **C** (via the [V6C](https://github.com/parallelno/v6llvmc) toolchain) — without having to
reinvent sprite blitting, tile maps, music playback, input handling, or
RAM-disk asset streaming from scratch.

The repository bundles three things:

1. **The runtime library** (`v6/`) — assembly modules you compile into .o file,
   then link with your game: graphics, sound, controls, OS/file I/O, and utilities.
2. **The asset pipeline** (`scripts/`) — Python CLI tools that turn artist-facing
   source files (PNG, Tiled maps, YM music) into compact binary blobs plus the
   assembly metadata that links them into your program.
3. **Samples & tools** (`samples/`, `tools/`) — minimal example builds and the
   external binaries the pipeline drives (assembler, FDD packer, compressor).

## Goals

- **Performance first.** Routines are hand-tuned for the i8080 and the
  Vector-06c's four 8 KB screen buffers; data formats are pre-shifted and
  plane-packed so the runtime does the least possible work per frame.
- **Approachable.** A newcomer can build the sample, swap in their own art, and
  iterate without deep knowledge of the hardware quirks.
- **Asm + C friendly.** The library follows the V6C calling convention so you can
  call engine routines from C or drop down to assembly for hot paths.
- **One-command asset builds.** A single driver converts every asset listed in a
  build config and packs them into a bootable floppy image.

## Repository structure

```
v6/            The runtime engine library (assembly).
  common/        Global constants and macros.
  controls/      Keyboard / joystick input.
  gfx/           Sprites, tiles, backgrounds, decals, tiled images, text.
  misc/          Interrupts, memory utils, palette, RNG, ZX0 decompression.
  os/            CP/M-style file I/O, OS init, RAM-disk control.
  sound/         AY-3-8910 music player ("GigaChad") + 8253 sound effects.
  v6.asm         Library entry point that .includes every module.
  build.bat      Assembles the library to an object file.

scripts/       The asset pipeline (Python 3).
  v6export.py    CLI: export one asset (dispatch by asset_type).
  v6loads.py     CLI: RAM-disk packing + loads.asm + includes/consts.
  build_assets.py Driver: export every asset of a config and build an FDD.
  clear.py       Clean build outputs.
  exporters/     One module per asset type (sprite, font, music, level, ...).
  utils/         Shared helpers (consts, asm generation, image helpers).

assets/        Source assets (PNG art, Tiled maps, YM music, JSON metadata).
samples/       Minimal example projects.
tools/         External tools (AY emulator, ZX0 compressor).
docs/          This documentation hub.
```

## Prerequisites

The only thing you need to install by hand is **Python 3.10+**. The Python
dependencies and every external tool are installed for you:

```bat
pip install -e .            REM Pillow, lhafile (the pipeline's Python deps)
python install_tools.py     REM v6asm, v6fdd, zx0, V6C, emulators -> tools/
```

`install_tools.py` reads [`tools.lock.json`](../tools.lock.json) and downloads
each tool's pinned release for your OS into `tools/` (gitignored). The pipeline
discovers them there automatically — no `PATH` or environment variables needed.
Use `--list` to inspect state or pass tool names to install a subset.

The tools it manages:

| Tool | Purpose |
|------|---------|
| [**v6asm** / **v6fdd**](https://github.com/parallelno/v6asm) | The assembler (engine + asset data) and the bootable-`.fdd` packer. |
| [**zx0** (salvador)](https://github.com/emmanuel-marty/salvador) | ZX0 compressor, used inside some formats and as optional transport compression. |
| [**V6C**](https://github.com/parallelno/v6llvmc) | LLVM/Clang toolchain for compiling C to the Vector-06c. |
| [**Devector**](https://github.com/parallelno/Devector) | GUI emulator/debugger. |
| [**v6emul**](https://github.com/parallelno/v6emul) | Command-line emulator for quick debug iterations. |

To point the pipeline at tools you manage yourself instead, pass `--asm` /
`--packer` / `--v6fdd`, or set the `V6ASM` / `ZX0` / `V6FDD` environment
variables.

See [Building & Tooling](02-building.md) for exact commands and configuration.
