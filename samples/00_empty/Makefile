# v6gel — samples/00_empty Makefile
#
#   Demonstrates an empty sample project and debug output.
#
# It assembles the v6 engine library (with this sample's subsystem flags),
# assembles main.asm, links the two into a .rom with clang, and can launch it in
# an emulator.

# Run it from the repository root or from this folder:
#
#   make                 # assemble + link -> build/00_empty/00_empty.rom
#   make run             # build and launch the ROM in the emulator
#   make engine          # only rebuild the engine library
#   make clean           # remove this sample's build output
#
# Override any tool path or define on the command line or via the environment:
#
# Requires env vars:
#  V6ASM   — path to the v6asm assembler (default: tools/v6asm/v6asm)
#  READELF — path to llvm-readelf (default: tools/v6llvmc/bin/llvm-readelf)
#  V6C     — path to the v6c compiler (default: tools/v6llvmc/bin/clang)
#  EMU     — path to the emulator (default: tools/devector/devector)
#
# The .bat version read tool paths from ./samples/common/paths.bat; here they
# default to the tools/ layout produced by `python install_tools.py`, matching
# the repository root Makefile.
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

# --- locate the repository root from this makefile's own path --------------
# Makes the file work whether invoked from the repo root (-f) or from here.
SAMPLE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ROOT_DIR   := $(abspath $(SAMPLE_DIR)/../..)

# --- tools (overridable) ---------------------------------------------------
V6ASM   ?= $(ROOT_DIR)/tools/v6asm/v6asm$(EXE)
V6C   ?= $(ROOT_DIR)/tools/v6llvmc/bin/clang$(EXE)
READELF ?= $(ROOT_DIR)/tools/v6llvmc/bin/llvm-readelf$(EXE)
EMU     ?= $(ROOT_DIR)/tools/devector/devector$(EXE)

# --- sample settings (from build.bat, overridable) -------------------------
STACK_MAIN_PROGRAM_ADDR ?= 0x100
V6_INTERRUPTIONS        ?= 0
V6_CONTROLS             ?= 0
V6_MUSIC                ?= 0

TARGET := -target i8080-unknown-v6c

# --- project paths (mirror samples/common/build_setup.bat) ------------------
PROJECT_NAME := $(notdir $(SAMPLE_DIR))
OUT_DIR      := $(ROOT_DIR)/build/$(PROJECT_NAME)
OUT_ROM      := $(OUT_DIR)/$(PROJECT_NAME).rom
MAIN_OBJ     := $(OUT_DIR)/main/main.o

# The engine object lives under build/v6/ (mirror engine/build.bat).
V6_OBJ       := $(ROOT_DIR)/build/v6/v6.o
V6_SYMTAB    := $(V6_OBJ).symtab
ENGINE_DIR   := $(ROOT_DIR)/engine
ENGINE_SRCS  := $(wildcard $(ENGINE_DIR)/*.asm) $(wildcard $(ENGINE_DIR)/*/*.asm)

# ---------------------------------------------------------------------------
all: $(OUT_ROM) ## Assemble + link the sample ROM.

## engine: assemble the v6 engine library with this sample's feature flags.
engine: $(V6_OBJ)

$(V6_OBJ): $(ENGINE_SRCS)
	$(call mkdir,$(dir $(V6_OBJ)))
	@echo === samples/00_empty: Build the v6 library ===
	"$(V6ASM)" "$(ENGINE_DIR)/v6.asm" \
	    -D V6_CONTROLS=$(V6_CONTROLS) \
	    -D V6_MUSIC=$(V6_MUSIC) \
	    -D V6_INTERRUPTIONS=$(V6_INTERRUPTIONS) \
	    -D STACK_MAIN_PROGRAM_ADDR=$(STACK_MAIN_PROGRAM_ADDR) \
	    -o "$(V6_OBJ)" -f obj
	@echo === samples/00_empty: Emit engine symbol table ===
	"$(READELF)" -s "$(V6_OBJ)" > "$(V6_SYMTAB)"

## rom: assemble main.asm and link it with the engine into the ROM.
rom: $(OUT_ROM)

$(MAIN_OBJ): $(SAMPLE_DIR)/main.asm
	$(call mkdir,$(dir $(MAIN_OBJ)))
	@echo === samples/00_empty: Assemble the main file ===
	"$(V6ASM)" "$(SAMPLE_DIR)/main.asm" \
	    -D STACK_MAIN_PROGRAM_ADDR=$(STACK_MAIN_PROGRAM_ADDR) \
	    -o "$(MAIN_OBJ)" -f obj

$(OUT_ROM): $(MAIN_OBJ) $(V6_OBJ)
	$(call mkdir,$(OUT_DIR))
	@echo === samples/00_empty: Linking ===
	"$(V6C)" $(TARGET) -nostdlib -O2 \
	    "$(MAIN_OBJ)" \
	    "$(V6_OBJ)" \
	    -Wl,-Map,"$(OUT_DIR)/$(PROJECT_NAME).map" \
	    -Wl,--v6c-constants-map,"$(OUT_DIR)/$(PROJECT_NAME).constants.map" \
	    -o "$(OUT_ROM)"
	@echo Linking output to: $(OUT_ROM)

## run: build the ROM and launch it in the emulator.
run: $(OUT_ROM)
	@echo === samples/00_empty: Run the ROM in the emulator ===
	@echo Running: $(EMU) $(OUT_ROM)
	"$(EMU)" "$(OUT_ROM)"

## clean: remove this sample's build output (ROM and engine object).
clean:
	$(call rmdir,$(OUT_DIR))
	$(call rmdir,$(dir $(V6_OBJ)))

## help: list the available targets.
help:
	@echo samples/00_empty make targets:
	@echo.
	@echo   all      Assemble + link the sample ROM (default)
	@echo   engine   Assemble the v6 engine library only
	@echo   rom      Assemble main.asm and link the ROM
	@echo   run      Build the ROM and launch it in the emulator
	@echo   clean    Remove this sample's build output
	@echo   help     Show this message
	@echo.
	@echo Override a tool path, e.g.:  make run V6ASM=/path/to/v6asm
