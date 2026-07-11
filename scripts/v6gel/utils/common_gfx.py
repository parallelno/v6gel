import os
import json
from PIL import Image
from pathlib import Path

IMAGE_COLORS_MAX = 16

def palette_file_to_asm(palette_path, asset_path = "", label_prefix = ""):
	with open(palette_path, "rb") as file:
		palette_j = json.load(file)

	palette_dir = str(Path(palette_path).parent) + "/"

	image = Image.open(palette_dir + palette_j['path_png'])

	palette_coords = palette_j["colors_pos"]
	colors = {}
	asm = "; " + asset_path + "\n"
	label = label_prefix + "_palette"
	palette = image.getpalette() 

	for i, pos in enumerate(palette_coords):
		x = pos["x"]
		y = pos["y"]
		color_idx = image.getpixel((x, y))
		r = palette[color_idx * 3]
		g = palette[color_idx * 3 + 1]
		b = palette[color_idx * 3 + 2]
		colors[(r, g, b)] = i
		color = pack_color(r, g, b)
		if i % 4 == 0 : asm += "			.byte "
		asm += "%" + format(color, '08b') + ", "
		if i % 4 == 3 : asm += "\n"
	
	return asm, colors, label, IMAGE_COLORS_MAX

# combines RGB values into a Vector06c color format
def pack_color(r,g,b):
	r = r >> 5
	g = g >> 5
	g = g << 3
	b = b >> 6
	b = b << 6
	return b | g | r

def remap_colors(image, colors):
	palette = image.getpalette()
	color_matching_table = {}
	
	for color_idx in range(len(palette) //3):
		r = palette[color_idx*3]
		g = palette[color_idx*3 + 1]
		b = palette[color_idx*3 + 2]
		rgb = (r,g,b)
		if rgb not in colors: 
			continue
		cidx = colors[rgb]
		color_matching_table[color_idx] = cidx
	
	w = image.width
	h = image.height

	for y in range(h) :
		for x in range(w) :
			color_idx = image.getpixel((x, y))
			new_color_idx = color_matching_table[color_idx]
			image.putpixel((x,y), new_color_idx)
	return image

color_index_to_bit = [
		(0,0,0,0), # color_idx = 0
		(0,0,0,1),
		(0,0,1,0), # color_idx = 2
		(0,0,1,1),
		(0,1,0,0), # color_idx = 4
		(0,1,0,1),
		(0,1,1,0),
		(0,1,1,1),
		(1,0,0,0), # color_idx = 8
		(1,0,0,1),
		(1,0,1,0),
		(1,0,1,1),
		(1,1,0,0),
		(1,1,0,1),
		(1,1,1,0),
		(1,1,1,1),
	]

def indexes_to_bit_lists(tile_img):
	bits0 = [] # 8000-9FFF # from left to right, from bottom to top
	bits1 = [] # A000-BFFF
	bits2 = [] # C000-DFFF
	bits3 = [] # E000-FFFF
	for line in tile_img:
		for color_idx in line:
			bit0, bit1, bit2, bit3 = color_index_to_bit[color_idx]
			bits0.append(bit0) 
			bits1.append(bit1)
			bits2.append(bit2)
			bits3.append(bit3)
	return bits0, bits1, bits2, bits3

def plane_indexes_to_bit_lists(tile_img):
	bits0 = [] # 8000-9FFF # from left to right, from bottom to top
	bits1 = [] # A000-BFFF
	bits2 = [] # C000-DFFF
	bits3 = [] # E000-FFFF
	for color_idx in tile_img:
		bit0, bit1, bit2, bit3 = color_index_to_bit[color_idx]
		bits0.append(bit0) 
		bits1.append(bit1)
		bits2.append(bit2)
		bits3.append(bit3)
	return bits0, bits1, bits2, bits3
