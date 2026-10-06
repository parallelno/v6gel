; ------------------------------------------------------------------------------
; This demo shows how to play sprite animations with the v6gel engine:
;    * palette update and fade-in
;    * sprite erase and sprite draw
;    * reading controls (keyboard/joystick)
;    * a small animation player that selects the knight's animation
;      (idle / run / defence) from the input and advances its frames over time
;    * exporting assets into meta-data and data files, and referencing them from
;      assembly
; ------------------------------------------------------------------------------

.global main

; Import engine constants, control codes, and helper macros.
.include "../../engine/common/v6_consts.asm"
.include "../../engine/common/v6_macros.asm"
.include "../../engine/controls/v6_controls_consts.asm"

; Include generated metadata for the palette and sprite assets.
; Each asset is exported into two files:
; 1. *_meta.asm: contains relative labels to the data file and useful constants.
;    It is usually included in the program.
; 2. *_data.asm: contains the actual bytes. It can be included, linked or loaded
;    from FDD at runtime.
.include "build/08_sprite_anim/palettes/asm/pal_lv1_meta.asm"
.include "build/08_sprite_anim/sprites/asm/knight_meta.asm"

; ------------------------------------------------------------------------------
; Configuration
; ------------------------------------------------------------------------------
; Initial sprite position.
; Note: `SPRITE_INIT_POS_X` is specified in bytes (screen X in 8-pixel columns).
; To convert to pixels multiply by 8 where needed.
; `SPRITE_X_SCR_ADDR` is an engine-provided constant (screen base X offset).
SPRITE_INIT_POS_X = 10 ; in bytes (8 pixels per byte)
SPRITE_INIT_POS_Y = 128

; Number of engine frames each animation frame stays on screen. The engine runs
; at 50 Hz, so 6 frames is about 8 animation steps per second.
ANIM_FRAME_DELAY = 6

; Erase box used to clear the sprite's previous location. Every preshift-0 knight
; frame is at most 16 px wide and 15 px tall, so one fixed box covers all of
; them. sprite_erase expects HL = (H = width packed, L = height), where the
; packed width is 0 -> 8 px, 1 -> 16 px, 2 -> 24 px, 3 -> 32 px.
KNIGHT_ERASE_W_PACKED = 1 ; 16 px
KNIGHT_ERASE_H = 15
KNIGHT_ERASE_WH = KNIGHT_ERASE_W_PACKED << 8 | KNIGHT_ERASE_H

; Animation ids. They index `knight_anim_ptrs` / `knight_anim_counts`.
ANIM_IDLE = 0
ANIM_RUN_R = 1
ANIM_RUN_L = 2
ANIM_DEF_R = 3
ANIM_DEF_L = 4

; Any of the fire keys triggers the defence pose.
CONTROL_CODE_FIRE = CONTROL_CODE_FIRE1 | CONTROL_CODE_FIRE2

; ---------------------------------------------------------------------------
; Entry point
; Steps:
;  1. Apply the exported palette and fade it in from black.
;  2. Start the idle animation.
;  3. Enter the main loop.
; ---------------------------------------------------------------------------
main:
            ; By default the engine uses a black palette.
            ; Request the engine to refresh the hardware palette from
            ; `v6_palette`. The engine watches `v6_palette_update_request` and
            ; applies palette data when it is set to `PALETTE_UPD_REQ_YES`.
            lxi d, v6_palette_update_request
            mvi a, PALETTE_UPD_REQ_YES
            hlt

            ; Fade-in the palette from black to our exported palette.
            ; The meta file defines the fade animation offset label
            ; `_pal_lv1_palette_fade_to_black_relative`.
            lxi d, _pal_lv1 + _pal_lv1_palette_fade_to_black_relative
            call palette_fade_reverse

            ; Start playing the idle animation.
            mvi a, ANIM_IDLE
            call knight_set_anim

