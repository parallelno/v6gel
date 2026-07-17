"""Interactive PNG canvas with glyph-rect overlays.

GlyphRectItem   — QGraphicsObject that draws one glyph rect with resize handles.
FontCanvasWidget — QGraphicsView hosting the PNG + all GlyphRectItems.

Canvas interactions:
  • Ctrl+scroll            — zoom in/out
  • Click on glyph rect    — select it (emits glyph_selected)
  • Click on empty area    — rubber-band drag to create new glyph (emits glyph_added)
  • Drag handle of selected rect — resize (emits glyph_geometry_committed on release)
  • Right-click glyph      — context menu (Delete, Rename, Auto-detect bounds)
"""
from __future__ import annotations

import io
from typing import Optional

from PIL import Image as PILImage
from PyQt6.QtCore import (
    QModelIndex, QPoint, QPointF, QRect, QRectF, QSize,
    Qt, pyqtSignal,
)
from PyQt6.QtGui import (
    QBrush, QColor, QCursor, QPainter, QPen, QPixmap,
)
from PyQt6.QtWidgets import (
    QAbstractItemView, QApplication, QGraphicsItem, QGraphicsObject,
    QGraphicsPixmapItem, QGraphicsScene, QGraphicsView,
    QMenu, QRubberBand, QSizePolicy,
)

from .glyph_model import FontData, GlyphEntry, GlyphTableModel

# ---------------------------------------------------------------------------
# Color palette for glyph rects
# ---------------------------------------------------------------------------
_COLORS = [
    QColor(255, 80,  80),
    QColor(80,  220, 80),
    QColor(80,  150, 255),
    QColor(255, 220, 60),
    QColor(255, 80,  220),
    QColor(60,  230, 230),
    QColor(255, 150, 30),
    QColor(180, 80,  255),
    QColor(0,   210, 170),
    QColor(255, 120, 100),
    QColor(150, 255, 80),
    QColor(80,  180, 255),
]


# ---------------------------------------------------------------------------
# GlyphRectItem
# ---------------------------------------------------------------------------

