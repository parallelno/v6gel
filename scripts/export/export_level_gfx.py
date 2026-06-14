import os
from PIL import Image
from pathlib import Path
import json

import export.export_level_utils as export_level_utils
import utils.common as common
import utils.common_gfx as common_gfx
import utils.build as build

def export_if_updated(asset_j_path, asm_meta_path, asm_data_path, bin_path,
		force_export):

	if (force_export or
		export_level_utils.is_source_updated(asset_j_path, build.ASSET_TYPE_LEVEL_DATA)):

		export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path)
		print(f"export_level_gfx: {asset_j_path} got exported.")

def export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path):

	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	asset_dir = str(Path(asset_j_path).parent) + "/"
	level_j_path = asset_dir + asset_j["path_level"]

	asm_ram_disk_data, relative_ptrs, remap_idxs = ram_disk_data_to_asm(level_j_path)
	asm_ram_data = ram_data_to_asm(level_j_path, relative_ptrs, remap_idxs)

	# save the asm gfx
	asm_data_dir = str(Path(asm_data_path).parent) + "/"
	if not os.path.exists(asm_data_dir):
		os.mkdir(asm_data_dir)
	with open(asm_data_path, "w") as file:
		file.write(asm_ram_disk_data)

	# compile and save the gfx bin files
	build.generate_asm_meta_file(asm_meta_path, asm_data_path, bin_path, asm_ram_data)

	return True

def ram_disk_data_to_asm(level_j_path):

	with open(level_j_path, "rb") as file:
		level_j = json.load(file)

	level_name = common.path_to_basename(level_j_path)
	level_dir = str(Path(level_j_path).parent) + "/"

	asm = ""
	relative_ptrs = {}
	local_addrs = build.SAFE_WORD_LEN

	#=====================================================================
	# palette
	path_png = level_dir + level_j["path_png"]
	image = Image.open(path_png)

	palette_asm, colors, palette_label, palette_len = \
		common_gfx.palette_file_to_asm(level_dir + level_j['palette_path'], path_png, '_' + level_name)
	asm += f"			.word 0 ; safety pair of bytes for reading by POP B\n"
	asm += f"{palette_label}_relative:\n"
	asm += palette_asm + "\n"
	relative_ptrs[palette_label+'_relative'] = local_addrs
	local_addrs += palette_len

	#=====================================================================
	# list of gfx tiles
	image = common_gfx.remap_colors(image, colors)

	room_paths = level_j["rooms"]
	rooms_j = []
	# load and parse tiled map
	for room_path_p in room_paths:
		room_path = level_dir + room_path_p['path']
		with open(room_path, "rb") as file:
			rooms_j.append(json.load(file))

	# make a tile index remap dictionary, to have the first idx = 0
	remap_idxs = export_level_utils.remap_index(rooms_j)

	# list of tiles addreses
	png_name = common.path_to_basename(path_png)

	# tile gfx data to asm
	gfx_asm, gfx_ptrs, gfx_data_len = gfx_to_asm(rooms_j[0], image, path_png, remap_idxs, "_" + png_name)
	asm += gfx_asm

	# add gfx ptrs
	for label_name, gfx_ptr in gfx_ptrs.items():
		relative_ptrs[label_name] = gfx_ptr + local_addrs

	local_addrs += gfx_data_len
	#=====================================================================



	return asm, relative_ptrs, remap_idxs

