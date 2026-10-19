@echo off
cd /d "%~dp0"
start "" ".runtime\godot-4.7.1\Godot_v4.7.1-stable_win64.exe" --path "%~dp0godot" --log-file "%~dp0.runtime\game.log"
