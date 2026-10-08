
@memusage_room_tiledata:

; it copies the room tiledata into room_tiledata_backup
; for room_redraw and storing states of breakable objects
room_backup_tiledata:
			lxi h, room_tiledata
			lxi d, room_tiledata_backup
			lxi b, ROOM_TILEDATA_LEN
			jmp mem_copy


; calls the tiledata handler func to spawn a back, breakable, char, etc
room_handle_room_tiledata:
			mvi a, ROOM_TILEDATA_LEN

; in:
; a = the tile_id to stop handling
room_handle_room_tiledata_ex:
			sta @last_tile_id + 1

			; handle the tiledata calling tiledata funcs
			lxi h, room_tiledata
			mvi c, 0
@loop:
			push b
			push h
			mov b, m
			; b - tiledata
			; extract a function
			mvi a, TILEDATA_FUNC_MASK
			ana b

			; check if this func skippable
			cpi TILEDATA_FUNC_ID_CHARS<<4
@check:
			jmp @no_skip
			mvi a, TILEDATA_RESTORE_TILE
			jmp @func_ret_addr

@no_skip:
			RRC_(2) ; to make a jmp table ptr with a 4 byte allignment
			HL_TO_A_PLUS_INT16(room_tiledata_funcs)
			; extract a func argument
			mvi a, TILEDATA_ARG_MASK
			ana b
			lxi d, @func_ret_addr
			push d
			pchl
@func_ret_addr:
			pop h
			pop b
			mov m, a ; save tiledata returned by individual handle func (ex. backs_spawn) back into room_tiledata.
			inx h
			inr c
@last_tile_id:
			mvi a, TEMP_BYTE
			cmp c
			jnz @loop
			ret
room_handle_room_tiledata_check = @check


; check tiles if they need to be restored.
; all gfx of tiledata that are > 0, need to be restored if there is a sprite on it
; in:
; de - scr addr
; h - width
;		00 - 8pxs,
;		01 - 16pxs,
;		10 - 24pxs,
;		11 - 32pxs
; l - height
; out:
; Z flag == 0 if this area needs to be restored
; v2. 124 - 280
room_check_tiledata_restorable:
			; convert scr addr to room_tiles_gfx_ptrs offset
			mvi a, %00011110
			ana d
			rrc
			mov b, a
			mvi a, %11110000
			ana e
			mov c, a
			; b = x in tiles
			; c, a = y in tiles * 32

			dad d
			; hl - top-right corner scr addr
			mvi d, >room_tiledata

			; check bottom-left corner
			ora b
			mov e, a
			ldax d
			CPI_ZERO(TILEDATA_NO_COLLISION)
			rnz			; 124 cc if returns

			; get x+dx in tiles
			mvi a, %00011110
			ana h
			rrc
			mov h, a
			; h, a = x+dx in tiles

			; check bottom-right corner
			ora c
			mov e, a
			ldax d
			CPI_ZERO(TILEDATA_NO_COLLISION)
			rnz		; 180 cc if returns

			; get y+dy in tiles
			dcr l ; to be inside the AABB
			mvi a, %11110000
			ana l
			mov l, a
			; l, a = y+dy in tiles

			; check top-right corner
			ora h
			mov e, a
			ldax d
			CPI_ZERO(TILEDATA_NO_COLLISION)
			rnz		; 240 cc if returns

			; check top-left corner
			mov a, b
			ora l
			mov e, a
			ldax d
			CPI_ZERO(TILEDATA_NO_COLLISION)
			ret		; 280 cc

; collects tiledata of tiles that intersect with a sprite
; if several tile corners stays on the same tile,
; they all read same tiledata to let collision logic works properly
; in:
; d - pos_x
; e - pos_y
; b - width-1
; c - height-1
; out:
; hl - (top-left), (top-right)
; de - (bottom-left), (bottom-right)
; a - "OR" operation on tiledata of all tiles that intersect with a sprite
; ~253 cc
room_get_collision_tiledata:
			; calc y in tiles
			mvi a, %11110000
			ana e
			mov l, a
			; l = y in tiles

			; calc y+dy in tiles
			mov a, e
			add c
			ani %11110000
			cmp l
			; if y = y+dy, do not top two corners
			jz @sameTileRow

			; calc x+dx in tiles
			mov a, d
			add b
			ani %11110000
			mov h, a
			; h = x+dx in tiles
			mvi a, %11110000
			ana d
			; a = x in tiles
			cmp h
			jz @sameTileCol

			RRC_(4)
			ora l
			mov l, a
			mvi h, >room_tiledata

			mov e, m
			inx h
			mov d, m
			lxi b, ROOM_WIDTH
			dad b
			mov a, m
			dcx h
			mov l, m
			mov h, a

			ora l
			ora d
			ora e
			ret

@sameTileRow:
			; calc x+dx in tiles
			mov a, d
			add b
			ani %11110000
			mov h, a
			; h = x+dx in tiles
			mvi a, %11110000
			ana d
			; a = x in tiles
			cmp h
			jz @singleTile

@tileSizeW2H1:
			RRC_(4)
			ora l
			mov l, a
			mvi h, >room_tiledata

			mov e, m
			inx h
			mov d, m
			mov h, d
			mov l, e

			mov a, d
			ora e
			ret

@singleTile:
			RRC_(4)
			ora l
			mov l, a
			mvi h, >room_tiledata

			; all four corners in the same tile
			mov h, m
			mov l, h
			mov d, h
			mov e, h

			mov a, h
			ret

@sameTileCol:
			RRC_(4)
			ora l
			mov l, a
			mvi h, >room_tiledata

			mov e, m
			lxi b, ROOM_WIDTH
			dad b
			mov l, m
			mvi h, 0
			mov d, h

			mov a, e
			ora l
			ret

; Collects unique tile idxs that sprite corners stay on.
; If multiple sprite corners lie on the same tile,
; that tile's idx is stored only once.
; Max checking area 3x3 tiles.
; in:
;	de - sprite left-bottom pos_xy
; 	bc - sprite width, height
; out:
;   hl - points to the last element in room_get_tiledata_idxs

; used by room_tiledata_handling as an EOD marker
room_get_tiledata_idxs_eod:
			.byte TILE_IDX_INVALID
; contains up to 4 unique tile indices
room_get_tiledata_idxs:
			.byte 0,0,0,0

; v1. 2x2 tiles MAX only!
; 1x1: 41*4 = 164 cc
; 2x1: 47*4 = 188 cc
; 2x2: 59*4 = 236 cc

; v2. 3x3 tiles MAX, with 4 corners only!
; 1x1: 44 * 4 = 176 cc
; 2x1: (43 + 10) * 4 = 212 cc
; 1x2: (43 + 9 + 6) * 4 = 232 cc
; 2x2: (43 + 9 + 5 + 17) * 4 = 296 cc

; v3. universal
; 1x1: 212 + 13*4 = 264 cc
; 1x2: 332 cc
; 2x2: 404 cc

; v4. 3x3 max
; 1x1: 196 cc
; 1x2:  cc
; 2x1:  cc
; 2x2: 268 cc

