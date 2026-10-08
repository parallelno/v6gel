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
#  READELF — path to llvm-readelf (default: tools/v6clang/bin/llvm-readelf)
#  V6CLANG     — path to the v6clang compiler (default: tools/v6clang/bin/clang)
#
# The root Makefile downloads the tools and sets the environment variables.
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

# --- tools (overridable) ------------------------------------------------------
V6ASM   ?= $(ROOT_DIR)/tools/v6asm/v6asm$(EXE)
READELF ?= $(ROOT_DIR)/tools/v6clang/bin/llvm-readelf$(EXE)

# --- feature flags ------------------------------------------------------------
# It takes these from the caller's environment; the defaults below build
# every optional subsystem out.
V6_CONTROLS             ?= 0
V6_MUSIC                ?= 0
V6_INTERRUPTIONS        ?= 0
V6_CHARS                ?= 0
STACK_MAIN_PROGRAM_ADDR ?= 0x100

# --- output -------------------------------------------------------------------
V6_OBJ    := $(ROOT_DIR)/build/v6/v6.o
V6_SYMTAB := $(V6_OBJ).symtab

# v6.asm plus every assembler source it can pull in.
ENGINE_SRCS := $(wildcard $(ENGINE_DIR)/*.asm) $(wildcard $(ENGINE_DIR)/*/*.asm)

# ------------------------------------------------------------------------------
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
	    -D V6_CHARS=$(V6_CHARS) \
	    -D STACK_MAIN_PROGRAM_ADDR=$(STACK_MAIN_PROGRAM_ADDR) \
	    -o "$(V6_OBJ)" -f obj

## symbols: emit a symbol table for the engine object.
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
