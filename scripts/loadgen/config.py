"""Build config loading and validation for the v6 asset pipeline."""

from utils import common, consts
from utils.log import ExportError


def load_build_config(path):
	"""Load a build config JSON and verify it is a config asset."""
	config_j = common.load_json(path)
	if config_j.get("asset_type") != consts.ASSET_TYPE_CONFIG:
		raise ExportError(f"asset_type != '{consts.ASSET_TYPE_CONFIG}': {path}")
	return config_j