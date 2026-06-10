jmp v6_main_init

.include "asm/v6/v6_macros.asm"
.include "asm/v6/v6_consts.asm"
.include "build/build_consts.asm"
.include "asm/v6/v6_os.asm"
.include "asm/v6/v6_utils.asm"
.include "asm/v6/v6_controls.asm"
.include "asm/v6/v6_interruption.asm"
.include "asm/v6/v6_text_mono_draw.asm"
.include "asm/v6/v6_text_ex_draw.asm"
.include "asm/v6/sound/v6_sound.asm"
.include "asm/v6/v6_tile_draw.asm"
.include "asm/v6/v6_sprite.asm"
.include "asm/v6/v6_sprite_erase.asm"
.include "asm/v6/v6_sprite_copy_to_scr.asm"
.include "asm/v6/v6_sprite_copy_to_backbuf.asm"
.include "asm/v6/v6_sprite_draw.asm"
.include "asm/v6/v6_sprite_draw_hit.asm"
.include "asm/v6/v6_sprite_draw_invis.asm"
.include "asm/v6/v6_tiled_img_draw.asm"
.include "asm/v6/v6_decal_draw.asm"
.include "asm/v6/v6_back_draw.asm"

v6_main_init:
			lxi h, interruption
			call v6_os_init
			call app_start
			call v6_os_exit