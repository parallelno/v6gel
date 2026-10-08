# v6gel — samples/02_palette Makefile
#
#   Demonstrates palette usage and fade effects.
#
# It exports this sample's assets (via v6export), assembles the v6 engine
# library (with this sample's subsystem flags) and main.asm, links everything
# into a .rom with clang, and can launch it in an emulator.

# Run it from the repository root or from this folder:
#
#   make                 # export assets + assemble + link -> build/02_palette/02_palette.rom
#   make assets          # only (re)export this sample's assets
#   make run             # build and launch the ROM in the emulator
#   make engine          # only rebuild the engine library
#   make clean           # remove this sample's build output
#
# Override any tool path or define on the command line or via the environment:
#
#   make V6ASM=/custom/v6asm DEVECTOR=/custom/emulator
#   make V6_CONTROLS=0
#
# ------------------------------------------------------------------------------

.PHONY: all assets engine run rom clean help

# --- platform detection -------------------------------------------------------
ifeq ($(OS),Windows_NT)
    EXE      := .exe
    VENV_BIN := .venv/Scripts
    mkdir = @if not exist "$(subst /,\\,$1)" mkdir "$(subst /,\\,$1)"
    rmdir = @if exist "$(subst /,\\,$1)" rmdir /s /q "$(subst /,\\,$1)"
else
    EXE      :=
    VENV_BIN := .venv/bin
    mkdir = @mkdir -p $1
    rmdir = @rm -rf $1
endif

# --- locate the repository root from this makefile's own path -----------------
# Makes the file work whether invoked from the repo root (-f) or from here.
SAMPLE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ROOT_DIR   := $(abspath $(SAMPLE_DIR)/../..)

# --- tools (overridable) ------------------------------------------------------
V6ASM   ?= $(ROOT_DIR)/tools/v6asm/v6asm$(EXE)
V6CLANG     ?= $(ROOT_DIR)/tools/v6clang/bin/clang$(EXE)
READELF ?= $(ROOT_DIR)/tools/v6clang/bin/llvm-readelf$(EXE)
DEVECTOR     ?= $(ROOT_DIR)/tools/devector/devector$(EXE)
# Prefer the project-local .venv interpreter (created by `make venv` in the repo
# root) when it exists, otherwise fall back to whatever `python` is on PATH.
PYTHON  ?= $(if $(wildcard $(ROOT_DIR)/$(VENV_BIN)/python$(EXE)),$(ROOT_DIR)/$(VENV_BIN)/python$(EXE),python)

# Make the v6gel pipeline package importable for the asset exports (mirrors the
# root Makefile's `export PYTHONPATH := scripts`).
export PYTHONPATH := $(ROOT_DIR)/scripts

# --- sample settings ----------------------------------------------------------
STACK_MAIN_PROGRAM_ADDR ?= 0x100
V6_INTERRUPTIONS        ?= 1
V6_CONTROLS             ?= 1
V6_MUSIC                ?= 0

TARGET := -target i8080-unknown-v6clang

# --- project paths ------------------------------------------------------------
PROJECT_NAME := $(notdir $(SAMPLE_DIR))
OUT_DIR      := $(ROOT_DIR)/build/$(PROJECT_NAME)
OUT_ROM      := $(OUT_DIR)/$(PROJECT_NAME).rom
MAIN_OBJ     := $(OUT_DIR)/main/main.o

# main.asm includes its generated assets and the engine via paths relative to
# the repository root (e.g. "build/02_palette/palettes/asm/pal_lv0_meta.asm"),
# so the asset export and the main assembly both run from ROOT_DIR. OUT_REL is
# OUT_DIR expressed relative to ROOT_DIR for those recipes.
OUT_REL      := build/$(PROJECT_NAME)

# The v6 engine object and its debug files are isolated per sample under this
# sample's build dir, so building every sample at once never clobbers a shared
# build/v6/v6.o. engine/Makefile is the single source of truth and produces it
# via the recursive `engine` rule below.
V6_DIR       := $(OUT_DIR)/v6
V6_OBJ       := $(V6_DIR)/v6.o
V6_SYMTAB    := $(V6_OBJ).symtab
ENGINE_DIR   := $(ROOT_DIR)/engine
ENGINE_SRCS  := $(wildcard $(ENGINE_DIR)/*.asm) $(wildcard $(ENGINE_DIR)/*/*.asm)

# Feature flags forwarded to engine/Makefile. V6_CHARS is forwarded only when a
# sample defines it (only 08_sprite_anim needs the character subsystem).
V6_DEFS := \
    V6_CONTROLS=$(V6_CONTROLS) \
    V6_MUSIC=$(V6_MUSIC) \
    V6_INTERRUPTIONS=$(V6_INTERRUPTIONS) \
    STACK_MAIN_PROGRAM_ADDR=$(STACK_MAIN_PROGRAM_ADDR) \
    $(if $(V6_CHARS),V6_CHARS=$(V6_CHARS))

