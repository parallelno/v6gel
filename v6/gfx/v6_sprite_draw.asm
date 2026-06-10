@memusage_v6_sprite_draw:
; sharetable chunk of code to restore SP and
; return a couple of parameters within HL, C
draw_sprite_ret:
draw_sprite_restore_sp:
			lxi sp, TEMP_ADDR
draw_sprite_scr_addr:
			lxi b, TEMP_ADDR
draw_sprite_width_height:
; d - width
;		00 - 8pxs,
;		01 - 16pxs,
;		10 - 24pxs,
;		11 - 32pxs,
; e - height
			lxi d, TEMP_WORD
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
; out:
; d - width
;		00 - 8pxs,
;		01 - 16pxs,
;		10 - 24pxs
; e - height
; bc - sprite screen addr + offset
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
; odd line from left to right
; mask, color_scr1, color_scr2, color_scr3
; even line from right to left
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


sprite_draw_vm:	; VM stands for: V - variable height, M - mask support
			; store SP
			lxi h, 0
			dad sp
			shld draw_sprite_restore_sp + 1
			; sp = BC
			mov	h, b
			mov	l, c
			sphl
			xchg
			pop b
			; b - offset_x
			; c - offset_y
			dad b
			; store a sprite screen addr to return it from this func
			shld draw_sprite_scr_addr + 1
			; hl - sprite screen addr + offset

			; store sprite width and height
			pop b
			mov d, b
			mov e, c
			xchg
			; h, b - width
			; l, c - height
			shld draw_sprite_width_height + 1
			xchg
			; d, b - width
			; e, c - height
			mov a, b
			rrc
			jc @width16
			rrc
			jc @width24
			jmp @width8

@width8:
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
			DRAW_SPRITE_VM1()

@width8_offset20:
			mvi h, TEMP_BYTE ; init_x + 0x20

			// Scr2
			DRAW_SPRITE_VM2()

@width8_offset40:
			mvi h, TEMP_BYTE ; init_x + 0x40

			// Scr3
			DRAW_SPRITE_VM3()

			inr l ; Y + 1
			dcr e
			jz draw_sprite_ret

// even line from right to left
// first byte
    		// Scr3
			DRAW_SPRITE_VM1()

@width8_offset20_2:
			mvi h, TEMP_BYTE ; init_x + 0x20

			// Scr2
			DRAW_SPRITE_VM2()

@width8_offset00:
			mvi h, TEMP_BYTE ; init_x + 0x00

			// Scr1
			DRAW_SPRITE_VM3()

			inr l ; Y + 1
            dcr e
            jnz @width8_loop
			jmp draw_sprite_ret


@width16:
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
			DRAW_SPRITE_VM1()

@width16_offset20:
			mvi h, TEMP_BYTE ; init_x + 0x20

			// Scr2
			DRAW_SPRITE_VM2()

@width16_offset40:
			mvi h, TEMP_BYTE ; init_x + 0x40

			// Scr3
			DRAW_SPRITE_VM3()

			inr h ; X + 1

// last byte

			// Scr3
			DRAW_SPRITE_VM1()

@width16_offset21:
			mvi h, TEMP_BYTE ; init_x + 0x21

			// Scr2
			DRAW_SPRITE_VM2()

@width16_offset01:
			mvi h, TEMP_BYTE ; init_x + 0x01

			// Scr1
			DRAW_SPRITE_VM3()

			inr l ; Y + 1

			dcr e
			jz draw_sprite_ret

// even line from right to left
// last byte
    		// Scr1
			DRAW_SPRITE_VM1()

@width16_offset21_2:
			mvi h, TEMP_BYTE ; init_x + 0x21

			// Scr2
			DRAW_SPRITE_VM2()

@width16_offset41:
			mvi h, TEMP_BYTE ; init_x + 0x41

			// Scr3
			DRAW_SPRITE_VM3()

			dcr h ; X - 1

// first byte

			// Scr3
			DRAW_SPRITE_VM1()

