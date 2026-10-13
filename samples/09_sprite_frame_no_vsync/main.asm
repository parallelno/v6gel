; ------------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * palette update
;    * palette fade
;    * sprite erase
;    * sprite draw
;    * read controls
;    * export assets into meta-data and data files, and reference it in assembly
;    * an attempt to use a timer to avoid beam while rendering.
; ------------------------------------------------------------------------------

.global main

; Import engine constants and control codes
.include "../../engine/common/v6_consts.asm"
.include "../../engine/controls/v6_controls_consts.asm"
.include "../../engine/common/v6_macros.asm"

; Include generated metadata for palette and sprite assets.
; Each asset is exported into two files:
; 1. *_meta.asm: contains relative labels to the data file and usefull constants.
;    It is usually included in the program.
; 2. *_data.asm: contains the actual bytes to be loaded into the RAM disk. It
;    can be included, linked or loaded from FDD at runtime.
.include "build/09_sprite_frame_no_vsync/palettes/asm/pal_lv0_meta.asm"
.include "build/09_sprite_frame_no_vsync/sprites/asm/knight_meta.asm"
.include "build/09_sprite_frame_no_vsync/levels/asm/lv0_data_meta.asm"
.include "build/09_sprite_frame_no_vsync/levels/asm/lv0_gfx_meta.asm"


SPR_MAX = 10
; ---------------------------------------------------------------------------
; Configuration: initial sprite position
; Note: `SPRITE_INIT_POS_X` is specified in bytes (screen X in 8-pixel columns).
; To convert to pixels multiply by 8 where needed.
; `SPRITE_X_SCR_ADDR` is an engine-provided constant (screen base X offset).
; ---------------------------------------------------------------------------
SPRITE_INIT_POS_X = 10 ; in bytes (8 pixels per byte)
SPRITE_INIT_POS_Y = 128

FRAME_SAFE_SCR_INES = 50
BEAM_OUT_OF_SCR = 0

FRAME_BORDER_TOP    = 40
FRAME_SCR           = 256
FRAME_BORDER_BOTTOM = 16

FRAME_LINES      = FRAME_BORDER_TOP + FRAME_SCR + FRAME_BORDER_BOTTOM
FRAME_LINE_TIME  = 96
FRAME_TIME       = FRAME_LINES * FRAME_LINE_TIME

; ---------------------------------------------------------------------------
; Entry point
; Steps performed here:
;  1. Request the engine to apply the palette stored in `v6_palette`.
;  2. Start a fade-in animation from a constant color to our exported palette.
;  3. Enter the main loop which syncs to frames, handles controls and
;     renders the animated sprite.
; ---------------------------------------------------------------------------
main:
            hlt ; sync to the start of the frame
            call set_timer

            call init_sprite_scr_addrs
            call room_init
            call room_copy_scr_to_backbuffs

            ; By default the engine uses a black palette.
            ; Request the engine to refresh hardware palette from `v6_palette`.
            ; The engine watches `v6_palette_update_request` and applies
            ; palette data when the request value is set to `PALETTE_UPD_REQ_YES`.
            lxi d, v6_palette_update_request   ; DE = palette update request addr
            mvi a, PALETTE_UPD_REQ_YES         ; A = request value
            hlt
            ; Fade-in the palette from black to our exported palette.
            ; The meta file defines the fade animation offset
            ; label `_pal_lv1_palette_fade_to_black_relative`.
            ; The object file contains the actual data and the label that points
            ; to it in a format `_<asset_json_file_name>`.
            lxi d, _pal_lv0 + _pal_lv0_palette_fade_to_black_relative
            call palette_fade_reverse



; ---------------------------------------------------------------------------
; Main game loop: sync to frame start, read controls and update sprite
; ---------------------------------------------------------------------------
main_loop:

            ; Prepare the screen address pointer for the knight sprite.
            lxi h, knight_scr_addr

            ; Read current keyboard action code provided by engine.
            ; Codes are defined in `v6_controls_consts.asm` and are bitwise ORed together.
            lda v6_action_code
            mov c, a              ; save action code in C for multi-key checks

            ; Check UP: if pressed, increment Y (screen row) = move up visually
            ani CONTROL_CODE_UP
            jz check_key_down
            inr m                 ; increment low byte (Y)
            jmp check_key_left

