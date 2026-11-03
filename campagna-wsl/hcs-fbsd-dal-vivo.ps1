# hcs-fbsd-dal-vivo.ps1 -- Claude 03/11/2026. Come hcs-fbsd.ps1 (FreeBSD come utility VM di HCS, schema del fork
# WSL-For-FreeBSD, Uefi.BootThis ScsiDrive, senza il servizio WSL) ma DAL VIVO: la COM1 di FreeBSD si vede in questa
# finestra mentre arriva, e i tasti vanno a FreeBSD (login sulla console seriale). F10 = spegne la VM ed esce.
# Registro: dal-vivo-com1.txt (tutta la COM1) e dal-vivo-esito.txt (i passi). Va lanciato nella sessione di marietto,
# da amministratore (schtasks /it /rl highest): computecore.dll richiede i privilegi.
# -Avvio VmbFs (03/11, ADR-001 opzione B): il firmware carica loader.efi da una CARTELLA di Windows (come WSL fa
# su ARM64 col kernel), e OptionalData gli passa le variabili (rootdev=...) per trovare il kernel sul disco SCSI.
param([string]$Disco = "C:\claude\wsl-fbsd\fbsd152-wsl.vhdx", [int]$Cpu = 2, [int]$MemMB = 2048,
      [ValidateSet("ScsiDrive", "VmbFs")][string]$Avvio = "ScsiDrive",
      [string]$VmbFsDir = "C:\claude\wsl-fbsd\vmbfs", [string]$VmbFsFile = "\loader.efi",
      [string]$Opzioni = "console=comconsole rootdev=disk0p4:",
      # -ConsoleVirtio (03/11): la stessa console virtio hvc0 che WSL aggiunge (VirtioSerial, su vPCI): riproduce il
      # blocco di FreeBSD su virtio_pci visto con wsl.exe (ADR-002, prova 1)
      [switch]$ConsoleVirtio,
      # -Disco2 (03/11): secondo disco SCSI (LUN 1 = disk1 per il loader), es. un disco di AVVIO piccolo con un kernel
      # di prova: rootdev=disk1p1: e vfs.root.mountfrom=ufs:/dev/gpt/rootfs per la radice del disco principale
      [string]$Disco2 = "")
$ErrorActionPreference = "Stop"
$dir = "C:\claude\wsl-fbsd"; $log = "$dir\dal-vivo-com1.txt"; $esito = "$dir\dal-vivo-esito.txt"
$Host.UI.RawUI.WindowTitle = "FreeBSD 15.2 come VM di Hyper-V (HCS) - console COM1 dal vivo - F10 spegne"
try { $Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(132, 5000)
      $Host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size(132, 46) } catch { }
[Console]::TreatControlCAsInput = $true
"" | Out-File -Encoding utf8 $log
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') inizio" | Out-File -Encoding utf8 $esito
function Di($t, $col = "Cyan") {
    $r = "$(Get-Date -Format HH:mm:ss) $t"
    Write-Host ""; Write-Host "[claude] $r" -ForegroundColor $col
    $r | Out-File -Append -Encoding utf8 $esito
}

Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class Hcs {
  [DllImport("computecore.dll")] public static extern IntPtr HcsCreateOperation(IntPtr ctx, IntPtr cb);
  [DllImport("computecore.dll")] public static extern void HcsCloseOperation(IntPtr op);
  [DllImport("computecore.dll", CharSet=CharSet.Unicode)] public static extern int HcsWaitForOperationResult(IntPtr op, uint ms, out IntPtr doc);
  [DllImport("computecore.dll", CharSet=CharSet.Unicode)] public static extern int HcsCreateComputeSystem(string id, string json, IntPtr op, IntPtr sd, out IntPtr cs);
  [DllImport("computecore.dll", CharSet=CharSet.Unicode)] public static extern int HcsStartComputeSystem(IntPtr cs, IntPtr op, string opt);
  [DllImport("computecore.dll", CharSet=CharSet.Unicode)] public static extern int HcsTerminateComputeSystem(IntPtr cs, IntPtr op, string opt);
  [DllImport("computecore.dll")] public static extern void HcsCloseComputeSystem(IntPtr cs);
  [DllImport("computecore.dll", CharSet=CharSet.Unicode)] public static extern int HcsGrantVmAccess(string vmId, string path);
  public static string Doc(IntPtr p) { return p == IntPtr.Zero ? "" : Marshal.PtrToStringUni(p); }
}
"@

