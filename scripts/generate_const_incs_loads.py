import json
import os
import export.export_config as export_config
import export.export_config_utils as export_config_utils
import utils.build as build
import utils.common as common
import argparse

"""
Generate the includes, consts, and fdd loads for every asset in the config JSON file.
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

# export config consts, includes, and fdd asset load code
build.printc(";===========================================================================", build.TextColor.MAGENTA)
build.printc(";", build.TextColor.MAGENTA)
build.printc(f"; Generate includes, consts, and fdd loads: {args.config_path}", build.TextColor.MAGENTA)
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

# check the assets file exists
if not os.path.exists(build.BUILD_ASSETS_INFO_PATH):
	build.exit_error(f'generate_const_incs_loads ERROR: assets file not found: {build.BUILD_ASSETS_INFO_PATH}')

# load the assets info JSON
with open(build.BUILD_ASSETS_INFO_PATH, "r") as file:
	assets = json.load(file)

# generate "len" fileds for assets
for asset in assets:
	bin_path = asset["bin_path"]
	if os.path.exists(bin_path):
		asset["len"] = os.path.getsize(bin_path)
	else:
		build.exit_error(f'generate_const_incs_loads ERROR: asset bin file not found: {bin_path}')

# export the code to load assets & a memory usage report
loads_path, ram_disk_usage_report = \
	export_config_utils.export_loads(config_j, assets, build_code_dir, build_bin_dir)

export_config.export_build_includes(assets, [loads_path])
export_config.export_build_consts(config_j, build_code_dir)

# export autoexec
autoexec_path = build_bin_dir + build.get_cpm_filename('autoexec', build.EXT_BAT)
com_filename = build.get_cpm_filename('app', build.EXT_COM)
export_config.export_autoexec(com_filename, autoexec_path)