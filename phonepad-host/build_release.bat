@echo off
echo ===================================================
echo   Building PhonePad Host Production Release (v0.2.0)
echo   Desktop Tauri Engine + React/TypeScript UI
echo ===================================================

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" 2>nul
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" 2>nul
set "RUSTUP_HOME=%USERPROFILE%\.rustup"
set "CARGO_HOME=%USERPROFILE%\.cargo"
set "PATH=%USERPROFILE%\.rustup\toolchains\stable-x86_64-pc-windows-msvc\bin;C:\Program Files\nodejs;%APPDATA%\npm;%PATH%"

echo [1/3] Building frontend distribution...
call npm run build
if %errorlevel% neq 0 (
    echo Error: Frontend build failed.
    exit /b %errorlevel%
)

echo [2/3] Compiling Tauri release binary...
call cargo build --release --manifest-path src-tauri\Cargo.toml
if %errorlevel% neq 0 (
    echo Error: Cargo build failed.
    exit /b %errorlevel%
)

echo [3/3] Copying release executables to root and release\ folder...
if not exist "release" mkdir release

if exist "src-tauri\target\release\phonepad-host.exe" (
    copy /Y "src-tauri\target\release\phonepad-host.exe" "release\phonepad-host.exe"
    copy /Y "src-tauri\target\release\phonepad-host.exe" "..\phonepad-host.exe"
    echo Success: Copied phonepad-host.exe to release\ and root workspace!
)

echo ===================================================
echo   Release build completed successfully!
echo   Executable is updated at: D:\coding\Project\PhonePad\phonepad-host.exe
echo ===================================================
