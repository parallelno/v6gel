"""Automatic glyph bounding-box detection from a palette-indexed PNG."""
from __future__ import annotations

from typing import Optional, Tuple

from PIL import Image

Rect = Tuple[int, int, int, int]   # x, y, w, h


def _bg_index(image: Image.Image, color_sample_pos: list) -> int:
    """Return the palette index (or pixel value) of the background."""
    sx, sy = int(color_sample_pos[0]), int(color_sample_pos[1])
    sx = max(0, min(sx, image.width - 1))
    sy = max(0, min(sy, image.height - 1))
    pixel = image.getpixel((sx, sy))
    # For indexed images pixel is an int; for RGB/RGBA it's a tuple.
    if isinstance(pixel, tuple):
        # Return a sentinel that can be compared to future getpixel results.
        return pixel
    return int(pixel)


def _is_fg(pixel, bg) -> bool:
    if isinstance(pixel, tuple) and isinstance(bg, tuple):
        return pixel[:3] != bg[:3]
    if isinstance(pixel, tuple):
        return any(v > 0 for v in pixel[:3])
    return pixel != bg


def detect_bounds(
    image: Image.Image,
    bg_idx,
    search_rect: Rect,
) -> Optional[Rect]:
    """Tightest bounding box of non-background pixels inside *search_rect*.

    Returns ``(x, y, w, h)`` or ``None`` if no foreground pixels found.
    """
    x0, y0, w, h = search_rect
    min_x = min_y = float("inf")
    max_x = max_y = float("-inf")

    for py in range(y0, y0 + h):
        for px in range(x0, x0 + w):
            if not (0 <= px < image.width and 0 <= py < image.height):
                continue
            if _is_fg(image.getpixel((px, py)), bg_idx):
                if px < min_x: min_x = px
                if py < min_y: min_y = py
                if px > max_x: max_x = px
                if py > max_y: max_y = py

    if min_x == float("inf"):
        return None
    return (int(min_x), int(min_y), int(max_x - min_x + 1), int(max_y - min_y + 1))


def detect_bounds_for_glyph(
    image: Image.Image,
    color_sample_pos: list,
    glyph_x: int,
    glyph_y: int,
    search_w: int = 16,
    search_h: int = 16,
) -> Optional[Rect]:
    """Detect tight bounds starting from the approximate glyph location."""
    bg = _bg_index(image, color_sample_pos)
    return detect_bounds(image, bg, (glyph_x, glyph_y, search_w, search_h))
