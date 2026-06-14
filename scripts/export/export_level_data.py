import os
from pathlib import Path
import json

import export.export_level_utils as export_level_utils
import utils.common as common
import utils.build as build

def export_if_updated(asset_j_path, asm_meta_path, asm_data_path, bin_path,
		force_export):

	if (force_export or
		export_level_utils.is_source_updated(asset_j_path, build.ASSET_TYPE_LEVEL_DATA)):

		export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path)
		print(f"export_level_data: {asset_j_path} got exported.")


def export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path):

	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	asset_dir = str(Path(asset_j_path).parent) + "/"
	level_j_path = asset_dir + asset_j["path_level"]

	asm_ram_disk_data, data_ptrs, \
	resources, resource_max_tiledata, \
	containers, container_max_tiledata = ram_disk_data_to_asm(level_j_path)

	asm_ram_data = ram_data_to_asm(data_ptrs, level_j_path,
								resources, resource_max_tiledata,
								containers, container_max_tiledata)

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

	level_dir = str(Path(level_j_path).parent) + "/"
	room_paths = level_j["rooms"]

	#=====================================================================
	# room data

	rooms_j = get_rooms_j(level_dir, room_paths)

	# make a tile index remap dictionary, to have the first idx = 0
	remap_idxs = export_level_utils.remap_index(rooms_j)

	# data for rooms_resources_tbl and rooms_resources
	resources = {}
	resource_max_tiledata = 0
	# data for rooms_containers_tbl and rooms_containers
	containers = {}
	container_max_tiledata = 0
	breakables_count = 0

	room_data_asm = ""
	room_data_ptrs = {}
	room_addr_offset = 0

	# per room data
	for room_id, room_j in enumerate(rooms_j):
		room_path = room_paths[room_id]['path']

		# clamp tiledata values into the range
		room_tiledatas_unclamped = room_j["layers"][1]["data"]
		room_tiledata = [x % 256 for x in room_tiledatas_unclamped]

		width = room_j["width"]
		height = room_j["height"]

		# add room gfx data
		asm_room_data = export_level_utils.room_tiles_to_asm(room_j["layers"][0], remap_idxs)

		# add teleport data
		teleport_tiles, asm_teleport_data = \
			export_level_utils.room_teleport_data(room_j["layers"][2], level_j_path)
		# merge teleport data with the room tiledata
		room_tiledata = export_level_utils.merge_teleport_data(teleport_tiles, room_tiledata)

		# add room tiledata
		asm_room_data += export_level_utils.room_tiles_data_to_asm(room_tiledata, width, height)

		room_data_label = export_level_utils.get_room_data_label(room_path)
		compressed_room_asm, data_len = common.asm_compress_to_asm(asm_room_data)

		room_data_asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
		room_data_asm += "; " + room_path + "\n"
		room_data_asm += room_data_label + ":\n"
		room_data_asm += "; compressed room data len\n"
		room_data_asm += f"			.word {data_len}\n"
		room_data_asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
		room_data_asm += compressed_room_asm + "\n"

		room_data_asm += "; teleport data\n"
		room_data_asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
		room_data_asm += asm_teleport_data + "\n"

		TELEPORT_IDS_MAX = 16

		room_data_ptrs[room_data_label] = room_addr_offset
		room_addr_offset += build.WORD_LEN # stored compressed_roomdata_len
		room_addr_offset += build.SAFE_WORD_LEN
		room_addr_offset += data_len
		room_addr_offset += build.SAFE_WORD_LEN
		room_addr_offset += len(teleport_tiles)
		room_addr_offset += build.SAFE_WORD_LEN

		for i, tiledata in enumerate(room_tiledata):

			# collect resource data
			dy, dx = divmod(i, width)
			tile_idx = (height - 1 - dy) * width + dx
			if export_level_utils.TILEDATA_RESOURCE <= tiledata < export_level_utils.TILEDATA_RESOURCE + export_level_utils.RESOURCES_UNIQUE_MAX:
				if tiledata not in resources:
					resources[tiledata] = []
				resources[tiledata].append((room_id, tile_idx))
				if resource_max_tiledata < tiledata:
					resource_max_tiledata = tiledata

			# collect container data
			if export_level_utils.TILEDATA_CONTAINER <= tiledata < export_level_utils.TILEDATA_CONTAINER + export_level_utils.CONTAINERS_UNIQUE_MAX:
				if tiledata not in containers:
					containers[tiledata] = []
				containers[tiledata].append((room_id, tile_idx))
				if container_max_tiledata < tiledata:
					container_max_tiledata = tiledata

			# count breakables
			if export_level_utils.TILEDATA_BREAKABLESS <= tiledata < export_level_utils.TILEDATA_BREAKABLESS + export_level_utils.BREAKABLES_UNIQUE_MAX:
				breakables_count += 1


	asm = ""
	relative_ptrs = {}
	relative_addr = build.SAFE_WORD_LEN

	#=====================================================================
	level_name = common.path_to_basename(level_j_path)

	#=====================================================================
	# resources data
	data_asm, label, data_len = \
		get_resources_inst_data(level_j_path, resources, resource_max_tiledata)
	asm += data_asm
	relative_ptrs[label] = relative_addr
	relative_addr += data_len
	relative_addr += build.SAFE_WORD_LEN

	#=====================================================================
	# containers data
	data_asm, label, data_len = \
		get_containers_inst_data(level_j_path, containers, container_max_tiledata)
	asm += data_asm
	relative_ptrs[label] = relative_addr
	relative_addr += data_len
	relative_addr += build.SAFE_WORD_LEN

	#=====================================================================
	# number of breakables to check if it fits into the buffer
	relative_ptrs[level_name.upper()+"_BREAKABLES"] = breakables_count
	#=====================================================================
	# rooms data
	asm += room_data_asm

	#=====================================================================
	# add the room data pointers
	for label, addr in room_data_ptrs.items():
		relative_ptrs[label] = addr + relative_addr

	return asm, relative_ptrs, \
		resources, resource_max_tiledata, \
		containers, container_max_tiledata

