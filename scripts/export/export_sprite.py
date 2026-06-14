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
		print(f"export_sprite: {asset_j_path} got exported.")


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

	mask_flag = 1 if "mask" in asset_j and asset_j["mask"] == True else 0
	preshifted_sprites_num = asset_j.get("preshifted_sprites", 1)

	sprites_j = asset_j["sprites"]
	data_relative_ptrs = {}
	sprite_data_relative_addr = 2 # safety pair of bytes for reading by POP B
	asm = f"{label_prefix}{asset_name}_sprites:"

	if (preshifted_sprites_num != 1 and
		preshifted_sprites_num != 4 and preshifted_sprites_num != 8):
		build.exit_error(f'export_sprite ERROR: preshifted_sprites can be only equal 1, 4, 8. Path: {asset_j_path}')

	for sprite in sprites_j:

		sprite_name = sprite["name"]

		x = sprite["x"]
		y = sprite["y"]
		w = sprite["width"]
		h = sprite["height"]
		offset_x = sprite["offset_x"] if sprite.get("offset_x") is not None else 0
		offset_y = sprite["offset_y"] if sprite.get("offset_y") is not None else 0
		mask_x = sprite.get("mask_x", x)
		mask_y = sprite.get("mask_y", y)
		mask_alpha = sprite.get("mask_alpha", 0)
		mask_color = sprite.get("mask_color", 1)

		# 2d pixel array RGB
		sprite_img = []
		mask_bits = None

		for pos_y in reversed(range(y, y + h)) : # Y is reversed because it is from bottom to top in the game
			line = []
			for pos_x in range(x, x + w) :
				color_idx = image.getpixel((pos_x, pos_y))
				line.append(color_idx)

			sprite_img.append(line)

		# 2d pixel array mask
		if mask_flag == 1:
			mask_bits = []
			# get a sprite as a color index 2d array

			for pos_y in reversed(range(mask_y, mask_y + h)) : # Y is reversed because it is from bottom to top in the game
				for pos_x in range(mask_x, mask_x + w) :
					color_idx = image.getpixel((pos_x, pos_y))
					mask = 1 if color_idx == mask_alpha else 0
					mask_bits.append(mask)


		# preshifted sprite data
		for preshift in range(0, preshifted_sprites_num):

			# make frame asm
			shift = 8 // preshifted_sprites_num * preshift
			frame_label = f"{label_prefix}{asset_name}_{sprite_name}_{preshift}_relative"

			frame_asm, frame_data_len = img_to_preshifted_sprite(
				frame_label, sprite_img, mask_bits,
				w, h, offset_x, offset_y, shift)

			asm += frame_asm
			# collect a label and its relative addr
			data_relative_ptrs[frame_label] = sprite_data_relative_addr
			sprite_data_relative_addr += frame_data_len

	return asm, data_relative_ptrs


