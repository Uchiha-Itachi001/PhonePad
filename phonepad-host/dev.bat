@echo off
cd /d "%~dp0"
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" 2>nul
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" 2>nul
set "PATH=C:\Program Files\nodejs;%APPDATA%\npm;%USERPROFILE%\.cargo\bin;%PATH%"
npx tauri dev
