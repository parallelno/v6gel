import os
from pathlib import Path
import json

import export.export_tiled_img_utils as export_tiled_img_utils
import utils.common as common
import utils.build as build


def export_if_updated(asset_j_path, asm_meta_path, asm_data_path, bin_path,
		force_export):

	if (force_export or
		export_tiled_img_utils.is_source_updated(asset_j_path, build.ASSET_TYPE_TILED_IMG_DATA)):

		export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path)
		print(f"export_tiled_img_data: {asset_j_path} got exported.")


def export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path):

	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	asset_dir = str(Path(asset_j_path).parent) + "/"
	tiled_img_j_path = asset_dir + asset_j["path_tiled_img"]

	#==========================
	asm_ram_disk_data, data_ptrs, = data_to_asm(tiled_img_j_path)
	asm_ram_data = data_ptrs_to_asm(data_ptrs)

	# save the asm gfx
	asm_data_dir = str(Path(asm_data_path).parent) + "/"
	if not os.path.exists(asm_data_dir):
		os.mkdir(asm_data_dir)
	with open(asm_data_path, "w") as file:
		file.write(asm_ram_disk_data)

	# compile and save the gfx bin files
	build.generate_asm_meta_file(asm_meta_path, asm_data_path, bin_path, asm_ram_data)

	return True

def data_ptrs_to_asm(data_ptrs):

	asm = ""

	# list of labels and local addresses
	for label, addr in data_ptrs.items():
		asm += f"{label} = 0x{addr:04x}\n"
	asm += "\n"

	return asm

def data_to_asm(tiled_img_j_path):

	with open(tiled_img_j_path, "rb") as file:
		tiled_img_j = json.load(file)

	base_name = common.path_to_basename(tiled_img_j_path)
	tiled_img_dir = str(Path(tiled_img_j_path).parent) + "/"

	asm = ""
	img_idxs_ptrs = {}
	img_idxs_addr_offset = 2 # added safety pair of bytes for reading by POP B

	# load the tiled file
	tiled_file_path = tiled_img_dir + tiled_img_j['path']
	with open(tiled_file_path, "rb") as file:
		tiled_file_j = json.load(file)


	# make a tile index remap dictionary, to have the first idx = 0
	remap_idxs = export_tiled_img_utils.remap_indices(tiled_file_j)

	for layer in tiled_file_j["layers"]:
		layer_name = layer["name"]
		if layer["type"] != "tilelayer":
			continue

		data = layer["data"]

		# determine pos_x, pos_y, tiles_w, tiles_h
		tile_first_x = export_tiled_img_utils.SCR_TILES_W # max
		tile_first_y = export_tiled_img_utils.SCR_TILES_H # max

		tile_last_x = -1 # min
		tile_last_y = -1 # min

		for t_y in range(export_tiled_img_utils.SCR_TILES_H):

			non_empty_tile_line = False

			for t_x in range(export_tiled_img_utils.SCR_TILES_W):

				t_idx = data[t_y * export_tiled_img_utils.SCR_TILES_W + t_x]

				if t_idx != 0:
					non_empty_tile_line = True

					if t_x < tile_first_x:
						tile_first_x = t_x

					if t_x > tile_last_x:
						tile_last_x = t_x

			if non_empty_tile_line:
				if t_y < tile_first_y:
					tile_first_y = t_y
				if t_y > tile_last_y:
					tile_last_y = t_y

		# image idxs to asm
		idxs = []
		for t_y in reversed(range(tile_first_y, tile_last_y + 1)):
			for t_x in range(tile_first_x, tile_last_x + 1):
				t_idx = data[t_y * export_tiled_img_utils.SCR_TILES_W + t_x]
				if t_idx > 0:
					idxs.append(remap_idxs[t_idx])
				else:
					idxs.append(0)

		label_name = "_" + base_name + "_" + layer_name
		pos_x = tile_first_x
		pos_y = (export_tiled_img_utils.SCR_TILES_H - tile_last_y - 1) * \
				export_tiled_img_utils.IMG_TILE_W
		tiles_w = tile_last_x - tile_first_x + 1
		tiles_h = tile_last_y - tile_first_y + 1

		tiled_img_asm, tiled_img_len = export_tiled_img_utils.tile_idxs_to_asm(
				label_name, idxs, pos_x, pos_y, tiles_w, tiles_h)

		# add the tiled img local ptr
		img_idxs_ptrs[label_name] = img_idxs_addr_offset
		img_idxs_addr_offset += tiled_img_len
		img_idxs_addr_offset += build.SAFE_WORD_LEN

		asm += tiled_img_asm

		# check if the length of the image fits the requirements
		if tiled_img_len > export_tiled_img_utils.TILED_IMG_IDXS_LEN_MAX:
			build.exit_error(f'export_tiled_img ERROR: tiled image {layer_name} > "{export_tiled_img_utils.TILED_IMG_IDXS_LEN_MAX}", path: {tiled_img_j_path}')

	return asm, img_idxs_ptrs
