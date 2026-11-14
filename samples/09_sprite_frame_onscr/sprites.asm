SPR_MAX = 10 ; max number of sprites to render

.struct sprite_offscr
    scr_y:  byte ; x scr position
    scr_x:  byte ; y scr position
    height: byte ; width (0=8pxs, 1=16pxs, 2=24pxs, 3=32pxs)
    width:  byte ; height (in pixels)
.endstruct

sprites_offscr:    sprite_offscr (scr_y= 17, scr_x=SPRITE_X_SCR_ADDR +  2, width=1, height=16)
SP01:       sprite_offscr (scr_y=203, scr_x=SPRITE_X_SCR_ADDR + 29, width=1, height=16)
SP02:       sprite_offscr (scr_y= 88, scr_x=SPRITE_X_SCR_ADDR + 11, width=1, height=16)
SP03:       sprite_offscr (scr_y=156, scr_x=SPRITE_X_SCR_ADDR + 24, width=1, height=16)
SP04:       sprite_offscr (scr_y=234, scr_x=SPRITE_X_SCR_ADDR +  7, width=1, height=16)
SP05:       sprite_offscr (scr_y= 42, scr_x=SPRITE_X_SCR_ADDR + 15, width=1, height=16)
SP06:       sprite_offscr (scr_y=119, scr_x=SPRITE_X_SCR_ADDR + 30, width=1, height=16)
SP07:       sprite_offscr (scr_y=175, scr_x=SPRITE_X_SCR_ADDR +  0, width=1, height=16)
SP08:       sprite_offscr (scr_y= 63, scr_x=SPRITE_X_SCR_ADDR + 18, width=1, height=16)
SP09:       sprite_offscr (scr_y=221, scr_x=SPRITE_X_SCR_ADDR + 26, width=1, height=16)
SP10:       sprite_offscr (scr_y=140, scr_x=SPRITE_X_SCR_ADDR +  5, width=1, height=16)
SP11:       sprite_offscr (scr_y= 95, scr_x=SPRITE_X_SCR_ADDR + 13, width=1, height=16)
SP12:       sprite_offscr (scr_y= 28, scr_x=SPRITE_X_SCR_ADDR + 22, width=1, height=16)
SP13:       sprite_offscr (scr_y=187, scr_x=SPRITE_X_SCR_ADDR +  9, width=1, height=16)
SP14:       sprite_offscr (scr_y= 71, scr_x=SPRITE_X_SCR_ADDR + 27, width=1, height=16)


.struct sprite_onscr
    scr_y:  byte ; x scr position
    scr_x:  byte ; y scr position
    height: byte ; width (0=8pxs, 1=16pxs, 2=24pxs, 3=32pxs)
    width:  byte ; height (in pixels)
    spg_sprite_mask:  word ; spatial grid cell sprite mask (1 bit per sprite)
.endstruct

sprites_onscr: sprite_onscr (scr_y=190, scr_x=SPRITE_X_SCR_ADDR + 27, width=1, height=16)
SPG01:         sprite_onscr (scr_y=203, scr_x=SPRITE_X_SCR_ADDR + 30, width=1, height=16)
SPG02:         sprite_onscr (scr_y= 63, scr_x=SPRITE_X_SCR_ADDR + 18, width=1, height=16)
SPG03:         sprite_onscr (scr_y=156, scr_x=SPRITE_X_SCR_ADDR + 24, width=1, height=16)
SPG04:         sprite_onscr (scr_y=234, scr_x=SPRITE_X_SCR_ADDR +  7, width=1, height=16)
SPG05:         sprite_onscr (scr_y=201, scr_x=SPRITE_X_SCR_ADDR + 26, width=1, height=16)
SPG06:         sprite_onscr (scr_y=119, scr_x=SPRITE_X_SCR_ADDR + 30, width=1, height=16)
SPG07:         sprite_onscr (scr_y=175, scr_x=SPRITE_X_SCR_ADDR +  0, width=1, height=16)
SPG08:         sprite_onscr (scr_y=200, scr_x=SPRITE_X_SCR_ADDR + 29, width=1, height=16)
SPG09:         sprite_onscr (scr_y=221, scr_x=SPRITE_X_SCR_ADDR + 26, width=1, height=16)

SPG10:         sprite_onscr (scr_y=140, scr_x=SPRITE_X_SCR_ADDR +  5, width=1, height=16)
SPG11:         sprite_onscr (scr_y= 42, scr_x=SPRITE_X_SCR_ADDR + 15, width=1, height=16)
SPG12:         sprite_onscr (scr_y= 28, scr_x=SPRITE_X_SCR_ADDR + 22, width=1, height=16)
SPG13:         sprite_onscr (scr_y=195, scr_x=SPRITE_X_SCR_ADDR + 31, width=1, height=16)
SPG14:         sprite_onscr (scr_y=171, scr_x=SPRITE_X_SCR_ADDR + 1, width=1, height=16)



SPG_SPRITE_MASK_SIZE = 2 ; 16 bits = 2 bytes
SPG_WIDTH = 16
SPG_HEIGHT = 16
SPG_LEN = SPG_WIDTH * SPG_HEIGHT * SPG_SPRITE_MASK_SIZE
SPG_CLUSTER_MAX = SPR_MAX
SPG_CLUSTERS_LEN = SPG_CLUSTER_MAX * SPG_SPRITE_MASK_SIZE


_safe_word:
            .storage 2
.align 32

; cluster array.
; must follow the spatial_grid
spg_clusters:
            .storage SPG_CLUSTERS_LEN

; spatial grid (SPG) data
spatial_grid:
            .storage SPG_LEN

.struct sprite_batch
    ptr: word ; ptr to the last addr byte of a last sprite in sprite_ptrs that
              ; that belongs to this cluster
    scr_y:  byte ; x scr position
    scr_x:  byte ; y scr position
    height: byte ; width (0=8pxs, 1=16pxs, 2=24pxs, 3=32pxs)
    width:  byte ; height (in pixels)
    len: byte ; the number of sprites in the batch

.endstruct

render_batches:
            sprite_batch[SPG_CLUSTER_MAX]

current_render_batch:
            .storage ADDR_LEN

sprite_ptrs:
            .storage SPR_MAX * ADDR_LEN

current_sprite_ptr:
            .storage ADDR_LEN

_filler:
            .align 32
_filler_end: