; ---------------------------------------------------------------------------
; Utility: wait for any key press (frame-synced)
; This routine demonstrates a safe zero-check idiom using `CPI_ZERO` macro,
; details in `samples/01_controls` and `v6_macros.asm`.
; Out:
;  A - action code of the key pressed
; ---------------------------------------------------------------------------
wait_until_any_key_pressed:
            ; delay 1/50th of a second (1 frame).
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
            jz wait_until_any_key_pressed

            ; Check the old action code to ensure it was not pressed in the
            ; previous frame (to avoid repeated triggers).
            ana h
            jnz wait_until_any_key_pressed
            mov a, l
            ret