; ---------------------------------------------------------------------------
; Main loop: sync to a frame, move, pick an animation, advance it, render.
; ---------------------------------------------------------------------------
main_loop:
            ; Synchronize with the frame start.
            hlt
            DEBUG_BORDER_LINE(0)

            ; -------- movement (knight_scr_addr stores Y then X) --------------
            lxi h, knight_scr_addr
            ; Read the current keyboard/joystick action code (bitwise ORed).
            lda v6_action_code
            mov c, a

            ; UP -> increment Y (a higher Y is up on the Vector-06c screen)
            ani CONTROL_CODE_UP
            jz @chk_down
            inr m
            inr m
@chk_down:
            mov a, c
            ani CONTROL_CODE_DOWN
            jz @chk_x
            dcr m
            dcr m
@chk_x:
            inx h                    ; HL -> the X byte of knight_scr_addr
            mov a, c
            ani CONTROL_CODE_LEFT
            jz @chk_right
            dcr m                    ; move left
            mvi a, 1
            sta knight_facing        ; remember we face left
@chk_right:
            mov a, c
            ani CONTROL_CODE_RIGHT
            jz @pick_anim
            inr m                    ; move right
            xra a
            sta knight_facing        ; remember we face right

            ; -------- select the animation for this frame ---------------------
@pick_anim:
            mov a, c
            ani CONTROL_CODE_FIRE
            jnz @anim_defence        ; fire -> defence pose
            mov a, c
            ani CONTROL_CODE_LEFT
            jnz @anim_run_l
            mov a, c
            ani CONTROL_CODE_RIGHT
            jnz @anim_run_r
            mvi b, ANIM_IDLE
            jmp @apply_anim
@anim_defence:
            lda knight_facing
            ora a
            jnz @anim_def_l
            mvi b, ANIM_DEF_R
            jmp @apply_anim
@anim_def_l:
            mvi b, ANIM_DEF_L
            jmp @apply_anim
@anim_run_l:
            mvi b, ANIM_RUN_L
            jmp @apply_anim
@anim_run_r:
            mvi b, ANIM_RUN_R

            ; Switch animation only when it actually changes, so the frame timer
            ; keeps running while a key is held down.
@apply_anim:
            mov a, b
            lxi h, knight_anim_id
            cmp m
            jz @anim_tick
            call knight_set_anim

            ; -------- advance the animation frame every N frames --------------
@anim_tick:
            lxi h, knight_frame_timer
            dcr m
            jnz render
            mvi m, ANIM_FRAME_DELAY
            call knight_next_frame

            ; -------- render: erase the old frame, draw the current one -------
render:
            ; Erase the sprite at its previous position.
            lhld knight_scr_addr_old
            xchg
            lxi h, KNIGHT_ERASE_WH
            call sprite_erase

            ; Draw the current animation frame at the current position.
            ; knight_frame_ptr points at the current slot of the active
            ; animation's frame table; the slot holds the frame data address.
            lhld knight_frame_ptr
            mov e, m
            inx h
            mov d, m                 ; DE = frame data addr
            mov b, d
            mov c, e                 ; BC = animation frame data
            lhld knight_scr_addr
            xchg                     ; DE = screen addr
            call sprite_draw_vm

            ; Remember the position for the next erase.
            lhld knight_scr_addr
            shld knight_scr_addr_old

            DEBUG_BORDER_LINE(1)
            jmp main_loop
            ret

; ---------------------------------------------------------------------------
; knight_set_anim - switch to animation A (see the ANIM_* constants).
; Resets the animation to its first frame and restarts the frame timer.
; in:  a - animation id
; out: (updates knight_anim_* and knight_frame_ptr)
; ---------------------------------------------------------------------------
knight_set_anim:
            sta knight_anim_id

            ; HL = knight_anim_ptrs + id * 2
            add a
            mvi b, 0
            mov c, a
            lxi h, knight_anim_ptrs
            dad b
            mov e, m
            inx h
            mov d, m                 ; DE = first frame table addr
            xchg                     ; HL = first frame table addr
            shld knight_anim_base
            shld knight_frame_ptr    ; start at the first frame

            ; end = base + frame_count * 2 (one past the last frame)
            lda knight_anim_id
            lxi h, knight_anim_counts
            mvi b, 0
            mov c, a
            dad b                    ; HL -> this animation's frame count
            mov a, m
            add a                    ; frame_count * 2
            mov e, a
            mvi d, 0
            lhld knight_anim_base
            dad d
            shld knight_anim_end

            ; restart the frame timer
            mvi a, ANIM_FRAME_DELAY
            sta knight_frame_timer
            ret

