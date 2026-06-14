"""Shared helpers for the tiled-image exporters (data + gfx).

Port of the original ``export_tiled_img_utils`` with staleness checking removed
and the ``build`` dependency replaced by ``consts``/``log``.
"""

from utils import common, common_gfx, consts

IMG_TILE_W = 8
IMG_TILE_H = 8

SCR_TILES_W = 32
SCR_TILES_H = 32

TILED_IMG_GFX_IDX_MAX = 255
TILED_IMG_IDXS_LEN_MAX = 512

# metadata layout (see draw_tiled_img.asm):
#   .word COPY_LENGTH   ; how many byte pairs to copy from the RAM Disk
#   .word SCR addr
#   .word SCR addr end
COPY_LEN = 2
SCR_START = 2
SCR_END = 2

REPEATER_CODE = 255


def get_tiledata(bytes0, bytes1, bytes2, bytes3, use_mask):
	if not use_mask:
		# reverse every second list of bytes to support the tiled_img format
		bytes1 = bytes1[::-1]
		bytes3 = bytes3[::-1]

	all_bytes = [bytes0, bytes1, bytes2, bytes3]
	mask = 0
	data = []
	for plane in all_bytes:
		if use_mask:
			mask >>= 1
			if common.is_bytes_zeros(plane):
				continue
			mask += 8
		data.extend(plane)

	return data, mask


def gfx_to_asm(label_prefix, image, remap_idxs):
	asm = "\n"
	for t_idx in remap_idxs:
		tile_img = []
		idx = t_idx - 1  # Tiled exports the first tile index as 1.
		sx = idx % SCR_TILES_W * IMG_TILE_W
		sy = idx // SCR_TILES_W * IMG_TILE_H
		for y in reversed(range(sy, sy + IMG_TILE_H)):
			tile_img.append([image.getpixel((x, y)) for x in range(sx, sx + IMG_TILE_W)])

		bits0, bits1, bits2, bits3 = common_gfx.indexes_to_bit_lists(tile_img)
		bytes0 = common.combine_bits_to_bytes(bits0)
		bytes1 = common.combine_bits_to_bytes(bits1)
		bytes2 = common.combine_bits_to_bytes(bits2)
		bytes3 = common.combine_bits_to_bytes(bits3)

		# do not use a mask: it is a large overhead for such small tiles.
		data, _ = get_tiledata(bytes0, bytes1, bytes2, bytes3, False)

		asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
		asm += label_prefix + "_tile" + str(remap_idxs[t_idx]) + ":\n"
		asm += common.bytes_to_asm(data, IMG_TILE_H, True)

	return asm


def remap_indices(tiled_file_j):
	unique_idxs = {}
	new_idx = 1
	for layer in tiled_file_j["layers"]:
		if layer["type"] != "tilelayer":
			continue
		for idx in layer["data"]:
			if idx != 0 and idx not in unique_idxs:
				unique_idxs[idx] = new_idx
				new_idx += 1
	return unique_idxs


def pack_idxs(idxs_unpacked, tiles_w, tiles_h):
	idxs = []
	for j in range(tiles_h):
		repeaters = []
		repeaters_lens = []
		prev_idx = -1
		for i in range(tiles_w):
			idx = idxs_unpacked[j * tiles_w + i]
			if idx != prev_idx:
				repeaters.append(idx)
				repeaters_lens.append(1)
				prev_idx = idx
			else:
				repeaters_lens[-1] += 1

		idxs_line = []
		# encode runs longer than 3 as (REPEATER_CODE, IDX, LEN).
		for i, idx in enumerate(repeaters):
			repeater_len = repeaters_lens[i]
			if repeater_len <= 3:
				idxs_line.extend([idx] * repeater_len)
			else:
				idxs_line.append(REPEATER_CODE)
				idxs_line.append(idx)
				idxs_line.append(repeater_len)
		idxs.extend(idxs_line)
	return idxs


def tile_idxs_to_asm(label_name, idxs_unpacked, pos_x, pos_y, tiles_w, tiles_h):
	idxs = pack_idxs(idxs_unpacked, tiles_w, tiles_h)

	data_len = len(idxs) + COPY_LEN + SCR_START + SCR_END
	copy_data_len = len(idxs) + SCR_START + SCR_END
	# rounded up to the nearest even number of bytes
	idxs_data_copy_rounded_len = (copy_data_len // 2 + copy_data_len % 2) * 2

	asm = f"{label_name.upper()}_COPY_LEN = {idxs_data_copy_rounded_len}\n"
	asm += "			.word 0 ; safety pair of bytes for reading by POP B\n"
	asm += label_name + ":\n"
	asm += f"			.word {label_name.upper()}_COPY_LEN ; data len to copy\n"
	asm += f"			.word 0x8000 + ({pos_x}<<8 | {pos_y})	; scr addr\n"
	asm += f"			.word 0x8000 + ({pos_x + tiles_w}<<8 | {(pos_y + tiles_h * 8) % 256})	; scr addr end\n"
	asm += common.bytes_to_asm(idxs)

	return asm, data_len
