@echo off
rem Un geolier fait sa ronde dans une salle (marche animee).
cd /d "%~dp0"
start "" "C:\jeux\Godot\Godot_v4.7.2-stable_win64.exe" --path . res://tests/voir_geolier.tscn
