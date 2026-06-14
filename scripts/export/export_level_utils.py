import os
from PIL import Image
from pathlib import Path
import json
import utils.common as common
import utils.common as common_gfx
import utils.build as build

# TODO: get this from asm file
TILEDATA_TELEPORT	= 2*16
TILEDATA_RESOURCE	= 7*16
RESOURCES_UNIQUE_MAX = 16
RESOURCES_INST_DATA_PTRS_LEN	= 0x100
# collect container data
TILEDATA_CONTAINER	= 11*16
CONTAINERS_UNIQUE_MAX = 16
CONTAINERS_INST_DATA_PTRS_LEN	= 0x100
TILEDATA_BREAKABLESS	= 13*16
BREAKABLES_UNIQUE_MAX = 16


def is_source_updated(asset_j_path, type):

	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	asset_dir = str(Path(asset_j_path).parent) + "/"
	level_j_path = asset_dir + asset_j["path_level"]


	with open(level_j_path, "rb") as file:
		level_j = json.load(file)

	level_dir = str(Path(level_j_path).parent) + "/"
	path_png = level_dir + level_j["path_png"]

	room_paths = level_j["rooms"]

	if build.is_file_updated(asset_j_path):
		return True
	if build.is_file_updated(level_j_path):
		return True

	if type == build.ASSET_TYPE_LEVEL_DATA:
		for room_path_p in room_paths:
			room_path = room_path_p['path']
			if build.is_file_updated(room_path):
				return True

	if type == build.ASSET_TYPE_LEVEL_GFX:
		if build.is_file_updated(path_png):
			return True

	return False

def remap_index(rooms_j):
	unique_idxs = [] # old idx : new idx
	for room_j in rooms_j:
		for idx in room_j["layers"][0]["data"]:
			if idx in unique_idxs:
				continue
			unique_idxs.append(idx)
	remap_idxs = {} # old idx : new idx
	for i, idx in enumerate(unique_idxs):
		remap_idxs[idx] = i

	return remap_idxs

def get_list_of_rooms(room_paths, label_prefix):
	label = label_prefix + "_data_rooms_ptrs"
	rooms_data_ptrs_len = len(room_paths) * (build.WORD_LEN + build.SAFE_WORD_LEN)
	rooms_data_ptrs_len += build.SAFE_WORD_LEN
	rooms_data_ptrs_len += 2 # EOD

	asm = ""
	asm += f"{label}:\n			.word "

	for room_path_p in room_paths:
		room_path = room_path_p['path']
		asm += get_room_data_label(room_path) + ", "
	asm += "\n			.word EOD\n"
	asm += "\n"

	return asm, label, rooms_data_ptrs_len

def get_room_data_label(room_path):
	return '_' + common.path_to_basename(room_path)

def room_tiles_to_asm(layer_j, remap_idxs):
	asm = ""
	width = layer_j["width"]
	height = layer_j["height"]

	for y in reversed(range(height)):
		asm += "			.byte "
		for x in range(width):
			i = y*width + x
			t_idx = layer_j["data"][i]
			asm += str(remap_idxs[t_idx]) + ", "
		asm += "\n"
	return asm

def room_tiles_data_to_asm(data, width, height):
	asm = ""
	for y in reversed(range(height)):
		asm += "			.byte "
		for x in range(width):
			i = y*width + x
			t_idx = data[i]
			asm += str(t_idx) + ", "
		asm += "\n"
	return asm

def room_teleport_data(layer_j, level_j_path):

	teleport_tiles = {}
	teleport_ids = {}
	teleport_id = 0

	for tile_idx, room_id_unclamped in enumerate(layer_j["data"]):
		if room_id_unclamped == 0:
			continue

		if room_id_unclamped < 1024:
			build.exit_error(f"ERROR: {level_j_path} teleport layer contains tiles from a wrong tileset: tile_id: {room_id_unclamped}.")
		room_id = room_id_unclamped % 256

		if room_id not in teleport_tiles:
			teleport_tiles[room_id] = []
			teleport_ids[room_id] = teleport_id
			teleport_id += 1

			if teleport_id > 16:
				build.exit_error(f"ERROR: {level_j_path} the room contains more than 16 different rooms to teleport.")

		teleport_tiles[room_id].append((tile_idx, teleport_ids[room_id]))


	asm_teleport_data = "			.byte "
	for room_id, teleport_id in teleport_ids.items():
		asm_teleport_data += f"{room_id}, "

	asm_teleport_data += "\n"

	return teleport_tiles, asm_teleport_data

def merge_teleport_data(teleport_tiles, room_tiledata):

	for _, tile_idxs_teleport_ids in teleport_tiles.items():
		for [tile_idx, teleport_id] in tile_idxs_teleport_ids:
			room_tiledata[tile_idx] = TILEDATA_TELEPORT + teleport_id

	return room_tiledata


def room_tiles_data_to_bytes(data, width, height, room_path):
	out = []

	for y in reversed(range(height)):
		for x in range(width):
			i = y*width + x
			t_idx = data[i]
			out.append(t_idx)
	return out

def get_tiledata(bytes0, bytes1, bytes2, bytes3):
	all_bytes = [bytes0, bytes1, bytes2, bytes3]
	# data structure description is in draw_tile.asm
	mask = 0
	data = []
	for bytes in all_bytes:
		mask >>=  1
		if common.is_bytes_zeros(bytes) :
			continue
		mask += 8

		x = 0
		for y in reversed(range(16)):
			byte = bytes[y * 2 + x]
			data.append(byte)
		x = 1
		for y in range(16):
			byte = bytes[y * 2 + x]
			data.append(byte)

	return data, mask