def ram_data_to_asm(level_j_path, relative_ptrs, remap_idxs):

	with open(level_j_path, "rb") as file:
		level_j = json.load(file)

	level_name = common.path_to_basename(level_j_path)
	level_dir = str(Path(level_j_path).parent) + "/"

	asm = ""

	#=====================================================================
	# list of tiles
	path_png = level_dir + level_j["path_png"]
	png_name = common.path_to_basename(path_png)
	data_asm, list_of_tiles_label = get_list_of_tiles(remap_idxs, level_name, png_name)
	asm += data_asm

	#=====================================================================
	# level data init tbl
	data_init_tbl_label = f"{level_name}_gfx_init_tbl"
	asm += f"{data_init_tbl_label}:\n"
	asm += f"			.byte TEMP_BYTE ; RAM_DISK_S_{level_name.upper()}_DATA ; defined in loads.asm and inited by _gfx_init\n"
	asm += f"			.byte TEMP_BYTE ; RAM_DISK_M_{level_name.upper()}_DATA ; defined in loads.asm and inited by _gfx_init\n"
	asm += f"			.word {list_of_tiles_label}\n"
	asm += f"@data_end:\n"
	asm += f"{data_init_tbl_label.upper()}_LEN = @data_end - {data_init_tbl_label}\n"
	asm += "\n"

	#=====================================================================
	# init func
	asm += f"; in:\n"
	asm += f"; bc - {level_name.upper()}_DATA_ADDR\n"
	asm += f"; l - RAM_DISK_S\n"
	asm += f"; h - RAM_DISK_M\n"
	asm += f"; ex. hl = RAM_DISK_M_LV0_GFX<<8 | RAM_DISK_S_LV0_GFX\n"
	asm += f"{level_name}_gfx_init:\n"
	asm += f"			shld {data_init_tbl_label}\n"
	asm += f"\n"

	asm += f"			push b\n"
	asm += f"\n"

	asm += f"			lxi h, {list_of_tiles_label}\n"
	asm += f"			call add_offset_to_labels_eod\n"
	asm += f"\n"

	asm += f"			pop d\n"
	asm += f"			; d = {level_name.upper()}_DATA_ADDR\n"
	asm += f"\n"

	asm += f"			; copy a level init data\n"
	asm += f"			lxi h, {data_init_tbl_label}\n"
	asm += f"			lxi d, lv_gfx_init_tbl\n"
	asm += f"			lxi b, {data_init_tbl_label.upper()}_LEN\n"
	asm += f"			call mem_copy_len\n"

	asm += f"			ret\n"
	asm += f"\n"

	#=====================================================================
	# list of local labels
	for label, addr in relative_ptrs.items():
		asm += f"{label} = 0x{addr:04x}\n"
	asm += "\n"

	return asm

def get_list_of_tiles(remap_idxs, label_prefix, pngLabelPrefix):
	asm = ""
	#asm += "\n			.word 0 ; safety pair of bytes for reading by POP B\n"
	label = label_prefix + "_gfx_tiles_ptrs"
	asm += f"{label}:\n			.word "

	for i, t_idx in enumerate(remap_idxs):
		asm += f"_{pngLabelPrefix}_tile{remap_idxs[t_idx]:02x}_relative, "
	asm += "\n"
	asm += f"			.word EOD\n\n"

	return asm, label

def gfx_to_asm(room_j, image, path, remap_idxs, label_prefix):
	asm = "; " + path + "\n"
	asm += label_prefix + "_tiles:\n"

	tileW = room_j["tilewidth"]
	tileH = room_j["tileheight"]

	width = room_j["layers"][0]["width"]
	height = room_j["layers"][0]["height"]

	relative_ptrs = {}
	tile_relative_addr = 2 # added safety pair of bytes for reading by POP B

	# extract tile images and convert them into asm
	for t_idx in remap_idxs:
		# get a tile as a color index 2d array
		tile_img = []
		idx = (t_idx) % 256 # because in Tiled exported data the first tile index is 1 instead of 0.
		sx = idx % width * tileW
		sy = idx // width * tileH
		for y in range(sy, sy + tileH):
			line = []
			for x in range(sx, sx + tileW):
				color_idx = image.getpixel((x, y))
				line.append(color_idx)
				#x += 1
			tile_img.append(line)
			#y += 1

		# convert indexes into bit lists.
		bits0, bits1, bits2, bits3 = common_gfx.indexes_to_bit_lists(tile_img)

		# combite bits into byte lists
		bytes0 = common.combine_bits_to_bytes(bits0) # 8000-9FFF # from left to right, from bottom to top
		bytes1 = common.combine_bits_to_bytes(bits1) # A000-BFFF
		bytes2 = common.combine_bits_to_bytes(bits2) # C000-DFFF
		bytes3 = common.combine_bits_to_bytes(bits3) # E000-FFFF

		# to support a tile render function
		data, mask = export_level_utils.get_tiledata(bytes0, bytes1, bytes2, bytes3)

		label = f"{label_prefix}_tile{remap_idxs[t_idx]:02x}_relative"

		asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
		asm += label + ":\n"
		asm += "			.byte " + str(mask) + " ; mask\n"
		asm += "			.byte 4 ; counter\n"
		asm += common.bytes_to_asm(data)

		relative_ptrs[label] = tile_relative_addr
		tile_relative_addr += 2 # mask, counter
		tile_relative_addr += len(data)
		tile_relative_addr += build.SAFE_WORD_LEN

	return asm, relative_ptrs, tile_relative_addr - build.SAFE_WORD_LEN
