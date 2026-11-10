; renders sprites to the back buffer, then copies them to the screen
; 117488 cc
; without blittering to the screen: 83128 cc
backbuf_renderer:
            call restore_backbuf
            call render_sprites_to_backbuf
            call copy_backbuf_to_scr
            ret


restore_backbuf:
            lxi h, sprites
            mvi a, SPR_MAX
            sta @loop_counter + 1
            ; SCR_BUFF1_ADDR
@loop:
            ; read scr addr
            mov e, m
            HL_ADVANCE(sprite.scr_y, sprite.scr_x)
            mov d, m
            HL_ADVANCE(sprite.scr_x, sprite.height)
            ; read height
            mov c, m
            HL_ADVANCE(sprite.height, sprite.width)
            ; read width
            mov b, m
            HL_ADVANCE(sprite.width, sprite.width+1)
            push h
            mov h, b
            mov l, c
            ; de - scr pos
            ; h - width
            ; l - height
            call sprite_copy_to_back_buff_v
            pop h
@loop_counter:
            mvi a, SPR_MAX
            dcr a
            sta @loop_counter + 1
            jnz @loop
            ret


render_sprites_to_backbuf:
            lxi h, sprites
            mvi a, SPR_MAX
            sta @loop_counter + 1
            ; SCR_BUFF2_ADDR
@loop:
            ; read scr addr
            mov e, m
            HL_ADVANCE(sprite.scr_y, sprite.scr_x)
            mov d, m
            HL_ADVANCE(sprite.scr_x, sprite.width+1)
            push h

            lxi b, _knight + _knight_idle_0_0_relative
            ; BC = Sprite data, DE = Screen addr
            CALL_RAM_DISK_FUNC(sprite_draw_vm, RAM_DISK_M_BACKBUFF | RAM_DISK_M_8F )
            pop h
@loop_counter:
            mvi a, SPR_MAX
            dcr a
            sta @loop_counter + 1
            jnz @loop
            ret


copy_backbuf_to_scr:
            lxi h, sprites
            mvi a, SPR_MAX
            sta @loop_counter + 1
            ; SCR_BUFF2_ADDR
@loop:
            ; read scr addr
            mov e, m
            HL_ADVANCE(sprite.scr_y, sprite.scr_x)
            mov d, m
            HL_ADVANCE(sprite.scr_x, sprite.height)
            ; read height
            mov c, m
            HL_ADVANCE(sprite.height, sprite.width)
            ; read width
            mov b, m
            HL_ADVANCE(sprite.width, sprite.width+1)
            push h
            ; de - screen addr
            ; b - width
            ; c - height
            call sprite_copy_to_scr_v
            pop h
@loop_counter:
            mvi a, SPR_MAX
            dcr a
            sta @loop_counter + 1
            jnz @loop
            ret