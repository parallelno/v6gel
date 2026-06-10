@memusage_v6_os:

.include "asm/v6/v6_os_consts.asm"
.include "asm/v6/v6_os_macros.asm"
;=======================================================
; RDS (based on CP/M 2.2 and MicroDos 3) library
; Refs:
; https://github.com/ImproverX/RDS/blob/master/manuals/rds-rpro.txt
; https://www.seasip.info/Cpm/bdos.html
; https://www.seasip.info/Cpm/fcb.html
; https://www.seasip.info/Cpm/format22.html
; http://www.cpm.z80.de/manuals/cpm22-m.pdf
; https://zxpress.ru/book_articles.php?id=2318
;=======================================================


v6_os_err_file_open:		.text "Error opening file: $"
v6_os_err_hardware:			.text "Hardware error\n$"
v6_os_err_invalid_fcb:		.text "Invalid FCB\n$"
v6_os_msg_exit:				.text "Exit the game.\n$"
/*
errmsg_invalid_read_data:	.text "Invalid read data\n$"

errmsg_file_make:			.text "NO DIRECTORY SPACE\n$"
errmsg_invalid_save_data:	.text "Invalid save data\n$"

errmsg_delete_file:			.text "Error deleting file\n$"
errmsg_search_file:			.text "Error searching for file\n$"
errmsg_open_del_file:		.text "Error open DEL file\n$"

errmsg_file_open_to_save:	.text "Error opening file for saving\n$"
errmsg_file_save:	.text "Error saving file\n$"

errmsg:				.text "Error\n$"
msg_file_saved:		.text "File saved\n$"

donemsg:			.text "Done\n$"
*/
LOADING_TEXT_SCR_BUFF = 0xB000

;=======================================================
; OS init. Should be called first in the application
; in:
;	hl - interruption_addr
;=======================================================
v6_os_init:
			shld STACK_MAIN_PROGRAM_ADDR - WORD_LEN * 2
			; take from the stack the return addr
            pop h
			shld STACK_MAIN_PROGRAM_ADDR - WORD_LEN

.if DEBUG
			jmp @print
@text:
			.text "Debug mode is on\n$"
@print:
			SYS_CALL_D(CPM_SUB_PRINT, @text)
.endif
			di
			lxi sp, 0 ; TODO: check if it's required for call 5
			; map 0x0A000-0xDFFF range to the Screen buffer
			A_TO_ZERO(RDS_SCR_MODE_ON)
			sta RDS_SCR_MODE
			; enable the RDS mode 1
			mvi a, RDS_MODE_1
			sta RDS_MODE
			SYS_CALL(RDS_SUB_SCR_MODE)
			; temporaly store the system fdd disk num
			lda RDS_DISK
			sta os_disk

			RAM_DISK_OFF_NO_RESTORE(true, RAM_DISK0_PORT) ; disable the RAM Disk 0 because the OS uses it
			RAM_DISK_OFF_NO_RESTORE() ; disable RAM Disk used by the game

			; set the interrupt routine vector
			mvi a, OPCODE_JMP
			sta INT_ADDR

			lxi sp, STACK_MAIN_PROGRAM_ADDR - WORD_LEN * 2
			; "- WORD_LEN * 2" because
			; stack contain the return addr
			; and the addr of the interrupt routine
			pop h
			shld INT_ADDR + 1
			ei
			ret

;=======================================================
; Read file
;=======================================================
/*
.macro LOAD_FILE(filename_ptr, command, dest, file_len)
		odd_len = file_len & 1
		.if odd_len
			.error "file length must be even. filename_ptr = ", filename_ptr
		.endif

			lxi h, dest
		recs .var file_len>>7
		last_rec = file_len & (CMP_DMA_BUFFER_LEN - 1)
	.if last_rec > 0
		recs = recs + 1
	.endif

			lxi b, (recs<<8) | last_rec
			lxi d, filename_ptr
			mvi a, command
			call load_file
.endmacro
*/
.macro FILE_LOAD_PARAMS(filename_ptr, command, dest, file_len)
		odd_len = file_len & 1
		.if odd_len
			.error "file length must be even. filename_ptr = ", filename_ptr
		.endif

		recs .var file_len>>7
		last_rec = file_len & (CMP_DMA_BUFFER_LEN - 1)
	.if last_rec > 0
		recs = recs + 1
	.endif

			.word dest, filename_ptr
			.byte last_rec, recs, command
.endmacro

; in:
; hl - pointer to list of FILE_LOAD_PARAMS
; e - the number of FILE_LOAD_PARAMS
load_files_from_params:
			push h
			push d
			call loading_text_draw
			pop d
			pop h
