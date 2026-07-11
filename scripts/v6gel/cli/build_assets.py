#!/usr/bin/env python3
"""build_assets.py - thin asset build driver for the v6 toolchain.

Wires the standalone CLI tools together for a whole build config:

  for each asset listed in the config "loads":
      v6export   -> <name>.bin (+ _meta.asm + manifest)
      zx0        -> <name>.com  (transport compression, optional)
  v6loads        -> loads.asm / code_consts.asm / build_includes.asm / autoexec
  v6fdd          -> <config>.fdd  (template + the stored blobs + autoexec)

The driver itself contains no asset-format logic; it only orchestrates the
tools. Up-to-date checking is intentionally not performed here - run it when
assets change (a Makefile / outer script may gate it).
"""

import argparse
import os
import sys

_SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
if _SCRIPTS_DIR not in sys.path:
	sys.path.insert(0, _SCRIPTS_DIR)

import v6export
import v6loads
from utils import asmgen, common, consts, tools
from utils.log import ExportError, TextColor, printc


def _unique_asset_paths(config_j):
	"""Flatten config["loads"] into a de-duplicated list of asset JSON paths."""
	seen = set()
	ordered = []
	for asset_paths in config_j["loads"].values():
		for asset_path in asset_paths:
			if asset_path not in seen:
				seen.add(asset_path)
				ordered.append(asset_path)
	return ordered


def _resolve_asset(asset_path, config_dir):
	"""Resolve an asset path that may be relative to cwd or to the config dir."""
	if os.path.isfile(asset_path):
		return asset_path
	candidate = os.path.join(config_dir, asset_path)
	if os.path.isfile(candidate):
		return candidate
	# fall back to the cwd-relative path so the error names what was expected
	return asset_path


def parse_args(argv):
	p = argparse.ArgumentParser(
		prog="build_assets",
		description="Export all assets of a build config and pack them into an FDD.",
	)
	p.add_argument("config", help="build config JSON (asset_type=config)")
	p.add_argument("-o", "--out-dir", default="build/release", help="build output root")
	p.add_argument("--asm", default=None, help="path to v6asm (default: $V6ASM, tools/v6asm/, or PATH)")
	p.add_argument("--packer", default=None, help="zx0 packer command (default: $ZX0, tools/zx0/, or PATH)")
	p.add_argument("--v6fdd", default=None, help="path to v6fdd (default: $V6FDD, tools/v6asm/, or PATH)")
	p.add_argument("--fdd-template", default=None, help="template/boot FDD image (-t)")
	p.add_argument("--transport", action="store_true",
				help="transport-compress each blob (.bin->.com) before storing on the "
					"FDD; the runtime must decompress on load. Off by default: blobs "
					"are stored raw (their format-intrinsic compression is already "
					"applied by the exporter).")
	p.add_argument("--emit-asm", action="store_true", help="also keep *_data.asm (debug)")
	return p.parse_args(argv)


def _transport_compress(packer_path, bin_path, com_path):
	"""Whole-file zx0 compression of a blob for FDD storage."""
	if os.path.exists(com_path):
		os.remove(com_path)
	asmgen.run([*packer_path.split(), bin_path, com_path])
	if not os.path.isfile(com_path):
		raise ExportError(f"transport compression produced no file: {com_path}")


def main(argv=None):
	args = parse_args(argv if argv is not None else sys.argv[1:])

	config_j = common.load_json(args.config)
	if config_j.get("asset_type") != consts.ASSET_TYPE_CONFIG:
		printc(f"build_assets ERROR: asset_type != '{consts.ASSET_TYPE_CONFIG}': {args.config}",
			TextColor.RED)
		return 1

	config_dir = os.path.dirname(os.path.abspath(args.config))
	config_name = common.path_to_basename(args.config)

	out_dir = args.out_dir
	meta_dir = os.path.join(out_dir, "meta")
	bin_dir = os.path.join(out_dir, "bin")
	code_dir = os.path.join(out_dir, "code")
	for d in (meta_dir, bin_dir, code_dir):
		os.makedirs(d, exist_ok=True)

	transport = args.transport
	stored_ext = consts.EXT_COM if transport else consts.EXT_BIN

	try:
		args.asm = tools.resolve_v6asm(args.asm)
		args.packer = tools.resolve_zx0(args.packer)
		args.v6fdd = tools.resolve_v6fdd(args.v6fdd)

		# --- per-asset export (+ transport compression) ---
		stored_files = []
		for asset_path in _unique_asset_paths(config_j):
			meta_path = _resolve_asset(asset_path, config_dir)
			export_argv = [
				meta_path,
				"-o", meta_dir,
				"--bin-dir", bin_dir,
				"--asm", args.asm,
				"--packer", args.packer,
				"--stored-ext", stored_ext,
			]
			if args.emit_asm:
				export_argv.append("--emit-asm")
			if v6export.main(export_argv) != 0:
				return 1

			name = common.path_to_basename(asset_path)
			bin_path = os.path.join(bin_dir, asmgen.cpm_filename(name, consts.EXT_BIN))
			stored_path = os.path.join(bin_dir, asmgen.cpm_filename(name, stored_ext))
			if transport:
				_transport_compress(args.packer, bin_path, stored_path)
				printc(f"build_assets: transport-compressed {os.path.basename(stored_path)} "
					f"({os.path.getsize(stored_path)} bytes)", TextColor.GRAY)
			stored_files.append(stored_path)

		# --- loads / consts / includes / autoexec ---
		loads_argv = [
			args.config,
			"--manifest-dir", meta_dir,
			"-o", code_dir,
			"--bin-dir", bin_dir,
			"--com-name", asmgen.cpm_filename("app", consts.EXT_COM),
		]
		if v6loads.main(loads_argv) != 0:
			return 1
		autoexec_path = os.path.join(bin_dir, "AUTOEXEC.BAT")

		# --- FDD image ---
		fdd_path = os.path.join(out_dir, config_name + consts.EXT_FDD)
		fdd_cmd = [args.v6fdd]
		if args.fdd_template:
			fdd_cmd += ["-t", args.fdd_template]
		for stored in stored_files:
			fdd_cmd += ["-i", stored]
		if os.path.exists(autoexec_path):
			fdd_cmd += ["-i", autoexec_path]
		fdd_cmd += ["-o", fdd_path]
		asmgen.run(fdd_cmd)
		printc(f"build_assets: wrote FDD image -> {fdd_path}", TextColor.GREEN)

	except ExportError as e:
		printc(f"build_assets ERROR: {e}", TextColor.RED)
		if e.detail:
			printc(f"  {e.detail}", TextColor.GRAY)
		return 1

	printc(f"build_assets: done ({len(stored_files)} assets).", TextColor.GREEN)
	return 0


if __name__ == "__main__":
	sys.exit(main())
