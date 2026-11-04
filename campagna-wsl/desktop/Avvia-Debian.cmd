@echo off
rem Avvia-Debian.cmd -- Claude 04/11/2026. Debian con il desktop XFCE in una finestra di WSLg: arriva alla
rem schermata di login di xdm (utente marietto, password a), poi parte XFCE. Debian vuole il kernel Linux di WSL:
rem se c e il .wslconfig di FreeBSD lo mette da parte (.wslconfig.freebsd) e riavvia WSL.
title Debian - XFCE  (non chiudere questa finestra)
if exist "%USERPROFILE%\.wslconfig" (
  echo Tolgo il .wslconfig di FreeBSD e riavvio WSL con il kernel Linux...
  wsl.exe --shutdown
  move /y "%USERPROFILE%\.wslconfig" "%USERPROFILE%\.wslconfig.freebsd" >nul
)
echo Avvio Debian: tra poco si apre la finestra "Debian - XFCE" con il login.
wsl.exe -d Debian -u root -e /usr/local/sbin/claude-desktop
echo.
echo Desktop di Debian chiuso.
pause