@loop:
			push d
			push h
			xchg
			; hl - reversed file counter
			lxi b, 0x0930 + LOADING_TEXT_SCR_BUFF
			; bc - scr addr
			; l - int8
			call text_mono_draw_int8
			pop h

			; get the loading destination addr
			mov e, m
			inx h
			mov d, m
			inx h
			push d
			; get filename_ptr
			mov e, m
			inx h
			mov d, m
			inx h
			; get last_rec
			mov c, m
			inx h
			; get recs
			mov b, m
			inx h
			; get RAM Disk activation command
			mov a, m
			inx h

			xthl
			; hl - loading destination addr
			; de - filename ptr
			; b - the num of full records (128 byte long)
			; c - the len of the last record (<128)
			; a - RAM Disk activation command

			call load_file
			pop h
			pop d
			dcr e
			jnz @loop
			ret

; in:
; hl - loading destination addr
; de - filename ptr
; b - the num of full records (128 byte long)
; c - the len of the last record (<128)
; a - RAM Disk activation command
; out:
; os_file_data_ptr - points to next byte after loaded file
; the len must be even
load_file:
			shld os_file_data_ptr
load_file_next:
			sta @ram_disk_activation + 1
			mov a, b
			sta @rec_num
			mov a, c
			sta @restore_last_rec_len + 1

			xchg
			; hl - ptr to a filename (8 bytes name, 3 bytes extention)
			call set_file_name

			; Open the file
			SYS_CALL_D(CPM_SUB_F_OPEN, CPM_FCB)
			cpi CPM_MSG_ERROR
			jz v6_os_error_file_open

@loop:
			; Read the record from the file
			SYS_CALL_D(CPM_SUB_F_READ, CPM_FCB)
			cpi CPM_MSG_ERROR
			jz v6_os_error_hardware
			cpi CPM_MSG_INVALID_FCB
			jz v6_os_error_invalid_fcb
			cpi CPM_MSG_EOF
			jz @close_file

			; detect the last record
			lxi h, @rec_num
			dcr m
			push psw

			lxi d, CMP_DMA_BUFFER_LEN
			jnz @copy
			; it's the last record
@restore_last_rec_len:
			mvi e, TEMP_WORD ; set the last record len
@copy:
			call @copy_record

			pop psw
			jnz @loop
@close_file:
			; Close the file
			SYS_CALL_D(CPM_SUB_F_CLOSE, CPM_FCB)
			ret

; in:
; de - len
@copy_record:
			; check if len=0
			A_TO_ZERO(0)
			ora e
			rz

			push d ; len
			; advance os_file_data_ptr by the loaded chunk
			lhld os_file_data_ptr
			dad d
			shld os_file_data_ptr

			; copy the data
			lxi d, CMP_DMA_BUFFER
			pop b
			; de - dma buffer
			; hl - loading destination addr + len
			; bc - len
@ram_disk_activation:
			mvi a, TEMP_BYTE ; RAM Disk activation command
			call mem_copy_to_ram_disk
			ret
@rec_num:
			.byte TEMP_BYTE
/*
;=======================================================
; Delete file
;=======================================================
del_file:
			lxi h, file_name
			call set_file_name

			SYS_CALL_D(CPM_SUB_F_SFIRST, CPM_FCB)
			cpi CPM_ERROR
			lxi d, errmsg_search_file
			jz exit_w_error

			; delete the file
			SYS_CALL_D(CPM_SUB_F_DELETE, CPM_FCB)
			cpi CPM_ERROR
			lxi d, errmsg_delete_file
			jz exit_w_error
			ret

;=======================================================
; Save file
;=======================================================

save_file:
			lxi h, bin_data
			shld bin_data_ptr

			lxi h, SAVE_FILE_LEN
			shld save_file_len_ptr

			lxi h, file_name
			call set_file_name

			; Create the file
			SYS_CALL_D(CPM_SUB_F_MAKE, CPM_FCB)
			cpi CPM_ERROR		; Check if file was created successfully
			jz error_file_make	; Handle file creation error

			; Open file for writing
			SYS_CALL_D(CPM_SUB_F_OPEN, CPM_FCB)
			cpi CPM_ERROR
			lxi d, errmsg_file_open_to_save
			jz exit_w_error

			; Write data to the file
@loop:
			; Fill up the DMA buffer with data to write
			lhld bin_data_ptr
			lxi d, CMP_DMA_BUFFER
			mvi c, 128
			call copy_data
			shld bin_data_ptr

			; Write a record to the file
			SYS_CALL_D(CPM_SUB_F_WRITE, CPM_FCB)
			cpi CPM_SUCCESS
			lxi d, errmsg_file_save
			jnz exit_w_error

			; check if all data is written
			lhld save_file_len_ptr
			dcx h
			shld save_file_len_ptr
			mov a, l
			ora h
			jnz @loop

@done:
			; Close the file
			SYS_CALL_D(CPM_SUB_F_CLOSE, CPM_FCB)

			; Exit program
			SYS_CALL_D(CPM_SUB_PRINT, msg_file_saved)
			ret
*/

