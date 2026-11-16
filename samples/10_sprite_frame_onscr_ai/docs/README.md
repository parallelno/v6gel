# Direct, beam-aware overlapping sprites

## Status and measured result

This sample renders ten overlapping knights directly into the three colour
planes at `$A000..$FFFF`. It does not construct an off-screen composite or copy
one to the screen. Sample 09 and its unfinished implementation are unchanged.

**The active rendering work beats 117,488 cycles, but total elapsed time does
not consistently beat it.** Do not interpret the active-work figure as a
wall-clock result. The final conservative scheduler deliberately waits when
the beam is too close.

Measured with V6EMUL `2026.10.21-3813e34`:

| Measurement | CPU cycles |
| --- | ---: |
| Three repeated ten-sprite updates: sum of four active bands | 93,760 each |
| Largest measured active band | 29,880 |
| Six moving updates, including admission, scheduling and waiting | 114,368; 128,812; 111,872; 127,684; 147,352; 136,272 |
| Supplied off-screen reference | 117,488 |

Active work is about 20.2% below the supplied reference, before adding density
admission, scheduler and waiting overhead. Thus **the strict end-to-end speed
requirement remains unmet** for several tested frames. This is a working,
tested renderer with an explicit limitation, not a claim of a universally
faster implementation. An update may take more than one 50 Hz display refresh.

## Build, test and run

The sample uses the same asset exporter, engine object, assembler and linker
pipeline as sample 09. From the repository root:

```powershell
make -f samples/10_sprite_frame_onscr_ai/Makefile all
make -f samples/10_sprite_frame_onscr_ai/Makefile test
& $env:V6EMUL -rom build/10_sprite_frame_onscr_ai/10_sprite_frame_onscr_ai.rom -run-frames 200
```

`V6ASM`, `V6CLANG`, `READELF` and `PYTHON` can be overridden as in sample 09.
`V6EMUL` must name the command-line emulator executable for tests. The test
client needs only the Python standard library; its small MessagePack encoder
and decoder implement the subset of the documented IPC protocol it uses.

The installed **release assembler failed on existing engine expressions** such
as `mvi a, ~SCR_ADDR_MASK` (it rejects -225). No shared engine sources were
modified to work around that. Validation used the installed debug assembler:

```powershell
make -f samples/10_sprite_frame_onscr_ai/Makefile test V6ASM=C:/Work/Programming/v6asm/target/debug/v6asm.exe
```

Controls and music are disabled. Initialization uses the engine palette fade
and room drawing; steady-state operation installs a minimal interrupt handler
so the engine's debug/FPS writes cannot damage the visible image.

## Coordinate system and input contract

A **memory band** is a contiguous range of low screen-address bytes. Vector
screen memory is column-major: the high byte selects a byte column and plane,
and the low byte selects vertical position. Memory Y increases *up* the
display, opposite to raster-line numbering.

`sprites` contains ten `(x_byte, memory_y)` pairs, in back-to-front order.
`old_sprites` records the last committed positions. Input restrictions:

* X is byte aligned, 0..30. The sprite occupies two byte columns.
* Y is 0..241. The exported knight is **16 x 15**, not 16 x 16; sample 09's
  first idle frame uses this same 15-row asset inside its 16-row footprint.
* There is one compiled idle frame. Animation-frame selection, pixel-aligned
  horizontal preshifts, clipping off screen and variable dimensions are not
  implemented.
* The background and palette remain fixed after initialization. Changing the
  room requires refreshing the immutable background and resetting old state.
* Positions are a snapshot: do not change them while `renderer` is executing.

The demo moves all ten X positions by one byte every 32 completed loop calls,
wrapping at the right edge. Its initial positions deliberately include several
overlapping pairs. Tests additionally move Y across band boundaries.

## Algorithm

The screen is partitioned into four disjoint 64-row memory bands. A
**transaction** means restoring all old sprite footprints in one band and
then drawing every new sprite intersecting that band, with no beam visit
between the two operations.

1. Count old and new footprints in each band. If either exceeds four, defer
   the entire update **before writing any screen bytes**. `deferred_frames`
   counts these rejections. The old image and old positions are retained.
2. Set four pending bits, one per band.
3. Scan pending bands. Check their beam phase; skip an unsafe band immediately
   and try another. No band waits while a different one could be processed.
4. Disable interrupts for an admitted transaction. For every old rectangle,
   restore its intersection from the immutable background. Then visit new
   sprites in increasing array order and draw their intersections.
5. Enable interrupts and clear the band's pending bit.
6. Once all bands finish, copy positions to `old_sprites` and increment
   `render_count`.

The fixed partition is not a sprite occupancy grid: there are no cell sprite
masks, cluster graphs, pairwise overlap tests or cluster bounding boxes.

### Why overlap works

