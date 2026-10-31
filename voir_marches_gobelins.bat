@echo off
rem Apercu des marches des gobelins (Grok) avant de les brancher dans le jeu.
cd /d "%~dp0"
python outils\apercu_marches_gobelins.py
start "" "C:\jeux\Godot\Godot_v4.7.2-stable_win64.exe" --path . res://tests/voir_marches_gobelins.tscn
