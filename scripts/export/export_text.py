import os
from pathlib import Path
import json
import utils.common as common
import utils.build as build

# string special symbols:
#	_EOD_ ; at the end
#	_LINE_BREAK_ at the end of the line
#	_PARAG_BREAK_ at the end of the peragraph

TEXT_LEN_MAX = 512

def export_if_updated(
		asset_j_path, asm_meta_path, asm_data_path, bin_path,
		force_export, localization_id = build.LOCAL_ENG):

	if force_export or is_source_updated(asset_j_path):
		export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path, localization_id)
		print(f"export_font: {asset_j_path} got exported.")

def is_source_updated(asset_j_path):
	return build.is_file_updated(asset_j_path)


def export_asm(
		asset_j_path, asm_meta_path, asm_data_path,
		bin_path, localization_id = build.LOCAL_ENG):

	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	asm_ram_disk_data, data_relative_ptrs = \
		ramdisk_data_to_asm(asset_j_path, asset_j, localization_id)

	asm_ram_data = meta_data_to_asm(data_relative_ptrs)

	# save the RAM Disk asm
	asm_gfx_dir = str(Path(asm_data_path).parent) + "/"
	if not os.path.exists(asm_gfx_dir):
		os.mkdir(asm_gfx_dir)
	with open(asm_data_path, "w") as file:
		file.write(asm_ram_disk_data)

	# compile and save the meta and RAM Disk data
	build.generate_asm_meta_file(asm_meta_path, asm_data_path, bin_path, asm_ram_data)

	return True

def meta_data_to_asm(data_relative_ptrs):
	asm = ""

	asm += "; relative labels\n"
	for label, val in data_relative_ptrs.items():
		asm += f"{label} = 0x{val:04x}\n"

	return asm

