; The sfx player for 580ВИ53 (Intel 8253) programmable interval timer
SFX_DATA_EOD = 0 ; the end of the sfx data

setting_sfx:	.byte SETTING_ON

; TODO: use all 3 channels to simulate a volume change

; SFX Data Layout:
; .word - frequency divider for channel0, freq = 1500000 / freq_div
; .word - frequency divider for channel1, 
; .word - frequency divider for channel0,  
; .word - frequency divider for channel1, 
; ...
; .word $0 ; SFX_DATA_EOD

; TODO: move sfx data to the RAM Disk
/*
			; light short vibrant sound. choosing an option in the menu
sfx_song_menu_enter: 
			.word 300, 100, 175, 80, 200, 100, 200, 130, 90, 0
			.word 300, 100, 175, 80, 200, 100, 200, 130, 90
*/
/*
			; menu sound light
sfx_song_menu_light: 
			.word 300, 200, 375, 280, 300, 300, 200, 330, 290, 0
			.word 1220, 340, 1100, 275, 500, 350, 300, 400, 340
*/
/*
			; menu sound medium
sfx_song_menu_med: 
			.word 710, 810, 950, 1670, 2571, 2027, 1427, 711, 1065, 0
			.word 700, 800, 952, 1675, 2572, 2020, 1417, 712, 1067
*/

/*
			; resemble a false use
sfx_song_false: 
			.word 1700, 2700, 2750, 1100, 6500, 3700, 7100, 1750, 5500, 0
			.word 1700, 2700, 2750, 1100, 6500, 3700, 7100, 1750, 5000, 0
*/

sfx_vampire_attack:
			.dword 0710<<16 | 0700, 
			.dword 0700<<16 | 0700, 
			.dword 1750<<16 | 1750,
			.dword 1000<<16 | 1100,
			.dword 1100<<16 | 1100,
			.dword 1700<<16 | 1700,
			.dword 2100<<16 | 2100,
			.dword 4750<<16 | 4750,
			.dword 5750<<16 | 5750,
			.word SFX_DATA_EOD

sfx_bomb_attack: 
			.dword 50010<<16 | 57000,
			.dword 44700<<16 | 44700,
			.dword 33750<<16 | 33750,
			.dword 13500<<16 | 33100,
			.dword 11000<<16 | 11000,
			.dword 1700<<16 | 1100,
			.dword 2100<<16 | 6500,
			.dword 4750<<16 | 700,
			.dword 5450<<16 | 700,
			.dword 1220<<16 | 42700,
			.dword 4340<<16 | 2750,
			.dword 1100<<16 | 1100,
			.dword 11075<<16 | 6500,
			.word SFX_DATA_EOD

sfx_hero_hit:
			.dword 50010<<16 | 57000,
			.dword 44700<<16 | 44700,
			.dword 33750<<16 | 33750,
			.dword 13500<<16 | 33100,
			.dword 11000<<16 | 11000,
			.dword 5450<<16 | 700,
			.dword 4340<<16 | 2750,
			.dword 11075<<16 | 6500,
			.word SFX_DATA_EOD

sfx_song_hi_pitch: 
			.dword 242<<16 | 226,
			.dword 132<<16 | 153,
			.dword 17<<16 | 152,
			.dword 125<<16 | 99,
			.dword 85<<16 | 52,
			.dword 1<<16 | 30,
			.dword 164<<16 | 16,
			.dword 13<<16 | 5,
			.dword 175<<16 | 1,
			.word SFX_DATA_EOD

; send silence to the sound chip
v6_sfx_reg_mute:
			; stop sound
			mvi a, TIMER_INIT_CH0
			out PORT_TIMER
			mvi a, TIMER_INIT_CH1
			out PORT_TIMER
			ret
v6_sfx_stop:
			; stop sound
			call v6_sfx_reg_mute
			mvi a, OPCODE_RET
			sta v6_sfx_update_ptr			
			ret

v6_sfx_player_init:
			call v6_sfx_stop
			mvi a, SETTING_ON
			sta setting_sfx
			ret

; start the next sfx to play
; in:
; hl - sfx pointer
v6_sfx_play:
			shld v6_sfx_update_ptr + 1
			mvi a, OPCODE_LXI_H
			sta v6_sfx_update_ptr
			ret

; uses:
; hl, a, c
v6_sfx_update:
@song_ptr:
			lxi h, TEMP_ADDR; sfx_vampire_attack

			; return if muted
			lda setting_sfx
			cpi SETTING_ON
			rnz

			; check the end of the song
			mov c, m
			inx h
			mov a, m
			ora c
			jz v6_sfx_stop
@play:
			; set freq_div to ch0
			mvi a, TIMER_INIT_CH0
			out PORT_TIMER
			mov a, c
			out TIMER_PORT_CH0
			mov a, m
			inx h
			out TIMER_PORT_CH0

			; set freq_div to ch1
			mvi a, TIMER_INIT_CH1
			out PORT_TIMER
			mov a, m
			inx h
			out TIMER_PORT_CH1
			mov a, m
			inx h
			out TIMER_PORT_CH1
			; store the current song ptr ch0		
			shld @song_ptr + 1		
			ret
v6_sfx_update_ptr: = @song_ptr

; to mute the sfx player. It can continue the sfx after unmute
; to call from this module: call v6_sfx_mute
v6_sfx_mute:
			call v6_sfx_reg_mute
			; disable the updates
			mvi a, SETTING_OFF
			sta setting_sfx
			ret

; to unmute the sfx player after being muted. It continues the sfx from where it has been stopped
; to call from this module: call v6_sfx_unmute
v6_sfx_unmute:
			mvi a, SETTING_ON
			sta setting_sfx
			ret

; to flip mute/unmute
; to call from this module: call v6_sfx_flip_mute
v6_sfx_flip_mute:
			lxi h, setting_sfx
			mov a, m
			cma
			mov m, a
			cpi SETTING_OFF
			jz v6_sfx_mute
			jmp v6_sfx_unmute

; return setting_sfx value
; to call from this module: call v6_sfx_get_setting
; out:
; c - setting_sfx value
v6_sfx_get_setting:
			lda setting_sfx
			mov c, a
			ret