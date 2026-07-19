@memusage_v6_tile_draw:
.global draw_tile_16x16

;----------------------------------------------------------------
; draw a tile (16x16 pixels)
; this graphics is used to render level rooms.
; This func can read gfx data from the RAM Disk if it's properly activated
; input:
; bc - a tile gfx ptr
; de - screen addr
; use: a, hl, sp

; tile gfx format:
; .byte - a bit mask xxxxECA8:
;		If "8" bit is enabled, draw the next 16 bytes in the $8000 buffer,
;		If "A" bit is enabled, draw the next 16 bytes in the $A000 buffer etc.
; .byte 4 - needs for a counter
; screen format:
; SCR_BUFF0_ADDR : draw 16 bytes down, step one byte right, draw 16 bytes up.
; SCR_BUFF1_ADDR : same
; SCR_BUFF2_ADDR : same
; SCR_BUFF3_ADDR : same

draw_tile_16x16:
			; store sp
			lxi h, $0000
			dad sp
			shld @restore_sp + 1
			; sp = BC
			mov h, b
			mov l, c
			sphl
			; get a mask and a counter
			pop b
			xchg
			mov e, c
			mov d, b

; HL - screen buff addr
; SP - sprite data
; E - contains a bit mask xxxxECA8
;   "8" bit - draw in $8000 buffer
;   "A" bit - draw in $A000 buffer etc.
; D - counter of screen buffers
@loop:
			mov a, e
			rrc
			mov e, a
			jnc @erase_tile_buf

			DRAWTILE16x16_DRAW_BUF()
			jmp @next_buf

@erase_tile_buf:
			DRAWTILE16x16_ERASE_BUF()
@next_buf:
			; move X to the next scr buff
			mvi a, $20
			add h
			mov h, a

			dcr d
			jnz @loop
@restore_sp:
			lxi sp, TEMP_ADDR
			ret
draw_tile_16x16_end:


.macro DRAWTILE16x16_DRAW_BUF()
		.loop 7
			pop b					; (12)
			mov m, c				; (8)
			inr l					; (8)
			mov m, b				; (8)
			inr l					; (8)
		.endloop
			pop b					; (12)
			mov m, c				; (8)
			inr l					; (8)
			mov m, b				; (8)

			inr h					; (8)
		.loop 7
			pop b					; (12)
			mov m, c				; (8)
			dcr l					; (8)
			mov m, b				; (8)
			dcr l					; (8)
		.endloop
			pop b					; (12)
			mov m, c				; (8)
			dcr l					; (8)
			mov m, b				; (8)
			dcr h					; (8) (704)
.endmacro

.macro DRAWTILE16x16_ERASE_BUF()
			A_TO_ZERO(NULL)
		.loop 15
			mov m, a
			inr l
		.endloop
			mov m, a
			inr h
		.loop 15
			mov m, a
			dcr l
		.endloop
			mov m, a
			dcr h
.endmacro
