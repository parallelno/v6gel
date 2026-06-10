@memusage_v6_text_ex_draw:

.include "asm/v6/v6_text_ex_consts.asm"

LINE_SPACING_DEFAULT = -12
PARAG_SPACING_DEFAULT = -24

; set a default line and a paragraph spacing
text_ex_reset_spacing:
			mvi a, LINE_SPACING_DEFAULT
			sta text_ex_line_spacing + 1

			mvi a, PARAG_SPACING_DEFAULT
			sta text_ex_parag_spacing + 1
			ret

; set a line and a paragraph spacing
; in:
; c - line spacing
; b - paragraph spacing
text_ex_set_spacing:
			lxi h, text_ex_line_spacing + 1
			mov m, c
			lxi h, text_ex_parag_spacing + 1
			mov m, b
			ret

; set what scr buffers to draw to (SCR_BUFF3_ADDR, SCR_BUFF2_ADDR, SCR_BUFF1_ADDR)
; in:
; a - SCR_BUFF3_ADDR or SCR_BUFF2_ADDR or SCR_BUFF1_ADDR
text_ex_set_scr_addr:
			sta text_ex_scr_buff_addr + 1
			ret

; init the font gfx data
; in:
; a - font gfx RAM Disk stack activation command
; hl - font_gfx_ptrs
; bc - font global gfx addr (points to where gfx was loaded)
text_ex_init_font:
			; set font gfx RAM Disk stack activation command
			sta text_ex_draw_ramdisk_access_gfx + 1
			; hl - font_gfx_ptrs
			push h
			; font_gfx_ptrs - ADDR_LEN because there is no char_code = 0
			dcx h
			dcx h
			shld text_ex_draw_font_gfx_ptrs + 1
			pop h

			; update gfx local labels
			; hl - font_gfx_ptrs with local ptrs
			; bc - font global gfx addr
			call add_offset_to_labels_eod
			ret

; init the text data
; in:
; a - text data RAM Disk activation command
; hl - text data addr (points to the addr where it was loaded)
text_ex_init_text:
			; set text data RAM Disk activation command
			sta text_ex_draw_ramdisk_access_data + 1
			; set text data addr
			shld text_ex_draw_data_addr + 1
			ret


; draw a text with kerning
; in:
; de - local text addr

; if called text_ex_draw_pos_offset_set
; in:
; de - local text addr
; hl - scr_pos offset

; blend func - OR
; chat gfx Data Layout:
;	.byte offset_y
;	.byte offset_x
;	.word 16 pxls data. the first 8 pixels are empty to support shifting
;	.byte pos_y_offset for the next char
;	.byte pos_x_offset for the next char
;	because the second byte of the each char line is 0, the sufficient
;	condition of the end of the char data is a non zero byte which is pos_x_offset
; chat gfx data always follows safety pair of bytes for reading by POP B

; text Data Layout:
;	.word data len to copy to ram
; 	.byte scr pos_x
;	.byte scr pos_y
;	.byte char codes where 0 is the EOD, 255 is a new paragraph, 106 is a new line
;
;	before rendering a text its text is copied to the ram. Copied data does not
;	contain the length word.
; text data always follows safety pair of bytes for reading by POP B
text_ex_draw:
			lxi h, 0
text_ex_draw_pos_offset_set:
			shld text_ex_draw_pos_offset + 1
			; de - text data addr in the RAM Disk
text_ex_draw_data_addr:
			lxi h, TEMP_ADDR
			dad d
			push h
			xchg
text_ex_draw_ramdisk_access_data:
			mvi a, TEMP_BYTE
			push psw
			; a - idx data RAM Disk activation command
			; de - points to the idx data len
			call get_word_from_ram_disk
			; bc = idxs_data_len
			lxi d, temp_buff
			pop psw
			pop h
			inx h
			inx h

			; hl - text_data addr + 2, because the first two bytes are the length
			; de - temp_buff addr
			; bc - length
			; a - RAM Disk activation command
			; copy text data into a temp buffer
			call mem_copy_from_ram_disk

text_ex_draw_ramdisk_access_gfx:
			mvi a, TEMP_BYTE
			RAM_DISK_ON_BANK()
			lxi h, 0x0000
			dad sp
			shld restore_sp + 1

			lxi h, temp_buff
			; get scr pos
			; add scr pos offset