; in:
;	hl - ptr to a filename (8 bytes name, 3 bytes extention)
set_file_name:
			; copy a filename string
			push h
			lxi d, CPM_FCB + 1 ; file name addr
			lxi b, FILENAME_LEN
			call mem_copy_len
			pop h

			push h

			; Store the filename as a CPM string
			lxi d, os_filename
			mvi c, BASENAME_LEN
			call copy_filebase
			; print the '.' symbol
			mvi a, '.'
			stax d
			inx d

			pop h
			; hl - filename ptr
			lxi b, BASENAME_LEN
			dad b
			lxi b, EXT_LEN
			; hl - file ext ptr
			; de - points to v6_os_errmsg_file_open_ext
			; bc - extention len
			call mem_copy_len
			mvi a, '\n'
			stax d
			inx d
			mvi a, '$'
			stax d

			; Set the disk drive number
			mvi a, DISK_CURRENT
			sta CPM_FCB

			; Erase the rest of the FCB
			lxi h, CPM_FCB + FILENAME_LEN + 1
			lxi b, CMP_DMA_BUFFER
			call mem_erase
			ret

;=======================================================
; Error handling
;=======================================================

v6_os_error_file_open:
			call v6_os_exit_prep
			SYS_CALL_D(CPM_SUB_PRINT, v6_os_err_file_open)
			SYS_CALL_D(CPM_SUB_PRINT, os_filename)
			jmp CPM_EXIT

v6_os_error_hardware:
			call v6_os_exit_prep
			SYS_CALL_D(CPM_SUB_PRINT, v6_os_err_hardware)
			jmp CPM_EXIT

v6_os_error_invalid_fcb:
			call v6_os_exit_prep
			SYS_CALL_D(CPM_SUB_PRINT, v6_os_err_invalid_fcb)
			jmp CPM_EXIT

;=======================================================
; Return to OS. Should be called last in the application
;=======================================================

v6_os_exit:
			call v6_os_exit_prep
			SYS_CALL_D(CPM_SUB_PRINT, v6_os_msg_exit)
			jmp CPM_EXIT

v6_os_exit_prep:
			pop h
			shld @return + 1
			di
			mvi a, RDS_MODE_0
			sta RDS_MODE
			SYS_CALL(RDS_SUB_SCR_MODE)

			ei
			; restore the system fdd disk num
			lda os_disk
			sta RDS_DISK
@return:
			lxi h, TEMP_ADDR
			pchl

; Copies a string.
; Stops when it meets the first whitespace (' ') or
; when it copies C characters.
; in:
; 	hl - source
; 	de - destination
; 	c - max length
; out:
; 	hl - points to the next byte after copied source buffer
;	de - points to the next byte after copied destination buffer
; use:
; a
copy_filebase:
@loop:		mov a, m
			; check if it's the end
			cpi ' '
			rz

			stax d
			inx h
			inx d
			dcr c
			jnz @loop
			ret

; draws an image 8 pxls tall.
loading_text_draw:
			lxi d, @loading
			lxi h, 0x0430 + LOADING_TEXT_SCR_BUFF
			mvi b, 5 ; width in bytes
			call @new_char
			lxi d, @left
			lxi h, 0x0B30 + LOADING_TEXT_SCR_BUFF
			mvi b, 3 ; width in bytes
@new_char:
			mvi c, 8
@loop:
			ldax d
			mov m, a
			inx d
			dcr l
			dcr c
			jnz @loop
			; advance HL to the next char position
			mvi a, 8
			add l
			mov l, a
			inr h
			dcr b
			jnz @new_char
			ret
; text "LOADING:" atored as an row 40x8 image
@loading:
			.byte %10000011
			.byte %10000100
			.byte %10000100
			.byte %10000100
			.byte %10000100
			.byte %10000100
			.byte %11110011
			.byte 0

			.byte %10001110
			.byte %01010001
			.byte %01010001
			.byte %01011111
			.byte %01010001
			.byte %01010001
			.byte %10010001
			.byte 0

			.byte %01111011
			.byte %01000101
			.byte %01000101
			.byte %01000101
			.byte %01000101
			.byte %01000101
			.byte %01111011
			.byte 0

			.byte %10100010
			.byte %00110010
			.byte %00101010
			.byte %00101010
			.byte %00100110
			.byte %00100110
			.byte %10100010
			.byte 0

			.byte %01110000
			.byte %10001010
			.byte %10000000
			.byte %10111000
			.byte %10001000
			.byte %10001010
			.byte %01111000
			.byte 0
@left:
			.byte %10000111
			.byte %10000100
			.byte %10000100
			.byte %10000111
			.byte %10000100
			.byte %10000100
			.byte %11110111
			.byte 0

			.byte %10111101
			.byte %00100000
			.byte %00100000
			.byte %10111000
			.byte %00100000
			.byte %00100000
			.byte %10100000
			.byte 0

			.byte %11110000
			.byte %01000000
			.byte %01000000
			.byte %01000000
			.byte %01000000
			.byte %01000000
			.byte %01000000
			.byte 0