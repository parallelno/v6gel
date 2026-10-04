# v6gel — engine/Makefile
#
# It assembles engine/v6.asm (the library entry point that .includes every
# subsystem) into a single relocatable object, build/v6/v6.o, to be linked with
# a game.
#
# Run it from the repository root or from this folder:
#
#   make                 # assemble build/v6/v6.o with default subsystem flags
#   make engine          # same thing
#   make symbols         # also emit build/v6/v6.o.symtab via llvm-readelf
#   make clean           # remove the engine object
#   make V6_CONTROLS=1 V6_MUSIC=1 ...   # override subsystem flags
#
# Requires env vars:
#  V6ASM   — path to the v6asm assembler (default: tools/v6asm/v6asm)
#  READELF — path to llvm-readelf (default: tools/v6llvmc/bin/llvm-readelf)
#  V6C     — path to the v6c compiler (default: tools/v6llvmc/bin/clang)
#
# The root Makefile downloads the tools,  and then
# invokes this one with `make -f engine/Makefile`, so it can
# be run from the repo root or from the engine/ folder. It also sets the default
# subsystem flags for each sample, so the sample Makefiles can just invoke
# `make engine` to build the engine library with the right features.
# ---------------------------------------------------------------------------

.DEFAULT_GOAL := all

.PHONY: all engine symbols clean help

# --- platform detection ----------------------------------------------------
ifeq ($(OS),Windows_NT)
    EXE   := .exe
    mkdir = @if not exist "$(subst /,\\,$1)" mkdir "$(subst /,\\,$1)"
    rmdir = @if exist "$(subst /,\\,$1)" rmdir /s /q "$(subst /,\\,$1)"
	lsplit = "^"
else
    EXE   :=
    mkdir = @mkdir -p $1
    rmdir = @rm -rf $1
endif

# --- locate the repository root from this makefile's own path --------------
# Makes the file work whether invoked from the repo root (-f) or from here.
ENGINE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ROOT_DIR   := $(abspath $(ENGINE_DIR)/..)

# --- tools (overridable) ---------------------------------------------------
V6ASM   ?= $(ROOT_DIR)/tools/v6asm/v6asm$(EXE)
READELF ?= $(ROOT_DIR)/tools/v6llvmc/bin/llvm-readelf$(EXE)

# --- feature flags ---------------------------------------------------------
# It takes these from the caller's environment; the defaults below build
# every optional subsystem out.
V6_CONTROLS             ?= 0
V6_MUSIC                ?= 0
V6_INTERRUPTIONS        ?= 0
STACK_MAIN_PROGRAM_ADDR ?= 0x100

# --- output (mirror engine/build.bat: build/v6/v6.o) -----------------------
V6_OBJ    := $(ROOT_DIR)/build/v6/v6.o
V6_SYMTAB := $(V6_OBJ).symtab

# v6.asm plus every assembler source it can pull in.
ENGINE_SRCS := $(wildcard $(ENGINE_DIR)/*.asm) $(wildcard $(ENGINE_DIR)/*/*.asm)

# ---------------------------------------------------------------------------
all: engine ## Assemble the v6 engine library (default).

## engine: assemble engine/v6.asm into build/v6/v6.o.
engine: $(V6_OBJ)

$(V6_OBJ): $(ENGINE_SRCS)
	$(call mkdir,$(dir $(V6_OBJ)))
	@echo === engine: Build the v6 library ===
	"$(V6ASM)" "$(ENGINE_DIR)/v6.asm" \
	    -D V6_CONTROLS=$(V6_CONTROLS) \
	    -D V6_MUSIC=$(V6_MUSIC) \
	    -D V6_INTERRUPTIONS=$(V6_INTERRUPTIONS) \
	    -D STACK_MAIN_PROGRAM_ADDR=$(STACK_MAIN_PROGRAM_ADDR) \
	    -o "$(V6_OBJ)" -f obj

## symbols: emit a symbol table for the engine object (build.bat --symbols).
symbols: $(V6_SYMTAB)

$(V6_SYMTAB): $(V6_OBJ)
	@echo === engine: Print symbols ===
	"$(READELF)" -s "$(V6_OBJ)" > "$(V6_SYMTAB)"

## clean: remove the engine object and its symbol table.
clean:
	$(call rmdir,$(dir $(V6_OBJ)))

## help: list the available targets.
help:
	@echo engine make targets:
	@echo.
	@echo   all      Assemble the v6 engine library (default)
	@echo   engine   Assemble engine/v6.asm into build/v6/v6.o
	@echo   symbols  Emit build/v6/v6.o.symtab via llvm-readelf
	@echo   clean    Remove the engine object
	@echo   help     Show this message
	@echo.
	@echo Override a tool path or flag, e.g.:
	@echo   make V6ASM=/path/to/v6asm
	@echo   make V6_CONTROLS=1 V6_MUSIC=1
