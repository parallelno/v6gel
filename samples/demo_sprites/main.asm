; Demo: Initialize palette and play demo music
; This module prepares the system palette, unpacks and starts a
; packed song, and continuously requests palette updates so the
; engine can animate colors on each interrupt.


; Expose the `main` label to make it reachable by linker.
; Engine calls it after initialization.
.global main

.include "../../engine/controls/v6_controls_consts.asm"
.include "../../engine/common/v6_consts.asm"

; Include the palette meta data (supplied to the engine color update routine)
; It contains relative labels to the sub-data (palette, fade animation)
.include "build/demo_sprites/palettes/meta/pal_lv1_meta.asm"
.include "build/demo_sprites/sprites/meta/knight_meta.asm"

main:
            ; The engine palette is all black by default. Apply it to the HW.
            lxi d, v6_palette_update_request ; DE = palette update request addr
            mvi a, PALETTE_UPD_REQ_YES       ; A = request value

            ; Inquire the engine to apply the palette change. The engine will read the
            ; palette data from the v6_palette table and apply it to the HW.
            hlt

            ; ------------------------------------------------------------------
            ; Fade the palette from black to the sample palette.
            ; The fade animation data is included in the palette meta data.
            lxi d, _pal_lv1_data + _pal_lv1_palette_fade_to_black_relative
            call palette_fade_reverse


            ; ------------------------------------------------------------------
            ; Unpack the packed song data into the RAM disk and start the
            ; music player. The symbol `_little_mermaid_data` points to the packed
            ; data included with this sample.
            lxi h, _song01_data
            call v6_gc_unpack_init_play_song


SPRITE_INIT_POS_X = 10 ; in bytes, multiply by 8 for pixel position
SPRITE_INIT_POS_Y = 128

main_loop:
            ; print A register to the console for debugging
            ; out 0xED
            ; sync with the frame start
            hlt

            lxi h, knight_scr_addr

            ; handle the controls
            lda v6_action_code
            mov c, a

            ; check key UP
            ani CONTROL_CODE_UP
            jz check_key_down
            inr m
            out 0xED
            jmp check_key_left

check_key_down:
            mov a, c
            ani CONTROL_CODE_DOWN
            jz check_key_left
            dcr m

check_key_left:
            inx h ; move to the x position (in bytes)
            mov a, c
            ani CONTROL_CODE_LEFT
            jz check_key_right
            dcr m
            jmp render

check_key_right:
            mov a, c
            ani CONTROL_CODE_RIGHT
            jz render
            inr m

render:
            ; erase the old sprite
            lhld knight_scr_addr_old
            xchg
            ; we will be drawing one frame of the knight animation.
            ; the frame data contains a width and height in the second pair of bytes.
            ; the width is minus 1 of the actual width in bytes.
            ; we reconstruct the actual width by adding 1 to it.
            ; for more details about the sprite data format, see the
            ; engine\gfx\v6_sprite_draw.asm and meta data in build/demo_sprites/sprites/meta/knight_meta.asm
            lhld _knight_data + _knight_idle_0_0_relative + 2
            inr h
            ; de - scr addr
            ; hl - width, height
            call sprite_erase


draw_sprites:
            ; Draw a sprite on the screen.
            ; bc - sprite data
            ; de - screen addr
            ; we will be drawing one frame of the knight animation.
            lxi b, _knight_data + _knight_idle_0_0_relative
            lhld knight_scr_addr
            xchg
            call sprite_draw_vm

            ; copy the current screen position to the old position for next frame
            lhld knight_scr_addr
            shld knight_scr_addr_old


            jmp main_loop
            ret

knight_scr_addr:
            .db SPRITE_INIT_POS_Y
            .db SPRITE_X_SCR_ADDR + SPRITE_INIT_POS_X

knight_scr_addr_old:
            .db SPRITE_INIT_POS_Y
            .db SPRITE_X_SCR_ADDR + SPRITE_INIT_POS_X