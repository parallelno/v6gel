"""v6loads - RAM Disk layout and FDD load-routine generator.

Consumes a build config JSON plus the per-asset manifests emitted by
``v6export`` and produces the linker-side artefacts:

* ``loads.asm``          - per-load file-load tables and init/uninit routines
* ``build_includes.asm`` - includes every asset ``*_meta.asm`` + loads.asm
* ``code_consts.asm``    - config consts + RAM Disk reservations
* ``build_consts.asm``   - wrapper that includes code_consts.asm
* ``autoexec`` (.bat)    - CP/M autoexec for the produced COM

This is a faithful port of the old ``export_config_utils`` + ``export_config``
orchestration, with staleness checking removed and asset placement driven by
the manifests (``ram_disk_after_stack`` / ``ram_disk_align``) instead of
hard-coded config type lists.
"""

from __future__ import annotations

import argparse
import os
import sys

# Allow running both as "python scripts/v6loads.py" and "python -m v6loads".
_SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
if _SCRIPTS_DIR not in sys.path:
	sys.path.insert(0, _SCRIPTS_DIR)

from utils import common, consts
from utils.log import ExportError, TextColor, error, printc
from exporters.context import AssetManifest


# ---------------------------------------------------------------------------
# Asset records (built from config "loads" grouping + manifests)
# ---------------------------------------------------------------------------
def _collect_assets(config_j, manifest_dir):
	"""Build the flat asset list the packer/codegen operate on."""
	special_types = config_j.get("loaded_after_stack", [])
	types_alignment = config_j.get("types_alignment", {})
	assets = []
	for load_name, asset_paths in config_j["loads"].items():
		for asset_path in asset_paths:
			name = common.path_to_basename(asset_path)
			manifest_path = os.path.join(manifest_dir, name + consts.EXT_MANIFEST)
			if not os.path.exists(manifest_path):
				error("manifest not found", manifest_path)
			manifest = AssetManifest.read(manifest_path)

			if not os.path.exists(manifest.bin_path):
				error("asset blob not found", manifest.bin_path)

			asset_type = manifest.asset_type
			after_stack = asset_type in special_types
			align = types_alignment.get(asset_type, consts.WORD_LEN)

			assets.append({
				"type": asset_type,
				"load_name": load_name,
				"name": name,
				"bin_path": manifest.bin_path,
				"asm_meta_path": manifest.meta_asm_path,
				"asset_j_path": asset_path,
				"len": manifest.bin_len,
				"after_stack": after_stack,
				"align": align,
			})
	return assets


# ---------------------------------------------------------------------------
# RAM Disk layout / packing
# ---------------------------------------------------------------------------
def get_ram_disk_layout(config_j):
	segments = {}
	for bank_idx in range(consts.RAM_DISK_BANKS_MAX):
		# segment before the stack
		seg_name0 = f"bank{bank_idx} addr0"
		segments[seg_name0] = {
			"bank_idx": bank_idx,
			"start_addr": 0,
			"load_addr": 0,
			"non_permanent_load_addr": 0,
			"len": consts.RAM_DISK_SEGMENT_LEN - consts.ALL_STACKS_LEN,
		}

		# segment after the stack
		seg_name1 = f"bank{bank_idx} addr8000"
		seg_len1 = consts.RAM_DISK_SEGMENT_LEN
		reservation = next(
			(x for x in config_j["ram_disk_reserve"] if x["bank_idx"] == bank_idx), None
		)
		if reservation is not None and "len" in reservation:
			seg_len1 -= common.hex_str_to_int(reservation["len"])

		segments[seg_name1] = {
			"bank_idx": bank_idx,
			"start_addr": consts.SCR_ADDR,
			"load_addr": consts.SCR_ADDR,
			"non_permanent_load_addr": consts.SCR_ADDR,
			"len": seg_len1,
		}

	return segments


