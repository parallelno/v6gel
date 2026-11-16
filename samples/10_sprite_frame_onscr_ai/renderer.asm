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
scan_count: .byte 0
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
            cpi 12
            jnc band_not_safe
            ora a
            ret
band_not_safe:
            stc
            ret

; One cheap Y rejection per sprite per pass; only intersections pay clipping.
scan_sprites:
            mvi a, 10
            sta scan_count
scan_next:
            inx h
            mov c, m
            inx h
            lda band_y
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
            lhld scan_ptr
scan_skip:
            lda scan_count
            dcr a
            sta scan_count
            jnz scan_next
            ret

; Restore six short columns with POP B from bank 0 while writes use main RAM.
; SP is never used for CALL/RET while mapped. IRQs are disabled by band_begin.
restore_span:
            lxi h, 0
            dad sp
            shld restore_stack + 1
            lda job_len
            cpi 15
            jz restore_full
            lda job_len
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
            mvi a, RAM_DISK_S0
            out RAM_DISK_PORT
            lda job_x
            adi 0a0h
            sta restore_column + 1
            mvi a, 6
            sta restore_columns + 1
restore_column:
            mvi h, 0
            lda job_y
            mov l, a
            sphl
restore_jump:
            jmp 0
restore_column_done:
            ; Columns: A0+x,A1+x,C0+x,C1+x,E0+x,E1+x.
            lda restore_columns + 1
            ani 1
            mvi e, 1
            jz restore_step
            mvi e, 31
restore_step:
            lda restore_column + 1
            add e
            sta restore_column + 1
restore_columns:
            mvi a, 6
            dcr a
            sta restore_columns + 1
            jnz restore_column
restore_full_done:
            xra a
            out RAM_DISK_PORT
restore_stack:
            lxi sp, 0
            ret
restore_full:
            lda job_x
            adi 0a0h
            mov h, a
            lda job_y
            mov l, a
            mov e, a
            mvi a, RAM_DISK_S0
            out RAM_DISK_PORT
            jmp restore_full_sprite

; Six column spans eliminate per-pixel screen-plane address arithmetic.
draw_span:
            lda job_len
            cpi 15
            jz draw_full
            lda job_row
            mov l, a
            mvi h, 0
            dad h
            mov d, h
            mov e, l
            dad h
            dad d
            dad h
            lxi d, compiled_rows
            dad d
draw_table_ready:
            shld draw_ptr + 1
            lda job_x
            adi 0a0h
            sta draw_column + 1
            mvi a, 6
            sta draw_columns + 1
draw_ptr:
            lxi h, 0
            mov e, m
            inx h
            mov d, m
            inx h
            shld draw_ptr + 1
draw_column:
            mvi h, 0
            lda job_y
            mov l, a
            lda job_len
            mov b, a
            push h
            lxi h, draw_column_done
            xthl
            push d
            ret
draw_column_done:
            lda draw_columns + 1
            ani 1
            mvi e, 1
            jz draw_step
            mvi e, 31
draw_step:
            lda draw_column + 1
            add e
            sta draw_column + 1
draw_columns:
            mvi a, 6
            dcr a
            sta draw_columns + 1
            jnz draw_ptr
            ret
draw_full:
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