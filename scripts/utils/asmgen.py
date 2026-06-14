"""ASM generation and assembly helpers for the export tools.

This module knows how to:

* invoke the external ``v6asm`` assembler to turn a generated data-ASM into a
  raw binary blob (the file that is later transport-compressed and stored on
  the FDD image), and
* emit the small ``*_meta.asm`` file that is linked into the main program and
  describes the blob (its CP/M filename and length plus an exporter-specific
  body of pointers/constants).
"""

import os
import subprocess

from utils import consts
from utils.log import error


def cpm_filename(name, ext=consts.EXT_BIN):
	"""Return an upper-case CP/M style file name, e.g. ``SONG01.BIN``.

	The base name is truncated to ``CPM_FILENAME_LEN`` (8) characters.
	"""
	return (name[:consts.CPM_FILENAME_LEN] + ext).upper()


def run(command, cwd=None):
	"""Run an external command, raising :class:`ExportError` on failure."""
	result = subprocess.run(command, cwd=cwd)
	if result.returncode != 0:
		error(
			f"command failed (exit {result.returncode})",
			" ".join(str(c) for c in command),
		)


def assemble(v6asm_path, asm_text, out_bin_path, temp_dir, keep_asm_path=None):
	"""Assemble ``asm_text`` into a raw binary at ``out_bin_path`` using v6asm.

	``temp_dir`` is used for the intermediate ``.asm`` file unless
	``keep_asm_path`` is given, in which case the ASM is written there and kept
	(used by the ``--emit-asm`` debug option).
	"""
	os.makedirs(temp_dir, exist_ok=True)
	os.makedirs(os.path.dirname(out_bin_path) or ".", exist_ok=True)

	if keep_asm_path:
		os.makedirs(os.path.dirname(keep_asm_path) or ".", exist_ok=True)
		asm_path = keep_asm_path
	else:
		asm_path = os.path.join(temp_dir, "asmgen_tmp" + consts.EXT_ASM)

	with open(asm_path, "w", encoding="ascii") as f:
		f.write(asm_text)

	run([v6asm_path, asm_path, "-o", out_bin_path])

	if not os.path.isfile(out_bin_path):
		error(f"v6asm did not produce a binary: {out_bin_path}")

	# Pad the blob to an even (word-aligned) length, matching the layout the
	# Z80 runtime expects when copying data in 16-bit words.
	if os.path.getsize(out_bin_path) % 2 != 0:
		with open(out_bin_path, "ab") as f:
			f.write(b"\x00")

	if keep_asm_path is None:
		try:
			os.remove(asm_path)
		except OSError:
			pass

	return os.path.getsize(out_bin_path)


def meta_asm(bin_path, body=""):
	"""Build the contents of a ``*_meta.asm`` file for a blob.

	The blob is referenced by its final stored path (``bin_path``); the
	``.filesize`` directive is resolved by the main build when the file exists.
	``body`` is the exporter-specific block of pointers/constants.
	"""
	source_name = _basename_no_ext(bin_path)
	upper = source_name.upper()
	fname = os.path.basename(bin_path).split(".")
	name_part = fname[0]
	ext_part = fname[1] if len(fname) > 1 else ""

	asm = "; fdd blob metadata (linked into the main program)\n"
	asm += f"; blob file: {bin_path}\n\n"
	asm += f'{upper}_FILE_LEN .filesize "{bin_path}"\n'
	asm += f"{upper}_LAST_RECORD_LEN = {upper}_FILE_LEN & 0x7f\n\n"

	asm += f"{upper}_FILENAME_PTR:\n"
	asm += f'			.byte "{name_part}" ; filename\n'
	if len(name_part) < consts.CPM_FILENAME_LEN:
		pad = " " * (consts.CPM_FILENAME_LEN - len(name_part))
		asm += f'			.byte "{pad}" ; filename padding\n'
	asm += f'			.byte "{ext_part}" ; extension\n\n'

	asm += body
	return asm


def _basename_no_ext(path):
	return os.path.splitext(os.path.basename(path))[0]