@width16_offset20_2:
			mvi h, TEMP_BYTE ; init_x + 0x20

			// Scr2
			DRAW_SPRITE_VM2()

@width16_offset00:
			mvi h, TEMP_BYTE ; init_x + 0x00

			// Scr1
			DRAW_SPRITE_VM3()

			inr l ; Y + 1

            dcr e
            jnz @width16_loop
			jmp draw_sprite_ret

@width24:
			mov a, h
			sta @width24_offset00 + 1
			inr a
			sta @width24_offset01 + 1
			inr a
			sta @width24_offset02 + 1
			adi 0x20 - 2
			sta @width24_offset20 + 1
			sta @width24_offset20_2 + 1
			inr a
			sta @width24_offset21 + 1
			sta @width24_offset21_2 + 1
			inr a
			sta @width24_offset22 + 1
			sta @width24_offset22_2 + 1
			adi 0x40 - 0x22
			sta @width24_offset40 + 1
			inr a
			sta @width24_offset41 + 1
			inr a
			sta @width24_offset42 + 1

@width24_loop:
// odd line from left to right
// first byte
    		// Scr1
			DRAW_SPRITE_VM1()

@width24_offset20:
			mvi h, TEMP_BYTE ; init_x + 0x20

			// Scr2
			DRAW_SPRITE_VM2()

@width24_offset40:
			mvi h, TEMP_BYTE ; init_x + 0x40

			// Scr3
			DRAW_SPRITE_VM3()

			inr h ; X + 1
			; 32*4=

// second byte

			// Scr3
			DRAW_SPRITE_VM1()

@width24_offset21:
			mvi h, TEMP_BYTE ; init_x + 0x21

			// Scr2
			DRAW_SPRITE_VM2()

@width24_offset01:
			mvi h, TEMP_BYTE ; init_x + 0x01

			// Scr1
			DRAW_SPRITE_VM3()

			inr h ; X + 1

// last byte

			// Scr1
			DRAW_SPRITE_VM1()

@width24_offset22:
			mvi h, TEMP_BYTE ; init_x + 0x22

			// Scr2
			DRAW_SPRITE_VM2()

@width24_offset42:
			mvi h, TEMP_BYTE ; init_x + 0x42

			// Scr3
			DRAW_SPRITE_VM3()

			inr l ; Y + 1

			dcr e
			jz draw_sprite_ret

// even line from right to left
// last byte
    		// Scr3
			DRAW_SPRITE_VM1()

@width24_offset22_2:
			mvi h, TEMP_BYTE ; init_x + 0x22

			// Scr2
			DRAW_SPRITE_VM2()

@width24_offset02:
			mvi h, TEMP_BYTE ; init_x + 0x02

			// Scr1
			DRAW_SPRITE_VM3()

			dcr h ; X - 1

// second byte

			// Scr1
			DRAW_SPRITE_VM1()

@width24_offset21_2:
			mvi h, TEMP_BYTE ; init_x + 0x21

			// Scr2
			DRAW_SPRITE_VM2()

@width24_offset41:
			mvi h, TEMP_BYTE ; init_x + 0x41

			// Scr3
			DRAW_SPRITE_VM3()

			dcr h ; X - 1

// last byte

			// Scr3
			DRAW_SPRITE_VM1()

@width24_offset20_2:
			mvi h, TEMP_BYTE ; init_x + 0x20

			// Scr2
			DRAW_SPRITE_VM2()

@width24_offset00:
			mvi h, TEMP_BYTE ; init_x + 0x00

			// Scr1
			DRAW_SPRITE_VM3()

			inr l ; Y + 1

            dcr e
            jnz @width24_loop
			jmp draw_sprite_ret



; 9*4=36cc
.macro DRAW_SPRITE_VM1()
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
.macro DRAW_SPRITE_VM2()
			mov a, m
			ana d
			pop b ; c - color, b - color
			ora c
			mov m, a
.endmacro

; 6*4=24cc
; in:
; d - mask
.macro DRAW_SPRITE_VM3()
			mov a, m
			ana d
			ora b
			mov m, a
.endmacro