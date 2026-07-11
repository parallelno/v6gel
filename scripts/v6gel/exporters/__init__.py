"""v6 asset exporters.

Each submodule exposes ``export(ctx: ExportContext) -> AssetManifest``.
The :data:`EXPORTERS` registry maps an ``asset_type`` to its module so the
``v6export`` CLI can dispatch generically.
"""

from utils import consts

from exporters.context import ExportContext, AssetManifest

# Imported lazily inside get_exporter to keep optional heavy deps (PIL, lhafile)
# out of the import path when they are not needed.
_REGISTRY = {
	consts.ASSET_TYPE_MUSIC: "exporters.music",
	consts.ASSET_TYPE_BACK: "exporters.back",
	consts.ASSET_TYPE_PALETTE: "exporters.palette",
	consts.ASSET_TYPE_SPRITE: "exporters.sprite",
	consts.ASSET_TYPE_DECAL: "exporters.decal",
	consts.ASSET_TYPE_FONT: "exporters.font",
	consts.ASSET_TYPE_TEXT_ENG: "exporters.text",
	consts.ASSET_TYPE_TEXT_RUS: "exporters.text",
	consts.ASSET_TYPE_LEVEL_DATA: "exporters.level_data",
	consts.ASSET_TYPE_LEVEL_GFX: "exporters.level_gfx",
	consts.ASSET_TYPE_TILED_IMG_DATA: "exporters.tiled_img_data",
	consts.ASSET_TYPE_TILED_IMG_GFX: "exporters.tiled_img_gfx",
}


def supported_types():
	return sorted(_REGISTRY.keys())


def get_exporter(asset_type):
	"""Return the ``export`` callable for ``asset_type`` or ``None``."""
	module_name = _REGISTRY.get(asset_type)
	if module_name is None:
		return None
	import importlib
	module = importlib.import_module(module_name)
	return module.export


__all__ = [
	"ExportContext",
	"AssetManifest",
	"supported_types",
	"get_exporter",
]
