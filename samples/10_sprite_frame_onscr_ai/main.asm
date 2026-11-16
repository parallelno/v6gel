; Direct masked rendering. Screen Y is the LOW address byte and grows upwards.
.global main, renderer, frame_complete, band_begin, band_end, sprites
.global old_sprites, render_count, band_y, animation_tick, main_loop
.global deferred_frames
.include "../../engine/common/v6_consts.asm"
.include "../../engine/common/v6_macros.asm"
.include "build/10_sprite_frame_onscr_ai/palettes/asm/pal_lv0_meta.asm"
.include "build/10_sprite_frame_onscr_ai/levels/asm/lv0_data_meta.asm"
.include "build/10_sprite_frame_onscr_ai/levels/asm/lv0_gfx_meta.asm"
.include "misc.asm"
.include "renderer.asm"
.include "build/10_sprite_frame_onscr_ai/compiled.asm"

main:
            call room_init
            ; One immutable background only, in bank 0 of the engine RAM disk.
            lxi d, SCR_BUFF1_ADDR
            lxi h, 0
            lxi b, SCR_BUFF_LEN * 3
            mvi a, RAM_DISK_S0
            call mem_copy_to_ram_disk
            call set_palette_fadein
            ; Small dedicated ISR: no FPS/debug writes into the visible screen.
            di
            mvi a, 0c3h
            sta 38h
            lxi h, frame_interrupt
            shld 39h
            ei
            hlt
            di
            ; 1.5 MHz PIT clock; one display frame is 29,952 timer ticks.
            mvi a, 34h
            out 8
            mvi a, <29952
            out 11
            mvi a, >29952
            out 11
            ei
main_loop:
            call renderer
frame_complete:
            ; Move all ten sprites in byte columns, wrapping at the right edge.
            ; Tests also vary Y to exercise dirty footprints across band edges.
            lxi h, sprites
            mvi b, 10
            lda animation_tick
            inr a
            sta animation_tick
            ani 31
            jnz main_loop
move_loop:
            inr m
            mov a, m
            cpi 31
            jc move_ok
            mvi m, 0
move_ok:
            inx h
            inx h
            dcr b
            jnz move_loop
            jmp main_loop

frame_interrupt:
            ei
            ret

animation_tick: .byte 0