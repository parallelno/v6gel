"""Tiled-image data exporter: RLE-packed tile-index streams per layer.

Faithful port of the original ``export_tiled_img_data``.
"""

import json
from pathlib import Path

from utils import asmgen, common, consts
from utils.log import error
from exporters import tiled_img_common
from exporters.context import AssetManifest, ExportContext


def export(ctx: ExportContext) -> AssetManifest:
	tiled_img_j_path = ctx.asset_rel("path_tiled_img")

	data_asm, data_ptrs = _data_to_asm(tiled_img_j_path)
	meta_body = _data_ptrs_to_asm(data_ptrs)

	keep_asm = ctx.data_asm_path if ctx.emit_asm else None
	bin_len = asmgen.assemble(
		ctx.v6asm_path, data_asm, ctx.bin_path, ctx.temp_dir, keep_asm
	)
	with open(ctx.meta_asm_path, "w", encoding="ascii") as f:
		f.write(asmgen.meta_asm(ctx.stored_path, meta_body))

	return AssetManifest(
		name=ctx.name,
		asset_type=consts.ASSET_TYPE_TILED_IMG_DATA,
		bin_path=ctx.bin_path,
		bin_len=bin_len,
		meta_asm_path=ctx.meta_asm_path,
		data_asm_path=keep_asm,
	)


def _data_ptrs_to_asm(data_ptrs):
	asm = ""
	for label, addr in data_ptrs.items():
		asm += f"{label} = 0x{addr:04x}\n"
	asm += "\n"
	return asm


def _data_to_asm(tiled_img_j_path):
	tiled_img_j = common.load_json(tiled_img_j_path)
	base_name = common.path_to_basename(tiled_img_j_path)
	tiled_img_dir = str(Path(tiled_img_j_path).parent) + "/"

	tiled_file_path = tiled_img_dir + tiled_img_j["path"]
	tiled_file_j = common.load_json(tiled_file_path)

	remap_idxs = tiled_img_common.remap_indices(tiled_file_j)

	scr_w = tiled_img_common.SCR_TILES_W
	scr_h = tiled_img_common.SCR_TILES_H

	asm = ""
	img_idxs_ptrs = {}
	img_idxs_addr_offset = consts.SAFE_WORD_LEN

	for layer in tiled_file_j["layers"]:
		if layer["type"] != "tilelayer":
			continue
		layer_name = layer["name"]
		data = layer["data"]

		# bounding box of non-empty tiles
		tile_first_x = scr_w
		tile_first_y = scr_h
		tile_last_x = -1
		tile_last_y = -1

		for t_y in range(scr_h):
			non_empty_tile_line = False
			for t_x in range(scr_w):
				if data[t_y * scr_w + t_x] != 0:
					non_empty_tile_line = True
					tile_first_x = min(tile_first_x, t_x)
					tile_last_x = max(tile_last_x, t_x)
			if non_empty_tile_line:
				tile_first_y = min(tile_first_y, t_y)
				tile_last_y = max(tile_last_y, t_y)

		idxs = []
		for t_y in reversed(range(tile_first_y, tile_last_y + 1)):
			for t_x in range(tile_first_x, tile_last_x + 1):
				t_idx = data[t_y * scr_w + t_x]
				idxs.append(remap_idxs[t_idx] if t_idx > 0 else 0)

		label_name = "_" + base_name + "_" + layer_name
		pos_x = tile_first_x
		pos_y = (scr_h - tile_last_y - 1) * tiled_img_common.IMG_TILE_W
		tiles_w = tile_last_x - tile_first_x + 1
		tiles_h = tile_last_y - tile_first_y + 1

		tiled_img_asm, tiled_img_len = tiled_img_common.tile_idxs_to_asm(
			label_name, idxs, pos_x, pos_y, tiles_w, tiles_h
		)

		img_idxs_ptrs[label_name] = img_idxs_addr_offset
		img_idxs_addr_offset += tiled_img_len
		img_idxs_addr_offset += consts.SAFE_WORD_LEN

		asm += tiled_img_asm

		if tiled_img_len > tiled_img_common.TILED_IMG_IDXS_LEN_MAX:
			error(
				f"tiled image {layer_name} > {tiled_img_common.TILED_IMG_IDXS_LEN_MAX}",
				tiled_img_j_path,
			)

	return asm, img_idxs_ptrs
