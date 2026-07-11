import os
import json
import shutil
import subprocess

from utils import consts
from utils.log import TextColor, error, printc

def combine_bits_to_bytes(_bits):
	bytes = []
	i = 0
	while i < len(_bits):
		byte = 0
		for j in range(8):
			byte += _bits[i] << 7-j
			i += 1
		bytes.append(byte)
	return bytes

def path_to_basename(path):
	path_wo_ext = os.path.splitext(path)[0]
	name = os.path.basename(path_wo_ext)
	return name

def rename_extention(path, ext):
	return os.path.splitext(path)[0] + ext

def is_bytes_zeros(bytes):
	for byte in bytes:
		if byte != 0 : return False
	return True

def bytes_to_asm(data, numbers_in_line = 16, add_empty_last_line = False):
	asm = ""
	for i, byte in enumerate(data):
		if i % numbers_in_line == 0:
			if i != 0:
				asm += "\n"
			asm += "			.byte "
		asm += f"0x{byte:02X}, "

	asm += "\n"
	if add_empty_last_line:
		asm += "\n"
	return asm

def words_to_asm(data, numbers_in_line = 16):
	asm = ""
	for i, word in enumerate(data):
		if i % numbers_in_line == 0:
			if i != 0:
				asm += "\n"
			asm += "			.word "
		asm += f"0x{word:X},"
	return asm + "\n"

def bin_to_asm(path, out_path):
	with open(path, "rb") as file:
		txt = ""
		while True:
			data = file.read(32)
			if data:
				txt += "\n.byte "
				for byte in data:
					txt += str(byte) + ", "
			else: break

		with open(out_path, "w") as fw:
			fw.write(txt)

def CheckJsonField(source_j, field_name, comment = "", field_value = "", exit = True):
	if field_name not in source_j:
		if exit: error(comment)
		else: return False
	elif field_value != "" and source_j[field_name] != field_value:
		if exit: error(comment)
		else: return False
	return True

def CheckPath(path, comment = "", exit = True):
	if not os.path.isfile(path):
		if exit:
			error(f"{comment}. invalid path: {path}")
		else:
			printc(f"ERROR: {comment}. invalid path: {path}", TextColor.RED)

def DeleteDir(dir):
	if os.path.isdir(dir):
		shutil.rmtree(dir)

def run_command(command, comment = "", check_path = ""):
	if comment != "" :
		printc(comment, TextColor.CYAN)

	if check_path == "" or os.path.isfile(check_path):
		os.system(command)
	else:
		error(f"run_command ERROR: command: {command} failed. file {check_path} doesn't exist")

def delete_file(path):
	if os.path.isfile(f"{path}"):
		os.remove(f"{path}")

def rename_file(path, new_path, delete_old = False):
	if os.path.isfile(f"{path}"):
		if os.path.isfile(f"{new_path}"):
			delete_file(new_path)

		os.rename(f"{path}", f"{new_path}")

		if delete_old:
			delete_file(path)
	else:
		error(f"rename_file ERROR: file doesn't exist: {path}")

def load_json(source_j_path):
	with open(source_j_path, "rb") as file:
		source_j = json.load(file)
	return source_j

def remove_duplicate_slashes(path):
    return path.replace('//', '/')

def add_double_slashes(path: str) -> str:
    return path.replace('/', '//')

def get_addr_wo_prefix(hex_string):
	hex_string_without_prefix = hex_string.replace("$", "")
	hex_string_without_prefix = hex_string_without_prefix.replace("0x", "")

	if int(hex_string_without_prefix, 16) == 0:
		hex_string_without_prefix = "0"

	return hex_string_without_prefix

def hex_str_to_int(hex_string):
	hex_string_without_prefix = hex_string.replace("$", "")
	return int(hex_string_without_prefix, 16)

def align_string(str, allign, to_left = False):
	addition = "                   "
	if to_left:
		str = addition + str
		return str[-allign:]
	else:
		str += addition
		return str[0:allign]

def get_label_addr(path, _label):
	with open(path, "rb") as file:
		labels = file.readlines()

	if len(labels) == 0:
		return 0

	for line_a in labels:
		line = line_a.decode('ascii')
		if line.find(_label) != -1:
			addr_s = line[line.find("$") + 1:]
			return int(addr_s, 16)

	return -1


def compress_block_to_asm(asm_body, v6asm_path, packer_path, temp_dir, tag="blk", window=None):
	"""Assemble a data-ASM fragment and return its zx0-compressed bytes as ASM.

	Used for format-intrinsic compression (e.g. per-room level data): the body
	is assembled to a raw binary by v6asm, then packed with the external zx0
	packer. Returns ``(asm_string, packed_len)``.
	"""
	os.makedirs(temp_dir, exist_ok=True)
	path_asm = os.path.join(temp_dir, tag + consts.EXT_ASM)
	path_bin = os.path.join(temp_dir, tag + consts.EXT_BIN)
	path_packed = os.path.join(temp_dir, tag + consts.EXT_ZX0)

	with open(path_asm, "w", encoding="ascii") as f:
		f.write(".org 0\n" + asm_body)

	subprocess.run([v6asm_path, path_asm, "-o", path_bin], check=True)

	cmd = [*packer_path.split()]
	if window is not None:
		cmd += ["-w", str(window)]
	cmd += [path_bin, path_packed]
	delete_file(path_packed)
	result = subprocess.run(cmd)
	if result.returncode != 0:
		error("zx0 packer failed", " ".join(cmd))

	with open(path_packed, "rb") as f:
		packed = f.read()

	for p in (path_asm, path_bin, path_packed):
		delete_file(p)

	return bytes_to_asm(packed), len(packed)
