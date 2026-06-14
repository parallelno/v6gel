import os
from PIL import Image
from pathlib import Path
import json
import utils.common as common
import utils.common_gfx as common_gfx
import utils.build as build
import numpy as np

IMG_TILE_W = 8
IMG_TILE_H = 8

SCR_TILES_W = 32
SCR_TILES_H = 32

TILED_IMG_GFX_IDX_MAX = 255
TILED_IMG_IDXS_LEN_MAX = 512

# metadata contains:
# 	.word COPY_LENGHT ; how many pairs of bytes to copy from the RAM Disk to the main memory
# 	.word SCR_BUFF0_ADDR + (0<<8 | 0)	; scr addr
# 	.word SCR_BUFF0_ADDR + (32<<8 | 64)	; scr addr end
COPY_LEN = 2
SCR_START = 2
SCR_END = 2

REPEATER_CODE = 255


def is_source_updated(asset_j_path, type):

	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	asset_dir = str(Path(asset_j_path).parent) + "/"
	path_tiled_img_j = asset_dir + asset_j["path_tiled_img"]
	tiled_img_dir = str(Path(path_tiled_img_j).parent) + "/"

	with open(path_tiled_img_j, "rb") as file:
		tiled_img_j = json.load(file)

	path_tmj = tiled_img_dir + tiled_img_j["path"]
	path_png = tiled_img_dir + tiled_img_j["path_png"]

	updated = (
		build.is_file_updated(asset_j_path) |
		build.is_file_updated(path_tiled_img_j) |
		build.is_file_updated(path_tmj))

	updated |= build.is_file_updated(path_png)

	return updated


def get_tiledata(bytes0, bytes1, bytes2, bytes3, use_mask):
	if not use_mask:
		# reverse every second list of bytes to support tiled_img format
		bytes1 = bytes1[::-1]
		bytes3 = bytes3[::-1]

	all_bytes = [bytes0, bytes1, bytes2, bytes3]
	# data structure description is in draw_tiled_img.asm
	mask = 0
	data = []
	for bytes in all_bytes:
		if use_mask:
			mask >>=  1
			if common.is_bytes_zeros(bytes) :
				continue
			mask += 8

		data.extend(bytes)

	return data, mask

def gfx_to_asm(label_prefix, image, remap_idxs):
	asm = "\n"

	# extract tile images and convert them into asm
	for t_idx in remap_idxs:
		# get a tile as a color index array
		tile_img = []
		idx = t_idx - 1 # because in Tiled exported data the first tile index is 1 instead of 0.
		sx = idx % SCR_TILES_W * IMG_TILE_W
		sy = idx // SCR_TILES_W * IMG_TILE_H
		for y in reversed(range(sy, sy + IMG_TILE_H)):
			line = []
			for x in range(sx, sx + IMG_TILE_W):
				color_idx = image.getpixel((x, y))
				line.append(color_idx)
				#x += 1
			tile_img.append(line)

		# convert indexes into bit lists.
		bits0, bits1, bits2, bits3 = common_gfx.indexes_to_bit_lists(tile_img)

		# combite bits into byte lists
		bytes0 = common.combine_bits_to_bytes(bits0) # 8000-9FFF # from left to right, from bottom to top
		bytes1 = common.combine_bits_to_bytes(bits1) # A000-BFFF
		bytes2 = common.combine_bits_to_bytes(bits2) # C000-DFFF
		bytes3 = common.combine_bits_to_bytes(bits3) # E000-FFFF

		# to support a tile render function
		# do not use the mask because this gives a big overhead for such small tiles.
		data, mask = get_tiledata(bytes0, bytes1, bytes2, bytes3, False)


		asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
		asm += label_prefix + "_tile" + str(remap_idxs[t_idx]) + ":\n"
		# remove it because this gives a big overhead for such small tiles.
		# asm += "			.byte " + str(mask) + " ; mask\n"
		# asm += "			.byte 4 ; counter\n"
		asm += common.bytes_to_asm(data, IMG_TILE_H, True)

	return asm

def remap_indices(tiled_file_j):
	unique_idxs = {}
	new_idx = 1
	for layer in tiled_file_j["layers"]:
		if layer["type"] != "tilelayer":
			continue

		for idx in layer["data"]:
			if idx != 0 and idx not in unique_idxs:
				unique_idxs[idx] = new_idx
				new_idx += 1
	return unique_idxs

def get_img_ptrs(images_j, label_prefix):
	asm = "\n			.word 0 ; safety pair of bytes for reading by POP B\n"
	asm += label_prefix + "_tiled_imgs_addr:\n			.word "

	for i, image_j in enumerate(images_j):
		layer_name = image_j['layer_name']
		path = image_j['path']
		label_name = "__" + common.path_to_basename(path) + "_" + layer_name
		asm += label_name + ", "

		if i != len(images_j)-1:
			# two safety fytes
			asm += "0, "
	asm += "\n"
	return asm

def pack_idxs(idxs_unpacked, tiles_w, tiles_h):
	idxs = []
	for j in range(tiles_h):
		# convert the line into the pairs (idx, how many times it repeats)
		repeaters = []
		repeaters_lens = []
		prev_idx = -1
		for i in range(tiles_w):
			idx = idxs_unpacked[j * tiles_w + i]
			if idx != prev_idx:
				repeaters.append(idx)
				repeaters_lens.append(1)
				prev_idx = idx
			else:
				repeaters_lens[-1] += 1

		idxs_line = []
		# decode pairs with len > 3 into (REPEATER_CODE, IDX, LEN)
		for i, idx in enumerate(repeaters):
			repeater_len = repeaters_lens[i]
			if repeater_len <= 3:
				for j in range(repeater_len):
					idxs_line.append(idx)
			else:
				idxs_line.append(REPEATER_CODE)
				idxs_line.append(idx)
				idxs_line.append(repeater_len)
		idxs.extend(idxs_line)
	return idxs

def tile_idxs_to_asm(label_name, idxs_unpacked, pos_x, pos_y, tiles_w, tiles_h):

	idxs = pack_idxs(idxs_unpacked, tiles_w, tiles_h)

	asm = ""
	data_len = len(idxs) + COPY_LEN + SCR_START + SCR_END
	copy_data_len = len(idxs) + SCR_START + SCR_END

	# the len of bytes copied from the RAM Disk
	# rounded to the nearest (biggest) even number
	idxs_data_copy_rounded_len = (copy_data_len // 2 + copy_data_len % 2) * 2
	asm += f"{label_name.upper()}_COPY_LEN = {idxs_data_copy_rounded_len}\n"

	asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
	asm += label_name + ":\n"

	asm += f"			.word {label_name.upper()}_COPY_LEN ; data len to copy\n"
	asm += f"			.word 0x8000 + ({pos_x}<<8 | {pos_y})	; scr addr\n"
	asm += f"			.word 0x8000 + ({pos_x + tiles_w}<<8 | {(pos_y + tiles_h * 8) % 256})	; scr addr end\n"
	asm += common.bytes_to_asm(idxs)

	return asm, data_len