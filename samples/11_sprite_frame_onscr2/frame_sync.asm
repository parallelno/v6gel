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


; Reads the timer synced with the frame rasterizer. It's a zero at the bottom
; CRT line, and FRAME_TIME / 128 at the top CRT line.
; out:
; a - remaining time until the end of a frame in range [0..FRAME_TIME / 128)
; which is [0..234)
; use: a
get_frame_timer:
            A_TO_ZERO(NULL) ; защёлкнуть счётчик 0
            out 8
            in 11
            ral
            in 11
            ral
            ret


; remaps scr_y into a timer range [30, 221]
.align 256
scr_y_to_timer:
            .byte 30,31,32,32,33,34,35,35,36,37,38,38,39,40,41,41
            .byte 42,43,44,44,45,46,47,47,48,49,50,50,51,52,53,53
            .byte 54,55,56,56,57,58,59,59,60,61,62,62,63,64,65,65
            .byte 66,67,68,68,69,70,71,71,72,73,74,74,75,76,77,77
            .byte 78,79,80,80,81,82,83,83,84,85,86,86,87,88,89,89
            .byte 90,91,92,92,93,94,95,95,96,97,98,98,99,100,101,101
            .byte 102,103,104,104,105,106,107,107,108,109,110,110,111,112,113,113
            .byte 114,115,116,116,117,118,119,119,120,121,122,122,123,124,125,125
            .byte 126,127,128,128,129,130,131,131,132,133,134,134,135,136,137,137
            .byte 138,139,140,140,141,142,143,143,144,145,146,146,147,148,149,149
            .byte 150,151,152,152,153,154,155,155,156,157,158,158,159,160,161,161
            .byte 162,163,164,164,165,166,167,167,168,169,170,170,171,172,173,173
            .byte 174,175,176,176,177,178,179,179,180,181,182,182,183,184,185,185
            .byte 186,187,188,188,189,190,191,191,192,193,194,194,195,196,197,197
            .byte 198,199,200,200,201,202,203,203,204,205,206,206,207,208,209,209
            .byte 210,211,212,212,213,214,215,215,216,217,218,218,219,220,221,221


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
