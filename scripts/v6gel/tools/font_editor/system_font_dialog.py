"""Dialog for importing a system font and generating font.png + glyph entries.

The dialog renders glyphs with QPainter (black bg, white fg) into a packed
grid PNG, then converts to PIL indexed mode P (index 0 = black, index 1 = white).
No color controls are exposed — the v6 font renderer is purely binary.
"""
from __future__ import annotations

import io
import os
from typing import Optional

from PIL import Image as PILImage
from PyQt6.QtCore import QBuffer, QIODevice, Qt
from PyQt6.QtGui import QColor, QFont, QFontMetrics, QImage, QPainter, QPen
from PyQt6.QtWidgets import (
    QCheckBox,
    QDialog,
    QDialogButtonBox,
    QFontComboBox,
    QFormLayout,
    QGroupBox,
    QLabel,
    QMessageBox,
    QSpinBox,
    QVBoxLayout,
)

from .glyph_model import FontData, GlyphEntry
from .templates import ENG_GFX_PTRS


def _build_gfx_ptrs(chars: list[tuple[str, str]]) -> list[str]:
    """Map imported Latin glyphs to the engine's C64-compatible charset."""
    names = {name for _, name in chars}
    gfx_ptrs = [name if name in names else "space" for name in ENG_GFX_PTRS]

    # Cyrillic has no C64-compatible code-page mapping, so keep its selected
    # order after the standard Latin table.
    gfx_ptrs.extend(name for _, name in chars if name not in ENG_GFX_PTRS)
    return gfx_ptrs


