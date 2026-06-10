@memusage_v6_consts:
	; This line is for proper formatting in VSCode
;=======================================================
; Ports
;=======================================================
PORT0_OUT_OUT			= 0x88
PORT0_OUT_IN			= 0x8a

PORT_TIMER				= 0x08
TIMER_INIT_CH0			= 0x36
TIMER_INIT_CH1			= 0x76
TIMER_INIT_CH2			= 0xB6
TIMER_PORT_CH0			= 0x0b
TIMER_PORT_CH1			= 0x0a
TIMER_PORT_CH2			= 0x09

PORT_AY_REG				= 0x15
PORT_AY_DATA			= 0x14

;=======================================================
; Color
;=======================================================
PALETTE_LEN			    = 16
PALETTE_UPD_REQ_NO		= 0
PALETTE_UPD_REQ_YES		= 1
BORDER_COLOR_IDX		= 1

;=======================================================
; Screen Buffer
;=======================================================
SCR_VERTICAL_OFFSET_DEFAULT = 255

SCR_ADDR				= 0x8000
SCR_BUFF0_ADDR			= 0x8000
SCR_BUFF1_ADDR			= 0xA000
SCR_BUFF2_ADDR			= 0xC000
SCR_BUFF3_ADDR			= 0xE000
SCR_BUFF_LEN            = 0x2000
SCR_BUFFS_LEN			= SCR_BUFF_LEN * 4
BACK_BUFF_ADDR          = 0xA000
BACK_BUFF_LEN           = SCR_BUFF_LEN * 3
BACK_BUFF2_ADDR         = 0xA000
BACK_BUFF2_LEN          = SCR_BUFF_LEN * 3
SCR_ADDR_MASK			= %1110_0000

;=======================================================
; Sprite
;=======================================================
SPRITE_X_SCR_ADDR		= >SCR_BUFF1_ADDR
SPRITE_SCR_BUFFS		= 3
SPRITE_W16				= 2
SPRITE_W24				= 3
SPRITE_W8_PACKED		= 0
SPRITE_W16_PACKED		= 1
SPRITE_W24_PACKED		= 2
SPRITE_W32_PACKED		= 3

; sprite preshift
SPRITE_PRESHIFT_H_MAX	= 24
SPRITES_PRESHIFTED_4	= 4
SPRITES_PRESHIFTED_8	= 8
; sprite copy to scr
SPRITE_COPY_TO_SCR_W_PACKED_MIN = SPRITE_W8_PACKED
SPRITE_COPY_TO_SCR_W_PACKED_MAX = SPRITE_W32_PACKED
SPRITE_COPY_TO_SCR_H_MIN = 5
SPRITE_COPY_TO_SCR_H_MAX = 20
; sprite min
SPRITE_W_PACKED_MIN		= SPRITE_COPY_TO_SCR_W_PACKED_MIN
SPRITE_H_MIN			= SPRITE_COPY_TO_SCR_H_MIN

;=======================================================
; Ram-disk
;=======================================================

RAM_DISK0_PORT = 0x10
RAM_DISK1_PORT = 0x11
RAM_DISK2_PORT = 0x20
RAM_DISK3_PORT = 0x21
RAM_DISK4_PORT = 0x40
RAM_DISK5_PORT = 0x41
RAM_DISK6_PORT = 0x80
RAM_DISK7_PORT = 0x81

RAM_DISK_PORT = RAM_DISK1_PORT ; working RAM Disk used by the game

RAM_DISK_OFF_CMD = 0
RAM_DISK_S0 = %00010000
RAM_DISK_S1 = %00010100
RAM_DISK_S2 = %00011000
RAM_DISK_S3 = %00011100

RAM_DISK_M0 = %00000000
RAM_DISK_M1 = %00000001
RAM_DISK_M2 = %00000010
RAM_DISK_M3 = %00000011

RAM_DISK_M_89 = %01000000
RAM_DISK_M_AD = %00100000
RAM_DISK_M_EF = %10000000
RAM_DISK_M_8F = RAM_DISK_M_89 | RAM_DISK_M_AD | RAM_DISK_M_EF
RAM_DISK_M_AF = RAM_DISK_M_AD | RAM_DISK_M_EF

;=======================================================
; V6 Engine
;=======================================================
RESTART_ADDR 			= 0x0000
INT_ADDR	 			= 0x0038

MAIN_STACK_LEN	= 48 ; used in the main programm
INT_STACK_LEN	= 30 ; used in the interruption routine
TMP_STACK_LEN	= 2  ; used as a temp 2 byte space in the render routines such as sprite_copy_to_scr_v

; defines available user space
; "-2" because erase funcs can let the interruption call corrupt 0x7ffe, @7fff bytes.
STACK_MAIN_PROGRAM_ADDR	= 0x8000 - 2
; used by the iterruption func
STACK_INTERRUPTION_ADDR	= STACK_MAIN_PROGRAM_ADDR - MAIN_STACK_LEN
; used as a temp 2 byte space in the render routines such as sprite_copy_to_scr_v
; It's used in rare cases when mapping is enabled, SP points to the data, and BC reg pair is
; temporally needed
STACK_TEMP_ADDR			= STACK_INTERRUPTION_ADDR - INT_STACK_LEN
STACK_MIN_ADDR			= STACK_TEMP_ADDR - TMP_STACK_LEN

