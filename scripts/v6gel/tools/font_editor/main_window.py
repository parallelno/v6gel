"""Main application window for the v6 Font Editor."""
from __future__ import annotations

import copy
import os
from typing import Optional

from PIL import Image as PILImage
from PyQt6.QtCore import Qt, QPoint
from PyQt6.QtGui import QAction, QKeySequence
from PyQt6.QtWidgets import (
    QAbstractItemView, QApplication, QDialog, QFileDialog, QFormLayout,
    QGroupBox, QHBoxLayout, QInputDialog, QLabel, QLineEdit, QListWidget,
    QListWidgetItem, QMainWindow, QMenu, QMessageBox, QPushButton,
    QSizePolicy, QSpinBox, QSplitter, QStatusBar, QTabWidget,
    QTableView, QToolBar, QVBoxLayout, QWidget,
)

from .auto_detect import detect_bounds, _bg_index
from .canvas_widget import FontCanvasWidget
from .glyph_model import FontData, GlyphEntry, GlyphTableModel
from .json_io import read_font_json, write_font_json
from .preview_widget import FontPreviewWidget
from .system_font_dialog import SystemFontDialog
from .templates import TEMPLATES


class FontEditorMainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self._json_path: Optional[str] = None
        self._base_dir: Optional[str] = None
        self._font_data: Optional[FontData] = None
        self._model: Optional[GlyphTableModel] = None
        self._pil_image: Optional[PILImage.Image] = None
        self._dirty = False
        self._updating_form = False  # re-entrancy guard

        self._build_ui()
        self._build_actions()
        self._build_menu()
        self._build_toolbar()
        self._connect_signals()
        self._set_title()
        self._preview_input.setText("Hello World!")  # default preview text

    # =========================================================================
    # UI construction
    # =========================================================================

    def _build_ui(self):
        self.setWindowTitle("v6 Font Editor")
        self.resize(1440, 900)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        self.setCentralWidget(splitter)

        # Left: canvas
        self._canvas = FontCanvasWidget()
        splitter.addWidget(self._canvas)
        splitter.setStretchFactor(0, 1)

        # Right: tabs
        self._tabs = QTabWidget()
        splitter.addWidget(self._tabs)
        splitter.setStretchFactor(1, 1)
        # Default 50/50 split; user can drag freely from edge to edge
        splitter.setSizes([720, 720])

        self._build_preview_tab()
        self._build_glyphs_tab()
        self._build_charset_tab()
        self._build_settings_tab()

        # Status bar
        self._lbl_path = QLabel("No file open")
        self._lbl_count = QLabel("")
        self.statusBar().addWidget(self._lbl_path, 1)
        self.statusBar().addPermanentWidget(self._lbl_count)

    def _build_preview_tab(self):
        self._preview_input = QLineEdit()
        self._preview_input.setPlaceholderText("Type text to preview…")
        self._preview_input.setToolTip(
            "Type any string here to see how it looks with the current font.\n"
            "Characters not present in the glyph list are shown as placeholder boxes."
        )
        self._preview_widget = FontPreviewWidget()
        self._preview_widget.setToolTip(
            "Live preview of the text above rendered using the current glyph data and PNG.\n"
            "Use the zoom slider to scale up, and toggle \"Show cursor marks\" to see\n"
            "the baseline (green ticks) and actual glyph-origin positions."
        )

        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(4, 4, 4, 4)
        lay.addWidget(self._preview_input)
        lay.addWidget(self._preview_widget, 1)
        self._tabs.addTab(w, "Preview")

    def _build_glyphs_tab(self):
        # Tooltips shared by input widgets AND their form-row labels
        tt_table = (
            "List of all glyphs defined in this font.\n"
            "Click a row to select the glyph and highlight it on the canvas.\n"
            "Columns: Name | X | Y | Width (adv) | Height | Offset X | Offset Y"
        )
        tt_name = (
            "Glyph identifier. Must match the name used in the Charset tab.\n"
            "Examples: A  a  0  space  exclamation  comma"
        )
        tt_x = "X coordinate of the top-left pixel of the glyph crop in the PNG."
        tt_y = "Y coordinate of the top-left pixel of the glyph crop in the PNG."
        tt_w = (
            "Cursor X advance after drawing this glyph (in pixels).\n"
            "This is NOT the visual pixel crop width — the data cell is always 8 px wide.\n"
            "The cursor moves by: width + global spacing."
        )
        tt_h = "Pixel crop height of the glyph in the PNG."
        tt_ox = (
            "Horizontal rendering offset from the cursor position (pixels).\n"
            "Negative → glyph shifts left of cursor.\n"
            "Does NOT affect the next char’s cursor position."
        )
        tt_oy = (
            "Vertical rendering offset from the cursor baseline (pixels).\n"
            "Negative → glyph’s bottom extends below baseline (descender: g, j, p…).\n"
            "Positive → glyph floats above the baseline (dash, quote…).\n"
            "Does NOT affect the next char’s cursor position.\n"
            "The green cross on the canvas shows the resulting baseline anchor."
        )

        def _lbl(text, tt):
            lbl = QLabel(text); lbl.setToolTip(tt); return lbl

        # Table
        self._glyph_table = QTableView()
        self._glyph_table.setToolTip(tt_table)
        self._glyph_table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self._glyph_table.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self._glyph_table.horizontalHeader().setStretchLastSection(True)
        self._glyph_table.verticalHeader().setDefaultSectionSize(18)

        # Property form
        self._prop_name = QLineEdit(); self._prop_name.setToolTip(tt_name)
        self._prop_x = QSpinBox(); self._prop_x.setRange(0, 9999); self._prop_x.setToolTip(tt_x)
        self._prop_y = QSpinBox(); self._prop_y.setRange(0, 9999); self._prop_y.setToolTip(tt_y)
        self._prop_w = QSpinBox(); self._prop_w.setRange(1, 255);  self._prop_w.setToolTip(tt_w)
        self._prop_h = QSpinBox(); self._prop_h.setRange(1, 255);  self._prop_h.setToolTip(tt_h)
        self._prop_offset_x = QSpinBox(); self._prop_offset_x.setRange(-128, 127)
        self._prop_offset_x.setToolTip(tt_ox)
        self._prop_offset_y = QSpinBox(); self._prop_offset_y.setRange(-128, 127)
        self._prop_offset_y.setToolTip(tt_oy)

        form = QFormLayout()
        form.addRow(_lbl("Name:",         tt_name),  self._prop_name)
        form.addRow(_lbl("X:",            tt_x),     self._prop_x)
        form.addRow(_lbl("Y:",            tt_y),     self._prop_y)
        form.addRow(_lbl("Width (adv):",  tt_w),     self._prop_w)
        form.addRow(_lbl("Height:",       tt_h),     self._prop_h)
        form.addRow(_lbl("Offset X:",     tt_ox),    self._prop_offset_x)
        form.addRow(_lbl("Offset Y:",     tt_oy),    self._prop_offset_y)

        form_widget = QWidget()
        form_widget.setLayout(form)

        # Buttons
        self._btn_add    = QPushButton("Add Glyph")
        self._btn_add.setToolTip("Add a new empty glyph entry. Prompts for a name.")
        self._btn_del    = QPushButton("Delete")
        self._btn_del.setToolTip("Delete the selected glyph entry.")
        self._btn_detect = QPushButton("Auto-detect")
        self._btn_detect.setToolTip(
            "Scan the PNG for non-background pixels in the selected glyph\u2019s area\n"
            "and tighten X, Y, Height to the actual pixel bounds."
        )
        self._btn_detect_all = QPushButton("Detect All")
        self._btn_detect_all.setToolTip("Run Auto-detect on every glyph in the list.")

        btn_row = QHBoxLayout()
        for b in (self._btn_add, self._btn_del, self._btn_detect, self._btn_detect_all):
            btn_row.addWidget(b)

        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(4, 4, 4, 4)
        lay.addWidget(self._glyph_table, 2)
        lay.addWidget(form_widget, 1)
        lay.addLayout(btn_row)
        self._tabs.addTab(w, "Glyphs")

    def _build_charset_tab(self):
        note = QLabel(
            "Each entry maps a charset code position to a glyph name.\n"
            "\"space\" = unmapped slot. Drag rows to reorder."
        )
        note.setWordWrap(True)

        self._charset_list = QListWidget()
        self._charset_list.setDragDropMode(QAbstractItemView.DragDropMode.InternalMove)
        self._charset_list.setToolTip(
            "The gfx_ptrs mapping: each row is a charset code position (0-based)\n"
            "mapped to a glyph name. The game engine looks up char code N here to\n"
            "find which glyph to draw. Use \"space\" for unmapped positions.\n"
            "Drag rows to reorder. Double-click a row to rename it."
        )

        self._btn_cs_add  = QPushButton("Add")
        self._btn_cs_add.setToolTip("Append a new entry at the end of the charset mapping.")
        self._btn_cs_del  = QPushButton("Remove")
        self._btn_cs_del.setToolTip("Remove the selected charset entry.")
        self._btn_cs_up   = QPushButton("\u2191")
        self._btn_cs_up.setToolTip("Move the selected entry one position up (decrements its char code).")
        self._btn_cs_down = QPushButton("\u2193")
        self._btn_cs_down.setToolTip("Move the selected entry one position down (increments its char code).")
        self._btn_cs_edit = QPushButton("Edit")
        self._btn_cs_edit.setToolTip("Rename the glyph name at the selected charset position.")

        cs_btn = QHBoxLayout()
        for b in (self._btn_cs_add, self._btn_cs_del,
                  self._btn_cs_up, self._btn_cs_down, self._btn_cs_edit):
            cs_btn.addWidget(b)

        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(4, 4, 4, 4)
        lay.addWidget(note)
        lay.addWidget(self._charset_list, 1)
        lay.addLayout(cs_btn)
        self._tabs.addTab(w, "Charset")

    def _build_settings_tab(self):
        self._sett_spacing = QSpinBox()
        self._sett_spacing.setRange(0, 20)
        self._sett_spacing.setToolTip(
            "Pixels added to every glyph's advance width between characters.\n"
            "Final cursor step = glyph width + spacing."
        )

        self._sett_csp_x = QSpinBox()
        self._sett_csp_x.setRange(0, 9999)
        self._sett_csp_x.setToolTip(
            "X coordinate of the pixel used to sample the background colour.\n"
            "Any pixel in the PNG that equals this colour is treated as transparent."
        )

        self._sett_csp_y = QSpinBox()
        self._sett_csp_y.setRange(0, 9999)
        self._sett_csp_y.setToolTip(
            "Y coordinate of the pixel used to sample the background colour.\n"
            "Any pixel in the PNG that equals this colour is treated as transparent."
        )

        self._sett_comment = QLineEdit()
        self._sett_comment.setToolTip(
            "Free-text comment stored in font.json. Not used by the engine."
        )

        self._sett_path_png = QLineEdit()
        self._sett_path_png.setToolTip(
            "Path to the glyph atlas PNG, relative to the font.json file.\n"
            "Example: art/font.png"
        )

        self._btn_browse_png = QPushButton("Browse\u2026")
        self._btn_browse_png.setToolTip("Open a file picker to select the PNG atlas.")

        path_row = QHBoxLayout()
        path_row.addWidget(self._sett_path_png)
        path_row.addWidget(self._btn_browse_png)

        # Tooltip strings for the Settings labels
        tt_spacing = self._sett_spacing.toolTip()
        tt_csp_x   = self._sett_csp_x.toolTip()
        tt_csp_y   = self._sett_csp_y.toolTip()
        tt_comment = self._sett_comment.toolTip()
        tt_pathpng = self._sett_path_png.toolTip()

        def _lbl(text, tt):
            lbl = QLabel(text); lbl.setToolTip(tt); return lbl

        form = QFormLayout()
        form.addRow(_lbl("Spacing:",      tt_spacing), self._sett_spacing)
        form.addRow(_lbl("BG sample X:",  tt_csp_x),   self._sett_csp_x)
        form.addRow(_lbl("BG sample Y:",  tt_csp_y),   self._sett_csp_y)
        form.addRow(_lbl("Comment:",      tt_comment), self._sett_comment)
        form.addRow(_lbl("Path PNG:",     tt_pathpng), path_row)

        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(6, 6, 6, 6)
        lay.addLayout(form)
        lay.addStretch()
        self._tabs.addTab(w, "Settings")

    # =========================================================================
    # Actions / menus / toolbar
    # =========================================================================

    def _build_actions(self):
        def act(text, shortcut=None, tip=None, slot=None):
            a = QAction(text, self)
            if shortcut: a.setShortcut(QKeySequence(shortcut))
            if tip:      a.setStatusTip(tip)
            if slot:     a.triggered.connect(slot)
            return a

        self._act_new         = act("New…",        "Ctrl+N", slot=self.action_new)
        self._act_open        = act("Open…",        "Ctrl+O", slot=self.action_open)
        self._act_save        = act("Save",          "Ctrl+S", slot=self.action_save)
        self._act_save_as     = act("Save As…",    "Ctrl+Shift+S", slot=self.action_save_as)
        self._act_import_font = act("Import System Font…", slot=self.action_import_font)
        self._act_load_png    = act("Load PNG only…", slot=self.action_load_png)
        self._act_zoom_in     = act("Zoom In",      "Ctrl+=", slot=self._canvas.zoom_in)
        self._act_zoom_out    = act("Zoom Out",     "Ctrl+-", slot=self._canvas.zoom_out)
        self._act_zoom_fit    = act("Fit to View",  "Ctrl+0", slot=self._canvas.zoom_fit)
        self._act_zoom_1x     = act("1:1",           slot=self._canvas.zoom_1x)

    def _build_menu(self):
        mb = self.menuBar()
        file_m = mb.addMenu("File")
        file_m.addAction(self._act_new)
        file_m.addAction(self._act_open)
        file_m.addSeparator()
        file_m.addAction(self._act_save)
        file_m.addAction(self._act_save_as)

        import_m = mb.addMenu("Import")
        import_m.addAction(self._act_import_font)
        import_m.addAction(self._act_load_png)

        view_m = mb.addMenu("View")
        view_m.addAction(self._act_zoom_in)
        view_m.addAction(self._act_zoom_out)
        view_m.addAction(self._act_zoom_fit)
        view_m.addAction(self._act_zoom_1x)

    def _build_toolbar(self):
        tb = self.addToolBar("Main")
        tb.setMovable(False)
        tb.addAction(self._act_zoom_in)
        tb.addAction(self._act_zoom_out)
        tb.addAction(self._act_zoom_fit)
        tb.addAction(self._act_zoom_1x)

    # =========================================================================
    # Signal wiring
    # =========================================================================

    def _connect_signals(self):
        # Canvas ↔ glyphs tab
        self._canvas.glyph_selected.connect(self._on_canvas_glyph_selected)
        self._canvas.glyph_added.connect(self._on_canvas_glyph_added)
        self._canvas.context_menu_requested.connect(self._on_canvas_context_menu)

        # Preview text input
        self._preview_input.textChanged.connect(self._preview_widget.set_text)

        # Glyph table selection → property form
        # (model assigned later via _attach_model)

        # Property form changes → model
        self._prop_name.editingFinished.connect(self._on_prop_changed)
        for sp in (self._prop_x, self._prop_y, self._prop_w,
                   self._prop_h, self._prop_offset_x, self._prop_offset_y):
            sp.valueChanged.connect(self._on_prop_changed)

        # Glyph buttons
        self._btn_add.clicked.connect(self._on_add_glyph)
        self._btn_del.clicked.connect(self._on_delete_glyph)
        self._btn_detect.clicked.connect(self._on_autodetect_selected)
        self._btn_detect_all.clicked.connect(self._on_autodetect_all)

        # Charset buttons
        self._btn_cs_add.clicked.connect(self._on_cs_add)
        self._btn_cs_del.clicked.connect(self._on_cs_del)
        self._btn_cs_up.clicked.connect(self._on_cs_up)
        self._btn_cs_down.clicked.connect(self._on_cs_down)
        self._btn_cs_edit.clicked.connect(self._on_cs_edit)
        self._charset_list.itemDoubleClicked.connect(
            lambda _: self._on_cs_edit()
        )
        self._charset_list.model().rowsMoved.connect(self._on_cs_reordered)

        # Settings
        self._sett_spacing.valueChanged.connect(self._on_settings_changed)
        self._sett_csp_x.valueChanged.connect(self._on_settings_changed)
        self._sett_csp_y.valueChanged.connect(self._on_settings_changed)
        self._sett_comment.editingFinished.connect(self._on_settings_changed)
        self._sett_path_png.editingFinished.connect(self._on_png_path_changed)
        self._btn_browse_png.clicked.connect(self._on_browse_png)

    def _attach_model(self):
        """Connect the new model to the table view and its selection changes."""
        self._glyph_table.setModel(self._model)
        sel = self._glyph_table.selectionModel()
        sel.currentRowChanged.connect(self._on_glyph_row_changed)
        self._model.dataChanged.connect(self._on_model_changed)
        self._model.rowsInserted.connect(self._on_model_changed)
        self._model.rowsRemoved.connect(self._on_model_changed)

    # =========================================================================
    # File I/O actions
    # =========================================================================

    def action_new(self):
        if not self._confirm_discard():
            return
        names = list(TEMPLATES.keys())
        choice, ok = _pick_item(self, "New Font", "Select template:", names)
        if not ok:
            return
        fd = copy.deepcopy(TEMPLATES[choice])
        path, _ = QFileDialog.getSaveFileName(
            self, "Save new font.json", "font.json",
            "Font JSON (*.json)"
        )
        if not path:
            return
        self._json_path = path
        self._base_dir = os.path.dirname(os.path.abspath(path))
        self._load_font_data(fd)
        self._dirty = False
        self._set_title()

    def action_open(self, path: str = ""):
        if not self._confirm_discard():
            return
        if not path:
            path, _ = QFileDialog.getOpenFileName(
                self, "Open font.json", "",
                "Font JSON (*.json);;All files (*)"
            )
        if not path:
            return
        try:
            fd, base = read_font_json(path)
        except Exception as exc:
            QMessageBox.critical(self, "Open error", str(exc))
            return
        self._json_path = path
        self._base_dir = base
        self._load_font_data(fd)
        self._dirty = False
        self._set_title()

    def action_save(self) -> bool:
        if not self._json_path:
            return self.action_save_as()
        return self._do_save(self._json_path)

    def action_save_as(self) -> bool:
        default = self._json_path or "font.json"
        path, _ = QFileDialog.getSaveFileName(
            self, "Save As", default,
            "Font JSON (*.json)"
        )
        if not path:
            return False
        self._json_path = path
        self._base_dir = os.path.dirname(os.path.abspath(path))
        return self._do_save(path)

    def _do_save(self, path: str) -> bool:
        if not self._font_data:
            return False
        try:
            write_font_json(path, self._font_data)
        except Exception as exc:
            QMessageBox.critical(self, "Save error", str(exc))
            return False
        self._dirty = False
        self._set_title()
        return True

    def action_import_font(self):
        if not self._confirm_discard():
            return
        # Ask the user to name the output JSON file
        json_path, _ = QFileDialog.getSaveFileName(
            self, "Save font as…", "font.json", "Font JSON (*.json)"
        )
        if not json_path:
            return
        out_dir = os.path.dirname(os.path.abspath(json_path))
        png_stem = os.path.splitext(os.path.basename(json_path))[0]
        dlg = SystemFontDialog(out_dir, png_stem, self)
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        fd = dlg.result_data
        img = dlg.result_image
        if fd and img:
            self._json_path = json_path
            self._base_dir = out_dir
            self._pil_image = img
            self._load_font_data(fd)
            # Save JSON immediately alongside the already-written PNG
            self._do_save(json_path)

    def action_load_png(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Load PNG", "", "PNG images (*.png)"
        )
        if path and self._font_data:
            rel = os.path.relpath(path, self._base_dir or ".")
            self._font_data.path_png = rel.replace("\\", "/")
            self._reload_png()
            self._mark_dirty()

    # =========================================================================
    # Document loading helpers
    # =========================================================================

    def _load_font_data(self, fd: FontData):
        self._font_data = fd
        self._model = GlyphTableModel(fd)
        self._attach_model()
        self._canvas.set_model(self._model)
        self._reload_png()
        self._populate_settings()
        self._populate_charset()
        self._update_status()

    def _reload_png(self):
        if not self._font_data or not self._base_dir:
            return
        png_rel = self._font_data.path_png
        png_abs = os.path.join(self._base_dir, png_rel)
        if not os.path.isfile(png_abs):
            return
        try:
            self._pil_image = PILImage.open(png_abs)
            self._canvas.load_image(png_abs)
            self._canvas.zoom_fit()
            self._preview_widget.set_font_data(self._font_data, self._pil_image)
        except Exception as exc:
            QMessageBox.warning(self, "PNG load error", str(exc))

    def _populate_settings(self):
        if not self._font_data:
            return
        self._updating_form = True
        try:
            fd = self._font_data
            self._sett_spacing.setValue(fd.spacing)
            self._sett_csp_x.setValue(int(fd.color_sample_pos[0]))
            self._sett_csp_y.setValue(int(fd.color_sample_pos[1]))
            self._sett_comment.setText(fd.comment)
            self._sett_path_png.setText(fd.path_png)
        finally:
            self._updating_form = False

    def _populate_charset(self):
        self._charset_list.blockSignals(True)
        self._charset_list.clear()
        if self._font_data:
            for i, name in enumerate(self._font_data.gfx_ptrs):
                self._charset_list.addItem(QListWidgetItem(f"{i:>3}: {name}"))
        self._charset_list.blockSignals(False)

    def _refresh_charset_labels(self):
        for i in range(self._charset_list.count()):
            name = self._font_data.gfx_ptrs[i]
            self._charset_list.item(i).setText(f"{i:>3}: {name}")

    # =========================================================================
    # Slot handlers
    # =========================================================================

    # -- Canvas --------------------------------------------------------------

    def _on_canvas_glyph_selected(self, row: int):
        self._tabs.setCurrentIndex(1)   # switch to Glyphs tab
        self._glyph_table.selectRow(row)

    def _on_canvas_glyph_added(self, x: int, y: int, w: int, h: int):
        if not self._model:
            return
        name, ok = QInputDialog.getText(self, "New Glyph", "Glyph name:")
        if ok and name.strip():
            self._model.add_glyph(GlyphEntry(name=name.strip(), x=x, y=y, width=w, height=h))
            self._tabs.setCurrentIndex(1)
            self._glyph_table.selectRow(self._model.rowCount() - 1)
            self._mark_dirty()
            self._update_status()

    def _on_canvas_context_menu(self, row: int, global_pos: QPoint):
        menu = QMenu(self)
        menu.addAction("Select", lambda: (
            self._tabs.setCurrentIndex(1),
            self._glyph_table.selectRow(row),
        ))
        menu.addAction("Auto-detect bounds", lambda: self._autodetect_row(row))
        menu.addSeparator()
        menu.addAction("Delete", lambda: self._delete_glyph_row(row))
        menu.exec(global_pos)

    # -- Glyph table / property form -----------------------------------------

    def _on_glyph_row_changed(self, current, _previous):
        row = current.row()
        if not self._model or row < 0:
            return
        g = self._model.glyph_at(row)
        if g is None:
            return
        self._canvas.select_row(row)
        self._updating_form = True
        try:
            self._prop_name.setText(g.name)
            self._prop_x.setValue(g.x)
            self._prop_y.setValue(g.y)
            self._prop_w.setValue(g.width)
            self._prop_h.setValue(g.height)
            self._prop_offset_x.setValue(g.offset_x)
            self._prop_offset_y.setValue(g.offset_y)
        finally:
            self._updating_form = False

    def _on_prop_changed(self, *_):
        if self._updating_form or not self._model:
            return
        row = self._glyph_table.currentIndex().row()
        if row < 0:
            return
        g = self._model.glyph_at(row)
        if g is None:
            return
        g.name     = self._prop_name.text().strip() or g.name
        g.x        = self._prop_x.value()
        g.y        = self._prop_y.value()
        g.width    = self._prop_w.value()
        g.height   = self._prop_h.value()
        g.offset_x = self._prop_offset_x.value()
        g.offset_y = self._prop_offset_y.value()
        self._model.update_glyph(row, g)
        self._mark_dirty()

    def _on_model_changed(self, *_):
        self._preview_widget.set_font_data(self._font_data, self._pil_image)
        self._update_status()

    # -- Glyph buttons -------------------------------------------------------

    def _on_add_glyph(self):
        if not self._model:
            return
        name, ok = QInputDialog.getText(self, "New Glyph", "Glyph name:")
        if ok and name.strip():
            self._model.add_glyph(GlyphEntry(name=name.strip(), x=0, y=0, width=4, height=8))
            self._glyph_table.selectRow(self._model.rowCount() - 1)
            self._mark_dirty()
            self._update_status()

    def _on_delete_glyph(self):
        row = self._glyph_table.currentIndex().row()
        self._delete_glyph_row(row)

    def _delete_glyph_row(self, row: int):
        if not self._model or row < 0:
            return
        g = self._model.glyph_at(row)
        if g and QMessageBox.question(
            self, "Delete Glyph", f"Delete glyph \"{g.name}\"?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        ) == QMessageBox.StandardButton.Yes:
            self._model.remove_glyph(row)
            self._mark_dirty()
            self._update_status()

    def _on_autodetect_selected(self):
        row = self._glyph_table.currentIndex().row()
        self._autodetect_row(row)

    def _autodetect_row(self, row: int):
        if not self._model or not self._pil_image or not self._font_data:
            return
        g = self._model.glyph_at(row)
        if g is None:
            return
        bg = _bg_index(self._pil_image, self._font_data.color_sample_pos)
        search_w = max(g.width + 8, 24)
        search_h = max(g.height + 8, 24)
        result = detect_bounds(self._pil_image, bg,
                               (g.x, g.y, search_w, search_h))
        if result:
            g.x, g.y, g.width, g.height = result
            self._model.update_glyph(row, g)
            self._on_glyph_row_changed(self._glyph_table.currentIndex(), None)
            self._mark_dirty()

    def _on_autodetect_all(self):
        if not self._model or not self._pil_image or not self._font_data:
            return
        bg = _bg_index(self._pil_image, self._font_data.color_sample_pos)
        count = 0
        for row in range(self._model.rowCount()):
            g = self._model.glyph_at(row)
            if g is None:
                continue
            search_w = max(g.width + 8, 24)
            search_h = max(g.height + 8, 24)
            result = detect_bounds(self._pil_image, bg,
                                   (g.x, g.y, search_w, search_h))
            if result:
                g.x, g.y, g.width, g.height = result
                self._model.update_glyph(row, g)
                count += 1
        if count:
            self._mark_dirty()
            self.statusBar().showMessage(f"Auto-detected bounds for {count} glyphs.", 3000)

    # -- Charset tab ---------------------------------------------------------

    def _on_cs_add(self):
        if not self._font_data:
            return
        name, ok = QInputDialog.getText(self, "Add Charset Entry", "Glyph name:")
        if ok and name.strip():
            self._font_data.gfx_ptrs.append(name.strip())
            self._charset_list.addItem(
                QListWidgetItem(f"{len(self._font_data.gfx_ptrs)-1:>3}: {name.strip()}")
            )
            self._mark_dirty()

    def _on_cs_del(self):
        if not self._font_data:
            return
        row = self._charset_list.currentRow()
        if row < 0:
            return
        self._font_data.gfx_ptrs.pop(row)
        self._charset_list.takeItem(row)
        self._refresh_charset_labels()
        self._mark_dirty()

    def _on_cs_up(self):
        self._charset_move(-1)

    def _on_cs_down(self):
        self._charset_move(1)

    def _charset_move(self, delta: int):
        if not self._font_data:
            return
        row = self._charset_list.currentRow()
        new_row = row + delta
        if new_row < 0 or new_row >= len(self._font_data.gfx_ptrs):
            return
        ptrs = self._font_data.gfx_ptrs
        ptrs[row], ptrs[new_row] = ptrs[new_row], ptrs[row]
        self._refresh_charset_labels()
        self._charset_list.setCurrentRow(new_row)
        self._mark_dirty()

    def _on_cs_edit(self):
        if not self._font_data:
            return
        row = self._charset_list.currentRow()
        if row < 0 or row >= len(self._font_data.gfx_ptrs):
            return
        name, ok = QInputDialog.getText(
            self, "Edit Charset Entry", "Glyph name:",
            text=self._font_data.gfx_ptrs[row],
        )
        if ok and name.strip():
            self._font_data.gfx_ptrs[row] = name.strip()
            self._refresh_charset_labels()
            self._mark_dirty()

    def _on_cs_reordered(self, _src_parent, src_start, src_end, _dst_parent, dst_row):
        """Sync FontData.gfx_ptrs after the user drags a QListWidget row."""
        if not self._font_data:
            return
        new_ptrs = [
            self._charset_list.item(i).text().split(": ", 1)[1]
            for i in range(self._charset_list.count())
        ]
        self._font_data.gfx_ptrs = new_ptrs
        self._refresh_charset_labels()
        self._mark_dirty()

    # -- Settings tab --------------------------------------------------------

    def _on_settings_changed(self, *_):
        if self._updating_form or not self._font_data:
            return
        self._font_data.spacing = self._sett_spacing.value()
        self._font_data.color_sample_pos = [
            self._sett_csp_x.value(),
            self._sett_csp_y.value(),
        ]
        self._font_data.comment = self._sett_comment.text()
        self._mark_dirty()

    def _on_png_path_changed(self):
        if self._updating_form or not self._font_data:
            return
        self._font_data.path_png = self._sett_path_png.text()
        self._reload_png()
        self._mark_dirty()

    def _on_browse_png(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Select PNG", self._base_dir or "",
            "PNG images (*.png)"
        )
        if path and self._font_data and self._base_dir:
            rel = os.path.relpath(path, self._base_dir).replace("\\", "/")
            self._font_data.path_png = rel
            self._sett_path_png.setText(rel)
            self._reload_png()
            self._mark_dirty()

    # =========================================================================
    # Helpers
    # =========================================================================

    def _mark_dirty(self):
        if not self._dirty:
            self._dirty = True
            self._set_title()

    def _set_title(self):
        name = os.path.basename(self._json_path) if self._json_path else "Untitled"
        star = " *" if self._dirty else ""
        self.setWindowTitle(f"v6 Font Editor — {name}{star}")

    def _update_status(self):
        if self._json_path:
            self._lbl_path.setText(self._json_path)
        else:
            self._lbl_path.setText("Untitled")
        count = len(self._font_data.gfx) if self._font_data else 0
        self._lbl_count.setText(f"{count} glyphs")

    def _confirm_discard(self) -> bool:
        if not self._dirty:
            return True
        ans = QMessageBox.question(
            self, "Unsaved changes",
            "You have unsaved changes. Discard them?",
            QMessageBox.StandardButton.Discard | QMessageBox.StandardButton.Cancel,
        )
        return ans == QMessageBox.StandardButton.Discard

    def closeEvent(self, event):
        if self._confirm_discard():
            event.accept()
        else:
            event.ignore()


# ---------------------------------------------------------------------------
# Small helper
# ---------------------------------------------------------------------------

def _pick_item(parent, title: str, label: str, items: list[str]) -> tuple[str, bool]:
    from PyQt6.QtWidgets import QInputDialog
    return QInputDialog.getItem(parent, title, label, items, 0, False)
