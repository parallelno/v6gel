; ------------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * main entry point setup
;    * debug output
;    * disabled V6_MUSIC, V6_CONTROLS, V6_INTERRUPTIONS features in build.bat
; ------------------------------------------------------------------------------

; Expose `main` symbol so the linker and engine can call into this demo.
.global main

main:
            ; Send the `42` test value to the emulator debug port which redirects
            ; it to the stdout for inspection.
            ; Learners can send any bytes here for debugging purposes.
            mvi a, 42
            out 0xED

@exit:
            ; Return to crt0, then halt (DI, HLT): engine\v6.asm, lines #86-87
            ; In the next v6 gel releases COM executibles will properly return to OS.
            ret