; v5. 3x3 max
; 1x1:  cc
; 1x2:  cc
; 2x1:  cc
; 2x2: 232 cc, super fast, but spaghetti & agly &  :(

; v6. 3x3 max. to make it 4x4 increase the capacity of room_get_tiledata_idxs
; 1x1: 204 cc
; 1x2: 228 cc
; 2x1: 228 cc
; 2x2: 248 cc
; 2x3: 488 cc
; 3x3: 624 cc

; it's crazy, but I have to go back to the v1!
; Sprites are 16 pxls max. No reason for 3x3 checking
; area. Teleport's logic fails if the check area bigger
; than 2x2 tiles.
; v1. 2x2 tiles MAX only!
; 1x1: 41*4 = 164 cc
; 2x1: 47*4 = 188 cc
; 2x2: 59*4 = 236 cc
room_get_tiledata:
			; calc y in tiles
			mvi a, %11110000
			ana e
			mov l, a
			; l = y in tiles

			; calc y+dy in tiles
			mov a, e
			add c
			ani %11110000
			cmp l
			; if y = y+dy, do not top two corners
			jz @tileSizeH1

			; calc x+dx in tiles
			mov a, d
			add b
			ani %11110000
			mov h, a
			; h = x+dx in tiles
			mvi a, %11110000
			ana d
			; a = x in tiles
			cmp h
			jz @tileSizeW1H2

			RRC_(4)
			ora l
			; a - left-bottom corner

			; store tile_idxs
			lxi h, room_get_tiledata_idxs
			mov m, a
			inx h
			inr a
			mov m, a
			inx h
			adi ROOM_WIDTH-1
			mov m, a
			inx h
			inr a
			mov m, a
			; 23 * 4 cc
			ret

@tileSizeH1:
			; calc x+dx in tiles
			mov a, d
			add b
			ani %11110000
			mov h, a
			; h = x+dx in tiles
			mvi a, %11110000
			ana d
			; a = x in tiles
			cmp h
			jz @tileSizeW1H1

@tileSizeW2H1:
			RRC_(4)
			ora l
			; a - left-bottom corner

			; store tile_idxs
			lxi h, room_get_tiledata_idxs
			mov m, a
			inx h
			inr a
			mov m, a
			ret

@tileSizeW1H1:
			RRC_(4)
			ora l

			; store tile_idxs
			lxi h, room_get_tiledata_idxs
			mov m, a
			ret

@tileSizeW1H2:
			RRC_(4)
			ora l
			; a - left-bottom corner

			; store tile_idxs
			lxi h, room_get_tiledata_idxs
			mov m, a
			inx h
			adi ROOM_WIDTH
			mov m, a
			ret


; fill up the tile_data_buff with tiledata = 1
; (walkable tile, restore back, no decal)
; in:
; c - tiledata to fill
room_fill_tiledata:
			mov e, c
			lxi h, room_tiledata
			lxi b, room_tiledata_end
			call mem_fill
			ret


; a tiledata handler.
; tiledata should be in the format: ffffDDDD
;		ffff is a func_id of a func handler in the func_table
;		DDDD is a func argument
; call a handler func with func_id=ffff, A=DDDD, C=tile_idx
; in:
; de - pos_xy
.macro TILEDATA_HANDLING(width, height, actor_tile_func_table)
			lxi b, (width-1)<<8 | height - 1
			lxi h, actor_tile_func_table - JMP_4_LEN ; because we skip tiledata_func_id = 0
			call room_tiledata_handling
.endmacro

; in:
; de - pos_xy
; hl - actor_tile_func_table - JMP_4_LEN ; because we skip tiledata_func_id = 0
room_tiledata_handling:
			shld @actor_tile_func_table + 1
			; de - pos_xy
			call room_get_tiledata
			; hl - ptr to the last tile_idx in the array room_get_tiledata_idxs
@loop:
			mov a, m
			cpi TILE_IDX_INVALID
			rz

			mov c, a
			; c - tile_idx
			mvi b, >room_tiledata
			ldax b
			mov b, a
			; b - tiledata
			ani TILEDATA_FUNC_MASK
			; a - func_id
			jz @skip

			push h
			; store return addr
			lxi h, @funcReturnAddr
			push h
			; to make a jmp table ptr with a 4 byte allignment
			RRC_(2)
			mov l, a
			mvi h, 0
@actor_tile_func_table:
			lxi d, TEMP_ADDR
			dad d
			; b - tiledata
			mvi a, TILEDATA_ARG_MASK
			ana b
			pchl
@funcReturnAddr:
			pop h
@skip:
			dcx h
			jmp @loop
			ret