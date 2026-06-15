# v6gel — V6 Game Engine Library for the Vector-06c

> A practical, performance-focused engine library that helps newcomers build
> fast games for the **Vector-06c** 8-bit computer in classic 8080/Z80-style
> assembly — and in **C** via the V6C toolchain.

v6gel bundles a hand-tuned runtime library, a complete asset pipeline that turns
artist-facing source files into compact runtime blobs, and sample projects to
get you started quickly.

## Features

- **Graphics** — pre-shifted, plane-packed sprites, 16×16 tiles, backgrounds,
  decals, tiled images, and both monospaced and proportional text.
- **Sound** — an AY-3-8910 music player ("GigaChad") with per-channel ZX0
  streaming, plus 8253-timer sound effects.
- **Input** — keyboard and joystick reading with edge detection.
- **OS & memory** — CP/M-style file I/O, RAM-disk asset streaming, palette
  fades, RNG, and ZX0 decompression.
- **Asset pipeline** — one command converts every asset of a build config and
  packs them into a bootable floppy image.

## Documentation

📚 **Full documentation lives in the [Documentation Hub](docs/README.md).**

| Guide | What's inside |
|-------|---------------|
| [Project Overview](docs/01-overview.md) | Goals, repository structure, prerequisites. |
| [Building & Tooling](docs/02-building.md) | Build commands and the tools the pipeline needs. |
| [Asset Pipeline & Data Layout](docs/03-asset-pipeline.md) | Source and exported formats, per asset type. |
| [v6gel Library Reference](docs/04-engine-library.md) | The engine's public API. |

## Quick start

Prerequisites: **Python 3.10+**. Everything else (the **v6asm**/**v6fdd**
toolchain, the **zx0** compressor, the **V6C** compiler, and the emulators) is
fetched for you by the bundled installer.

```bat
REM 0. Install the Python deps and the external tools.
pip install -e .
python install_tools.py

REM 1. Build the engine library.
cd v6
build.bat
cd ..

REM 2. Build all assets and pack them into a floppy image.
python scripts\build_assets.py assets\config.json -o build\release ^
    --fdd-template assets\basefdd\rds308.fdd
```

The tools land in `tools/` (gitignored) and are discovered automatically — no
`PATH` or environment setup required. Run `python install_tools.py --list` to
see what is available and what is already installed, or pass tool names (e.g.
`python install_tools.py v6asm zx0`) to install a subset.

The result is `build\release\config.fdd`, ready to boot in a Vector-06c
emulator. For iterating on a single asset, use `v6export` directly — see
[Building & Tooling](docs/02-building.md#one-asset-at-a-time--v6export).


## Repository layout

```
v6/        Runtime engine library (assembly).
scripts/   Asset pipeline (Python): v6export, v6loads, build_assets, exporters.
assets/    Source assets (PNG art, Tiled maps, YM music, JSON metadata).
samples/   Minimal example projects.
tools/     External tools (AY emulator, FDD tool, ZX0 compressor).
docs/       Documentation hub.
```

## License

See [LICENSE](LICENSE).
