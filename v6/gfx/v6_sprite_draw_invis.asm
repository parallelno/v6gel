@memusage_v6_sprite_draw_invis:
; =============================================
; It does not draw a sprite, but saves a return scr addr, width, height
; it is used for invinceble status
; it uses sp to read the sprite data
; ex. CALL_RAM_DISK_FUNC(sprite_draw_invis_vm, RAM_DISK_S_HERO_ATTACK01 | RAM_DISK_? | RAM_DISK_M_8F)
; input:
; bc	sprite data
; de	screen addr
; use: a, hl, sp

sprite_draw_invis_vm:	; VM stands for: V - variable height, M - mask support
			; store SP
			lxi h, 0
			dad sp
			shld draw_sprite_restore_sp + 1
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
			shld draw_sprite_scr_addr + 1

			; store sprite width and height
			; b - width, c - height
			pop b
			mov d, b
			mov e, c
			xchg
			shld draw_sprite_width_height + 1
			jmp draw_sprite_ret