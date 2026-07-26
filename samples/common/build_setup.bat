
echo.
echo === samples/common/build_setup.bat ========================================
rem requires: set CURRENT_DIR to the location of the calling script, V6_ASM,
rem V6_LLVMC, EMU build paths

rem === Set the project name to the name of the current directory ==============
for %%I in ("%CURRENT_DIR:~0,-1%") do set "PROJECT_NAME=%%~nxI"
set OUT_DIR=build/%PROJECT_NAME%
set OUT_ROM=%OUT_DIR%/%PROJECT_NAME%.rom

set main_o=%OUT_DIR%/main/main.o

echo main_o=%main_o%
echo OUT_DIR=%OUT_DIR%
echo OUT_ROM=%OUT_ROM%


rem === samples/common/build_setup.bat: Build the v6 library ===================
rem Build engine library (use --symbols to emit symbol table useful for debugging)
pushd .
call engine/build.bat %1
if %errorlevel% neq 0 exit /b %errorlevel%
popd


echo.
echo === samples/common/build_setup.bat: Assemble the main file ================
%V6_ASM% "%CURRENT_DIR%main.asm" -o "%main_o%" -f obj
if %errorlevel% neq 0 exit /b %errorlevel%
