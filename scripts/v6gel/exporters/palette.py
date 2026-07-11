"""Palette exporter (Vector06c colors plus optional fade tables)."""

from utils import asmgen, common, common_gfx, consts
from exporters.context import AssetManifest, ExportContext


def export(ctx: ExportContext) -> AssetManifest:
	name = ctx.name
	data_asm, relative_ptrs = _data_to_asm(ctx)
	meta_body = _meta_body(relative_ptrs)

	keep_asm = ctx.data_asm_path if ctx.emit_asm else None
	bin_len = asmgen.assemble(
		ctx.v6asm_path, data_asm, ctx.bin_path, ctx.temp_dir, keep_asm
	)
	with open(ctx.meta_asm_path, "w", encoding="ascii") as f:
		f.write(asmgen.meta_asm(ctx.stored_path, meta_body))

	return AssetManifest(
		name=name,
		asset_type=consts.ASSET_TYPE_PALETTE,
		bin_path=ctx.bin_path,
		bin_len=bin_len,
		meta_asm_path=ctx.meta_asm_path,
		data_asm_path=keep_asm,
	)


def _data_to_asm(ctx):
	palette_j = ctx.meta
	palette_name = ctx.name

	asm = ""
	local_addrs = 0
	relative_ptrs = {}

	# --- palette ---
	palette_asm, colors, palette_label, palette_len = common_gfx.palette_file_to_asm(
		ctx.meta_path, ctx.asset_rel("path_png"), "_" + palette_name
	)
	asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
	asm += f"{palette_label}_relative:\n"
	asm += palette_asm + "\n"

	local_addrs += consts.SAFE_WORD_LEN
	relative_ptrs[palette_label + "_relative"] = local_addrs
	local_addrs += palette_len

	# --- fades (each fade is a sequence of blended palettes) ---
	if "fades" in palette_j:
		for fade_j in palette_j["fades"]:
			fade_name = fade_j["name"]
			fade_to_color = fade_j["color"]
			fade_to_r = (fade_to_color.get("r", 0) << 5) & 0xFF
			fade_to_g = (fade_to_color.get("g", 0) << 5) & 0xFF
			fade_to_b = (fade_to_color.get("b", 0) << 6) & 0xFF
			fade_iterations = fade_j.get("iterations", 7)

			asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
			fade_label = f"{palette_label}_fade_{fade_name}_relative"
			asm += f"{fade_label}:\n"
			asm += f"			.byte {fade_iterations - 2} ; fade_iterations - 2\n"

			iteration_max = fade_iterations - 1
			for i in range(fade_iterations):
				asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
				asm += "			.byte "
				for color in colors:
					r, g, b = color
					blend = (iteration_max - i) / iteration_max
					fr = int(r * blend + fade_to_r * (1 - blend))
					fg = int(g * blend + fade_to_g * (1 - blend))
					fb = int(b * blend + fade_to_b * (1 - blend))
					v6 = (fb & 0b11000000) | ((fg & 0b11100000) >> 2) | (fr >> 5)
					asm += f"0x{v6:02x}, "
				asm += "\n"
			asm += "\n"

			local_addrs += consts.SAFE_WORD_LEN
			relative_ptrs[fade_label] = local_addrs
			local_addrs += consts.BYTE_LEN
			local_addrs += (consts.SAFE_WORD_LEN + common_gfx.IMAGE_COLORS_MAX) * fade_iterations

	return asm, relative_ptrs


def _meta_body(relative_ptrs):
	asm = ""
	for label, addr in relative_ptrs.items():
		asm += f"{label} = 0x{addr:04x}\n"
	asm += "\n"
	return asm
