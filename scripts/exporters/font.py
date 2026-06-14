"""Font exporter: character glyphs with Unicode-aware label mangling.

Faithful port of the original ``export_font`` layout (see
``v6/gfx/v6_text_ex_draw.asm``).
"""

from PIL import Image

from utils import asmgen, common, consts
from exporters.context import AssetManifest, ExportContext

ENG_ALPHABET_LEN = 26
GLYPH_WIDTH = 8  # glyph cell width sampled from the PNG


def export(ctx: ExportContext) -> AssetManifest:
	asset_j = ctx.meta
	name = ctx.name

	image = Image.open(ctx.asset_rel("path_png"))

	data_asm, gfx_ptrs = _gfx_to_asm("_" + name, asset_j, image)
	meta_body = _gfx_ptrs_to_asm(name, asset_j, gfx_ptrs)

	keep_asm = ctx.data_asm_path if ctx.emit_asm else None
	bin_len = asmgen.assemble(
		ctx.v6asm_path, data_asm, ctx.bin_path, ctx.temp_dir, keep_asm
	)
	with open(ctx.meta_asm_path, "w", encoding="ascii") as f:
		f.write(asmgen.meta_asm(ctx.stored_path, meta_body))

	return AssetManifest(
		name=name,
		asset_type=consts.ASSET_TYPE_FONT,
		bin_path=ctx.bin_path,
		bin_len=bin_len,
		meta_asm_path=ctx.meta_asm_path,
		data_asm_path=keep_asm,
	)


def _gfx_to_asm(label_prefix, asset_j, image):
	gfx_ptrs = {}
	asm = label_prefix + "_gfx:"

	bg_pos = asset_j.get("color_sample_pos", [0, 0])
	bg_color_idx = image.getpixel((bg_pos[0], bg_pos[1]))
	spacing = asset_j.get("spacing", 1)

	char_addr_offset = 0
	for char_j in asset_j["gfx"]:
		char_name = char_j["name"]
		x = char_j["x"]
		y = char_j["y"]
		offset_x = char_j.get("offset_x", 0)
		offset_y = char_j.get("offset_y", 0)
		width = char_j["width"]
		height = char_j["height"]

		# Y reversed: stored bottom-to-top. First 8 px wide cell.
		bits = []
		for py in reversed(range(y, y + height)):
			for px in range(x, x + GLYPH_WIDTH):
				bits.append(0 if image.getpixel((px, py)) == bg_color_idx else 1)
		data = common.combine_bits_to_bytes(bits)

		asm += "\n"
		asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
		adjusted_char = _char_label_postfix(char_name)
		asm += f"{label_prefix}_{adjusted_char}:\n"

		if offset_y < 0:
			offset_x -= 1
		asm += f"			.byte {offset_y}, {offset_x} ; offset_y, offset_x\n"
		asm += common.words_to_asm(data)
		asm += f"			.byte 0, {width + spacing} ; next_char_pos_y_offset, next_char_pos_x_offset\n"

		char_addr_offset += consts.SAFE_WORD_LEN
		gfx_ptrs[char_name] = char_addr_offset
		# offset_y, offset_x (2) + data words (2 each) + next_char offset (2)
		char_addr_offset += 2 + len(data) * 2 + 2

	return asm, gfx_ptrs


def _char_label_postfix(char_name):
	"""Map a glyph name to a deterministic, case-insensitively-unique label.

	v6asm treats labels case-insensitively, so the upper- and lower-case
	alphabet would otherwise collide (``_font_A`` vs ``_font_a``). Upper-case
	ASCII letters are therefore mangled to ``cap_<lower>``. Label names are
	internal to the blob (only relative offsets matter), so this does not affect
	the produced binary.
	"""
	adjusted_char = char_name
	code_point = ord(char_name[0])
	if code_point > 0x100:
		adjusted_code_point = (code_point - 0x100) % ENG_ALPHABET_LEN + 0x61
		offset = (code_point - 0x100) // ENG_ALPHABET_LEN
		adjusted_char = f"{chr(adjusted_code_point)}{offset}"
	elif len(char_name) == 1 and "A" <= char_name <= "Z":
		adjusted_char = "cap_" + char_name.lower()
	return adjusted_char


def _gfx_ptrs_to_asm(label_prefix, asset_j, gfx_ptrs):
	asm = ""
	for char_name in gfx_ptrs:
		adjusted_char = _char_label_postfix(char_name)
		asm += f"_{label_prefix}_{adjusted_char} = {gfx_ptrs[char_name]}\n"

	asm += f"{label_prefix}_gfx_ptrs:\n"
	numbers_in_line = 16
	for i, char_name in enumerate(asset_j["gfx_ptrs"]):
		if i % numbers_in_line == 0:
			if i != 0:
				asm += "\n"
			asm += "			.word "
		adjusted_char = _char_label_postfix(char_name)
		asm += f"_{label_prefix}_{adjusted_char}, "
	asm += "\n			.word EOD\n\n"
	return asm
