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

	if force_export or is_source_updated(asset_j_path):
		export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path)
		print(f"export_back: {asset_j_path} got exported.")


def is_source_updated(asset_j_path):
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
	asm_ram_data = anims_to_asm("_", asset_name, asset_j, data_relative_ptrs, asset_j_path)

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
		offset_x = sprite.get("offset_x", 0)
		offset_y = sprite.get("offset_y", 0)

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

		# to support a sprite render function
		data = sprite_data(bytes0, bytes1, bytes2, bytes3, width, height)
		frame_label = f"{label_prefix}{asset_name}_{sprite_name}_relative"
		asm += "\n"
		asm += f"			.word 0  ; safety pair of bytes for reading by POP B\n"
		asm += frame_label + ":\n"

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


def anims_to_asm(label_prefix, asset_name, asset_j, data_relative_ptrs, asset_j_path):
	asm = ""

	preshifted_sprites = 1 # means no preshifted sprites
	asm += f"{asset_name}_get_scr_addr:\n"
	asm += f"			.word sprite_get_scr_addr{preshifted_sprites}\n"
	asm += f"{asset_name}_ram_disk_s_cmd:\n"
	asm += f"			.byte TEMP_BYTE ; inited by sprite_init_meta_data\n"
	asm += f"{asset_name}_preshifted_sprites:\n"
	asm += f"			.byte {preshifted_sprites}\n"

	# make a list of anim_names
	asm += f"{asset_name}_anims:\n"
	asm += "			.word "
	for anim_name in asset_j["anims"]:
		asm += f"{asset_name}_{anim_name}, "
	asm += "EOD\n"

	# make a list of sprites for an every anim
	for anim_name in asset_j["anims"]:

		asm += f"{asset_name}_{anim_name}:\n"

		anims = asset_j["anims"][anim_name]["frames"]
		loop = asset_j["anims"][anim_name]["loop"]
		frame_count = len(asset_j["anims"][anim_name]["frames"])
		for i, frame in enumerate(anims):

			if i < frame_count-1:
				next_frame_offset = preshifted_sprites * 2 # every frame consists of preshifted_sprites pointers
				next_frame_offset += 1 # increase the offset to save one instruction in the game code
				asm += f"			.byte {next_frame_offset}, 0 ; offset to the next frame\n"
			else:
				next_frame_offset_hi_str = "$ff"
				if loop == False:
					next_frame_offset_low = -1
				else:
					offset_addr = 1
					next_frame_offset_low = 255 - (frame_count - 1) * (preshifted_sprites + offset_addr) * 2 + 1
					next_frame_offset_low -= 1 # decrease the offset to save one instruction in the game code

				asm += f"			.byte {next_frame_offset_low}, {next_frame_offset_hi_str} ; offset to the first frame\n"

			asm += "			.word "
			for i in range(preshifted_sprites):
				frame_label = f"{label_prefix}{asset_name}_{frame}"
				asm += f"{frame_label}_relative, "
			asm += "\n"

	# add the list of frame labels and their addresses
	frame_relative_labels_asm = "; relative frame labels\n"
	for label_name, addr in data_relative_ptrs.items():
		frame_relative_labels_asm += f"{label_name} = {addr}\n"
	frame_relative_labels_asm += "\n"
	asm = frame_relative_labels_asm + asm

	return asm



def sprite_data(bytes0, bytes1, bytes2, bytes3, w, h):
	# data format is described in draw_back.asm
	# sprite uses 4 screen buffers without a mask
	# the width is devided by 8 because there is 8 pixels per a byte
	width = w // 8
	data = []
	for y in range(h):
		even_line = y % 2 == 0
		if even_line:
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
