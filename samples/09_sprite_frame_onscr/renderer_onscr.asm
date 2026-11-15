; renders sprites to the back buffer, then copies them to the screen
renderer_onscr:
                                       ; for 10 16x16 sprites:
            call init_sprite_masks_ptrs ;        1696 cc
            call init_spg_clusters     ;         5876 cc
            call update_spatial_grid   ;        15612 cc
            call init_render_batches  ;          3512 cc
                                       ; total: 26696 cc ; off screen render 34360 cc
            ret

; defines spg_sprite_mask = 1 << sprite_id for each sprite.
; inits the sprite ptrs contgues array
init_sprite_masks_ptrs:
            lxi h, sprites_onscr.spg_sprite_mask
            mvi a, SPR_MAX
            sta @counter + 1
            lxi d, 1 ; initial sprite mask
            lxi b, sprite_ptrs
@loop:
            ; store the sprite ptr
            mov a, l
            stax b
            inx b
            mov a, h
            stax b
            inx b
            ; store the 2-byte mask
            mov m, e
            HL_ADVANCE(sprites_onscr.spg_sprite_mask, sprites_onscr.spg_sprite_mask + 1)
            mov m, d
            HL_ADVANCE(sprites_onscr.spg_sprite_mask + 1, sprites_onscr.spg_sprite_mask + sprites_onscr.size, BY_BC)

            ; shift the mask
            xchg
            dad h
            xchg
            ; decrement, check the counter
@counter:   mvi a, TEMP_BYTE
            dcr a
            sta @counter + 1
            jnz @loop
            ret


init_spg_clusters:
            ; erase spatial_grid + clusters
            ; lxi h, spatial_grid
            ; lxi b, spg_clusters + SPG_CLUSTERS_LEN
            ; ; hl - source
            ; ; bc - source + len
            ; call mem_erase

            SPG_BUF_LEN = _filler_end - spg_clusters
			lxi b, _filler_end
			lxi d, SPG_BUF_LEN / 32 - 1
			mvi a, 0
			call mem_erase_sp
            ret


update_spatial_grid:
            lxi h, sprites_onscr.scr_y
            A_TO_ZERO(0)
            sta @sprite_counter + 1
@loop:
            ; read sprite scr addr
            mov e, m
            HL_ADVANCE(sprites_onscr.scr_y, sprites_onscr.scr_x)
            mov d, m
            HL_ADVANCE(sprites_onscr.scr_x, sprites_onscr.height)
            mov c, m
            HL_ADVANCE(sprites_onscr.height, sprites_onscr.width)
            mov b, m
            push b
            HL_ADVANCE(sprites_onscr.width, sprites_onscr.spg_sprite_mask)
            mov c, m
            HL_ADVANCE(sprites_onscr.spg_sprite_mask, sprites_onscr.spg_sprite_mask + 1)
            mov b, m
            HL_ADVANCE(sprites_onscr.spg_sprite_mask + 1, sprites_onscr + sprites_onscr.size)
            xthl
            ; sprites_onscr ptr in stack
            ; hl - height, width
            ; bc - spg_sprite_mask
            ; de - scr_xy
            push b
            call update_occupied_spg_cells
            pop d
            ; de - spg_sprite_mask
            ; bc - cumulative_cell_sprite_mask

            ; check if previously processed sprites occupy the same grid cells.
            mov a, e
            cmp c
            jnz @merge_clusters
            mov a, d
            cmp b
            jz @create_cluster

@merge_clusters:
            ; At least one previously processed sprite occupies one or more of
            ; the same grid cells.

            ; find all clusters that intersect the cumulative mask, merge them
            ; into the cummulative mask, those cluster array entry.
            lda @sprite_counter + 1
            mov d, a
            call merge_clusters

@create_cluster:
            ; Create a new cluster by storing `cumulative_cell_sprite_mask` in
            ; an empty cluster array entry.
            lda @sprite_counter + 1
            mov d, a
            call find_empty_cluster
            ; bc - merged cumulative_cell_sprite_mask
            ; hl points to the hi byte of the cluster
            ; store the merged cluster into the spg_clusters
            mov m, b
            dcx h
            mov m, c

            pop h
