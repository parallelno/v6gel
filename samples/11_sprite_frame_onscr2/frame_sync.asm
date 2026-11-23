BEAM_OUT_OF_SCR = 0

FRAME_BORDER_TOP    = 40
FRAME_SCR           = 256
FRAME_BORDER_BOTTOM = 16

FRAME_LINES      = FRAME_BORDER_TOP + FRAME_SCR + FRAME_BORDER_BOTTOM
FRAME_LINE_TIME  = 96
FRAME_TIME       = FRAME_LINES * FRAME_LINE_TIME


; set the timer to sync with the start of the frame
; requres EI (enable interrupts) to be called before
set_frame_timer:
            hlt ; sync to the start of the frame
            mvi a, 34h      ; счётчик 0, мл.+ст. байт, режим 2
            out 8
            ; submit the counter (7500h)
            A_TO_ZERO(<FRAME_TIME)
            out 11
            mvi a, >FRAME_TIME
            out 11
            ret


; read the timer
; out:
; a - remaining time until the end of the frame in range [0..FRAME_TIME / 128)
; which is [0..234)
get_frame_timer:
            A_TO_ZERO(NULL) ; защёлкнуть счётчик 0
            out 8
            in 11
            ral
            in 11
            ral
            ret


; remap scr_y into a timer range [30, 221].
; in:
; l - scr_y
; out:
; a - scr_y mapped to CRT_Y remapped into [0-234) range
SCR_Y_TO_TIMER_BC = 0
SCR_Y_TO_TIMER_DE = 1
SCR_Y_TO_TIMER_HL = 2
.macro SCR_Y_TO_TIMER(regpair=SCR_Y_TO_TIMER_HL)
        .if regpair == SCR_Y_TO_TIMER_BC
            .error "SCR_Y_TO_TIMER(regpair=SCR_Y_TO_TIMER_BC) is unimplemented"
        .endif
        .if regpair == SCR_Y_TO_TIMER_DE
            .error "SCR_Y_TO_TIMER(regpair=SCR_Y_TO_TIMER_DE) is unimplemented"
        .endif
        .if regpair == SCR_Y_TO_TIMER_HL
            mvi h, >remap_256_192
            mov a, m
        .endif
.endmacro

.align 256
remap_256_192:
            .byte 221,221,220,219,218,218,217,216,215,215,214,213,212,212,211,210
            .byte 209,209,208,207,206,206,205,204,203,203,202,201,200,200,199,198
            .byte 197,197,196,195,194,194,193,192,191,191,190,189,188,188,187,186
            .byte 185,185,184,183,182,182,181,180,179,179,178,177,176,176,175,174
            .byte 173,173,172,171,170,170,169,168,167,167,166,165,164,164,163,162
            .byte 161,161,160,159,158,158,157,156,155,155,154,153,152,152,151,150
            .byte 149,149,148,147,146,146,145,144,143,143,142,141,140,140,139,138
            .byte 137,137,136,135,134,134,133,132,131,131,130,129,128,128,127,126
            .byte 125,125,124,123,122,122,121,120,119,119,118,117,116,116,115,114
            .byte 113,113,112,111,110,110,109,108,107,107,106,105,104,104,103,102
            .byte 101,101,100,99,98,98,97,96,95,95,94,93,92,92,91,90
            .byte 89,89,88,87,86,86,85,84,83,83,82,81,80,80,79,78
            .byte 77,77,76,75,74,74,73,72,71,71,70,69,68,68,67,66
            .byte 65,65,64,63,62,62,61,60,59,59,58,57,56,56,55,54
            .byte 53,53,52,51,50,50,49,48,47,47,46,45,44,44,43,42
            .byte 41,41,40,39,38,38,37,36,35,35,34,33,32,32,31,30


; read the timer
; out:
; hl - remaining time until the end of the frame (0..FRAME_TIME)
; error: the actual current rasterized line is 5 lines below,
; so the correct output is hl += 5*FRAME_LINE_TIME, must be accounted for.
; get_frame_timer:
;             A_TO_ZERO(NULL) ; защёлкнуть счётчик 0
;             out 8
;             in 11
;             mov l, a
;             in 11
;             mov h, a
;             ret


; ; get the aproximete currently rasterized line
; ; use:
; ; a, hl
; ; out
; ; a - aproximete currently rasterized line in a range of 0..255
; ; a = BEAM_OUT_OF_SCR if it's out of screen.
; get_scr_rast_line:
;             call get_frame_timer
;             ; hl - counter in a range of 0..FRAME_TIME

;             ; div by 128 = >>7 = <<1
;             dad h
;             ; h - current frame line remapped from [0, FRAME_LINES)
;             ; to [0..234)

;             ; check if it's insode the top border.
;             mvi a, 204 ; FRAME_BORDER_BOTTOM + FRAME_SCR mapped from [0..312) to [0..234)
;             sub h
;             jc @out_of_scr

;             ; sub bottom border
;             mvi a, -12 ; FRAME_BORDER_BOTTOM mapped from [0..312) to [0..234)
;             add h
;             jnc @out_of_scr

;             ; a is an aproximete currently rasterized screen line in
;             ; a range of [0..192). remap it to [0..256)
;             HL_TO_A_PLUS_INT16 (remap_192_to_256)
;             mov a, m
;             ret
; @out_of_scr:
;             A_TO_ZERO(BEAM_OUT_OF_SCR)
;             ret



; temp\scripts\generate_remap_192_to_256.py
; remap_192_to_256:
;             .db 0, 1, 3, 4, 5, 7, 8, 9, 11, 12, 13, 15, 16, 17, 19, 20
;             .db 21, 23, 24, 25, 27, 28, 29, 31, 32, 33, 35, 36, 37, 39, 40, 41
;             .db 43, 44, 45, 47, 48, 49, 51, 52, 53, 55, 56, 57, 59, 60, 61, 63
;             .db 64, 65, 67, 68, 69, 71, 72, 73, 75, 76, 77, 79, 80, 81, 83, 84
;             .db 85, 87, 88, 89, 91, 92, 93, 95, 96, 97, 99, 100, 101, 103, 104, 105
;             .db 107, 108, 109, 111, 112, 113, 115, 116, 117, 119, 120, 121, 123, 124, 125, 127
;             .db 128, 129, 131, 132, 133, 135, 136, 137, 139, 140, 141, 143, 144, 145, 147, 148
;             .db 149, 151, 152, 153, 155, 156, 157, 159, 160, 161, 163, 164, 165, 167, 168, 169
;             .db 171, 172, 173, 175, 176, 177, 179, 180, 181, 183, 184, 185, 187, 188, 189, 191
;             .db 192, 193, 195, 196, 197, 199, 200, 201, 203, 204, 205, 207, 208, 209, 211, 212
;             .db 213, 215, 216, 217, 219, 220, 221, 223, 224, 225, 227, 228, 229, 231, 232, 233
;             .db 235, 236, 237, 239, 240, 241, 243, 244, 245, 247, 248, 249, 251, 252, 253, 255
