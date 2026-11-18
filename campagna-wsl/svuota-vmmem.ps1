# svuota-vmmem.ps1 -- Claude 05/11/2026, procedura di riproduzione del difetto LAPIC/MMIO (rapporti WSL2-FreeBSD
# 009-010). Svuota a ripetizione il working set del processo della VM di WSL (vmmemWSL, o vmmem), perche'
# Hyper-V tracci piu' spesso gli accessi alla memoria del guest. Registro in C:\claude\svuota-vmmem.log.
# Uso: svuota-vmmem.ps1 [-Secondi 1100] [-PausaMs 1000]
param([int]$Secondi = 1100, [int]$PausaMs = 1000)
$log = 'C:\claude\svuota-vmmem.log'
Add-Type -Namespace W -Name P -MemberDefinition @'
[DllImport("psapi.dll", SetLastError = true)] public static extern bool EmptyWorkingSet(IntPtr h);
[DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr OpenProcess(uint acc, bool inh, int pid);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
'@
"inizio $(Get-Date -Format 'HH:mm:ss.fff')" | Out-File $log -Encoding ascii
$fine = (Get-Date).AddSeconds($Secondi); $ok = 0; $ko = 0; $ultimoErr = 0
while ((Get-Date) -lt $fine) {
    $p = Get-Process -Name vmmemWSL, vmmem -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p) {
        $ws = $p.WorkingSet64
        $h = [W.P]::OpenProcess(0x1100, $false, $p.Id)   # PROCESS_SET_QUOTA | PROCESS_QUERY_LIMITED_INFORMATION
        if ($h -ne [IntPtr]::Zero -and [W.P]::EmptyWorkingSet($h)) { $ok++ } else { $ko++; $ultimoErr = [Runtime.InteropServices.Marshal]::GetLastWin32Error() }
        if ($h -ne [IntPtr]::Zero) { [void][W.P]::CloseHandle($h) }
        if (($ok + $ko) % 60 -eq 1) { "{0} {1} pid={2} ws={3:N0} MB ok={4} ko={5} err={6}" -f (Get-Date -Format 'HH:mm:ss'), $p.Name, $p.Id, ($ws / 1MB), $ok, $ko, $ultimoErr | Out-File $log -Append -Encoding ascii }
    }
    Start-Sleep -Milliseconds $PausaMs
}
"fine $(Get-Date -Format 'HH:mm:ss.fff') ok=$ok ko=$ko err=$ultimoErr" | Out-File $log -Append -Encoding ascii
