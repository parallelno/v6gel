@echo off

echo.
echo === samples/common/paths.bat: Build paths =================================
rem v6asm (https://github.com/parallelno/v6asm)
rem clang (https://github.com/parallelno/v6llvmc)
rem emulator (https://github.com/parallelno/devector)

set V6_ASM=C:/Work/Programming/v6asm/target/release/v6asm
set V6_LLVMC=C:/Work/Programming/v6llvmc/llvm-build/bin/clang
set EMU=C:/Work/Programming/devector/bin/devector

echo V6_ASM=%V6_ASM%
echo V6_LLVMC=%V6_LLVMC%
echo EMU=%EMU%
echo Update the tool paths if needed.