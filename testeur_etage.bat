@echo off
rem Testeur automatique de l'etage 1 : combien de temps pour vaincre le gardien ? (README, section "Testeur d'etage")
rem Usage : testeur_etage.bat [parties] [graine]   (par defaut : 3 parties, graine 1000)
cd /d "%~dp0"
"C:\jeux\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --fixed-fps 60 --path . -s tests/testeur_etage.gd -- %1 %2 | findstr /C:"==" /C:"TOTAL" /C:"temps" /C:"salles" /C:"combat :" /C:"ABANDON" /C:"abandonn" /C:"non visit" /C:"morts" /C:"BILAN" /C:"Hypoth" /C:"Testeur"
echo.
echo Rapport complet : tests\rapports\testeur_etage.txt
pause