def pack_files(load_name, assets, segments):
	special = []
	regular = []
	for asset in assets:
		if asset["load_name"] != load_name:
			continue
		(special if asset["after_stack"] else regular).append(asset)

	# Sort by size descending (largest first).
	special = sorted(special, key=lambda x: x["len"], reverse=True)
	regular = sorted(regular, key=lambda x: x["len"], reverse=True)

	seg_space = {}
	for seg_name, seg in segments.items():
		reserved = seg["non_permanent_load_addr"] - seg["start_addr"]
		seg_space[seg_name] = seg["len"] - reserved

	allocation = {seg_name: [] for seg_name in segments}
	after_stack_segs = [
		name for name, s in segments.items() if s["start_addr"] == consts.SCR_ADDR
	]

	# Step 1: place after-stack-only files in the high segments.
	for asset in special:
		placed = False
		for seg_name in sorted(after_stack_segs, key=lambda x: seg_space[x], reverse=True):
			align = asset["align"]
			alignment_offset = (align - segments[seg_name]["load_addr"] % align) % align
			if asset["len"] + alignment_offset <= seg_space[seg_name]:
				asset["addr"] = segments[seg_name]["load_addr"] + alignment_offset
				segments[seg_name]["load_addr"] += asset["len"] + alignment_offset
				allocation[seg_name].append(asset)
				seg_space[seg_name] -= asset["len"] + alignment_offset
				placed = True
				break
		if not placed:
			return None, None, (
				"can't fit after-stack files into the high segments. "
				f"bin_path:{asset['bin_path']}"
			)

	# Step 2: place regular files into any segment (tightest fit first).
	for asset in regular:
		placed = False
		for seg_name in sorted(seg_space.keys(), key=lambda x: seg_space[x]):
			if asset["len"] <= seg_space[seg_name]:
				asset["addr"] = segments[seg_name]["load_addr"]
				segments[seg_name]["load_addr"] += asset["len"]
				allocation[seg_name].append(asset)
				seg_space[seg_name] -= asset["len"]
				placed = True
				break
		if not placed:
			return None, None, (
				f"can't fit file into the RAM Disk. bin_path:{asset['bin_path']}"
			)

	free_space = sum(seg_space.values())
	return allocation, free_space, None


# ---------------------------------------------------------------------------
# Code generation
# ---------------------------------------------------------------------------
def get_usage_report(load_name, allocation, free_space, segments):
	total_used = 0
	report = f"### `{load_name}` RAM Disk usage:\n"
	total_reserved = 0
	seg_report = ""
	for seg_name, seg in allocation.items():
		seg_report += f"- {seg_name}\n"
		used_len = 0
		for asset in seg:
			bin_file_name = os.path.basename(asset["bin_path"])
			seg_report += (
				f"	* {bin_file_name}: addr: {asset['addr']}, len: `{asset['len']}`\n"
			)
			used_len += asset["len"]

		non_perm_load_addr = segments[seg_name]["non_permanent_load_addr"]
		start_addr = segments[seg_name]["start_addr"]
		reserved = non_perm_load_addr - start_addr
		total_reserved += reserved

		free = segments[seg_name]["len"] - used_len - reserved
		seg_report += "\n"
		seg_report += f"  `Used: {used_len}, Free: {free}`\n\n"
		total_used += used_len

	report += "\n"
	report += f"> Used: `{total_used}`, Free Space: `{free_space}`\n\n"
	report += seg_report
	report += "\n---\n"
	return report


