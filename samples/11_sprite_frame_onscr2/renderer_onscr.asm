init_render:
            ; init band_sprites1 & band_sprites2
            lxi h, band_sprites1
            shld band_sprites_new
            lxi h, band_sprites2
            shld band_sprites_old

            ; init band_new_offset
            A_TO_ZERO(0)
            sta band_new_offset
            ret


; renders sprites to the back buffer, then copies them to the screen
; update_render_onscr total cc must be < than update_render_offscr (83128 cc)
update_render_onscr:
            call swap_bands
            call update_bands
            call draw_bands
            ret


; v1. 1468 cc
; v2. 1320 cc
; v3. 712 cc
; v4. 740 cc
swap_bands:
            A_TO_ZERO(0)
            sta band_sprites_count

            ; swap band_sprites_new & band_sprites_old
            lhld band_sprites_new
            xchg
            lhld band_sprites_old
            shld band_sprites_new
            shld band_sprite_tail
            xchg
            shld band_sprites_old

            ; switch band_new_offset
            lxi h, band_new_offset
            inr m

            ; erase bands new
            ERASE_BUF_LEN = BAND_MAX * band.size
            mov a, m
            rrc ; check the 0-bit
            lxi b, bands1 + ERASE_BUF_LEN
            jnc @clear_buffs
            lxi b, bands2 + ERASE_BUF_LEN
