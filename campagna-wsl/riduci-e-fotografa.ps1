# riduci-e-fotografa.ps1 -- Claude 03/11/2026. Riduce a icona le finestre PowerShell delle prove (titolo "Claude: ...")
# perche' non coprano le finestre di WSLg, poi fotografa lo schermo (cattura-schermo.ps1). Va lanciato con schtasks /it.
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class Finestre { [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h, int n); }
"@
Get-Process | Where-Object { $_.MainWindowTitle -like "Claude:*" } | ForEach-Object { [void][Finestre]::ShowWindowAsync($_.MainWindowHandle, 6) }
Start-Sleep 2
& C:\claude\cattura-schermo.ps1