def get_load_asm(load_name, allocation, segments):
	asm = ";===============================================\n"
	asm += f"; {load_name}\n"
	asm += ";===============================================\n"

	load_params = []
	asm_load_consts = ""
	asm_load_init = ""
	asm_load_uninit = ""
	sprite_label_init_params = []

	for seg_name, seg in allocation.items():
		for asset in seg:
			bank_idx = segments[seg_name]["bank_idx"]
			NAME = common.path_to_basename(asset["bin_path"]).upper()
			name_low = asset["name"]

			const_ram_disk_m = f"{load_name.upper()}_{NAME}_RAM_DISK_M"
			const_ram_disk_s = f"{load_name.upper()}_{NAME}_RAM_DISK_S"
			global_addr_label = f"{load_name.upper()}_{NAME}_ADDR"
			asset_addr = asset["addr"]
			asset_addr_s = f"0x{asset_addr:04X}"
			negative_global_addr_label = (
				f"$ffff - {global_addr_label} + 1" if asset_addr > 0 else "0 ; global offset"
			)

			asm_load_consts += f"			{const_ram_disk_m} = RAM_DISK_M{bank_idx}\n"
			asm_load_consts += f"			{const_ram_disk_s} = RAM_DISK_S{bank_idx}\n"
			asm_load_consts += f"			{global_addr_label} = {asset_addr_s}\n\n"

			load_params.append(
				[f"{NAME}_FILENAME_PTR", const_ram_disk_s, global_addr_label, f"{NAME}_FILE_LEN"]
			)

			asset_type = asset["type"]
			if asset_type == consts.ASSET_TYPE_FONT:
				asm_load_init += f"			mvi a, {const_ram_disk_s}\n"
				asm_load_init += f"			lxi h, {name_low}_gfx_ptrs\n"
				asm_load_init += f"			lxi b, {global_addr_label}\n"
				asm_load_init += "			call text_ex_init_font\n\n"

				asm_load_uninit += f"			mvi a, {const_ram_disk_s}\n"
				asm_load_uninit += f"			lxi h, {name_low}_gfx_ptrs\n"
				asm_load_uninit += f"			lxi b, {negative_global_addr_label}\n"
				asm_load_uninit += "			call text_ex_init_font\n\n"

			elif asset_type in (consts.ASSET_TYPE_TEXT_ENG, consts.ASSET_TYPE_TEXT_RUS):
				asm_load_init += f"			mvi a, {const_ram_disk_s}\n"
				asm_load_init += f"			lxi h, {global_addr_label}\n"
				asm_load_init += "			call text_ex_init_text\n\n"

			elif asset_type == consts.ASSET_TYPE_MUSIC:
				asm_load_init += f"			lxi d, {global_addr_label}\n"
				asm_load_init += f"			lxi h, {name_low}_ay_reg_data_ptrs\n"
				asm_load_init += "			call v6_gc_init_song\n\n"

				asm_load_uninit += f"			lxi d, {negative_global_addr_label}\n"
				asm_load_uninit += f"			lxi h, {name_low}_ay_reg_data_ptrs\n"
				asm_load_uninit += "			call v6_gc_init_song\n\n"

			elif asset_type in (consts.ASSET_TYPE_LEVEL_DATA, consts.ASSET_TYPE_LEVEL_GFX):
				asm_load_init += f"			lxi h, {const_ram_disk_m}<<8 | {const_ram_disk_s}\n"
				asm_load_init += f"			lxi b, {global_addr_label}\n"
				asm_load_init += f"			call {name_low}_init\n\n"

				asm_load_uninit += f"			lxi h, {const_ram_disk_m}<<8 | {const_ram_disk_s}\n"
				asm_load_uninit += f"			lxi b, {negative_global_addr_label}\n"
				asm_load_uninit += f"			call {name_low}_init\n\n"

			elif asset_type in (consts.ASSET_TYPE_SPRITE, consts.ASSET_TYPE_BACK):
				sprite_label_init_params.append(
					[f"{name_low}_ram_disk_s_cmd", const_ram_disk_s, global_addr_label]
				)

			elif asset_type == consts.ASSET_TYPE_TILED_IMG_DATA:
				asm_load_init += f"			mvi a, {const_ram_disk_s}\n"
				asm_load_init += f"			lxi h, {global_addr_label}\n"
				asm_load_init += "			call tiled_img_init_idxs\n\n"

				asm_load_uninit += f"			mvi a, {const_ram_disk_s}\n"
				asm_load_uninit += f"			lxi h, {negative_global_addr_label}\n"
				asm_load_uninit += "			call tiled_img_init_idxs\n\n"

			elif asset_type == consts.ASSET_TYPE_TILED_IMG_GFX:
				asm_load_init += f"			mvi a, {const_ram_disk_s}\n"
				asm_load_init += f"			lxi h, {global_addr_label}\n"
				asm_load_init += "			call tiled_img_init_gfx\n\n"

				asm_load_uninit += f"			mvi a, {const_ram_disk_s}\n"
				asm_load_uninit += f"			lxi h, {negative_global_addr_label}\n"
				asm_load_uninit += "			call tiled_img_init_gfx\n\n"

			elif asset_type == consts.ASSET_TYPE_DECAL:
				if asset_addr != 0:
					asm_load_init += f"			lxi h, {name_low}_gfx_ptrs\n"
					asm_load_init += f"			lxi b, {global_addr_label}\n"
					asm_load_init += "			call add_offset_to_labels_eod\n\n"

					asm_load_uninit += f"			lxi h, {name_low}_gfx_ptrs\n"
					asm_load_uninit += f"			lxi b, {negative_global_addr_label}\n"
					asm_load_uninit += "			call add_offset_to_labels_eod\n\n"

	asm += asm_load_consts + "\n"

	param_label = f"load_{load_name}_load_params"
	asm += f"{param_label}:\n"
	for filename_ptr, command, dest, file_len in load_params:
		asm += f"			FILE_LOAD_PARAMS({filename_ptr}, {command}, {dest}, {file_len})\n"
	asm += "\n"

	sprite_label_init_label = f"load_{load_name}_sprite_init_data"
	asm += f"{sprite_label_init_label}:\n"
	for ram_disk_cmd_ptr, ram_disk_s_cmd, sprite_gfx_addr in sprite_label_init_params:
		asm += f"			.word {ram_disk_cmd_ptr}\n"
		asm += f"			.byte {ram_disk_s_cmd} | RAM_DISK_M_BACKBUFF | RAM_DISK_M_8F\n"
		asm += f"			.word {sprite_gfx_addr}\n"
	asm += "\n"

	# Load + init.
	asm += f"load_{load_name}:\n"
	asm += f"			lxi h, {param_label}\n"
	asm += f"			mvi e, {len(load_params)}\n"
	asm += "			call load_files_from_params\n\n"

	if len(sprite_label_init_params) > 0:
		asm += f"			lxi h, {sprite_label_init_label}\n"
		asm += f"			mvi e, {len(sprite_label_init_params)}\n"
		asm += "			call sprite_init_meta_data\n\n"

	asm += asm_load_init
	asm += "			ret\n\n"

	# Uninit.
	asm += f"uninit_{load_name}:\n"
	if len(sprite_label_init_params) > 0:
		asm += f"			lxi h, {sprite_label_init_label}\n"
		asm += f"			mvi e, {len(sprite_label_init_params)}\n"
		asm += "			call sprite_uninit_meta_data\n\n"

	asm += asm_load_uninit
	asm += "			ret\n"

	return asm


