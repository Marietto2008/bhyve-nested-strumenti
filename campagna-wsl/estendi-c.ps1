# estendi-c.ps1 -- Claude 03/11/2026. Estende C: sul disco portato da 200 a 400 GiB (immagine del clone allungata
# sull'host). Procedura Microsoft: WinRE disattivato, partizione di ripristino tolta, C: estesa lasciando 1 GiB in
# fondo, partizione di ripristino ricreata in fondo, WinRE riattivato. Si ferma al primo passo che non torna.
$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "Claude: estensione di C: (200 -> 400 GiB)"
Start-Transcript -Path C:\claude\estendi-c.log -Force | Out-Null
function Passo($t) { Write-Host ""; Write-Host "[claude] $(Get-Date -Format HH:mm:ss) $t" -ForegroundColor Cyan }
function Stato {
    Get-Partition -DiskNumber 0 | Format-Table PartitionNumber,DriveLetter,Type,@{n='InizioGB';e={[math]::Round($_.Offset/1GB,2)}},@{n='GB';e={[math]::Round($_.Size/1GB,2)}} -AutoSize | Out-Host
    Get-Volume -DriveLetter C | Format-Table DriveLetter,@{n='GB';e={[math]::Round($_.Size/1GB,1)}},@{n='LiberiGB';e={[math]::Round($_.SizeRemaining/1GB,2)}} -AutoSize | Out-Host
}
try {
    Passo "1. il disco come lo vede Windows adesso"
    Update-HostStorageCache; Update-Disk -Number 0
    $d = Get-Disk -Number 0; Write-Host ("disco 0: {0:N1} GiB" -f ($d.Size / 1GB)); Stato
    if ($d.Size -lt 399GB) { throw "il disco non e' cresciuto: $($d.Size)" }
    $rec = Get-Partition -DiskNumber 0 | Where-Object { $_.GptType -eq '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}' }
    $c = Get-Partition -DriveLetter C
    if (@($rec).Count -ne 1) { throw "attesa UNA partizione di ripristino, trovate $(@($rec).Count)" }
    if ($rec.Offset -lt $c.Offset) { throw "la partizione di ripristino non e' dopo C: (non serve toglierla)" }

    Passo "2. WinRE disattivato (l'immagine di ripristino torna in C:\Windows\System32\Recovery)"
    reagentc /disable | Out-Host
    if (-not (Test-Path C:\Windows\System32\Recovery\Winre.wim -PathType Leaf)) { throw "Winre.wim non e' in C:\Windows\System32\Recovery: mi fermo PRIMA di toccare le partizioni" }
    Write-Host ("Winre.wim su C: ({0:N0} MB)" -f ((Get-Item -Force C:\Windows\System32\Recovery\Winre.wim).Length / 1MB))

    Passo "3. tolgo la vecchia partizione di ripristino (numero $($rec.PartitionNumber), $([math]::Round($rec.Size/1MB)) MB)"
    Remove-Partition -DiskNumber 0 -PartitionNumber $rec.PartitionNumber -Confirm:$false
    Stato

    Passo "4. estendo C: lasciando 1 GiB in fondo"
    $max = (Get-PartitionSupportedSize -DriveLetter C).SizeMax
    Resize-Partition -DriveLetter C -Size ($max - 1GB)
    Stato

    Passo "5. nuova partizione di ripristino in fondo al disco"
    $p = New-Partition -DiskNumber 0 -UseMaximumSize -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'
    Format-Volume -Partition $p -FileSystem NTFS -NewFileSystemLabel "Recovery" -Confirm:$false | Out-Null
    "select disk 0`r`nselect partition $($p.PartitionNumber)`r`ngpt attributes=0x8000000000000001`r`n" | Out-File -Encoding ascii C:\claude\estendi-c-dp.txt
    diskpart /s C:\claude\estendi-c-dp.txt | Out-Host
    Stato

    Passo "6. WinRE riattivato"
    reagentc /enable | Out-Host
    reagentc /info | Out-Host
    Passo "FATTO" ; Write-Host "ESITO: OK" -ForegroundColor Green
}
catch { Write-Host ""; Write-Host "ESITO: FERMATO - $($_.Exception.Message)" -ForegroundColor Red }
finally { Stop-Transcript | Out-Null; Write-Host ""; Write-Host "Premi un tasto per chiudere." -ForegroundColor Yellow; [void][Console]::ReadKey($true) }
