"""Tiled-image graphics exporter: 8x8 tile bitmaps (no mask).

Faithful port of the original ``export_tiled_img_gfx``.
"""

from pathlib import Path

from PIL import Image

from utils import asmgen, common, common_gfx, consts
from utils.log import error
from exporters import tiled_img_common
from exporters.context import AssetManifest, ExportContext


def export(ctx: ExportContext) -> AssetManifest:
	tiled_img_j_path = ctx.asset_rel("path_tiled_img")

	data_asm = _data_to_asm(tiled_img_j_path)

	keep_asm = ctx.data_asm_path if ctx.emit_asm else None
	bin_len = asmgen.assemble(
		ctx.v6asm_path, data_asm, ctx.bin_path, ctx.temp_dir, keep_asm
	)
	with open(ctx.meta_asm_path, "w", encoding="ascii") as f:
		f.write(asmgen.meta_asm(ctx.stored_path))

	return AssetManifest(
		name=ctx.name,
		asset_type=consts.ASSET_TYPE_TILED_IMG_GFX,
		bin_path=ctx.bin_path,
		bin_len=bin_len,
		meta_asm_path=ctx.meta_asm_path,
		data_asm_path=keep_asm,
	)


def _data_to_asm(tiled_img_j_path):
	source_j = common.load_json(tiled_img_j_path)
	source_dir = str(Path(tiled_img_j_path).parent) + "/"
	source_name = common.path_to_basename(tiled_img_j_path)

	path_png = source_dir + source_j["path_png"]
	image = Image.open(path_png)

	_, colors, _, _ = common_gfx.palette_file_to_asm(
		source_dir + source_j["palette_path"], path_png, "_" + source_name
	)
	image = common_gfx.remap_colors(image, colors)

	tiled_file_j = common.load_json(source_dir + source_j["path"])
	remap_idxs = tiled_img_common.remap_indices(tiled_file_j)

	if len(remap_idxs) > tiled_img_common.TILED_IMG_GFX_IDX_MAX:
		error(
			f"gfx_idxs > {tiled_img_common.TILED_IMG_GFX_IDX_MAX}",
			tiled_img_j_path,
		)

	png_name = common.path_to_basename(path_png)
	return tiled_img_common.gfx_to_asm("_" + png_name, image, remap_idxs)