class SystemFontDialog(QDialog):
    """Let the user pick a system font and generate a <name>.png + FontData."""

    def __init__(self, out_dir: str, png_stem: str, parent=None):
        super().__init__(parent)
        self.out_dir = out_dir
        self._png_stem = png_stem   # base name without extension, e.g. "my_font"
        self._result_data: Optional[FontData] = None
        self._result_image: Optional[PILImage.Image] = None

        self.setWindowTitle("Import System Font")
        self.setMinimumWidth(480)

        # -- Font selection --------------------------------------------------
        self._font_combo = QFontComboBox()
        self._size_spin = QSpinBox()
        self._size_spin.setRange(4, 24)
        self._size_spin.setValue(8)

        font_form = QFormLayout()
        font_form.addRow("Font family:", self._font_combo)
        font_form.addRow("Size (pt):", self._size_spin)

        # -- Charset checkboxes ----------------------------------------------
        self._cb_upper  = QCheckBox("Uppercase  A – Z")
        self._cb_lower  = QCheckBox("Lowercase  a – z")
        self._cb_digits = QCheckBox("Digits  0 – 9")
        self._cb_punct  = QCheckBox("Punctuation  ! . , - : ? ( ) \" & space")
        self._cb_cyrillic = QCheckBox("Cyrillic  а–я  А–Я")
        for cb in (self._cb_upper, self._cb_lower, self._cb_digits, self._cb_punct):
            cb.setChecked(True)

        charset_box = QGroupBox("Charset")
        cb_layout = QVBoxLayout(charset_box)
        for cb in (self._cb_upper, self._cb_lower, self._cb_digits,
                   self._cb_punct, self._cb_cyrillic):
            cb_layout.addWidget(cb)

        # -- Layout options --------------------------------------------------
        self._padding_spin = QSpinBox()
        self._padding_spin.setRange(0, 16)
        self._padding_spin.setValue(2)
        self._per_row_spin = QSpinBox()
        self._per_row_spin.setRange(1, 64)
        self._per_row_spin.setValue(16)

        opt_form = QFormLayout()
        opt_form.addRow("Cell padding (px):", self._padding_spin)
        opt_form.addRow("Glyphs per row:", self._per_row_spin)

        # -- Preview ---------------------------------------------------------
        self._preview_label = QLabel()
        self._preview_label.setMinimumSize(384, 80)
        self._preview_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._preview_label.setStyleSheet(
            "background: black; border: 1px solid #444; color: white;"
        )
        self._preview_label.setText("(preview)")

        # -- Buttons ---------------------------------------------------------
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self._on_accept)
        buttons.rejected.connect(self.reject)

        # -- Main layout -----------------------------------------------------
        layout = QVBoxLayout(self)
        layout.addLayout(font_form)
        layout.addWidget(charset_box)
        layout.addLayout(opt_form)
        layout.addWidget(QLabel("Preview:"))
        layout.addWidget(self._preview_label)
        layout.addWidget(buttons)

        # -- Wire changes to preview update ----------------------------------
        self._font_combo.currentFontChanged.connect(self._update_preview)
        self._size_spin.valueChanged.connect(self._update_preview)
        for cb in (self._cb_upper, self._cb_lower, self._cb_digits,
                   self._cb_punct, self._cb_cyrillic):
            cb.stateChanged.connect(self._update_preview)
        self._padding_spin.valueChanged.connect(self._update_preview)
        self._per_row_spin.valueChanged.connect(self._update_preview)

        self._update_preview()

    # -- Public results ------------------------------------------------------

    @property
    def result_data(self) -> Optional[FontData]:
        return self._result_data

    @property
    def result_image(self) -> Optional[PILImage.Image]:
        return self._result_image

    # -- Internals -----------------------------------------------------------

    def _get_charset(self) -> list[tuple[str, str]]:
        """Return list of (display_char, glyph_name) pairs."""
        chars: list[tuple[str, str]] = []
        if self._cb_upper.isChecked():
            chars += [(c, c) for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
        if self._cb_lower.isChecked():
            chars += [(c, c) for c in "abcdefghijklmnopqrstuvwxyz"]
        if self._cb_digits.isChecked():
            chars += [(c, c) for c in "0123456789"]
        if self._cb_punct.isChecked():
            chars += [
                ("!", "exclamation"), (".", "period"), (",", "comma"),
                ("-", "dash"), (":", "colon"), ("?", "question"),
                ("(", "parent_l"), (")", "parent_r"), ('"', "quote"),
                ("&", "ampersand"), (" ", "space"),
            ]
        if self._cb_cyrillic.isChecked():
            for c in "абвгдеёжзийклмнопрстуфхцчшщъыьэюя":
                chars.append((c, c))
            for c in "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ":
                chars.append((c, c))
        if not any(name == "space" for _, name in chars):
            chars.append((" ", "space"))
        return chars

    def _render_to_pil(self) -> tuple[PILImage.Image, list[GlyphEntry]]:
        chars = self._get_charset()
        if not chars:
            return PILImage.new("P", (8, 8)), []

        qfont = QFont(self._font_combo.currentFont().family(),
                  self._size_spin.value())
        qfont.setStyleStrategy(QFont.StyleStrategy.NoAntialias)
        fm = QFontMetrics(qfont)
        padding = self._padding_spin.value()
        per_row = self._per_row_spin.value()

        # Uniform cell size: widest advance + padding, full font height + padding
        max_adv = max(fm.horizontalAdvance(c) for c, _ in chars)
        cell_w = max_adv + 2 * padding
        cell_h = fm.height() + 2 * padding
        draw_h = cell_h - 2 * padding   # inner draw-rect height = fm.height()

        # Baseline position within each cell (Qt y-down).
        baseline_in_cell = padding + fm.ascent()

        n = len(chars)
        cols = min(per_row, n)
        rows = (n + cols - 1) // cols
        img_w = cols * cell_w
        img_h = rows * cell_h

        # Render to a black QImage with white text
        qimg = QImage(img_w, img_h, QImage.Format.Format_RGB32)
        qimg.fill(QColor(0, 0, 0))
        painter = QPainter(qimg)
        painter.setFont(qfont)
        painter.setPen(QColor(255, 255, 255))

        cell_info: list[tuple[int, int, int]] = []  # cell origin x, y, advance
        for idx, (char, name) in enumerate(chars):
            col_i = idx % cols
            row_i = idx // cols
            cell_x = col_i * cell_w
            cell_y = row_i * cell_h
            adv = fm.horizontalAdvance(char)

            painter.drawText(cell_x + padding, cell_y + baseline_in_cell, char)
            cell_info.append((cell_x, cell_y, adv))
        painter.end()

        # Convert QImage → PIL indexed P mode (0=black bg, 1=white fg)
        buf = QBuffer()
        buf.open(QIODevice.OpenModeFlag.WriteOnly)
        qimg.save(buf, "PNG")
        buf.close()
        pil_rgb = PILImage.open(io.BytesIO(bytes(buf.data()))).convert("L")
        indexed = PILImage.new("P", pil_rgb.size)
        pal = [0] * 768
        pal[3:6] = [255, 255, 255]
        indexed.putpalette(pal)
        indexed.putdata([1 if p else 0 for p in pil_rgb.getdata()])

        # Auto-detect tight pixel bounds for each glyph and derive offset_y.
        from .auto_detect import detect_bounds
        entries: list[GlyphEntry] = []
        for (cell_x, cell_y, adv), (char, name) in zip(cell_info, chars):
            result = detect_bounds(indexed, 0,
                                   (cell_x, cell_y, cell_w, cell_h))
            if result:
                gx, gy, gw, gh = result
                # offset_y = baseline_qt − glyph_bottom_qt
                # baseline_qt = cell_y + baseline_in_cell
                # glyph_bottom_qt = gy + gh
                offset_y = (cell_y + baseline_in_cell) - (gy + gh)
                entries.append(GlyphEntry(
                    name=name,
                    x=gx,
                    y=gy,
                    width=max(1, gw),  # tight ink width; the engine adds global spacing
                    height=max(1, gh),
                    offset_y=int(round(offset_y)),
                    pixel_width=gw,
                ))
            else:
                # Invisible glyph (e.g. space) keeps its font-metric advance.
                entries.append(GlyphEntry(
                    name=name,
                    x=cell_x + padding,
                    y=cell_y + padding,
                    width=max(1, adv),
                    height=1,
                    pixel_width=0,
                ))
        return indexed, entries

    def _update_preview(self, *_):
        try:
            img, entries = self._render_to_pil()
            buf = io.BytesIO()
            img.save(buf, format="PNG")
            buf.seek(0)
            from PyQt6.QtGui import QPixmap
            pm = QPixmap()
            pm.loadFromData(buf.read())
            painter = QPainter(pm)
            warning_pen = QPen(QColor(230, 50, 50), 1)
            painter.setPen(warning_pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            for glyph in entries:
                if glyph.pixel_width > 8:
                    painter.drawRect(glyph.x, glyph.y, glyph.pixel_width - 1, glyph.height - 1)
            painter.end()
            scaled = pm.scaled(
                self._preview_label.size(),
                Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.FastTransformation,
            )
            self._preview_label.setPixmap(scaled)
        except Exception as exc:
            self._preview_label.setText(f"Preview error: {exc}")

    def _on_accept(self):
        try:
            img, entries = self._render_to_pil()
            chars = self._get_charset()
            gfx_ptrs = _build_gfx_ptrs(chars)

            # Save PNG as art/<stem>.png
            art_dir = os.path.join(self.out_dir, "art")
            os.makedirs(art_dir, exist_ok=True)
            png_filename = self._png_stem + ".png"
            png_path = os.path.join(art_dir, png_filename)
            img.save(png_path)
            path_png_rel = "art/" + png_filename

            family = self._font_combo.currentFont().family()
            size = self._size_spin.value()
            self._result_data = FontData(
                path_png=path_png_rel,
                comment=f"Generated from system font: {family} {size}pt",
                spacing=1,
                color_sample_pos=[0, 0],
                gfx_ptrs=gfx_ptrs,
                gfx=entries,
            )
            self._result_image = img
            self.accept()
        except Exception as exc:
            QMessageBox.warning(self, "Error", f"Failed to generate font:\n{exc}")
