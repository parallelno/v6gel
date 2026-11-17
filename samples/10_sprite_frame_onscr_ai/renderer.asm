; Each 64-row band is an independent erase-all / draw-all transaction. There are no
; overlap graphs, compositing buffers, saved-under sprite pixels, or blits.
; Positions are byte-aligned X (0..30), memory Y (0..241); height=15.
sprites:
            .byte 2,17, 3,22, 11,88, 12,93, 7,234
            .byte 15,42, 16,48, 0,175, 1,180, 26,221
old_sprites:
            .byte 2,17, 3,22, 11,88, 12,93, 7,234
            .byte 15,42, 16,48, 0,175, 1,180, 26,221
band_y:     .byte 0
job_y:      .byte 0
job_x:      .byte 0
job_row:    .byte 0
job_len:    .byte 0
scan_ptr:   .word 0
draw_mode:  .byte 0
render_count: .word 0
pending_bands: .byte 0
band_bit: .byte 0
deferred_frames: .word 0
density: .byte 0,0,0,0

renderer:
            ; Admission is all-or-nothing, before the first visible write.
            ; Four old and four new footprints per band bound the transaction.
            lxi h, old_sprites
            call check_density
            rc
            lxi h, sprites
            call check_density
            rc
            mvi a, 15
            sta pending_bands
            mvi a, 192
            sta band_y
            mvi a, 8
            sta band_bit
schedule_band:
            lda pending_bands
            mov b, a
            lda band_bit
            ana b
            jz next_band
            call wait_band
            jc next_band
            jmp band_begin
next_band:
            lda band_bit
            rrc
            ani 15
            jnz next_bit_ok
            mvi a, 8
next_bit_ok:
            sta band_bit
            lda band_y
            sui 64
            sta band_y
            jmp schedule_band
band_begin:
            ; Keep stack reads from immutable RAM disk safe from IRQ pushes.
            di
            xra a
            sta draw_mode
            lxi h, old_sprites
            call scan_sprites
            mvi a, 1
            sta draw_mode
            lxi h, sprites
            call scan_sprites
            ei
band_end:
            lda band_bit
            cma
            mov b, a
            lda pending_bands
            ana b
            sta pending_bands
            jnz next_band
            ; Commit old positions only after EVERY band used the old frame.
            lxi h, sprites
            lxi d, old_sprites
            mvi b, 20
commit_positions:
            mov a, m
            stax d
            inx h
            inx d
            dcr b
            jnz commit_positions
            lhld render_count
            inx h
            shld render_count
            ret

; Admit a transaction AFTER the beam has passed the entire 64-row band.
; The timer starts in the top border after IRQ; allow 8 lines for phase offset.
; Memory-Y band [y,y+63] is raster lines [192-y,255-y].
; Accept a short window starting at raster 304-y (40+256-y+8).
; Threshold is remaining PIT ticks (312-(304-y))*96 = (y+8)*96.
; Full 16-bit modular phase avoids line-0/border ambiguity. Carry means unsafe;
; the caller tries another unfinished band rather than blocking this one.
wait_band:
            lda band_y
            rrc
            rrc
            rrc
            mov b, a
            add a
            add b
            adi 3
            sta wait_threshold + 2
wait_poll:
            xra a
            out 8
            in 11
            mov e, a
            in 11
            mov d, a
wait_threshold:
            lxi h, 768
            ; HL = (threshold - remaining) modulo 29952 PIT ticks.
            mov a, l
            sub e
            mov l, a
            mov a, h
            sbb d
            jnc wait_positive
            ; Circular phase: a safe interval can cross the PIT reload.
            mov h, a
            lxi d, 29952
            dad d
            mov a, h
wait_positive:
            ; Whole-span kernels reduce the maximum transaction workload.
            ; 6144 PIT ticks leave about 33000 CPU cycles before the band top;
            ; density admission still limits each pass to four footprints.
            cpi 24
            jnc band_not_safe
            ora a
            ret
band_not_safe:
            stc
            ret

; One cheap Y rejection per sprite per pass; only intersections pay clipping.
scan_sprites:
            lda band_y
            sta scan_band + 1
            mvi b, 10
