
echo.

echo === samples/common/build_v6_main.bat =====================================
rem requires: V6ASM, V6LLVMC, EMU build paths defined

rem === samples/common/build_v6_main.bat: Build the v6 library ===================
rem Build engine library (use --symbols to emit symbol table useful for debugging)
pushd .
call engine/build.bat %1
if %errorlevel% neq 0 exit /b %errorlevel%
popd


echo.
echo === samples/common/build_v6_main.bat: Assemble the main file ================
%V6ASM% "%CURRENT_DIR%main.asm" ^
    -D STACK_MAIN_PROGRAM_ADDR=%STACK_MAIN_PROGRAM_ADDR% ^
    -o "%main_o%" ^
    -f obj
if %errorlevel% neq 0 exit /b %errorlevel%