def anims_to_asm(label_prefix, asset_name, asset_j, data_relative_ptrs, asset_j_path):
	asm = ""

	preshifted_sprites = asset_j.get("preshifted_sprites", 1)

	if (preshifted_sprites != 1 and
		preshifted_sprites != 4 and preshifted_sprites != 8):
		build.exit_error(f'export_sprite ERROR: preshifted_sprites can be only equal 1, 4, 8", path: {asset_j_path}')

	asm += f"{asset_name}_get_scr_addr:\n"
	asm += f"			.word sprite_get_scr_addr{preshifted_sprites}\n"
	asm += f"{asset_name}_ram_disk_s_cmd:\n"
	asm += f"			.byte TEMP_BYTE ; inited by sprite_init_meta_data\n"
	asm += f"{asset_name}_preshifted_sprites:\n"
	asm += f"			.byte {str(preshifted_sprites)}\n"

	# make a list of anim_names
	asm += f"{asset_name}_anims:\n"
	asm += "			.word "
	for anim_name in asset_j["anims"]:
		asm += f"{asset_name}_{anim_name}_anim, "
	asm += "EOD\n"

	# make a list of sprites for an every anim
	for anim_name in asset_j["anims"]:

		asm += f"{asset_name}_{anim_name}_anim:\n"

		frames = asset_j["anims"][anim_name]["frames"]
		loop = asset_j["anims"][anim_name]["loop"]
		frame_count = len(frames)
		for i, frame in enumerate(frames):

			if i < frame_count-1:
				next_frame_offset = preshifted_sprites * 2 # every frame consists of preshifted_sprites pointers
				next_frame_offset += 1 # increase the offset to save one instruction in the game code
				asm += f"			.byte {str(next_frame_offset)}, 0 ; offset to the next frame\n"
			else:
				next_frame_offset_hi_str = "$ff"
				if loop == False:
					next_frame_offset_low = -1
					comment = "offset to the same last frame"
				else:
					offset_addr = 1
					next_frame_offset_low = 255 - (frame_count - 1) * (preshifted_sprites + offset_addr) * 2 + 1
					next_frame_offset_low -= 1 # decrease the offset to save one instruction in the game code
					comment = "offset to the first frame"

				asm += f"			.byte {next_frame_offset_low}, {next_frame_offset_hi_str} ; {comment}\n"

			asm += "			.word "
			for i in range(preshifted_sprites):
				frame_label = f"{label_prefix}{asset_name}_{str(frame)}_{str(i)}_relative"
				asm += frame_label + ", "
			asm += "\n"

	# add the end label
	asm += f"{asset_name}_anims_end:\n"
	# add len of the anims data
	asm += f"{asset_name}_anims_len: = {asset_name}_anims_end - {asset_name}_anims\n"


	# add the list of frame labels and their addresses
	frame_relative_labels_asm = "; relative frame labels\n"
	for label_name, addr in data_relative_ptrs.items():
		frame_relative_labels_asm += f"{label_name} = {addr}\n"
	frame_relative_labels_asm += "\n"
	asm = frame_relative_labels_asm + asm

	return asm


