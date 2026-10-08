.include "room/v6_room_draw.asm"
.include "room/v6_room_tiledata_spawn.asm"
.include "room/v6_room_tiledata.asm"
@memusage_room:

;=======================================================

room_init:
			call chars_init
			call overlays_init
			call backs_init
			call room_unpack
			call room_backup_tiledata
			call breakables_room_status_init
			call room_init_tiles_gfx
			call room_draw_tiles
			call room_handle_room_tiledata
			; TODO: optimization. do not copy UI panel
			call room_copy_scr_to_backbuffs
			jmp room_init_statuses

; must be called for teleporting into the other room
; h - level_id
; l - room_id
; a - global request
room_teleport:
			sta app_request
			push h
			call breakables_room_status_store
			pop h
			; store it after call breakables_room_status_store
			shld room_id
			ret

; restores game statuses
room_init_statuses:
			lda game_status_fart
			CPI_ZERO()
			cnz fart_init
			ret


; uncompress the room data (graphics tile indeces and the room tiledata)
; destination_addr = room_tiles_gfx_ptrs + offset
; offset = (size of room_tiles_gfx_ptrs buffer) / 2
; after uncompression:
; * the room tile_idxs occupies the second half of the room_tiles_gfx_ptrs
; * the room tiledata occupies the room_tiledata

; we keep room tile_idxs in the second half to further convert into the
; tile gfx ptrs.

; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; !!! ROOT DATA (tile idxs and the tiledata) MUST BE LOADED !!!
; !!!         INTO THE RAM DISK $8000-$FFFF SEGMENT         !!!
; !!!   BECAUSE IT'S ACCESSED VIA THE NON_STACK OPERATIONS  !!!
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

; packed room data has to be stored into $8000-$FFFF segment to be properly unzipped
room_unpack:
			lhld lv_rooms_pptr
			; convert a room_id into the addr of the room data (gfx tile idxs & tiledata)
			; like _lv0_home or _lv0_farm_fence, etc
			lda room_id
			; double the room idx to get an addr offset in the _lv0_rooms_ptrs array
			rlc
			mov c, a
			mvi b, 0
			dad b

			; load a pointer to the room data
			mov e, m
			inx h
			mov d, m

			push d ; store the room data addr

			; get the compressed room data addr
			lxi h, ADDR_LEN + SAFE_WORD_LEN ; 2 bytes of compressed room data len + 2 safety bytes
			dad d
			xchg
			; de - ptr to the compressed room data

			; copy the room data into the room_tiles_gfx_ptrs + offset
			; offset = ROOM_TILES_GFX_PTRS_LEN / 2
			lxi b, room_tiles_gfx_ptrs + ROOM_TILES_GFX_PTRS_LEN / 2
			lda lv_ram_disk_m_data
			ori RAM_DISK_M_8F
			CALL_RAM_DISK_FUNC_BANK(dzx0)

			; copy the teleport data from the RAM Disk
			; restore the room data addr
			pop d

			; get the compressed room data len
			lda lv_ram_disk_m_data
			ori RAM_DISK_M_8F
			call get_word_from_scr_ram_disk
			; hl - ptr to the room data + 1
			; bc - compressed room data len
			; get the addr of room_teleports_data in a RAM Disk
			dad b
			; 2 bytes of compressed room data len + 2 safety bytes minus 1
			; because get_word_from_scr_ram_disk returns room data + 1
			; plus 2 safety bytes before the teleport data
			lxi b, ADDR_LEN + SAFE_WORD_LEN - 1 + SAFE_WORD_LEN
			dad b
			; hl - ptr to the room_teleports_data
			lxi d, room_teleports_data
			lxi b, TELEPORT_IDS_MAX
			lda lv_ram_disk_m_data
			ori RAM_DISK_M_8F
			call mem_copy_from_ram_disk
			ret



; copies door and containr tiledata from room_tiledata_backup
; back into room_tiledata
restore_doors_containers_tiledata:
			mvi c, ROOM_TILEDATA_LEN
restore_doors_containers_tiledata_ex:
			lxi h, room_tiledata_backup
			mvi b, TILEDATA_FUNC_MASK
			lxi d, (TILEDATA_FUNC_ID_DOORS<<4)<<8 | TILEDATA_FUNC_ID_CONTAINERS<<4
@loop:
			mov a, m
			ana b
			cmp e
			jz @copy_tiledata
			cmp d
			jnz @next
@copy_tiledata:
			mov a, m
			mvi h, >room_tiledata
			mov m, a
			mvi h, >room_tiledata_backup
@next:
			inx h
			dcr c
			jnz @loop
			ret

; convert room gfx tile_idxs into room gfx tile ptrs
room_init_tiles_gfx:
			lhld lv_tiles_pptr
			shld @gfx_tiles_ptrs + 1

			lxi h, room_tiles_gfx_ptrs + ROOM_TILES_GFX_PTRS_LEN / 2
			lxi d, room_tiles_gfx_ptrs
			mvi a, ROOM_WIDTH * ROOM_HEIGHT
			; hl - current room gfx tile_idxs
			; de - current room gfx tile ptrs
			; a - counter
@loop:
			; bc gets the tile idx
			push psw
			mov c, m
			mvi b, 0
			inx h
			push h
			; convert the tile gfx idx into the tile gfx ptr
@gfx_tiles_ptrs:
			lxi h, TEMP_WORD
			dad b
			dad b ; second addition becasue the tile gfx ptr is 2 bytes long
			; hl - points to the tile gfx ptr

			; read the tile gfx ptr
			mov c, m
			inx h
			mov b, m
			; bc - current room current tile gfx ptrs
			; store it into the room gfx ptrs table
			xchg
			mov m, c
			inx h
			mov m, b
			inx h
			xchg
			pop h
			pop psw
			dcr a
			jnz @loop
			ret

; checks if the actor collides with the room border
; in:
; hl - ptr to actor_pos_x + 1
; d - collision width
; e - collision height
; out:
; CY is set if collides
room_check_border:
			; check the right side
			mvi a, (ROOM_WIDTH - 1 ) * TILE_WIDTH
			sub d
			cmp m
			jc @collides_horiz
			; check the left side
			mov a, m
			cpi TILE_WIDTH
			jc @collides_horiz
			; check the top side
			HL_ADVANCE(char_pos_x + 1, char_pos_y + 1)
			mvi a, (ROOM_HEIGHT - 1) * TILE_HEIGHT
			sub e
			cmp m
			rc
			; check the bottom side
			mov a, m
			cpi TILE_HEIGHT
			rc
			; no collision
			ret
@collides_horiz:
			HL_ADVANCE(char_pos_x + 1, char_pos_y + 1)
			stc
			ret