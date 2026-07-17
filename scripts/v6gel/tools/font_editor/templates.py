"""Charset presets (templates) for new font documents."""
from __future__ import annotations

import copy
from .glyph_model import FontData

_DEFAULT_PALETTE = [{"x": i * 16, "y": 0} for i in range(16)]

# ---------------------------------------------------------------------------
# gfx_ptrs lists  (matching existing sample fonts)
# ---------------------------------------------------------------------------

ENG_GFX_PTRS = [
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "space", "space", "space", "space", "space",
    "space", "exclamation", "quote", "space", "space", "space", "ampersand", "quote",
    "parent_l", "parent_r", "space", "space", "comma", "dash", "period", "space",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "colon", "space", "space", "space", "space", "question",
    "space", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
]

RUS_GFX_PTRS = [
    "а", "б", "в", "г", "д", "е", "ё", "ж", "з", "и", "й", "к", "л", "м", "н", "о",
    "п", "р", "с", "т", "у", "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ы", "ь", "э", "ю", "я",
    "А", "Б", "В", "Г", "Д", "Е", "Е", "Ж", "З", "И", "И", "К", "Л", "М", "Н", "О",
    "П", "Р", "С", "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "period", "comma", "colon", "parent_r", "parent_l",
    "quote", "exclamation", "question", "dash", "ampersand", "space",
]

MINIMAL_GFX_PTRS = [
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "space",
]


def _make(gfx_ptrs: list, comment: str = "") -> FontData:
    return FontData(
        path_png="art/font.png",
        comment=comment,
        spacing=1,
        color_sample_pos=[0, 0],
        palette=copy.deepcopy(_DEFAULT_PALETTE),
        gfx_ptrs=list(gfx_ptrs),
        gfx=[],
    )


# ---------------------------------------------------------------------------
# Public registry
# ---------------------------------------------------------------------------

TEMPLATES: dict[str, FontData] = {
    "English (Latin)": _make(ENG_GFX_PTRS, "English/Latin font"),
    "Russian (Cyrillic + Latin)": _make(RUS_GFX_PTRS, "Russian/Cyrillic font"),
    "Minimal (a-z, 0-9)": _make(MINIMAL_GFX_PTRS, "Minimal font"),
    "Empty": _make([], ""),
}
