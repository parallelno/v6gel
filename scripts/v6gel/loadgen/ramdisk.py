"""RAM disk layout, packing, and reporting for v6 load generation."""

import os

from utils import common, consts


def get_ram_disk_layout(config_j):
	segments = {}
	for bank_idx in range(consts.RAM_DISK_BANKS_MAX):
		# segment before the stack
		seg_name0 = f"bank{bank_idx} addr0"
		segments[seg_name0] = {
			"bank_idx": bank_idx,
			"start_addr": 0,
			"load_addr": 0,
			"non_permanent_load_addr": 0,
			"len": consts.RAM_DISK_SEGMENT_LEN - consts.ALL_STACKS_LEN,
		}

		# segment after the stack
		seg_name1 = f"bank{bank_idx} addr8000"
		seg_len1 = consts.RAM_DISK_SEGMENT_LEN
		reservation = next(
			(x for x in config_j["ram_disk_reserve"] if x["bank_idx"] == bank_idx), None
		)
		if reservation is not None and "len" in reservation:
			seg_len1 -= common.hex_str_to_int(reservation["len"])

		segments[seg_name1] = {
			"bank_idx": bank_idx,
			"start_addr": consts.SCR_ADDR,
			"load_addr": consts.SCR_ADDR,
			"non_permanent_load_addr": consts.SCR_ADDR,
			"len": seg_len1,
		}

	return segments


def pack_files(load_name, assets, segments):
	special = []
	regular = []
	for asset in assets:
		if asset["load_name"] != load_name:
			continue
		(special if asset["after_stack"] else regular).append(asset)

	# Sort by size descending (largest first).
	special = sorted(special, key=lambda x: x["len"], reverse=True)
	regular = sorted(regular, key=lambda x: x["len"], reverse=True)

	seg_space = {}
	for seg_name, seg in segments.items():
		reserved = seg["non_permanent_load_addr"] - seg["start_addr"]
		seg_space[seg_name] = seg["len"] - reserved

	allocation = {seg_name: [] for seg_name in segments}
	after_stack_segs = [
		name for name, segment in segments.items() if segment["start_addr"] == consts.SCR_ADDR
	]

	# Step 1: place after-stack-only files in the high segments.
	for asset in special:
		placed = False
		for seg_name in sorted(after_stack_segs, key=lambda x: seg_space[x], reverse=True):
			align = asset["align"]
			alignment_offset = (align - segments[seg_name]["load_addr"] % align) % align
			if asset["len"] + alignment_offset <= seg_space[seg_name]:
				asset["addr"] = segments[seg_name]["load_addr"] + alignment_offset
				segments[seg_name]["load_addr"] += asset["len"] + alignment_offset
				allocation[seg_name].append(asset)
				seg_space[seg_name] -= asset["len"] + alignment_offset
				placed = True
				break
		if not placed:
			return None, None, (
				"can't fit after-stack files into the high segments. "
				f"bin_path:{asset['bin_path']}"
			)

	# Step 2: place regular files into any segment (tightest fit first).
	for asset in regular:
		placed = False
		for seg_name in sorted(seg_space.keys(), key=lambda x: seg_space[x]):
			if asset["len"] <= seg_space[seg_name]:
				asset["addr"] = segments[seg_name]["load_addr"]
				segments[seg_name]["load_addr"] += asset["len"]
				allocation[seg_name].append(asset)
				seg_space[seg_name] -= asset["len"]
				placed = True
				break
		if not placed:
			return None, None, (
				f"can't fit file into the RAM Disk. bin_path:{asset['bin_path']}"
			)

	free_space = sum(seg_space.values())
	return allocation, free_space, None


def get_usage_report(load_name, allocation, free_space, segments):
	total_used = 0
	report = f"### `{load_name}` RAM Disk usage:\n"
	total_reserved = 0
	seg_report = ""
	for seg_name, seg in allocation.items():
		seg_report += f"- {seg_name}\n"
		used_len = 0
		for asset in seg:
			bin_file_name = os.path.basename(asset["bin_path"])
			seg_report += (
				f"\t* {bin_file_name}: addr: {asset['addr']}, len: `{asset['len']}`\n"
			)
			used_len += asset["len"]

		non_perm_load_addr = segments[seg_name]["non_permanent_load_addr"]
		start_addr = segments[seg_name]["start_addr"]
		reserved = non_perm_load_addr - start_addr
		total_reserved += reserved

		free = segments[seg_name]["len"] - used_len - reserved
		seg_report += "\n"
		seg_report += f"  `Used: {used_len}, Free: {free}`\n\n"
		total_used += used_len

	report += "\n"
	report += f"> Used: `{total_used}`, Free Space: `{free_space}`\n\n"
	report += seg_report
	report += "\n---\n"
	return report