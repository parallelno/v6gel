import os
import sqlite3
import utils.common as common
from pathlib import Path
import json

ASSET_TYPE_BACK			= "back"
ASSET_TYPE_FONT			= "font"
ASSET_TYPE_FONT_RD		= "font_rd" # font_gfx_ptrs.asm will be included into the main programm. it has to be included into the RAM Disk asm code manually instead.
ASSET_TYPE_SPRITE		= "sprite"
ASSET_TYPE_TEXT_ENG		= "text_eng"
ASSET_TYPE_TEXT_RUS		= "text_rus"

ASSET_TYPE_LEVEL		= "level"
ASSET_TYPE_LEVEL_DATA	= "level_data"
ASSET_TYPE_LEVEL_GFX	= "level_gfx"

ASSET_TYPE_TILED_IMG	= "tiled_img"
ASSET_TYPE_TILED_IMG_DATA	= "tiled_img_data"
ASSET_TYPE_TILED_IMG_GFX	= "tiled_img_gfx"

ASSET_TYPE_DECAL		= "decal"
ASSET_TYPE_IMAGE		= "image"
ASSET_TYPE_MUSIC		= "music"
ASSET_TYPE_CODE			= "code"
ASSET_TYPE_CONFIG 		= "config"
ASSET_TYPE_PALETTE		= "palette"

LABEL_POSTFIX_ASSET_START	= "_rd_data_start"
LABEL_POSTFIX_ASSET_END		= "_rd_data_end"

DEBUG_FILE_NAME	= "debug.txt"
MEM_USAGE_FILE_NAME	= "mem_usage.md"

EXT_TXT			= ".txt"
EXT_ASM			= ".asm"
EXT_BIN			= ".bin"
EXT_ZX0			= ".zx0"
EXT_BIN_ZX0		= ".bin.zx0"
EXT_UPKR		= ".upkr"
EXT_BIN_UPKR	= ".bin.upkr"
EXT_ROM			= ".rom"
EXT_COM			= ".com"
EXT_FDD			= ".fdd"
EXT_YM			= ".ym"
EXT_JSON		= ".json"
EXT_BAT			= ".bat"

PACKER_ZX0				= 0
PACKER_ZX0_SALVADORE	= 1
PACKER_UPKR				= 2

LOCAL_SYMBOL_NAME = "LOCALIZATION"
LOCAL_ENG	= '0'
LOCAL_RUS	= '1'

CMP_DMA_BUFFER_LEN	= 128

# global consts
BUILD_PATH = "build/"
ASSET_PROJECTS_DIR = BUILD_PATH + "projects/"
BIN_DIR = BUILD_PATH + "bin/"
TEMP_DIR = BUILD_PATH + "temp/"

# global vars
build_db_path = "./build/build.db"
debug_mode = False
build_name = "release"
build_subfolder = BUILD_PATH + build_name + "/"
BUILD_ASSETS_INFO_PATH = BUILD_PATH + "assets_info" + EXT_JSON

assembler_labels_cmd = " -x"

zx0_path = "tools/zx0 -c"
zx0salvadore_path = "tools/zx0salvador.exe -v -classic"
upkr_path = "tools/upkr.exe --z80"

packer_path 	= ""
packer_ext		= ""
packer_bin_ext	= ""

#================================================================================
# hardware and game consts

SAFE_WORD_LEN : int	= 2 # safty pair of bytes for reading by POP B
BYTE_LEN : int		= 1
WORD_LEN : int		= 2
NULL_S			= "NULL"

RAM_LEN : int				= 0x10000
RAM_DISK_BANK_LEN : int		= 0x10000
RAM_DISK_BANKS_MAX : int	= 4
RAM_DISK_LEN				= RAM_DISK_BANK_LEN * RAM_DISK_BANKS_MAX

SCR_BUFF_LEN : int	= 0x2000
SCR_BUFFS_LEN : int	= SCR_BUFF_LEN * 4
SCR_ADDR : int 		= 0x8000

MAIN_STACK_LEN : int	= 32 # used in the main programm
INT_STACK_LEN : int		= 30 # used in the interruption routine
TMP_STACK_LEN : int		= 2  # used as a temp 2 byte space in the render routines such as sprite_copy_to_scr_v
ALL_STACKS_LEN = MAIN_STACK_LEN + INT_STACK_LEN + TMP_STACK_LEN

