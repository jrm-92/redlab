@echo off
chcp 65001 >nul
title RedLab - Deploiement Nolio

REM Se placer dans le dossier de CE fichier, d'ou qu'on le lance :
REM un double-clic depuis un raccourci du Bureau demarre ailleurs.
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo.
  echo   Node.js est introuvable.
  echo   Installe-le depuis https://nodejs.org puis relance ce fichier.
  echo.
  pause
  exit /b 1
)

if not exist "config.json" (
  echo.
  echo   config.json est absent : la configuration Nolio n'a jamais ete faite.
  echo   Copie config.example.json en config.json et remplis-le.
  echo   Voir README.md, section 3.
  echo.
  pause
  exit /b 1
)

echo.
echo   RedLab - Deploiement Nolio
echo   ==========================
echo.
echo     1  Lancer l'interface      (le cas normal)
echo     2  Reautoriser Nolio       (si "autorisation" ou "token" apparait en erreur)
echo     3  Essai a blanc           (traduit les seances, n'envoie RIEN)
echo.
set "choix="
set /p "choix=  Ton choix [1] : "
if not defined choix set "choix=1"

if "%choix%"=="2" goto auth
if "%choix%"=="3" goto dry

:ui
echo.
echo   Interface sur http://localhost:8730 - le navigateur s'ouvre tout seul.
echo   Laisse cette fenetre OUVERTE tant que tu deploies.
echo   Ctrl+C pour arreter.
echo.
node server.js
goto fin

:auth
echo.
echo   Une page va s'ouvrir : connecte-toi a Nolio et accepte.
echo.
node index.js --auth
goto fin

:dry
echo.
echo   Rien ne sera envoye. Le resultat s'ecrit dans out\payloads.json
echo.
node index.js --dry-run
goto fin

:fin
echo.
if errorlevel 1 (
  echo   L'outil s'est arrete sur une erreur - le message est au-dessus.
  echo   Si elle parle d'autorisation ou de token, relance ce fichier et choisis 2.
) else (
  echo   Termine.
)
echo.
pause
