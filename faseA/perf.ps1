# Claude 23/10/2026 -- parere #33 §3: contatori di Windows ogni secondo durante una prova
# del filone DrvFs/9P (CPU, disco, coda dei processi), con l'ora di Windows nel CSV.
# uso: perf.ps1 -M A -Sec 480
param([string]$M = "A", [int]$Sec = 480)
$out = "C:\claude\faseA\perf-$M.csv"
if (Test-Path $out) { Clear-Content $out }
& typeperf "\Processor(_Total)\% Processor Time" "\PhysicalDisk(_Total)\Disk Bytes/sec" "\PhysicalDisk(_Total)\Avg. Disk sec/Transfer" "\System\Processor Queue Length" -si 1 -sc $Sec -f CSV -o $out -y | Out-Null