def ramdisk_data_to_asm(asset_j_path, asset_j, localization_id):
	data_relative_ptrs = {}
	text_local_addr_offset = 2 # added safety pair of bytes for reading by POP B
	asm = ""

	asm += f"_LINE_BREAK_ = {LINE_BREAK}\n"
	asm += f"_PARAG_BREAK_ = {PARAG_BREAK}\n"
	asm += f"_EOD_ = {EOD}\n"

	asm += ".macro TEXT (string, end_code=_EOD_)\n"
	asm += ".encoding \"screencodecommodore\", \"mixed\"\n"
	asm += "    .text string\n"
	asm += "    .byte end_code\n"
	asm += ".endmacro\n\n"

	for comment in asset_j["text"]:
		labels_text = asset_j["text"][comment]
		asm += f";===============================================================================\n"
		asm += f"; {comment}\n"
		asm += f";===============================================================================\n"

		for label_postfix  in labels_text:

			label = "_" + comment.replace(" ", "_") + "_" + label_postfix.replace(" ", "_")

			text_data = labels_text[label_postfix]

			lines = len(text_data["text"])
			pos_x, pos_y = text_data["scr_pos"]
			text_block_asm = ""
			text_block_len = 0
			text_block = ""

			for i, text_raw in enumerate(text_data["text"]):

				# because retroassembler adds EOD code anyway
				command = "" if localization_id == build.LOCAL_ENG else EOD_S

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

				if localization_id == build.LOCAL_RUS:
					rus_text_data = rus_text_to_data(text, asset_j_path)
					text_block_asm += common.bytes_to_asm(rus_text_data)
					text_block_asm += f'			.byte {command})\n'
				else:
					text_block_asm += f'			TEXT("{text}", {command})\n'

				text_block_asm += break_line
				text_block_len += len(text) + 1 #  + 1 because there's always a key-code at the end of the string
				text_block += text + "\n"


			copy_text_block_len = text_block_len
			copy_text_block_len += 2 # scr pos
			data_relative_ptrs[label] = text_local_addr_offset
			text_local_addr_offset += copy_text_block_len
			text_local_addr_offset += 2 # length
			text_local_addr_offset += build.SAFE_WORD_LEN

			# check if the length of the text fits the requirements
			if copy_text_block_len > TEXT_LEN_MAX:
				build.exit_error(
					f"export_text ERROR: text: \n"
					f'"{text_block}"\n '
					f"is {copy_text_block_len} symbols long. "
					f"Which is longer than TEXT_LEN_MAX={TEXT_LEN_MAX} symbols,"
					f" path: {asset_j_path}"
				)

			# the len of bytes copied from the RAM Disk
			# rounded to the nearest (biggest) even number
			copy_text_block_rounded_len = \
				(copy_text_block_len // 2 + copy_text_block_len % 2) * 2

			asm += "\n			.word 0 ; safety pair of bytes for reading by POP B\n"
			asm += f"{label}:\n"
			asm += f"			.word {copy_text_block_rounded_len} ; data len to copy to ram\n"
			asm += f"			.byte {pos_y}, {pos_x} ; scr pos (y, x)\n"
			asm += text_block_asm

	return asm, data_relative_ptrs


#=====================================================

# special char codes

LINE_BREAK_S	= "_LINE_BREAK_"
PARAG_BREAK_S	= "_PARAG_BREAK_"
EOD_S			= "_EOD_"

LINE_BREAK	= 0x6a # '\n' (106)
PARAG_BREAK	= 0xff		# (255)
EOD			= 0			# (0)

# the custom RUS charset is described in source\sprites\font_rus.json
rus_charset = {
		"а"	: 1,		"б"	: 2,		"в"	: 3,		"г"	: 4,
		"д"	: 5,		"е"	: 6,		"ё"	: 7,		"ж"	: 8,
		"з"	: 9,		"и"	: 10,		"й"	: 11,		"к"	: 12,
		"л"	: 13,		"м"	: 14,		"н"	: 15,		"о"	: 16,
		"п"	: 17,		"р"	: 18,		"с"	: 19,		"т"	: 20,
		"у"	: 21,		"ф"	: 22,		"х"	: 23,		"ц"	: 24,
		"ч"	: 25,		"ш"	: 26,		"щ"	: 27,		"ъ"	: 28,
		"ы"	: 29,		"ь"	: 30,		"э"	: 31,		"ю"	: 32,
		"я"	: 33,		"А"	: 34,		"Б"	: 35,		"В"	: 36,
		"Г"	: 37,		"Д"	: 38,		"Е"	: 39,		"Ё"	: 40,
		"Ж"	: 41,		"З"	: 42,		"И"	: 43,		"Й"	: 44,
		"К"	: 45,		"Л"	: 46,		"М"	: 47,		"Н"	: 48,
		"О"	: 49,		"П"	: 50,		"Р"	: 51,		"С"	: 52,
		"Т"	: 53,		"У"	: 54,		"Ф"	: 55,		"Х"	: 56,
		"Ц"	: 57,		"Ч"	: 58,		"Ш"	: 59,		"Щ"	: 60,
		"Ъ"	: 61,		"Ы"	: 62,		"Ь"	: 63,		"Э"	: 64,
		"Ю"	: 65,		"Я"	: 66,		"0"	: 67,		"1"	: 68,
		"2"	: 69,		"3"	: 70,		"4"	: 71,		"5"	: 72,
		"6"	: 73,		"7"	: 74,		"8"	: 75,		"9"	: 76,
		"."	: 77,		","	: 78,		":"	: 79,		")"	: 80,
		"("	: 81,		"'"	: 82,		"!"	: 83,		"?"	: 84,
		"-"	: 85,		"&"	: 86,		" "	: 87
		}

def rus_text_to_data(text, asset_j_path):

	result = []
	for char_ in text:
		if char_ not in rus_charset:
			build.exit_error(
				f'export_text ERROR: unsupported char: '
				f'{char_}" в тексте: "{text}", path: {asset_j_path}')

		result.append(rus_charset[char_])

	return result
