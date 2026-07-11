@memusage_v6_sprite_draw_hit:
; =============================================
;
; OLD! the sprite format got changed
;
; =============================================
; Draw a monochrome sprite with a mask in three consiquence screen buffs with offset_x and offset_y
; it is used for hit indication
; width is 1-3 bytes
; height is 0-255
; offset_x in bytes
; offset_y in pixels
; it uses sp to read the sprite data
; ex. CALL_RAM_DISK_FUNC(sprite_draw_hit_vm, RAM_DISK_S_HERO_ATTACK01 | RAM_DISK_? | RAM_DISK_M_8F)
; input:
; bc	sprite data
; de	screen addr
; use: a, hl, sp

; Data Layout:
; .word - two safety bytes prevent data corruption caused by interruptions
; .byte - offset_y
; .byte - offset_x
; .byte - height
; .byte - width
; 		0 - one byte width,
;		1 - two bytes width,
;		2 - three bytes width

; pixel format:
; 1st screen buff : 1 -> 2
; 2nd screen buff : 4 <- 3
; 3rd screen buff : 6 <- 5
; y++
; 3rd screen buff : 7 -> 8
; 2nd screen buff : 10 <- 9
; 1st screen buff : 12 <- 11
; y++
; repeat for the next lines of the art data

//		IT IS NOT RECOMMENDED TO USE
//		BECAUSE OF THE RISK OF DATA CORRUPTION
//		RAM_DISK_ON_BANK macro must not be used before calling a function!
//		check the reqs of RAM_DISK_ON_BANK_NO_RESTORE before using it here
/*
sprite_draw_hit_vm:	; VM stands for: V - variable height, M - mask support
			; store SP
			lxi h, 0
			dad sp
			shld sprite_draw_restore_sp_ram_disk + 1
			; sp = BC
			mov	h, b
			mov	l, c
			sphl
			xchg
			; b - offset_x
			; c - offset_y
			pop b
			dad b
			; store a sprite screen addr to return it from this func
			shld sprite_draw_scr_addr_ram_disk + 1

			; store sprite width and height
			; b - width, c - height
			pop b
			mov d, b
			mov e, c
			xchg
			shld sprite_draw_width_height_ram_disk + 1
			xchg
			mov a, b
			rrc
			jc @width16
			rrc
			jc @width24
			jmp @width8


;------------------------------------------------
@width16:
			; save the high screen byte to restore X
			rlc
			add h
			sta @w16oddScr1 + 1
			adi $20
			mov d, a
			adi $20
			sta @w16evenScr3 + 1

@w16evenScr1:
			SPRITE_DRAW_HIT_VM()
			inr h
			SPRITE_DRAW_HIT_VM()
@w16evenScr2:
			mov h, d
			SPRITE_DRAW_HIT_VM(false)
			dcr h
			SPRITE_DRAW_HIT_VM(false)
@w16evenScr3:
			mvi h, TEMP_BYTE
			SPRITE_DRAW_HIT_VM()
			dcr h
			SPRITE_DRAW_HIT_VM()
			inr l
			dcr e
			jz sprite_draw_ret_ram_disk

@w16oddScr3:
			SPRITE_DRAW_HIT_VM()
			inr h
			SPRITE_DRAW_HIT_VM()
@w16oddScr2:
			mov h, d
			SPRITE_DRAW_HIT_VM(false)
			dcr h
			SPRITE_DRAW_HIT_VM(false)
@w16oddScr1:
			mvi h, TEMP_BYTE
			SPRITE_DRAW_HIT_VM()
			dcr h
			SPRITE_DRAW_HIT_VM()
			inr l
			dcr e
			jnz @w16evenScr1
			jmp sprite_draw_ret_ram_disk
;-------------------------------------------------
@width24:
			; save the high screen byte to restore X
			mvi a, 2
			add h
			sta @w24oddScr1 + 1
			adi $20
			mov d, a
			adi $20
			sta @w24evenScr3 + 1

@w24evenScr1:
			SPRITE_DRAW_HIT_VM()
			inr h
			SPRITE_DRAW_HIT_VM()
			inr h
			SPRITE_DRAW_HIT_VM()

@w24evenScr2:
			mov h, d
			SPRITE_DRAW_HIT_VM(false)
			dcr h
			SPRITE_DRAW_HIT_VM(false)
			dcr h
			SPRITE_DRAW_HIT_VM(false)

@w24evenScr3:
			mvi h, TEMP_BYTE
			SPRITE_DRAW_HIT_VM()
			dcr h
			SPRITE_DRAW_HIT_VM()
			dcr h
			SPRITE_DRAW_HIT_VM()
			inr l
			dcr e
			jz sprite_draw_ret_ram_disk

@w24oddScr3:
			SPRITE_DRAW_HIT_VM()
			inr h
			SPRITE_DRAW_HIT_VM()
			inr h
			SPRITE_DRAW_HIT_VM()
@w24oddScr2:
			mov h, d
			SPRITE_DRAW_HIT_VM(false)
			dcr h
			SPRITE_DRAW_HIT_VM(false)
			dcr h
			SPRITE_DRAW_HIT_VM(false)
@w24oddScr1:
			mvi h, TEMP_BYTE
			SPRITE_DRAW_HIT_VM()
			dcr h
			SPRITE_DRAW_HIT_VM()
			dcr h
			SPRITE_DRAW_HIT_VM()
			inr l
			dcr e
			jnz @w24evenScr1
			jmp sprite_draw_ret_ram_disk
;------------------------------------------------------
@width8:
			; save the high screen byte to restore X
			mov a, h
			sta @w8oddScr1 + 1
			adi $20
			mov d, a
			adi $20
			sta @w8evenScr3 + 1

@w8evenScr1:
			SPRITE_DRAW_HIT_VM()
@w8evenScr2:
			mov h, d
			SPRITE_DRAW_HIT_VM(false)
@w8evenScr3:
			mvi h, TEMP_BYTE
			SPRITE_DRAW_HIT_VM()
			inr l
			dcr e
			jz sprite_draw_ret_ram_disk
@w8oddScr3:
			SPRITE_DRAW_HIT_VM()
@w8oddScr2:
			mov h, d
			SPRITE_DRAW_HIT_VM(false)
@w8oddScr1:
			mvi h, TEMP_BYTE
			SPRITE_DRAW_HIT_VM()
			inr l
			dcr e
			jnz @w8evenScr1
			jmp sprite_draw_ret_ram_disk

.macro SPRITE_DRAW_HIT_VM(fill = true)
			pop b
			.if fill
				mov a, c
				cma
				ora m
			.endif
			.if fill == false
				mov a, m
				ana c
			.endif
			mov m, a
.endmacro
*/