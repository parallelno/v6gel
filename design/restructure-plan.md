# v6gel Restructure Plan

Status: APPROVED DESIGN — ready to implement. Authored 2026-06-15.

This document is the agreed plan for restructuring v6gel from a game-fused
codebase into a reusable engine + toolchain that serves four project shapes.
It captures *what* we will do and *why*, plus the concrete sequencing. It does
not change behavior on its own — it guides the edits that follow.

> Companion note: the same decisions are mirrored in repo memory at
> `/memories/repo/architecture-vision.md` for cross-session continuity.

---

## 1. Goals (the "why")

1. The **product is the engine** (asm runtime). Everything in `scripts/` is a
   **toolchain**, not product source.
2. The repo is a **skeleton** users fork: copy a sample, drop in their own
   code + assets, build with minimal setup.
3. Support **four project shapes**, on two independent axes:

   |                         | pure ASM user code | C user code |
   |-------------------------|--------------------|-------------|
   | **small → single ROM**  | `02_rom_asm`       | `01_rom_c`  |
   | **big → FDD image**     | `04_fdd_asm`       | `03_fdd_c`  |

   The ROM/FDD axis = how assets reach the program (embedded vs streamed).
   The ASM/C axis = which front end compiles user code (both link via lld).
4. **Transparency over magic.** The pipeline's stages are visible as Makefile
   targets, not hidden inside one orchestrator script.

---

## 2. Target repository layout

```
v6gel/
  engine/                 # was v6/ — the asm runtime (THE product)
    common/ controls/ gfx/ misc/ os/ sound/
    v6.asm
  scripts/                # KEEP name. Toolchain, made importable (package-ified)
    v6gel/                #   importable package (no sys.path hacks)
      exporters/
      loadgen/
      utils/
      cli/                #   v6export / v6loads entry points
    pyproject.toml deps already declared at repo root
  tools/                  # external installed binaries (unchanged)
  samples/                # example projects = copyable templates
    01_rom_c/
      project.json        #   name, lang=c, target=rom, defines, entry
      src/main.c
      assets/             #   THIS project's sources (discovered)
      build/              #   THIS project's outputs (gitignored)
    02_rom_asm/           # small · ROM · pure asm
    03_fdd_c/             # big · FDD · C   (+ fdd_loads.json)
    04_fdd_asm/           # big · FDD · pure asm (+ fdd_loads.json)
  docs/  design/  Makefile  install_tools.py  tools.lock.json
```

Key rules:
- Each sample **owns** its `assets/`, `build/`, config, and `src/`.
- Samples **never reach sideways** into sibling output dirs. A sample depends
  only on (a) the shared `engine/` and (b) its own `build/` root.
- `engine/` keeps internal file/tool identifiers (`v6.asm`, `v6asm`) unchanged;
  only the folder name changes (per repo naming memory).

---

## 3. Config model (per project)

### ROM project (`samples/01_rom_c/project.json`)
```jsonc
{
  "schema": "v6gel/project",
  "name": "hello",
  "target": "rom",
  "lang": "c",                 // "c" | "asm"
  "entry": "src/main.c",
  "defines": { "DEBUG": 1, "TEXT_MONOSPACED_CHARS": 0, "LOCALIZATION": 0 }
}
```
No load plan. User hand-writes `.include` of each asset's `_meta.asm` and
`.incbin` of its `.bin`, choosing placement themselves (transparent + flexible).

### FDD project (`samples/03_fdd_c/`)
`project.json` (same shape, `target: "fdd"`) **plus** `fdd_loads.json`:
```jsonc
{
  "permanent": [ "font", "song01", "pal_menu" ],
  "menu":      [ "tim_data", "tim_gfx", "txt_menu" ],
  "level0":    [ "hero", "skeleton", "lv0_data", "lv0_gfx" ]
}
```
- `fdd_loads.json` carries **grouping** — irreducible authoring info that
  discovery cannot infer.
- It is consumed by **two** FDD build stages (codegen AND image packing). Kept
  as two stages for pipeline simplicity; both read the same file.
- FDD build **validates** group names against discovered assets and warns on
  mismatch (named-but-missing, or present-but-ungrouped).

### Fields removed from the old `assets/config.json`
| Old field | Verdict |
|-----------|---------|
| `game_name` | keep as `name` (output naming) |
| `consts` | DROP — replaced by `-D` defines (see §4) |
| `scripts` (debugger Lua) | DELETE from build config (debug metadata lives elsewhere, TBD) |
| `dependencies` (rebuild tracking) | DELETE — rebuild policy is "keep simple" (§6) |
| `export_dir` | DROP — toolchain controls layout |
| `packer_path`, `build_db_path` | DELETE — resolved by `utils/tools.py`; tracking gone |
| `basefdd_path` | move into FDD config; `--fdd-template` CLI overrides |
| `ram_disk_reserve` | engine invariant — eventual goal: engine exposes to packer; stays FDD-only config until that channel exists |
| `types_alignment` | DELETE — music no longer needs 256-align |
| `loaded_after_stack` | becomes an ASSET-TYPE property, not config |

---

