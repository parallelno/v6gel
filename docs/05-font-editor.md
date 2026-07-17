# 5. Font Editor (`v6font-editor`)

The **v6 Font Editor** is a PyQt6 GUI tool that lets you create and edit
`font.json` asset files for the v6gel asset pipeline. It can work from an
existing hand-drawn PNG spritesheet or generate one from any system font.

## Quick start

```bat
REM Install the Python deps (includes PyQt6)
pip install -e .

REM Open an existing font
v6font-editor samples\del_me_all_assets_here\assets\fonts\eng\font.json

REM Or run as a module
python -m v6gel.tools.font_editor
```

---

## Window layout

```
[Menu: File | Import | Help]  [Toolbar: New | Open | Save | Import Font | Zoom | Fit]
┌───────────────────────────────────┬──────────────────────────────────────────────┐
│  PNG canvas (QGraphicsView)       │  [Preview]  [Glyphs]  [Charset]  [Settings] │
│                                   │                                              │
│  • Each glyph rect shown with     │  Preview tab                                 │
│    colored outline + name label   │    Type test string → glyphs render live     │
│  • Rubber-band drag on empty area │    Zoom slider (1× – 8×)                     │
│    → create new glyph rect        │    "Show cursor marks" toggle                │
│  • Drag corner/edge handle        │                                              │
│    → resize rect (8 handles)      │  Glyphs tab                                  │
│  • Click → select in Glyphs tab   │    Table: name | X | Y | Width | Height |    │
│  • Right-click → context menu     │           Offset X | Offset Y               │
│    (Delete / Auto-detect)         │    Property form + tooltips                  │
│  • Ctrl+scroll → zoom             │    Buttons: Add  Delete  Auto-detect  Detect All
│                                   │                                              │
│                                   │  Charset tab  (gfx_ptrs mapping)             │
│                                   │    Drag to reorder / Add / Remove / Edit     │
│                                   │                                              │
│                                   │  Settings tab                                │
│                                   │    Spacing · BG sample pos · Comment         │
│                                   │    Path PNG (browse button)                  │
└───────────────────────────────────┴──────────────────────────────────────────────┘
[Status: path | N glyphs]
```

---

## Workflow: editing an existing PNG font

1. **Open** `font.json` (File → Open or drag the file path onto the command line).
   The PNG is loaded automatically from `path_png` relative to the JSON.
2. The canvas shows every glyph from the `gfx` array as a colored rectangle.
3. **Select** a glyph by clicking its rect or the row in the Glyphs table.
4. **Adjust** `X`, `Y`, `Width (adv)`, `Height`, `Offset X`, `Offset Y` in the
   property form, or drag the rect's handles directly on the canvas.
5. **Auto-detect**: click "Auto-detect" to tighten the selected glyph's rect to the
   actual pixel bounds (non-background pixels). "Detect All" runs it on every glyph.
6. **Preview** your changes: switch to the Preview tab and type a test string.
7. **Save** (Ctrl+S).

---

## Workflow: importing a system font

1. File → **Import System Font…**  (or toolbar button).
2. Choose the output folder — it will contain `font.json` and `art/font.png`.
3. In the dialog:
   - Pick a **font family** and **size** (pt).
   - Tick the **charset** groups you want: A–Z, a–z, 0–9, Punctuation, Cyrillic.
   - Adjust **cell padding** and **glyphs per row**.
   - The **preview** updates live.
4. Click **OK** — the tool renders glyphs with a black background and white
   foreground, packs them into a grid PNG, and opens the result for editing.
5. Fine-tune glyph bounds with Auto-detect or manual drag, then Save.

---

## Glyph fields reference

| Field | JSON key | Meaning |
|-------|----------|---------|
| Name | `name` | Identifier used in `gfx_ptrs` (e.g. `"A"`, `"space"`, `"exclamation"`) |
| X, Y | `x`, `y` | Top-left pixel of the crop region in the PNG |
| Width (adv) | `width` | **Cursor X advance** after this glyph — NOT the pixel crop width. The data cell is always 8 px wide (`GLYPH_WIDTH`). |
| Height | `height` | Pixel crop height in the PNG |
| Offset X | `offset_x` | Horizontal render displacement from cursor (optional, default 0) |
| Offset Y | `offset_y` | Vertical render displacement from cursor (optional, default 0) |

### Offset semantics (from `v6_text_ex_draw.asm`)

`offset_x` and `offset_y` are **local to the glyph** — they shift where the
pixels are painted but do not move the cursor:

```
Glyph renders at: (cursor_x + offset_x, cursor_y + offset_y)
Cursor then moves to: (cursor_x + width + spacing, cursor_y)
                       ↑ cursor_y NEVER changes per character
```

- `offset_y < 0` → glyph renders **above** the cursor line (ascenders, most normal chars).
- `offset_y > 0` → glyph renders **below** the cursor line (e.g. `"dash"` +3, `"quote"` +6).
- `offset_x` is usually 0; set it when a glyph needs to tuck left (e.g. `"j"` −1).

The tool edits logical values. The exporter silently applies an `offset_x − 1`
correction when `offset_y < 0` to compensate for a byte-wrap carry in the
hardware screen address arithmetic — this is transparent to the user.

---

## Charset tab — `gfx_ptrs`

The **Charset** tab edits `gfx_ptrs`, the ordered list that maps char-code
positions to glyph names. The position index corresponds to the byte value the
game sends to the text renderer (e.g. position 0 = char code 1). Unmapped slots
use `"space"`.

You can drag rows to reorder, double-click to rename, and add/remove entries.
The ENG template matches the Commodore 64 charset layout used by the sample
fonts.

---

## PNG constraints

The v6 font renderer is **binary** (ink / paper). Only two states matter:

- Pixel == background color index → **off** (transparent / paper).
- Pixel != background color index → **on** (ink).

The tool always generates PNGs with **black background (palette index 0)** and
**white foreground (index 1)** in indexed `P` mode. `color_sample_pos` is fixed
at `[0, 0]` (top-left pixel = background).

> **Note:** The `palette` field in `font.json` (16 × `{x, y}` sampling points)
> is written for schema compatibility but is not read by the font exporter.

---

## New font from a template

File → New… shows a template picker:

| Template | `gfx_ptrs` pre-filled with |
|----------|--------------------------|
| English (Latin) | a–z, A–Z, 0–9, common punctuation — C64 layout |
| Russian (Cyrillic + Latin) | а–я, А–Я, digits, punctuation |
| Minimal (a–z, 0–9) | Lowercase + digits only |
| Empty | Blank — define your own charset |

All templates start with no glyph entries (`gfx: []`); add them by drawing
rects on the canvas or importing a system font.

---

## Source files

```
scripts/v6gel/tools/font_editor/
  glyph_model.py       GlyphEntry / FontData dataclasses + QAbstractTableModel
  json_io.py           read_font_json / write_font_json
  templates.py         Charset presets
  auto_detect.py       Pixel bounding-box detection
  preview_widget.py    Live text preview widget
  canvas_widget.py     QGraphicsView canvas + GlyphRectItem
  system_font_dialog.py  System font → PNG + glyph entries dialog
  main_window.py       QMainWindow assembling all panels
  app.py / __main__.py Entry points
```

Related: [design/font-editor-plan.md](../design/font-editor-plan.md) — design notes and decisions.

---

← [Asset Pipeline](03-asset-pipeline.md) | [Documentation Hub](README.md)
