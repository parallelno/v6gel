; V6 runtime buffers


;===============================================================================
; Pointers to Current Level Data & Graphics
;===============================================================================
; This section holds data pointers to level-specific data such as rooms
; tiledata, resources, containers, the hero initial pose in the first room of
; the level, level, tile gparhics, and RAM-disk commands to access that data.
; NOTE:
; - Each level has its own set of level data. When the level is loaded, the
;     level data pointers and RAM-disk commands init this structire.

;------------------------------
; Level Data Table
;------------------------------
lv_data_init_tbl:				= $7602
  lv_ram_disk_s_data:				= lv_data_init_tbl		; .byte RAM-disk command for Stack access
  lv_ram_disk_m_data:				= lv_data_init_tbl + 1	; .byte RAM-disk command for Non-Stack access
  lv_rooms_pptr:					= lv_data_init_tbl + 2	; .word Pointer to packed room data (tiledata + graphics tile idxs)
  lv_resources_inst_data_pptr:	= lv_data_init_tbl + 4	; .word Pointer to resource instance data
  lv_containers_inst_data_pptr:	= lv_data_init_tbl + 6	; .word Pointer to container instance data
  lv_start_pos:					= lv_data_init_tbl + 8	; .word Hero start position (Y, X)
;------------------------------
; Graphics Init Table
;------------------------------
lv_gfx_init_tbl:				= lv_start_pos + WORD_LEN
  lv_ram_disk_s_gfx:				= lv_gfx_init_tbl		; .byte RAM-disk command for Stack access
  lv_ram_disk_m_gfx:				= lv_gfx_init_tbl + 1	; .byte RAM-disk command for Non-Stack access
  lv_tiles_pptr:					= lv_gfx_init_tbl + 2	; .word Pointer to tile graphics data
@data_end:						= lv_gfx_init_tbl + 4
LEVEL_INIT_TBL_LEN = @data_end - lv_data_init_tbl



;===============================================================================
; Temporary Buffer
;===============================================================================
; Usage:
; - unpacking tiled image index data
; - unpacking text data

TEMP_BUFF_LEN	= $200
temp_buff: 		.storage TEMP_BUFF_LEN


;===============================================================================
; Room Tile Graphics Pointer Table
;===============================================================================
; Stores pointers to tile graphics used in the current room.
; NOTE:
; - When a hero enters a room, the room's data including tiledata and tile
;     graphics idxs are unpacked from the RAM-disk into this buffer and the
;     buffer above (room_tiles_gfx_ptrs & room_tiledata).
; - Room conststs of ROOM_WIDTH * ROOM_HEIGHT tiles. Each tile has its own
;     tiledata elements and tile graphics idx.
; - Tile graphics idx is used to render the tile.
;
;-------------------------------------------------------------------------------
; Data Layout:
;-------------------------------------------------------------------------------
; .loop ROOM_HEIGHT
;	.loop ROOM_WIDTH
;		.word - tile_gfx_addr
;	.endloop
; .endloop

ROOM_TILES_GFX_PTRS_LEN	= ROOM_WIDTH * ROOM_HEIGHT * ADDR_LEN
room_tiles_gfx_ptrs:		= $7920
room_tiles_gfx_ptrs_end:	= room_tiles_gfx_ptrs + ROOM_TILES_GFX_PTRS_LEN


;===============================================================================
; Room TileData Buffer
;===============================================================================
; Stores the tiledata for the current room.
; NOTE:
; - When a hero enters a room, the room's data including tiledata and tile
;     graphics idxs are unpacked from the RAM-disk into this buffer and the
;     buffer above (room_tiles_gfx_ptrs & room_tiledata).
; - Room conststs of ROOM_WIDTH * ROOM_HEIGHT tiles. Each tile has its own
;     tiledata elements and tile graphics idx.
; - Tiledata is used for collision detection, and game mechanics. Tiledata can
;     be a char, char spawner, container, door, and other interactive element.
;     See tiledata_consts.asm for all tiledata values.
; - Tiledata can be modified during gameplay, e.g. breakable objects, doors,
;     and containers can change their tiledata when broken/opened.
; - Tiledata is restored from the room_tiledata_backup buffer when dialogs
;     are displayed.
; - Data is $100-aligned and must fit inside $100 block.
;-------------------------------------------------------------------------------
; Data Layout:
;-------------------------------------------------------------------------------

; Data Layout:
; .loop ROOM_HEIGHT
;	.loop ROOM_WIDTH
;		.byte - tiledata
;	.endloop
; .endloop

ROOM_TILEDATA_LEN	= ROOM_WIDTH * ROOM_HEIGHT
room_tiledata:		= $7B00
room_tiledata_end:	= room_tiledata + ROOM_TILEDATA_LEN
