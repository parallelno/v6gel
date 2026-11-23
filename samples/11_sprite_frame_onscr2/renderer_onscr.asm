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
update_render_onscr:
                                      ; for 10 16x16 sprites:
            call swap_bands
            call update_bands         ;        ? cc
            call draw_bands           ;        ? cc
                                      ; total: ? cc ;
            ret

; v1. 1468 cc
; v2. 1320 cc
; v3. 712 cc
swap_bands:
            ; swap band_sprites_new & band_sprites_old
            lhld band_sprites_new
            xchg
            lhld band_sprites_old
            shld band_sprites_new
            shld band_sprite_tail
            shld band_sprites_old

            ; switch band_new_offset
            lxi h, band_new_offset
            inr m

            ; unroll mem_erase same way as jmp_tbl in mem_copy_to_ram_disk

            ; erase bands new
            ERASE_BUF_LEN = BAND_MAX * band.size
            lda band_new_offset
            rrc ; check the 0-bit
            jc @band_swapped
            lxi b, bands1 + ERASE_BUF_LEN
            jmp @clear_buffs
@band_swapped:
            lxi b, bands2 + ERASE_BUF_LEN
@clear_buffs
            lxi d, 0
            A_TO_ZERO(0)
            call mem_erase_sp
            ret


; v1. 12528 cc
; v2. 12572 cc
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
            RLC_(3)
            mov h, a
            ; h - top-half sprite band idx
            ; top band idx
            mov a, c
            add e
            dcr a ; find the last line scr_y
            ani b1110_0000
            RLC_(3)
            cmp h
            jnz @save_split_band_sprite
@save_unsplit_band_sprite:
            call init_band_sprite
            jmp @loop_check
@save_split_band_sprite:
            ; h - bottom-half sprite band idx
            ; a - top-half sprite band idx
			; b - width
            ; c - height
            ; de - scr addr
            ; (init_band_sprite_gfx + 1) - sprite gfx

            ; sprite bottom half handling
            ; adjust height
            push b
            push d
            RRC_(3)
            sta @top_band_height + 1
            ; a - height of a top-half sprite band
            sub e
            mov c, a
            mov a, h
            call init_band_sprite
            pop d
            pop b
@top_band_height:
            mvi h, TEMP_BYTE
            ; h - height of a top-half sprite band

            ; sprite top half handling
            ; adjust height
            mov a, e
            add c
            sub h
            ; a - height of a top half
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
; a - band_idx
; b - width
; c - height
; de - scr addr
; at (@sprite_gfx + 1) - sprite gfx
init_band_sprite:
            lhld band_sprite_tail
            push h
            ; hl - band sprite addr
            mov m, a
            HL_ADVANCE(band_sprite.band_idx, band_sprite.scr_addr_y)
            mov m, e
            HL_ADVANCE(band_sprite.scr_addr_y, band_sprite.scr_addr_x)
            mov m, d
            HL_ADVANCE(band_sprite.scr_addr_x, band_sprite.height)
            mov m, c
            HL_ADVANCE(band_sprite.height, band_sprite.width)
            mov m, b
            HL_ADVANCE(band_sprite.width, band_sprite.gfx_ptr)
init_band_sprite_gfx:
            lxi d, TEMP_ADDR
            mov m, e
            HL_ADVANCE(band_sprite.gfx_ptr, band_sprite.gfx_ptr + 1)
            mov m, d
            HL_ADVANCE(band_sprite.gfx_ptr + 1, band_sprite.band_idx + band_sprite.size)
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
            lxi h, update_bands_sprite_idx + 1
            mov l, m
            mvi h, 0
            dad h ; HL *=4,
            dad h ; because the band.size is 4 bytes
            lxi d, bands1
            lda band_new_offset
            rrc ; check the 0-bit
            jz @calc_band_ptr
            lxi d, bands2
@calc_band_ptr:
            dad d
            ; update band cost
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
draw_bands:
            lxi d, bands1
            lda band_new_offset
            rrc ; check the 0-bit
            jz @loop
            lxi d, bands2
@loop:      ; infinite loop over all bands
            ret



/*
            lxi b, 0
            ; infinite loop over all bands
@loop:
            ; check cost
            lhld band_costs_new
            dad b
            mov a, m
            CPI_ZERO(0)
            jz @check_loop

            mov e, a ; e - cost
            mov a, c
            RRC_(3)
            adi BAND_HEIGHT - 1 ; TODO: remove it if unnecessary
            ; a - height of the top line of the band
            add e
            mov e, a
            ; e - safe line. if the beam above, we good to render all band sprites
            ; TODO: logical error! we also need take into account the cost of
            ; erase.

            ; check the beam.
            call get_scr_rast_line
            ; a - aproximete currently rasterized line in a range of 0..255
            sub e
            jnc @skip_band

            push b

            lxi d, 0xA000
            lxi b, _knight + _knight_idle_0_0_relative
            ; BC = Sprite data, DE = Screen addr
;            call sprite_draw_vm

            pop b

@skip_band:
            ; band was skipped because of a beam intersection. requset a loop
            ; repeat.
            mvi a, 1
            sta @repeat_loop + 1
@check_loop:
            inr c
            mvi a, BAND_MAX
            cmp c
            jnz @loop

@repeat_loop:
            mvi a, TEMP_BYTE
            CPI_ZERO(0)
            mvi a, 0
            sta @repeat_loop + 1
            jnz @loop
            ret

; there is a problem . we can;t set the init_band_sprite_gfx to sp directly
; because interupt routine will corrupt 2 prior bytes
*/
            ret