def get_resources_inst_data(level_j_path, resources, resource_max_tiledata):

	data_len = 0

	level_prefix = common.path_to_basename(level_j_path)
	label = f"_{level_prefix}_resources_inst_data"

	asm = ""
	asm += "NULL = 0\n\n"
	asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
	asm += f"{label}_ptrs:\n"

	# make resources_inst_data_ptrs data
	if len(resources) > 0:
		asm += "			.byte "

		# add resource tiledata which is not present in the level to
		# make resources_inst_data_ptrs array contain contiguous data
		# for example: all the rooms contain only res_id=1 and res_id=3
		# to make a proper data we need to add null_ptrs for res_id=0 and res_id=2
		# to let the asm code look up it by the res_id
		for tiledata in range(export_level_utils.TILEDATA_RESOURCE, resource_max_tiledata + 1):
			if tiledata not in resources:
				resources[tiledata] = []

		resources_sorted = dict(sorted(resources.items()))

		ptr = 0
		resources_inst_data_ptrs_len = len(resources_sorted) + 1

		for i, tiledata in enumerate(resources_sorted):
			inst_len = len(resources_sorted[tiledata]) * build.WORD_LEN
			if len(resources_sorted[tiledata]) > 0:
				data_byte = ptr + resources_inst_data_ptrs_len
				asm += f"0x{data_byte:02X}, "
			else:
				asm += f"NULL, "


			ptr += inst_len
			data_len += build.BYTE_LEN

		asm += f"0x{(ptr + resources_inst_data_ptrs_len):02X}, "
		data_len += build.BYTE_LEN

		# make resources_inst_data data
		asm += f"\n;{label}:\n"
		for i, tiledata in enumerate(resources_sorted):
			if len(resources_sorted[tiledata]) > 0:
				asm += f";			tiledata = {tiledata}, data below is pairs of tile_idx, room_id\n"
				data = []
				for room_id, tile_idx in resources_sorted[tiledata]:
					data.append(tile_idx)
					data.append(room_id)
				asm += common.bytes_to_asm(data)
				data_len += len(data)


		if ptr + resources_inst_data_ptrs_len > 256:
			build.exit_error(f"ERROR: {level_j_path} has resource instance data len: {ptr + resources_inst_data_ptrs_len} > {export_level_utils.RESOURCES_INST_DATA_PTRS_LEN} bytes")

	asm += "\n"

	return asm, label+'_ptrs', data_len

def get_containers_inst_data(level_j_path, containers, container_max_tiledata):

	data_len = 0

	level_prefix = common.path_to_basename(level_j_path)
	label = f"_{level_prefix}_containers_inst_data"

	asm = ""
	asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
	asm += f"{label}_ptrs:\n"

	# make containers_inst_data_ptrs data
	if len(containers) > 0:
		asm += "			.byte "

		# add container tiledata which is not present in the level
		# to make containers_inst_data_ptrs array contain contiguous data
		# for example: all the rooms contain only container_id=1 and container_id=3
		# to make a proper data we need to add null_ptrs for container_id=0 and container_id=2
		# to let the asm code look up it by the container_id
		# more about containers tiledata and a format of containers data can be found in:
		# levels_data_consts.asm and runtime_data.asm
		for tiledata in range(export_level_utils.TILEDATA_CONTAINER, container_max_tiledata + 1):
			if tiledata not in containers:
				containers[tiledata] = []

		containers_sorted = dict(sorted(containers.items()))

		ptr = 0
		containers_inst_data_ptrs_len = len(containers_sorted) + 1
		for i, tiledata in enumerate(containers_sorted):
			inst_len = len(containers_sorted[tiledata]) * build.WORD_LEN
			if len(containers_sorted[tiledata]) > 0:
				byte_data = ptr + containers_inst_data_ptrs_len
			else:
				byte_data = ptr + inst_len + containers_inst_data_ptrs_len

			asm += f"0x{byte_data:02X}, "
			ptr += inst_len
			data_len += build.BYTE_LEN

		asm += f"0x{(ptr + containers_inst_data_ptrs_len):02X}, "
		data_len += build.BYTE_LEN

		# make containers_inst_data data
		asm += f"\n;{label}:\n"
		for i, tiledata in enumerate(containers_sorted):
			if len(containers_sorted[tiledata]) > 0:
				asm += f";			tiledata = {tiledata}, data below is pairs of tile_idx, room_id\n"
				data = []

				for room_id, tile_idx in containers_sorted[tiledata]:
					data.append(tile_idx)
					data.append(room_id)

				asm += common.bytes_to_asm(data)
				data_len += len(data)

		if 	ptr + containers_inst_data_ptrs_len > export_level_utils.CONTAINERS_INST_DATA_PTRS_LEN:
			build.exit_error(f"ERROR: {level_j_path} has container instance data len: {ptr + containers_inst_data_ptrs_len} > {export_level_utils.CONTAINERS_INST_DATA_PTRS_LEN} bytes")

	asm += "\n"

	return asm, label+'_ptrs', data_len


