# Plan: Font Editor GUI Tool (v6font-editor)

## TL;DR
Build a PyQt6 GUI tool at `scripts/v6gel/tools/font_editor/` that edits font asset JSON files for the v6gel pipeline. Supports: loading a PNG spritesheet and interactively defining glyph rectangles, auto-detecting glyph bounds, live text preview, and importing system fonts (via Qt/Pillow rendering) into the correct PNG+JSON format. Entry point: `v6font-editor`.

---

## JSON Format + ASM Data Layout

Key fields in font.json:
- `asset_type`: `"font"`
- `path_png`: relative path to art PNG (e.g. `"art/font.png"`)
- `comment`: free string
- `spacing`: int (added to `width` for cursor X advance)
- `backgrount_color_pos`: [x, y] — NOTE: the exporter actually reads `color_sample_pos` (falls back to [0,0]). Tool writes `color_sample_pos`.
- `palette`: array of 16 `{"x": N, "y": N}` sampling positions on the PNG — **NOT read by the font exporter**; written for completeness only
- `gfx_ptrs`: ordered list of glyph names mapping charset positions to glyph entries (repeated "space" = unmapped slots)
- `gfx`: array of glyph defs: `{name, x, y, width, height, offset_x?, offset_y?}`

### JSON glyph field semantics (confirmed from font.py exporter):
- `x`, `y`: top-left pixel position of the glyph crop in the PNG
- `width`: **cursor X advance amount** — how far the cursor moves after this char. NOT the pixel crop width; pixel data cell is always 8px wide (`GLYPH_WIDTH = 8`).
- `height`: pixel crop height in the PNG
- `offset_x`, `offset_y` (both optional, default 0): **local rendering offset only** — the glyph is drawn at (cursor_x + offset_x, cursor_y + offset_y), but the cursor position is **not affected**. Common non-zero examples from eng/font.json: `"j"` offset_y=-3, `"g"` offset_x=-2/offset_y=-2, `"p"` offset_y=-4, `"dash"` offset_y=3, `"quote"` offset_y=6.

### Compiled glyph binary layout (from font.py + v6_text_ex_draw.asm):
```
.word 0                  ; safety pair (for POP B look-ahead)
.byte offset_y           ; signed local Y shift (can be -4, -3, -2, -1, 0, 3, 6…)
.byte offset_x           ; signed local X shift (usually 0, sometimes negative)
; then for each pixel row, stored BOTTOM-TO-TOP (height rows total):
.word [0x00, pixel_byte] ; low byte = 0 (empty shift buffer); high byte = 8 pixels
.byte 0                  ; cursor Y advance = always 0 (cursor Y never changes per char)
.byte width + spacing    ; cursor X advance
```

Draw sequence in text_ex_draw:
1. Save current cursor position (bc)
2. `pop b` → C=offset_y, B=offset_x from glyph header; `dad b` → draw at (cursor_x+offset_x, cursor_y+offset_y)
3. Draw all pixel rows (pop word per row)
4. `pop b` → C=0, B=width+spacing from glyph footer (cursor advance)
5. **Restore** saved cursor (bc), then `dad b` → new cursor = (cursor_x + width + spacing, cursor_y)

The cursor always snaps back to the saved position before advancing — offset_x/offset_y affect only pixels, never the cursor.

**Exporter correction**: when `offset_y < 0`, exporter does `offset_x -= 1` before writing to binary, to compensate for byte-wrap carry in the hardware screen address arithmetic. Transparent to user — the tool stores and edits logical values only.

### PNG color constraints:
- The v6 font renderer is binary: pixel == bg_color_idx → off; else → on. No grays.
- System font PNG: background = black (PIL index 0), foreground = white (index 1), mode `P`
- `color_sample_pos = [0, 0]` always (top-left pixel = background = index 0)
- No color UI exposed anywhere in the tool

---

## File Structure

```
scripts/v6gel/tools/
  __init__.py
  font_editor/
    __init__.py
    __main__.py          # python -m v6gel.tools.font_editor
    app.py               # main() / QApplication
    main_window.py       # QMainWindow: menus, toolbar, splitter layout
    canvas_widget.py     # QGraphicsView: PNG + glyph rects, rubber-band draw, resize handles
    glyph_model.py       # FontData/GlyphEntry dataclasses + QAbstractTableModel
    preview_widget.py    # renders text string from PNG + current glyph data
    system_font_dialog.py  # QFontComboBox → QPainter renders → PIL indexed PNG
    auto_detect.py       # pixel bounding-box scanner
    json_io.py           # read_font_json / write_font_json
    templates.py         # ENG / RUS / Minimal / Empty charset presets
pyproject.toml           # +PyQt6>=6.4 dep, +v6font-editor entry point
```

---

## UI Layout

