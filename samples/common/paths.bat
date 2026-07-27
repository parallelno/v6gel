@echo off

echo.
echo === samples/common/paths.bat: Build paths =================================
rem v6asm (https://github.com/parallelno/v6asm)
rem clang (https://github.com/parallelno/v6llvmc)
rem emulator (https://github.com/parallelno/devector)

set V6ASM=C:/Work/Programming/v6asm/target/release/v6asm
set V6LLVMC=C:/Work/Programming/v6llvmc/llvm-build/bin
set EMU=C:/Work/Programming/devector/bin/devector

echo V6ASM=%V6ASM%
echo V6LLVMC=%V6LLVMC%
echo EMU=%EMU%
echo Update the tool paths if needed.