Write-Host "FreeBSD 15.2 come utility VM di Hyper-V, nello stesso modo in cui WSL2 avvia il suo Linux." -ForegroundColor Yellow
Write-Host "Disco $Disco, $Cpu CPU, $MemMB MB. Quello che segue e' la console seriale di FreeBSD. F10 = spegni." -ForegroundColor Yellow

$id = [guid]::NewGuid().ToString()
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$pipe = "claude-fbsd-com1"
if ($Avvio -eq "VmbFs") {
    $bootThis = ConvertTo-Json -Compress @{ DeviceType = "VmbFs"; VmbFsRootPath = $VmbFsDir; DevicePath = $VmbFsFile; OptionalData = $Opzioni }
} else {
    $bootThis = '{ "DevicePath": "Primary disk", "DiskNumber": 0, "DeviceType": "ScsiDrive" }'
}
Write-Host "Avvio: $Avvio $bootThis" -ForegroundColor Yellow
$secondo = ""
if ($Disco2) { $secondo = ', "1": { "Type": "VirtualDisk", "Path": "' + ($Disco2 -replace '\\','\\') + '" }'
               Write-Host "Secondo disco: $Disco2" -ForegroundColor Yellow }
$virtio = ""
if ($ConsoleVirtio) { $virtio = ',' + "`n" + '      "VirtioSerial": { "Ports": { "0": { "Name": "hvc0", "NamedPipe": "\\\\.\\pipe\\claude-fbsd-hvc0", "ConsoleSupport": true } } }'
                     Write-Host "Console virtio hvc0: SI'" -ForegroundColor Yellow }
$json = @"
{
  "Owner": "claude-fbsd",
  "SchemaVersion": { "Major": 2, "Minor": 3 },
  "ShouldTerminateOnLastHandleClosed": true,
  "VirtualMachine": {
    "StopOnReset": true,
    "Chipset": { "Uefi": { "BootThis": $bootThis } },
    "ComputeTopology": {
      "Memory": { "SizeInMB": $MemMB, "AllowOvercommit": true, "BackingPageSize": "Small" },
      "Processor": { "Count": $Cpu }
    },
    "Devices": {
      "ComPorts": { "0": { "NamedPipe": "\\\\.\\pipe\\$pipe" } },
      "HvSocket": { "HvSocketConfig": {
        "DefaultBindSecurityDescriptor": "D:P(A;;FA;;;SY)(A;;FA;;;$sid)",
        "DefaultConnectSecurityDescriptor": "D:P(A;;FA;;;SY)(A;;FA;;;$sid)" } },
      "Scsi": { "Primary disk": { "Attachments": { "0": { "Type": "VirtualDisk", "Path": "$($Disco -replace '\\','\\')" }$secondo } } }$virtio
    }
  }
}
"@
$json | Out-File -Encoding utf8 "$dir\dal-vivo.json"

