import struct
import sys
import os
import json
from pathlib import Path
import utils.common as common
import utils.build as build
import lhafile
import io


def export_if_updated(		asset_j_path, asm_meta_path, asm_data_path, bin_path,
		force_export):

	if force_export or is_source_updated(asset_j_path):
		export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path)
		print(f"export_music: {asset_j_path} got exported.")

def is_source_updated(asset_j_path):
	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	asset_dir = str(Path(asset_j_path).parent) + "/"
	path_ym = asset_dir + asset_j["path_ym"]

	if build.is_file_updated(asset_j_path) | build.is_file_updated(path_ym):
		return True
	return False

def export_asm(asset_j_path, asm_meta_path, asm_data_path, bin_path, clean_tmp = True):

	with open(asset_j_path, "rb") as file:
		asset_j = json.load(file)

	label_prefix = common.path_to_basename(asset_j_path)

	asm_ram_disk_data, data_relative_ptrs, ay_reg_data_labels = \
		ramdisk_data_to_asm(asset_j_path, asset_j, label_prefix, clean_tmp)

	asm_ram_data = meta_data_to_asm(label_prefix, data_relative_ptrs, ay_reg_data_labels)


	# save the RAM Disk asm
	asm_data_dir = str(Path(asm_data_path).parent) + "/"
	if not os.path.exists(asm_data_dir):
		os.mkdir(asm_data_dir)
	with open(asm_data_path, "w") as file:
		file.write(asm_ram_disk_data)

	# compile and save the meta and RAM Disk data
	build.generate_asm_meta_file(asm_meta_path, asm_data_path, bin_path, asm_ram_data)

	return True

def ramdisk_data_to_asm(asset_j_path, asset_j, label_prefix, clean_tmp = True):

	try:
		with open(asset_j_path, "rb") as file:
			asset_j = json.load(file)

			asset_dir = str(Path(asset_j_path).parent) + "/"
			song_path = asset_dir + asset_j["path_ym"]

		[reg_data, comment1, comment2, comment3] = readym(song_path)
	except:
		build.exit_error(f'export_music ERROR: reading file: {song_path}')

	ay_reg_data_lens = []

	# make the asm
	asm = ""
	# task stacks
	# song's credits
	asm += f'; {comment1}\n; {comment2}\n; {comment3}\n'

	# org

	data_relative_ptrs = {}
	addr_relative = 0

	# add the v6_gc_buffer
	GC_BUFFER_SIZE = 0x100
	GC_TASKS = 14
	GC_STACK_SIZE = 16

	asm += f'.org 0\n'
	asm += f'GC_BUFFER_SIZE	= {GC_BUFFER_SIZE}\n'
	asm += f'GC_TASKS		= {GC_TASKS}\n'
	asm += f'GC_STACK_SIZE	= {GC_STACK_SIZE}\n'
	asm += f'.align GC_BUFFER_SIZE\n'
	asm += f'; these are GC_TASKS buffers GC_BUFFER_SIZE bytes long\n'
	asm += f'; MUST BE ALIGNED by 0x100\n'
	asm += f'_v6_gc_buffer:\n'
	asm += f'			.storage GC_BUFFER_SIZE * GC_TASKS, $00	\n\n'
	asm += f'_v6_gc_task_stack:\n'
	asm += f'			.storage GC_STACK_SIZE * GC_TASKS, $00	\n\n'
	asm += f'_v6_gc_task_stack_end:\n'

	data_relative_ptrs['_v6_gc_buffer'] = addr_relative
	addr_relative += GC_BUFFER_SIZE * GC_TASKS
	addr_relative += GC_STACK_SIZE * GC_TASKS
	data_relative_ptrs['_v6_gc_task_stack_end'] = addr_relative

	# export reg data and build reg data asm block
	temp_dir = build.TEMP_DIR
	os.makedirs(temp_dir, exist_ok=True)

	for i, c in enumerate(reg_data[0:14]):
		bin_file = f"{temp_dir}{label_prefix}{i:02d}{build.EXT_BIN}"
		zx0File = f"{temp_dir}{label_prefix}{i:02d}{build.packer_ext}"
		with open(bin_file, "wb") as f:
			f.write(c)

		common.delete_file(zx0File)
		common.run_command(f"{build.packer_path.replace('/', '\\')} -w 256 {bin_file} {zx0File}")

		with open(zx0File, "rb") as f:
			dbname = f"_{label_prefix}_ay_reg_data{i:02d}_relative"
			data = f.read()
			asm += f'{dbname}: .byte ' + ",".join("$%02x" % x for x in data) + "\n"
			ay_reg_data_lens.append(len(data))

		if clean_tmp:
			print("export_music: clean up tmp resources")
			common.delete_file(bin_file)
			common.delete_file(zx0File)


	# convert ay register data lengths to relative ptrs
	ay_reg_data_labels = []
	for i, reg_data_len in enumerate(ay_reg_data_lens):
		label_name = f'_{label_prefix}_ay_reg_data{i:02d}_relative'
		data_relative_ptrs[label_name] = addr_relative
		addr_relative += reg_data_len
		ay_reg_data_labels.append(label_name)

	return asm, data_relative_ptrs, ay_reg_data_labels

def meta_data_to_asm(label_prefix, data_relative_ptrs, ay_reg_data_labels):
	asm = ""

	asm += "; relative labels\n"
	for label, val in data_relative_ptrs.items():
		asm += f"{label} = 0x{val:04x}\n"
	asm += "\n\n"

	# reg_data ptrs.
	asm += f'{label_prefix}_ay_reg_data_ptrs:\n			.word '
	for label_name in ay_reg_data_labels:
		asm += f'{label_name}, '
	asm += "\n\n"

	return asm


def chunker(seq, size):
	return (seq[pos:pos + size] for pos in range(0, len(seq), size))

def drop_comment(f):

	comment = ''
	print("export_music: song name/credits: ")
	while True:
		b = f.read(1)
		if b[0] == 0:
			break
		comment = comment + chr(b[0])
		print(chr(b[0]), end='')
	print()
	return comment

def readym(filename):
	try:
		lf = lhafile.Lhafile(filename)
		data = lf.read(lf.namelist()[0])
		f = io.BytesIO(data)
	except:
		f = open(filename, "rb")

	hdr = f.read(12) # YM6!LeOnArD!               # 12
	print('export_music: hdr=', hdr)
	nframes = struct.unpack(">I", f.read(4))[0]      # 16

	print("export_music: YM6 file has ", nframes, " frames")

	attrib = struct.unpack(">I", f.read(4))       # 20
	digidrums = struct.unpack(">h", f.read(2))    # 22
	masterclock = struct.unpack(">I", f.read(4))  # 26
	framehz = struct.unpack(">h", f.read(2))      # 28
	loopfrm = struct.unpack(">I", f.read(4))      # 32
	f.read(2) # additional data                   # 34
	print("export_music: Masterclock: ", masterclock, "Hz")
	print("export_music: Frame: ", framehz, "Hz")

	# skip digidrums but we don't do that here..

	comment1 = drop_comment(f)
	comment2 = drop_comment(f)
	comment3 = drop_comment(f)

	regs=[]
	for i in range(16):
		complete = list(f.read(nframes))
		chu = chunker(complete, 2)
		#decimated = [x if x < y else y for x, y in chu]
		#decimated = complete[::2]
		#decimated = [x if x != 255 else y for x, y in chu]
		decimated = complete
		decbytes = bytes(decimated)
		regs.append(decbytes)  ## brutal decimator

	f.close()

	return [regs, comment1, comment2, comment3]