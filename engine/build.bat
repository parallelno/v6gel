@echo off
setlocal
rem Build v6 engine library.

rem === UPDATE TOOLS PATHS =====================================================
set v6asm=C:\Work\Programming\v6asm\target\release\v6asm


rem === Assemble the v6 library ================================================
set current_dir=%~dp0
%v6asm% %current_dir%v6.asm -o build\v6\v6.o -f obj