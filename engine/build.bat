@echo off
setlocal
rem Build v6 engine library.

rem === TOOLS PATHS =====================================================
rem required: set V6_ASM to the path of the v6 assembler
rem required: set V6_LLVMC to the path of the v6 llvm C compiler and tools

rem === Assemble the v6 library ================================================
set CURRENT_DIR=%~dp0
%V6_ASM% %CURRENT_DIR%v6.asm -o build\v6\v6.o -f obj
if %errorlevel% neq 0 exit /b %errorlevel%

rem === Print symbols if --symbols flag is set =================================
if "%1"=="--symbols" (
    %V6_LLVMC%\llvm-readelf -s build\v6\v6.o > build\v6\v6.symtab
)
endlocal