; V6 runtime startup
; Built by build.bat. Output is in out\v6.o.

; Include this file and all files it includes at most once
.setting force_once, true

.include "common\v6_consts.asm"
.include "common\v6_macros.asm"
.include "misc\v6_interruption.asm"


;
; This is a replacement of the standard V6C crt0 startup.
; To make it happen, opt out for crt0 via -nostdlib, and link v6.o
;
; Responsibilities:
;   1. Set SP = __stack_top
;   2. Zero [__bss_start, __bss_end).
;   3. CALL __entry  (defaults to `main`; override with --defsym=__entry=NAME).
;   4. HLT on return (no exit syscall on bare V6C).
;
; Symbols supplied by the linker script:
;   __stack_top  - initial SP value (default 0x0000 -> first PUSH lands at 0xFFFE)
;   __bss_start  - first byte of .bss (inclusive)
;   __bss_end    - one-past-last byte of .bss (exclusive)
;   __entry      - C entry point alias (default: main).
;                  Override at link time: -Wl,--defsym=__entry=myStart
;                  The PROVIDE in v6c.ld makes __entry = main unless --defsym
;                  defines it first.
;
; Symbol supplied by user code:
;   main (or the function named by __entry) - C entry point, normal V6C
;                  calling convention
;
; Calling convention reminder (V6C_CConv):
;   main's return value lands in A (i8) or HL (i16); ignored here.

    .section .text._start, "ax"
    .globl _start
_start:
    DI                       			; Disable interrupts during setup
    LXI SP, STACK_MAIN_PROGRAM_ADDR		; Initialize V6 stack pointer

    ; Zero [__bss_start, __bss_end). Empty range is handled correctly
    ; (loop exits immediately when HL == DE).
    LXI H, __bss_start
    LXI D, __bss_end
_crt0_bss_loop:
    MOV A, L
    CMP E
    JNZ _crt0_bss_step       ; L != E -> not done
    MOV A, H
    CMP D
    JZ  _crt0_bss_done       ; H == D and L == E -> done
_crt0_bss_step:
    MVI M, 0                 ; [HL] = 0
    INX H                    ; HL++
    JMP _crt0_bss_loop
_crt0_bss_done:


	; disable the RAM Disk 0 because the OS uses it
	RAM_DISK_OFF_NO_RESTORE(true, RAM_DISK0_PORT)
	RAM_DISK_OFF_NO_RESTORE() ; disable RAM Disk used by the game

	; set the interrupt routine vector
	mvi a, OPCODE_JMP
	sta INT_ADDR
	lxi h, v6_interruption
	shld INT_ADDR + 1

	ei

    CALL __entry             ; Run user entry (default: main; override: --defsym=__entry=NAME)

    DI                       ; Disable interrupts before halting
    HLT                      ; Stop the CPU on return