@clear_buffs:
            lxi d, 0 ; counter (len//32 - 1)
            A_TO_ZERO(0)
            call mem_erase_sp
            ret


; v1. 12528 cc
; v2. 12572 cc
; v3. 12932 cc
update_bands:
            ; init the loop
            A_TO_ZERO(0)
            sta update_bands_sprite_idx + 1
            lxi h, sprites
            ; loop over every sprite
update_bands_loop:
            ; get sprite scr_addr, frame_ptr
            mov e, m
            HL_ADVANCE(sprites.scr_addr_y, sprites.scr_addr_x)
            mov d, m
            HL_ADVANCE(sprites.scr_addr_x, sprites.frame_ptr)
            mov c, m
            HL_ADVANCE(sprites.frame_ptr, sprites.frame_ptr + 1)
            mov b, m
            HL_ADVANCE(sprites.frame_ptr + 1, sprites + sprites.size)

            push h

            ; de - scr_addr
            ; bc - frame_ptr
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
            xchg
            lxi h, 0
            dad sp
@restore_sp:
            lxi sp, TEMP_ADDR
			; b - width
            ; c - height
            ; de - scr addr
            ; hl - sprite gfx
            shld init_band_sprite_gfx + 1

            ; find intersecting bands
            ; bottom-half sprite band idx
            mvi a, b1110_0000
            ana e
            mov h, a
            ; h - top-half sprite band_y

            ; calc the top-half band_y
            mov a, c
            add e
            dcr a ; find the last line scr_y
            ani b1110_0000
            cmp h
            jnz @save_split_band_sprite
@save_unsplit_band_sprite:
            call init_band_sprite
            jmp @loop_check
@save_split_band_sprite:
            ; h - bottom-half sprite band_y
            ; a - top-half sprite band_y
			; b - width
            ; c - height
            ; de - scr addr
            ; (init_band_sprite_gfx + 1) - sprite gfx

            ; sprite bottom-half handling
            ; adjust height
            push b
            push d
            sta @top_band_height + 1
            ; a - height of a top-half sprite band
            sub e
            mov c, a
            call init_band_sprite
            pop d
            pop b
@top_band_height:
            mvi h, TEMP_BYTE
            ; h - top-half sprite band_y

            ; sprite top half handling
            ; adjust height
            mov a, e
            add c
            sub h
            ; a - height of a top-half sprite
            mov c, a
            ; adjust scr_y
            mov e, h
            call init_band_sprite

@loop_check:
            pop h
update_bands_sprite_idx:
            mvi a, TEMP_BYTE
            inr a
            sta update_bands_sprite_idx + 1
            cpi SPR_MAX
            jnz update_bands_loop
            ret


; init band_sprite
; in:
; b - width
; c - height
; de - scr addr
; at (@sprite_gfx + 1) - sprite gfx
init_band_sprite:
            ; update the total sprite_count
            lxi h, band_sprites_count
            inr m

            lhld band_sprite_tail
            push h
            ; hl - band sprite addr
            mov m, e
            HL_ADVANCE(band_sprite.scr_addr, band_sprite.scr_addr + 1)
            mov m, d
            HL_ADVANCE(band_sprite.scr_addr + 1, band_sprite.height)
            mov m, c
            HL_ADVANCE(band_sprite.height, band_sprite.width)
            mov m, b
            HL_ADVANCE(band_sprite.width, band_sprite.gfx_ptr)
init_band_sprite_gfx:
            lxi d, TEMP_ADDR
            mov m, e
            HL_ADVANCE(band_sprite.gfx_ptr, band_sprite.gfx_ptr + 1)
            mov m, d
            HL_ADVANCE(band_sprite.gfx_ptr + 1, band_sprite.size)
            shld band_sprite_tail

            ; calc and store a render cost
            ; sprite render cost = height * w
            mov a, c
            dcr b
            jm @save_cost   ; cost x1 ; width8
            add a           ; cost x2 ; width16
            dcr b
			jm @save_cost
            add c           ; cost x3 ; width24
@save_cost:
            ; a - render cost
            mov c, a ; tmp cost

            lda update_bands_sprite_idx + 1
            add a ; sprite_idx * 4
            add a ; because the band.size is 4 bytes
            mov l, a
            mvi h, 0

            ; TODO: instead of band_new_offset use bands1/bands2 swap
            lda band_new_offset
            rrc ; check the 0-bit
            lxi d, bands1
            jnc @calc_band_ptr
            lxi d, bands2
@calc_band_ptr:
            dad d
            ; update band cost
            ; TODO: check if clamp is necessary or should be adjusted
            ; clamp to 255
            mov a, m
            add c
            mov m, a
            jnc @save_count
            mvi m, 255 ; clamp to max

            ; update the band count
@save_count:
            HL_ADVANCE(band.cost, band.count)
            inr m

            ; update the band first sprite
            HL_ADVANCE(band.count, band.sprite)
            pop b
            ; b - ptr to current band_sprite
            ; check if a band first sprite already inited
            A_TO_ZERO(0)
            ora m
            HL_ADVANCE(band.sprite, band.sprite + 1)
            ora m
            rnz
            mov m, b
            HL_ADVANCE(band.sprite + 1, band.sprite)
            mov m, c
            ret


; erase old sprites, draw new sprites.
; v1. 7996 cc
draw_bands:
            lxi h, bands2
            lxi d, bands1
            lda band_new_offset
            rrc ; check the 0-bit
            jnc @main_loop
            xchg

@main_loop:
            ; de - bands new
            ; hl - bands old
            A_TO_ZERO(0)
            sta @band_y + 1
@loop:      ; infinite loop over all bands

            push h
            push d

            ; get new+old cost
            mov a, m
            xchg
            add m
            mov b, a
            ; b - new+old cost
            ; go next if a band is empty
            jz @next_beam

            ; if a beam is below a band_y, we good to render
            push h
            lxi h, @band_y + 1
            mov l, m
            mvi h, >scr_y_to_crt_line
            mov c, m
            ; c - band scr_y remaped to the timer range [30, 221]
            call get_crt_line
            ; scr lines are in reverse
            ; if scr_y=255, crt_line 30
            ; if scr_y=0, crt_line 221
            ; a - current crt_line
            ; c - band height mapped to crt_line range
            cmp c
            pop h
            jnc @render_beam

            ; check if a beam is above a band height + new+old cost
            ; b - new+old cost
            add b
            cmp c
            jc @next_beam

@render_beam:
            ; de - bands new
            ; hl - bands old

/*
            ; erase old sprites
            push h
            push d

            HL_ADVANCE(band.cost, band.count)
            mov a, m
            HL_ADVANCE(band.count, band.sprite)
            mov e, m
            HL_ADVANCE(band.sprite, band.sprite + 1)
            mov d, m
            ; a - sprite count
            ; de - first sprite ptr
            call erase_band_sprites
            pop d
            pop h
*/

            ; erase costs to mark the beam rendered
            A_TO_ZERO(0)
            mov m, a
            stax d

            ; increase the all beams sprite total counter
            lxi h, band_sprites_count
            dcr m
            jz @exit

@next_beam:
            LXI_B_TO_DIFF(band.cost, band.size)
            ; advance old and new band ptrs
            pop h
            dad b
            xchg
            ; advance new band ptr to next
            pop h
            dad b

            ; check band end
@band_y:
            mvi a, TEMP_BYTE ; band_y
            adi BAND_HEIGHT
            sta @band_y + 1
            jnz @loop
            jmp @main_loop

@exit:
            ; clean up the stack
            pop h
            pop h
            ret
band_y: = @band_y


; erase old sprites in the band
; in:
; a - sprite count
; de - first sprite ptr
erase_band_sprites:
            sta @loop_check + 1
            xchg
@loop:
            ; read the beam sprite data
            mov e, m
            HL_ADVANCE(band_sprite.scr_addr, band_sprite.scr_addr + 1)
            mov d, m
            HL_ADVANCE(band_sprite.scr_addr + 1, band_sprite.height)
            mov c, m
            HL_ADVANCE(band_sprite.height, band_sprite.width)
            push h
            mov h, m
            mov l, a

            ; de - scr addr
            ; h - width
            ; l - height
            call sprite_copy_to_back_buff_v

            pop h

            ; check remaining sprites

            ; advance to next sprite
            HL_ADVANCE(band_sprite.width, band_sprite.size)

@loop_check:
            mvi a, TEMP_BYTE
            dcr a
            sta @loop_check + 1
            jnz @loop

            ret