$cs = [IntPtr]::Zero; $op = [IntPtr]::Zero
try {
    $hr = [Hcs]::HcsGrantVmAccess($id, $Disco); Di ("accesso al disco per la VM {0}: hr=0x{1:X8}" -f $id, $hr)
    if ($hr -ne 0) { throw "GrantVmAccess fallita" }
    if ($Disco2) { $hr = [Hcs]::HcsGrantVmAccess($id, $Disco2); Di ("accesso al secondo disco: hr=0x{0:X8}" -f $hr)
                   if ($hr -ne 0) { throw "GrantVmAccess (secondo disco) fallita" } }
    $op = [Hcs]::HcsCreateOperation([IntPtr]::Zero, [IntPtr]::Zero)
    $hr = [Hcs]::HcsCreateComputeSystem($id, $json, $op, [IntPtr]::Zero, [ref]$cs)
    $doc = [IntPtr]::Zero; $hr = [Hcs]::HcsWaitForOperationResult($op, 60000, [ref]$doc); [Hcs]::HcsCloseOperation($op)
    Di ("VM creata: hr=0x{0:X8} {1}" -f $hr, [Hcs]::Doc($doc)); if ($hr -ne 0) { throw "Create fallita" }
    $op = [Hcs]::HcsCreateOperation([IntPtr]::Zero, [IntPtr]::Zero)
    $hr = [Hcs]::HcsStartComputeSystem($cs, $op, $null); Di ("accensione chiesta: hr=0x{0:X8}" -f $hr)
    $t0 = Get-Date; $avviata = $false; $c = $null; $leggi = $null; $buf = New-Object byte[] 4096
    $enc = [Text.Encoding]::UTF8; $tutto = New-Object Text.StringBuilder; $segnale = $false
    while ($true) {
        if (-not $avviata) {
            $doc = [IntPtr]::Zero; $hr = [Hcs]::HcsWaitForOperationResult($op, 50, [ref]$doc)
            if ($hr -eq 0) { $avviata = $true; Di ("Hyper-V: VM accesa dopo {0:N1} s" -f ((Get-Date) - $t0).TotalSeconds) }
            elseif ($hr -ne -2143878888) { Di ("accensione fallita: hr=0x{0:X8} {1}" -f $hr, [Hcs]::Doc($doc)) Red; break }
        }
        if ($c -eq $null) {
            try { $c = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipe, [IO.Pipes.PipeDirection]::InOut, [IO.Pipes.PipeOptions]::Asynchronous)
                  $c.Connect(200); Di ("console COM1 collegata dopo {0:N1} s" -f ((Get-Date) - $t0).TotalSeconds) Green
                  $leggi = $c.ReadAsync($buf, 0, $buf.Length) }
            catch { $c = $null }
        }
        if ($leggi -ne $null -and $leggi.Wait(30)) {
            $n = $leggi.Result
            if ($n -le 0) { Di "FreeBSD ha chiuso la console (VM spenta)" Yellow; break }
            $s = $enc.GetString($buf, 0, $n); [void]$tutto.Append($s)
            Write-Host -NoNewline $s; [IO.File]::AppendAllText($log, $s)
            if (-not $segnale -and $tutto.ToString() -match "CLAUDE-FBSD-WSL: multiutente raggiunto") { $segnale = $true
                Di ("FreeBSD al multiutente dopo {0:N1} s dall'accensione. Login: root (senza password)" -f ((Get-Date) - $t0).TotalSeconds) Green }
            $leggi = $c.ReadAsync($buf, 0, $buf.Length)
        }
        while ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true)
            if ($k.Key -eq [ConsoleKey]::F10) { Di "F10: spengo la VM" Yellow; throw "fine chiesta" }
            if ($c -ne $null) {
                switch ($k.Key) {
                    ([ConsoleKey]::Enter)     { $b = [byte[]](13) }
                    ([ConsoleKey]::Backspace) { $b = [byte[]](127) }
                    ([ConsoleKey]::UpArrow)   { $b = [byte[]](27, 91, 65) }
                    ([ConsoleKey]::DownArrow) { $b = [byte[]](27, 91, 66) }
                    ([ConsoleKey]::RightArrow){ $b = [byte[]](27, 91, 67) }
                    ([ConsoleKey]::LeftArrow) { $b = [byte[]](27, 91, 68) }
                    default { if ([int]$k.KeyChar -ne 0) { $b = $enc.GetBytes([string]$k.KeyChar) } else { $b = $null } }
                }
                if ($b) { $c.Write($b, 0, $b.Length); $c.Flush() }
            }
        }
        if ($c -eq $null -and $avviata) { Start-Sleep -Milliseconds 200 }
    }
}
catch { if ($_.Exception.Message -ne "fine chiesta") { Di "ERRORE: $($_.Exception.Message)" Red } }
finally {
    if ($cs -ne [IntPtr]::Zero) {
        $op2 = [Hcs]::HcsCreateOperation([IntPtr]::Zero, [IntPtr]::Zero)
        $hr = [Hcs]::HcsTerminateComputeSystem($cs, $op2, $null)
        $doc = [IntPtr]::Zero; [void][Hcs]::HcsWaitForOperationResult($op2, 30000, [ref]$doc)
        [Hcs]::HcsCloseOperation($op2); [Hcs]::HcsCloseComputeSystem($cs)
        Di ("VM spenta (Terminate hr=0x{0:X8})" -f $hr) Yellow
    }
    "=== fine" | Out-File -Append -Encoding utf8 $esito
    Write-Host ""; Write-Host "Premi un tasto per chiudere la finestra." -ForegroundColor Yellow
    [void][Console]::ReadKey($true)
}
