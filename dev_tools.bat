@echo off
title AutAnalysis Dev Tools
color 0B

:menu
cls
echo ========================================================
echo               AutAnalysis Dev Tools Menu
echo ========================================================
echo.
echo  [1] Avvia Backend (Docker Compose Up)
echo  [2] Ferma Backend (Docker Compose Down)
echo  [3] Ricostruisci Backend (Docker Compose Build)
echo.
echo  [4] Avvia Frontend (Flutter su Chrome)
echo  [5] Genera Frontend (Flutter APK)
echo.
echo  [6] Push modifiche su GitHub (Git Add, Commit, Push)
echo.
echo  [0] Esci
echo.
echo ========================================================
set /p choice="Scegli un'opzione [0-6]: "

if "%choice%"=="1" goto start_backend
if "%choice%"=="2" goto stop_backend
if "%choice%"=="3" goto build_backend
if "%choice%"=="4" goto start_flutter
if "%choice%"=="5" goto build_apk
if "%choice%"=="6" goto git_push
if "%choice%"=="0" goto exit

echo Scelta non valida, riprova.
pause
goto menu

:start_backend
echo Avvio dei container Docker...
docker-compose up -d
pause
goto menu

:stop_backend
echo Chiusura dei container Docker...
docker-compose down
pause
goto menu

:build_backend
echo Ricostruzione dell'immagine Docker backend...
docker-compose up -d --build
pause
goto menu

:start_flutter
echo Avvio del frontend su Chrome...
cd frontend
flutter run -d chrome
cd ..
pause
goto menu

:build_apk
echo Generazione dell'APK Flutter...
cd frontend
flutter build apk
explorer "build\app\outputs\flutter-apk\"
cd ..
pause
goto menu

:git_push
echo.
set /p commit_msg="Inserisci il messaggio di commit: "
if "%commit_msg%"=="" set commit_msg="Update"
git add .
git commit -m "%commit_msg%"
git push
echo Push completato.
pause
goto menu

:exit
exit
