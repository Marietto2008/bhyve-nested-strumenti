' Claude 24/10/2026: avvia wsl-guardia.ps1 SENZA finestra (-WindowStyle Hidden non basta da un'attivita' /it)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\claude\wsl-guardia.ps1", 0, False