# --- assets -------------------------------------------------------------------
# export_asset <meta.json> <asset-out-dir-relative-to-root> [extra flags]
# Runs from ROOT_DIR (so generated ASM uses root-relative paths) and emits
# <dir>/asm, <dir>/manifests and <dir>/bin, assembling <name>.o into bin.
define export_asset
	@echo === samples/02_palette: Export $(notdir $(1)) ===
	cd "$(ROOT_DIR)" && $(PYTHON) -m v6gel.cli.v6export "$(1)" \
	    -o "$(2)/asm" \
	    --manifest-dir "$(2)/manifests" \
	    --bin-dir "$(2)/bin" \
	    --asm "$(V6ASM)" \
	    --temp "build/temp/" \
	    --emit-asm \
	    --emit-obj \
	    $(3)
endef

pal_lv0_JSON := $(SAMPLE_DIR)/assets/palettes/pal_lv0.json
pal_lv0_REL  := $(OUT_REL)/palettes
pal_lv0_DIR  := $(ROOT_DIR)/$(pal_lv0_REL)
pal_lv0_OBJ  := $(pal_lv0_DIR)/bin/pal_lv0.o

ASSET_OBJS := $(pal_lv0_OBJ)

# ------------------------------------------------------------------------------
all: $(OUT_ROM) ## Export assets, assemble + link the sample ROM.

## assets: (re)export this sample's assets via v6export.
assets: $(ASSET_OBJS)

$(pal_lv0_OBJ): $(pal_lv0_JSON)
	$(call export_asset,$(pal_lv0_JSON),$(pal_lv0_REL))

## engine: assemble the v6 engine library via engine/Makefile (isolated output).
engine: $(V6_OBJ)

$(V6_OBJ): $(ENGINE_SRCS)
	@echo === samples/02_palette: Build the v6 library ===
	cd "$(ENGINE_DIR)" && $(MAKE) engine symbols \
	    V6ASM=$(V6ASM) READELF=$(READELF) \
	    V6_OBJ=$(V6_OBJ) \
	    $(V6_DEFS)

## rom: assemble main.asm and link it with the engine and assets into the ROM.
rom: $(OUT_ROM)

# main.asm .includes the generated *_meta.asm files, so export the assets first.
$(MAIN_OBJ): $(SAMPLE_DIR)/main.asm $(ASSET_OBJS)
	$(call mkdir,$(dir $(MAIN_OBJ)))
	@echo === samples/02_palette: Assemble the main file ===
	cd "$(ROOT_DIR)" && "$(V6ASM)" "$(SAMPLE_DIR)/main.asm" \
	    -D STACK_MAIN_PROGRAM_ADDR=$(STACK_MAIN_PROGRAM_ADDR) \
	    -o "$(MAIN_OBJ)" -f obj

$(OUT_ROM): $(MAIN_OBJ) $(V6_OBJ) $(ASSET_OBJS)
	$(call mkdir,$(OUT_DIR))
	@echo === samples/02_palette: Linking ===
	"$(V6CLANG)" $(TARGET) -nostdlib -O2 \
	    "$(MAIN_OBJ)" \
	    "$(V6_OBJ)" \
	    $(foreach o,$(ASSET_OBJS),"$(o)") \
	    -Wl,-Map,"$(OUT_DIR)/$(PROJECT_NAME).map" \
	    -Wl,--v6clang-constants-map,"$(OUT_DIR)/$(PROJECT_NAME).constants.map" \
	    -o "$(OUT_ROM)"
	@echo Linking output to: $(OUT_ROM)

## run: build the ROM and launch it in the emulator.
run: $(OUT_ROM)
	@echo === samples/02_palette: Run the ROM in the emulator ===
	@echo Running: $(DEVECTOR) $(OUT_ROM)
	"$(DEVECTOR)" "$(OUT_ROM)"

## clean: remove this sample's build output (ROM, assets and engine object).
clean:
	$(call rmdir,$(OUT_DIR))

## help: list the available targets.
help:
	@echo samples/02_palette make targets:
	@echo.
	@echo   all      Export assets, assemble + link the sample ROM (default)
	@echo   assets   (Re)export this sample's assets via v6export
	@echo   engine   Assemble the v6 engine library only
	@echo   rom      Assemble main.asm and link the ROM
	@echo   run      Build the ROM and launch it in the emulator
	@echo   clean    Remove this sample's build output
	@echo   help     Show this message
	@echo.
	@echo Override a tool path, e.g.:  make run V6ASM=/path/to/v6asm