"""Font preview widget — renders a text string using the current glyph data.

Rendering exactly mirrors the v6 text engine (v6_text_ex_draw.asm):
  • cursor_y is fixed throughout the string (never changes per char).
  • each glyph is painted at (cursor_x + offset_x, cursor_y + offset_y).
  • cursor advances by (width + spacing) in X only.
  • offset_x / offset_y are local and do not carry to the next char.
"""
from __future__ import annotations

import io
from typing import Optional

from PIL import Image
from PyQt6.QtCore import Qt, pyqtSlot
from PyQt6.QtGui import QImage, QPixmap, QPainter, QColor, QPen
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QScrollArea,
    QSlider, QCheckBox, QSizePolicy,
)

from .glyph_model import FontData, GlyphEntry

# Mapping from a typed character to a glyph ``name`` field.
_CHAR_TO_NAME: dict[str, str] = {
    " ": "space",
    "!": "exclamation",
    '"': "quote",
    "'": "quote",
    "&": "ampersand",
    "(": "parent_l",
    ")": "parent_r",
    ",": "comma",
    "-": "dash",
    ".": "period",
    ":": "colon",
    "?": "question",
}
# Letters and digits map to themselves
for _c in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789":
    _CHAR_TO_NAME[_c] = _c
# Cyrillic
for _c in "абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ":
    _CHAR_TO_NAME[_c] = _c