check_key_down:
            mov a, c
            ani CONTROL_CODE_DOWN
            jz check_key_left
            dcr m                 ; decrement low byte (Y)

check_key_left:
            inx h                 ; advance HL to the X position byte (screen X in bytes)
            mov a, c
            ani CONTROL_CODE_LEFT
            jz check_key_right
            dcr m                 ; decrement X (move left)
            jmp render

check_key_right:
            mov a, c
            ani CONTROL_CODE_RIGHT
            jz render
            inr m                 ; increment X (move right)

; ---------------------------------------------------------------------------
; Rendering: erase previous sprite then draw the new one
; - `knight_scr_addr_old` stores previous screen coordinates
; - sprite metadata contains frame width/height and pixel data
; - `_knight`            - linked sprite blob. The label is defined in the
;                          exported `knight_obj.asm`.
; - The exported *_meta.asm provides the relative offsets of each frame.
; ---------------------------------------------------------------------------
render:
            ; Erase the sprite at the old position (read address, then call erase)
            lhld knight_scr_addr_old
            xchg

            ; The sprite frame header: first two bytes are frame x/y offset,
            ; next two bytes are width/height (width is stored as width-1 in
            ; exporter for performance reasons).
            ; Load a frame width/height.
            lhld _knight + _knight_idle_0_0_relative + 2
            ; DE = screen addr to clear, HL = width,height pair expected by routine
            call sprite_erase


            ; Draw a frame 0, pixel preshift 0 of the idle animation at current
            ; screen position.
            lxi b, _knight + _knight_idle_0_0_relative
            lhld knight_scr_addr
            xchg
            ; BC = Sprite data, DE = Screen addr
            call sprite_draw_vm

            ; Save current screen position for the next frame erase
            lhld knight_scr_addr
            shld knight_scr_addr_old

            ; draw sprites
            call erase_draw_sprites
            jmp main_loop


; delay loop for pausing the game
; in:
; hl - counter for the delay loop
pause:
@loop:
            dcx h
            mov a, h
            ora l
            jnz @loop
            ret

; ---------------------------------------------------------------------------
; Screen address variables (stored as low/high byte pairs matching engine API)
; `SPRITE_X_SCR_ADDR` is an engine constant pointing to the X base offset.
; We add `SPRITE_INIT_POS_X` to place the sprite horizontally.
; ---------------------------------------------------------------------------
knight_scr_addr:
            .db SPRITE_INIT_POS_Y
            .db SPRITE_X_SCR_ADDR + SPRITE_INIT_POS_X

knight_scr_addr_old:
            .db SPRITE_INIT_POS_Y
            .db SPRITE_X_SCR_ADDR + SPRITE_INIT_POS_X



; contains the spr scr addrs
sprite_scr_addrs:
            .dw ((SPRITE_X_SCR_ADDR +  2)<<8) +  17
            .dw ((SPRITE_X_SCR_ADDR + 29)<<8) + 203
            .dw ((SPRITE_X_SCR_ADDR + 11)<<8) +  88
            .dw ((SPRITE_X_SCR_ADDR + 24)<<8) + 156
            .dw ((SPRITE_X_SCR_ADDR +  7)<<8) + 234
            .dw ((SPRITE_X_SCR_ADDR + 15)<<8) +  42
            .dw ((SPRITE_X_SCR_ADDR + 30)<<8) + 119
            .dw ((SPRITE_X_SCR_ADDR +  0)<<8) + 175
            .dw ((SPRITE_X_SCR_ADDR + 18)<<8) +  63
            .dw ((SPRITE_X_SCR_ADDR + 26)<<8) + 221
            .dw ((SPRITE_X_SCR_ADDR +  5)<<8) + 140
            .dw ((SPRITE_X_SCR_ADDR + 13)<<8) +  95
            .dw ((SPRITE_X_SCR_ADDR + 22)<<8) +  28
            .dw ((SPRITE_X_SCR_ADDR +  9)<<8) + 187
            .dw ((SPRITE_X_SCR_ADDR + 27)<<8) +  71


; contains old scr addr to restore the back
sprite_scr_addrs_old:
        .loop SPR_MAX
            .storage 2 ; scr addr
        .endloop

; contains the rendering state for each sprite
; 0 - not rendered
; 1 - rendered
sprite_render_state:
            .storage SPR_MAX

