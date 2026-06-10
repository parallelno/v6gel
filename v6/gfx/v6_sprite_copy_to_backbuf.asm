@memusage_v6_sprite_copy_to_backbuf:
; copy a sprite from backbuff1 to backbuff2
; in:
; de - scr addr
; h - width
;		00 - 8pxs,
;		01 - 16pxs,
;		10 - 24pxs,
;		11 - 32pxs
; l - height

; TODO: this func is giant. the size of this func is 1219 bytes. think of a better solution
sprite_copy_to_back_buff_v:
			; Y -= 1 because we start copying bytes with dec Y
			inr e

			; h=min(h, SPRITE_COPY_TO_SCR_H_MAX)
			mov a, l
			cpi SPRITE_COPY_TO_SCR_H_MAX
			jc @do_not_set_min
@set_min:
			mvi a, SPRITE_COPY_TO_SCR_H_MAX
@do_not_set_min:

			; BC = an offset in the copy routine table
			ADD_A(2)	; to make a JMP_4 ptr
			mov c, a
			mvi b, 0
			; temp a = width
			mov a, h

			; store sp
			lxi h, 0
			dad	sp
			shld restore_sp + 1

			; hl - an addr of a copy routine
			lxi h, @copy_routine_addrs - SPRITE_COPY_TO_SCR_H_MIN * JMP_4_LEN
			dad b
			; run the copy routine
			pchl

@h05:		COPY_SPRITE_TO_SCR2(5)
@h06:		COPY_SPRITE_TO_SCR2(6)
@h07:		COPY_SPRITE_TO_SCR2(7)
@h08:		COPY_SPRITE_TO_SCR2(8)
@h09:		COPY_SPRITE_TO_SCR2(9)
@h10:		COPY_SPRITE_TO_SCR2(10)
@h11:		COPY_SPRITE_TO_SCR2(11)
@h12:		COPY_SPRITE_TO_SCR2(12)
@h13:		COPY_SPRITE_TO_SCR2(13)
@h14:		COPY_SPRITE_TO_SCR2(14)
@h15:		COPY_SPRITE_TO_SCR2(15)
@h16:		COPY_SPRITE_TO_SCR2(16)
@h17:		COPY_SPRITE_TO_SCR2(17)
@h18:		COPY_SPRITE_TO_SCR2(18)
@h19:		COPY_SPRITE_TO_SCR2(19)
@h20:		COPY_SPRITE_TO_SCR2(20)

@copy_routine_addrs:
			JMP_4(@h05)
			JMP_4(@h06)
			JMP_4(@h07)
			JMP_4(@h08)
			JMP_4(@h09)
			JMP_4(@h10)
			JMP_4(@h11)
			JMP_4(@h12)
			JMP_4(@h13)
			JMP_4(@h14)
			JMP_4(@h15)
			JMP_4(@h16)
			JMP_4(@h17)
			JMP_4(@h18)
			JMP_4(@h19)
			JMP_4(@h20)

.macro COPY_SPRITE_TO_SCR_PB2(move_up = true)
			pop b
			mov m, c
			inr l
			mov m, b
		.if move_up == true
			inr l
		.endif
.endmacro
.macro COPY_SPRITE_TO_SCR_B2()
			pop b
			mov m, c
.endmacro

.macro COPY_SPRITE_TO_SCR_LOOP2(height)
			height_odd = (height / 2)*2 != height

	.if height_odd
		.loop height / 2 - 1
			COPY_SPRITE_TO_SCR_PB()
		.endloop
			COPY_SPRITE_TO_SCR_B()
	.endif
	.if height_odd == false
		.loop height / 2 - 2
			COPY_SPRITE_TO_SCR_PB()
		.endloop
			COPY_SPRITE_TO_SCR_PB(false)
	.endif
.endmacro

.macro COPY_SPRITE_TO_SCR2(height)
			; hl - scr addr
			xchg
			; d - width
			mov d, a
@next_column:
			RAM_DISK_ON(RAM_DISK_S_BACKBUFF2 | RAM_DISK_M_BACKBUFF2 | RAM_DISK_M_8F)
			; read without a stack operations because
			; we need fill up BC prior to use POP B
			mov b, m
			dcr l
			mov c, m
			RAM_DISK_ON(RAM_DISK_S_BACKBUFF2 | RAM_DISK_M_BACKBUFF | RAM_DISK_M_8F)

			mov m, c
			inr l
			mov m, b
			inr l
			sphl

			COPY_SPRITE_TO_SCR_LOOP2(height)

			; set SP to STACK_TEMP_ADDR to be able to use BC not only for "POP B"
			lxi sp, STACK_TEMP_ADDR
			; advance Y down and to the next scr buff
			lxi b, SCR_BUFF_LEN - height + 2
			dad b

			jnc @next_column
			; advance Y to the next column
			mvi a, -(>SCR_BUFF_LEN) * 3 + 1
			add h
			mov h, a
			dcr d
			jp @next_column
			jmp restore_sp
.endmacro