## 4. Constants / symbols

- Engine uses **assembly-time** conditionals (`.if DEBUG`,
  `.if TEXT_MONOSPACED_CHARS`). These need **assembly-time** defines.
- Use v6asm's `-D NAME=value` / `-D FLAG` for engine + asm user code.
- `-Wl,--defsym=NAME=value` is **link-time only** (e.g. `__stack_top`) — use it
  *only* for true linker symbols, never for `.if`.
- Consequence: the **engine is assembled per-project** (header-like), so each
  project's `defines` apply. It's fast (~0.4 s); not a prebuilt `v6.o`.
- The build driver translates `project.json` `defines` → `-D` flags.

---

## 5. Pipeline: decomposed, Make-visible stages

Replace the all-in-one `build_assets.py` orchestrator with focused scripts,
each surfaced as a Make target. Keep **format logic in Python**; keep
**orchestration/ordering in the Makefile**.

```
EXPORT  (shared, target-agnostic, LENIENT)
  discover assets/**  →  per asset: .bin + _meta.asm + manifest
  broken asset → log in report, CONTINUE, exit 0
  stage-level failure (missing tool / unwritable dir / bad config) → exit nonzero

         ↓ build depends on export outputs (one-directional)

ROM build (STRICT)
  link engine(+defines) + user code; user .include's _meta.asm + .incbin's .bin
  missing .bin → assembler/linker fails for free

FDD build (STRICT) — two stages, both read fdd_loads.json
  1. codegen  : loads.asm / autoexec  (validate groups vs discovered assets)
  2. pack     : v6fdd image from template + stored blobs
  missing required (grouped) asset → stop with a clear error
```

Proposed Make targets (per sample, e.g. `SAMPLE=01_rom_c`):
```
make export   SAMPLE=…   # stage: discover + export (lenient, writes report)
make rom      SAMPLE=…   # ROM link  (depends on export)
make fdd-gen  SAMPLE=…   # FDD codegen (depends on export)
make fdd      SAMPLE=…   # FDD image  (depends on fdd-gen)
make run      SAMPLE=…   # build + launch in emulator
make clean    SAMPLE=…
```

### Failure semantics (locked)
- **Export = lenient.** Per-asset isolation; one broken asset never aborts the
  batch. Report prints a summary like `N ok, M failed: hero, vampire`. The
  report is load-bearing (only place asset failures surface before build).
- **Build = strict.** Stops on a missing *required* asset. "Required" =
  FDD: every asset named in `fdd_loads.json`; ROM: enforced by the toolchain
  via `.incbin`.

---

## 6. Rebuild policy

- Make rebuilds a target when a listed prerequisite is newer.
- We do **not** track toolchain `.py` mtimes as asset prerequisites (by choice,
  option "keep simple"). After changing exporters/toolchain: `make clean` then
  rebuild.
- The old `dependencies` + `build.db` staleness system stays deleted.

---

## 7. Implementation sequencing (lowest risk → highest)

Each step is independently verifiable via a `make` target; no long broken
window.

**Step 1 — Foundations (rename + package-ify).**
- Rename `v6/` → `engine/`; update include paths in `engine/build.bat`,
  Makefile, and docs.
- Make `scripts/` an importable package (`scripts/v6gel/…`), drop every
  `sys.path.insert(...)`; wire console entry points in `pyproject.toml`.
- Verify: `make engine`, `make assets` (legacy path) still pass.

**Step 2 — ROM packaging path.**
- Add the discovery-based export entry + the ROM build (engine+defines link;
  manual `.include`/`.incbin` model).
- Verify: produce a `.rom` from existing assets.

**Step 3 — First self-contained sample.**
- Convert current sample 01 into `samples/01_rom_c/` (own `project.json`,
  `assets/`, `src/`, `build/`). Move the demo art it needs into it.
- Verify: `make rom SAMPLE=01_rom_c && make run SAMPLE=01_rom_c`.

**Step 4 — Per-project `build/` unification.**
- Route all generated artifacts under each sample's `build/`; one clean target.

**Step 5 — Remaining sample shapes.**
- Add `02_rom_asm`, `03_fdd_c` (with `fdd_loads.json`), `04_fdd_asm` as they
  mature. FDD path reuses today's `v6loads`/`v6fdd` logic, split into the two
  Make-visible stages.

Deferred (only when requested): WIP skip convention (leading `_` to exclude
draft assets from discovery).

---

## 8. Already completed (context)

- Deleted dead scripts: `generate_asset_projects.py`,
  `generate_const_incs_loads.py`, `utils/build.py`.
- `scripts/utils/tools.py` resolves v6asm/v6fdd/zx0 (flag → env → `tools/` → PATH);
  removed hardcoded `C:\…` defaults.
- `pyproject.toml` (deps Pillow, lhafile; ruff dev extra).
- `install_tools.py` + `tools.lock.json` (manifest-driven installer).
- Root `Makefile` (validated with GNU make 4.4.1; engine + assets build pass).
- `.gitignore`: `/tools/*` with `!/tools/ay_emul/`; untracked installed tools.
- v6asm `-D` define flag confirmed available.
```
