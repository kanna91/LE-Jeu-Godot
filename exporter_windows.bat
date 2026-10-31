@echo off
rem Fabrique la version jouable Windows du jeu :
rem   ..\export\windows\LE_Jeu_Ultime.exe + images des salles, puis ..\export\LE_Jeu_Ultime_Windows.zip
rem Il faut les modeles d'export Godot 4.7.2 (Editeur > Gerer les modeles d'export).
cd /d "%~dp0"
set GODOT=C:\jeux\Godot\Godot_v4.7.2-stable_win64_console.exe
set SORTIE=..\export\windows

if exist "%SORTIE%" rmdir /s /q "%SORTIE%"
mkdir "%SORTIE%"

echo Import des ressources...
"%GODOT%" --headless --path . --import
echo Export du jeu...
"%GODOT%" --headless --path . --export-release "Windows" "%SORTIE%\LE_Jeu_Ultime.exe"
if not exist "%SORTIE%\LE_Jeu_Ultime.exe" (
  echo ECHEC : l'export n'a pas produit le .exe.
  pause
  exit /b 1
)

rem Ces dossiers ont un .gdignore : Godot ne les met pas dans le .exe, le jeu les lit a cote.
robocopy "images\salles_peintes" "%SORTIE%\images\salles_peintes" /E /XF .gdignore /NFL /NDL /NJH /NJS >nul
robocopy "images\objets_salles" "%SORTIE%\images\objets_salles" /E /XF .gdignore /NFL /NDL /NJH /NJS >nul

echo Creation du zip...
if exist "..\export\LE_Jeu_Ultime_Windows.zip" del "..\export\LE_Jeu_Ultime_Windows.zip"
powershell -NoProfile -Command "Compress-Archive -Path '%SORTIE%\*' -DestinationPath '..\export\LE_Jeu_Ultime_Windows.zip'"

echo Termine : ..\export\LE_Jeu_Ultime_Windows.zip
pause
