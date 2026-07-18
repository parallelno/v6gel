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

import v6gel.exporters as exporters
from v6gel.exporters.context import ExportContext
from v6gel.utils import asmgen, consts, tools
from v6gel.utils.log import ExportError, TextColor, printc


def parse_args(argv=None):
	parser = argparse.ArgumentParser(
		prog="v6export",
		description="Export a v6 asset described by its meta JSON file.",
	)
	parser.add_argument("meta", help="path to the asset meta JSON file")
	parser.add_argument(
		"-o", "--out-dir", default=None,
		help="directory for generated ASM files (default: <meta file dir>/asm)",
	)
	parser.add_argument(
		"--manifest-dir", default=None,
		help="directory for <name>.manifest.json (default: sibling manifests dir)",
	)
	parser.add_argument(
		"--bin-dir", default=None,
		help="directory for the .bin blob (default: out-dir)",
	)
	parser.add_argument(
		"--asm", dest="v6asm", default=None,
		help="path to the v6asm assembler (default: $V6ASM, tools/v6asm/, or PATH)",
	)
	parser.add_argument(
		"--packer", default=None,
		help="zx0 packer command for format-intrinsic compression "
			"(default: $ZX0, tools/zx0/, or PATH)",
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
		"--emit-obj", action="store_true",
		help="also assemble a linkable object file <name>.o that embeds the blob",
	)
	parser.add_argument(
		"--obj-dir", default=None,
		help="directory for the .o object file (default: bin-dir)",
	)
	parser.add_argument(
		"--emit-filename", action="store_true",
		help="include the FILENAME_PTR block in *_meta.asm (needed when "
			"the blob is loaded from an FDD; omitted by default for ROM inclusion)",
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
	parser.add_argument(
		"--compress", action="store_true",
		help="transport-compress the .bin with zx0 after export; the compressed "
			"file (default extension .zx0, overridable via --stored-ext) is what "
			"gets embedded in the .o object file and referenced in *_meta.asm",
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

	asset_dir = os.path.dirname(os.path.abspath(args.meta))
	out_dir = args.out_dir or os.path.join(asset_dir, "asm")
	manifest_dir = args.manifest_dir or os.path.join(os.path.dirname(out_dir), "manifests")
	bin_dir = args.bin_dir or out_dir
	os.makedirs(out_dir, exist_ok=True)
	os.makedirs(manifest_dir, exist_ok=True)
	os.makedirs(bin_dir, exist_ok=True)

	name = os.path.splitext(os.path.basename(args.meta))[0]

	stored_ext = args.stored_ext
	if args.compress and stored_ext == consts.EXT_BIN:
		stored_ext = consts.EXT_ZX0
	if stored_ext and not stored_ext.startswith("."):
		stored_ext = "." + stored_ext

	return ExportContext(
		meta_path=args.meta,
		meta=meta,
		asset_type=asset_type,
		name=name,
		out_dir=out_dir,
		manifest_dir=manifest_dir,
		bin_dir=bin_dir,
		v6asm_path=tools.resolve_v6asm(args.v6asm),
		packer_path=tools.resolve_zx0(args.packer),
		emit_asm=args.emit_asm,
		emit_obj=args.emit_obj,
		obj_dir=args.obj_dir,
		emit_filename=args.emit_filename,
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
		if args.compress:
			asmgen.run([*ctx.packer_path.split(), ctx.bin_path, ctx.stored_path])
		if ctx.emit_obj:
			obj_path = ctx.obj_path
			keep_obj_asm = (
				os.path.join(ctx.out_dir, ctx.name + "_obj" + consts.EXT_ASM)
				if ctx.emit_asm else None
			)
			asmgen.assemble_obj(
				ctx.v6asm_path, ctx.name, ctx.stored_path, obj_path, ctx.temp_dir,
				keep_asm_path=keep_obj_asm,
			)
			manifest.obj_path = obj_path
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
