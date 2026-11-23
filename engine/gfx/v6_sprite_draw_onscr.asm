.global *

.opt
; sharetable chunk of code to restore SP and
; return a couple of parameters within HL, C
draw_sprite_onscr_ret:
			lxi sp, TEMP_ADDR
			ret


; =============================================
; Draw a sprite with a mask in three consiquence screen buffs with offset_x and offset_y
; it can draw a sprite from the RAM Disk if it's activated
; width is 1-3 bytes (24 pixels max)
; height is 0-255
; offset_x in bytes
; offset_y in pixels
; it uses sp to read the sprite data
; ex. CALL_RAM_DISK_FUNC(sprite_draw_vm, RAM_DISK_S_BURNER | RAM_DISK_M_BACKBUFF | RAM_DISK_M_8F )
; in:
; bc - sprite data
; de - screen addr
; use: all

; Data Layout:
; .word - two safety bytes prevent data corruption caused by interruptions
; .byte - offset_y
; .byte - offset_x
; .byte - height
; .byte - width
; 		0 - one byte width,
;		1 - two bytes width,
;		2 - three bytes width
; pixels data:

; 8 width:
; odd line
; mask, color_scr1, color_scr2, color_scr3
; even line
; mask, color_scr3, color_scr2, color_scr1

; 16 width:
; odd line from left to right
; mask, color_scr1, color_scr2, color_scr3
; mask, color_scr3, color_scr2, color_scr1
; even line from right to left
; mask, color_scr1, color_scr2, color_scr3
; mask, color_scr3, color_scr2, color_scr1

; 24 width:
; odd line from left to right
; mask, color_scr1, color_scr2, color_scr3
; mask, color_scr3, color_scr2, color_scr1
; mask, color_scr1, color_scr2, color_scr3
; even line from right to left
; mask, color_scr3, color_scr2, color_scr1
; mask, color_scr1, color_scr2, color_scr3
; mask, color_scr3, color_scr2, color_scr1


; in:
; c - height
; b - width
; de - sprite data
; hl - screen addr
sprite_draw_vm_onscr:
			; check
			ret


; render a sprite width8
; in:
; sp - sprite gfx
; hl - scr addr
; e - height
draw_sprite_onscr_w8:
			mov a, h
			sta @width8_offset00 + 1
			adi 0x20
			sta @width8_offset20 + 1
			sta @width8_offset20_2 + 1
			adi 0x20
			sta @width8_offset40 + 1

@width8_loop:
// odd line from left to right
// first byte
    		// Scr1
			DRAW_SPRITE_VM_ONSCR1()

@width8_offset20:
			mvi h, TEMP_BYTE ; init_x + 0x20

			// Scr2
			DRAW_SPRITE_VM_ONSCR2()

@width8_offset40:
			mvi h, TEMP_BYTE ; init_x + 0x40

			// Scr3
			DRAW_SPRITE_VM_ONSCR3()

			inr l ; Y + 1
			dcr e
			jz draw_sprite_onscr_ret

// even line from right to left
// first byte
    		// Scr3
			DRAW_SPRITE_VM_ONSCR1()

@width8_offset20_2:
			mvi h, TEMP_BYTE ; init_x + 0x20

			// Scr2
			DRAW_SPRITE_VM_ONSCR2()

@width8_offset00:
			mvi h, TEMP_BYTE ; init_x + 0x00

			// Scr1
			DRAW_SPRITE_VM_ONSCR3()

			inr l ; Y + 1
            dcr e
            jnz @width8_loop
			jmp draw_sprite_onscr_ret


; render a sprite width16
; in:
; sp - sprite gfx
; hl - scr addr
; e - height
draw_sprite_onscr_w16:
			mov a, h
			sta @width16_offset00 + 1
			inr a
			sta @width16_offset01 + 1
			adi 0x20 - 1
			sta @width16_offset20 + 1
			sta @width16_offset20_2 + 1
			inr a
			sta @width16_offset21 + 1
			sta @width16_offset21_2 + 1
			adi 0x40 - 0x21
			sta @width16_offset40 + 1
			inr a
			sta @width16_offset41 + 1

@width16_loop:
// odd line from left to right
// first byte
    		// Scr1
			DRAW_SPRITE_VM_ONSCR1()

@width16_offset20:
			mvi h, TEMP_BYTE ; init_x + 0x20

			// Scr2
			DRAW_SPRITE_VM_ONSCR2()

@width16_offset40:
			mvi h, TEMP_BYTE ; init_x + 0x40

			// Scr3
			DRAW_SPRITE_VM_ONSCR3()

			inr h ; X + 1

// last byte

			// Scr3
			DRAW_SPRITE_VM_ONSCR1()

@width16_offset21:
			mvi h, TEMP_BYTE ; init_x + 0x21

			// Scr2
			DRAW_SPRITE_VM_ONSCR2()

@width16_offset01:
			mvi h, TEMP_BYTE ; init_x + 0x01

			// Scr1
			DRAW_SPRITE_VM_ONSCR3()

			inr l ; Y + 1

			dcr e
			jz draw_sprite_onscr_ret

// even line from right to left
// last byte
    		// Scr1
			DRAW_SPRITE_VM_ONSCR1()

