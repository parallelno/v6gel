import os
import json

from utils import build
from utils import common
from export import export_config_utils
from export import export_font
from export import export_music
from export import export_level_data
from export import export_level_gfx
from export import export_sprite
from export import export_fdd
from export import export_tiled_img_data
from export import export_tiled_img_gfx
from export import export_text
from export import export_decal
from export import export_back
from export import export_palette

import fddutil_python.src.fddimage as fddimage


#===============================================================================
#
# helper funcs
#
#===============================================================================

def export_ram_data_labels(build_code_dir, segments_info, main_asm_labels):
	# use the main programm labels to find preshift anim labels and their addrs
	asm = "; ram_data_labels:\n"

	for seg_info in segments_info:
		ram_data_paths = seg_info["ram_include_paths"]
		for ram_data_path in ram_data_paths:
			if len(ram_data_path) != 0:
				asm += export_sprite.get_anim_labels(ram_data_path, main_asm_labels)
	asm += "\n"

	path = f"{build_code_dir}ram_data_labels{build.EXT_ASM}"
	with open(path, "w") as file:
		file.write(asm)

def export_autoexec(com_filename, autoexec_path):
	# delete output file if it exists
	if os.path.exists(autoexec_path):
		os.remove(autoexec_path)

	with open(autoexec_path, 'w') as f:
		f.write("A:\n")
		f.write(com_filename + "\n")

def export_build_consts(config_j, build_code_dir):

	# save an inter-build const file
	build_consts_filename = 'build_consts' + build.EXT_ASM
	build_consts_path = build.BUILD_PATH + build_consts_filename
	code_consts_filename = 'code_consts' + build.EXT_ASM
	code_consts_path = build_code_dir + code_consts_filename
	with open(build_consts_path, 'w') as f:
		f.write(f'.include "{code_consts_path}"\n')


	asm = ""

	asm += "; Config consts:\n"
	for const in config_j["consts"]:
		asm += const + "\n"
	asm += "\n"

	# ram disk reservations
	asm += "; RAM Disk reserved blocks:\n"
	for reservation in config_j["ram_disk_reserve"]:
		idx = reservation["bank_idx"]
		asm += f"RAM_DISK_M_{reservation["name"]} = RAM_DISK_M{idx}\n"
		asm += f"RAM_DISK_S_{reservation["name"]} = RAM_DISK_S{idx}\n"

	# save the file
	with open(code_consts_path, 'w') as f:
		f.write(asm)


def export_build_includes(assets, extra_includes):
	# prepare the include path
	build_include_path = build.BUILD_PATH + "build_includes" + build.EXT_ASM

	# delete output file if it exists
	if os.path.exists(build_include_path):
		os.remove(build_include_path)

	build_include = ""

	# include all meta files
	already_included = set()
	for asset in assets:
		asm_path = asset["asm_meta_path"]
		if asm_path not in already_included:
			build_include += f'@memusage_{os.path.basename(asm_path).split('.')[0]}:\n'
			build_include += f'.include "{asm_path}"\n'
			already_included.add(asm_path)

	build_include += "\n"

	# include all includes
	for include_path in extra_includes:
		build_include += f'.include "{include_path}"\n'
	build_include += "\n"

	# save the file
	with open(build_include_path, 'w') as f:
		f.write(build_include)


def get_asset_export_paths(asset_j_path, build_bin_dir):
	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	asset_name = common.path_to_basename(asset_j_path)
	asset_type = asset_j["asset_type"]
	export_asm_dir = os.path.join(build.build_subfolder, asset_type)

	# linked to the main program
	asm_meta_path = os.path.join(export_asm_dir, asset_name + "_meta" + build.EXT_ASM)
	# exported into the fdd file
	asm_data_path = os.path.join(export_asm_dir, asset_name + "_data" + build.EXT_ASM)
	bin_path = os.path.join(build_bin_dir, build.get_cpm_filename(asset_name))

	return asm_meta_path, asm_data_path, bin_path, asset_type


def export_mem_usage(
		raw_labels_path, mem_usage_path,
		ram_disk_usage_report, fdd_free_space,
		ram_free_space_label = "RAM_FREE_SPACE"):
	with open(raw_labels_path, "r") as file:
		raw_labels = file.readlines()

	free_ram = 0
	labels_addrs = {}

	for line in raw_labels:
		if line.find("$") == -1:
			continue
		label, _, addrS = line.partition(' ')
		addr = int(addrS[1:], 16)
		if label.startswith("memusage_"):
			labels_addrs[label] = addr
		if label == ram_free_space_label:
			free_ram = addr

	# calc the size of each element in labels_addrs
	labels = list(labels_addrs.keys())
	code_blocks_sizes = {}
	code_block_len = len(labels) - 1 # because the last one is EOD
	for i in range(code_block_len):
		label_name = labels[i]
		next_label_name = labels[i + 1]
		code_blocks_sizes[label_name] = labels_addrs[next_label_name] - labels_addrs[label_name]

	# sort the code block sizes by mem usage
	code_blocks_sizes = dict(sorted(code_blocks_sizes.items(), key=lambda item: item[1], reverse=True))

	# store the code block sizes into mem_usage_path
	with open(mem_usage_path, "w") as file:
		file.write(f"## Main Ram memory usage:\n")
		file.write(f"> Free Space: `{free_ram}`\n\n")
		file.write(f"|Assembly| Usage|\n")
		file.write(f"|-|-|\n")
		for label_name in code_blocks_sizes:
			file.write(f"|{label_name}:|{code_blocks_sizes[label_name]}|\n")
		file.write(f"\n")

		# write the fdd free space report
		file.write(f"## FDD Usage:\n")
		file.write(f"> Used: `{fddimage.FDD_SIZE - fdd_free_space}`, Free Space: `{fdd_free_space}`\n\n")

		# write the RAM Disk usage report
		file.write(f"## Ram disk usage:\n")
		file.write(f"{ram_disk_usage_report}\n")