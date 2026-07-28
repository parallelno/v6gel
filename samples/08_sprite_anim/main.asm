; ------------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * palette update
;    * palette fade
;    * sprite erase
;    * sprite draw
;    * read controls
;    * export assets into meta-data and data files, and reference it in assembly
; ------------------------------------------------------------------------------

.global main

; Import engine constants and control codes
.include "../../engine/common/v6_consts.asm"
.include "../../engine/common/v6_macros.asm"
.include "../../engine/controls/v6_controls_consts.asm"

; Include generated metadata for palette and sprite assets.
; Each asset is exported into two files:
; 1. *_meta.asm: contains relative labels to the data file and usefull constants.
;    It is usually included in the program.
; 2. *_data.asm: contains the actual bytes to be loaded into the RAM disk. It
;    can be included, linked or loaded from FDD at runtime.
.include "build/08_sprite_anim/palettes/asm/pal_lv1_meta.asm"
.include "build/08_sprite_anim/sprites/asm/knight_meta.asm"

; ---------------------------------------------------------------------------
; Entry point
; Steps performed here:
;  1. Request the engine to apply the palette stored in `v6_palette`.
;  2. Start a fade-in animation from a constant color to our exported palette.
;  3. Enter the main loop which syncs to frames, handles controls and
;     renders the animated sprite.
; ---------------------------------------------------------------------------
main:
            ; By default the engine uses a black palette.
            ; Request the engine to refresh hardware palette from `v6_palette`.
            ; The engine watches `v6_palette_update_request` and applies
            ; palette data when the request value is set to `PALETTE_UPD_REQ_YES`.
            lxi d, v6_palette_update_request   ; DE = palette update request addr
            mvi a, PALETTE_UPD_REQ_YES         ; A = request value
            hlt                                 ; yield; engine will process request

            ; Fade-in the palette from black to our exported palette.
            ; The meta file defines the fade animation offset
            ; label `_pal_lv1_palette_fade_to_black_relative`.
            ; The object file contains the actual data and the label that points
            ; to it in a format `_<asset_json_file_name>`.
            lxi d, _pal_lv1 + _pal_lv1_palette_fade_to_black_relative
            call palette_fade_reverse

; ---------------------------------------------------------------------------
; Configuration: initial sprite position
; Note: `SPRITE_INIT_POS_X` is specified in bytes (screen X in 8-pixel columns).
; To convert to pixels multiply by 8 where needed.
; `SPRITE_X_SCR_ADDR` is an engine-provided constant (screen base X offset).
; ---------------------------------------------------------------------------
SPRITE_INIT_POS_X = 10 ; in bytes (8 pixels per byte)
SPRITE_INIT_POS_Y = 128

; ---------------------------------------------------------------------------
; Main game loop: sync to frame start, read controls and update sprite
; ---------------------------------------------------------------------------
main_loop:
            ; Synchronize with the frame start.
            hlt
            DEBUG_BORDER_LINE(0)


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
            inr m                 ; increment low byte (Y)
            jmp check_key_left

check_key_down:
            mov a, c
            ani CONTROL_CODE_DOWN
            jz check_key_left
            dcr m                 ; decrement low byte (Y)
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

draw_sprites:
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

            DEBUG_BORDER_LINE(1)
            jmp main_loop
            ret

knight_pos:
            .db SPRITE_INIT_POS_Y
            .db SPRITE_X_SCR_ADDR + SPRITE_INIT_POS_X

knight_pos_old:
            .db SPRITE_INIT_POS_Y
            .db SPRITE_X_SCR_ADDR + SPRITE_INIT_POS_X