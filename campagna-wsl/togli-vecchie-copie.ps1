# togli-vecchie-copie.ps1 -- Claude 03/11/2026. Copie di prova superate in C:\claude\wsl-fbsd (gli originali sono
# sull'host, verificati con sha alla copia). Elenco esplicito: niente caratteri jolly.
$nomi = @(
  'fbsd152-wsl-ro3k.vhd', 'fbsd152-wsl-ro3l.vhd', 'fbsd152-wsl-ro4a.vhd', 'fbsd152-wsl-ro4b.vhd', 'fbsd152-wsl-ro4c.vhd',
  'fbsd152-wsl-ro4d.vhd', 'fbsd152-wsl-ro4e.vhd', 'fbsd152-wsl-ro4f.vhd')
foreach ($n in $nomi) {
    $p = Join-Path 'C:\claude\wsl-fbsd' $n
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p; "tolto $n" }
}
"liberi su C: " + [math]::Round((Get-PSDrive C).Free / 1GB, 1) + " GB"
