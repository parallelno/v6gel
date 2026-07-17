"""Read and write font.json files.

The exporter (scripts/v6gel/exporters/font.py) reads ``color_sample_pos``
(falls back to [0,0]).  Older hand-authored JSONs use the typo'd key
``backgrount_color_pos`` — we read both, always write the canonical key.
"""
from __future__ import annotations

import json
import os
from typing import Tuple

from .glyph_model import FontData, GlyphEntry

_DEFAULT_PALETTE = [{"x": i * 16, "y": 0} for i in range(16)]


def read_font_json(path: str) -> Tuple[FontData, str]:
    """Load *path* and return ``(FontData, abs_dir)``.

    ``abs_dir`` is the directory that contains the JSON file — used to resolve
    ``path_png`` and to write the JSON back to the same location.
    """
    with open(path, "r", encoding="utf-8") as fh:
        raw = json.load(fh)

    gfx = [
        GlyphEntry(
            name=g["name"],
            x=int(g["x"]),
            y=int(g["y"]),
            width=int(g["width"]),
            height=int(g["height"]),
            offset_x=int(g.get("offset_x", 0)),
            offset_y=int(g.get("offset_y", 0)),
        )
        for g in raw.get("gfx", [])
    ]

    # Accept both the canonical and the legacy typo'd key
    csp = raw.get("color_sample_pos", raw.get("backgrount_color_pos", [0, 0]))

    data = FontData(
        path_png=raw.get("path_png", "art/font.png"),
        comment=raw.get("comment", ""),
        spacing=int(raw.get("spacing", 1)),
        color_sample_pos=list(csp),
        palette=raw.get("palette", list(_DEFAULT_PALETTE)),
        gfx_ptrs=list(raw.get("gfx_ptrs", [])),
        gfx=gfx,
    )
    return data, os.path.dirname(os.path.abspath(path))


def write_font_json(path: str, data: FontData) -> None:
    """Write *data* to *path* with canonical tab-indented formatting."""
    gfx_list = []
    for g in data.gfx:
        entry: dict = {
            "name": g.name,
            "x": g.x,
            "y": g.y,
            "width": g.width,
            "height": g.height,
        }
        if g.offset_x != 0:
            entry["offset_x"] = g.offset_x
        entry["offset_y"] = g.offset_y
        gfx_list.append(entry)

    out = {
        "asset_type": "font",
        "path_png": data.path_png,
        "comment": data.comment,
        "gfx_ptrs": data.gfx_ptrs,
        "color_sample_pos": data.color_sample_pos,
        "spacing": data.spacing,
        "gfx": gfx_list,
    }
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent="\t", ensure_ascii=False)
