"""Music exporter (AY-3-8910 register streams from a YM6 file).

Output blob layout (assembled from the generated data-ASM):

* the V6 "GC" task buffers/stacks (zeroed, alignment-critical), followed by
* the 14 AY register streams, **each individually zx0-compressed** with a
  256-byte window.

The per-channel compression is part of the data *format*: at run time the
player decompresses each register stream on the fly through a small 256-byte
window buffer, so it stays inside the exporter (unlike the whole-file transport
compression applied by ``v6export --compress`` before embedding or storing the
blob).
"""

import io
import struct

import lhafile

from v6gel.utils import asmgen, consts
from v6gel.utils.log import error
from v6gel.exporters.context import AssetManifest, ExportContext

# V6 garbage-collected task buffer geometry (must match the runtime).
GC_BUFFER_SIZE = 0x100
GC_TASKS = 14
GC_STACK_SIZE = 16

AY_REG_COUNT = 14
ZX0_WINDOW = 256


def export(ctx: ExportContext) -> AssetManifest:
	ym_path = ctx.asset_rel("path_ym")

	reg_data, comment1, comment2, comment3 = _read_ym(ym_path)

	data_asm = _build_data_asm(ctx, reg_data, (comment1, comment2, comment3))
	meta_body = _build_meta_body(ctx.name)

	keep_asm = ctx.data_asm_path if ctx.emit_asm else None
	bin_len = asmgen.assemble(
		ctx.v6asm_path, data_asm, ctx.bin_path, ctx.temp_dir, keep_asm
	)

	with open(ctx.meta_asm_path, "w", encoding="ascii") as f:
		f.write(asmgen.meta_asm(ctx.stored_path, meta_body, ctx.emit_filename))

	return AssetManifest(
		name=ctx.name,
		asset_type=consts.ASSET_TYPE_MUSIC,
		bin_path=ctx.bin_path,
		bin_len=bin_len,
		meta_asm_path=ctx.meta_asm_path,
		data_asm_path=keep_asm,
		extra={"ay_reg_data_ptrs": f"_{ctx.name}_ay_reg_data_ptrs"},
	)


# ----------------------------------------------------------------------------
# Data / meta ASM generation
# ----------------------------------------------------------------------------

def _build_data_asm(ctx, reg_data, comments):
	prefix = ctx.name

	asm = "; It will be assembled and compressed, then either linked to the main program or loaded from disk.\n\n"
	asm += f"; {comments[0]}\n; {comments[1]}\n; {comments[2]}\n"
	asm += "\n.org 0\n\n"
	asm += "ADDR_LEN\t\t= 2\n\n"
	asm += "; runtime buffers:\n"
	asm += f"GC_TASKS\t\t= {GC_TASKS} ; 14 individual threads for each AY register\n"
	asm += "GC_MUSIC_REG_PTRS_LEN = GC_TASKS * ADDR_LEN\n"
	asm += "GC_STREAM_BUFFERS \t\t= 0x8000\n"
	asm += "\n\n"

	# Compress each AY register stream individually.
	packed_channels = []
	for i, channel in enumerate(reg_data[0:AY_REG_COUNT]):
		packed = _zx0_compress(ctx, channel, f"{prefix}{i:02d}")
		packed_channels.append(packed)

	# Compute pointer formula values (GC area size + cumulative compressed stream offset).
	# These equal the old-format relative offsets, ensuring the same runtime layout.
	gc_area_size = GC_BUFFER_SIZE * GC_TASKS + GC_STACK_SIZE * GC_TASKS
	addr = gc_area_size
	ptr_values = []
	for packed in packed_channels:
		ptr_values.append(addr)
		addr += len(packed)

	# Emit pointer constant definitions.
	for i, val in enumerate(ptr_values):
		asm += f"_{prefix}_ay_reg_data{i:02d}_ptr = 0x{val:04x} + GC_MUSIC_REG_PTRS_LEN + GC_STREAM_BUFFERS\n"

	asm += "\n"
	asm += f"_{prefix}_ay_reg_data_ptrs:\n"
	asm += "\t\t\t.word " + ", ".join(f"_{prefix}_ay_reg_data{i:02d}_ptr" for i in range(AY_REG_COUNT))
	asm += ",\n\n"

	asm += f"\n_{prefix}_ay_reg_data:\n"
	for i, packed in enumerate(packed_channels):
		name = f"_{prefix}_ay_reg_data{i:02d}"
		asm += f"{name}: .byte " + ",".join("$%02x" % b for b in packed) + "\n"

	return asm


def _build_meta_body(prefix):
	return ""


def _zx0_compress(ctx, raw, tag):
	"""Compress one register stream and return the packed bytes."""
	import os
	os.makedirs(ctx.temp_dir, exist_ok=True)
	bin_path = os.path.join(ctx.temp_dir, tag + consts.EXT_BIN)
	zx0_path = os.path.join(ctx.temp_dir, tag + consts.EXT_ZX0)

	with open(bin_path, "wb") as f:
		f.write(raw)
	if os.path.exists(zx0_path):
		os.remove(zx0_path)

	asmgen.run([*ctx.packer_path.split(), "-w", str(ZX0_WINDOW), bin_path, zx0_path])

	with open(zx0_path, "rb") as f:
		packed = f.read()

	for path in (bin_path, zx0_path):
		try:
			os.remove(path)
		except OSError:
			pass
	return packed


# ----------------------------------------------------------------------------
# YM6 parsing
# ----------------------------------------------------------------------------

def _read_ym(filename):
	"""Parse a (optionally LHA-compressed) YM6 file into 16 register streams."""
	try:
		archive = lhafile.Lhafile(filename)
		data = archive.read(archive.namelist()[0])
		f = io.BytesIO(data)
	except Exception:
		f = open(filename, "rb")

	try:
		header = f.read(12)  # "YM6!LeOnArD!"
		if not header.startswith(b"YM"):
			error(f"not a YM file: {filename}", header.hex())
		nframes = struct.unpack(">I", f.read(4))[0]

		f.read(4)  # attributes
		f.read(2)  # digidrums count
		f.read(4)  # master clock
		f.read(2)  # frame rate (Hz)
		f.read(4)  # loop frame
		f.read(2)  # additional data size

		comment1 = _read_cstr(f)
		comment2 = _read_cstr(f)
		comment3 = _read_cstr(f)

		regs = []
		for _ in range(16):
			regs.append(bytes(f.read(nframes)))
	finally:
		f.close()

	return regs, comment1, comment2, comment3


def _read_cstr(f):
	chars = []
	while True:
		b = f.read(1)
		if not b or b[0] == 0:
			break
		chars.append(chr(b[0]))
	return "".join(chars)