def ram_data_to_asm(data_ptrs, level_j_path,
					resources, resource_max_tiledata,
					containers, container_max_tiledata):

	with open(level_j_path, "rb") as file:
		level_j = json.load(file)

	level_name = common.path_to_basename(level_j_path)
	room_paths = level_j["rooms"]

	asm = ""

	#=====================================================================
	# rooms data (gfx_idx + tiledata) pointers
	rooms_data_data_asm, rooms_data_label, data_len = \
		export_level_utils.get_list_of_rooms(room_paths, level_name)
	asm += rooms_data_data_asm

	#=====================================================================
	# resources data
	data_asm, resources_inst_data_label, resources_inst_data_len = \
		get_resources_inst_data(level_j_path, resources, resource_max_tiledata)

	#=====================================================================
	# containers data
	data_asm, containers_inst_data_label, containers_inst_data_len = \
		get_containers_inst_data(level_j_path, containers, container_max_tiledata)

	#=====================================================================
	# player's start pose
	player_start_pose_label = f"{level_name}_start_pos"

	#=====================================================================
	# level data init tbl
	data_init_tbl_label = f"{level_name}_data_init_tbl"
	asm += f"{data_init_tbl_label}:\n"
	asm += f"			.byte TEMP_BYTE ; defined in loads.asm and inited by _data_init\n"
	asm += f"			.byte TEMP_BYTE ; defined in loads.asm and inited by _data_init\n"
	asm += f"			.word {rooms_data_label}\n"
	asm += f"{resources_inst_data_label[1:]}:\n"
	asm += f"			.word {resources_inst_data_label}\n"
	asm += f"			.word {containers_inst_data_label}\n"
	asm += f"			.byte {level_j["hero_start_pos"]["y"]}			; hero start pos_y\n"
	asm += f"			.byte {level_j["hero_start_pos"]["x"]}			; hero start pos_x\n"
	asm += f"@data_end:\n"
	asm += f"{data_init_tbl_label.upper()}_LEN = @data_end - {data_init_tbl_label}\n"
	asm += "\n"

	asm += f'{level_name.upper()}_RECOURCES_DATA_LEN = {resources_inst_data_len}\n'
	asm += f'{level_name.upper()}_CONTAINERS_DATA_LEN = {containers_inst_data_len}\n'
	asm += "\n"


	#=====================================================================
	# init func
	asm += f"; in:\n"
	asm += f"; bc - {level_name.upper()}_DATA_ADDR\n"
	asm += f"; l - RAM_DISK_S\n"
	asm += f"; h - RAM_DISK_M\n"
	asm += f"; ex. hl = RAM_DISK_M_LV0_GFX<<8 | RAM_DISK_S_LV0_GFX\n"
	asm += f"{level_name}_data_init:\n"
	asm += f"			shld {data_init_tbl_label}\n"
	asm += f"\n"

	asm += f"			push b\n"
	asm += f"\n"

	asm += f"			lxi h, {rooms_data_label}\n"
	asm += f"			call add_offset_to_labels_eod\n"
	asm += f"\n"

	asm += f"			pop d\n"
	asm += f"			; d = {level_name.upper()}_DATA_ADDR\n"
	asm += f"\n"

	asm += f"			lxi h, {resources_inst_data_label[1:]}\n"
	asm += f"			mvi c, 2 ; _lv0_resources_inst_data_ptrs and _lv0_containers_inst_data_ptrs\n"
	asm += f"			call add_offset_to_labels_len\n"
	asm += f"\n"

	asm += f"			; copy a level init data\n"
	asm += f"			lxi h, {data_init_tbl_label}\n"
	asm += f"			lxi d, lv_data_init_tbl\n"
	asm += f"			lxi b, {data_init_tbl_label.upper()}_LEN\n"
	asm += f"			call mem_copy_len\n"

	asm += f"			ret \n"
	asm += f"\n"

	#=====================================================================
	# list of labels and their addrs
	for label, addr in data_ptrs.items():
		asm += f"{label} = 0x{addr:04x}\n"
	asm += "\n"

	return asm

def get_rooms_j(asset_dir, room_paths):

	rooms_j = []
	# load and process tiled map
	for room_path_p in room_paths:
		room_path = room_path_p['path']
		with open(asset_dir + room_path, "rb") as file:
			rooms_j.append(json.load(file))

	return rooms_j