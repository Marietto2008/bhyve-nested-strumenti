# digita-login.ps1 -- Claude 04/11/2026. Clicca nel punto X,Y (campo Login della finestra di xdm) per dargli il fuoco,
# poi scrive utente e password.
param([int]$X = 726, [int]$Y = 318)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class ClaudeMouse {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
}
"@
[ClaudeMouse]::SetCursorPos($X, $Y) | Out-Null
[ClaudeMouse]::mouse_event(0x2, 0, 0, 0, [IntPtr]::Zero); [ClaudeMouse]::mouse_event(0x4, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 800
$w = New-Object -ComObject WScript.Shell
$w.SendKeys("marietto{ENTER}"); Start-Sleep -Seconds 2
$w.SendKeys("a{ENTER}")
"cliccato in $X,$Y e digitato" | Out-File C:\claude\digita-login.txt