@sprite_counter:
            mvi a, TEMP_BYTE
            inr a
            sta @sprite_counter + 1
            cpi SPR_MAX
            jnz @loop
            ret


; merge all clusters that intersect the cumulative mask into the cumulative mask,
; then empty those cluster array entry.
; in:
; d - sprite_counter. used as a search depth
; bc - cumulative_cell_sprite_mask
; out:
; bc - merged cumulative_cell_sprite_mask
merge_clusters:
            lxi h, spg_clusters - 1 ; because the loop starts with increment

@merge_cluster_loop:
            ; d - strite id
            ; hl - spg_clusters
            ; bc - cumulative_cell_sprite_mask
            ; res = cluster_sprite_mask AND cumulative_cell_sprite_mask
            inx h
            mov a, m
            ana c
            mov e, a
            inx h
            mov a, m
            ana b
            ora e
            ; res  = 0 : cumulative_cell_sprite_mask has no intersections with
            ;            the current cluster. Continue to the next cluster.
            jz @merge_cluster_counter
            ; res != 0: Merge the cluster into the cumulative mask:
            ; cumulative_cell_sprite_mask |= cluster_sprite_mask
            mov a, m
            ora b
            mov b, a
            dcx h
            mov a, m
            ora c
            mov c, a
            ; clear the original cluster entry by setting it to zero.
            mvi m, 0
            inx h
            mvi m, 0
@merge_cluster_counter:
            dcr d
            jp @merge_cluster_loop
            ret


; find an empty cluster array entry
; in:
; d - sprite_counter. used as a search depth
; out:
; hl points to the hi byte of the cluster
find_empty_cluster:
            lxi h, spg_clusters - 1 ; because the loop starts with increment
@loop:
            inx h
            mov a, m
            inx h
            ora m
            rz
            dcr d
            jp @loop
            ret


; update grid cells occupied by a sprite
; in:
; de - scr addr
; h - width
;		00 - 8pxs,
;		01 - 16pxs,
;		10 - 24pxs,
; l - height
; bc - spg_sprite_mask
; out:
; bc - cumulative_cell_sprite_mask
update_occupied_spg_cells:
            mov a, c
            sta @sprite_mask + 1
            mov a, b
            sta @sprite_mask + 2

			; convert scr addr to 16x16 tile index
			mvi a, %00011110
			ana d
			rrc
			mov b, a
			mvi a, %11110000
			ana e
			mov c, a
			; b = x in tiles
			; c, a = y in tiles * 16

			; get scr addr of a top-left corner
            dad d

			; check bottom-left corner
			ora b
            mov e, a

			; get x+dx in tiles
			mvi a, %00011110
			ana h
			rrc
			mov h, a
			; h, a = x+dx in tiles

			; get bottom-right corner
			ora c
			mov d, a

			; get y+dy in tiles
			dcr l ; to be inside the AABB
			mvi a, %11110000
			ana l
			mov l, a
			; l, a = y+dy in tiles

			; get top-right corner
			ora h
            mov c, a

			; get top-left corner
			mov a, b
			ora l

            ; a - top-left corner tile idx
            ; c - top-right corner tile idx
            ; d - bottom-right corner tile idx
            ; e - bottom-left corner tile idx

            ; store the cell addr occupied by a top-right sprite corner
            mov l, c
            mvi h, 0
            lxi b, spatial_grid
            dad h ; double the offset because a cell size is 2 bytes
            dad b
            push h

            ; store the cell addr occupied by a top-left sprite corner
            mov l, a
            mvi h, 0
            dad h ; double the offset because a cell size is 2 bytes
            dad b
            push h

            ; store the cell addr occupied by the bottom-left sprite corner
            mov l, e
            mvi h, 0
            dad h ; double the offset because a cell size is 2 bytes
            dad b
            push h

            ; store the cell addr occupied by the bottom-right sprite corner
            mov l, d
            mvi h, 0
            dad h ; double the offset because a cell size is 2 bytes
            dad b

