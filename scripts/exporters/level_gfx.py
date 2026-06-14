"""Level graphics exporter: palette plus 16x16 level tile bitmaps.

Faithful port of the original ``export_level_gfx``.
"""

import json
from pathlib import Path

from PIL import Image

from utils import asmgen, common, common_gfx, consts
from exporters import level_common
from exporters.context import AssetManifest, ExportContext


def export(ctx: ExportContext) -> AssetManifest:
	level_j_path = ctx.asset_rel("path_level")

	data_asm, relative_ptrs, remap_idxs = _ram_disk_data_to_asm(level_j_path)
	meta_body = _ram_data_to_asm(level_j_path, relative_ptrs, remap_idxs)

	keep_asm = ctx.data_asm_path if ctx.emit_asm else None
	bin_len = asmgen.assemble(
		ctx.v6asm_path, data_asm, ctx.bin_path, ctx.temp_dir, keep_asm
	)
	with open(ctx.meta_asm_path, "w", encoding="ascii") as f:
		f.write(asmgen.meta_asm(ctx.stored_path, meta_body))

	return AssetManifest(
		name=ctx.name,
		asset_type=consts.ASSET_TYPE_LEVEL_GFX,
		bin_path=ctx.bin_path,
		bin_len=bin_len,
		meta_asm_path=ctx.meta_asm_path,
		data_asm_path=keep_asm,
	)


def _ram_disk_data_to_asm(level_j_path):
	level_j = common.load_json(level_j_path)
	level_name = common.path_to_basename(level_j_path)
	level_dir = str(Path(level_j_path).parent) + "/"

	asm = ""
	relative_ptrs = {}
	local_addrs = consts.SAFE_WORD_LEN

	# --- palette ---
	path_png = level_dir + level_j["path_png"]
	image = Image.open(path_png)
	palette_asm, colors, palette_label, palette_len = common_gfx.palette_file_to_asm(
		level_dir + level_j["palette_path"], path_png, "_" + level_name
	)
	asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
	asm += f"{palette_label}_relative:\n"
	asm += palette_asm + "\n"
	relative_ptrs[palette_label + "_relative"] = local_addrs
	local_addrs += palette_len

	# --- tile bitmaps ---
	image = common_gfx.remap_colors(image, colors)
	room_paths = level_j["rooms"]
	rooms_j = []
	for room_path_p in room_paths:
		with open(level_dir + room_path_p["path"], "rb") as f:
			rooms_j.append(json.load(f))

	remap_idxs = level_common.remap_index(rooms_j)
	png_name = common.path_to_basename(path_png)

	gfx_asm, gfx_ptrs, gfx_data_len = _gfx_to_asm(
		rooms_j[0], image, path_png, remap_idxs, "_" + png_name
	)
	asm += gfx_asm
	for label_name, gfx_ptr in gfx_ptrs.items():
		relative_ptrs[label_name] = gfx_ptr + local_addrs
	local_addrs += gfx_data_len

	return asm, relative_ptrs, remap_idxs


def _ram_data_to_asm(level_j_path, relative_ptrs, remap_idxs):
	level_j = common.load_json(level_j_path)
	level_name = common.path_to_basename(level_j_path)
	level_dir = str(Path(level_j_path).parent) + "/"

	path_png = level_dir + level_j["path_png"]
	png_name = common.path_to_basename(path_png)
	data_asm, list_of_tiles_label = _get_list_of_tiles(remap_idxs, level_name, png_name)
	asm = data_asm

	data_init_tbl_label = f"{level_name}_gfx_init_tbl"
	asm += f"{data_init_tbl_label}:\n"
	asm += f"			.byte TEMP_BYTE ; RAM_DISK_S_{level_name.upper()}_DATA ; defined in loads.asm and inited by _gfx_init\n"
	asm += f"			.byte TEMP_BYTE ; RAM_DISK_M_{level_name.upper()}_DATA ; defined in loads.asm and inited by _gfx_init\n"
	asm += f"			.word {list_of_tiles_label}\n"
	asm += "@data_end:\n"
	asm += f"{data_init_tbl_label.upper()}_LEN = @data_end - {data_init_tbl_label}\n\n"

	asm += "; in:\n"
	asm += f"; bc - {level_name.upper()}_DATA_ADDR\n"
	asm += "; l - RAM_DISK_S\n"
	asm += "; h - RAM_DISK_M\n"
	asm += "; ex. hl = RAM_DISK_M_LV0_GFX<<8 | RAM_DISK_S_LV0_GFX\n"
	asm += f"{level_name}_gfx_init:\n"
	asm += f"			shld {data_init_tbl_label}\n\n"
	asm += "			push b\n\n"
	asm += f"			lxi h, {list_of_tiles_label}\n"
	asm += "			call add_offset_to_labels_eod\n\n"
	asm += "			pop d\n"
	asm += f"			; d = {level_name.upper()}_DATA_ADDR\n\n"
	asm += "			; copy a level init data\n"
	asm += f"			lxi h, {data_init_tbl_label}\n"
	asm += "			lxi d, lv_gfx_init_tbl\n"
	asm += f"			lxi b, {data_init_tbl_label.upper()}_LEN\n"
	asm += "			call mem_copy_len\n"
	asm += "			ret\n\n"

	for label, addr in relative_ptrs.items():
		asm += f"{label} = 0x{addr:04x}\n"
	asm += "\n"
	return asm


def _get_list_of_tiles(remap_idxs, label_prefix, png_label_prefix):
	label = label_prefix + "_gfx_tiles_ptrs"
	asm = f"{label}:\n			.word "
	for t_idx in remap_idxs:
		asm += f"_{png_label_prefix}_tile{remap_idxs[t_idx]:02x}_relative, "
	asm += "\n			.word EOD\n\n"
	return asm, label


def _gfx_to_asm(room_j, image, path, remap_idxs, label_prefix):
	asm = "; " + path + "\n"
	asm += label_prefix + "_tiles:\n"

	tile_w = room_j["tilewidth"]
	tile_h = room_j["tileheight"]
	width = room_j["layers"][0]["width"]

	relative_ptrs = {}
	tile_relative_addr = consts.SAFE_WORD_LEN

	for t_idx in remap_idxs:
		# Tiled exports the first tile index as 1; bring it back to 0-based.
		idx = t_idx % 256
		sx = idx % width * tile_w
		sy = idx // width * tile_h

		tile_img = []
		for y in range(sy, sy + tile_h):
			tile_img.append([image.getpixel((x, y)) for x in range(sx, sx + tile_w)])

		bits0, bits1, bits2, bits3 = common_gfx.indexes_to_bit_lists(tile_img)
		bytes0 = common.combine_bits_to_bytes(bits0)
		bytes1 = common.combine_bits_to_bytes(bits1)
		bytes2 = common.combine_bits_to_bytes(bits2)
		bytes3 = common.combine_bits_to_bytes(bits3)

		data, mask = level_common.get_tiledata(bytes0, bytes1, bytes2, bytes3)
		label = f"{label_prefix}_tile{remap_idxs[t_idx]:02x}_relative"

		asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
		asm += label + ":\n"
		asm += f"			.byte {mask} ; mask\n"
		asm += "			.byte 4 ; counter\n"
		asm += common.bytes_to_asm(data)

		relative_ptrs[label] = tile_relative_addr
		tile_relative_addr += 2  # mask, counter
		tile_relative_addr += len(data)
		tile_relative_addr += consts.SAFE_WORD_LEN

	return asm, relative_ptrs, tile_relative_addr - consts.SAFE_WORD_LEN