class _PreviewCanvas(QWidget):
    """Bare widget that paints the pre-rendered pixmap, scaled by zoom."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._pixmap: Optional[QPixmap] = None
        self._zoom = 3
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self.setMinimumSize(64, 32)
        self.setStyleSheet("background: #141414;")

    def set_pixmap(self, pm: Optional[QPixmap], zoom: int):
        self._pixmap = pm
        self._zoom = zoom
        if pm:
            self.setMinimumSize(pm.width() * zoom + 8, pm.height() * zoom + 8)
        self.update()

    def paintEvent(self, _event):
        painter = QPainter(self)
        painter.fillRect(self.rect(), QColor(20, 20, 20))
        if self._pixmap and not self._pixmap.isNull():
            z = self._zoom
            scaled = self._pixmap.scaled(
                self._pixmap.width() * z,
                self._pixmap.height() * z,
                Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.FastTransformation,
            )
            painter.drawPixmap(4, 4, scaled)


class FontPreviewWidget(QWidget):
    """Renders a typed text string using the current FontData + PNG.

    Public API:
        set_font_data(data, pil_image) — call when document changes.
        set_text(text)                 — call when user edits the input.
        refresh()                      — force re-render (e.g. after model update).
    """

    def __init__(self, parent=None):
        super().__init__(parent)
        self._font_data: Optional[FontData] = None
        self._pil_image: Optional[Image.Image] = None
        self._text: str = ""

        self._canvas = _PreviewCanvas()
        self._zoom_slider = QSlider(Qt.Orientation.Horizontal)
        self._zoom_slider.setRange(1, 8)
        self._zoom_slider.setValue(3)
        self._zoom_slider.setMaximumWidth(150)
        self._show_cursors_cb = QCheckBox("Show cursor marks")
        self._show_cursors_cb.setChecked(False)

        ctrl = QHBoxLayout()
        ctrl.addWidget(QLabel("Zoom:"))
        ctrl.addWidget(self._zoom_slider)
        ctrl.addWidget(self._show_cursors_cb)
        ctrl.addStretch()

        scroll = QScrollArea()
        scroll.setWidget(self._canvas)
        scroll.setWidgetResizable(False)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addLayout(ctrl)
        layout.addWidget(scroll, 1)

        self._zoom_slider.valueChanged.connect(self._on_zoom_changed)
        self._show_cursors_cb.stateChanged.connect(self._render)

    # -- public API ----------------------------------------------------------

    def set_font_data(self, data: Optional[FontData], pil_image: Optional[Image.Image]):
        self._font_data = data
        self._pil_image = pil_image
        self._render()

    @pyqtSlot(str)
    def set_text(self, text: str):
        self._text = text
        self._render()

    def refresh(self):
        self._render()

    # -- internals -----------------------------------------------------------

    def _on_zoom_changed(self, _value: int):
        self._render()

    def _render(self, *_):
        pm = self._build_pixmap()
        self._canvas.set_pixmap(pm, self._zoom_slider.value())

    def _build_pixmap(self) -> Optional[QPixmap]:
        fd = self._font_data
        pil = self._pil_image
        if not fd or not pil or not self._text:
            return None

        # Background index
        bx, by = int(fd.color_sample_pos[0]), int(fd.color_sample_pos[1])
        bx = max(0, min(bx, pil.width - 1))
        by = max(0, min(by, pil.height - 1))
        try:
            bg_idx = pil.getpixel((bx, by))
        except Exception:
            bg_idx = 0

        glyph_map = {g.name: g for g in fd.gfx}
        spacing = fd.spacing

        # Resolve each char to a GlyphEntry (or None)
        resolved: list[Optional[GlyphEntry]] = []
        for ch in self._text:
            name = _CHAR_TO_NAME.get(ch, ch)
            g = glyph_map.get(name)
            if g is None:
                g = glyph_map.get(ch)
            resolved.append(g)

        if not any(g is not None for g in resolved):
            return None

        valid = [g for g in resolved if g is not None]

        # Vertical extents relative to cursor_y
        above = max((-(g.offset_y) for g in valid if g.offset_y < 0), default=0)
        below = max((g.offset_y + g.height for g in valid), default=10)
        baseline_y = int(above) + 2    # cursor_y in output image coords
        total_h = baseline_y + int(below) + 4

        # Horizontal
        total_w = sum((g.width if g else 4) + spacing for g in resolved) + 6

        out = Image.new("RGBA", (max(total_w, 1), max(total_h, 1)), (20, 20, 20, 255))
        show_cursors = self._show_cursors_cb.isChecked()
        cursor_marks: list[tuple[int, int]] = []

        cursor_x = 2
        for g in resolved:
            if show_cursors:
                cursor_marks.append((cursor_x, baseline_y))

            if g is not None:
                draw_x = cursor_x + g.offset_x
                draw_y = baseline_y + g.offset_y

                # Blit glyph pixels
                for dy in range(g.height):
                    for dx in range(g.width):
                        px, py = g.x + dx, g.y + dy
                        if not (0 <= px < pil.width and 0 <= py < pil.height):
                            continue
                        try:
                            pixel = pil.getpixel((px, py))
                            is_fg = (pixel[:3] != (0, 0, 0) if isinstance(pixel, tuple)
                                     else pixel != bg_idx)
                        except Exception:
                            continue
                        if is_fg:
                            ox, oy = draw_x + dx, draw_y + dy
                            if 0 <= ox < out.width and 0 <= oy < out.height:
                                out.putpixel((ox, oy), (255, 255, 255, 255))

                cursor_x += g.width + spacing
            else:
                cursor_x += 4 + spacing  # placeholder

        # Cursor marks
        if show_cursors:
            for cx, cy in cursor_marks:
                # Green vertical tick at cursor anchor
                for dy in range(-3, 4):
                    oy = cy + dy
                    if 0 <= cx < out.width and 0 <= oy < out.height:
                        out.putpixel((cx, oy), (0, 210, 80, 220))
            # Dashed baseline
            for bx_i in range(0, out.width, 2):
                if 0 <= baseline_y < out.height:
                    cur = out.getpixel((bx_i, baseline_y))
                    if cur[3] < 100:
                        out.putpixel((bx_i, baseline_y), (50, 100, 50, 140))

        # Convert PIL → QPixmap
        data = out.tobytes("raw", "RGBA")
        qimg = QImage(data, out.width, out.height, out.width * 4,
                      QImage.Format.Format_RGBA8888)
        return QPixmap.fromImage(qimg.copy())