@sprite_mask:
            lxi b, TEMP_WORD
            ; update the cell addr occupied by a bottom-right sprite corner
            ; hl - cell addr
            ; bc - sprite_mask, it will accmulate cell_sprite_masks
            mov a, m
            ora c
            mov c, a
            mov m, a
            inx h
            mov a, m
            ora b
            mov b, a
            mov m, a

            ; update the cell addr occupied by a bottom-left sprite corner
            pop h
            ; hl - cell addr
            mov a, m
            ora c
            mov c, a
            mov m, a
            inx h
            mov a, m
            ora b
            mov b, a
            mov m, a

            ; update the cell addr occupied by a top-left sprite corner
            pop h
            ; hl - cell addr
            mov a, m
            ora c
            mov c, a
            mov m, a
            inx h
            mov a, m
            ora b
            mov b, a
            mov m, a

            ; update the cell addr occupied by a top-right sprite corner
            pop h
            ; hl - cell addr
            mov a, m
            ora c
            mov c, a
            mov m, a
            inx h
            mov a, m
            ora b
            mov b, a
            mov m, a
            ; bc - cumulative_cell_sprite_mask
			ret


; builds a render batch for each cluster that includes a bounding box pos, w, h,
; sprite ptrs.
init_render_batches:
            lxi h, sprite_ptrs
            shld current_sprite_ptr
            lxi h, render_batches
            shld current_render_batch

            lxi h, spg_clusters
            mvi a, <(spg_clusters + SPG_CLUSTERS_LEN)
            sta @check_loop + 1
@loop:
            ; get a cluster sprite mask
            mov a, m
            inx h
            mov b, m
            inx h

            mov c, a
            ; a - lo cluster sprite mask
            ; bc - cluster sprite mask

            push h
            call count_bits16
            pop h
            ; a - sprites in cluster
            ; bc - cluster sprite mask

            ; if empty, move to next
            jz @check_loop

            push h
            ; a - sprites in cluster
            ; bc - cluster sprite mask
            call init_render_batch
            pop h

@check_loop:
            mvi a, TEMP_BYTE
            cmp l
            jnz @loop
            ret

; builds a render batch that includes a bounding box pos, w, h, sprite ptrs.
; in:
; a - sprites in cluster
; bc - cluster sprite mask
init_render_batch:
            sta @check_loop + 1
@loop:
@check_loop:
            mvi a, TEMP_BYTE
            dcr a
            sta @check_loop + 1
            rm

;it is not enough for perf to have only a sprite number and a mask bits because
; we still do not know where enabled bits are and we will spin loop iteratiions
; on disabled bits.

; we need count_bits16 to provide a bit indeces that we will convert into sprite
; ptrs.
; or do not use prite aabb at all, and uset spatial grid cells, so we do not need
; to spend time on building cummulative cluster sprites aabb.
; but firstly check the perf of this func with just handling a aabb for one sprite
; it can be enough slow to give up on this approach.

            ; convert the sprite mask to the sprite ptr
            ; calc the sprite idx
            push psw
            mvi a, 7
            sub c
            ; get the sprite ptr
            ; a - sprite idx
            HL_TO_AX2_PLUS_INT16(sprite_ptrs)
            mov e, m
            inx h
            mov d, m
            ; de - sprite ptr

            ; store the sprite ptr into a batch
            lhld current_render_batch
            mov m, e
            HL_ADVANCE(render_batches.ptr, render_batches.ptr + 1)
            mov m, d
            HL_ADVANCE(render_batches.ptr + 1, render_batches.height)

            ; calc the cluster cummulative bounding box
            ; if it's a first sprite, copy its aabb
            mov a, m
            CPI_ZERO(0)
    ;        jnz @extend_existing_aabb

            ; copy sprite's aabb to a cluster's
            HL_ADVANCE(render_batches.height, render_batches.scr_y)
            ; de - points to sprite.scr_y
            ; hl - points to cluster.scr_y
            ldax d
            mov m, a
            DE_ADVANCE(sprites_onscr.scr_y, sprites_onscr.scr_x)
            HL_ADVANCE(render_batches.scr_y, render_batches.scr_x)
            ldax d
            mov m, a
            DE_ADVANCE(sprites_onscr.scr_x, sprites_onscr.height)
            HL_ADVANCE(render_batches.scr_x, render_batches.height)
            ldax d
            mov m, a
            DE_ADVANCE(sprites_onscr.height, sprites_onscr.width)
            HL_ADVANCE(render_batches.height, render_batches.width)
            ldax d
            mov m, a




            pop psw

            ret
