@echo off
rem Editeur des zones des salles peintes (voir README, section Lancer le jeu).
rem Pour ouvrir une salle precise : editeur_zones.bat grande5
cd /d "%~dp0"
start "" "C:\jeux\Godot\Godot_v4.7.2-stable_win64.exe" --path . res://scenes/outils/editeur_zones.tscn -- %1
