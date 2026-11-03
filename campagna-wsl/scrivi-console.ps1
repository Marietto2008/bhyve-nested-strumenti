# scrivi-console.ps1 -- Claude 03/11/2026. Digita delle righe nella console di un processo PowerShell trovato per riga
# di comando (stessa tecnica di spegni-fbsd-console.ps1: AttachConsole + WriteConsoleInput, senza prendere il focus).
# Uso: scrivi-console.ps1 -Cerca "*prova-wsl-vhd.ps1*" -Righe "uname -a|tty|exit" [-Pausa 2]
# Le righe si separano con '|'; senza -Righe si leggono da C:\claude\righe-console.txt. Esito in C:\claude\scrivi-console.txt.
param([string]$Cerca = "*prova-wsl-vhd.ps1*", [string]$Righe = "", [int]$Pausa = 2)
$r = "C:\claude\scrivi-console.txt"
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class Tasti {
  [StructLayout(LayoutKind.Explicit, CharSet=CharSet.Unicode)] public struct KEY { [FieldOffset(0)] public int bKeyDown; [FieldOffset(4)] public short wRepeatCount;
    [FieldOffset(6)] public short wVirtualKeyCode; [FieldOffset(8)] public short wVirtualScanCode; [FieldOffset(10)] public char UnicodeChar; [FieldOffset(12)] public int dwControlKeyState; }
  [StructLayout(LayoutKind.Explicit)] public struct REC { [FieldOffset(0)] public short EventType; [FieldOffset(4)] public KEY Key; }
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool FreeConsole();
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool AttachConsole(uint pid);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern IntPtr CreateFileW(string n, uint a, uint s, IntPtr sa, uint c, uint f, IntPtr t);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool WriteConsoleInputW(IntPtr h, REC[] r, uint n, out uint w);
  [DllImport("user32.dll")] public static extern short VkKeyScanW(char c);
  public static string Scrivi(uint pid, string testo) {
    FreeConsole();
    if (!AttachConsole(pid)) return "AttachConsole " + Marshal.GetLastWin32Error();
    IntPtr h = CreateFileW("CONIN$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
    if (h == new IntPtr(-1)) return "CONIN$ " + Marshal.GetLastWin32Error();
    foreach (char c in testo) {
      short vk = (c == '\r') ? (short)0x0D : (short)(VkKeyScanW(c) & 0xff);
      REC[] e = new REC[2];
      for (int i = 0; i < 2; i++) { e[i].EventType = 1; e[i].Key.bKeyDown = (i == 0) ? 1 : 0; e[i].Key.wRepeatCount = 1; e[i].Key.wVirtualKeyCode = vk; e[i].Key.UnicodeChar = c; }
      uint w; if (!WriteConsoleInputW(h, e, 2, out w)) return "WriteConsoleInput " + Marshal.GetLastWin32Error();
    }
    FreeConsole(); return "ok";
  }
}
"@
$p = Get-CimInstance Win32_Process | Where-Object { $_.Name -eq "powershell.exe" -and $_.CommandLine -like $Cerca } | Select-Object -First 1
if (-not $p) { "$(Get-Date -Format HH:mm:ss) console '$Cerca' non trovata" | Out-File $r; exit 1 }
$esiti = @()
$elenco = if ($Righe) { $Righe -split '\|' } else { Get-Content C:\claude\righe-console.txt }   # senza -Righe: una riga per riga del file
foreach ($riga in $elenco) { $esiti += [Tasti]::Scrivi([uint32]$p.ProcessId, "$riga`r"); Start-Sleep $Pausa }
"$(Get-Date -Format HH:mm:ss) console pid $($p.ProcessId): $($esiti -join ', ')" | Out-File $r
