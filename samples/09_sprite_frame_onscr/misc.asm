set_palette_fadein:
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

			; copy $a000-$ffff scr buffs to the RAM Disk back buffer2 (to restore the background in the back buffer)
			lxi d, SCR_BUFF1_ADDR
			lxi h, 0; SCR_BUFF1_ADDR + SCR_BUFF_LEN * 3
			lxi b, SCR_BUFF_LEN * 3
			mvi a, RAM_DISK_S_BACKBUFF2
			call mem_copy_to_ram_disk
			ret
