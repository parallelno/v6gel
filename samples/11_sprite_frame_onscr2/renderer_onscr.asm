; renders sprites to the back buffer, then copies them to the screen
renderer_onscr:
                                      ; for 10 16x16 sprites:
            call init_bands
            call update_bands         ;        ? cc
            call draw_bands           ;        ? cc
                                      ; total: ? cc ;
            ret


init_bands:
            lxi h, band_sprites_new
            shld last_band_sprite_new_ptr
            lxi h, band_sprites_old
            shld vacant_band_sprite_old_ptr
            call swap_band_sprite_lists
            ret


update_bands:
            ; loop through every sprite
            mvi c, SPR_MAX
            lxi h, sprites
@loop:
            push b

            ; get sprite scr_addr, frame_ptr
            mov c, m
            HL_ADVANCE(sprites.scr_addr_y, sprites.scr_addr_x)
            mov b, m
            HL_ADVANCE(sprites.scr_addr_x, sprites.frame_ptr)
            mov e, m
            HL_ADVANCE(sprites.frame_ptr, sprites.frame_ptr + 1)
            mov d, m
            HL_ADVANCE(sprites.frame_ptr + 1, sprites + sprites.size)

            push h

            ; bc - scr_addr
            ; de - frame_ptr
            ; get frame offset_y, offset_x, h, w and compute final scr addr.

            ; store SP
			lxi h, 0
			dad sp
			shld @restore_sp + 1
			; sp = BC
			mov	h, b
			mov	l, c
			sphl
			xchg
			pop b
			; b - offset_x
			; c - offset_y
			dad b
			; hl - sprite screen addr

			; read sprite width and height
			pop b
			mov a, b
			; b, a - width
			; c - height
            ; hl - frame scr addr
            ; sp - sprite gfx
			dcr a
			jz @width16
			jp @width24
            ; width8
            lxi d, sprite_draw_vm_width8
            jmp @save_draw_func
@width16:
            lxi d, sprite_draw_vm_width16
            jmp @save_draw_func
@width24:
            lxi d, sprite_draw_vm_width24
@save_draw_func:
            shld @draw_func + 1
            xchg
            lxi h, 0
            dad sp
@restore_sp:
            lxi sp, TEMP_ADDR
			; b - width
            ; c - height
            ; de - frame scr addr
            ; hl - sprite gfx



            ; - find intersecting bands
            ; - store split scr_addr, w/h, adjusted graphics addr, draw func ptr, into band sprite list

            pop h
            pop b

            ret

draw_bands:
            ; - loop through every sprite
            ;
            ret


; swaps new_sprites and old_sprites ptrs of every bound
; uses:
; a, bc, de, hl
swap_band_sprite_lists:
            lxi h, bands.new_sprites
            lxi d, bands.old_sprites
            mvi b, BAND_MAX
@loop:
            ; --- lo byte swap (HL = new, DE = old) ---
            mov c, m
            ldax d
            xchg
            ; HL = old, DE = new
            stax d
            mov m, c
            inx h
            inx d

            ; --- hi byte swap (HL = old, DE = new) ---
            mov c, m
            ldax d
            xchg
            ; HL = new, DE = old
            stax d
            mov m, c
            ; The next step is 3 bytes for both ptrs, and the old is 2 bytes
            ; ahead of new. So we can advance DE by one byte, then copy DL to HL.
            inx d
            mov l, e
            mov h, d
            inx d
            inx d

@loop_check:
            dcr b
            jnz @loop
            ret