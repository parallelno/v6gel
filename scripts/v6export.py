#!/usr/bin/env python3
"""v6export — unified asset export CLI.

Reads an asset meta JSON (e.g. ``assets/music/song01.json``), dispatches to the
exporter for its ``asset_type`` and produces, by default:

* ``<name>.bin``           the raw data blob (later transport-compressed and
                            stored on the FDD image), and
* ``<name>_meta.asm``      the metadata linked into the main program, and
* ``<name>.manifest.json`` a placement-agnostic record consumed by ``v6loads``.

With ``--emit-asm`` the human-readable ``<name>_data.asm`` (the source the blob
is assembled from) is also kept, for debugging.

This tool performs no up-to-date / staleness checking; the outer build driver
decides whether an asset needs re-exporting.
"""

import argparse
import json
import os
import sys

# Allow running both as "python scripts/v6export.py" and from the scripts dir.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import exporters
from exporters.context import ExportContext
from utils import consts
from utils.log import ExportError, TextColor, printc

DEFAULT_V6ASM = r"C:\Work\Programming\v6asm\target\release\v6asm"
DEFAULT_PACKER = r"C:\Work\Programming\v6\tools\zx0\zx0salvador.exe -classic"


def parse_args(argv=None):
	parser = argparse.ArgumentParser(
		prog="v6export",
		description="Export a v6 asset described by its meta JSON file.",
	)
	parser.add_argument("meta", help="path to the asset meta JSON file")
	parser.add_argument(
		"-o", "--out-dir", default=None,
		help="directory for *_meta.asm / manifest (default: meta file dir)",
	)
	parser.add_argument(
		"--bin-dir", default=None,
		help="directory for the .bin blob (default: out-dir)",
	)
	parser.add_argument(
		"--asm", dest="v6asm", default=DEFAULT_V6ASM,
		help="path to the v6asm assembler",
	)
	parser.add_argument(
		"--packer", default=DEFAULT_PACKER,
		help="zx0 packer command for format-intrinsic compression",
	)
	parser.add_argument(
		"--temp", dest="temp_dir", default="build/temp/",
		help="scratch directory for intermediate files",
	)
	parser.add_argument(
		"--emit-asm", action="store_true",
		help="also keep the human-readable <name>_data.asm (debug)",
	)
	parser.add_argument(
		"--stored-ext", dest="stored_ext", default=consts.EXT_BIN,
		help="extension of the file actually stored on the FDD that the linked "
			"meta should reference, e.g. '.com' when transport-compressing "
			"(default: .bin)",
	)
	parser.add_argument(
		"--type", dest="asset_type", default=None,
		help="override the asset_type read from the meta JSON",
	)
	return parser.parse_args(argv)


def build_context(args):
	if not os.path.isfile(args.meta):
		raise ExportError(f"asset meta file not found: {args.meta}")

	with open(args.meta, "rb") as f:
		meta = json.load(f)

	asset_type = args.asset_type or meta.get("asset_type")
	if not asset_type:
		raise ExportError(f'no "asset_type" in {args.meta}')

	out_dir = args.out_dir or os.path.dirname(os.path.abspath(args.meta))
	bin_dir = args.bin_dir or out_dir
	os.makedirs(out_dir, exist_ok=True)
	os.makedirs(bin_dir, exist_ok=True)

	name = os.path.splitext(os.path.basename(args.meta))[0]

	stored_ext = args.stored_ext
	if stored_ext and not stored_ext.startswith("."):
		stored_ext = "." + stored_ext

	return ExportContext(
		meta_path=args.meta,
		meta=meta,
		asset_type=asset_type,
		name=name,
		out_dir=out_dir,
		bin_dir=bin_dir,
		v6asm_path=args.v6asm,
		packer_path=args.packer,
		emit_asm=args.emit_asm,
		temp_dir=args.temp_dir,
		stored_ext=stored_ext,
	)


def main(argv=None):
	args = parse_args(argv)
	try:
		ctx = build_context(args)
		exporter = exporters.get_exporter(ctx.asset_type)
		if exporter is None:
			raise ExportError(
				f'unsupported asset_type "{ctx.asset_type}"',
				"supported: " + ", ".join(exporters.supported_types()),
			)

		manifest = exporter(ctx)
		manifest.write(ctx.manifest_path)

		printc(
			f"v6export: {ctx.name} ({ctx.asset_type}) -> "
			f"{os.path.relpath(ctx.bin_path)} ({manifest.bin_len} bytes)",
			TextColor.GREEN,
		)
		return 0
	except ExportError as err:
		printc(f"v6export ERROR: {err}", TextColor.RED)
		if err.detail:
			printc(f"  detail: {err.detail}", TextColor.GRAY)
		return 1


if __name__ == "__main__":
	sys.exit(main())
