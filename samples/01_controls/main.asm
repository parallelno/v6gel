; ------------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * read controls
;    * avoid repeated key pressing
;    * debug output
;    * use of macros for safe zero comparison and zeroing A register
; ------------------------------------------------------------------------------

; Expose `main` symbol so the linker and engine can call into this demo.
.global main

; Import engine constants, control codes, and helper macros.
.include "../../engine/common/v6_consts.asm"
.include "../../engine/common/v6_macros.asm"
.include "../../engine/controls/v6_controls_consts.asm"


; ---------------------------------------------------------------------------
; Entry point
; Notes for learners:
;  - `v6_action_code` is a bitfield where each bit represents a control (see
;    `v6_controls_consts.asm`). Multiple keys can be ORed together.
;  - Use `ani` to mask and check for specific buttons, e.g. `ani CONTROL_CODE_UP`.
;  - The `out 0xED` instruction writes A to the emulator debug port
;    the Devector emulator can show this value in a console window.
; ---------------------------------------------------------------------------
main:
@loop:
            ; Delay 1/50th of a second (1 frame).
            hlt

            ; Read action code and the previous frame action code.
            lhld v6_action_code
            mov a, l
            ; Save the action code for comparison in the next frame.
            sta v6_action_code_old

            ; `CPI_ZERO` macro performs a safety check to ensure the constant
            ; is zero. It makes the usage of a `ora a` operation (optimized
            ; comparison with zero) safe and clear.
            ; Quick check: if action code equals CONTROL_CODE_NO (zero), continue.
            CPI_ZERO(CONTROL_CODE_NO)
            jz @loop

            ; Mask direction keys (example): if none of the four directions are set,
            ; jump to exit. This demonstrates using `ani` with a combined mask.
            ani CONTROL_CODE_UP | CONTROL_CODE_DOWN | CONTROL_CODE_LEFT | CONTROL_CODE_RIGHT
            jnz @debug_output

@check_space:
            ; Check if SPACE is pressed once (example): if not SPACE is pressed,
            ; terminate the program.
            mvi a, CONTROL_CODE_KEY_SPACE
            ana l
            jz @exit
            ; If SPACE is pressed, check the old action code to ensure it was
            ; not pressed in the previous frame (to avoid repeated triggers).
            ana h
            ; If SPACE was pressed in the previous frame, jump to loop to wait
            ; for button release.
            jnz @loop
            mov a, l

@debug_output:
            ; Send the raw action code to the emulator debug port for inspection.
            ; Learners can send any bytes here for debugging purposes.
            out 0xED

            jmp @loop

@exit:
            ; Print zero to the stdout to indicate graceful exit.
            A_TO_ZERO(NULL)
            out 0xED
            ; For ROMs it stops the program, for COMs it returns to the OS.
            ret