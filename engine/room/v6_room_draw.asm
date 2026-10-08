@memusage_room_draw:
;=========================================================
; redraws the room after dialog shown
; it uses data inited in the room_draw
ROOM_TILEDATA_HANDLING_ALL			= OPCODE_JMP
ROOM_TILEDATA_HANDLING_NO_CHARS	= OPCODE_JNZ
ROOM_DIALOG_TILE_HEIGHT = 4
room_redraw:
			call backs_init
			mvi c, ROOM_WIDTH * ROOM_DIALOG_TILE_HEIGHT
			call restore_doors_containers_tiledata_ex
			mvi a, ROOM_DIALOG_TILE_HEIGHT * TILE_HEIGHT
			call room_draw_tiles_ex

			mvi a, ROOM_TILEDATA_HANDLING_NO_CHARS
			sta room_handle_room_tiledata_check
			mvi a, ROOM_WIDTH * ROOM_DIALOG_TILE_HEIGHT
			call room_handle_room_tiledata_ex
			mvi a, ROOM_TILEDATA_HANDLING_ALL
			sta room_handle_room_tiledata_check
			ret

room_copy_scr_to_backbuffs:
			; copy $a000-$ffff scr buffs to the RAM Disk back buffer
			lxi d, SCR_BUFF1_ADDR
			lxi h, 0; SCR_BUFF1_ADDR + SCR_BUFF_LEN * 3
			lxi b, SCR_BUFF_LEN * 3
			mvi a, RAM_DISK_S_BACKBUFF
			call mem_copy_to_ram_disk

			; copy $a000-$ffff scr buffs to the RAM Disk back buffer2 (to restore the background in the back buffer)
			lxi d, SCR_BUFF1_ADDR
			lxi h, 0; SCR_BUFF1_ADDR + SCR_BUFF_LEN * 3
			lxi b, SCR_BUFF_LEN * 3
			mvi a, RAM_DISK_S_BACKBUFF2
			call mem_copy_to_ram_disk
			ret

;=========================================================
; draw a decal onto the screen, and backbuffers
; requires: store entity_id*2 into room_decal_draw_ptr_offset + 1 addr prior to calling this
; in:
; c - tile_idx in the room_tiledata array.
; use:
; hl - ptr to the graphics, ex. _doors_gfx_ptrs
; backbuffers = true means draw onto backbuffers as well
.macro ROOM_DECAL_DRAW(gfx_ptrs, backbuffers = false, _jmp = false)
			lxi h, gfx_ptrs
		.if backbuffers
			A_TO_ZERO(OPCODE_NOP)
			sta room_decal_draw_backbuffers
		.endif
		.if backbuffers == false
			mvi a, OPCODE_RET
			sta room_decal_draw_backbuffers
		.endif
		.if _jmp == false
			call room_decal_draw
		.endif
		.if _jmp
			jmp room_decal_draw
		.endif
.endmacro

; draw a decal onto the screen, and backbuffers
; ex. ROOM_DECAL_DRAW(containers_gfx_ptrs, true)
; requires: store item_id*2 into room_decal_draw_ptr_offset + 1 addr prior calling this
; in:
; hl - ptr to the graphics, ex. _doors_gfx_ptrs
; c - tile_idx in the room_tiledata array.
room_decal_draw:
			; scr_y = tile_idx % ROOM_WIDTH
			mvi a, %11110000
			ana c
			mov e, a
			; c - tile_idx
			; scr_x = tile_idx % ROOM_WIDTH * TILE_WIDTH_B + SCR_ADDR
			mvi a, %00001111
			ana c
			rlc
			adi >SCR_ADDR
			mov d, a
			; de - scr addr
			push d

; requires: store item_id*2 into room_decal_draw_ptr_offset + 1 addr prior to calling this
room_decal_draw_ptr_offset:
			lxi d, TEMP_WORD
			dad d

			; hl - pptr to a sprite
			; get ptr to sprite
			mov c, m
			inx h
			mov b, m

			pop d
			; bc - sprite addr
			; de - scr addr
			push b
			push d
			CALL_RAM_DISK_FUNC(draw_decal_v, <PERMANENT_DECALS0_RAM_DISK_S)
			pop d
			pop b
room_decal_draw_backbuffers:
			ret		; mutable. do not change

			push b
			push d
			CALL_RAM_DISK_FUNC(draw_decal_v, <PERMANENT_DECALS0_RAM_DISK_S | RAM_DISK_M_BACKBUFF | RAM_DISK_M_AF)
			pop d
			pop b
			CALL_RAM_DISK_FUNC(draw_decal_v, <PERMANENT_DECALS0_RAM_DISK_S | RAM_DISK_M_BACKBUFF2 | RAM_DISK_M_AF)
			ret

;=========================================================
; draw a room tiles. It might be a main screen, or a back buffer
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
