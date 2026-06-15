"""Asset manifest helpers for load generation."""

import os

from exporters.context import AssetManifest
from utils import common, consts
from utils.log import error


def collect_assets(config_j, manifest_dir):
	"""Build the flat asset list the RAM disk packer and codegen operate on."""
	special_types = config_j.get("loaded_after_stack", [])
	types_alignment = config_j.get("types_alignment", {})
	assets = []
	for load_name, asset_paths in config_j["loads"].items():
		for asset_path in asset_paths:
			name = common.path_to_basename(asset_path)
			manifest_path = os.path.join(manifest_dir, name + consts.EXT_MANIFEST)
			if not os.path.exists(manifest_path):
				error("manifest not found", manifest_path)
			manifest = AssetManifest.read(manifest_path)

			if not os.path.exists(manifest.bin_path):
				error("asset blob not found", manifest.bin_path)

			asset_type = manifest.asset_type
			after_stack = asset_type in special_types
			align = types_alignment.get(asset_type, consts.WORD_LEN)

			assets.append({
				"type": asset_type,
				"load_name": load_name,
				"name": name,
				"bin_path": manifest.bin_path,
				"asm_meta_path": manifest.meta_asm_path,
				"asset_j_path": asset_path,
				"len": manifest.bin_len,
				"after_stack": after_stack,
				"align": align,
			})
	return assets