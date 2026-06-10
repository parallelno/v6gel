; gigachad16 music player
; it uses AY-3-8910 sound chip
; info/credits:
; music has to be compressed into 14 buffers each for every AY register
; this player decompresses and plays 14 parallel streams, each for particular AY register
; Only one task is executed each frame that decompresses 16 bytes for one stream.
; Performance: 5-20 of 312 scanlines per a frame
; Original player code was written by svofski 2022
; Zx0 decompression port to i8080 was made by ivagor 2022

; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; !!!              MUSIC DATA MUST BE LOADED             !!!
; !!!  INTO RAM OR INTO THE RAM DISK $8000-$FFFF SEGMENT !!!
; !!! BECAUSE IT'S ACCESSED VIA THE NON_STACK OPERATIONS !!!
; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

.include "asm/v6/sound/v6_gc_consts.asm"
.include "asm/v6/sound/v6_gc_runtime_data.asm"

// Init the cong before playing
.global v6_gc_init_song
// Play the song
.global v6_gc_start
.global v6_gc_pause
.global v6_gc_unpause
.global v6_gc_flip_pause

setting_music:
			.byte SETTING_OFF

v6_gc_init:
			call v6_gc_pause
			;call v6_gc_clear_buffers ; commented out because it's already erased in the file
			ret

; init a new song before playing it.
; hl - the song reg ptrs (v6_gc_ay_reg_data_ptrs)
; de - the song data
; a - song data ram-disk access cmd
v6_gc_init_song:
			; store the command to be used in the interruption routine
			sta v6_song_ram_disk_m

			push h
			; store the end of the array of ptrs to the song reg data
			lxi b, GC_TASKS * ADDR_LEN
			dad b
			shld v6_song_reg_data_ptrs_end

			push d
			call v6_gc_pause
			pop d
			pop h
			; hl - points to the array of ptrs to the reg data
			; de - points to the song data
			push d
			mvi c, GC_TASKS
			call add_offset_to_labels_len

			; update _v6_gc_buffer ptr
			pop h
			push h
			; hl - points to the song data
			lxi d, _v6_gc_buffer
;			dad d
			; hl - absolute _v6_gc_buffer ptr
			mov a, h
			sta v6_gc_buffer_ptr0 + 1
			adi GC_TASKS - 1
			sta v6_gc_buffer_ptr2

			; update _v6_gc_task_stack_end ptr
			pop h
			; hl - points to the song data
			lxi d, _v6_gc_task_stack_end
			dad d
			shld v6_gc_task_stack_end0 + 1
			ret


; uses to start a new song or to repeat a finished song
; requires a call v6_gc_init_song upfront!
; ex. CALL_RAM_DISK_FUNC_NO_RESTORE(v6_gc_start, RAM_DISK_M_PERMANENT_SONG01 | RAM_DISK_M_8F)
v6_gc_start:
			call v6_gc_tasks_init
			call v6_gc_scheduler_init

			; set buffer_idx GC_TASKS bytes prior to the init unpacking addr (0),
			; to let zx0 unpack data for GC_TASKS number of regs
			; that means the music will be GC_TASKS number of frames delayed
			mvi a, -GC_TASKS
			sta v6_gc_buffer_idx
			mvi a, -1
			sta v6_gc_task_id

			call v6_gc_unpause
			ret


; called by the unterruption routine
; ex. CALL_RAM_DISK_FUNC_NO_RESTORE(v6_gc_update, RAM_DISK_S_SONG01 | RAM_DISK_M_PERMANENT_SONG01 | RAM_DISK_M_8F)
v6_gc_update:
			; return if muted
			lda setting_music
			CPI_ZERO(SETTING_OFF)
			rz

			; handle the current task
			lxi h, v6_gc_task_id
			mov a, m
			inr a
			ani $f
			mov m, a
			; if the task idx is higher GC_TASKS number, skip it
			cpi GC_TASKS
			jnc @skip
			call v6_gc_scheduler_update
@skip:
			lxi h, v6_gc_buffer_idx
			inr m
			call v6_gc_ay_update
			ret


;==========================================
; create a v6_gc_unpack tasks
v6_gc_tasks_init:
			; TODO: avoid disabling/enabling interruptions.
			; it's not obvious behavior
			di
			lxi h, 0
			dad sp
			shld v6_gc_tasks_init_restore_sp + 1
v6_gc_task_stack_end0:
			lxi sp, TEMP_ADDR ; v6_gc_task_stack_end
			lhld v6_song_reg_data_ptrs_end
			xchg
			; b = 0, c = a task counter * 2
			lxi b, (GC_TASKS - 1) * ADDR_LEN