class GlyphRectItem(QGraphicsObject):
    """One glyph rect drawn on the canvas.

    Visual layers:
      1. Semi-transparent fill + solid outline (data rect in PNG coords).
      2. Resize handles (8 squares at corners/edges) when selected.
      3. Name label (top-left of rect).
    """

    # row, x, y, w, h  — emitted on mouse-release after a resize/move
    geometry_committed = pyqtSignal(int, int, int, int, int)

    HANDLE_NONE = -1
    HANDLE_SIZE = 8.0

    # Handle indices 0-7 = TL,T,TR,R,BR,B,BL,L; 8 = interior (move)
    _CURSORS = [
        Qt.CursorShape.SizeFDiagCursor,
        Qt.CursorShape.SizeVerCursor,
        Qt.CursorShape.SizeBDiagCursor,
        Qt.CursorShape.SizeHorCursor,
        Qt.CursorShape.SizeFDiagCursor,
        Qt.CursorShape.SizeVerCursor,
        Qt.CursorShape.SizeBDiagCursor,
        Qt.CursorShape.SizeHorCursor,
        Qt.CursorShape.SizeAllCursor,
    ]

    def __init__(self, row: int, glyph: GlyphEntry, color: QColor, parent=None):
        super().__init__(parent)
        self.row = row
        self._color = color
        self._rect = QRectF(glyph.x, glyph.y, glyph.width, glyph.height)
        self._label = glyph.name
        self._active_handle = self.HANDLE_NONE
        self._drag_start: Optional[QPointF] = None
        self._drag_start_rect: Optional[QRectF] = None

        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable)
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemSendsGeometryChanges)
        self.setAcceptHoverEvents(True)
        self.setZValue(2)

    # -- geometry helpers ----------------------------------------------------

    def get_rect(self) -> QRectF:
        return QRectF(self._rect)

    def set_rect_from_glyph(self, glyph: GlyphEntry):
        self.prepareGeometryChange()
        self._rect = QRectF(glyph.x, glyph.y, glyph.width, glyph.height)
        self._label = glyph.name
        self.update()

    def _handle_centers(self) -> list[QPointF]:
        r = self._rect
        mx = (r.left() + r.right()) / 2
        my = (r.top() + r.bottom()) / 2
        return [
            QPointF(r.left(), r.top()),
            QPointF(mx,       r.top()),
            QPointF(r.right(), r.top()),
            QPointF(r.right(), my),
            QPointF(r.right(), r.bottom()),
            QPointF(mx,       r.bottom()),
            QPointF(r.left(), r.bottom()),
            QPointF(r.left(), my),
        ]

    def _hit_handle(self, pos: QPointF) -> int:
        if not self.isSelected():
            return self.HANDLE_NONE
        hs = self.HANDLE_SIZE / 2
        for i, hp in enumerate(self._handle_centers()):
            if abs(pos.x() - hp.x()) <= hs and abs(pos.y() - hp.y()) <= hs:
                return i
        if self._rect.contains(pos):
            return 8   # interior = move
        return self.HANDLE_NONE

    # -- QGraphicsItem API ---------------------------------------------------

    def boundingRect(self) -> QRectF:
        m = self.HANDLE_SIZE + 2
        return self._rect.adjusted(-m, -m, m, m)

    def paint(self, painter: QPainter, _option, _widget=None):
        r = self._rect

        # Fill
        fill = QColor(self._color)
        fill.setAlpha(45)
        painter.fillRect(r, fill)

        # Outline
        lw = 2.5 if self.isSelected() else 1.2
        painter.setPen(QPen(self._color, lw))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawRect(r)

        # Label
        if r.width() >= 4 and r.height() >= 5:
            lc = QColor(self._color)
            lc.setAlpha(230)
            painter.setPen(QPen(lc))
            f = painter.font()
            f.setPixelSize(max(5, min(8, int(r.height() * 0.55))))
            painter.setFont(f)
            label_rect = QRectF(r.left() + 1, r.top(), max(r.width() - 2, 2), 10)
            painter.drawText(
                label_rect,
                Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignTop,
                self._label,
            )

        # Resize handles when selected
        if self.isSelected():
            hs = self.HANDLE_SIZE / 2
            painter.setPen(QPen(QColor(0, 0, 0), 1))
            painter.setBrush(QBrush(self._color))
            for hp in self._handle_centers():
                painter.drawRect(QRectF(hp.x() - hs, hp.y() - hs,
                                        self.HANDLE_SIZE, self.HANDLE_SIZE))

    def hoverMoveEvent(self, event):
        h = self._hit_handle(event.pos())
        self.setCursor(QCursor(self._CURSORS[h] if 0 <= h < len(self._CURSORS)
                               else Qt.CursorShape.ArrowCursor))
        super().hoverMoveEvent(event)

    def hoverLeaveEvent(self, event):
        self.unsetCursor()
        super().hoverLeaveEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            h = self._hit_handle(event.pos())
            if h != self.HANDLE_NONE:
                self._active_handle = h
                self._drag_start = event.scenePos()
                self._drag_start_rect = QRectF(self._rect)
                event.accept()
                return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._active_handle != self.HANDLE_NONE:
            d = event.scenePos() - self._drag_start
            dx, dy = d.x(), d.y()
            r = QRectF(self._drag_start_rect)
            h = self._active_handle
            if   h == 0: r.setTopLeft(r.topLeft() + QPointF(dx, dy))
            elif h == 1: r.setTop(r.top() + dy)
            elif h == 2: r.setTopRight(r.topRight() + QPointF(dx, dy))
            elif h == 3: r.setRight(r.right() + dx)
            elif h == 4: r.setBottomRight(r.bottomRight() + QPointF(dx, dy))
            elif h == 5: r.setBottom(r.bottom() + dy)
            elif h == 6: r.setBottomLeft(r.bottomLeft() + QPointF(dx, dy))
            elif h == 7: r.setLeft(r.left() + dx)
            elif h == 8: r.translate(dx, dy)
            r = r.normalized()
            if r.width() < 1:  r.setWidth(1)
            if r.height() < 1: r.setHeight(1)
            self.prepareGeometryChange()
            self._rect = r
            self.update()
            event.accept()
        else:
            super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if self._active_handle != self.HANDLE_NONE and event.button() == Qt.MouseButton.LeftButton:
            self.geometry_committed.emit(
                self.row,
                int(round(self._rect.x())),
                int(round(self._rect.y())),
                max(1, int(round(self._rect.width()))),
                max(1, int(round(self._rect.height()))),
            )
            self._active_handle = self.HANDLE_NONE
            event.accept()
        else:
            super().mouseReleaseEvent(event)


# ---------------------------------------------------------------------------
# FontCanvasWidget
# ---------------------------------------------------------------------------

