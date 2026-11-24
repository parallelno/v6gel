SPR_MAX = 10 ; max number of sprites to render
BAND_MAX = 8
BAND_HEIGHT = 32

.struct sprite
    scr_addr_y: byte
    scr_addr_x: byte
    frame_ptr: word ; ptr to a sprite frame
.endstruct

sprites:  sprite (scr_addr_y=18, scr_addr_x=SPRITE_X_SCR_ADDR, frame_ptr=_knight + _knight_idle_0_0_relative)
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



; sprite rendered in a band. can be a verticaly split portion.
.struct band_sprite
    scr_addr: word
    height: byte    ; height (in pixels)
    width: byte     ; width (0=8pxs, 1=16pxs, 2=24pxs, 3=32pxs)
    gfx_ptr: word   ; ptr to a sprite frame
.endstruct

; list of new and old band sprites. the list length is doubled because every
; sprite can be split. To know what which one is new, read band_sprites_new and
; band_sprites_old
band_sprites1: band_sprite[SPR_MAX * 2]
band_sprites2: band_sprite[SPR_MAX * 2]

; points to the current band_sprites1 or band_sprites2.
; band_sprites_new and band_sprites_old swap every next frame.
band_sprites_new: .storage ADDR_LEN
band_sprites_old: .storage ADDR_LEN

; the next avaiable entry in band_spritesN
band_sprite_tail:
    .storage ADDR_LEN

; total count sprites in all bands
band_sprites_count:
    .storage BYTE_LEN

; contains the band context
.struct band
    cost: byte  ; render cost; used for beam avoidance.
    count: byte ; number of sprites in band
    sprite: word ; ptr to the first sprite in the in band_spritesN.
.endstruct


; align buffers for fast erase
.storage 2
bands1: band[BAND_MAX]

; align buffers for fast erase
.storage 2
bands2: band[BAND_MAX]

; if 0-bit is zero, bands1 is new, and vise versa
band_new_offset:
    .storage BYTE_LEN