# defines available user space
# "-2" because erase funcs can let the interruption call corrupt 0x7ffe, @7fff bytes.
STACK_MAIN_PROGRAM_ADDR : int	= 0x8000 - 2
# used by the iterruption func
STACK_INTERRUPTION_ADDR : int	= STACK_MAIN_PROGRAM_ADDR - MAIN_STACK_LEN
# used as a temp 2 byte space in the render routines such as sprite_copy_to_scr_v
STACK_TEMP_ADDR : int			= STACK_INTERRUPTION_ADDR - INT_STACK_LEN
STACK_MIN_ADDR : int			= STACK_TEMP_ADDR - TMP_STACK_LEN

RAM_DISK_SEGMENT_LEN  : int = RAM_DISK_BANK_LEN // 2

# end global vars

# ANSI escape codes for text color
class TextColor:
	BLACK = '\033[30m'
	RED = '\033[31m'
	GREEN = '\033[32m'
	YELLOW = '\033[33m'
	BLUE = '\033[34m'
	MAGENTA = '\033[35m'
	CYAN = '\033[36m'
	WHITE = '\033[37m'
	RESET = '\033[0m'  # Reset to default color
	GRAY = '\033[90m'
	GRAY_LIGHT = '\033[37m'

def printc(text, color = TextColor.WHITE):
	print(color + text + TextColor.RESET)

def exit_error(text, comment = ""):
	printc(text, TextColor.RED)
	printc("Stop export", TextColor.RED)
	if comment != "":
		printc(f"additional details: {comment}", TextColor.GRAY)
	exit(1)


def set_debug(debug):
	global debug_mode
	debug_mode = debug


def set_build_subfolder(name):
	global build_name
	build_name = name
	global build_subfolder
	build_subfolder = BUILD_PATH + build_name + "/"


def set_assembler_labels_cmd(cmd):
	global assembler_labels_cmd
	assembler_labels_cmd = cmd


def set_packer(_packer, _packer_path):
	global packer_path
	global packer
	global packer_ext
	global packer_bin_ext
	if _packer == PACKER_ZX0:
		packer_ext = EXT_ZX0
		packer_bin_ext = EXT_BIN_ZX0

	elif _packer == PACKER_ZX0_SALVADORE:
		packer_ext = EXT_ZX0
		packer_bin_ext = EXT_BIN_ZX0

	elif _packer == PACKER_UPKR:
		packer_ext = EXT_UPKR
		packer_bin_ext = EXT_BIN_UPKR

	packer_path = _packer_path
	packer = _packer


def set_emulator_path(path):
	global emulator_path
	emulator_path = path

def build_db_init(path):
	global build_db_path
	dir = os.path.dirname(path)
	if not os.path.exists(dir):
		os.mkdir(dir)
	build_db_path = path

def is_asm_updated(asm_path):
	with open(asm_path, "rb") as file:
		lines = file.readlines()

	includes = []
	for line_b in lines:
		line = line_b.decode('ascii')
		inc_str = ".include "
		inc_idx = line.find(inc_str)

		if inc_idx != -1 and line[0] != ";":
			path = line[inc_idx + len(inc_str) + 1:]
			path = common.remove_duplicate_slashes(path)
			path_end_q1 = path.find('"')
			path_end_q2 = path.find("'")
			if path_end_q1 != -1:
				includes.append(path[:path_end_q1])
			elif path_end_q2 != -1:
				includes.append(path[:path_end_q2])
			continue

	any_inc_updated = False
	for inc_path in includes:
		any_inc_updated |= is_file_updated(inc_path)
		if any_inc_updated:
			break

	return any_inc_updated | is_file_updated(asm_path)

def is_file_updated(path):
	con = sqlite3.connect(build_db_path)
	cur = con.cursor()
	cur.execute('''CREATE TABLE if not exists files
			   (path text, modtime integer)''')

	if not os.path.exists(path):
		return True
	modification_time = int(os.path.getmtime(path))


	res = cur.execute("SELECT * FROM files WHERE path = '%s'" % path)
	modified = False
	ents = res.fetchall()

	if not ents:
		cur.execute("INSERT INTO files VALUES ('" + path + "', " + str(modification_time) + ")")
		modified = True
	else:
		if ents[0][1] == modification_time:
			modified = False
		else:
			sql = ''' UPDATE files
			  SET modtime = ?
			  WHERE path = ?'''
			cur.execute(sql, (modification_time, path))
			modified = True

	# done with DB
	con.commit()
	con.close()
	return modified

def store_labels(labels, path):
	labels_txt = ""
	for label_name in labels:
		labels_txt += f"{label_name} ${labels[label_name]:X}\n"

	with open(path, "w") as file:
		file.write(labels_txt)

def export_debug_data(out_path, labels_path, scriptsJ):
	with open(labels_path, "rb") as file:
		lines = file.readlines()

	debug_data = {}
	debug_data["labels"] = {}
	debug_data["consts"] = {}
	debug_data["breakpoints"] = []
	debug_data["codePerfs"] = []
	debug_data["watchpoints"] = []
	debug_data["scripts"] = scriptsJ

	codePerfs = {}
	watchpoints = {}

	for line_b in lines:
		line = line_b.decode('ascii')
		lineParts = line.split(" ")

		if len(lineParts) == 0:
			continue

		# check if it's a breakpoint
		if lineParts[0].find("BREAKPOINT") != -1:

			addr = int(lineParts[1][1:], 16)
			addrS = f"0x{addr:X}"
			conditionPos = line.find("IF")
			condS = line[conditionPos+3:] if conditionPos != -1 else ""
			cond = condS.split(' ')

			if len(cond) >= 3:
				operand = cond[0]
				operator = cond[1]
				value = cond[2]
				comment = "" if len(cond) < 4 else cond[3]
				# combine all elements of cond from [3] to the rest because it's a comment
				comment = ' '.join(cond[3:]) if len(cond) > 3 else ""
				comment = comment.rstrip("\r\n")
			else:
				operand = "A"
				operator = "=ANY"
				value = "0"
				comment = ""

			bpJ = {}
			bpJ["addr"] = addrS
			bpJ["autoDel"] = False
			bpJ["comment"] = comment
			bpJ["cond"] = operator
			bpJ["memPages"] = 0xFFFFFFFF # means check every page of the RAM Disk. TODO: add support for other memPages
			bpJ["operand"] = operand
			bpJ["status"] = 1 # enabled
			bpJ["value"] = value

			debug_data["breakpoints"].append(bpJ)

		# check if it's a code performance start label
		elif lineParts[0].upper().find("CODEPERFSTART_") != -1:
			label_start = lineParts[0].upper().find("CODEPERFSTART_") + len("CODEPERFSTART_")
			label_name = lineParts[0][label_start:]

			codePerf = codePerfs.setdefault(label_name, {})
			addr = int(lineParts[1][1:], 16)
			addrS = f"0x{addr:X}"
			codePerf["addrStart"] = addrS

		# check if it's a code performance end label
		elif lineParts[0].upper().find("CODEPERFEND_") != -1:
			label_start = lineParts[0].upper().find("CODEPERFEND_") + len("CODEPERFEND_")
			label_name = lineParts[0][label_start:]

			codePerf = codePerfs.setdefault(label_name, {})
			addr = int(lineParts[1][1:], 16)
			addrS = f"0x{addr:X}"
			codePerf["addrEnd"] = addrS

		# check if it's a watchpoint
		elif lineParts[0].upper().find("WATCHPOINTSTART") != -1:
			globalAddr = int(lineParts[1][1:], 16)
			globalAddrS = f"0x{globalAddr:X}"

			tokensCommentPos = lineParts[0].upper().find("WATCHPOINTSTART")
			tokensComment = lineParts[0][tokensCommentPos + len("WATCHPOINTSTART"):]
			[tokens, comment] = tokensComment.split("_", 1)

			tokens = tokens.upper()

			active = not tokens.find("OFF") != -1
			accessS = "R" if tokens.find("R_") != -1 else \
				"W" if tokens.find("W_") != -1 else "RW"

			watchpoint = watchpoints.setdefault(comment, {})
			watchpoint["comment"] = comment
			watchpoint["globalAddr"] = globalAddrS
			watchpoint["addrStart"] = globalAddr
			watchpoint["active"] = active
			watchpoint["access"] = accessS
			watchpoint["id"] = len(watchpoints) - 1
			watchpoint["type"] = "LEN"
			watchpoint["value"] = "0x0000"
			watchpoint["cond"] = "=ANY"

		# check if it's a watchpoint end label
		elif lineParts[0].upper().find("WATCHPOINTEND") != -1:
			line = lineParts[0].upper()
			comment_pos = line.find("WATCHPOINTEND") + len("WATCHPOINTEND") + 1
			comment = lineParts[0][comment_pos:]

			watchpoint = watchpoints.setdefault(comment, {})
			globalAddr = int(lineParts[1][1:], 16)
			length = globalAddr - watchpoint["addrStart"]
			lenS = f"0x{length:X}"
			watchpoint["len"] = lenS

		# check if it's a label or a constant
		elif len(lineParts) == 2 and lineParts[1][0] == "$":
			label_name = lineParts[0]

			# check if it's not for export
			if len(label_name) >= 2 and label_name[0] == "_" and label_name[1] != "_":
				continue

			addr = int(lineParts[1][1:], 16)
			addrS = f"0x{addr:X}"

			if label_name == label_name.upper():
				debug_data["consts"][label_name] = addrS
			else:
				debug_data["labels"][label_name] = addrS

	# add codePerfs to the debug data
	for label_name in codePerfs:
		codePerf = codePerfs[label_name]
		if "addrEnd" in codePerf and "addrStart" in codePerf:
			codePerf["label"] = label_name
			codePerf["addrStart"] = codePerf["addrStart"]
			codePerf["addrEnd"] = codePerf["addrEnd"]
			codePerf["active"] = True
			debug_data["codePerfs"].append(codePerf)

	# add watchpoints to the debug data
	for comment_name in watchpoints:
		watchpoint = watchpoints[comment_name]
		watchpoint.pop("addrStart", None)
		debug_data["watchpoints"].append(watchpoint)

	if out_path:
		with open(out_path, "w") as file:
			file.write(json.dumps(debug_data, indent=4))

	return debug_data


def get_segment_name(bank_id, addr_s_wo_hex_sym):
	return f'segment_bank{bank_id}_addr{addr_s_wo_hex_sym}'


def get_chunk_name(bank_id, addr_s_wo_hex_sym, chunk_id):
	return f'chunk_bank{bank_id}_addr{addr_s_wo_hex_sym}' + "_" + str(chunk_id)


def find_backbuffers_bank_ids(source_j, source_j_path):
	# find bank_id_backbuffer and bank_id_backbuffer2
	bank_id_backbuffer = -1
	bank_id_backbuffer2 = -1
	for bank_id, bank_j in enumerate(source_j["banks"]):
		for segment_j in bank_j["segments"]:
			for asset in segment_j["assets"]:
				if "reserved" in asset and asset["reserved"]:
					if asset["asset_type"] == "backbuffer":
						if bank_id_backbuffer >= 0:
							print(f"export_ram_disk_init ERROR: more than one chunk is reserved for bank_id_backbuffer. path: {source_j_path}\n")
							exit(1)
						bank_id_backbuffer = bank_id

					elif asset["asset_type"] == "backbuffer2":
						if bank_id_backbuffer2 >= 0:
							print(f"export_ram_disk_init ERROR: more than one chunk is reserved for bank_id_backbuffer2. path: {source_j_path}\n")
							exit(1)
						bank_id_backbuffer2 = bank_id
					continue

	if bank_id_backbuffer < 0:
		exit_error(f"export_ram_disk_init ERROR: no chunk is reserved for bank_id_backbuffer. path: {source_j_path}\n")
	if bank_id_backbuffer2 < 0:
		exit_error(f"export_ram_disk_init ERROR: no chunk is reserved for bank_id_backbuffer2. path: {source_j_path}\n")

	return bank_id_backbuffer, bank_id_backbuffer2


def generate_asm_meta_file(asm_meta_path, asm_data_path, bin_path, asm_meta_body = ""):
	# add the last record len to the meta data
	source_name = common.path_to_basename(bin_path)
	asm_meta = "; fdd bin file metadata\n"
	asm_meta += "; asm data file: " + asm_data_path + "\n"
	asm_meta += "; bin file: " + bin_path + "\n"
	asm_meta += "\n"
	asm_meta += f'{source_name.upper()}_FILE_LEN .filesize \"{bin_path}\"\n'
	asm_meta += f"{source_name.upper()}_LAST_RECORD_LEN = {source_name.upper()}_FILE_LEN & 0x7f\n"
	asm_meta += "\n"
	# add the filename to the meta data
	cmp_filename = os.path.basename(bin_path).split(".")
	cmp_filename_wo_ext_len = len(cmp_filename[0])
	asm_meta += f'{source_name.upper()}_FILENAME_PTR:\n'
	asm_meta += f'			.byte "{cmp_filename[0]}" ; filename\n'
	if cmp_filename_wo_ext_len < CPM_FILENAME_LEN:
		filename_white_chars = " " * (CPM_FILENAME_LEN - len(cmp_filename[0]))
		asm_meta += f'			.byte "{filename_white_chars}" ; filename white chars\n'
	asm_meta += f'			.byte "{cmp_filename[1]}" ; extension\n'
	asm_meta += "\n"

	asm_meta += asm_meta_body

	# save the asm meta file
	asm_meta_dir = str(Path(asm_meta_path).parent) + "/"
	if not os.path.exists(asm_meta_dir):
		os.mkdir(asm_meta_dir)
	with open(asm_meta_path, "w") as file:
		file.write(asm_meta)


CPM_FILENAME_LEN = 8
def get_cpm_filename(filename, ext = EXT_BIN):
	return (filename[:CPM_FILENAME_LEN] + ext).upper()