; ---------------------------------------------------------------------------
; knight_next_frame - advance knight_frame_ptr to the next frame of the current
; animation, wrapping around to the first frame after the last.
; ---------------------------------------------------------------------------
knight_next_frame:
            lhld knight_frame_ptr
            INX_H(2)                 ; frame pointers are words
            shld knight_frame_ptr    ; tentatively point at the next frame
            xchg                     ; DE = next frame addr
            lhld knight_anim_end     ; HL = one past the last frame
            mov a, e
            cmp l
            jnz @done
            mov a, d
            cmp h
            jnz @done
            lhld knight_anim_base    ; wrapped -> back to the first frame
            shld knight_frame_ptr
@done:
            ret

; ---------------------------------------------------------------------------
; Animation database
;   * knight_anim_ptrs   - word ptr per animation to its frame pointer table
;   * knight_anim_counts - frame count per animation
;   * knight_frames_*    - preshift-0 frame data pointers. `_knight` is the
;                          linked sprite blob; the exported *_meta.asm provides
;                          the relative offsets of each frame inside it.
; ---------------------------------------------------------------------------
knight_anim_ptrs:
            .word knight_frames_idle
            .word knight_frames_run_r
            .word knight_frames_run_l
            .word knight_frames_defence_r
            .word knight_frames_defence_l

knight_anim_counts:
            .byte 2 ; idle
            .byte 4 ; run right
            .byte 4 ; run left
            .byte 4 ; defence right
            .byte 4 ; defence left

knight_frames_idle:
            .word _knight + _knight_idle_0_0_relative
            .word _knight + _knight_idle_1_0_relative
knight_frames_run_r:
            .word _knight + _knight_run_r0_0_relative
            .word _knight + _knight_run_r1_0_relative
            .word _knight + _knight_run_r2_0_relative
            .word _knight + _knight_run_r3_0_relative
knight_frames_run_l:
            .word _knight + _knight_run_l0_0_relative
            .word _knight + _knight_run_l1_0_relative
            .word _knight + _knight_run_l2_0_relative
            .word _knight + _knight_run_l3_0_relative
knight_frames_defence_r:
            .word _knight + _knight_defence_r0_0_relative
            .word _knight + _knight_defence_r1_0_relative
            .word _knight + _knight_defence_r2_0_relative
            .word _knight + _knight_defence_r3_0_relative
knight_frames_defence_l:
            .word _knight + _knight_defence_l0_0_relative
            .word _knight + _knight_defence_l1_0_relative
            .word _knight + _knight_defence_l2_0_relative
            .word _knight + _knight_defence_l3_0_relative

; ---------------------------------------------------------------------------
; Player state
;
; `knight_scr_addr` is the sprite screen address stored as a low/high byte pair
; matching the engine API. `SPRITE_X_SCR_ADDR` is an engine constant pointing to
; the screen X base offset; `SPRITE_INIT_POS_X` places the sprite horizontally.
; ---------------------------------------------------------------------------
knight_scr_addr:
            .byte SPRITE_INIT_POS_Y
            .byte SPRITE_X_SCR_ADDR + SPRITE_INIT_POS_X
knight_scr_addr_old:
            .byte SPRITE_INIT_POS_Y
            .byte SPRITE_X_SCR_ADDR + SPRITE_INIT_POS_X

knight_frame_ptr:   .word knight_frames_idle ; slot in the active frame table
knight_anim_base:   .word 0                  ; first frame of the active anim
knight_anim_end:    .word 0                  ; one past the last active frame
knight_anim_id:     .byte ANIM_IDLE
knight_frame_timer: .byte ANIM_FRAME_DELAY
knight_facing:      .byte 0                  ; 0 = right, 1 = left
