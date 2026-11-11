; renders sprites to the back buffer, then copies them to the screen
renderer_onscr:
            call init_spg_sprite_masks
            call update_spatial_grid
            ret


init_spg_sprite_masks:
            lxi h, sprites_onscr.spg_sprite_mask
            mvi a, SPR_MAX
            lxi d, 1 ; initial sprite mask
@loop:
            ; store the 2-byte mask
            mov m, e
            HL_ADVANCE(sprites_onscr.spg_sprite_mask, sprites_onscr.spg_sprite_mask + 1)
            mov m, d
            HL_ADVANCE(sprites_onscr.spg_sprite_mask + 1, sprites_onscr.spg_sprite_mask + sprites_onscr.size, BY_BC)

            ; shift the mask
            xchg
            dad h
            xchg
            ; decrement, check the counter
            dcr a
            jnz @loop
            ret


update_spatial_grid:
            lxi h, sprites_onscr.scr_y
            mvi a, SPR_MAX
            sta @sprite_counter + 1
@loop:
            ; read sprite scr addr
            mov e, m
            HL_ADVANCE(sprites_onscr.scr_y, sprites_onscr.scr_x)
            mov d, m
            HL_ADVANCE(sprites_onscr.scr_x, sprites_onscr.height)
            mov c, m
            HL_ADVANCE(sprites_onscr.height, sprites_onscr.width)
            mov b, m
            HL_ADVANCE(sprites_onscr.width, sprites_onscr.spg_sprite_mask)
            mov a, m
            HL_ADVANCE(sprites_onscr.width, sprites_onscr + sprites_onscr.size)
            push h

            mov h, b
            mov l, c

            call update_occupied_spg_cells
            call

            pop h
@sprite_counter:
            mvi a, TEMP_BYTE
            dcr a
            sta @sprite_counter + 1
            jnz @loop
            ret


; update grid cells occupied by a sprite
; in:
; de - scr addr
; h - width
;		00 - 8pxs,
;		01 - 16pxs,
;		10 - 24pxs,
; l - height
; a - sprite mask (1 bit per sprite)
; out:
; a - cumulative_cell_sprite_mask
update_occupied_spg_cells:
            sta @sprite_mask + 1

			; convert scr addr to room_tiles_gfx_ptrs offset
			mvi a, %00011110
			ana d
			rrc
			mov b, a
			mvi a, %11110000
			ana e
			mov c, a
			; b = x in tiles
			; c, a = y in tiles * 16

			; get scr addr of a top-left corner
            dad d

			; check bottom-left corner
			ora b
            mov e, a

			; get x+dx in tiles
			mvi a, %00011110
			ana h
			rrc
			mov h, a
			; h, a = x+dx in tiles

			; check bottom-right corner
			ora c
			mov d, a

			; get y+dy in tiles
			dcr l ; to be inside the AABB
			mvi a, %11110000
			ana l
			mov l, a
			; l, a = y+dy in tiles

			; check top-right corner
			ora h
            mov c, a

			; check top-left corner
			mov a, b
			ora l
			; a - top-left corner tile idx
            ; c - top-right corner tile idx
            ; d - bottom-right corner tile idx
            ; e - bottom-left corner tile idx

            ; update the cell occupied by a top-left sprite corner
            HL_TO_AX2_PLUS_INT16(spatial_grid)
            mov a, m
@sprite_mask:
            ori TEMP_BYTE
            mov m, a

            ; update the cell occupied by the top-right sprite corner
            mov l, c
            mvi h, 0
            lxi b, spatial_grid
            dad h ; double the offset because a cell size is 2 bytes
            dad b
            ; hl - spatial_grid cell addr occupied by the top-right corner of a sprite
            ; bc - spatial_grid
            ora m
            mov m, a

            ; update the cell occupied by the bottom-left sprite corner
            mov l, e
            mvi h, 0
            dad h ; double the offset because a cell size is 2 bytes
            dad b
            ; hl - spatial_grid cell addr occupied by the bottom-left corner of a sprite
            ; bc - spatial_grid
            ora m
            mov m, a

            ; update the cell occupied by the bottom-right sprite corner
            mov l, d
            mvi h, 0
            dad h ; double the offset because a cell size is 2 bytes
            dad b
            ; hl - spatial_grid cell addr occupied by the bottom-right corner of a sprite
            ; bc - spatial_grid
            ora m
            mov m, a
            ; a - cumulative_cell_sprite_mask
			ret
