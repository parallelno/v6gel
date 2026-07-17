"""Entry point for the v6 Font Editor."""
from __future__ import annotations

import sys

from PyQt6.QtWidgets import QApplication

from .main_window import FontEditorMainWindow


def main() -> None:
    app = QApplication(sys.argv)
    app.setApplicationName("v6 Font Editor")
    app.setOrganizationName("v6gel")

    win = FontEditorMainWindow()
    win.show()

    # Optional: open a file passed on the command line
    if len(sys.argv) > 1:
        win.action_open(sys.argv[1])

    sys.exit(app.exec())
