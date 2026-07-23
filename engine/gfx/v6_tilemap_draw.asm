@memusage_v6_tile_draw:

.global room_unpack
.global room_init_tiles_gfx
.global room_draw_tiles
.global room_draw_tiles_ex


; uncompress the room data (graphics tile indeces and the room tiledata)
; destination_addr = room_tiles_gfx_ptrs + offset
; offset = (size of room_tiles_gfx_ptrs buffer) / 2
; after uncompression:
; * the room tile_idxs occupies the second half of the room_tiles_gfx_ptrs
; * the room tiledata occupies the room_tiledata

; we keep room tile_idxs in the second half to further convert into the
; tile gfx ptrs.

; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; !!! TODO: Check if it is correct statement. I think it is only tile gfx must be on in THE RAM DISK $8000-$FFFF SEGMENT
; !!! ROOT DATA (tile idxs and the tiledata) MUST BE LOADED !!!
; !!!         INTO THE RAM DISK $8000-$FFFF SEGMENT         !!!
; !!!   BECAUSE IT'S ACCESSED VIA THE NON_STACK OPERATIONS  !!!
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

; packed room data has to be stored into $8000-$FFFF segment to be properly unzipped
.opt
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
.endopt




; convert room gfx tile_idxs into room gfx tile ptrs
.opt
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
.endopt


;=========================================================
; draw a room tiles. It might be a main screen, or a back buffer
.opt
room_draw_tiles:
			mvi a, ROOM_HEIGHT * TILE_HEIGHT
; in:
; a - tile pos_y to stop drawing
room_draw_tiles_ex:
			sta @last_tile_id + 1

			lda lv_ram_disk_s_gfx
			RAM_DISK_ON_BANK()

			; set y = 0
			mvi e, 0
			; set a pointer to the first item in the list of addrs of tile graphics
			lxi h, room_tiles_gfx_ptrs
@new_line:
			; reset the x. it's a high byte of the first screen buffer addr
			mvi d, >SCR_BUFF0_ADDR
@loop:
			; DE - screen addr
			; HL - tile graphics addr
			mov c, m
			inx h
			mov b, m
			inx h
			push d
			push h
			call draw_tile_16x16
			pop h
			pop d

			; x += 2
			INR_D(2)
			; repeat if x reaches the high byte of the second screen buffer addr
			mvi a, >SCR_BUFF1_ADDR
			cmp d
			jnz @loop

			; move pos_y up to the next tile line
			mvi a, TILE_HEIGHT
			add e
			mov e, a
@last_tile_id:
			cpi TEMP_BYTE
			jc @new_line
			RAM_DISK_OFF()
			ret
.endopt