BYTE_LEN	= 1
WORD_LEN	= 2
SAFE_WORD_LEN = 2 ; safty pair of bytes for reading by POP B
ADDR_LEN	= 2
JMP_4_LEN	= 4

TEMP_BYTE	= 00
TEMP_WORD	= 0000
TEMP_ADDR	= 0000
NULL		= 0
NULL_PTR	= 0000

INTS_PER_SEC			= 50 ; Interuptions per sec

; settings
SETTING_OFF	= 0
SETTING_ON	= 0xff

; the temporal space while before putting the data into the RAM Disk
LOADING_TEMP_ADDR = SCR_ADDR

; text
LINE_BREAK	= 0x6A ;'\n'
PARAG_BREAK	= 0xFF
EOD			= 0

;=======================================================
; V6 Debug
;=======================================================

; FPS counter screen addr
FPS_SCR_ADDR = 0xBDFB - 16

;=======================================================
; Op-codes
;=======================================================
OPCODE_NOP  	= 0x00
OPCODE_XCHG 	= 0xEB
OPCODE_RET  	= 0xC9
OPCODE_RC		= 0xD8
OPCODE_RNC  	= 0xD0
OPCODE_JMP		= 0xC3
OPCODE_JNZ		= 0xC2
OPCODE_JC		= 0xDA
OPCODE_JNC		= 0xD2
OPCODE_MOV_E_M	= 0x5E
OPCODE_MOV_E_A	= 0x5F
OPCODE_MOV_D_B	= 0x50
OPCODE_MOV_D_M	= 0x56
OPCODE_MOV_D_A	= 0x57
OPCODE_MOV_M_B	= 0x70
OPCODE_MOV_M_A	= 0x77
OPCODE_POP_B	= 0xC1
OPCODE_STC		= 0x37
OPCODE_INX_D	= 0x13
OPCODE_LXI_B	= 0x01
OPCODE_LXI_D	= 0x11
OPCODE_LXI_H	= 0x21
OPCODE_LXI_SP	= 0x31

;=======================================================
; AY-3-8910 sound chip consts
;=======================================================
; regs
AY_REG_TONE_FDIV_CHA_L	= 0 ; LLLLLLLL, channel A tone frequency divider low, FDIV = HHHH * 256 + LLLLLLLL, frq = 1.7734MHz / 16 / FDIV
AY_REG_TONE_FDIV_CHA_H	= 1 ; ----HHHH, channel A tone frequency divider high
AY_REG_TONE_FDIV_CHB_L	= 2 ; LLLLLLLL, channel B tone frequency divider low
AY_REG_TONE_FDIV_CHB_H	= 3 ; ----HHHH, channel B tone frequency divider high
AY_REG_TONE_FDIV_CHC_L	= 4 ; LLLLLLLL, channel C tone frequency divider low
AY_REG_TONE_FDIV_CHC_H	= 5 ; ----HHHH, channel C tone frequency divider high
AY_REG_NOISE_FDIV		= 6 ; ---NNNNN, noise frequency divider, FDIV = NNNNN, frq = 1.7734MHz / 16 / FDIV
AY_REG_MIXER			= 7 ; --CBAcba, cba - to mute tone channels, CBA - to mute noise channels, (1 = muted)
AY_REG_VOL_CHA			= 8 ; ---EVVVV, E - envelope (1=enabled), VVVV - master volune
AY_REG_VOL_CHB			= 9 ; ---EVVVV, E - envelope (1=enabled), VVVV - master volune
AY_REG_VOL_CHC			= 10; ---EVVVV, E - envelope (1=enabled), VVVV - master volune
AY_REG_ENV_FDIV_L		= 11; LLLLLLLL, envelope period low, to set the envelope lifetime. the larger the number, the longer the envelope
AY_REG_ENV_FDIV_H		= 12; HHHHHHHH, envelope period high, FDIV = FDIV_H * 256 + FDIV_L
AY_REG_ENV				= 13; ----EEEH, envelope type = EEE, H = 1 means hold
;							envelope type = 0: \_____________, single decay then off
;							envelope type = 1: /|____________, single attack then off
;							envelope type = 2: \|------------, single decay then hold
;							envelope type = 3: /-------------, single attack then hold
;							envelope type = 4: \|\|\|\|\|\|\|, repeated decay
;							envelope type = 5: /|/|/|/|/|/|/|, repeated attack
;							envelope type = 6: /\/\/\/\/\/\/\, repeated attack-decay
;							envelope type = 7: \/\/\/\/\/\/\/, repeated decay-attack
; mixer masks
AY_REG_MIXER_T_MUTE_CHA = %00000001 ; to mute tone channel A
AY_REG_MIXER_T_MUTE_CHB = %00000010 ; to mute tone channel B
AY_REG_MIXER_T_MUTE_CHC = %00000100 ; to mute tone channel C
AY_REG_MIXER_N_MUTE_CHA = %00001000 ; to mute noise channel A
AY_REG_MIXER_N_MUTE_CHB = %00010000 ; to mute noise channel B
AY_REG_MIXER_N_MUTE_CHC = %00100000 ; to mute noise channel C
; master volume masks
AY_REG_VOL_MASK			= %00001111
AY_REG_VOL_ENV_MASK		= %00010000
