# togli-vecchie-copie.ps1 -- Claude 03/11/2026. Copie di prova superate in C:\claude\wsl-fbsd (gli originali sono
# sull'host, verificati con sha alla copia). Elenco esplicito: niente caratteri jolly.
$nomi = @(
  'avvio-dbg1.vhdx', 'avvio-dbg2.vhdx', 'avvio-dbg3.vhdx', 'avvio-dbg4.vhdx', 'avvio-dbg5.vhdx', 'avvio-dbg6.vhdx',
  'avvio-dbg6.vhd', 'avvio-dbg7.vhd', 'avvio-dbg8.vhd', 'avvio-dbg9.vhd', 'avvio-dbg10.vhd', 'avvio-dbg12.vhd',
  'avvio-vpci1.vhd', 'avvio-vpci2.vhd', 'avvio-vpci3.vhd', 'avvio-fix1.vhd', 'avvio-fix2.vhd',
  'fbsd152-wsl-ro1.vhd', 'fbsd152-wsl-ro2.vhd', 'fbsd152-wsl-ro3.vhd', 'fbsd152-wsl-ro3b.vhd', 'fbsd152-wsl-ro3c.vhd',
  'fbsd152-wsl-ro3d.vhd', 'fbsd152-wsl-ro3e.vhd', 'fbsd152-wsl-ro3f.vhd', 'fbsd152-wsl-ro3g.vhd', 'fbsd152-wsl-ro3h.vhd',
  'fbsd152-wsl-ro3i.vhd', 'fbsd152-wsl-ro3j.vhd')
foreach ($n in $nomi) {
    $p = Join-Path 'C:\claude\wsl-fbsd' $n
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p; "tolto $n" }
}
"liberi su C: " + [math]::Round((Get-PSDrive C).Free / 1GB, 1) + " GB"
