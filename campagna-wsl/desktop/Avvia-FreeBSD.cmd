@echo off
rem Avvia-FreeBSD.cmd -- Claude 04/11/2026. FreeBSD con il desktop XFCE in una finestra di WSLg: arriva alla
rem schermata di login di xdm (utente marietto, password a), poi parte XFCE. FreeBSD fa da kernel di WSL con il
rem .wslconfig in C:\claude\wsl-fbsd\wslconfig-freebsd.ini: se quello attivo e diverso lo sostituisce (il
rem precedente resta in .wslconfig.prima-di-freebsd) e riavvia WSL.
title FreeBSD - XFCE  (non chiudere questa finestra)
set CONF=C:\claude\wsl-fbsd\wslconfig-freebsd.ini
fc /b "%CONF%" "%USERPROFILE%\.wslconfig" >nul 2>&1
if errorlevel 1 (
  echo Metto il .wslconfig di FreeBSD e riavvio WSL con il kernel FreeBSD...
  wsl.exe --shutdown
  if exist "%USERPROFILE%\.wslconfig" copy /y "%USERPROFILE%\.wslconfig" "%USERPROFILE%\.wslconfig.prima-di-freebsd" >nul
  copy /y "%CONF%" "%USERPROFILE%\.wslconfig" >nul
)
echo Avvio FreeBSD: tra poco si apre la finestra "FreeBSD - XFCE" con il login.
wsl.exe -d FreeBSD -u root -e /usr/local/sbin/claude-desktop
echo.
echo Desktop di FreeBSD chiuso.
pause
