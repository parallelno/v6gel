@memusage_v6_sprite_copy_to_scr:
; copy a sprite from the back buff to the screen
; in:
; de - scr addr
; b - width
;		00 - 8pxs,
;		01 - 16pxs,
;		10 - 24pxs,
;		11 - 32pxs
; c - height

sprite_copy_to_scr_v:
			; store sp
			lxi h, 0
			dad	sp
			shld restore_sp + 1

			; Y -= 1 because we start copying bytes with dec Y
			inr e

// 			; w=max(h, SPRITE_COPY_TO_SCR_H_MAX)
// 			mvi a, SPRITE_COPY_TO_SCR_W_PACKED_MAX
// 			cmp b
// 			jnc @skipMaxW
// @maxW:
// 			mvi b, SPRITE_COPY_TO_SCR_W_PACKED_MAX
// @skipMaxW:

			; h=max(h, SPRITE_COPY_TO_SCR_H_MAX)

// .if DEBUG
// 	.breakpoint "C > 0x14 h > SPRITE_COPY_TO_SCR_H_MAX"
// .endif
			mov a, c
// .if DEBUG
// 	.breakpoint "C < 0x5 h < SPRITE_COPY_TO_SCR_H_MIN"
// .endif

			/*
			TODO: BUG
			; h=max(h, SPRITE_COPY_TO_SCR_H_MAX)
			; clamp doesn't work. it leaves remaining pieces of sprites on the screen
			*/
			cpi SPRITE_COPY_TO_SCR_H_MAX
			jc @skipMaxH
@maxH:
			mvi a, SPRITE_COPY_TO_SCR_H_MAX
@skipMaxH:

			; BC = an offset in the copy routine table
			ADD_A(2) ; to make a JMP_4 ptr

			mov c, a
			mov a, b ; temp a = width
			mvi b, 0

			; hl - an addr of a copy routine
			lxi h, @copy_routine_addrs - SPRITE_COPY_TO_SCR_H_MIN * JMP_4_LEN
			dad b
			; run the copy routine
			pchl

@h05:		COPY_SPRITE_TO_SCR(5)
@h06:		COPY_SPRITE_TO_SCR(6)
@h07:		COPY_SPRITE_TO_SCR(7)
@h08:		COPY_SPRITE_TO_SCR(8)
@h09:		COPY_SPRITE_TO_SCR(9)
@h10:		COPY_SPRITE_TO_SCR(10)
@h11:		COPY_SPRITE_TO_SCR(11)
@h12:		COPY_SPRITE_TO_SCR(12)
@h13:		COPY_SPRITE_TO_SCR(13)
@h14:		COPY_SPRITE_TO_SCR(14)
@h15:		COPY_SPRITE_TO_SCR(15)
@h16:		COPY_SPRITE_TO_SCR(16)
@h17:		COPY_SPRITE_TO_SCR(17)
@h18:		COPY_SPRITE_TO_SCR(18)
@h19:		COPY_SPRITE_TO_SCR(19)
@h20:		COPY_SPRITE_TO_SCR(20)

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

.macro COPY_SPRITE_TO_SCR_PB(move_up = true)
			pop b
			mov m, c
			inr l
			mov m, b
		.if move_up == true
			inr l
		.endif
.endmacro
.macro COPY_SPRITE_TO_SCR_B()
			pop b
			mov m, c
.endmacro

.macro COPY_SPRITE_TO_SCR_LOOP(height, height_odd)
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

.macro COPY_SPRITE_TO_SCR(height)
			height_odd = (height / 2)*2 != height
			; hl - scr addr
			xchg
			; d - width
			mov d, a
			; to restore X
			mov e, h

@next_column:
			RAM_DISK_ON(RAM_DISK_S_BACKBUFF | RAM_DISK_M_BACKBUFF | RAM_DISK_M_8F)
			; read with non-stack operations because we must load BC before
			; using POP B
			mov b, m
			dcr l
			mov c, m
			/* TODO: Optimization: Instead of executing extra code to prevent data
			corruption by the interruption break, we can do the following: When a
			draw function starts, we set the interruption function return address
			to the start of the draw function. If an interruption break occurs
			during a draw function call, the interruption restarts the draw
			function, guaranteeing that the data will not be corrupted. In short,
			we call the draw function again if the interruption occurs.*/
			RAM_DISK_ON(RAM_DISK_S_BACKBUFF)

			mov m, c
			inr l
			mov m, b
			inr l
			sphl

			COPY_SPRITE_TO_SCR_LOOP(height, height_odd)

			; advance Y to the bottom of the sprite, X to the next scr buff
	.if height_odd
			lxi h, $2000-height+2-1-1
	.endif
	.if height_odd == false
			lxi h, $2000-height+2-1
	.endif
			dad sp
			; set SP to a STACK_TEMP_ADDR, for the case when an interruption call
			; happens between sta and out $10 in RAM_DISK_ON(RAM_DISK_S_BACKBUFF)
			; in the code above
			lxi sp, STACK_TEMP_ADDR

			jnc @next_column
			; advance Y to the next column
			inr e
			mov h, e
			dcr d
			jp @next_column
			jmp restore_sp
.endmacro