"""Sprite exporter: 3-plane masked sprites with optional preshifting.

Faithful port of the original ``export_sprite`` data layout (see
``v6/gfx/v6_sprite_draw.asm``). The dead experimental code paths from the old
script (alternate row-by-row packers and CPU-cycle estimators) were dropped;
the surviving packer is generalized to any width that is a multiple of 8.
"""

from PIL import Image

from utils import asmgen, common, common_gfx, consts
from utils.log import error
from exporters.context import AssetManifest, ExportContext

VALID_PRESHIFTS = (1, 4, 8)


def export(ctx: ExportContext) -> AssetManifest:
	asset_j = ctx.meta
	name = ctx.name

	preshift = asset_j.get("preshifted_sprites", 1)
	if preshift not in VALID_PRESHIFTS:
		error(
			"preshifted_sprites must be 1, 4 or 8",
			f"{ctx.meta_path}: got {preshift}",
		)

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
		asset_type=consts.ASSET_TYPE_SPRITE,
		bin_path=ctx.bin_path,
		bin_len=bin_len,
		meta_asm_path=ctx.meta_asm_path,
		data_asm_path=keep_asm,
	)


def _gfx_to_asm(label_prefix, asset_name, asset_j, image):
	mask_flag = 1 if asset_j.get("mask") is True else 0
	preshift_num = asset_j.get("preshifted_sprites", 1)

	relative_ptrs = {}
	relative_addr = consts.SAFE_WORD_LEN
	asm = f"{label_prefix}{asset_name}_sprites:"

	for sprite in asset_j["sprites"]:
		sprite_name = sprite["name"]
		x = sprite["x"]
		y = sprite["y"]
		w = sprite["width"]
		h = sprite["height"]
		offset_x = sprite.get("offset_x") or 0
		offset_y = sprite.get("offset_y") or 0
		mask_x = sprite.get("mask_x", x)
		mask_y = sprite.get("mask_y", y)
		mask_alpha = sprite.get("mask_alpha", 0)

		# Y reversed: stored bottom-to-top.
		sprite_img = []
		for py in reversed(range(y, y + h)):
			sprite_img.append([image.getpixel((px, py)) for px in range(x, x + w)])

		mask_bits = None
		if mask_flag == 1:
			mask_bits = []
			for py in reversed(range(mask_y, mask_y + h)):
				for px in range(mask_x, mask_x + w):
					mask_bits.append(1 if image.getpixel((px, py)) == mask_alpha else 0)

		for preshift in range(preshift_num):
			shift = 8 // preshift_num * preshift
			frame_label = f"{label_prefix}{asset_name}_{sprite_name}_{preshift}_relative"
			frame_asm, frame_len = _img_to_preshifted_sprite(
				frame_label, sprite_img, mask_bits, w, h, offset_x, offset_y, shift
			)
			asm += frame_asm
			relative_ptrs[frame_label] = relative_addr
			relative_addr += frame_len

	return asm, relative_ptrs


def _anims_to_asm(label_prefix, asset_name, asset_j, relative_ptrs):
	preshift = asset_j.get("preshifted_sprites", 1)

	asm = f"{asset_name}_get_scr_addr:\n"
	asm += f"			.word sprite_get_scr_addr{preshift}\n"
	asm += f"{asset_name}_ram_disk_s_cmd:\n"
	asm += "			.byte TEMP_BYTE ; inited by sprite_init_meta_data\n"
	asm += f"{asset_name}_preshifted_sprites:\n"
	asm += f"			.byte {preshift}\n"

	asm += f"{asset_name}_anims:\n			.word "
	for anim_name in asset_j["anims"]:
		asm += f"{asset_name}_{anim_name}_anim, "
	asm += "EOD\n"

	for anim_name in asset_j["anims"]:
		asm += f"{asset_name}_{anim_name}_anim:\n"
		frames = asset_j["anims"][anim_name]["frames"]
		loop = asset_j["anims"][anim_name]["loop"]
		frame_count = len(frames)
		for i, frame in enumerate(frames):
			if i < frame_count - 1:
				next_frame_offset = preshift * 2 + 1
				asm += f"			.byte {next_frame_offset}, 0 ; offset to the next frame\n"
			else:
				if loop is False:
					next_frame_offset_low = -1
					comment = "offset to the same last frame"
				else:
					offset_addr = 1
					next_frame_offset_low = (
						255 - (frame_count - 1) * (preshift + offset_addr) * 2 + 1 - 1
					)
					comment = "offset to the first frame"
				asm += f"			.byte {next_frame_offset_low}, $ff ; {comment}\n"

			asm += "			.word "
			for s in range(preshift):
				asm += f"{label_prefix}{asset_name}_{frame}_{s}_relative, "
			asm += "\n"

	asm += f"{asset_name}_anims_end:\n"
	asm += f"{asset_name}_anims_len: = {asset_name}_anims_end - {asset_name}_anims\n"

	labels_asm = "; relative frame labels\n"
	for label_name, addr in relative_ptrs.items():
		labels_asm += f"{label_name} = {addr}\n"
	labels_asm += "\n"
	return labels_asm + asm


