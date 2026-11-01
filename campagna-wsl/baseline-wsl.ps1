# baseline-wsl.ps1 -- Claude 02/11/2026. Raccoglie in SOLA LETTURA i dati Windows/WSL per BASELINE.md (cancello G0).
# Va eseguito nella sessione console di marietto (schtasks /it): wsl.exe da ssh fallisce («identita' non corretta»).
$out = "C:\claude\baseline-wsl.txt"
"=== INIZIO $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -Encoding utf8 $out
function Scrivi($t) { $t | Out-File -Append -Encoding utf8 $out }
function Wsl([string]$a) {
    Scrivi "--- wsl $a"
    $p = Start-Process -FilePath "$env:SystemRoot\System32\wsl.exe" -ArgumentList $a -NoNewWindow -Wait -PassThru `
         -RedirectStandardOutput C:\claude\b-o.txt -RedirectStandardError C:\claude\b-e.txt
    foreach ($f in "C:\claude\b-o.txt", "C:\claude\b-e.txt") {
        $b = [IO.File]::ReadAllBytes($f)
        # wsl.exe scrive in UTF-16, i programmi Linux in UTF-8
        if ($b.Length -gt 1 -and $b[1] -eq 0) { Scrivi ([Text.Encoding]::Unicode.GetString($b)) }
        elseif ($b.Length) { Scrivi ([Text.Encoding]::UTF8.GetString($b)) }
    }
    Scrivi "--- codice $($p.ExitCode)"
}
$v = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
Scrivi "--- Windows: $($v.ProductName) $($v.DisplayVersion) build $($v.CurrentBuild).$($v.UBR) ($($v.EditionID))"
$c = Get-CimInstance Win32_ComputerSystem
Scrivi "--- macchina: $($c.Name), hypervisor presente $($c.HypervisorPresent), vCPU logiche $($c.NumberOfLogicalProcessors), RAM $([math]::Round($c.TotalPhysicalMemory/1GB,1)) GB"
$g = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard Win32_DeviceGuard
Scrivi "--- VBS: stato $($g.VirtualizationBasedSecurityStatus) (0 spento, 1 abilitato, 2 in esecuzione); servizi in esecuzione: $($g.SecurityServicesRunning -join ',')"
foreach ($n in "Microsoft-Hyper-V-All", "VirtualMachinePlatform", "Microsoft-Windows-Subsystem-Linux", "HypervisorPlatform") {
    $f = Get-WindowsOptionalFeature -Online -FeatureName $n -ErrorAction SilentlyContinue
    Scrivi "--- funzione ${n}: $($f.State)"
}
$cfg = Join-Path $env:USERPROFILE ".wslconfig"
if (Test-Path $cfg) { Scrivi "--- .wslconfig:"; Scrivi (Get-Content $cfg -Raw) } else { Scrivi "--- .wslconfig: assente" }
Wsl "--version"
Wsl "--status"
Wsl "--list --verbose"
Wsl "-e uname -a"
Wsl "-e sh -c `"grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release; nproc; free -m | head -2`""
Wsl "--shutdown"
"=== FINE $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -Append -Encoding utf8 $out
