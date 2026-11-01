# Claude 24/10/2026 -- parere #42 §3/§9: memoria che la VM di WSL tiene davvero in Windows.
# Ogni secondo: ora di Windows in ns dall'epoca Unix (stesso orologio di hvperf.ps1, che ne da'
# lo scarto dall'host coi marcatori UDP), e per ogni processo vmmem* working set e memoria
# privata; poi la memoria fisica libera di Windows (kB).
# Righe: "P ns nome pid ws_byte privata_byte" e "S ns libera_kB".
# Si ferma prima se compare C:\claude\faseA\memwin-stop (lo crea l'host a fine fase).
# uso: memwin.ps1 -Sec 700 -Tag A1
param([int]$Sec = 700, [string]$Tag = "")
$d = "C:\claude\faseA"
$out = "$d\memwin$Tag.txt"
"# memwin $Sec s, fase $Tag" | Out-File -Encoding ascii $out
$e0 = [datetime]::new(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc).Ticks
if (Test-Path "$d\memwin-stop") { Remove-Item "$d\memwin-stop" }
$fine = (Get-Date).AddSeconds($Sec)
while ((Get-Date) -lt $fine) {
    if (Test-Path "$d\memwin-stop") { break }
    $t = ([datetime]::UtcNow.Ticks - $e0) * 100
    $r = @()
    foreach ($p in (Get-Process -Name vmmem* -ErrorAction SilentlyContinue)) {
        $r += "P $t $($p.ProcessName) $($p.Id) $($p.WorkingSet64) $($p.PrivateMemorySize64)"
    }
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $r += "S $t $($os.FreePhysicalMemory)"
    $r | Out-File -Append -Encoding ascii $out
    Start-Sleep -Milliseconds 1000
}
"MEMWIN-FINE" | Out-File -Append -Encoding ascii $out
