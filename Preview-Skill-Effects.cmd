@echo off
setlocal
set "VFX_ENGINE="
if defined GODOT_EXE if exist "%GODOT_EXE%" set "VFX_ENGINE=%GODOT_EXE%"
if not defined VFX_ENGINE if exist "%~dp0tools\godot\Godot_v4.6-stable_win64.exe" set "VFX_ENGINE=%~dp0tools\godot\Godot_v4.6-stable_win64.exe"
if not defined VFX_ENGINE if exist "%~dp0..\..\RPG2\tools\godot\Godot_v4.6-stable_win64_console.exe" set "VFX_ENGINE=%~dp0..\..\RPG2\tools\godot\Godot_v4.6-stable_win64_console.exe"
if not defined VFX_ENGINE for %%G in (godot.exe godot4.exe) do for %%P in (%%~$PATH:G) do if exist "%%P" set "VFX_ENGINE=%%P"
if not defined VFX_ENGINE (
    echo Godot 4.6 was not found. Set GODOT_EXE to your Godot executable.
    pause
    exit /b 1
)
if not exist "%~dp0runtime\logs" mkdir "%~dp0runtime\logs"
"%VFX_ENGINE%" --path "%~dp0game" --log-file "%~dp0runtime\logs\skill-effects-gallery.log" res://vfx_gallery.tscn -- %*
if errorlevel 1 pause
endlocal
