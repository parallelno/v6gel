"""Decal exporter: masked 4-plane sprites plus named pointer lists.

Faithful port of the original ``export_decal`` layout (see
``v6/gfx/v6_decal_draw.asm``).
"""

from PIL import Image

from utils import asmgen, common, common_gfx, consts
from exporters.context import AssetManifest, ExportContext


def export(ctx: ExportContext) -> AssetManifest:
	asset_j = ctx.meta
	name = ctx.name

	image = Image.open(ctx.asset_rel("path_png"))
	_, colors, _, _ = common_gfx.palette_file_to_asm(
		ctx.asset_rel("palette_path"), ctx.meta_path
	)
	image = common_gfx.remap_colors(image, colors)

	data_asm, relative_ptrs = _gfx_to_asm("_", name, asset_j, image)
	meta_body = _meta_to_asm("_", name, asset_j, relative_ptrs)

	keep_asm = ctx.data_asm_path if ctx.emit_asm else None
	bin_len = asmgen.assemble(
		ctx.v6asm_path, data_asm, ctx.bin_path, ctx.temp_dir, keep_asm
	)
	with open(ctx.meta_asm_path, "w", encoding="ascii") as f:
		f.write(asmgen.meta_asm(ctx.stored_path, meta_body))

	return AssetManifest(
		name=name,
		asset_type=consts.ASSET_TYPE_DECAL,
		bin_path=ctx.bin_path,
		bin_len=bin_len,
		meta_asm_path=ctx.meta_asm_path,
		data_asm_path=keep_asm,
	)


def _gfx_to_asm(label_prefix, asset_name, asset_j, image):
	relative_ptrs = {}
	relative_addr = consts.SAFE_WORD_LEN
	asm = f"{label_prefix}{asset_name}_sprites:"

	for sprite in asset_j["sprites"]:
		sprite_name = sprite["name"]
		x = sprite["x"]
		y = sprite["y"]
		width = sprite["width"]
		height = sprite["height"]
		offset_x = sprite.get("offset_x") or 0
		offset_y = sprite.get("offset_y") or 0
		mask_x = sprite.get("mask_x", x)
		mask_y = sprite.get("mask_y", y)
		mask_alpha = sprite.get("mask_alpha", 0)

		sprite_img = []
		for py in reversed(range(y, y + height)):
			sprite_img.append([image.getpixel((px, py)) for px in range(x, x + width)])

		bits0, bits1, bits2, bits3 = common_gfx.indexes_to_bit_lists(sprite_img)
		bytes0 = common.combine_bits_to_bytes(bits0)
		bytes1 = common.combine_bits_to_bytes(bits1)
		bytes2 = common.combine_bits_to_bytes(bits2)
		bytes3 = common.combine_bits_to_bytes(bits3)

		mask_img = []
		for py in reversed(range(mask_y, mask_y + height)):
			for px in range(mask_x, mask_x + width):
				mask_img.append(1 if image.getpixel((px, py)) == mask_alpha else 0)
		mask_bytes = common.combine_bits_to_bytes(mask_img)

		data = _sprite_data(bytes0, bytes1, bytes2, bytes3, width, height, mask_bytes)
		frame_label = f"{label_prefix}{asset_name}_{sprite_name}_relative"
		asm += "\n"
		asm += "			.word 0  ; safety pair of bytes for reading by POP B\n"
		asm += f"{frame_label}:\n"

		width_packed = width // 8 - 1
		offset_x_packed = offset_x // 8
		asm += f"			.byte {offset_y}, {offset_x_packed}; offset_y, offset_x\n"
		asm += f"			.byte {height}, {width_packed}; height, width\n"
		asm += common.bytes_to_asm(data)
		asm += "\n"

		frame_data_len = len(data) + consts.SAFE_WORD_LEN + 2 + 2
		relative_ptrs[frame_label] = relative_addr
		relative_addr += frame_data_len

	return asm, relative_ptrs


def _meta_to_asm(label_prefix, asset_name, asset_j, relative_ptrs):
	asm = "; relative frame labels\n"
	for label_name, addr in relative_ptrs.items():
		asm += f"{label_name} = {addr}\n"
	asm += "\n"
	asm += _lists_of_sprites_ptrs_to_asm(label_prefix, asset_name, asset_j)
	return asm


def _lists_of_sprites_ptrs_to_asm(label_prefix, asset_name, asset_j):
	asm = f"{asset_name}_gfx_ptrs:\n"
	for list_name in asset_j["lists"]:
		asm += f"{list_name}_gfx_ptrs: .word "
		for sprite_name in asset_j["lists"][list_name]:
			asm += f"{label_prefix}{asset_name}_{sprite_name}_relative, "
		asm += "\n"
	asm += ".word EOD ; used to convert relative ptrs to absolute\n"
	return asm


def _sprite_data(bytes0, bytes1, bytes2, bytes3, w, h, mask_bytes):
	# Data format in v6_decal_draw.asm: 4 screen buffers with a mask,
	# alternating plane order per even/odd line. Width is /8 (8 px per byte).
	width = w // 8
	data = []
	for y in range(h):
		even_line = y % 2 == 0
		planes = (bytes0, bytes1, bytes2, bytes3) if even_line else (bytes3, bytes2, bytes1, bytes0)
		# mask, then first plane ascending, then remaining planes descending.
		for x in range(width):
			data.append(mask_bytes[y * width + x])
		for x in range(width):
			data.append(planes[0][y * width + x])
		for plane in planes[1:]:
			for x in range(width):
				data.append(plane[y * width + width - x - 1])
	return data
