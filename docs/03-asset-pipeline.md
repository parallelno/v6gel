# 3. Asset Pipeline & Data Layout

The pipeline turns **artist-facing source files** into **compact runtime blobs**
plus the **assembly metadata** that links them into your game. This page
describes the source formats, the exported formats, and each asset type.

## Source vs exported

| Source (authoring) | Exported (runtime) |
|--------------------|--------------------|
| PNG art + JSON metadata | `<NAME>.BIN` raw blob |
| Tiled `.tmj` / `.tsx` maps | `<name>_meta.asm` (linked into the program) |
| YM (`.ym`) chip-music dumps | `<name>.manifest.json` (consumed by `v6loads`) |

Every asset's source JSON declares an `"asset_type"`, which selects the exporter.
Blobs are streamed from a **RAM disk** at run time; the `_meta.asm` provides the
CP/M filename, length, and the pointer/relative-label tables the engine needs to
locate frames, glyphs, rooms, etc. inside the blob once it is loaded.

### The build config

A top-level config (`asset_type: "config"`, e.g. `assets/config.json`) ties a
build together. Key fields:

| Field | Meaning |
|-------|---------|
| `consts` | Build-wide constants (e.g. `DEBUG`, `LOCALIZATION`). |
| `loads` | Named groups of asset paths to load together (e.g. `permanent`, `menu`, `level0`). Drives RAM-disk packing. |
| `loaded_after_stack` | Asset types placed in the high RAM-disk segment (after the stack). |
| `types_alignment` | Per-type byte alignment (e.g. `music: 256`). |
| `ram_disk_reserve` | Banks/lengths reserved from packing. |
| `basefdd_path` | Template floppy image used by `v6fdd`. |

## Common blob conventions

- **Plane-packed graphics.** The Vector-06c screen is organized as bit planes;
  graphics are pre-converted into the plane order the blitters expect.
- **Pre-shifting.** Sprites can be stored at several horizontal sub-positions so
  the runtime avoids per-frame bit shifting.
- **Format-intrinsic compression.** Some formats embed ZX0 compression *inside*
  the blob (see Music and Level data). This is independent of the optional
  whole-blob `--transport` compression done by the build driver.
- **Even length.** Blobs are padded to an even number of bytes for 16-bit copies.

## Asset types

### Sprite (`sprite`)
3-plane masked sprites with optional pre-shifting. Source: a PNG sheet plus a
JSON describing `sprites` (name, x/y, width/height, offsets, mask box),
`anims` (frame lists, loop flags), `preshifted_sprites`, and `mask`. Exported as
packed plane data with per-frame relative labels and animation pointer tables.
Drawn with `sprite_draw_vm` and friends; initialized with
`sprite_init_meta_data`.

### Background (`back`)
Full-screen, non-animated 4-plane images without an alpha channel. Drawn with
`draw_back_v`.

### Decal (`decal`)
Masked 4-plane sprites (16×N) with alpha, plus named pointer lists. Drawn with
`draw_decal_v`.

### Font (`font`)
Character glyphs for the proportional text renderer. Glyph labels are
Unicode-aware and **mangled** to avoid case-insensitive collisions in v6asm
(e.g. uppercase `A` → `cap_a`). The byte layout is unaffected (only relative
offsets matter). Used by `text_ex_init_font` / `text_ex_draw`.

### Palette (`palette`)
Vector-06c 16-color palettes, plus optional fade tables. Applied with
`set_palette` / the palette-fade utilities.

### Music (`music`)
AY-3-8910 register streams extracted from a YM (`.ym`) dump. Each of the AY
register channels is **ZX0-compressed independently** and streamed at run time
through a 256-byte window by the "GigaChad" player. The per-channel compression
is part of the *format* — `v6_gc_update` decompresses a slice each frame.
Initialized per song with `v6_gc_init_song` then `v6_gc_start`.

### Level data (`level_data`)
Per-room tile/teleport data plus resource and container instance tables. Each
room's data is **ZX0-compressed per room**. Exported with relative room pointer
tables.

### Level graphics (`level_gfx`)
A palette plus the 16×16 level tile bitmaps. Tiles are drawn with
`draw_tile_16x16`.

### Tiled image — data (`tiled_img_data`)
RLE-packed tile-index streams per layer (one byte stream of indices into the
tiled-image gfx, run-length encoded with a repeater code). Loaded with
`tiled_img_init_idxs` and drawn with `tiled_img_draw`.

### Tiled image — graphics (`tiled_img_gfx`)
8×8 tile bitmaps (no mask) referenced by the index streams above. Loaded with
`tiled_img_init_gfx`.

### Text (`text_eng`, `text_rus`) {#text}
Localized string blocks. Each named block stores a screen position and one or
more lines terminated by control codes (`_LINE_BREAK_` `0x6A`, `_PARAG_BREAK_`
`0xFF`, `_EOD_` `0`). Localization is selected by the asset type.

**Encoding note.** English text is translated to the engine's screen codes
**in the exporter** (`@`→0, letters→1–26, the `0x20–0x3F` range maps to itself).
Although v6asm offers `.text "screencodecommodore"`, its current implementation
mis-encodes the `0x21–0x3F` range (it subtracts `0x20`, so `'2'` becomes `0x12`
instead of `0x32`), which does not match the project's font and golden data. The
exporter therefore performs the translation directly until that assembler bug is
fixed, at which point the `.text` directive can be used instead. Russian text
uses a custom charset table and is emitted as raw bytes.

## Adding a new asset

1. Author the source (PNG/Tiled/YM) and a JSON with the right `asset_type`.
2. Add the JSON path to the appropriate `loads` group in your build config.
3. Run `build_assets.py` (or `v6export` for a single asset during iteration).
4. Reference the generated labels from your game code (the `_meta.asm` exposes
   the filename pointer, length, and relative tables; `loads.asm` exposes the
   load address constants).
