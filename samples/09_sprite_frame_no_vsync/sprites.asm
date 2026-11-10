SPR_MAX = 10 ; max number of sprites to render

; contains the spr scr addrs

.struct sprite
    scr_y:  byte ; x scr position
    scr_x:  byte ; y scr position
    height: byte ; width (0=8pxs, 1=16pxs, 2=24pxs, 3=32pxs)
    width:  byte ; height (in pixels)
.endstruct

sprites:    sprite (scr_y= 17, scr_x=SPRITE_X_SCR_ADDR +  2, width=1, height=16)
SP01:       sprite (scr_y=203, scr_x=SPRITE_X_SCR_ADDR + 29, width=1, height=16)
SP02:       sprite (scr_y= 88, scr_x=SPRITE_X_SCR_ADDR + 11, width=1, height=16)
SP03:       sprite (scr_y=156, scr_x=SPRITE_X_SCR_ADDR + 24, width=1, height=16)
SP04:       sprite (scr_y=234, scr_x=SPRITE_X_SCR_ADDR +  7, width=1, height=16)
SP05:       sprite (scr_y= 42, scr_x=SPRITE_X_SCR_ADDR + 15, width=1, height=16)
SP06:       sprite (scr_y=119, scr_x=SPRITE_X_SCR_ADDR + 30, width=1, height=16)
SP07:       sprite (scr_y=175, scr_x=SPRITE_X_SCR_ADDR +  0, width=1, height=16)
SP08:       sprite (scr_y= 63, scr_x=SPRITE_X_SCR_ADDR + 18, width=1, height=16)
SP09:       sprite (scr_y=221, scr_x=SPRITE_X_SCR_ADDR + 26, width=1, height=16)
SP10:       sprite (scr_y=140, scr_x=SPRITE_X_SCR_ADDR +  5, width=1, height=16)
SP11:       sprite (scr_y= 95, scr_x=SPRITE_X_SCR_ADDR + 13, width=1, height=16)
SP12:       sprite (scr_y= 28, scr_x=SPRITE_X_SCR_ADDR + 22, width=1, height=16)
SP13:       sprite (scr_y=187, scr_x=SPRITE_X_SCR_ADDR +  9, width=1, height=16)
SP14:       sprite (scr_y= 71, scr_x=SPRITE_X_SCR_ADDR + 27, width=1, height=16)
