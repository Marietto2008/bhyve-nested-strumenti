# hcs-fbsd.ps1 -- Claude 02/11/2026. Avvia FreeBSD come utility VM di HCS (Host Compute Service), con lo STESSO
# meccanismo e lo stesso schema JSON del fork WSL-For-FreeBSD (WslCoreVm.cpp, Chipset.Uefi.BootThis ScsiDrive),
# ma senza il servizio WSL: e' la prova che separa i difetti di Hyper-V/nested da quelli di WSL (G1).
# Registra la COM1 (named pipe) in un file; si ferma alla riga di successo o allo scadere; spegne SEMPRE la VM.
# Uso (amministratore): powershell -ExecutionPolicy Bypass -File hcs-fbsd.ps1 [-Secondi 180]
param([int]$Secondi = 180, [string]$Disco = "C:\claude\wsl-fbsd\fbsd15-wsl.vhdx")
$ErrorActionPreference = "Stop"
$log = "C:\claude\wsl-fbsd\hcs-fbsd-com1.txt"
$esito = "C:\claude\wsl-fbsd\hcs-fbsd-esito.txt"
"" | Out-File -Encoding utf8 $log
function Esito($t) { "$(Get-Date -Format HH:mm:ss) $t" | Out-File -Append -Encoding utf8 $esito }
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') inizio" | Out-File -Encoding utf8 $esito

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

function Attendi($op, $cosa) {
    $doc = [IntPtr]::Zero
    $hr = [Hcs]::HcsWaitForOperationResult($op, 60000, [ref]$doc)
    $t = [Hcs]::Doc($doc)
    Esito ("{0}: hr=0x{1:X8} {2}" -f $cosa, $hr, $t)
    if ($hr -ne 0) { throw "$cosa fallita: 0x$('{0:X8}' -f $hr) $t" }
}

$id = [guid]::NewGuid().ToString()
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$pipe = "claude-fbsd-com1"
$json = @"
{
  "Owner": "claude-fbsd",
  "SchemaVersion": { "Major": 2, "Minor": 3 },
  "ShouldTerminateOnLastHandleClosed": true,
  "VirtualMachine": {
    "StopOnReset": true,
    "Chipset": { "Uefi": { "BootThis": { "DevicePath": "Primary disk", "DiskNumber": 0, "DeviceType": "ScsiDrive" } } },
    "ComputeTopology": {
      "Memory": { "SizeInMB": 2048, "AllowOvercommit": true, "BackingPageSize": "Small" },
      "Processor": { "Count": 2 }
    },
    "Devices": {
      "ComPorts": { "0": { "NamedPipe": "\\\\.\\pipe\\$pipe" } },
      "HvSocket": { "HvSocketConfig": {
        "DefaultBindSecurityDescriptor": "D:P(A;;FA;;;SY)(A;;FA;;;$sid)",
        "DefaultConnectSecurityDescriptor": "D:P(A;;FA;;;SY)(A;;FA;;;$sid)" } },
      "Scsi": { "Primary disk": { "Attachments": { "0": { "Type": "VirtualDisk", "Path": "$($Disco -replace '\\','\\')" } } } }
    }
  }
}
"@
$json | Out-File -Encoding utf8 "C:\claude\wsl-fbsd\hcs-fbsd.json"
Esito "id $id, disco $Disco, utente $sid"

$cs = [IntPtr]::Zero
try {
    $hr = [Hcs]::HcsGrantVmAccess($id, $Disco); Esito ("GrantVmAccess hr=0x{0:X8}" -f $hr)
    if ($hr -ne 0) { throw "GrantVmAccess fallita" }
    $op = [Hcs]::HcsCreateOperation([IntPtr]::Zero, [IntPtr]::Zero)
    $hr = [Hcs]::HcsCreateComputeSystem($id, $json, $op, [IntPtr]::Zero, [ref]$cs); Esito ("CreateComputeSystem hr=0x{0:X8}" -f $hr)
    Attendi $op "Create"; [Hcs]::HcsCloseOperation($op)
    $op = [Hcs]::HcsCreateOperation([IntPtr]::Zero, [IntPtr]::Zero)
    $hr = [Hcs]::HcsStartComputeSystem($cs, $op, $null); Esito ("StartComputeSystem hr=0x{0:X8}" -f $hr)
    # Start puo' durare minuti nel nested: si aspetta a passi di 2 s e INTANTO ci si collega alla COM1
    # (il server della pipe e' il processo della VM), cosi' si vede l'avvio anche se Start non e' finita
    $fine = (Get-Date).AddSeconds($Secondi); $avviata = $false; $c = $null; $r = $null; $t = $null
    $buf = New-Object char[] 4096; $tutto = ""; $t0 = Get-Date; $segnale = $false
    while ((Get-Date) -lt $fine) {
        if (-not $avviata) {
            $doc = [IntPtr]::Zero; $hr = [Hcs]::HcsWaitForOperationResult($op, 2000, [ref]$doc)
            if ($hr -eq 0) { $avviata = $true; Esito ("Start completata dopo {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds) }
            elseif ($hr -ne -2143878888) { Esito ("Start fallita: hr=0x{0:X8} {1}" -f $hr, [Hcs]::Doc($doc)); break }
        }
        if ($c -eq $null) {
            try { $c = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipe, [System.IO.Pipes.PipeDirection]::In)
                  $c.Connect(500); Esito ("COM1 collegata dopo {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds)
                  $r = New-Object System.IO.StreamReader($c, [Text.Encoding]::ASCII); $t = $r.ReadAsync($buf, 0, $buf.Length) }
            catch { $c = $null }
        }
        if ($t -ne $null -and $t.Wait(500)) {
            $n = $t.Result; if ($n -le 0) { Esito "COM1 chiusa dalla VM"; break }
            $s = New-Object string($buf, 0, $n); $tutto += $s
            [IO.File]::AppendAllText($log, $s)
            if (-not $segnale -and $tutto -match "CLAUDE-FBSD-WSL: multiutente raggiunto") { $segnale = $true
                Esito ("SEGNALE RICEVUTO dopo {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds); $fine = (Get-Date).AddSeconds(5) }  # si legge ancora 5 s: la riga arriva a pezzi
            $t = $r.ReadAsync($buf, 0, $buf.Length)
        }
        if ($c -eq $null -and $avviata) { Start-Sleep -Milliseconds 500 }
    }
    if (-not $avviata) { Esito "Start NON completata entro $Secondi s" }
    [Hcs]::HcsCloseOperation($op)
    if ($tutto -notmatch "CLAUDE-FBSD-WSL") { Esito "NESSUN SEGNALE entro $Secondi s ($($tutto.Length) caratteri ricevuti)" }
}
catch { Esito "ERRORE: $($_.Exception.Message)" }
finally {
    if ($cs -ne [IntPtr]::Zero) {
        $op = [Hcs]::HcsCreateOperation([IntPtr]::Zero, [IntPtr]::Zero)
        $hr = [Hcs]::HcsTerminateComputeSystem($cs, $op, $null); Esito ("TerminateComputeSystem hr=0x{0:X8}" -f $hr)
        try { Attendi $op "Terminate" } catch { }
        [Hcs]::HcsCloseOperation($op); [Hcs]::HcsCloseComputeSystem($cs)
    }
    Esito "=== fine"
}
