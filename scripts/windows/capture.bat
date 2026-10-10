@echo off
rem The capture kit's menu (promo/README.md). Double-click it, or run it from a terminal.
setlocal
cd /d "%~dp0..\.."
set PY=python
where python >nul 2>nul || set PY=py
:menu
echo.
echo  GoonCrusher capture kit
echo  -----------------------
echo   1  Check this machine (run this first)
echo   2  Drive by hand and tape it
echo   3  Film a taped drive's bookmarks
echo   4  Film a shot file
echo   5  Build the AI stock library (long: leave it overnight)
echo   6  Open the gallery
echo   7  Quit
echo.
set /p CHOICE= Pick a number: 
if "%CHOICE%"=="1" %PY% promo\tools\capture.py doctor --fix
if "%CHOICE%"=="2" goto hand
if "%CHOICE%"=="3" goto replay
if "%CHOICE%"=="4" goto shot
if "%CHOICE%"=="5" %PY% promo\tools\capture.py stock
if "%CHOICE%"=="6" %PY% promo\tools\capture.py gallery
if "%CHOICE%"=="7" exit /b 0
goto menu
:hand
set /p NAME= A name for the drive (no spaces): 
set /p LEVEL= Level (prairie, city, quarry ...): 
set /p CAR= Car (sedan, taxi, pickup, police, ambulance, van, racer, supercar, semi): 
set /p TOD= Time (day or night): 
%PY% promo\tools\capture.py hand %NAME% --level %LEVEL% --car %CAR% --time %TOD%
goto menu
:replay
set /p NAME= The drive's name: 
set /p SIZE= Size (wide1080, wide4k, vertical, square): 
%PY% promo\tools\capture.py replay %NAME% --profile %SIZE%
goto menu
:shot
dir /b promo\shots\*.json
set /p NAME= Shot file (without .json): 
%PY% promo\tools\capture.py shot %NAME%
goto menu
