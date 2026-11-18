# carico-disco.ps1: scrive e rilegge file da 256 MB per <Secondi> secondi; una riga per giro in C:\claude\carico.log
param([int]$Secondi = 200)
$log = 'C:\claude\carico.log'
$b = New-Object byte[] 268435456
(New-Object Random).NextBytes($b)
[IO.File]::WriteAllBytes('C:\claude\carico0.bin', $b); [IO.File]::WriteAllBytes('C:\claude\carico1.bin', $b)
$fine = (Get-Date).AddSeconds($Secondi); $i = 0
"inizio $(Get-Date -Format 'HH:mm:ss.fff')" | Out-File $log
while ((Get-Date) -lt $fine) {
  $t0 = Get-Date
  $fs = [IO.File]::Open("C:\claude\carico$($i % 2).bin", 'Create', 'Write', 'None')
  $fs.Write($b, 0, $b.Length); $fs.Flush($true); $fs.Close()
  $null = [IO.File]::ReadAllBytes("C:\claude\carico$(($i + 1) % 2).bin")
  "{0} giro {1} {2:N0} ms" -f (Get-Date -Format 'HH:mm:ss.fff'), $i, ((Get-Date) - $t0).TotalMilliseconds | Out-File $log -Append
  $i++
}
"fine $(Get-Date -Format 'HH:mm:ss.fff')" | Out-File $log -Append
