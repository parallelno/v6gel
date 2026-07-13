@echo off
setlocal
rem Build v6 engine library.

rem === UPDATE TOOLS PATHS =====================================================
set v6asm=C:\Work\Programming\v6asm\target\release\v6asm
set v6llvmc=C:\Work\Programming\v6llvmc\llvm-build\bin

rem === Assemble the v6 library ================================================
set current_dir=%~dp0
%v6asm% %current_dir%v6.asm -o build\v6\v6.o -f obj
if %errorlevel% neq 0 exit /b %errorlevel%

rem === Print symbols if --symbols flag is set =================================
if "%1"=="--symbols" (
    %v6llvmc%\llvm-readelf -s build\v6\v6.o > build\v6\v6.symtab
)