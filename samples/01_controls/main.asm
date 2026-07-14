; ------------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * read controls
;    * debug output
; ------------------------------------------------------------------------------

; Expose `main` symbol so the linker and engine can call into this demo.
.global main

; Import engine constants and control codes
.include "../../engine/common/v6_consts.asm"
.include "../../engine/common/v6_macros.asm"
.include "../../engine/controls/v6_controls_consts.asm"


; ------------------------------------------------------------------------------
; Entry point
; Steps performed here:
; 1. Enter the main loop which syncs to frames, handles controls and
;    outputs the pressed key code to the debug console.
; ------------------------------------------------------------------------------
main:
@loop:
            ; Delay 1/50th of a second (1 frame).
            hlt

            ; Read current keyboard action code provided by engine.
            ; Codes are defined in `v6_controls_consts.asm` and are bitwise ORed together.
            lda v6_action_code
            ; `CPI_ZERO` macro performs a safety check to ensure the constant
            ; is zero. It makes the usage of a `ora a` operation (optimized
            ; comparison with zero) safe and clear.
            CPI_ZERO(CONTROL_CODE_NO)
            ; If no key is pressed, skip debug output and continue to the next frame.
            jz @loop

            ani CONTROL_CODE_UP | CONTROL_CODE_DOWN | CONTROL_CODE_LEFT | CONTROL_CODE_RIGHT
            jz @exit

@debug_output:
            ; Debug output of the pressed key code.
            ; Check the emulator's debug console to see the output.
            out 0xED

            jmp @loop
@exit:
            ; Stops the demo for ROMs, and returns to OS for COMs.
            A_TO_ZERO(NULL)
            out 0xED
            ret