v6_gc_tasks_init_loop:
			; store zx0 entry point to a task stack
			lxi h, v6_gc_unpack
			push h
			; store the buffer addr to a task stack
			mov a, c
			rrc
v6_gc_buffer_ptr0:
			adi TEMP_ADDR ; >v6_gc_buffer
			mov h, a
			mov l, b
			push h
			; store the reg_data addr to a task stack
			xchg
			dcx h
			mov d, m
			dcx h
			mov e, m
			push d
			xchg
			; store taskSP to v6_gc_task_sps
			lxi h, v6_gc_task_sps
			dad b
			shld v6_gc_tasks_init_loop_storeTaskSP + 1
			; move sp back 4 bytes to skip storing HL, PSW because zx0 doesnt use them to init
			LXI_H_NEG(WORD_LEN * 2)
			dad sp
v6_gc_tasks_init_loop_storeTaskSP:
			shld TEMP_ADDR
			; move SP to the previous task stack end
			LXI_H_NEG(GC_STACK_SIZE - WORD_LEN * 3)
			dad sp

			sphl
			dcr c
			dcr c
			jp v6_gc_tasks_init_loop
v6_gc_tasks_init_restore_sp:
			lxi sp, TEMP_ADDR
			ei
			ret

; Set the current task stack pointer to the first task stack pointer
v6_gc_scheduler_init:
			lxi h, v6_gc_task_sps
			shld v6_gc_current_task_spp
			ret

/*
; it clears the last 14 bytes of every buffer
; to prevent player to play garbage data
; when it repeats the current song or
; play a new one
v6_gc_clear_buffers:
@v6_gc_buffer_ptr:
			mvi h, TEMP_ADDR ; >v6_gc_buffer
			mvi a, >v6_gc_buffer_end
@next_buff:
			mvi l, -GC_TASKS
@loop:
			mvi m, 0
			inr l
			jnz @loop
			inr h
			cmp h
			jnz @next_buff
			ret
v6_gc_buffer_ptr1 = @v6_gc_buffer_ptr + 1
*/

; this func restores the context of the current task
; then calls v6_gc_unpack to let it continue unpacking reg_data
; this code is performed during an interruption
v6_gc_scheduler_update:
			lxi h, 0
			dad sp
			shld v6_gc_scheduler_restore_sp + 1
			lhld v6_gc_current_task_spp
			mov e, m
			inx h
			mov d, m ; de = &v6_gc_task_sps[n]
			xchg
			sphl
			; restore a task context and return into it
			pop psw
			pop h
			pop d
			pop b
			; go to v6_gc_unpack
			ret

; v6_gc_unpack task calls this after unpacking 16 bytes.
; it stores all the registers of the current task
v6_gc_scheduler_store_task_context:
			push b
			push d
			push h
			push psw

			lxi h, 0
			dad sp
			xchg
			lhld v6_gc_current_task_spp
			mov m, e
			inx h
			mov m, d
			inx h
			mvi a, <v6_gc_task_sps_end
			cmp l
			jnz @store_next_task_sp
			mvi a, >v6_gc_task_sps_end
			cmp h
			jnz @store_next_task_sp
			; (v6_gc_current_task_spp) = v6_gc_task_sps[0]
			lxi h, v6_gc_task_sps
@store_next_task_sp:
			shld v6_gc_current_task_spp
v6_gc_scheduler_restore_sp:
			lxi sp, TEMP_ADDR
			ret


; unpacks 16 bytes of reg_data for the current task
; this function is called from the interruption routine
; Parameters (forward):
; DE: source addr (compressed data)
; BC: destination addr (decompressing)
; unpack every 16 bytes into a current task circular buffer,
; then call v6_gc_scheduler_store_task_context
v6_gc_unpack:
			lxi h, $ffff
			push h
			inx h
			mvi a, $80
@literals:
			call @Elias
			push psw
@Ldir1:
			ldax d
			stax b
			inx d
			inr c 		; to stay inside the circular buffer
			; check if it's time to have a break
			mvi a, $0f
			ana c
			cz v6_gc_scheduler_store_task_context

			dcx h
			mov a, h
			ora l
			jnz @Ldir1
			pop psw
			add a

			jc @new_offset
			call @Elias
@copy:
			xchg
			xthl
			push h
			dad b
			mov h, b ; to stay inside the circular buffer
			xchg

