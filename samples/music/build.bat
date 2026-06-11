@echo off

@echo off
REM Build v6 library.

REM Tools paths.
set v6asm=C:\Work\Programming\v6asm\target\release\v6asm

REM Set the current directory to the location of this script.
cd /d "%~dp0"


echo Assemble the v6 library.
%v6asm% song01.asm -o out\song01.o -f obj
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo Done.