scan_next:
            inx h
            mov c, m
            inx h
scan_band:
            mvi a, 0
            sub c
            jc starts_inside
            cpi 15
            jnc scan_skip
            shld scan_ptr
            sta job_row
            mov e, a
            mvi a, 15
            sub e
            cpi 64
            jc clipped_len
            mvi a, 64
            jmp clipped_len
starts_inside:
            ; Reject if sprite starts at least 64 rows above this memory band.
            cma
            inr a
            cpi 64
            jnc scan_skip
            shld scan_ptr
            mov e, a
            mvi a, 64
            sub e
            cpi 15
            jc starts_len_ok
            mvi a, 15
starts_len_ok:
            sta job_len
            mov a, c
            sta job_y
            xra a
            sta job_row
            jmp dispatch_job
clipped_len:
            sta job_len
            lda band_y
            sta job_y
dispatch_job:
            push b
            lhld scan_ptr
            dcx h
            dcx h
            mov a, m
            sta job_x
            lda draw_mode
            ora a
            jz erase_job
            call draw_span
            jmp job_done
erase_job:
            call restore_span
job_done:
            pop b
            lhld scan_ptr
scan_skip:
            dcr b
            jnz scan_next
            ret

; Select one complete six-column restoration kernel by clipped height.
; All stack mapping is confined to this wrapper/kernel; IRQs are already off.
restore_span:
            lxi h, 0
            dad sp
            shld restore_stack + 1
            lda job_len
            cpi 15
            jz restore_fast_full
            add a
            mov e, a
            mvi d, 0
            lxi h, restore_lengths
            dad d
            mov e, m
            inx h
            mov d, m
            xchg
            shld restore_jump + 1
            lda job_x
            adi 0a0h
            mov h, a
            lda job_y
            mov l, a
            mov e, a
            mvi a, RAM_DISK_S0
            out RAM_DISK_PORT
restore_jump:
            jmp 0
restore_full_done:
            xra a
            out RAM_DISK_PORT
restore_stack:
            lxi sp, 0
            ret
restore_fast_full:
            lda job_x
            adi 0a0h
            mov h, a
            lda job_y
            mov l, a
            mov e, a
            mvi a, RAM_DISK_S0
            out RAM_DISK_PORT
            jmp restore_full_sprite

; A clipped 15-row sprite is always a prefix or suffix of its source image.
; Select a whole six-column kernel once, not six individual column callbacks.
draw_span:
            lda job_len
            cpi 15
            jz draw_fast_full
            lda job_row
            ora a
            jnz draw_suffix
            lda job_len
            jmp draw_index
draw_suffix:
            ; Nonzero row implies a suffix ending at the sprite's last row.
draw_suffix_index:
            adi 15
draw_index:
            add a
            mov e, a
            mvi d, 0
            lxi h, draw_spans
            dad d
            mov e, m
            inx h
            mov d, m
            xchg
            shld draw_jump + 1
            lda job_x
            adi 0a0h
            mov h, a
            lda job_y
            mov l, a
            mov e, a
draw_jump:
            jmp 0
draw_fast_full:
            lda job_x
            adi 0a0h
            mov h, a
            lda job_y
            mov l, a
            mov e, a
            jmp draw_full_sprite

; Return carry on overload. No partial frame or old-position commit on failure.
; Each 15-row sprite can intersect at most two 64-row memory bands.
check_density:
            push h
            lxi h, density
            mvi m, 0
            inx h
            mvi m, 0
            inx h
            mvi m, 0
            inx h
            mvi m, 0
            pop h
            mvi b, 10
density_loop:
            inx h
            mov a, m
            inx h
            push h
            mov c, a
            rlc
            rlc
            ani 3
            mov e, a
            mvi d, 0
            lxi h, density
            dad d
            inr m
            mov a, m
            cpi 5
            jnc density_fail
            mov a, c
            ani 63
            cpi 50
            jc density_next
            inx h
            inr m
            mov a, m
            cpi 5
            jnc density_fail
density_next:
            pop h
            dcr b
            jnz density_loop
            ora a
            ret
density_fail:
            pop h
            lhld deferred_frames
            inx h
            shld deferred_frames
            stc
            ret