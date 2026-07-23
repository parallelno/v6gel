; V6 runtime buffers


.pack
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
lv_data_init_tbl:
  lv_ram_disk_s_data:			.storage 1 ; .byte RAM-disk command for Stack access
  lv_ram_disk_m_data:			.storage 1 ; .byte RAM-disk command for Non-Stack access
  lv_rooms_pptr:				.storage 2 ; .word Pointer to packed room data (tiledata + graphics tile idxs)
  lv_resources_inst_data_pptr:	.storage 2 ; .word Pointer to resource instance data
  lv_containers_inst_data_pptr:	.storage 2 ; .word Pointer to container instance data
  lv_start_pos:					.storage 2 ; .word Hero start position (Y, X)
;------------------------------
; Graphics Init Table
;------------------------------
lv_gfx_init_tbl:
  lv_ram_disk_s_gfx:			.storage 1 ; .byte RAM-disk command for Stack access
  lv_ram_disk_m_gfx:			.storage 1 ; .byte RAM-disk command for Non-Stack access
  lv_tiles_pptr:				.storage 2 ; .word Pointer to tile graphics data
@data_end:
LEVEL_INIT_TBL_LEN = @data_end - lv_data_init_tbl
.endpack


.pack
;===============================================================================
; Global Runtime States
;===============================================================================

global_states:
; The current room idx within the current level
room_id:				.storage 1 ; .byte ; Range: [0, ROOMS_MAX-1]

; The index of the current level (must be located immediately after room_id)
level_id:				.storage 1 ; .byte

; Currently visible item in the game UI panel
; Value corresponds to item ID, range: [0, ITEMS_MAX-1]
game_ui_item_visible_addr:  .storage 1 ; .byte

border_color_idx:		.storage 1 ; .byte Current border color index
scr_offset_y:			.storage 1 ; .byte Vertical screen offset ($255 by default)

; Counts pending game updates to sync the game loop with interrupts.
; If < 0, no updates are pending.
; Incremented in the interruption routine.
; Checked and decremented in the game update.
game_updates_required:	.storage 1 ; .byte

; Temporary coordinates used during character movement logic:
char_temp_x:			.storage 2 ; .word
char_temp_y:			.storage 2 ; .word
@data_end:		= global_states + 10
GLOBAL_STATES_LEN = @data_end - global_states
.endpack

.pack
;===============================================================================
; Temporary Buffer
;===============================================================================
; Usage:
; - unpacking tiled image index data
; - unpacking text data

TEMP_BUFF_LEN	= $200
temp_buff: 		.storage TEMP_BUFF_LEN
.endpack


.pack align
.storage 0x20 ; to align the room_tiledata block to a 0x100 boundary

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
room_tiles_gfx_ptrs:		  .storage ROOM_TILES_GFX_PTRS_LEN
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
room_tiledata:		  .storage ROOM_TILEDATA_LEN
room_tiledata_end:	= room_tiledata + ROOM_TILEDATA_LEN
.endpack

.pack
;===============================================================================
; Teleport Room IDs
;===============================================================================
; A table to convert teleport IDs to room IDs for the current room.
; NOTE:
; - When the hero steps on a teleport tile, the tiledata provides a teleport ID.
; - The teleport ID is used to look up the destination room ID in this table.
; - When a hero enters a room, the room's teleport data is copied from
;     the RAM-disk into this buffer.
;
;-------------------------------------------------------------------------------
; Data Layout:
;-------------------------------------------------------------------------------
; .byte - room_id for teleport_id = 0
; .byte - room_id for teleport_id = 1
; ...
; .byte - room_id for teleport_id = N
; Where N = TELEPORT_IDS_MAX - 1

; Defines the maximum number of unique teleport IDs per room.
TELEPORT_IDS_MAX = 16
ROOM_TELEPORTS_DATA_LEN = TELEPORT_IDS_MAX

room_teleports_data:
.storage TELEPORT_IDS_MAX
.endpack