init_sprite_scr_addrs:
            lxi h, sprite_scr_addrs
            lxi d, sprite_scr_addrs_old
            lxi b, SPR_MAX * 2 ; an entity is a word
            call mem_copy
            ret


; erase, then draw a sprite
; in:
; a - sprite idx in (0..SPR_MAX-1)
erase_draw_sprite:
            ; HL_TO_AX2_PLUS_INT16(sprite_scr_addrs_old)
            ; push h

            ; ; read the scr addr
            ; mov e, m
            ; inx h
            ; mov d, m
            ; inx h

            ; ; The sprite frame header: first two bytes are frame x/y offset,
            ; ; next two bytes are width/height (width is stored as width-1 in
            ; ; exporter for performance reasons).
            ; ; Load a frame width/height.
            ; lhld _knight + _knight_idle_0_0_relative + 2
            ; lxi h, ((1)<<8) + 16
            ; ;lxi d, ((SPRITE_X_SCR_ADDR)<<8) +  0
            ; ; de - scr addr
            ; ; hl - width, height
            ; call sprite_erase

            ; pop h

            ; draw a sprite
            ; advance hl to the sprite_scr_addrs
            ;HL_ADVANCE(sprite_scr_addrs_old, sprite_scr_addrs, BY_BC)

            HL_TO_AX2_PLUS_INT16(sprite_scr_addrs)

            ; read the scr addr
            mov e, m
            inx h
            mov d, m
            inx h

            lxi b, _knight + _knight_idle_0_0_relative
            ; BC = Sprite data, DE = Screen addr
            call sprite_draw_vm
            ret


erase_draw_sprites:
            call reset_sprite_render_state

            mvi a, SPR_MAX
            sta @remaining_sprites
            A_TO_ZERO(0)
            sta @current_sprite_idx
@loop:
            ; get the elapsed time since the start of the frame
            call get_scr_rast_line
            sta scr_rast_line

            ; check if the current sprite is rendered
            lda @current_sprite_idx
            HL_TO_A_PLUS_INT16(sprite_render_state)

            A_TO_ZERO(0)
            cmp m
            jnz @next_spr

            ; check if the rast beam is far enough to avoid it while rendering
            lda scr_rast_line
            CPI_ZERO(BEAM_OUT_OF_SCR)
            jz @render_sprite
            mov c, a

            ; get the sprite pos_y
            lda @current_sprite_idx
            HL_TO_AX2_PLUS_INT16(sprite_scr_addrs)
            mov a, c
            mov c, m
            ; a - beam scr_y
            ; c - sprite scr_y
            sub c
            jc @render_sprite ; beam is below the sprite, safe to render
            cpi FRAME_SAFE_SCR_INES
            jc @next_spr ; the beam is too close, try the next sprite
            ; beam is above enough, safe to render

@render_sprite:
            ; render a sprite
            lda @current_sprite_idx
            call erase_draw_sprite

            ; set the sprite rendered
            lda @current_sprite_idx
            HL_TO_A_PLUS_INT16(sprite_render_state)
            mvi m, 1

            ; check if there are any sprites left to render
            lxi h, @remaining_sprites
            dcr m
            rz

@next_spr:
            ; select the next sprite
            lxi h, @current_sprite_idx
            inr m
            mvi a, SPR_MAX
            cmp m
            jnz @no_wrap_spr_idx
@wrap_spr_idx:
            mvi m, 0
@no_wrap_spr_idx:
            jmp @loop

@remaining_sprites:
            .db 0
@current_sprite_idx:
            .db 0
scr_rast_line:
            .storage BYTE_LEN

reset_sprite_render_state:
            lxi h, sprite_render_state
            lxi b, sprite_render_state + SPR_MAX
            call mem_erase
            ret


set_timer:
            mvi a, 34h      ; счётчик 0, мл.+ст. байт, режим 2
            out 8
            ; submit the counter (7500h)
            A_TO_ZERO(<FRAME_TIME)
            out 11
            mvi a, >FRAME_TIME
            out 11
            ret


; read the timer
; out:
; hl - remaining time until the end of the frame (0..FRAME_TIME)
; error: the actual current rasterized line is 5 lines below,
; so the correct output is hl += 5*FRAME_LINE_TIME, must be accounted for.
get_timer_counter:
            A_TO_ZERO(NULL) ; защёлкнуть счётчик 0
            out 8
            in 11
            mov l, a
            in 11
            mov h, a
            ret