@width16_offset21_2:
			mvi h, TEMP_BYTE ; init_x + 0x21

			// Scr2
			DRAW_SPRITE_VM_ONSCR2()

@width16_offset41:
			mvi h, TEMP_BYTE ; init_x + 0x41

			// Scr3
			DRAW_SPRITE_VM_ONSCR3()

			dcr h ; X - 1

// first byte

			// Scr3
			DRAW_SPRITE_VM_ONSCR1()

@width16_offset20_2:
			mvi h, TEMP_BYTE ; init_x + 0x20

			// Scr2
			DRAW_SPRITE_VM_ONSCR2()

@width16_offset00:
			mvi h, TEMP_BYTE ; init_x + 0x00

			// Scr1
			DRAW_SPRITE_VM_ONSCR3()

			inr l ; Y + 1

            dcr e
            jnz @width16_loop
			jmp draw_sprite_onscr_ret


; render a sprite width24
; in:
; sp - sprite gfx
; hl - scr addr
; e - height
draw_sprite_onscr_w24:
            ; d=1
			mov a, h
			sta @width24_offset00 + 1
			add d
			sta @width24_offset01 + 1
		    add d
			sta @width24_offset02 + 1
			adi 0x20 - 2
			sta @width24_offset20 + 1
			sta @width24_offset20_2 + 1
			add d
			sta @width24_offset21 + 1
			sta @width24_offset21_2 + 1
			add d
			sta @width24_offset22 + 1
			sta @width24_offset22_2 + 1
			adi 0x40 - 0x22
			sta @width24_offset40 + 1
			add d
			sta @width24_offset41 + 1
			add d
			sta @width24_offset42 + 1

@width24_loop:
// odd line from left to right
// first byte
    		// Scr1
			DRAW_SPRITE_VM_ONSCR1()

@width24_offset20:
			mvi h, TEMP_BYTE ; init_x + 0x20

			// Scr2
			DRAW_SPRITE_VM_ONSCR2()

@width24_offset40:
			mvi h, TEMP_BYTE ; init_x + 0x40

			// Scr3
			DRAW_SPRITE_VM_ONSCR3()

			inr h ; X + 1
			; 32*4=

// second byte

			// Scr3
			DRAW_SPRITE_VM_ONSCR1()

@width24_offset21:
			mvi h, TEMP_BYTE ; init_x + 0x21

			// Scr2
			DRAW_SPRITE_VM_ONSCR2()

@width24_offset01:
			mvi h, TEMP_BYTE ; init_x + 0x01

			// Scr1
			DRAW_SPRITE_VM_ONSCR3()

			inr h ; X + 1

// last byte

			// Scr1
			DRAW_SPRITE_VM_ONSCR1()

@width24_offset22:
			mvi h, TEMP_BYTE ; init_x + 0x22

			// Scr2
			DRAW_SPRITE_VM_ONSCR2()

@width24_offset42:
			mvi h, TEMP_BYTE ; init_x + 0x42

			// Scr3
			DRAW_SPRITE_VM_ONSCR3()

			inr l ; Y + 1

			dcr e
			jz draw_sprite_onscr_ret

// even line from right to left
// last byte
    		// Scr3
			DRAW_SPRITE_VM_ONSCR1()

@width24_offset22_2:
			mvi h, TEMP_BYTE ; init_x + 0x22

			// Scr2
			DRAW_SPRITE_VM_ONSCR2()

@width24_offset02:
			mvi h, TEMP_BYTE ; init_x + 0x02

			// Scr1
			DRAW_SPRITE_VM_ONSCR3()

			dcr h ; X - 1

// second byte

			// Scr1
			DRAW_SPRITE_VM_ONSCR1()

@width24_offset21_2:
			mvi h, TEMP_BYTE ; init_x + 0x21

			// Scr2
			DRAW_SPRITE_VM_ONSCR2()

@width24_offset41:
			mvi h, TEMP_BYTE ; init_x + 0x41

			// Scr3
			DRAW_SPRITE_VM_ONSCR3()

			dcr h ; X - 1

// last byte

			// Scr3
			DRAW_SPRITE_VM_ONSCR1()

@width24_offset20_2:
			mvi h, TEMP_BYTE ; init_x + 0x20

			// Scr2
			DRAW_SPRITE_VM_ONSCR2()

@width24_offset00:
			mvi h, TEMP_BYTE ; init_x + 0x00

			// Scr1
			DRAW_SPRITE_VM_ONSCR3()

			inr l ; Y + 1

            dcr e
            jnz @width24_loop
			jmp draw_sprite_onscr_ret



; 9*4=36cc
.macro DRAW_SPRITE_VM_ONSCR1()
			pop b ; b - color, c - mask
			mov a, m
			ana c
			ora b
			mov m, a
			mov d, c
.endmacro

; 9*4=36cc
; in:
; d - mask
.macro DRAW_SPRITE_VM_ONSCR2()
			mov a, m
			ana d
			pop b ; c - color, b - color
			ora c
			mov m, a
.endmacro

; 6*4=24cc
; in:
; d - mask
.macro DRAW_SPRITE_VM_ONSCR3()
			mov a, m
			ana d
			ora b
			mov m, a
.endmacro

.endopt