"""Level data exporter: per-room tile/teleport data plus resource/container
instance tables.

Faithful port of the original ``export_level_data``. Per-room data keeps its
format-intrinsic zx0 compression (now performed via v6asm + the external
packer through :func:`utils.common.compress_block_to_asm`).
"""

import json
from pathlib import Path

from utils import asmgen, common, consts
from utils.log import error
from exporters import level_common
from exporters.context import AssetManifest, ExportContext


def export(ctx: ExportContext) -> AssetManifest:
	level_j_path = ctx.asset_rel("path_level")

	data_asm, data_ptrs, resources, resource_max, containers, container_max = (
		_ram_disk_data_to_asm(ctx, level_j_path)
	)
	meta_body = _ram_data_to_asm(
		data_ptrs, level_j_path, resources, resource_max, containers, container_max
	)

	keep_asm = ctx.data_asm_path if ctx.emit_asm else None
	bin_len = asmgen.assemble(
		ctx.v6asm_path, data_asm, ctx.bin_path, ctx.temp_dir, keep_asm
	)
	with open(ctx.meta_asm_path, "w", encoding="ascii") as f:
		f.write(asmgen.meta_asm(ctx.stored_path, meta_body))

	return AssetManifest(
		name=ctx.name,
		asset_type=consts.ASSET_TYPE_LEVEL_DATA,
		bin_path=ctx.bin_path,
		bin_len=bin_len,
		meta_asm_path=ctx.meta_asm_path,
		data_asm_path=keep_asm,
	)


def _get_rooms_j(level_dir, room_paths):
	rooms_j = []
	for room_path_p in room_paths:
		with open(level_dir + room_path_p["path"], "rb") as f:
			rooms_j.append(json.load(f))
	return rooms_j


def _ram_disk_data_to_asm(ctx, level_j_path):
	level_j = common.load_json(level_j_path)
	level_dir = str(Path(level_j_path).parent) + "/"
	room_paths = level_j["rooms"]

	rooms_j = _get_rooms_j(level_dir, room_paths)
	remap_idxs = level_common.remap_index(rooms_j)

	resources = {}
	resource_max_tiledata = 0
	containers = {}
	container_max_tiledata = 0
	breakables_count = 0

	room_data_asm = ""
	room_data_ptrs = {}
	room_addr_offset = 0

	for room_id, room_j in enumerate(rooms_j):
		room_path = room_paths[room_id]["path"]

		room_tiledatas_unclamped = room_j["layers"][1]["data"]
		room_tiledata = [x % 256 for x in room_tiledatas_unclamped]
		width = room_j["width"]
		height = room_j["height"]

		asm_room_data = level_common.room_tiles_to_asm(room_j["layers"][0], remap_idxs)

		teleport_tiles, asm_teleport_data = level_common.room_teleport_data(
			room_j["layers"][2], level_j_path
		)
		room_tiledata = level_common.merge_teleport_data(teleport_tiles, room_tiledata)
		asm_room_data += level_common.room_tiles_data_to_asm(room_tiledata, width, height)

		room_data_label = level_common.get_room_data_label(room_path)
		compressed_room_asm, data_len = common.compress_block_to_asm(
			asm_room_data, ctx.v6asm_path, ctx.packer_path, ctx.temp_dir,
			tag=f"room{room_id}",
		)

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

		room_data_ptrs[room_data_label] = room_addr_offset
		room_addr_offset += consts.WORD_LEN  # stored compressed room data len
		room_addr_offset += consts.SAFE_WORD_LEN
		room_addr_offset += data_len
		room_addr_offset += consts.SAFE_WORD_LEN
		room_addr_offset += len(teleport_tiles)
		room_addr_offset += consts.SAFE_WORD_LEN

		for i, tiledata in enumerate(room_tiledata):
			dy, dx = divmod(i, width)
			tile_idx = (height - 1 - dy) * width + dx

			if (level_common.TILEDATA_RESOURCE <= tiledata
					< level_common.TILEDATA_RESOURCE + level_common.RESOURCES_UNIQUE_MAX):
				resources.setdefault(tiledata, []).append((room_id, tile_idx))
				resource_max_tiledata = max(resource_max_tiledata, tiledata)

			if (level_common.TILEDATA_CONTAINER <= tiledata
					< level_common.TILEDATA_CONTAINER + level_common.CONTAINERS_UNIQUE_MAX):
				containers.setdefault(tiledata, []).append((room_id, tile_idx))
				container_max_tiledata = max(container_max_tiledata, tiledata)

			if (level_common.TILEDATA_BREAKABLESS <= tiledata
					< level_common.TILEDATA_BREAKABLESS + level_common.BREAKABLES_UNIQUE_MAX):
				breakables_count += 1

	asm = ""
	relative_ptrs = {}
	relative_addr = consts.SAFE_WORD_LEN
	level_name = common.path_to_basename(level_j_path)

	# resources data
	data_asm, label, data_len = _get_resources_inst_data(
		level_j_path, resources, resource_max_tiledata
	)
	asm += data_asm
	relative_ptrs[label] = relative_addr
	relative_addr += data_len + consts.SAFE_WORD_LEN

	# containers data
	data_asm, label, data_len = _get_containers_inst_data(
		level_j_path, containers, container_max_tiledata
	)
	asm += data_asm
	relative_ptrs[label] = relative_addr
	relative_addr += data_len + consts.SAFE_WORD_LEN

	# breakables count (to verify it fits the buffer)
	relative_ptrs[level_name.upper() + "_BREAKABLES"] = breakables_count

	# rooms data
	asm += room_data_asm
	for label, addr in room_data_ptrs.items():
		relative_ptrs[label] = addr + relative_addr

	return (asm, relative_ptrs, resources, resource_max_tiledata,
			containers, container_max_tiledata)


def _get_resources_inst_data(level_j_path, resources, resource_max_tiledata):
	data_len = 0
	level_prefix = common.path_to_basename(level_j_path)
	label = f"_{level_prefix}_resources_inst_data"

	asm = "NULL = 0\n\n"
	asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
	asm += f"{label}_ptrs:\n"

	if len(resources) > 0:
		asm += "			.byte "
		# pad missing tiledata so the pointer array is contiguous by res_id.
		for tiledata in range(level_common.TILEDATA_RESOURCE, resource_max_tiledata + 1):
			resources.setdefault(tiledata, [])
		resources_sorted = dict(sorted(resources.items()))

		ptr = 0
		ptrs_len = len(resources_sorted) + 1
		for tiledata in resources_sorted:
			inst_len = len(resources_sorted[tiledata]) * consts.WORD_LEN
			if len(resources_sorted[tiledata]) > 0:
				asm += f"0x{(ptr + ptrs_len):02X}, "
			else:
				asm += "NULL, "
			ptr += inst_len
			data_len += consts.BYTE_LEN
		asm += f"0x{(ptr + ptrs_len):02X}, "
		data_len += consts.BYTE_LEN

		asm += f"\n;{label}:\n"
		for tiledata in resources_sorted:
			if len(resources_sorted[tiledata]) > 0:
				asm += f";			tiledata = {tiledata}, data below is pairs of tile_idx, room_id\n"
				data = []
				for room_id, tile_idx in resources_sorted[tiledata]:
					data.append(tile_idx)
					data.append(room_id)
				asm += common.bytes_to_asm(data)
				data_len += len(data)

		if ptr + ptrs_len > 256:
			error(
				f"resource instance data is {ptr + ptrs_len} bytes "
				f"(> {level_common.RESOURCES_INST_DATA_PTRS_LEN})",
				level_j_path,
			)

	asm += "\n"
	return asm, label + "_ptrs", data_len


def _get_containers_inst_data(level_j_path, containers, container_max_tiledata):
	data_len = 0
	level_prefix = common.path_to_basename(level_j_path)
	label = f"_{level_prefix}_containers_inst_data"

	asm = "			.word 0 ; safety pair of bytes for reading by POP B\n"
	asm += f"{label}_ptrs:\n"

	if len(containers) > 0:
		asm += "			.byte "
		for tiledata in range(level_common.TILEDATA_CONTAINER, container_max_tiledata + 1):
			containers.setdefault(tiledata, [])
		containers_sorted = dict(sorted(containers.items()))

		ptr = 0
		ptrs_len = len(containers_sorted) + 1
		for tiledata in containers_sorted:
			inst_len = len(containers_sorted[tiledata]) * consts.WORD_LEN
			if len(containers_sorted[tiledata]) > 0:
				byte_data = ptr + ptrs_len
			else:
				byte_data = ptr + inst_len + ptrs_len
			asm += f"0x{byte_data:02X}, "
			ptr += inst_len
			data_len += consts.BYTE_LEN
		asm += f"0x{(ptr + ptrs_len):02X}, "
		data_len += consts.BYTE_LEN

		asm += f"\n;{label}:\n"
		for tiledata in containers_sorted:
			if len(containers_sorted[tiledata]) > 0:
				asm += f";			tiledata = {tiledata}, data below is pairs of tile_idx, room_id\n"
				data = []
				for room_id, tile_idx in containers_sorted[tiledata]:
					data.append(tile_idx)
					data.append(room_id)
				asm += common.bytes_to_asm(data)
				data_len += len(data)

		if ptr + ptrs_len > level_common.CONTAINERS_INST_DATA_PTRS_LEN:
			error(
				f"container instance data is {ptr + ptrs_len} bytes "
				f"(> {level_common.CONTAINERS_INST_DATA_PTRS_LEN})",
				level_j_path,
			)

	asm += "\n"
	return asm, label + "_ptrs", data_len


def _ram_data_to_asm(data_ptrs, level_j_path, resources, resource_max_tiledata,
					containers, container_max_tiledata):
	level_j = common.load_json(level_j_path)
	level_name = common.path_to_basename(level_j_path)
	room_paths = level_j["rooms"]

	asm = ""
	rooms_data_data_asm, rooms_data_label, _ = level_common.get_list_of_rooms(
		room_paths, level_name
	)
	asm += rooms_data_data_asm

	_, resources_inst_data_label, resources_inst_data_len = _get_resources_inst_data(
		level_j_path, resources, resource_max_tiledata
	)
	_, containers_inst_data_label, containers_inst_data_len = _get_containers_inst_data(
		level_j_path, containers, container_max_tiledata
	)

	data_init_tbl_label = f"{level_name}_data_init_tbl"
	asm += f"{data_init_tbl_label}:\n"
	asm += "			.byte TEMP_BYTE ; defined in loads.asm and inited by _data_init\n"
	asm += "			.byte TEMP_BYTE ; defined in loads.asm and inited by _data_init\n"
	asm += f"			.word {rooms_data_label}\n"
	asm += f"{resources_inst_data_label[1:]}:\n"
	asm += f"			.word {resources_inst_data_label}\n"
	asm += f"			.word {containers_inst_data_label}\n"
	asm += f"			.byte {level_j['hero_start_pos']['y']}			; hero start pos_y\n"
	asm += f"			.byte {level_j['hero_start_pos']['x']}			; hero start pos_x\n"
	asm += "@data_end:\n"
	asm += f"{data_init_tbl_label.upper()}_LEN = @data_end - {data_init_tbl_label}\n\n"

	asm += f"{level_name.upper()}_RECOURCES_DATA_LEN = {resources_inst_data_len}\n"
	asm += f"{level_name.upper()}_CONTAINERS_DATA_LEN = {containers_inst_data_len}\n\n"

	asm += "; in:\n"
	asm += f"; bc - {level_name.upper()}_DATA_ADDR\n"
	asm += "; l - RAM_DISK_S\n"
	asm += "; h - RAM_DISK_M\n"
	asm += "; ex. hl = RAM_DISK_M_LV0_GFX<<8 | RAM_DISK_S_LV0_GFX\n"
	asm += f"{level_name}_data_init:\n"
	asm += f"			shld {data_init_tbl_label}\n\n"
	asm += "			push b\n\n"
	asm += f"			lxi h, {rooms_data_label}\n"
	asm += "			call add_offset_to_labels_eod\n\n"
	asm += "			pop d\n"
	asm += f"			; d = {level_name.upper()}_DATA_ADDR\n\n"
	asm += f"			lxi h, {resources_inst_data_label[1:]}\n"
	asm += "			mvi c, 2 ; _lv0_resources_inst_data_ptrs and _lv0_containers_inst_data_ptrs\n"
	asm += "			call add_offset_to_labels_len\n\n"
	asm += "			; copy a level init data\n"
	asm += f"			lxi h, {data_init_tbl_label}\n"
	asm += "			lxi d, lv_data_init_tbl\n"
	asm += f"			lxi b, {data_init_tbl_label.upper()}_LEN\n"
	asm += "			call mem_copy_len\n"
	asm += "			ret \n\n"

	for label, addr in data_ptrs.items():
		asm += f"{label} = 0x{addr:04x}\n"
	asm += "\n"
	return asm
