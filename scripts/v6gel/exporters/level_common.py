"""Shared helpers for the level exporters (data + gfx).

Port of the original ``export_level_utils`` with the staleness checking removed
and the ``build`` dependency replaced by ``consts``/``log``.
"""

from utils import common, consts
from utils.log import error

# Tiledata category bases (see v6 level data consts).
TILEDATA_TELEPORT = 2 * 16
TILEDATA_RESOURCE = 7 * 16
RESOURCES_UNIQUE_MAX = 16
RESOURCES_INST_DATA_PTRS_LEN = 0x100
TILEDATA_CONTAINER = 11 * 16
CONTAINERS_UNIQUE_MAX = 16
CONTAINERS_INST_DATA_PTRS_LEN = 0x100
TILEDATA_BREAKABLESS = 13 * 16
BREAKABLES_UNIQUE_MAX = 16

TELEPORT_IDS_MAX = 16


def remap_index(rooms_j):
	"""Build an old-index -> contiguous-zero-based-index map across all rooms."""
	unique_idxs = []
	for room_j in rooms_j:
		for idx in room_j["layers"][0]["data"]:
			if idx not in unique_idxs:
				unique_idxs.append(idx)
	return {idx: i for i, idx in enumerate(unique_idxs)}


def get_list_of_rooms(room_paths, label_prefix):
	label = label_prefix + "_data_rooms_ptrs"
	rooms_data_ptrs_len = len(room_paths) * (consts.WORD_LEN + consts.SAFE_WORD_LEN)
	rooms_data_ptrs_len += consts.SAFE_WORD_LEN
	rooms_data_ptrs_len += 2  # EOD

	asm = f"{label}:\n			.word "
	for room_path_p in room_paths:
		asm += get_room_data_label(room_path_p["path"]) + ", "
	asm += "\n			.word EOD\n\n"
	return asm, label, rooms_data_ptrs_len


def get_room_data_label(room_path):
	return "_" + common.path_to_basename(room_path)


def room_tiles_to_asm(layer_j, remap_idxs):
	asm = ""
	width = layer_j["width"]
	height = layer_j["height"]
	for y in reversed(range(height)):
		asm += "			.byte "
		for x in range(width):
			asm += str(remap_idxs[layer_j["data"][y * width + x]]) + ", "
		asm += "\n"
	return asm


def room_tiles_data_to_asm(data, width, height):
	asm = ""
	for y in reversed(range(height)):
		asm += "			.byte "
		for x in range(width):
			asm += str(data[y * width + x]) + ", "
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
			error(
				"teleport layer contains tiles from a wrong tileset",
				f"{level_j_path}: tile_id {room_id_unclamped}",
			)
		room_id = room_id_unclamped % 256

		if room_id not in teleport_tiles:
			teleport_tiles[room_id] = []
			teleport_ids[room_id] = teleport_id
			teleport_id += 1
			if teleport_id > TELEPORT_IDS_MAX:
				error(
					"a room references more than 16 teleport destinations",
					level_j_path,
				)
		teleport_tiles[room_id].append((tile_idx, teleport_ids[room_id]))

	asm_teleport_data = "			.byte "
	for room_id in teleport_ids:
		asm_teleport_data += f"{room_id}, "
	asm_teleport_data += "\n"
	return teleport_tiles, asm_teleport_data


def merge_teleport_data(teleport_tiles, room_tiledata):
	for tile_idxs_teleport_ids in teleport_tiles.values():
		for tile_idx, teleport_id in tile_idxs_teleport_ids:
			room_tiledata[tile_idx] = TILEDATA_TELEPORT + teleport_id
	return room_tiledata


def get_tiledata(bytes0, bytes1, bytes2, bytes3):
	"""Pack up to 4 planes of a 16x16 tile with a presence mask.

	Data layout described in v6_tile_draw.asm.
	"""
	all_bytes = [bytes0, bytes1, bytes2, bytes3]
	mask = 0
	data = []
	for plane in all_bytes:
		mask >>= 1
		if common.is_bytes_zeros(plane):
			continue
		mask += 8
		x = 0
		for y in reversed(range(16)):
			data.append(plane[y * 2 + x])
		x = 1
		for y in range(16):
			data.append(plane[y * 2 + x])
	return data, mask
