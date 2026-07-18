.global main

; Import engine constants and helper macros.
.include "../../engine/common/v6_consts.asm"
.include "../../engine/common/v6_macros.asm"

.include "build/04_tiled_img/tiled_imgs/meta/tim_data_meta.asm"
; Include generated metadata for palette.
.include "build/04_tiled_img/palettes/meta/pal_lv1_meta.asm"

main:
            lxi d, _pal_lv1 + _pal_lv1_palette_fade_to_black_relative
            call palette_fade_reverse

            A_TO_ZERO(RAM_DISK_OFF_CMD)
            lxi h, _tim_data
            call tiled_img_init_idxs
            A_TO_ZERO(RAM_DISK_OFF_CMD)
            lxi h, _tim_gfx
            call tiled_img_init_gfx
            lxi d, _tim_main_menu_back
            call tiled_img_draw

            A_TO_ZERO(RAM_DISK_OFF_CMD)
            lxi h, _tim_data
            call tiled_img_init_idxs
            A_TO_ZERO(RAM_DISK_OFF_CMD)
            lxi h, _tim_gfx
            call tiled_img_init_gfx
            lxi d, _tim_main_menu_front
            call tiled_img_draw

            ; An infinite loop to keep the program running for demonstrating
            ; purposes.
@loop:      jmp @loop
