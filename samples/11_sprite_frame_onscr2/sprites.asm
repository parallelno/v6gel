SPR_MAX = 10 ; max number of sprites to render

.struct sprite
    scr_addr_y: byte
    scr_addr_x: byte
    frame_ptr: word ; ptr to a sprite frame
.endstruct

sprites:  sprite (scr_addr_y=190, scr_addr_x=SPRITE_X_SCR_ADDR + 27, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite01: sprite (scr_addr_y=203, scr_addr_x=SPRITE_X_SCR_ADDR + 30, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite02: sprite (scr_addr_y= 63, scr_addr_x=SPRITE_X_SCR_ADDR + 18, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite03: sprite (scr_addr_y=156, scr_addr_x=SPRITE_X_SCR_ADDR + 24, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite04: sprite (scr_addr_y=234, scr_addr_x=SPRITE_X_SCR_ADDR +  7, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite05: sprite (scr_addr_y=201, scr_addr_x=SPRITE_X_SCR_ADDR + 26, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite06: sprite (scr_addr_y=119, scr_addr_x=SPRITE_X_SCR_ADDR + 30, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite07: sprite (scr_addr_y=175, scr_addr_x=SPRITE_X_SCR_ADDR +  0, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite08: sprite (scr_addr_y=200, scr_addr_x=SPRITE_X_SCR_ADDR + 29, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite09: sprite (scr_addr_y=221, scr_addr_x=SPRITE_X_SCR_ADDR + 26, frame_ptr=_knight + _knight_idle_0_0_relative)

sprite10: sprite (scr_addr_y=140, scr_addr_x=SPRITE_X_SCR_ADDR +  5, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite11: sprite (scr_addr_y= 42, scr_addr_x=SPRITE_X_SCR_ADDR + 15, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite12: sprite (scr_addr_y= 28, scr_addr_x=SPRITE_X_SCR_ADDR + 22, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite13: sprite (scr_addr_y=195, scr_addr_x=SPRITE_X_SCR_ADDR + 31, frame_ptr=_knight + _knight_idle_0_0_relative)
sprite14: sprite (scr_addr_y=171, scr_addr_x=SPRITE_X_SCR_ADDR + 1, frame_ptr=_knight + _knight_idle_0_0_relative)


BAND_MAX = 8

_safe_word:
            .storage 2
.align 32

; sprite rendered in a band. can be a verticaly split portion.
.struct band_sprite
    scr_addr_y: byte
    scr_addr_x: byte
    height: byte ; width (0=8pxs, 1=16pxs, 2=24pxs, 3=32pxs)
    width:  byte ; height (in pixels)
    gfx_ptr: word ; ptr to a sprite frame
    draw_func: word
    next_ptr: word ; ptr to the next band_sprite in a band
.endstruct

; contigues list of new and old band sprites. the list length is doubled because
; every sprite can be split.
band_sprites_new: band_sprite[SPR_MAX * 2]
band_sprites_old: band_sprite[SPR_MAX * 2]

================================================================================

band_sprites_new and band_sprites_old must also be swapped.
also think if swapping new_sprites and old_sprites of every band is necessary

================================================================================

last_band_sprite_new_ptr: .storage ADDR_LEN ; ptr to next vacant entry in band_sprites_new

; ptr to next vacant entry in band_sprites_new for each band
last_bands_new_sprite: .storage BAND_MAX * ADDR_LEN

.struct band
    new_sprites: word ; ptr to a linked list of band_sprite
    old_sprites: word ; ptr to a linked list of band_sprite
.endstruct

bands: band[BAND_MAX]

.if bands.size > 256
    .error "bands.size > 256"
.endif

_aligner:
            .align 32
_filler_end: