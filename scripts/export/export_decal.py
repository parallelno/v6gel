import os
from pathlib import Path
from PIL import Image
import json
import utils.common as common
import utils.common_gfx as common_gfx
import utils.build as build

def export_if_updated(
		asset_j_path, asm_meta_path, asm_data_path, bin_path,
		force_export):

	if force_export or is_asset_updated(asset_j_path):
		export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path)
		print(f"export_decal: {asset_j_path} got exported.")


def is_asset_updated(asset_j_path):
	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	asset_dir = str(Path(asset_j_path).parent) + "/"
	path_png = asset_dir + asset_j["path_png"]

	if build.is_file_updated(asset_j_path) | build.is_file_updated(path_png):
		return True
	return False


def export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path):

	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	asset_name = common.path_to_basename(asset_j_path)
	asset_dir = str(Path(asset_j_path).parent) + "/"
	path_png = asset_dir + asset_j["path_png"]
	image = Image.open(path_png)
	_, colors, _, _ = \
		common_gfx.palette_file_to_asm(asset_dir + asset_j["palette_path"], asset_j_path)
	image = common_gfx.remap_colors(image, colors)

	asm_ram_disk_data, data_relative_ptrs = gfx_to_asm("_", asset_name, asset_j, image, asset_j_path)
	asm_ram_data = meta_to_asm("_", asset_name, asset_j, data_relative_ptrs, asset_j_path)

	# save the asm gfx
	asm_gfx_dir = str(Path(asm_data_path).parent) + "/"
	if not os.path.exists(asm_gfx_dir):
		os.mkdir(asm_gfx_dir)
	with open(asm_data_path, "w") as file:
		file.write(asm_ram_disk_data)

	# compile and save the gfx bin files
	build.generate_asm_meta_file(asm_meta_path, asm_data_path, bin_path, asm_ram_data)

	return True


def gfx_to_asm(label_prefix, asset_name, asset_j, image, asset_j_path):

	sprites_j = asset_j["sprites"]
	data_relative_ptrs = {}
	sprite_data_relative_addr = 2 # safety pair of bytes for reading by POP B
	asm = f"{label_prefix}{asset_name}_sprites:"

	for sprite in sprites_j:

		sprite_name = sprite["name"]

		x = sprite["x"]
		y = sprite["y"]
		width = sprite["width"]
		height = sprite["height"]
		offset_x = sprite["offset_x"] if sprite.get("offset_x") is not None else 0
		offset_y = sprite["offset_y"] if sprite.get("offset_y") is not None else 0
		mask_x = sprite.get("mask_x", x)
		mask_y = sprite.get("mask_y", y)
		mask_alpha = sprite.get("mask_alpha", 0)
		mask_color = sprite.get("mask_color", 1)

		# get a sprite as a color index 2d array
		sprite_img = []
		for py in reversed(range(y, y + height)) : # Y is reversed because it is from bottomto top in the game
			line = []
			for px in range(x, x+width) :
				color_idx = image.getpixel((px, py))
				line.append(color_idx)

			sprite_img.append(line)

		# convert indexes into bit lists.
		bits0, bits1, bits2, bits3 = common_gfx.indexes_to_bit_lists(sprite_img)

		# combite bits into byte lists
		bytes0 = common.combine_bits_to_bytes(bits0) # 8000-9FFF # from left to right, from bottom to top
		bytes1 = common.combine_bits_to_bytes(bits1) # A000-BFFF
		bytes2 = common.combine_bits_to_bytes(bits2) # C000-DFFF
		bytes3 = common.combine_bits_to_bytes(bits3) # E000-FFFF

		# get a sprite as a color index 2d array
		mask_img = []
		for py in reversed(range(mask_y, mask_y + height)) : # Y is reversed because it is from bottom to top in the game
			for px in range(mask_x, mask_x+width) :
				color_idx = image.getpixel((px, py))
				if color_idx == mask_alpha:
					mask_img.append(1)
				else:
					mask_img.append(0)

		mask_bytes = common.combine_bits_to_bytes(mask_img)

		# to support a decal render function
		data = sprite_data(bytes0, bytes1, bytes2, bytes3, width, height, mask_bytes)
		frame_label = f"{label_prefix}{asset_name}_{sprite_name}_relative"
		asm += "\n"
		asm += f"			.word 0  ; safety pair of bytes for reading by POP B\n"
		asm += f"{frame_label}:\n"

		width_packed = width//8 - 1
		offset_x_packed = offset_x//8
		asm += "			.byte " + str( offset_y ) + ", " +  str( offset_x_packed ) + "; offset_y, offset_x\n"
		asm += "			.byte " + str( height ) + ", " +  str( width_packed ) + "; height, width\n"
		asm += common.bytes_to_asm(data)
		asm += "\n"

		# collect a label and its relative addr
		frame_data_len = len(data)
		frame_data_len += build.SAFE_WORD_LEN
		frame_data_len += 2 # offset_y, offset_x
		frame_data_len += 2 # height, width
		data_relative_ptrs[frame_label] = sprite_data_relative_addr
		sprite_data_relative_addr += frame_data_len

	return asm, data_relative_ptrs

def meta_to_asm(label_prefix, asset_name, asset_j, data_relative_ptrs, asset_j_path):
	asm = ""

	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	# add the list of frame labels and their addresses
	frame_relative_labels_asm = "; relative frame labels\n"
	for label_name, addr in data_relative_ptrs.items():
		frame_relative_labels_asm += f"{label_name} = {addr}\n"
	frame_relative_labels_asm += "\n"
	asm += frame_relative_labels_asm

	asm += lists_of_sprites_ptrs_to_asm(label_prefix, asset_name, asset_j)

	return asm


def lists_of_sprites_ptrs_to_asm(label_prefix, asset_name, asset_j):

	asm = ""

	asm += f"{asset_name}_gfx_ptrs:\n"
	ptrs = 0
	for list_name in asset_j["lists"]:
		list_j = asset_j["lists"][list_name]

		#asm += f"			.word 0  ; safety pair of bytes for reading by POP B\n"
		asm += f"{list_name}_gfx_ptrs: .word "

		for i, sprite_name in enumerate(list_j):
			asm += f"{label_prefix}{asset_name}_{sprite_name}_relative, "
			ptrs += 1
			#if i < len(list_j) -1:
				#asm += "0, "
		asm += "\n"

	asm += f".word EOD ; used to convert relative ptrs to absolute\n"

	return asm


def sprite_data(bytes0, bytes1, bytes2, bytes3, w, h, mask_bytes):
	# data format is described in draw_decal.asm
	# sprite uses 4 screen buffers with a mask
	# the width is devided by 8 because there is 8 pixels per a byte
	width = w // 8
	data = []
	for y in range(h):
		even_line = y % 2 == 0
		if even_line:
			for x in range(width):
				i = y*width+x
				data.append(mask_bytes[i])
			for x in range(width):
				i = y*width+x
				data.append(bytes0[i])
			for x in range(width):
				i = y*width+width-x-1
				data.append(bytes1[i])
			for x in range(width):
				i = y*width+width-x-1
				data.append(bytes2[i])
			for x in range(width):
				i = y*width+width-x-1
				data.append(bytes3[i])
		else:
			for x in range(width):
				i = y*width+x
				data.append(mask_bytes[i])
			for x in range(width):
				i = y*width+x
				data.append(bytes3[i])
			for x in range(width):
				i = y*width+width-x-1
				data.append(bytes2[i])
			for x in range(width):
				i = y*width+width-x-1
				data.append(bytes1[i])
			for x in range(width):
				i = y*width+width-x-1
				data.append(bytes0[i])

	return data