def img_to_preshifted_sprite(
		frame_label, sprite_img, mask_bits,
		w, h, offset_x, offset_y, shift):

	# convert indexes into bit lists.
	bits0, bits1, bits2, bits3 = common_gfx.indexes_to_bit_lists(sprite_img)

	# preshift image
	if (shift > 0):
		#bits0 = shift_bits(bits0, w, h, shift)
		bits1 = shift_bits(bits1, w, h, shift)
		bits2 = shift_bits(bits2, w, h, shift)
		bits3 = shift_bits(bits3, w, h, shift)
		if (mask_bits):
			mask_bits = shift_bits(mask_bits, w, h, shift, 1)

		w += 8

	# find the first visible pixel from left and right
	bits_to_check = []
	if mask_bits:
		bits_to_check = [mask_bits]
	else:
		bits_to_check = [bits1, bits2, bits3]

	vis_bit_l = 0
	vis_bit_r = w
	enabled = 1 if mask_bits == None else 0
	for bits in bits_to_check:
		l = find_leftest_bit(bits, w, h, enabled)
		if l > vis_bit_l:
			vis_bit_l = l

		r = find_rightest_bit(bits, w, h, enabled)
		if r < vis_bit_r:
			vis_bit_r = r

	# crop a sprite to rounded by 8 pixels (bytes)
	local_offset_x = vis_bit_l // 8 * 8
	new_w_unrounded = vis_bit_r - local_offset_x
	new_w = (new_w_unrounded // 8) * 8
	if (new_w_unrounded % 8) > 0:
		new_w += 8

	# fixing the issue with completely transparent sprites
	if new_w <= 0:
		new_w = 8
		local_offset_x = 0
	else:
		bits1 = crop_bits(bits1, w, h, new_w, local_offset_x)
		bits2 = crop_bits(bits2, w, h, new_w, local_offset_x)
		bits3 = crop_bits(bits3, w, h, new_w, local_offset_x)
		if mask_bits:
			mask_bits = crop_bits(mask_bits, w, h, new_w, local_offset_x)


	# combine bits into byte lists
	# bits go from left to right, from bottom to top
	#bytes0 = common.combine_bits_to_bytes(bits0) # 8000-9FFF
	bytes1 = common.combine_bits_to_bytes(bits1) # A000-BFFF
	bytes2 = common.combine_bits_to_bytes(bits2) # C000-DFFF
	bytes3 = common.combine_bits_to_bytes(bits3) # E000-FFFF

	mask_bytes = common.combine_bits_to_bytes(mask_bits) if mask_bits else None

	# packing bytes to the sprite data
	data = sprite_data(bytes1, bytes2, bytes3, new_w, h, mask_bytes)

	# TODO: Perf comparison between the old line by line draw func, and the new one
	# that draws row by row only visible bytes.
	# data_row_by_row, row_heights = sprite_data2(bytes1, bytes2, bytes3, mask_bytes, new_w, h)
	# orig_cc, old_len, row1_cc, row1_len, line2_cc, line2_len = \
	# 	calc_cpu_cycles(row_heights, new_w, h)
	# with open(f"sprite_draw_compare.txt", "a") as f:
	# 	f.write(
	# 		f"{frame_label[:-8]}, "
	# 		f"orig_cc: {orig_cc}, old_len: {old_len}, "
	# 		f"row1_cc: {row1_cc}, new_len: {row1_len}, "
	# 		f"line2_cc: {line2_cc}, line2_len: {line2_len}\n"
	# 		)

	offset_x_packed = (offset_x + local_offset_x) // 8
	new_w_packed = new_w // 8 - 1

	asm = ""
	asm += "\n"
	asm += f"			.word 0  ; safety pair of bytes for reading by POP B\n"
	asm += f"{frame_label}:\n"
	asm += f"			.byte {str( offset_y )}, {str( offset_x_packed )}; offset_y, offset_x\n"
	asm += f"			.byte {str( h )}, {str( new_w_packed )}; h, w\n"
	asm += common.bytes_to_asm(data)

	frame_data_len = len(data)
	frame_data_len += build.SAFE_WORD_LEN
	frame_data_len += 4 # offset_y, offset_x_packed, h, width_packed

	return asm, frame_data_len

def crop_bits(bits, w, h, new_w, offset_x):
	if w == new_w:
		return bits
	cropped = []
	for y in range(h):
		for x in range(w):
			if x < offset_x or x >= offset_x + new_w:
				continue
			b = bits[y*w + x]
			cropped.append(b)

	return cropped


# find the most leftest or rightest enabled bit in a 2d bit array
# return its dx
def find_leftest_bit(bits, w, h, enabled):
	dx = w
	for y in range(h):
		for x in range(w):
			b = bits[y*w + x]
			if b == enabled and x < dx:
				dx = x
				break
	return dx

def find_rightest_bit(bits, w, h, enabled):
	dx = 0
	for y in range(h):
		for x in reversed(range(w)):
			b = bits[y*w + x]
			if b == enabled and x > dx:
				dx = x
				break
	return dx

def shift_bits(bits, w, h, shift, filler = 0):
	shifted_bits = []
	shifted_w = w + 8
	for y in range(h):
		for x in range(shift):
			shifted_bits.append(filler)

		for x in range(w):
			b = bits[w*y + x]
			shifted_bits.append(b)

		for x in range(8 - shift):
			shifted_bits.append(filler)

	return shifted_bits


def get_sprite_params(dx_l, dx_r, shift):
	shifted_dx_l = shift + dx_l
	shifted_dx_r = shift + dx_r

	offset_x_preshifted_local = shifted_dx_l//8 * 8
	width_new = (shifted_dx_r//8 + 1) * 8 - offset_x_preshifted_local
	return offset_x_preshifted_local, width_new

def make_empty_sprite_data(has_mask, w, h):
	src_buff_count = 3
	data = []
	for dy in range(h):
		for dx in range(w // 8 * src_buff_count):
			if has_mask:
				data.append(255)
			data.append(0)

	return data


def get_anim_labels(path, main_ram_labels_addrs):
	with open(path, "r") as file:
		lines = file.readlines()

	anim_j_path = lines[0][2:]
	sprite_name = common.path_to_basename(anim_j_path)

	anim_labels = ""

	for i, line in enumerate(lines):
		if line.find(sprite_name) == 0 and line.find(':') != -1:
			label_name_end = line.find(":")
			label_name = line[:label_name_end]
			addr = main_ram_labels_addrs[label_name]
			anim_labels += f"{label_name} = ${addr:X}\n"

	return 	anim_labels

def sprite_data2(bytes1, bytes2, bytes3, mask_bytes, width, h):
	# sprite data structure description is in draw_sprite.asm
	# sprite uses only 3 out of 4 screen buffers.
	# bytes order: mask, bytes1, bytes2, bytes3
	# row by row from bottom to top, from left to right
	w = width // 8
	data = []
	row_heights = []
	for x in range(w):
		row_data = []
		for y in range(h):
			i = y*w+x
			row_data.append([mask_bytes[i], bytes1[i], bytes2[i], bytes3[i]])

		# find first not 0xFF byte
		mask_starts_at = 0
		for i in range(len(row_data)):
			if row_data[i] != 0xFF:
				mask_starts_at = i
				break
		# find last not 0xFF byte
		mask_ends_at = len(row_data) - 1
		for i in reversed(range(len(row_data))):
			if row_data[i] != 0xFF:
				mask_ends_at = i
				break
		# add row, and reverse every second row
		# details in draw_sprite.asm
		row_h = mask_ends_at + 1 - mask_starts_at
		for i in range(mask_starts_at, mask_ends_at + 1, 1):
			a, scr1, scr2, scr3 = row_data[i]
			even_line = y % 2 == 0
			if even_line:
				data.append(a)
				data.append(scr1)
				data.append(scr2)
				data.append(scr3)
			else:
				data.append(a)
				data.append(scr3)
				data.append(scr2)
				data.append(scr1)

		# add scr addr offset to the next row
		TEMP_OFFSET_L = 0x00
		TEMP_OFFSET_H = 0x00
		data.append(TEMP_OFFSET_L)
		data.append(TEMP_OFFSET_H)
		# add height & placeholder byte
		data.append(row_h)
		data.append(0)
		row_heights.append(row_h)

	return data, row_heights

def calc_cpu_cycles(row_heights, w, h):
	w_in_bytes = w // 8

	# orig sprite draw cost:
	# prep 16: 49*4 = 196 cc
	# prep 24: 49*4 + 4*4 = 212 cc
	# prep 8: 49*4 + 4*4 + 3*4 = 224 cc

	# w16 prep: 16*4 = 64 cc
	# line w16 loop: (11*6 + 5) * 4 = 284 cc per line
	# w24 prep: 18*4 = 72 cc
	# line w24 loop: (11*9 + 5) * 4 = 416 cc per line
	# w8 prep: 16*4 = 64 cc
	# line w8 loop: (11*3 + 5) * 4 = 152 cc per line

	# ret: 48 cc

	line1_prep16 = 196
	line1_prep24 = line1_prep16 + 16
	line1_prep8 = line1_prep24 + 12
	line1_w8_prep = 64
	line1_w8_loop = 152
	line1_w16_prep = 64
	line1_w16_loop = 284
	line1_w24_prep = 72
	line1_w24_loop = 416
	line1_ret = 48

	if w == 8:
		line1_cc = line1_prep8 + line1_w8_prep + line1_w8_loop*h + line1_ret
	elif w == 16:
		line1_cc = line1_prep16 + line1_w16_prep + line1_w16_loop*h + line1_ret
	elif w == 24:
		line1_cc = line1_prep24 + line1_w24_prep + line1_w24_loop*h + line1_ret

	line1_len = 2 + 2 + 2 + w_in_bytes * h * 6

	# draw_spite_rvm, draw by row cost:
	# prep: 18*4= 72 cc
	# row prep: 36*4 = 144 cc
	# row loop: 37*4 = 148 cc per byte
	# post row: 3*4 = 12 cc
	# ret: (14 + 17) * 4 = 124 cc

	row1_prep = 72
	row1_row_prep = 144
	#row1_row_loop = 148 # row end test every line
	#row1_row_loop = 138 # row end test every second line
	row1_row_loop = 128 # no row end test
	row1_post_row = 12
	row1_ret = 124

	row1_total_bytes = sum(row_heights)

	row1_cc = row1_prep + \
				(row1_row_prep + row1_post_row) * w_in_bytes + \
				row1_row_loop * row1_total_bytes + row1_ret

	row1_len = 2 + (2 + 2) * w_in_bytes + row1_total_bytes * 4


	# new approach, draw by line cost:
	# prep 16: 49*4 = 196 cc
	# prep 24: 49*4 + 4*4 = 212 cc
	# prep 8: 49*4 + 4*4 + 3*4 = 224 cc

	# prep: (w_in_bytes * 6 + 1)*4
	# loop: (32*w_in_bytes + 5) * 4 = cc per line
	# ret: 48 cc

	line2_prep16 = 196
	line2_prep24 = line2_prep16 + 16
	line2_prep8 = line2_prep24 + 12
	line2_line_prep = (w_in_bytes * 6 + 1) * 4
	line2_loop = (32*w_in_bytes + 5) * 4
	line2_ret = 48

	if w == 8:
		line2_cc = line2_prep8 + line2_line_prep + line2_loop*h + line2_ret
	elif w == 16:
		line2_cc = line2_prep16 + line2_line_prep + line2_loop*h + line2_ret
	elif w == 24:
		line2_cc = line2_prep24 + line2_line_prep + line2_loop*h + line2_ret

	line2_len = 2 + 2 + 2 + w_in_bytes * h * 4

	return line1_cc, line1_len, row1_cc, row1_len, line2_cc, line2_len


def sprite_data(bytes1, bytes2, bytes3, width, h, mask_bytes = None):
	# sprite data structure description is in draw_sprite.asm
	# sprite uses only 3 out of 4 screen buffers.
	w_in_bytes = width // 8 # 8 pxls per byte
	data = []

	for y in range(h):
		even_line = y % 2 == 0
		if width == 8:
			if even_line:
				x = 0
				i = y * w_in_bytes + x
				if mask_bytes:
					data.append(mask_bytes[i])
				data.append(bytes1[i])
				data.append(bytes2[i])
				data.append(bytes3[i])
			else:
				x = 0
				i = y * w_in_bytes + x
				if mask_bytes:
					data.append(mask_bytes[i])
				data.append(bytes3[i])
				data.append(bytes2[i])
				data.append(bytes1[i])
		elif width == 16:
			if even_line:
				x = 0
				i = y * w_in_bytes + x
				if mask_bytes:
					data.append(mask_bytes[i])
				data.append(bytes1[i])
				data.append(bytes2[i])
				data.append(bytes3[i])
				x = 1
				i = y * w_in_bytes + x
				if mask_bytes:
					data.append(mask_bytes[i])
				data.append(bytes3[i])
				data.append(bytes2[i])
				data.append(bytes1[i])
			else:
				x = 1
				i = y * w_in_bytes + x
				if mask_bytes:
					data.append(mask_bytes[i])
				data.append(bytes1[i])
				data.append(bytes2[i])
				data.append(bytes3[i])
				x = 0
				i = y * w_in_bytes + x
				if mask_bytes:
					data.append(mask_bytes[i])
				data.append(bytes3[i])
				data.append(bytes2[i])
				data.append(bytes1[i])
		elif width == 24:
			if even_line:
				x = 0
				i = y * w_in_bytes + x
				if mask_bytes:
					data.append(mask_bytes[i])
				data.append(bytes1[i])
				data.append(bytes2[i])
				data.append(bytes3[i])
				x = 1
				i = y * w_in_bytes + x
				if mask_bytes:
					data.append(mask_bytes[i])
				data.append(bytes3[i])
				data.append(bytes2[i])
				data.append(bytes1[i])
				x = 2
				i = y * w_in_bytes + x
				if mask_bytes:
					data.append(mask_bytes[i])
				data.append(bytes1[i])
				data.append(bytes2[i])
				data.append(bytes3[i])
			else:
				x = 2
				i = y * w_in_bytes + x
				if mask_bytes:
					data.append(mask_bytes[i])
				data.append(bytes3[i])
				data.append(bytes2[i])
				data.append(bytes1[i])
				x = 1
				i = y * w_in_bytes + x
				if mask_bytes:
					data.append(mask_bytes[i])
				data.append(bytes1[i])
				data.append(bytes2[i])
				data.append(bytes3[i])
				x = 0
				i = y * w_in_bytes + x
				if mask_bytes:
					data.append(mask_bytes[i])
				data.append(bytes3[i])
				data.append(bytes2[i])
				data.append(bytes1[i])

	return data
