# v6gel — samples/01_controls Makefile
#
#   Demonstrates reading input and sending debug output. Use arrow keys and
#   check the keycode response in stdout output.
#
# It assembles the v6 engine library (with this sample's subsystem flags),
# assembles main.asm, links the two into a .rom with clang, and can launch it in
# an emulator.

# Run it from the repository root or from this folder:
#
#   make                 # assemble + link -> build/01_controls/01_controls.rom
#   make run             # build and launch the ROM in the emulator
#   make engine          # only rebuild the engine library
#   make clean           # remove this sample's build output
#
# Requires env vars:
#  V6ASM   — path to the v6asm assembler (default: tools/v6asm/v6asm)
#  READELF — path to llvm-readelf (default: tools/v6clang/bin/llvm-readelf)
#  V6CLANG     — path to the v6clang compiler (default: tools/v6clang/bin/clang)
#  DEVECTOR     — path to the emulator (default: tools/devector/devector)
#
# The root Makefile downloads the tools and sets the environment variables.
# ---------------------------------------------------------------------------

.PHONY: all engine run rom clean help

# --- platform detection ----------------------------------------------------
ifeq ($(OS),Windows_NT)
    EXE   := .exe
    mkdir = @if not exist "$(subst /,\\,$1)" mkdir "$(subst /,\\,$1)"
    rmdir = @if exist "$(subst /,\\,$1)" rmdir /s /q "$(subst /,\\,$1)"
else
    EXE   :=
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

# --- sample settings (overridable) --------------------------------------------
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

# ------------------------------------------------------------------------------
all: $(OUT_ROM) ## Assemble + link the sample ROM.

## engine: assemble the v6 engine library via engine/Makefile (isolated output).
engine: $(V6_OBJ)

$(V6_OBJ): $(ENGINE_SRCS)
	@echo === samples/01_controls: Build the v6 library ===
	cd "$(ENGINE_DIR)" && $(MAKE) engine symbols \
	    V6ASM=$(V6ASM) READELF=$(READELF) \
	    V6_OBJ=$(V6_OBJ) \
	    $(V6_DEFS)

## rom: assemble main.asm and link it with the engine into the ROM.
rom: $(OUT_ROM)

$(MAIN_OBJ): $(SAMPLE_DIR)/main.asm
	$(call mkdir,$(dir $(MAIN_OBJ)))
	@echo === samples/01_controls: Assemble the main file ===
	"$(V6ASM)" "$(SAMPLE_DIR)/main.asm" \
	    -D STACK_MAIN_PROGRAM_ADDR=$(STACK_MAIN_PROGRAM_ADDR) \
	    -o "$(MAIN_OBJ)" -f obj

$(OUT_ROM): $(MAIN_OBJ) $(V6_OBJ)
	$(call mkdir,$(OUT_DIR))
	@echo === samples/01_controls: Linking ===
	"$(V6CLANG)" $(TARGET) -nostdlib -O2 \
	    "$(MAIN_OBJ)" \
	    "$(V6_OBJ)" \
	    -Wl,-Map,"$(OUT_DIR)/$(PROJECT_NAME).map" \
	    -Wl,--v6clang-constants-map,"$(OUT_DIR)/$(PROJECT_NAME).constants.map" \
	    -o "$(OUT_ROM)"
	@echo Linking output to: $(OUT_ROM)

## run: build the ROM and launch it in the emulator.
run: $(OUT_ROM)
	@echo === samples/01_controls: Run the ROM in the emulator ===
	@echo Running: $(DEVECTOR) $(OUT_ROM)
	"$(DEVECTOR)" "$(OUT_ROM)"

## clean: remove this sample's build output (ROM and engine object).
clean:
	$(call rmdir,$(OUT_DIR))

## help: list the available targets.
help:
	@echo samples/01_controls make targets:
	@echo.
	@echo   all      Assemble + link the sample ROM (default)
	@echo   engine   Assemble the v6 engine library only
	@echo   rom      Assemble main.asm and link the ROM
	@echo   run      Build the ROM and launch it in the emulator
	@echo   clean    Remove this sample's build output
	@echo   help     Show this message
	@echo.
	@echo Override a tool path, e.g.:  make run V6ASM=/path/to/v6asm