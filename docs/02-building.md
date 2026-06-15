# 2. Building & Tooling

This page covers how the build works, what tools the pipeline drives, and the
commands you will actually run.

## Toolchain at a glance

```
art (PNG) ─┐
Tiled maps ┤   v6export        v6loads            v6fdd
YM music  ─┤   (per asset)     (pack + link)      (image)
JSON meta ─┘
            │      │                 │                 │
            ▼      ▼                 ▼                 ▼
         <name>.bin          loads.asm          <config>.fdd
         <name>_meta.asm     code_consts.asm    (bootable floppy)
         <name>.manifest     build_includes.asm
```

| Tool | Role |
|------|------|
| **v6asm** | Assembles the engine library and each generated asset data-asm into a raw blob. |
| **zx0 (`zx0salvador.exe`)** | Compresses data. Used *inside* some formats (music, levels) and, optionally, as a whole-blob transport step. |
| **v6fdd** | Builds the floppy image from a template plus the stored blobs. |
| **v6export.py / v6loads.py / build_assets.py** | The Python orchestration described below. |

The external binary paths are discovered automatically: the pipeline looks for a
tool given by a CLI flag first, then an environment variable (`V6ASM`, `V6FDD`,
`ZX0`), then the bundled `tools/<name>/` directory populated by
`install_tools.py`, and finally your system `PATH`. Override any tool explicitly
with `--asm`, `--packer`, or `--v6fdd` when your layout differs.

## Building the engine library

The library compiles to a single object file you link with your game:

```bat
cd v6
build.bat
```

`build.bat` runs:

```bat
v6asm v6.asm -o out\v6.o -f obj
```

`v6.asm` `.include`s every subsystem (`common`, `controls`, `gfx`, `misc`, `os`,
`sound`) and supplies a custom crt0 startup (`_start`) that initializes the
stack, zeroes `.bss`, installs the interrupt vector, and calls your `main`.

## Building assets

### One asset at a time — `v6export`

```bat
python scripts\v6export.py <asset.json> -o <meta-dir> --bin-dir <bin-dir> [--emit-asm]
```

`v6export` reads the asset's `asset_type`, dispatches to the matching exporter,
and produces three outputs:

- `<NAME>.BIN` — the raw blob (already format-compressed where applicable).
- `<name>_meta.asm` — small assembly file linked into your program: the blob's
  CP/M filename, its length, and exporter-specific pointer/relative-label tables.
- `<name>.manifest.json` — machine-readable record consumed by `v6loads`.

`--emit-asm` additionally keeps the human-readable `<name>_data.asm` for
debugging.

### Linking & RAM-disk packing — `v6loads`

```bat
python scripts\v6loads.py <config.json> --manifest-dir <dir> -o <code-dir>
```

`v6loads` reads the build config's `loads` groups plus every manifest and:

- bin-packs each blob into RAM-disk segments (size-descending, honoring
  per-type alignment and `loaded_after_stack` placement),
- emits `loads.asm` (the `FILE_LOAD_PARAMS` tables and init/uninit routines),
- emits `code_consts.asm`, `build_includes.asm`, `build_consts.asm`, and
  `AUTOEXEC.BAT`.

### Whole build — `build_assets`

The driver does everything for a config in one shot:

```bat
python scripts\build_assets.py assets\config.json -o build\release ^
    --fdd-template assets\basefdd\rds308.fdd
```

For each asset listed in the config it runs `v6export`, optionally transport-
compresses the blob, then runs `v6loads` and finally `v6fdd` to write
`build\release\config.fdd`.

Useful flags:

| Flag | Effect |
|------|--------|
| `-o, --out-dir` | Build output root (default `build/release`). |
| `--emit-asm` | Keep every `*_data.asm` for inspection/diffing. |
| `--transport` | Whole-blob ZX0 compress (`.bin`→`.com`) before storing on the FDD. **Off by default** — blobs are stored raw because their format-intrinsic compression is already applied. |
| `--asm`, `--packer`, `--v6fdd`, `--fdd-template` | Override external tool / template paths. |

Output layout under the build root:

```
build/release/
  meta/    <name>_meta.asm + <name>.manifest.json
  bin/     <NAME>.BIN  (the stored blobs) + AUTOEXEC.BAT
  code/    loads.asm, code_consts.asm, build_includes.asm, build_consts.asm
  config.fdd
```

### Cleaning

```bat
python scripts\clear.py [path] [--all]
```

## Notes & gotchas

- **Even-length blobs.** Every exported blob is padded to an even byte length so
  the runtime can copy data in 16-bit words.
- **v6asm is case-insensitive** for labels and macro names; the exporters mangle
  potentially colliding names (e.g. font glyph labels) accordingly.
- **Text encoding** is handled by v6asm via the `.encoding
  "screencodecommodore"` / `.text` directives (wrapped in a `TEXT` macro) — see
  [Asset Pipeline → Text](03-asset-pipeline.md#text).
