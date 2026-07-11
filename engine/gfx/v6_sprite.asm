@memusage_v6_sprite:
; get a sprite data addr
; in:
; hl - anim_ptr
; c - preshifted sprite idx*2 offset based on pos_x then +2
; out:
; bc - ptr to a sprite
sprite_get_addr:
			mvi b, 0
			dad b
			mov c, m
			inx h
			mov b, m
			ret

; getting scr addr of sprites preshifted for each pixel
; in:
; hl - ptr to pos_x + 1 (high byte in 16-bit pos)
; out:
; de - sprite screen addr
; c - preshifted sprite idx*2 offset based on pos_x then +2
; hl - ptr to pos_y + 1
; use: a
sprite_get_scr_addr8:
			; calc preshifted sprite idx*2 offset
			mov	a, m
			ani SPRITES_PRESHIFTED_8 - 1 ; %0000_0111
			rlc
			adi 2 ; because there are two bytes of next_frame_offset in front of sprite ptrs
			mov	c, a
			; calc screen addr X
			mov	a, m
			RRC_(3)
			ani %00011111
			adi SPRITE_X_SCR_ADDR
			INX_H(2)
			mov e, m
			mov	d, a
			; de - sprite screen addr
			ret

; getting scr addr of sprites preshifted for each second pixel
; in:
; hl - ptr to pos_x + 1 (high byte in 16-bit pos)
; out:
; de - sprite screen addr
; c - preshifted sprite idx*2 offset based on pos_x then +2
; hl - ptr to pos_y + 1
; use: a
sprite_get_scr_addr4:
			; calc preshifted sprite idx*2 offset
			mov	a, m
			ani (SPRITES_PRESHIFTED_4 - 1) * 2 ; %0000_0110
			adi 2 ; because there are two bytes of next_frame_offset in front of sprite ptrs
			mov	c, a
			; calc screen addr X
			mov	a, m
			RRC_(3)
			ani %00011111
			adi SPRITE_X_SCR_ADDR
			INX_H(2)
			mov e, m
			mov	d, a
			; de - sprite screen addr
			ret

; getting scr addr of non-preshifted sprites. alligned by 8 pixels horizontally
; in:
; hl - ptr to pos_x + 1 (high byte in 16-bit pos)
; out:
; de - sprite screen addr
; c - preshifted sprite idx*2 offset based on pos_x then +2
; hl - ptr to pos_y + 1
; use: a
sprite_get_scr_addr1:
			; calc preshifted sprite idx*2 offset
			mvi	c, 2
			; calc screen addr X
			mov	a, m
			RRC_(3)
			ani %00011111
			adi SPRITE_X_SCR_ADDR
			INX_H(2)
			mov e, m
			mov	d, a
			; de - sprite screen addr
			ret

; converts a scr addr to pos_xy
; bc - scr addr (ex. $8222)
; out:
; bc - scr pos
sprite_scr_addr_to_pos:
			mvi a, ~SCR_ADDR_MASK
			ana b
			RLC_(3)
			mov b, a
			ret

; initializes the sprite meta data including the RAM Disk access,
; a propriate sprite_get_scr_addr func addr, animation (frame ptrs)
; in:
; hl - points to the list where each element contains:
; .word {{asset_name}_ram_disk_cmd}
; .byte RAM_DISK_S_{asset_name}
; .word {sprite_gfx_addr}
; e - the number of elements in the list
sprite_uninit_meta_data:
			mvi a, OPCODE_JMP
			jmp @store_opcode
@sprite_init_meta_data:
			mvi a, OPCODE_LXI_B
@store_opcode:
			sta @check_if_uninit
@loop:
			push d

			; get the meta_data addr
			mov e, m
			inx h
			mov d, m
			inx h

			; get the RAM Disk S cmd
			mov a, m
			inx h

			; store the RAM Disk S cmd in the meta data
			xchg
			mov m, a
			; advance hl to the preshifted_sprites addr
			inx h
			push h ; temporally store the pointer to the preshifted_sprites addr
			xchg

			; get the sprite gfx addr
@check_if_uninit:
			jmp @uninit
@init:		; read sprite gfx addr as it is
			mov e, m
			inx h
			mov d, m
			jmp @cont
@uninit:
			; read sprite gfx addr make it negative
			; to set the anim ptrs back to local
			mov a, m
			cma
			mov e, a
			inx h
			mov a, m
			cma
			mov d, a
			inx d
@cont:
			inx h

			xthl
			xchg

			; hl - sprite gfx addr (_hero_l_sprites)
			; de - preshifted_sprites ptrs i.e. _hero_l_preshifted_sprites
			call sprite_update_labels
			pop h
			pop d
			dcr e
			jnz @loop
			ret
sprite_init_meta_data: = @sprite_init_meta_data

; updates sprite label addrs
; in:
; de - preshifted_sprites ptrs i.e. _hero_l_preshifted_sprites
; hl - sprite gfx addr (_hero_l_sprites)
sprite_update_labels:
			shld @gfx_addr + 1
			xchg
			; hl - _hero_l_preshifted_sprites
			mov a, m
			sta @preshifted_sprites + 1
			inx h
			; read the anim ptr
@next_anim:
			mov e, m
			inx h
			mov d, m
			inx h
			; check if all anims are updated
			mov a, d
			ora e
			rz
			; de - anim ptr
			push h
			xchg
			; hl - anim ptr
			call @update_frame_labels
			pop h
			jmp @next_anim
			ret

; in:
; hl - anim ptr
@update_frame_labels:
			; check if it's the last frame (offset to the next frame < 0)

			inx h
			mov a, m
			push psw
			inx h
			; hl - ptr to array of frame ptrs
			; the len of array = @preshifted_sprites
@preshifted_sprites:
			mvi c, TEMP_BYTE
@gfx_addr:
			lxi d, TEMP_ADDR
			; hl - points to the array of ptrs to the data
			; de - the data addr
			; c - the len of the array
			call add_offset_to_labels_len
			pop psw
			; if a < 0, we updated the last frame in the animation
			ora a
			jp @update_frame_labels
			ret