text_ex_draw_pos_offset:
			lxi b, TEMP_WORD
			mov e, m
			inx h
			mov d, m
			inx h
			xchg
			dad b
			xchg
			; de - scr pos


			; store pos_x
			mov a, d
			sta text_ex_restore_pos_x + 1
			mov b, d
			mov c, e


			; bc - scr pos
			; hl - text addr
text_ex_draw_next_char:
			; get a char code
			mov e, m
			; return if it's 0
			A_TO_ZERO(NULL)
			ora e
			jz restore_sp
			inx h

			; a - char_code
			; check if it is the end of the line
			cpi <_LINE_BREAK_
			jz text_ex_line_spacing
			; check if it is the end of the line
			cpi <_PARAG_BREAK_
			jz text_ex_parag_spacing

			shld text_ex_draw_restore_text_addr + 1  ; preserve the text data ptr
			; preserve pos_xy
			mov a, c
			sta text_ex_draw_restore_pos_xy + 1
			mov a, b
			sta text_ex_draw_restore_pos_xy + 2

			; get a char gfx pptr
			xchg
 			; l = char_idx
			mvi h, 0
			dad h
text_ex_draw_font_gfx_ptrs:
			lxi d, TEMP_ADDR ; font_gfx_ptrs - ADDR_LEN ; because there is no char_code = 0
			dad d
			; hl points to char gfx ptr
			; get a char gfx ptr
			mov e, m
			inx h
			mov d, m
			xchg
			; hl points to a char gfx

			sphl
			mov h, b
			mov l, c
			; hl - scr pos

			; add a pos_xy offset
			pop b
			dad b

			; calc a pxl shift
			mvi a, %111
			ana h
			; make a ptr to skip_dad dad h
			; de = a * 2 + text_ex_draw_skip_dad_ptrs
			DE_TO_AX2_PLUS_INT16(text_ex_draw_skip_dad_ptrs)

			; read skip_ptr
			xchg
			mov a, m
			inx h
			mov h, m
			mov l, a
			shld text_ex_draw_skip_dad + 1

			; de - scr pos
			; pos_xy to scr addr
			mvi a, %11111000
			ana d
			RRC_(3)
text_ex_scr_buff_addr:
			adi >SCR_BUFF1_ADDR
			mov d, a

			; draw a char
text_ex_draw_loop:
			; de - scr addr
			; shift a pair of gfx bytes
			pop b
			; check if it is the end of the char gfx
			A_TO_ZERO(NULL)
			ora b
			jnz text_ex_draw_advance_pos
			mov l, c
			mov h, b

			; shift char gfx runtime
			; depending on the char pos
text_ex_draw_skip_dad:	jmp TEMP_ADDR

text_ex_draw_shift1:	dad h
text_ex_draw_shift2:	dad h
text_ex_draw_shift3:	dad h
text_ex_draw_shift4:	dad h
text_ex_draw_shift5:	dad h
text_ex_draw_shift6:	dad h
text_ex_draw_shift7:	dad h

			ldax d
			ora h
			stax d
			inr d
			ldax d
			ora l
			stax d
			dcr d
			inr e
			jmp text_ex_draw_loop

text_ex_draw_shift0:
			ldax d
			ora c
			stax d
			inr e
			jmp text_ex_draw_loop

text_ex_draw_advance_pos:
			; bc - a pos offset
			lxi sp, STACK_TEMP_ADDR
text_ex_draw_restore_pos_xy:
			lxi h, TEMP_WORD ; restore pos_xy
			; advance a pos_xy to the next char
			dad b
			mov b, h
			mov c, l
text_ex_draw_restore_text_addr:
			lxi h, TEMP_ADDR ; retore text addr
			jmp text_ex_draw_next_char

; move a position to the next paragraph
text_ex_parag_spacing:
			mvi a, PARAG_SPACING_DEFAULT
			add c
			mov c, a
			jmp text_ex_restore_pos_x
; move a position to the next line
text_ex_line_spacing:
			mvi a, LINE_SPACING_DEFAULT
			add c
			mov c, a
text_ex_restore_pos_x:
			mvi b, TEMP_BYTE
			jmp text_ex_draw_next_char

text_ex_draw_skip_dad_ptrs:
			.word text_ex_draw_shift0, text_ex_draw_shift1,	text_ex_draw_shift2, text_ex_draw_shift3, text_ex_draw_shift4, text_ex_draw_shift5, text_ex_draw_shift6, text_ex_draw_shift7