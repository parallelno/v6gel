import os
from pathlib import Path
from PIL import Image
import json
import utils.common as common
import utils.build as build

def export_if_updated(
		asset_j_path, asm_meta_path, asm_data_path, bin_path,
		force_export):

	if force_export or is_source_updated(asset_j_path):
		export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path)
		print(f"export_font: {asset_j_path} got exported.")


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

	asm_ram_disk_data, data_ptrs = gfx_to_asm("_" + asset_name, asset_j, image)

	asm_ram_data = gfx_ptrs_to_asm(asset_name, asset_j, data_ptrs)

	# save the asm gfx
	asm_gfx_dir = str(Path(asm_data_path).parent) + "/"
	if not os.path.exists(asm_gfx_dir):
		os.mkdir(asm_gfx_dir)
	with open(asm_data_path, "w") as file:
		file.write(asm_ram_disk_data)

	# compile and save the gfx bin files
	build.generate_asm_meta_file(asm_meta_path, asm_data_path, bin_path, asm_ram_data)

	return True


def gfx_to_asm(label_prefix, asset_j, image):
	gfx_ptrs = {}
	gfx_j = asset_j["gfx"]
	asm = label_prefix + "_gfx:"

	backgrount_color_pos = asset_j.get("color_sample_pos", [0,0])
	backgrount_color_idx = image.getpixel((backgrount_color_pos[0], backgrount_color_pos[1]))
	spacing = asset_j.get("spacing", 1)

	char_addr_offset = 0
	for char_j in gfx_j:
		char_name = char_j["name"]
		# every char gfx is 16 pxls width, there first 8 pixels are empty to support shifting
		WIDTH_MAX = 8
		x = char_j["x"]
		y = char_j["y"]
		offset_x = char_j.get("offset_x", 0)
		offset_y = char_j.get("offset_y", 0)
		width = char_j["width"]
		height = char_j["height"]

		# convert color indexes into a list of bits.
		bits = []
		for py in reversed(range(y, y + height)) : # Y is reversed because it is from bottomto top in the game
			for px in range(x, x + WIDTH_MAX) :
				color_idx = image.getpixel((px, py))
				if color_idx == backgrount_color_idx:
					bit = 0
				else:
					bit = 1
				bits.append(bit)

		# combite bits into byte lists
		data = common.combine_bits_to_bytes(bits)

		asm += "\n"
		asm += f"			.word 0 ; safety pair of bytes for reading by POP B\n"
		adjusted_char = get_char_label_postfix(char_name)
		asm += f"{label_prefix}_{adjusted_char}:\n"

		if offset_y < 0:
			offset_x -= 1
		asm += f"			.byte {offset_y}, {offset_x} ; offset_y, offset_x\n"

		asm += common.words_to_asm(data)
		asm += f"			.byte 0, {width + spacing} ; next_char_pos_y_offset, next_char_pos_x_offset\n"

		char_addr_offset += build.SAFE_WORD_LEN
		gfx_ptrs[char_name] = char_addr_offset
		char_addr_offset += 2 + len(data)*2 + 2 # offset_y, offset_x + data_len + next_char_offset

	return asm, gfx_ptrs

def get_char_label_postfix(char_name):
	eng_alphabet_len = 26

	adjusted_char = char_name
	unicode_code_point = ord(char_name[0])
	if unicode_code_point > 0x100:
		adjusted_code_point = (unicode_code_point - 0x100) % eng_alphabet_len + 0x61
		offset = (unicode_code_point - 0x100) // eng_alphabet_len
		adjusted_char = f"{chr(adjusted_code_point)}{offset}"
	return adjusted_char

def gfx_ptrs_to_asm(label_prefix, asset_j, gfx_ptrs):
	asm = ""

	# if font_gfx_ptrs_rd == True, then add list of labels with relatives addresses
	for char_name in gfx_ptrs:
		adjusted_char = get_char_label_postfix(char_name)
		asm += f"_{label_prefix}_{adjusted_char} = {gfx_ptrs[char_name]}\n"

	asm += f"{label_prefix}_gfx_ptrs:\n"

	numbers_in_line = 16
	for i, char_name in enumerate(asset_j["gfx_ptrs"]):
		if i % numbers_in_line == 0:
			if i != 0:
				asm += "\n"
			asm += "			.word "
		adjusted_char = get_char_label_postfix(char_name)
		asm += f"_{label_prefix}_{adjusted_char}, "
	asm += "\n			.word EOD\n"
	asm +="\n"

	return asm
