# v6gel — root Makefile
#
# A thin, cross-platform task runner. Each target mirrors what the old .bat
# files did, but in one place that works the same on Windows, Linux and macOS.
#
# Quick start:
#   make tools      # download the external tools into tools/
#   make engine     # assemble the v6 engine library
#   make assets     # build every asset into a bootable .fdd
#   make sample     # build sample 01 (engine + song + main.c -> .rom)
#   make help       # list every target
#
# Override any tool path on the command line or via the environment, e.g.
#   make engine V6ASM=/custom/path/v6asm
# ---------------------------------------------------------------------------

# Run the help target when "make" is invoked with no arguments.
.DEFAULT_GOAL := help

# --- platform detection ----------------------------------------------------
# GNU Make sets OS=Windows_NT on Windows; use it to pick the .exe suffix and a
# portable "make a directory" command.
ifeq ($(OS),Windows_NT)
    EXE := .exe
    mkdir = @if not exist "$(subst /,\,$1)" mkdir "$(subst /,\,$1)"
else
    EXE :=
    mkdir = @mkdir -p $1
endif

# --- tools -----------------------------------------------------------------
# Defaults point at tools/<name>/, the layout produced by install_tools.py.
# `?=` means "only set if not already provided", so env vars / CLI args win.
PYTHON ?= python
V6ASM  ?= tools/v6asm/v6asm$(EXE)
V6FDD  ?= tools/v6asm/v6fdd$(EXE)
CLANG  ?= tools/v6llvmc/bin/clang$(EXE)

# --- project paths ---------------------------------------------------------
CONFIG       := assets/config.json
BUILD_DIR    := build/release
FDD_TEMPLATE := assets/basefdd/rds308.fdd

# i8080 / Vector-06c target and stack top (see v6/common/v6_consts.asm).
TARGET    := -target i8080-unknown-v6c
STACK_TOP := 0x7FFE
STACK_DEF := -Wl,--defsym=__stack_top=$(STACK_TOP)

# Build artifacts.
ENGINE_OBJ := v6/out/v6.o
SONG_OBJ   := samples/music/out/song01.o
SONG_DATA  := samples/music/out/song01_data.zx0
SAMPLE_ROM := samples/01/out/main.rom

# ---------------------------------------------------------------------------
.PHONY: all help tools engine song sample assets run clean

all: engine assets sample ## Build the engine, all assets, and sample 01.

## tools: download the external toolchain into tools/ (see tools.lock.json).
tools:
	$(PYTHON) install_tools.py

## engine: assemble the v6 engine library to v6/out/v6.o.
engine: $(ENGINE_OBJ)

$(ENGINE_OBJ): $(wildcard v6/**/*.asm) v6/v6.asm
	$(call mkdir,v6/out)
	cd v6 && "$(abspath $(V6ASM))" v6.asm -o out/v6.o -f obj

## song: assemble + compress the sample song (samples/music).
song: $(SONG_OBJ)

$(SONG_OBJ): samples/music/song01.asm samples/music/song01_data.asm
	$(call mkdir,samples/music/out)
	cd samples/music && "$(abspath $(V6ASM))" song01_data.asm -o out/song01_data.bin
	cd samples/music && "$(abspath $(V6ASM))" song01.asm -o out/song01.o -f obj

## assets: export every asset of the config and pack a bootable .fdd.
assets:
	$(PYTHON) scripts/build_assets.py $(CONFIG) -o $(BUILD_DIR) --fdd-template $(FDD_TEMPLATE)

## sample: build sample 01 (needs the engine and the song).
sample: $(SAMPLE_ROM)

$(SAMPLE_ROM): samples/01/main.c $(ENGINE_OBJ) $(SONG_OBJ)
	$(call mkdir,samples/01/out)
	"$(CLANG)" $(TARGET) -nostdlib -O2 $(STACK_DEF) \
		samples/01/main.c $(ENGINE_OBJ) $(SONG_OBJ) -o $(SAMPLE_ROM)

## run: build sample 01 and launch it in the v6emul emulator.
run: $(SAMPLE_ROM)
	tools/v6emul/v6emul$(EXE) $(SAMPLE_ROM)

## clean: remove build outputs.
clean:
	$(PYTHON) scripts/clear.py

## help: list the available targets.
help:
	@echo v6gel make targets:
	@echo.
	@echo   tools    Download the external toolchain into tools/
	@echo   engine   Assemble the v6 engine library
	@echo   song     Assemble + compress the sample song
	@echo   assets   Build all assets into a bootable .fdd
	@echo   sample   Build sample 01 (engine + song + main.c)
	@echo   run      Build and run sample 01 in v6emul
	@echo   all      engine + assets + sample
	@echo   clean    Remove build outputs
	@echo.
	@echo Override a tool path, e.g.:  make engine V6ASM=/path/to/v6asm