```
[Menu: File | Import | Help]  [Toolbar: New|Open|Save | Import Font | Zoom|Fit|Grid]
┌─────────────────────────────────────────┬──────────────────────────────────────┐
│  QGraphicsView (PNG canvas)             │  QTabWidget                          │
│  • PNG image displayed 1:1              │                                      │
│  • Glyph rects: colored outlines        │  [Preview]  [Glyphs]  [Charset]  [Settings]
│    + name labels                        │                                      │
│  • Rubber-band drag → new glyph rect    │  Preview tab:                        │
│  • Drag corner/edge → resize            │    ┌──────────────────────────┐      │
│  • Click rect → select in Glyph list   │    │ Type test string here... │      │
│  • Right-click: Rename/Delete/          │    └──────────────────────────┘      │
│    Auto-detect/Set BG sample            │    [rendered glyph preview]          │
│                                         │    Zoom: ──●──────                   │
│  Controls: Zoom in/out/fit              │                                      │
│            Toggle labels / grid         │  Glyphs tab:                         │
│                                         │    Table: name|x|y|w|h|dx|dy        │
│                                         │    ─────────────────────────         │
│                                         │    Property form (selected glyph)    │
│                                         │    Name:[___] x:[_] y:[_]            │
│                                         │    w:[_] h:[_] offset_x:[_] offset_y:[_]
│                                         │    [Add] [Delete] [Auto-detect]      │
│                                         │                                      │
│                                         │  Charset tab: editable gfx_ptrs list │
│                                         │  Settings: spacing, color_sample_pos,│
│                                         │    comment, path_png (palette hidden) │
└─────────────────────────────────────────┴──────────────────────────────────────┘
[Status: filename | N glyphs | cursor (x, y)]
```

---

## Phases (all implemented)

### Phase 1 — Foundation
1. `tools/__init__.py` + `font_editor/__init__.py` stubs
2. `glyph_model.py` — `GlyphEntry` + `FontData` dataclasses + `GlyphTableModel(QAbstractTableModel)`
3. `json_io.py` — `read_font_json` (handles both key spellings) / `write_font_json` (tab-indented, `color_sample_pos`)
4. `templates.py` — ENG / RUS / Minimal / Empty presets (charset + empty glyph list)
5. `pyproject.toml` — `PyQt6>=6.4`, `v6font-editor` entry point

### Phase 2 — Canvas Widget
6. `canvas_widget.py` — `GlyphRectItem(QGraphicsObject)` with 8 resize handles + `FontCanvasWidget(QGraphicsView)`
   - Rubber-band draw on empty area to create glyphs
   - Drag handles to resize; emits `geometry_committed` on release
   - Ctrl+scroll zoom

### Phase 3 — Side Panels
7. `preview_widget.py` — `FontPreviewWidget(QWidget)`: correct cursor logic, zoom slider, cursor-mark toggle
8. `auto_detect.py` — tight pixel bounding-box detection within a search region

### Phase 4 — System Font Dialog
9. `system_font_dialog.py` — `SystemFontDialog(QDialog)`:
   - Font family + size; charset checkboxes (A-Z, a-z, 0-9, punctuation, Cyrillic)
   - Cell padding + glyphs-per-row; live preview
   - Outputs indexed PIL Image (black=0, white=1) + `FontData`

### Phase 5 — Main Window + Entry Points
10. `main_window.py` — `FontEditorMainWindow(QMainWindow)`: all signal wiring, 4 tabs, menus, toolbar, unsaved-changes guard
11. `app.py` + `__main__.py` — entry points

---

## Key Details & Decisions

- **GLYPH_WIDTH=8**: The exporter always samples 8px wide per row. `width` = cursor advance only. Labeled "Width (adv)" in the UI.
- **offset_x / offset_y**: local rendering offset — do NOT affect cursor. Cursor is restored before advancing. Exporter silently does `offset_x -= 1` when `offset_y < 0` (byte-wrap carry fix).
- **color_sample_pos vs backgrount_color_pos**: Tool reads both on load (priority to `color_sample_pos`), always writes `color_sample_pos`.
- **Black/white PNG only**: no color UI. `palette` JSON field is written with defaults but not editable.
- **Scope exclusions**: no pixel editor, no live `v6export`, no undo/redo in v1.

---

## Verification Checklist
1. `pip install -e .` → `v6font-editor` entry point available
2. `v6font-editor samples/del_me_all_assets_here/assets/fonts/eng/font.json` → canvas shows PNG with all 79 glyph rects
3. Type "Hello World" in Preview tab → glyphs render from actual PNG pixel data
4. Drag a glyph rect corner → x/y/w/h updates in property panel
5. "Auto-detect" on a selected glyph → rect tightens to pixel bounds
6. Save → round-trip JSON structurally identical (tab-indented, `color_sample_pos` key)
7. Import system font (A-Z + digits) → PNG saved, glyphs populated, preview works
8. New → template picker → "English" → gfx_ptrs pre-filled