def export_loads(config_j, assets, build_code_dir):
	load_path = os.path.join(build_code_dir, "loads" + consts.EXT_ASM)
	if os.path.exists(load_path):
		os.remove(load_path)

	segments = get_ram_disk_layout(config_j)

	asm = "memusage_loads:\n"
	report_asm = ""

	loads = dict(config_j["loads"])

	# permanent load first; its allocation reserves space in every following load.
	perm_load_name = config_j.get("permanent_load_name")
	perm_load = loads.get(perm_load_name)
	if perm_load:
		loads.pop(perm_load_name)
		allocation, free_space, error_s = pack_files(perm_load_name, assets, segments)
		if error_s:
			error(error_s)
		report_asm += get_usage_report(perm_load_name, allocation, free_space, segments)
		asm += get_load_asm(perm_load_name, allocation, segments)

	# the free space after the permanent load becomes each load's baseline.
	for seg in segments.values():
		seg["non_permanent_load_addr"] = seg["load_addr"]

	for load_name in loads:
		allocation, free_space, error_s = pack_files(load_name, assets, segments)
		if error_s:
			error(error_s)
		report_asm += get_usage_report(load_name, allocation, free_space, segments)
		asm += get_load_asm(load_name, allocation, segments)
		# reset each segment's load_addr back to the post-permanent baseline.
		for seg in segments.values():
			seg["load_addr"] = seg["non_permanent_load_addr"]

	asm += "memusage_loads_end:\n"

	with open(load_path, "w", encoding="ascii") as f:
		f.write(asm)

	return load_path, report_asm


