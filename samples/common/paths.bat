@echo off

echo.
echo === samples/common/paths.bat: Build paths =================================
echo Purpose: Add `v6asm`, `clang`, and emulator to PATH, build main and v6
echo library.

rem requires: update the TOOLS PATHS below if your tools are installed elsewhere.
rem v6asm (https://github.com/parallelno/v6asm)
rem clang (https://github.com/parallelno/v6llvmc)
rem devector emulator (https://github.com/parallelno/devector)

set V6_ASM=C:/Work/Programming/v6asm/target/release/v6asm
set V6_LLVMC=C:/Work/Programming/v6llvmc/llvm-build/bin/clang
set EMU=C:/Work/Programming/devector/bin/devector