@ldirFromBuff:
			push psw
@ldirFromBuff1:
			ldax d
			stax b
			inr e		; to stay inside the circular buffer
			inr c 		; to stay inside the circular buffer
			; check if it's time to have a break
			mvi a, $0f
			ana c
			cz v6_gc_scheduler_store_task_context

			dcx h
			mov a, h
			ora l
			jnz @ldirFromBuff1
			mvi h, 0	; ----------- ???
			pop psw
			add a

			xchg
			pop h
			xthl
			xchg
			jnc @literals
@new_offset:
			call @Elias
			mov h, a
			pop psw
			xra a
			sub l
			jz @exit
			push h
			rar
			mov h, a
			ldax d
			rar
			mov l, a
			inx d
			xthl
			mov a, h
			lxi h, 1
			cnc @elias_backtrack
			inx h
			jmp @copy

@Elias:
			inr l
@elias_loop:
			add a
			jnz @elias_skip
			ldax d
			inx d
			ral
@elias_skip:
			rc
@elias_backtrack:
			dad h
			add a
			jnc @elias_loop
			jmp @Elias

@exit:
			; the song ended
			; restore sp
			lhld v6_gc_scheduler_restore_sp + 1
			sphl
			; restart the music
			call v6_gc_start

			; pop v6_gc_scheduler_update return addr
			; to return right to the func that called v6_gc_update
			pop psw
			; return to the func that called v6_gc_update
			ret

.macro GC_AY_UPDATE_REG(do_dcr = true)
			mov a, e
			out PORT_AY_REG

			ldax b
			out PORT_AY_DATA
		.if do_dcr
			dcr b
			dcr e
		.endif
.endmacro

; send buffers data to AY regs
; input:
; hl = buffer_idx
; if envelope shape reg13 data = $ff, then don't send data to reg13
; AY-3-8910 ports

v6_gc_ay_update:
			mvi e, GC_TASKS - 1
			mov c, m
@v6_gc_buffer_ptr:
			mvi b, TEMP_ADDR ; (>v6_gc_buffer) + GC_TASKS - 1
			ldax b
			cpi $ff
			jz @doNotSendEnvData
			GC_AY_UPDATE_REG(false) ; reg 13 (Envelope)
@doNotSendEnvData:
			dcr b
			dcr e
			GC_AY_UPDATE_REG() ; reg 12 (envelope FDIV H)
			GC_AY_UPDATE_REG() ; reg 11 (envelope FDIV L)
			GC_AY_UPDATE_REG() ; reg 10 (Vol C)
			GC_AY_UPDATE_REG() ; reg 9  (Vol B)
			GC_AY_UPDATE_REG() ; reg 8  (Vol A)
			GC_AY_UPDATE_REG() ; reg 7 (Mixer)
			GC_AY_UPDATE_REG() ; reg 6 (Noise FDIV)
			GC_AY_UPDATE_REG() ; reg 5 (Tone FDIV CHC H)
			GC_AY_UPDATE_REG() ; reg 4 (Tone FDIV CHC L)
			GC_AY_UPDATE_REG() ; reg 3 (Tone FDIV CHB H)
			GC_AY_UPDATE_REG() ; reg 2 (Tone FDIV CHB L)
			GC_AY_UPDATE_REG() ; reg 1 (Tone FDIV CHA H)
			GC_AY_UPDATE_REG() ; reg 0 (Tone FDIV CHA L)

@doNotSendData:
			ret
v6_gc_buffer_ptr2 = @v6_gc_buffer_ptr + 1

; to mute the player. It can continue the song after unmute
; to call from this module: call v6_gc_pause
v6_gc_pause:
			; disable the updates
			mvi a, SETTING_OFF
			sta setting_music
			; set zeros to AY regs to mute it
			mvi e, GC_TASKS - 1
@send_data:
			mov a, e
			out PORT_AY_REG
			A_TO_ZERO(0)
			out PORT_AY_DATA
			dcr e
			jp @send_data
			ret

; to unpause the player after being muted. It continues the song from where it has been stopped
v6_gc_unpause:
			mvi a, SETTING_ON
			sta setting_music
			ret

; to flip mute/unmute
v6_gc_flip_pause:
			lxi h, setting_music
			mov a, m
			cma
			mov m, a
			cpi SETTING_OFF
			jz v6_gc_pause
			jmp v6_gc_unpause

; return setting_music value
; to call from this module: call v6_gc_get_setting
; out:
; a - setting_music value
v6_gc_get_setting:
			lda setting_music
			ret