; get the aproximete currently rasterized line
; out
; a - aproximete currently rasterized line in a range of 0..255
; a = BEAM_OUT_OF_SCR if it's out of screen.
get_scr_rast_line:
            call get_timer_counter
            ; hl - counter in a range of 0..FRAME_TIME

            ; div by 128 = >>7 = <<1
            dad h
            ; h - current frame line remapped from [0, FRAME_LINES)
            ; to [0..234)

            ; check if it's insode the top border.
            mvi a, 204 ; FRAME_BORDER_BOTTOM + FRAME_SCR mapped from [0..312) to [0..234)
            sub h
            jc @out_of_scr

            ; sub bottom border
            mvi a, -12 ; FRAME_BORDER_BOTTOM mapped from [0..312) to [0..234)
            add h
            jnc @out_of_scr

            ; a is an aproximete currently rasterized screen line in
            ; a range of [0..192). remap it to [0..256)
            HL_TO_A_PLUS_INT16 (remap_192_to_256)
            mov a, m
            ret
@out_of_scr:
            A_TO_ZERO(BEAM_OUT_OF_SCR)
            ret


room_init:
            lxi b, _lv0_data
            lxi h, RAM_DISK_OFF_CMD<<8 | RAM_DISK_OFF_CMD
            ; bc - LV0_DATA_ADDR
            ; l - RAM_DISK_S
            ; h - RAM_DISK_M
            ; ex. hl = RAM_DISK_M_LV0_GFX<<8 | RAM_DISK_S_LV0_GFX
            call lv0_data_init

            lxi b, _lv0_gfx
            lxi h, RAM_DISK_OFF_CMD<<8 | RAM_DISK_OFF_CMD
            ; bc - LV0_DATA_ADDR
            ; l - RAM_DISK_S
            ; h - RAM_DISK_M
            ; ex. hl = RAM_DISK_M_LV0_GFX<<8 | RAM_DISK_S_LV0_GFX
            call lv0_gfx_init

			call room_unpack
			call room_init_tiles_gfx
			call room_draw_tiles
            ret

room_copy_scr_to_backbuffs:
			; copy $a000-$ffff scr buffs to the RAM Disk back buffer
			lxi d, SCR_BUFF1_ADDR
			lxi h, 0; SCR_BUFF1_ADDR + SCR_BUFF_LEN * 3
			lxi b, SCR_BUFF_LEN * 3
			mvi a, RAM_DISK_S_BACKBUFF
			call mem_copy_to_ram_disk
			ret

; temp\scripts\generate_remap_192_to_256.py
remap_192_to_256:
            .db 0, 1, 3, 4, 5, 7, 8, 9, 11, 12, 13, 15, 16, 17, 19, 20
            .db 21, 23, 24, 25, 27, 28, 29, 31, 32, 33, 35, 36, 37, 39, 40, 41
            .db 43, 44, 45, 47, 48, 49, 51, 52, 53, 55, 56, 57, 59, 60, 61, 63
            .db 64, 65, 67, 68, 69, 71, 72, 73, 75, 76, 77, 79, 80, 81, 83, 84
            .db 85, 87, 88, 89, 91, 92, 93, 95, 96, 97, 99, 100, 101, 103, 104, 105
            .db 107, 108, 109, 111, 112, 113, 115, 116, 117, 119, 120, 121, 123, 124, 125, 127
            .db 128, 129, 131, 132, 133, 135, 136, 137, 139, 140, 141, 143, 144, 145, 147, 148
            .db 149, 151, 152, 153, 155, 156, 157, 159, 160, 161, 163, 164, 165, 167, 168, 169
            .db 171, 172, 173, 175, 176, 177, 179, 180, 181, 183, 184, 185, 187, 188, 189, 191
            .db 192, 193, 195, 196, 197, 199, 200, 201, 203, 204, 205, 207, 208, 209, 211, 212
            .db 213, 215, 216, 217, 219, 220, 221, 223, 224, 225, 227, 228, 229, 231, 232, 233
            .db 235, 236, 237, 239, 240, 241, 243, 244, 245, 247, 248, 249, 251, 252, 253, 255