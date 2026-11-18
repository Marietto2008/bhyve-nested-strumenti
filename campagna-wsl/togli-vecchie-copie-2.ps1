# togli-vecchie-copie-2.ps1 -- Claude 05/11/2026 (utente: «cancella un po' di vecchie immagini su C. Lo spazio e' quasi
# esaurito»). Copie di prova superate in C:\claude\wsl-fbsd (gli originali sono sull'host in
# wsl2-freebsd-work/images/claude-wsl2-immagini, con sha256) e i file di carico della notte del 05/11.
# RESTANO: distro\FreeBSD.vhd (distro registrata), fbsd152-wsl-ro7d.vhd (riproduttore del panic LAPIC), le basi
# fbsd152-wsl.vhd/.vhdx e fbsd15-wsl.vhdx. Elenco esplicito: niente caratteri jolly.
$copie = @(
  'fbsd152-wsl-ro4g.vhd', 'fbsd152-wsl-ro4h.vhd', 'fbsd152-wsl-ro4i.vhd', 'fbsd152-wsl-ro4j.vhd', 'fbsd152-wsl-ro4k.vhd',
  'fbsd152-wsl-ro4l.vhd', 'fbsd152-wsl-ro5a.vhd', 'fbsd152-wsl-ro6a.vhd', 'fbsd152-wsl-ro6b.vhd', 'fbsd152-wsl-ro7a.vhd',
  'fbsd152-wsl-ro7b.vhd', 'fbsd152-wsl-ro7c.vhd')
$prove = @('carico0.bin', 'carico1.bin', 'prova-disco.bin', 'prova-disco2.bin', 'prova-disco3.bin', 'prova-disco4.bin',
  'prova-disco5.bin')
"liberi prima: " + [math]::Round((Get-PSDrive C).Free / 1GB, 1) + " GB"
foreach ($n in $copie) {
    $p = Join-Path 'C:\claude\wsl-fbsd' $n
    if (Test-Path -LiteralPath $p) {
        try { Remove-Item -LiteralPath $p -ErrorAction Stop; "tolto $n" } catch { "NON tolto $n : $($_.Exception.Message)" }
    }
}
foreach ($n in $prove) {
    $p = Join-Path 'C:\claude' $n
    if (Test-Path -LiteralPath $p) {
        try { Remove-Item -LiteralPath $p -ErrorAction Stop; "tolto $n" } catch { "NON tolto $n : $($_.Exception.Message)" }
    }
}
"liberi dopo: " + [math]::Round((Get-PSDrive C).Free / 1GB, 1) + " GB"
