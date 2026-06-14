import os
from PIL import Image
from pathlib import Path
import json

import export.export_tiled_img_utils as export_tiled_img_utils
import utils.common as common
import utils.common_gfx as common_gfx
import utils.build as build


def export_if_updated(asset_j_path, asm_meta_path, asm_data_path, bin_path,
		force_export):

	if (force_export or
		export_tiled_img_utils.is_source_updated(asset_j_path, build.ASSET_TYPE_TILED_IMG_DATA)):

		export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path)
		print(f"export_tiled_img_gfx: {asset_j_path} got exported.")


def export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path):

	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	asset_dir = str(Path(asset_j_path).parent) + "/"
	tiled_img_j_path = asset_dir + asset_j["path_tiled_img"]

	#==========================
	asm_ram_disk_data = data_to_asm(tiled_img_j_path)

	# save the asm gfx
	asm_data_dir = str(Path(asm_data_path).parent) + "/"
	if not os.path.exists(asm_data_dir):
		os.mkdir(asm_data_dir)
	with open(asm_data_path, "w") as file:
		file.write(asm_ram_disk_data)

	# compile and save the gfx bin files
	build.generate_asm_meta_file(asm_meta_path, asm_data_path, bin_path, "")

	return True

def data_to_asm(tiled_img_j_path):

	with open(tiled_img_j_path, "rb") as file:
		source_j = json.load(file)

	source_dir = str(Path(tiled_img_j_path).parent) + "/"

	path_png = source_dir + source_j["path_png"]
	image = Image.open(path_png)

	source_name = common.path_to_basename(tiled_img_j_path)

	asm = ""

	_, colors, _, _ = \
		common_gfx.palette_file_to_asm(source_dir + source_j["palette_path"], path_png, "_" + source_name)

	image = common_gfx.remap_colors(image, colors)

	tiled_file_path = source_dir + source_j['path']
	with open(tiled_file_path, "rb") as file:
		tiled_file_j = json.load(file)

	# make a tile index remap dictionary, to have the first idx = 0
	remap_idxs = export_tiled_img_utils.remap_indices(tiled_file_j)

	if len(remap_idxs) > export_tiled_img_utils.TILED_IMG_GFX_IDX_MAX:
		build.exit_error(f'export_tiled_img ERROR: gfx_idxs > "{export_tiled_img_utils.TILED_IMG_GFX_IDX_MAX}", path: {source_j_path}')

	# list of tiles addreses
	png_name = common.path_to_basename(path_png)

	# tile gfx data to asm
	asm += export_tiled_img_utils.gfx_to_asm("_" + png_name, image, remap_idxs)

	return asm