All erases precede all draws *within the same disjoint band*. Restoring one old
rectangle therefore cannot erase a newly drawn neighbour. Redrawing new
sprites in a stable order produces ordinary masked back-to-front composition.
The last sprite wins only at opaque pixels. Drawing a masked byte is:

```text
screen = (screen AND preserve_mask) OR colour_bits
```

The preserve mask is shared across the three planes. Unmodified plane `$8000`
is left alone. Repeated restoration of overlapping rectangles is harmless:
every restoration reads the same immutable background, never saved sprite
pixels. A sprite crossing a band boundary is split into independently safe
pieces. Its old and new positions need not intersect the same bands.

## Compiled drawing and restoration

`compile_sprite.py` consumes the exported `KNIGHT.BIN`, not a hand-redrawn
substitute. It decodes the exporter's alternating column/plane traversal and
emits assembly into the build directory.

For a complete 15-row intersection, generated code is fully unrolled over
the six columns. This removes per-row loop tests, data loads and screen-plane
address arithmetic. A zero preserve mask becomes an immediate store; setting
all non-preserved bits can become a single OR rather than AND followed by OR.

For a clipped intersection, a row/column entry-point table jumps into an
unrolled column chain, and a row counter stops at the clipped end. Restoration
has length-specific unrolled entry points. Full rectangles have an additional
fast path with no column loop. Source-background reads use `POP B` from the
RAM disk while ordinary memory stores target the visible screen.

Self-modifying operands hold column addresses, continuation pointers and the
saved stack pointer, following the engine's existing assembly style. The
renderer is not reentrant. Interrupts are disabled before the stack is mapped
and restored only after SP and RAM-disk mapping return to normal.

## Beam scheduling

The **PIT** is the programmable interval timer. Counter 0 runs in mode 2 with
29,952 ticks per frame: 312 lines x 96 timer ticks. The CPU runs two cycles per
timer tick; a display frame therefore occupies 59,904 CPU cycles.

Initialization synchronizes with `HLT`, then starts the PIT in the top border.
With normal vertical scroll 255, memory band `[y,y+63]` appears at active raster
rows `[192-y,255-y]`, plus the 40-line top border.

The safe-window start is conservatively set to raster `304-y`: the band's
bottom plus eight extra lines. Remaining timer ticks there are `(y+8)*96`.
For the four possible Y values this is computed cheaply in the high byte;
the low byte is zero. The latched 16-bit timer value is subtracted modulo
29,952. A band is eligible only during the first 3,072 timer ticks after that
threshold. Circular subtraction handles windows spanning frame wrap.

The safety strategy has two parts: a narrow start window and a maximum of
four old plus four new footprints per band. Tests independently read the
emulator raster at transaction entry and assert the complete transaction
finishes before the next visit to that band's *top*. Twelve tested
transactions pass; the lowest observed remaining deadline in that run was
41,960 cycles, compared with a maximum measured workload of 29,880.

This is **emulator-validated scheduling for the documented fixed workload**,
not a formal exhaustive hardware timing proof. Real hardware timer phase and
the worst combination of clipped/old/new rectangles should be validated
before treating the density bound as a production guarantee. Music, long
interrupt handlers, altered scrolling, different sprite dimensions or CPU
timing invalidate these assumptions. The scheduler does not guarantee an
atomic whole-screen swap: independently completed bands may become visible
on different refreshes, but the tested transactions avoid erase/draw beam
crossings.

## Memory

One RAM-disk bank holds a 24,576-byte immutable copy of `$A000..$FFFF` at the
same CPU addresses. No second background, compositing backbuffer or
saved-under sprite storage is required. This is under the permitted 64 KiB.
No RAM-disk lookup table is necessary; compiled code and small entry tables
are in ordinary RAM below the screen. Room and palette assets use the existing
linker/exporter layout. Generated code is intentionally traded for runtime
speed. `old_sprites` needs 20 bytes; pending/density/job state is small.

## Verification details

`tests/verify.py` starts an isolated emulator IPC server on a free port, checks
protocol version 2, loads the ROM deterministically, and uses debugger
breakpoints. It does not use `RUN_HEADLESS` for breakpoints: that emulator
command does not evaluate debugger breakpoints.

The test captures the pristine room, then computes an independent full-screen
reference composition. It checks **all 24,576 bytes** after each of six moving
updates, including overlap, old-footprint erasure, right-edge wrapping and
band crossing. It times renderer entry through return separately from active
transactions, verifies twelve transaction deadlines, asserts active work is
below 117,488 cycles, and checks that ten sprites concentrated into one band
are rejected without changing either screen RAM or old positions.

The test does not assert the end-to-end target because the measured final
implementation does not meet it consistently. Next optimizations should target
admission/dispatch overhead, clipping fast paths, and scheduling against a
per-band cycle budget rather than a fixed narrow window. Those changes must
retain the independent reference and raster-deadline checks.