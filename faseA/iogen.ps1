# Claude 23/10/2026 -- parere #33 §3, prova C: I/O NTFS generato da Windows mentre WSL2
# e' acceso con il solo campionatore. Cicli di 8 file da 128 MB: scrittura, lettura e
# SHA-256, con l'ora UTC in ms di ogni passo. uso: iogen.ps1 -Sec 420
param([int]$Sec = 420)
$dir = "C:\claude\iogen"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$log = "C:\claude\faseA\iogen.log"
"=== $([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) inizio" | Out-File -Encoding utf8 $log
$buf = New-Object byte[] (128MB)
(New-Object Random).NextBytes($buf)
$t0 = Get-Date
while (((Get-Date) - $t0).TotalSeconds -lt $Sec) {
  for ($i = 1; $i -le 8; $i++) { [IO.File]::WriteAllBytes("$dir\f$i", $buf) }
  "$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) scritti" | Out-File -Append -Encoding utf8 $log
  for ($i = 1; $i -le 8; $i++) { $null = Get-FileHash -Algorithm SHA256 "$dir\f$i" }
  "$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) letti" | Out-File -Append -Encoding utf8 $log
}
"=== $([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) FINE" | Out-File -Append -Encoding utf8 $log