class FontCanvasWidget(QGraphicsView):
    """QGraphicsView that displays the font PNG and all glyph rect overlays."""

    glyph_selected = pyqtSignal(int)        # row index
    glyph_deselected = pyqtSignal()
    glyph_added = pyqtSignal(int, int, int, int)   # x, y, w, h (image coords)
    context_menu_requested = pyqtSignal(int, QPoint)  # row, global_pos

    def __init__(self, parent=None):
        super().__init__(parent)
        self._scene = QGraphicsScene(self)
        self.setScene(self._scene)
        self._pix_item: Optional[QGraphicsPixmapItem] = None
        self._glyph_items: list[GlyphRectItem] = []
        self._model: Optional[GlyphTableModel] = None

        self._rb: Optional[QRubberBand] = None
        self._rb_origin: Optional[QPoint] = None

        self.setDragMode(QGraphicsView.DragMode.NoDrag)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setBackgroundBrush(QBrush(QColor(28, 28, 28)))
        self.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, False)
        self.setInteractive(True)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)

        self._scene.selectionChanged.connect(self._on_scene_selection_changed)

    # -- document loading ----------------------------------------------------

    def load_image(self, path: str) -> None:
        pil = PILImage.open(path)
        buf = io.BytesIO()
        pil.save(buf, format="PNG")
        buf.seek(0)
        pm = QPixmap()
        pm.loadFromData(buf.read())

        if self._pix_item:
            self._scene.removeItem(self._pix_item)
        self._pix_item = self._scene.addPixmap(pm)
        self._pix_item.setZValue(0)
        self._pix_item.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable, False)
        self._scene.setSceneRect(self._pix_item.boundingRect())

    def set_model(self, model: GlyphTableModel) -> None:
        self._model = model
        self._rebuild_items()
        model.dataChanged.connect(self._on_model_data_changed)
        model.rowsInserted.connect(lambda *_: self._rebuild_items())
        model.rowsRemoved.connect(lambda *_: self._rebuild_items())

    def _rebuild_items(self) -> None:
        for item in self._glyph_items:
            self._scene.removeItem(item)
        self._glyph_items.clear()
        if not self._model:
            return
        for i, g in enumerate(self._model._data.gfx):
            color = _COLORS[i % len(_COLORS)]
            item = GlyphRectItem(i, g, color)
            item.geometry_committed.connect(self._on_geometry_committed)
            self._scene.addItem(item)
            self._glyph_items.append(item)

    def _on_model_data_changed(self, tl: QModelIndex, br: QModelIndex, _roles):
        for row in range(tl.row(), br.row() + 1):
            if 0 <= row < len(self._glyph_items):
                g = self._model.glyph_at(row)
                if g:
                    self._glyph_items[row].set_rect_from_glyph(g)

    def _on_geometry_committed(self, row, x, y, w, h):
        if self._model:
            g = self._model.glyph_at(row)
            if g:
                g.x, g.y, g.width, g.height = x, y, w, h
                self._model.update_glyph(row, g)

    def _on_scene_selection_changed(self):
        sel = [i for i in self._glyph_items if i.isSelected()]
        if sel:
            self.glyph_selected.emit(sel[0].row)
        else:
            self.glyph_deselected.emit()

    # -- public helpers ------------------------------------------------------

    def select_row(self, row: int) -> None:
        self._scene.blockSignals(True)
        self._scene.clearSelection()
        if 0 <= row < len(self._glyph_items):
            self._glyph_items[row].setSelected(True)
        self._scene.blockSignals(False)

    def zoom_fit(self):
        if self._pix_item:
            self.fitInView(self._pix_item, Qt.AspectRatioMode.KeepAspectRatio)

    def zoom_in(self):  self.scale(1.5, 1.5)
    def zoom_out(self): self.scale(1 / 1.5, 1 / 1.5)
    def zoom_1x(self):
        self.resetTransform()
        if self._pix_item:
            self.centerOn(self._pix_item)

    # -- mouse / keyboard ----------------------------------------------------

    def wheelEvent(self, event):
        if event.modifiers() & Qt.KeyboardModifier.ControlModifier:
            factor = 1.15 if event.angleDelta().y() > 0 else 1 / 1.15
            self.scale(factor, factor)
        else:
            super().wheelEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            sp = self.mapToScene(event.pos())
            # Hit-test against glyph items (not the pixmap)
            glyph_hits = [
                i for i in self._scene.items(sp)
                if isinstance(i, GlyphRectItem)
            ]
            if glyph_hits:
                super().mousePressEvent(event)
                return
            # Start rubber-band for new glyph
            self._rb_origin = event.pos()
            if self._rb is None:
                self._rb = QRubberBand(QRubberBand.Shape.Rectangle, self.viewport())
            self._rb.setGeometry(QRect(event.pos(), QSize(0, 0)))
            self._rb.show()
            self._scene.clearSelection()

        elif event.button() == Qt.MouseButton.RightButton:
            sp = self.mapToScene(event.pos())
            glyph_hits = [
                i for i in self._scene.items(sp)
                if isinstance(i, GlyphRectItem)
            ]
            if glyph_hits:
                self.context_menu_requested.emit(
                    glyph_hits[0].row,
                    event.globalPosition().toPoint(),
                )
            else:
                super().mousePressEvent(event)
        else:
            super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._rb_origin is not None:
            self._rb.setGeometry(QRect(self._rb_origin, event.pos()).normalized())
        else:
            super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if self._rb_origin is not None and event.button() == Qt.MouseButton.LeftButton:
            rb_rect = QRect(self._rb_origin, event.pos()).normalized()
            self._rb.hide()
            self._rb_origin = None
            if rb_rect.width() >= 3 and rb_rect.height() >= 3:
                tl = self.mapToScene(rb_rect.topLeft())
                br = self.mapToScene(rb_rect.bottomRight())
                self.glyph_added.emit(
                    int(tl.x()), int(tl.y()),
                    max(1, int(br.x() - tl.x())),
                    max(1, int(br.y() - tl.y())),
                )
        else:
            super().mouseReleaseEvent(event)
