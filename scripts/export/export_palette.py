import os
from PIL import Image
from pathlib import Path
import json

import utils.common as common
import utils.common_gfx as common_gfx
import utils.build as build

def export_if_updated(asset_j_path, asm_meta_path, asm_data_path, bin_path,
		force_export):

	if (force_export or is_asset_updated(asset_j_path)):
		export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path)
		print(f"export_palette: {asset_j_path} got exported.")


def is_asset_updated(asset_j_path):
	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	asset_dir = str(Path(asset_j_path).parent) + "/"
	path_png = asset_dir + asset_j["path_png"]

	if build.is_file_updated(asset_j_path) | build.is_file_updated(path_png):
		return True
	return False

def export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path):

	asm_ram_disk_data, relative_ptrs = ram_disk_data_to_asm(asset_j_path)
	asm_ram_data = ram_data_to_asm(asset_j_path, relative_ptrs)

	# save the asm gfx
	asm_data_dir = str(Path(asm_data_path).parent) + "/"
	if not os.path.exists(asm_data_dir):
		os.mkdir(asm_data_dir)
	with open(asm_data_path, "w") as file:
		file.write(asm_ram_disk_data)

	# compile and save the gfx bin files
	build.generate_asm_meta_file(asm_meta_path, asm_data_path, bin_path, asm_ram_data)

	return True

def ram_disk_data_to_asm(j_path):

	with open(j_path, "rb") as file:
		palette_j = json.load(file)

	palette_name = common.path_to_basename(j_path)
	palette_dir = str(Path(j_path).parent) + "/"

	asm = ""
	local_addrs = 0
	relative_ptrs = {}

	#=====================================================================
	# palette to asm
	path_png = palette_dir + palette_j["path_png"]
	image = Image.open(path_png)

	palette_asm, colors, palette_label, palette_len = \
		common_gfx.palette_file_to_asm(j_path, path_png, '_' + palette_name)
	asm += f"			.word 0 ; safety pair of bytes for reading by POP B\n"
	asm += f"{palette_label}_relative:\n"
	asm += palette_asm + "\n"

	local_addrs += build.SAFE_WORD_LEN
	relative_ptrs[palette_label+'_relative'] = local_addrs
	local_addrs += palette_len

	#=====================================================================
	# fades to asm
	# list of palette fades (each fade is a list of palettes)

	if "fades" in palette_j:
		for fade_j in palette_j["fades"]:
			name = fade_j["name"]

			fade_to_color = fade_j["color"]
			# convert Vector06c color cmponents to RGB
			fade_to_r = (fade_to_color.get('r', 0) << 5) & 0xFF
			fade_to_g = (fade_to_color.get('g', 0) << 5) & 0xFF
			fade_to_b = (fade_to_color.get('b', 0) << 6) & 0xFF
			fade_iterations = fade_j.get("iterations", 7)

			# convert fade to asm
			asm += f"			.word 0 ; safety pair of bytes for reading by POP B\n"
			fade_label = f"{palette_label}_fade_{name}_relative"
			asm += f"{fade_label}:\n"
			asm += f"			.byte {fade_iterations - 2} ; fade_iterations - 2\n"

			iteration_max = fade_iterations - 1

			for i in range(fade_iterations):
				asm += f"			.word 0 ; safety pair of bytes for reading by POP B\n"
				asm += f"			.byte "
				for color in colors:
					r, g, b = color
					blend_factor = (iteration_max - i) / iteration_max
					faded_r = int(r * blend_factor + fade_to_r * (1 - blend_factor))
					faded_g = int(g * blend_factor + fade_to_g * (1 - blend_factor))
					faded_b = int(b * blend_factor + fade_to_b * (1 - blend_factor))

					v6_color = (faded_b & 0b11000000) | ((faded_g & 0b11100000) >> 2) | (faded_r >> 5)
					asm += f"0x{v6_color:02x}, "
				asm += f"\n"

			asm += f"\n"

			local_addrs += build.SAFE_WORD_LEN
			relative_ptrs[fade_label] = local_addrs

			local_addrs += build.BYTE_LEN # fade_iterations - 1
			local_addrs += (build.SAFE_WORD_LEN + common_gfx.IMAGE_COLORS_MAX) * fade_iterations

	#=====================================================================

	return asm, relative_ptrs

def ram_data_to_asm(j_path, relative_ptrs):

	with open(j_path, "rb") as file:
		palette_j = json.load(file)

	palette_name = common.path_to_basename(j_path)
	palette_dir = str(Path(j_path).parent) + "/"

	asm = ""

	#=====================================================================
	# palette
	path_png = palette_dir + palette_j["path_png"]

	_, _, palette_label, _ = \
		common_gfx.palette_file_to_asm(j_path, path_png, '_' + palette_name)

	#=====================================================================
	# list of local labels
	for label, addr in relative_ptrs.items():
		asm += f"{label} = 0x{addr:04x}\n"
	asm += "\n"

	return asm
