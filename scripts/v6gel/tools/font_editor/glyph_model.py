"""Core data model for the font editor.

GlyphEntry  — one glyph in a font.json ``gfx`` array.
FontData    — the entire font.json document.
GlyphTableModel — QAbstractTableModel adapter for the Glyphs table view.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional

from PyQt6.QtCore import QAbstractTableModel, QModelIndex, Qt, pyqtSignal


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class GlyphEntry:
    """One entry in ``font.json["gfx"]``.

    ``width``   = cursor X advance after drawing this glyph.
                  The pixel data cell is always 8 px wide (GLYPH_WIDTH).
    ``offset_x``, ``offset_y`` = local rendering displacement from the cursor.
                  They do NOT move the cursor; cursor is restored before advancing.
                  offset_y < 0 → glyph renders above cursor line.
                  offset_y > 0 → glyph renders below cursor line.
    """
    name: str
    x: int
    y: int
    width: int      # cursor advance, NOT pixel crop width
    height: int
    offset_x: int = 0
    offset_y: int = 0
    pixel_width: int = 0  # transient detected ink width; 0 means unknown


@dataclass
class FontData:
    """Complete contents of a font.json file."""
    path_png: str = "art/font.png"
    comment: str = ""
    spacing: int = 1
    color_sample_pos: list = field(default_factory=lambda: [0, 0])
    palette: list = field(default_factory=lambda: [{"x": i * 16, "y": 0} for i in range(16)])
    gfx_ptrs: list = field(default_factory=list)   # list[str]: charset mapping
    gfx: list = field(default_factory=list)         # list[GlyphEntry]


# ---------------------------------------------------------------------------
# Column layout
# ---------------------------------------------------------------------------

_ATTRS   = ('name', 'x', 'y', 'width', 'height', 'offset_x', 'offset_y')
_HEADERS = ('Name', 'X', 'Y', 'Width (adv)', 'Height', 'Offset X', 'Offset Y')


# ---------------------------------------------------------------------------
# QAbstractTableModel
# ---------------------------------------------------------------------------

class GlyphTableModel(QAbstractTableModel):
    """Wraps ``FontData.gfx`` as a table for QTableView."""

    def __init__(self, font_data: FontData, parent=None):
        super().__init__(parent)
        self._data = font_data

    # -- required overrides --------------------------------------------------

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:
        return len(self._data.gfx)

    def columnCount(self, parent: QModelIndex = QModelIndex()) -> int:
        return len(_ATTRS)

    def data(self, index: QModelIndex, role: int = Qt.ItemDataRole.DisplayRole) -> Any:
        if not index.isValid():
            return None
        if role in (Qt.ItemDataRole.DisplayRole, Qt.ItemDataRole.EditRole):
            return getattr(self._data.gfx[index.row()], _ATTRS[index.column()])
        return None

    def setData(self, index: QModelIndex, value: Any,
                role: int = Qt.ItemDataRole.EditRole) -> bool:
        if not index.isValid() or role != Qt.ItemDataRole.EditRole:
            return False
        g = self._data.gfx[index.row()]
        attr = _ATTRS[index.column()]
        try:
            setattr(g, attr, str(value) if attr == 'name' else int(value))
        except (ValueError, TypeError):
            return False
        self.dataChanged.emit(index, index, [Qt.ItemDataRole.DisplayRole])
        return True

    def flags(self, index: QModelIndex) -> Qt.ItemFlag:
        return (Qt.ItemFlag.ItemIsEnabled
                | Qt.ItemFlag.ItemIsSelectable
                | Qt.ItemFlag.ItemIsEditable)

    def headerData(self, section: int, orientation: Qt.Orientation,
                   role: int = Qt.ItemDataRole.DisplayRole) -> Any:
        if orientation == Qt.Orientation.Horizontal and role == Qt.ItemDataRole.DisplayRole:
            return _HEADERS[section]
        return None

    # -- helpers -------------------------------------------------------------

    def add_glyph(self, glyph: GlyphEntry) -> None:
        row = len(self._data.gfx)
        self.beginInsertRows(QModelIndex(), row, row)
        self._data.gfx.append(glyph)
        self.endInsertRows()

    def remove_glyph(self, row: int) -> None:
        if 0 <= row < len(self._data.gfx):
            self.beginRemoveRows(QModelIndex(), row, row)
            self._data.gfx.pop(row)
            self.endRemoveRows()

    def glyph_at(self, row: int) -> Optional[GlyphEntry]:
        if 0 <= row < len(self._data.gfx):
            return self._data.gfx[row]
        return None

    def update_glyph(self, row: int, glyph: GlyphEntry) -> None:
        """Replace the glyph at *row* and emit dataChanged."""
        if 0 <= row < len(self._data.gfx):
            self._data.gfx[row] = glyph
            tl = self.index(row, 0)
            br = self.index(row, len(_ATTRS) - 1)
            self.dataChanged.emit(tl, br, [Qt.ItemDataRole.DisplayRole])
