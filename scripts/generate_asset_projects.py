import json
import os
import export.export_config as export_config
from export import export_back, export_decal, export_font, export_level_data, export_level_gfx, export_music, export_palette, export_sprite, export_text, export_tiled_img_data, export_tiled_img_gfx
import utils.build as build
import utils.common as common
import argparse

"""
Generate the asset projects and their asm files for every asset in the config JSON file.
"""

# args parsing
parser = argparse.ArgumentParser(description="Process arguments.")
parser.add_argument("-config_path", help="The config path")
parser.add_argument("-build_name", help="Defines the name of the build subfolder", default="release")
parser.add_argument("-script_debug", action="store_true", help="This flag is to python script debugging purposes", default=False)
args = parser.parse_args()

build.set_debug(args.script_debug)
build.set_build_subfolder(args.build_name)

if not args.config_path:
	exit("Error: No config path provided. Use -config_path to provide the path.")


build.printc(";===========================================================================", build.TextColor.MAGENTA)
build.printc(";", build.TextColor.MAGENTA)
build.printc(f"; Generate asset ASM files: {args.config_path}", build.TextColor.MAGENTA)
build.printc(";", build.TextColor.MAGENTA)
build.printc(";===========================================================================", build.TextColor.MAGENTA)
print("\n")

common.CheckPath(args.config_path, "Config file not found")
with open(args.config_path, "rb") as file:
		config_j = json.load(file)

common.CheckJsonField(
	config_j, "asset_type",
	f'export_config ERROR: asset_type != "{build.ASSET_TYPE_CONFIG}", path: {args.config_path}',
	build.ASSET_TYPE_CONFIG)

# set the global vars
build.set_packer(build.PACKER_ZX0_SALVADORE, config_j["packer_path"])
build.build_db_init(config_j["build_db_path"])

# make required directories
build_code_dir = build.build_subfolder + config_j["export_dir"]["code"]
build_bin_dir = build.BIN_DIR
os.makedirs(os.path.dirname(build.build_subfolder), exist_ok=True)
os.makedirs(os.path.dirname(build_code_dir), exist_ok=True)
os.makedirs(os.path.dirname(build_bin_dir), exist_ok=True)

# check if general scripts were updated
dependency_paths_j = config_j["dependencies"]
global_force_export = False
for path in dependency_paths_j["scripts"]:
	if not os.path.exists(path):
		build.exit_error(f'export_config ERROR: script file not found: {path}')
	global_force_export |= build.is_file_updated(path)
asset_types_dependencies = dependency_paths_j["exporters"]


# check if asset-type-related scripts were updated
asset_types_force_export = {}
for asset_type in asset_types_dependencies:
	path = asset_types_dependencies[asset_type]
	if not os.path.exists(path):
		build.exit_error(f'export_config ERROR: script file not found: {path}')
	asset_types_force_export[asset_type] = global_force_export | build.is_file_updated(path)

# export assets
assets = []
# export the loads
for load_name in config_j["loads"]:
	for asset_j_path in config_j["loads"][load_name]:

		if not os.path.exists(asset_j_path):
			build.exit_error(f'export_config ERROR: file not found: {asset_j_path}')

		asm_meta_path, asm_data_path, bin_path, asset_type = \
			export_config.get_asset_export_paths(asset_j_path, build_bin_dir)

		force_export = asset_types_force_export[asset_type]

		match asset_type:
			case build.ASSET_TYPE_FONT:
				export_font.export_if_updated(
						asset_j_path,
						asm_meta_path, asm_data_path, bin_path,
						force_export)

			case build.ASSET_TYPE_MUSIC:
				export_music.export_if_updated(
						asset_j_path,
						asm_meta_path, asm_data_path, bin_path,
						force_export)

			case build.ASSET_TYPE_LEVEL_DATA:
				export_level_data.export_if_updated(
						asset_j_path,
						asm_meta_path, asm_data_path, bin_path,
						force_export)

			case build.ASSET_TYPE_LEVEL_GFX:
				export_level_gfx.export_if_updated(
						asset_j_path,
						asm_meta_path, asm_data_path, bin_path,
						force_export)

			case build.ASSET_TYPE_SPRITE:
				export_sprite.export_if_updated(
						asset_j_path,
						asm_meta_path, asm_data_path, bin_path,
						force_export)

			case build.ASSET_TYPE_TILED_IMG_DATA:
				export_tiled_img_data.export_if_updated(
						asset_j_path,
						asm_meta_path, asm_data_path, bin_path,
						force_export)

			case build.ASSET_TYPE_TILED_IMG_GFX:
				export_tiled_img_gfx.export_if_updated(
						asset_j_path,
						asm_meta_path, asm_data_path, bin_path,
						force_export)

			case build.ASSET_TYPE_TEXT_ENG:
				export_text.export_if_updated(
						asset_j_path,
						asm_meta_path, asm_data_path, bin_path,
						force_export, build.LOCAL_ENG)

			case build.ASSET_TYPE_TEXT_RUS:
				export_text.export_if_updated(
						asset_j_path,
						asm_meta_path, asm_data_path, bin_path,
						force_export, build.LOCAL_RUS)

			case build.ASSET_TYPE_DECAL:
				export_decal.export_if_updated(
						asset_j_path,
						asm_meta_path, asm_data_path, bin_path,
						force_export)

			case build.ASSET_TYPE_BACK:
				export_back.export_if_updated(
						asset_j_path,
						asm_meta_path, asm_data_path, bin_path,
						force_export)
			case build.ASSET_TYPE_PALETTE:
				export_palette.export_if_updated(
						asset_j_path,
						asm_meta_path, asm_data_path, bin_path,
						force_export)
		asset = {
			"load_name": load_name,
			"asset_j_path" : asset_j_path,
			"asm_meta_path": asm_meta_path,
			"asm_data_path": asm_data_path,
			"bin_path": bin_path,
			"type": asset_type,
		}
		assets.append(asset)

# store the assets info JSON
with open(build.BUILD_ASSETS_INFO_PATH, "w") as file:
	json.dump(assets, file, indent=4)

# generate asset projects
build.printc(";===========================================================================", build.TextColor.MAGENTA)
build.printc(";", build.TextColor.MAGENTA)
build.printc(f"; Generate asset projects: {args.config_path}", build.TextColor.MAGENTA)
build.printc(";", build.TextColor.MAGENTA)
build.printc(";===========================================================================", build.TextColor.MAGENTA)
print("\n")
# '"romAlign": 2' makes the bin file length even.
# The even len is required for the procedure of loading files from the FDD
# it operates with words (pop/push asm instructions) and it is aligned with
# the 0x0000 starts offset, so if the len on any file is odd, the alignment
# will be broken.
project_dir = build.ASSET_PROJECTS_DIR
os.makedirs(project_dir, exist_ok=True)
for asset in assets:
	asset_name = common.path_to_basename(asset["asset_j_path"])
	asmPath = asset["asm_data_path"].replace('build/', '../')
	romPath = asset["bin_path"].replace('build/', '../')

	project_j = {
		"name": asset_name,
		"asmPath": asmPath,
		"romPath": romPath,
		"romAlign": 2,
	}
	project_path = os.path.join(project_dir, project_j["name"] + '.project' + build.EXT_JSON)
	with open(project_path, "w") as file:
		json.dump(project_j, file, indent=4)
		build.printc(f"Generated asset project: {project_path}", build.TextColor.GREEN)
