"""Text exporter: localized string blocks (English screencode or Russian charset).

Faithful port of the original ``export_text``. The localization is selected
from the asset type: ``text_eng`` -> English, ``text_rus`` -> Russian.
"""

from utils import asmgen, common, consts
from utils.log import error
from exporters.context import AssetManifest, ExportContext

TEXT_LEN_MAX = 512

# special char codes
LINE_BREAK_S = "_LINE_BREAK_"
PARAG_BREAK_S = "_PARAG_BREAK_"
EOD_S = "_EOD_"

LINE_BREAK = 0x6A  # '\n'
PARAG_BREAK = 0xFF
EOD = 0

# Custom RUS charset (see source/sprites/font_rus.json).
RUS_CHARSET = {
	"а": 1, "б": 2, "в": 3, "г": 4, "д": 5, "е": 6, "ё": 7, "ж": 8,
	"з": 9, "и": 10, "й": 11, "к": 12, "л": 13, "м": 14, "н": 15, "о": 16,
	"п": 17, "р": 18, "с": 19, "т": 20, "у": 21, "ф": 22, "х": 23, "ц": 24,
	"ч": 25, "ш": 26, "щ": 27, "ъ": 28, "ы": 29, "ь": 30, "э": 31, "ю": 32,
	"я": 33, "А": 34, "Б": 35, "В": 36, "Г": 37, "Д": 38, "Е": 39, "Ё": 40,
	"Ж": 41, "З": 42, "И": 43, "Й": 44, "К": 45, "Л": 46, "М": 47, "Н": 48,
	"О": 49, "П": 50, "Р": 51, "С": 52, "Т": 53, "У": 54, "Ф": 55, "Х": 56,
	"Ц": 57, "Ч": 58, "Ш": 59, "Щ": 60, "Ъ": 61, "Ы": 62, "Ь": 63, "Э": 64,
	"Ю": 65, "Я": 66, "0": 67, "1": 68, "2": 69, "3": 70, "4": 71, "5": 72,
	"6": 73, "7": 74, "8": 75, "9": 76, ".": 77, ",": 78, ":": 79, ")": 80,
	"(": 81, "'": 82, "!": 83, "?": 84, "-": 85, "&": 86, " ": 87,
}


def export(ctx: ExportContext) -> AssetManifest:
	localization = (
		consts.LOCAL_RUS
		if ctx.asset_type == consts.ASSET_TYPE_TEXT_RUS
		else consts.LOCAL_ENG
	)

	data_asm, relative_ptrs = _data_to_asm(ctx, localization)
	meta_body = _meta_body(relative_ptrs)

	keep_asm = ctx.data_asm_path if ctx.emit_asm else None
	bin_len = asmgen.assemble(
		ctx.v6asm_path, data_asm, ctx.bin_path, ctx.temp_dir, keep_asm
	)
	with open(ctx.meta_asm_path, "w", encoding="ascii") as f:
		f.write(asmgen.meta_asm(ctx.stored_path, meta_body))

	return AssetManifest(
		name=ctx.name,
		asset_type=ctx.asset_type,
		bin_path=ctx.bin_path,
		bin_len=bin_len,
		meta_asm_path=ctx.meta_asm_path,
		data_asm_path=keep_asm,
	)


def _meta_body(relative_ptrs):
	asm = "; relative labels\n"
	for label, val in relative_ptrs.items():
		asm += f"{label} = 0x{val:04x}\n"
	return asm


def _data_to_asm(ctx, localization):
	asset_j = ctx.meta
	relative_ptrs = {}
	addr = consts.SAFE_WORD_LEN

	asm = f"_LINE_BREAK_ = {LINE_BREAK}\n"
	asm += f"_PARAG_BREAK_ = {PARAG_BREAK}\n"
	asm += f"_EOD_ = {EOD}\n"
	if localization != consts.LOCAL_RUS:
		# Let v6asm own the screencode mapping via .text/.encoding so it is never
		# duplicated in Python. "mixed"/"upper" both fold A-Z/a-z to 1-26 and keep
		# the 0x20-0x3F range (space, punctuation, digits) as-is.
		asm += ".macro TEXT (string, end_code = _EOD_)\n"
		asm += '.encoding "screencodecommodore", "mixed"\n'
		asm += "			.text string\n"
		asm += "			.byte end_code\n"
		asm += ".endmacro\n"
	asm += "\n"

	for comment in asset_j["text"]:
		labels_text = asset_j["text"][comment]
		asm += ";===============================================================================\n"
		asm += f"; {comment}\n"
		asm += ";===============================================================================\n"

		for label_postfix in labels_text:
			label = "_" + comment.replace(" ", "_") + "_" + label_postfix.replace(" ", "_")
			text_data = labels_text[label_postfix]
			lines = len(text_data["text"])
			pos_x, pos_y = text_data["scr_pos"]

			text_block_asm = ""
			text_block_len = 0
			text_block = ""

			for i, text_raw in enumerate(text_data["text"]):
				# the terminating key-code; the EOD marker ends the last line.
				command = EOD_S
				parag_break = text_raw.find(PARAG_BREAK_S)
				line_break = text_raw.find(LINE_BREAK_S)
				text = text_raw
				break_line = "\n"

				if parag_break >= 0:
					command = PARAG_BREAK_S
					text = text_raw[:parag_break]
				elif line_break >= 0 or i + 1 != lines:
					command = LINE_BREAK_S
					break_line = ""
					if line_break >= 0:
						text = text_raw[:line_break]

				if localization == consts.LOCAL_RUS:
					data = _rus_text_to_data(text, ctx.meta_path)
					text_block_asm += common.bytes_to_asm(data)
					text_block_asm += f"			.byte {command}\n"
				else:
					# v6asm encodes the literal via the TEXT macro (.text/.encoding).
					escaped = text.replace("\\", "\\\\").replace('"', '\\"')
					text_block_asm += f'			TEXT("{escaped}", {command})\n'

				text_block_asm += break_line
				text_block_len += len(text) + 1  # +1 for the trailing key-code
				text_block += text + "\n"

			copy_text_block_len = text_block_len + 2  # + scr pos
			relative_ptrs[label] = addr
			addr += copy_text_block_len
			addr += 2  # length
			addr += consts.SAFE_WORD_LEN

			if copy_text_block_len > TEXT_LEN_MAX:
				error(
					f"text block is {copy_text_block_len} symbols, "
					f"longer than TEXT_LEN_MAX={TEXT_LEN_MAX}",
					f"{ctx.meta_path}: {text_block}",
				)

			copy_text_block_rounded_len = (
				copy_text_block_len // 2 + copy_text_block_len % 2
			) * 2

			asm += "\n			.word 0 ; safety pair of bytes for reading by POP B\n"
			asm += f"{label}:\n"
			asm += f"			.word {copy_text_block_rounded_len} ; data len to copy to ram\n"
			asm += f"			.byte {pos_y}, {pos_x} ; scr pos (y, x)\n"
			asm += text_block_asm

	return asm, relative_ptrs


def _rus_text_to_data(text, meta_path):
	result = []
	for char_ in text:
		if char_ not in RUS_CHARSET:
			error(f"unsupported RUS char: {char_!r}", f"{meta_path}: {text}")
		result.append(RUS_CHARSET[char_])
	return result
