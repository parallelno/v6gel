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

| Requirement | Purpose |
|-------------|---------|
| [**v6asm**](https://github.com/parallelno/v6asm) | The assembler used for both the library and exported asset data. |
| **v6fdd** | Packs blobs into a bootable `.fdd` floppy image. Ships in the same [`v6asm`](https://github.com/parallelno/v6asm) workspace. |
| [**Python 3.10+**](https://www.python.org/downloads/) | Runs the asset pipeline. |
| **Pillow** | Python imaging library — decodes source PNGs (`pip install Pillow`). |
| **lhafile** | Reads packed archives used by some source assets (`pip install lhafile`). |
| [**zx0salvador**](https://github.com/emmanuel-marty/salvador/releases/tag/1.4.2) | ZX0 compressor used for format-intrinsic and optional transport compression. Bundled under `tools/zx0/`. |
| [**Devector**](https://github.com/parallelno/Devector) | An emulator  designed to simplify the development process and speed up the work. |
| [**v6emul**](https://github.com/parallelno/v6emul) | A command-line emulator for the Vector-06C Soviet PC. Suitable for quick debug iterations. |

See [Building & Tooling](02-building.md) for exact commands and configuration.
