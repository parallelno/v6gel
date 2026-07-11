"""Background exporter (full-screen, non-animated 4-plane image).

Faithful port of the original ``export_back`` byte layout; only the interface
(staleness/IO) changed. See ``v6/gfx/v6_back_draw.asm`` for the data format.
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
	meta_body = _anims_to_asm("_", name, asset_j, relative_ptrs)

	keep_asm = ctx.data_asm_path if ctx.emit_asm else None
	bin_len = asmgen.assemble(
		ctx.v6asm_path, data_asm, ctx.bin_path, ctx.temp_dir, keep_asm
	)
	with open(ctx.meta_asm_path, "w", encoding="ascii") as f:
		f.write(asmgen.meta_asm(ctx.stored_path, meta_body))

	return AssetManifest(
		name=name,
		asset_type=consts.ASSET_TYPE_BACK,
		bin_path=ctx.bin_path,
		bin_len=bin_len,
		meta_asm_path=ctx.meta_asm_path,
		data_asm_path=keep_asm,
	)


def _gfx_to_asm(label_prefix, asset_name, asset_j, image):
	sprites_j = asset_j["sprites"]
	relative_ptrs = {}
	sprite_data_relative_addr = consts.SAFE_WORD_LEN
	asm = f"{label_prefix}{asset_name}_sprites:"

	for sprite in sprites_j:
		sprite_name = sprite["name"]
		x = sprite["x"]
		y = sprite["y"]
		width = sprite["width"]
		height = sprite["height"]
		offset_x = sprite.get("offset_x", 0)
		offset_y = sprite.get("offset_y", 0)

		# Y is reversed: the game stores images bottom-to-top.
		sprite_img = []
		for py in reversed(range(y, y + height)):
			line = [image.getpixel((px, py)) for px in range(x, x + width)]
			sprite_img.append(line)

		bits0, bits1, bits2, bits3 = common_gfx.indexes_to_bit_lists(sprite_img)
		bytes0 = common.combine_bits_to_bytes(bits0)
		bytes1 = common.combine_bits_to_bytes(bits1)
		bytes2 = common.combine_bits_to_bytes(bits2)
		bytes3 = common.combine_bits_to_bytes(bits3)

		data = _sprite_data(bytes0, bytes1, bytes2, bytes3, width, height)
		frame_label = f"{label_prefix}{asset_name}_{sprite_name}_relative"
		asm += "\n"
		asm += "			.word 0  ; safety pair of bytes for reading by POP B\n"
		asm += frame_label + ":\n"

		width_packed = width // 8 - 1
		offset_x_packed = offset_x // 8
		asm += f"			.byte {offset_y}, {offset_x_packed}; offset_y, offset_x\n"
		asm += f"			.byte {height}, {width_packed}; height, width\n"
		asm += common.bytes_to_asm(data)
		asm += "\n"

		frame_data_len = len(data) + consts.SAFE_WORD_LEN + 2 + 2
		relative_ptrs[frame_label] = sprite_data_relative_addr
		sprite_data_relative_addr += frame_data_len

	return asm, relative_ptrs


def _anims_to_asm(label_prefix, asset_name, asset_j, relative_ptrs):
	preshifted_sprites = 1  # backgrounds are never preshifted
	asm = f"{asset_name}_get_scr_addr:\n"
	asm += f"			.word sprite_get_scr_addr{preshifted_sprites}\n"
	asm += f"{asset_name}_ram_disk_s_cmd:\n"
	asm += "			.byte TEMP_BYTE ; inited by sprite_init_meta_data\n"
	asm += f"{asset_name}_preshifted_sprites:\n"
	asm += f"			.byte {preshifted_sprites}\n"

	asm += f"{asset_name}_anims:\n			.word "
	for anim_name in asset_j["anims"]:
		asm += f"{asset_name}_{anim_name}, "
	asm += "EOD\n"

	for anim_name in asset_j["anims"]:
		asm += f"{asset_name}_{anim_name}:\n"
		anims = asset_j["anims"][anim_name]["frames"]
		loop = asset_j["anims"][anim_name]["loop"]
		frame_count = len(anims)
		for i, frame in enumerate(anims):
			if i < frame_count - 1:
				next_frame_offset = preshifted_sprites * 2 + 1
				asm += f"			.byte {next_frame_offset}, 0 ; offset to the next frame\n"
			else:
				if loop is False:
					next_frame_offset_low = -1
				else:
					offset_addr = 1
					next_frame_offset_low = (
						255 - (frame_count - 1) * (preshifted_sprites + offset_addr) * 2 + 1
					)
					next_frame_offset_low -= 1
				asm += f"			.byte {next_frame_offset_low}, $ff ; offset to the first frame\n"

			asm += "			.word "
			for _ in range(preshifted_sprites):
				asm += f"{label_prefix}{asset_name}_{frame}_relative, "
			asm += "\n"

	labels_asm = "; relative frame labels\n"
	for label_name, addr in relative_ptrs.items():
		labels_asm += f"{label_name} = {addr}\n"
	labels_asm += "\n"
	return labels_asm + asm


def _sprite_data(bytes0, bytes1, bytes2, bytes3, w, h):
	# Data format described in v6_back_draw.asm: 4 screen buffers, no mask,
	# alternating plane order on even/odd lines. Width is /8 (8 px per byte).
	width = w // 8
	data = []
	for y in range(h):
		even_line = y % 2 == 0
		planes = (bytes0, bytes1, bytes2, bytes3) if even_line else (bytes3, bytes2, bytes1, bytes0)
		first, rest = planes[0], planes[1:]
		for x in range(width):
			data.append(first[y * width + x])
		for plane in rest:
			for x in range(width):
				data.append(plane[y * width + width - x - 1])
	return data
