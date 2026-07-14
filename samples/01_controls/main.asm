; ------------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * read controls
;    * debug output
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

            ; Read action code provided by the engine (bitmask of pressed keys).
            lda v6_action_code

            ; Quick check: if action code equals CONTROL_CODE_NO (zero), continue.
            ; `CPI_ZERO` macro performs a safety check to ensure the constant
            ; is zero. It makes the usage of a `ora a` operation (optimized
            ; comparison with zero) safe and clear.
            CPI_ZERO(CONTROL_CODE_NO)
            jz @loop

            ; Mask direction keys (example): if none of the four directions are set,
            ; jump to exit. This demonstrates using `ani` with a combined mask.
            ani CONTROL_CODE_UP | CONTROL_CODE_DOWN | CONTROL_CODE_LEFT | CONTROL_CODE_RIGHT
            jz @exit

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