def export_build_includes(assets, extra_includes, build_dir):
	build_include_path = os.path.join(build_dir, "build_includes" + consts.EXT_ASM)
	if os.path.exists(build_include_path):
		os.remove(build_include_path)

	build_include = ""
	already_included = set()
	for asset in assets:
		asm_path = asset["asm_meta_path"]
		if asm_path not in already_included:
			memusage_name = os.path.basename(asm_path).split(".")[0]
			build_include += f"@memusage_{memusage_name}:\n"
			build_include += f'.include "{asm_path.replace(os.sep, "/")}"\n'
			already_included.add(asm_path)
	build_include += "\n"

	for include_path in extra_includes:
		build_include += f'.include "{include_path.replace(os.sep, "/")}"\n'
	build_include += "\n"

	with open(build_include_path, "w", encoding="ascii") as f:
		f.write(build_include)
	return build_include_path


def export_build_consts(config_j, build_dir, build_code_dir):
	build_consts_path = os.path.join(build_dir, "build_consts" + consts.EXT_ASM)
	code_consts_path = os.path.join(build_code_dir, "code_consts" + consts.EXT_ASM)

	with open(build_consts_path, "w", encoding="ascii") as f:
		f.write(f'.include "{code_consts_path.replace(os.sep, "/")}"\n')

	asm = "; Config consts:\n"
	for const in config_j["consts"]:
		asm += const + "\n"
	asm += "\n"

	asm += "; RAM Disk reserved blocks:\n"
	for reservation in config_j["ram_disk_reserve"]:
		idx = reservation["bank_idx"]
		asm += f"RAM_DISK_M_{reservation['name']} = RAM_DISK_M{idx}\n"
		asm += f"RAM_DISK_S_{reservation['name']} = RAM_DISK_S{idx}\n"

	with open(code_consts_path, "w", encoding="ascii") as f:
		f.write(asm)
	return code_consts_path


def export_autoexec(com_filename, autoexec_path):
	if os.path.exists(autoexec_path):
		os.remove(autoexec_path)
	with open(autoexec_path, "w", encoding="ascii") as f:
		f.write("A:\n")
		f.write(com_filename + "\n")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def parse_args(argv):
	p = argparse.ArgumentParser(
		prog="v6loads",
		description="Generate RAM Disk layout, FDD load routines, consts and includes.",
	)
	p.add_argument("config", help="build config JSON (asset_type=config)")
	p.add_argument("--manifest-dir", required=True, help="dir with <name>.manifest.json files")
	p.add_argument("-o", "--code-dir", required=True, help="output dir for code_consts.asm/loads.asm")
	p.add_argument("--build-dir", help="output dir for build_includes.asm/build_consts.asm (default: code-dir)")
	p.add_argument("--bin-dir", help="output dir for the autoexec file (default: code-dir)")
	p.add_argument("--com-name", default="APP.COM", help="CP/M COM name written into autoexec")
	return p.parse_args(argv)


def main(argv=None):
	args = parse_args(argv if argv is not None else sys.argv[1:])

	config_j = common.load_json(args.config)
	if config_j.get("asset_type") != consts.ASSET_TYPE_CONFIG:
		printc(
			f"v6loads ERROR: asset_type != '{consts.ASSET_TYPE_CONFIG}': {args.config}",
			TextColor.RED,
		)
		return 1

	code_dir = args.code_dir
	build_dir = args.build_dir or code_dir
	bin_dir = args.bin_dir or code_dir
	os.makedirs(code_dir, exist_ok=True)
	os.makedirs(build_dir, exist_ok=True)
	os.makedirs(bin_dir, exist_ok=True)

	try:
		assets = _collect_assets(config_j, args.manifest_dir)

		loads_path, report = export_loads(config_j, assets, code_dir)
		export_build_includes(assets, [loads_path], build_dir)
		export_build_consts(config_j, build_dir, code_dir)
		export_autoexec(args.com_name, os.path.join(bin_dir, "AUTOEXEC.BAT"))
	except ExportError as e:
		printc(f"v6loads ERROR: {e}", TextColor.RED)
		if e.detail:
			printc(f"  {e.detail}", TextColor.RED)
		return 1

	printc(f"v6loads: generated loads for {len(assets)} assets -> {loads_path}", TextColor.GREEN)
	return 0


if __name__ == "__main__":
	sys.exit(main())