def _img_to_preshifted_sprite(frame_label, sprite_img, mask_bits, w, h, offset_x, offset_y, shift):
	bits0, bits1, bits2, bits3 = common_gfx.indexes_to_bit_lists(sprite_img)

	if shift > 0:
		bits1 = _shift_bits(bits1, w, h, shift)
		bits2 = _shift_bits(bits2, w, h, shift)
		bits3 = _shift_bits(bits3, w, h, shift)
		if mask_bits:
			mask_bits = _shift_bits(mask_bits, w, h, shift, 1)
		w += 8

	# Find the visible bounds (from the mask, or from the color planes).
	if mask_bits:
		bits_to_check = [mask_bits]
		enabled = 0
	else:
		bits_to_check = [bits1, bits2, bits3]
		enabled = 1

	vis_bit_l = 0
	vis_bit_r = w
	for bits in bits_to_check:
		l = _find_leftest_bit(bits, w, h, enabled)
		if l > vis_bit_l:
			vis_bit_l = l
		r = _find_rightest_bit(bits, w, h, enabled)
		if r < vis_bit_r:
			vis_bit_r = r

	# Crop to 8-pixel (byte) alignment.
	local_offset_x = vis_bit_l // 8 * 8
	new_w_unrounded = vis_bit_r - local_offset_x
	new_w = (new_w_unrounded // 8) * 8
	if (new_w_unrounded % 8) > 0:
		new_w += 8

	if new_w <= 0:  # completely transparent sprite
		new_w = 8
		local_offset_x = 0
	else:
		bits1 = _crop_bits(bits1, w, h, new_w, local_offset_x)
		bits2 = _crop_bits(bits2, w, h, new_w, local_offset_x)
		bits3 = _crop_bits(bits3, w, h, new_w, local_offset_x)
		if mask_bits:
			mask_bits = _crop_bits(mask_bits, w, h, new_w, local_offset_x)

	bytes1 = common.combine_bits_to_bytes(bits1)
	bytes2 = common.combine_bits_to_bytes(bits2)
	bytes3 = common.combine_bits_to_bytes(bits3)
	mask_bytes = common.combine_bits_to_bytes(mask_bits) if mask_bits else None

	data = _sprite_data(bytes1, bytes2, bytes3, new_w, h, mask_bytes)

	offset_x_packed = (offset_x + local_offset_x) // 8
	new_w_packed = new_w // 8 - 1

	asm = "\n"
	asm += "			.word 0  ; safety pair of bytes for reading by POP B\n"
	asm += f"{frame_label}:\n"
	asm += f"			.byte {offset_y}, {offset_x_packed}; offset_y, offset_x\n"
	asm += f"			.byte {h}, {new_w_packed}; h, w\n"
	asm += common.bytes_to_asm(data)

	frame_len = len(data) + consts.SAFE_WORD_LEN + 4  # +4: offset_y, offset_x, h, w
	return asm, frame_len


def _crop_bits(bits, w, h, new_w, offset_x):
	if w == new_w:
		return bits
	cropped = []
	for y in range(h):
		for x in range(w):
			if x < offset_x or x >= offset_x + new_w:
				continue
			cropped.append(bits[y * w + x])
	return cropped


def _find_leftest_bit(bits, w, h, enabled):
	dx = w
	for y in range(h):
		for x in range(w):
			if bits[y * w + x] == enabled and x < dx:
				dx = x
				break
	return dx


def _find_rightest_bit(bits, w, h, enabled):
	dx = 0
	for y in range(h):
		for x in reversed(range(w)):
			if bits[y * w + x] == enabled and x > dx:
				dx = x
				break
	return dx


def _shift_bits(bits, w, h, shift, filler=0):
	shifted = []
	for y in range(h):
		shifted.extend([filler] * shift)
		for x in range(w):
			shifted.append(bits[w * y + x])
		shifted.extend([filler] * (8 - shift))
	return shifted


def _sprite_data(bytes1, bytes2, bytes3, width, h, mask_bytes=None):
	"""Pack 3 planes (+ optional mask) in the snake order the draw routine reads.

	Layout described in v6_sprite_draw.asm: rows go bottom-to-top, columns
	snake left-to-right on even lines and right-to-left on odd lines. The plane
	triple is emitted forwards (1,2,3) when the column and row parities match
	and reversed (3,2,1) otherwise. Generalized for any multiple-of-8 width.
	"""
	w_in_bytes = width // 8
	data = []
	for y in range(h):
		columns = range(w_in_bytes) if y % 2 == 0 else reversed(range(w_in_bytes))
		for x in columns:
			i = y * w_in_bytes + x
			if mask_bytes:
				data.append(mask_bytes[i])
			if (x % 2) == (y % 2):
				data.extend((bytes1[i], bytes2[i], bytes3[i]))
			else:
				data.extend((bytes3[i], bytes2[i], bytes1[i]))
	return data
