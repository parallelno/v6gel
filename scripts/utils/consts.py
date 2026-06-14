"""Hardware, asset and file-format constants for the v6 toolchain.

These were previously scattered across ``utils/build.py``. They are collected
here so the export tools can share them without importing the old build-state
god module.
"""

# ----------------------------------------------------------------------------
# Asset types (value of the "asset_type" field in an asset meta JSON)
# ----------------------------------------------------------------------------
ASSET_TYPE_BACK = "back"
ASSET_TYPE_FONT = "font"
# font_gfx_ptrs.asm is linked into the main program; it must be included into
# the RAM Disk asm code manually instead.
ASSET_TYPE_FONT_RD = "font_rd"
ASSET_TYPE_SPRITE = "sprite"
ASSET_TYPE_TEXT_ENG = "text_eng"
ASSET_TYPE_TEXT_RUS = "text_rus"

ASSET_TYPE_LEVEL = "level"
ASSET_TYPE_LEVEL_DATA = "level_data"
ASSET_TYPE_LEVEL_GFX = "level_gfx"

ASSET_TYPE_TILED_IMG = "tiled_img"
ASSET_TYPE_TILED_IMG_DATA = "tiled_img_data"
ASSET_TYPE_TILED_IMG_GFX = "tiled_img_gfx"

ASSET_TYPE_DECAL = "decal"
ASSET_TYPE_IMAGE = "image"
ASSET_TYPE_MUSIC = "music"
ASSET_TYPE_CODE = "code"
ASSET_TYPE_CONFIG = "config"
ASSET_TYPE_PALETTE = "palette"

# Localization ids used by the text exporter.
LOCAL_SYMBOL_NAME = "LOCALIZATION"
LOCAL_ENG = "0"
LOCAL_RUS = "1"

# ----------------------------------------------------------------------------
# File extensions
# ----------------------------------------------------------------------------
EXT_TXT = ".txt"
EXT_ASM = ".asm"
EXT_BIN = ".bin"
EXT_ZX0 = ".zx0"
EXT_ROM = ".rom"
EXT_COM = ".com"
EXT_FDD = ".fdd"
EXT_YM = ".ym"
EXT_JSON = ".json"
EXT_BAT = ".bat"
EXT_MANIFEST = ".manifest.json"

# ----------------------------------------------------------------------------
# CP/M file naming (used for FDD entries)
# ----------------------------------------------------------------------------
CPM_FILENAME_LEN = 8

# Default scratch directory for intermediate build files.
TEMP_DIR = "build/temp/"

# ----------------------------------------------------------------------------
# Hardware and game constants
# ----------------------------------------------------------------------------
SAFE_WORD_LEN = 2  # safety pair of bytes for reading by POP B
BYTE_LEN = 1
WORD_LEN = 2
NULL_S = "NULL"

RAM_LEN = 0x10000
RAM_DISK_BANK_LEN = 0x10000
RAM_DISK_BANKS_MAX = 4
RAM_DISK_LEN = RAM_DISK_BANK_LEN * RAM_DISK_BANKS_MAX
RAM_DISK_SEGMENT_LEN = RAM_DISK_BANK_LEN // 2

SCR_BUFF_LEN = 0x2000
SCR_BUFFS_LEN = SCR_BUFF_LEN * 4
SCR_ADDR = 0x8000

MAIN_STACK_LEN = 32  # used in the main program
INT_STACK_LEN = 30  # used in the interruption routine
TMP_STACK_LEN = 2  # temp 2-byte space in render routines (sprite_copy_to_scr_v)
ALL_STACKS_LEN = MAIN_STACK_LEN + INT_STACK_LEN + TMP_STACK_LEN

# "-2" because erase funcs can let the interruption call corrupt 0x7ffe/0x7fff.
STACK_MAIN_PROGRAM_ADDR = 0x8000 - 2
STACK_INTERRUPTION_ADDR = STACK_MAIN_PROGRAM_ADDR - MAIN_STACK_LEN
STACK_TEMP_ADDR = STACK_INTERRUPTION_ADDR - INT_STACK_LEN
STACK_MIN_ADDR = STACK_TEMP_ADDR - TMP_STACK_LEN
