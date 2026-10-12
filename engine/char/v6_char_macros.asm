; Inserts a char runtime data at the beginning of
; the char runtime data list
; in:
; hl - ptr to char_update_ptr + 1
; out:
; hl - points to char_data_next_ptr
; uses:
; de, hl
; 18*4 cc
.macro CHAR_DATA_INSERT_AT_HEAD()
			HL_ADVANCE(char_update_ptr + 1, char_data_next_ptr + 1, BY_DE)

			; read the char_data_next_ptr from the actor_data_head_ptr
			xchg
			lhld actor_data_head_ptr

			; store addr from the actor_data_head_ptr
			; into char_data_next_ptr
			xchg
			; de - points to the char_data_next_ptr of the previosly first char data
			mov m, d
			HL_ADVANCE(char_data_next_ptr + 1, char_data_next_ptr)
			mov m, e
			; de - points to the char_data_next_ptr of the previosly first char data
			; hl - points to char_data_next_ptr

			; store char_data_next_ptr to the actor_data_head_ptr
			shld actor_data_head_ptr
.endmacro


; Deletes a char runtime data from the char runtime data list
; in:
; hl - ptr to char_update_ptr + 1
; uses:
; a, bc, de, hl
.macro CHAR_DATA_REMOVE()
			HL_ADVANCE(char_update_ptr + 1, char_data_next_ptr, BY_BC)

			; current element = head
			lxi d, actor_data_head_ptr
			xchg

			; find the element that points to the element we want to delete
@loop:
			; hl - current element
			; de - element we want to delete
			; get the next element
			mov c, m
			inx h
			mov b, m

			; check if the next element is the element we want to delete
			mov a, b
			cmp d
			jnz @advance
			mov a, c
			cmp e
			jz @found

@advance:
			; bc - next element
			; current element = next element
			mov h, b
			mov l, c
			jmp @loop

	@found:
			; hl - previous element + 1
			dcx h
			; hl - previous element
			; de - char_data_next_ptr of element we want to delete

			; make the previous element point to
			; the next element of the element we want to delete
			ldax d
			mov m, a
			inx d
			inx h
			ldax d
			mov m, a
.endmacro