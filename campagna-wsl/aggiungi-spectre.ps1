# aggiungi-spectre.ps1 -- Claude 03/11/2026. Le librerie Spectre (servono alla build Release di WSL, /Qspectre): il
# .vsconfig di WSL usa gli identificativi VC.Tools.*.Spectre, che VS 17.14 non conosce e salta in silenzio.
$Host.UI.RawUI.WindowTitle = "Claude: librerie Spectre per Visual Studio"
Start-Transcript -Path C:\claude\aggiungi-spectre.log -Force | Out-Null
$vsi = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
$vw = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$id = @("Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre", "Microsoft.VisualStudio.Component.VC.Runtimes.ARM64.Spectre")
Write-Host "[claude] aggiungo: $($id -join ', ')" -ForegroundColor Cyan
$a = @("modify", "--installPath", "`"C:\Program Files\Microsoft Visual Studio\2022\Community`"", "--passive", "--norestart")
foreach ($x in $id) { $a += @("--add", $x) }
$p = Start-Process -FilePath $vsi -ArgumentList $a -Wait -PassThru
Write-Host "modify: codice $($p.ExitCode)"
foreach ($x in $id) { $r = & $vw -all -requires $x -format value -property instanceId; Write-Host ("{0} {1}" -f $(if ($r) { "SI'" } else { "no " }), $x) }
Get-ChildItem "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC" | ForEach-Object { Write-Host "$($_.Name) spectre: $((Get-ChildItem "$($_.FullName)\lib\spectre" -ErrorAction SilentlyContinue | ForEach-Object Name) -join ',')" }
if ($p.ExitCode -in 0, 3010) { Write-Host "ESITO: OK" -ForegroundColor Green } else { Write-Host "ESITO: FERMATO" -ForegroundColor Red }
Stop-Transcript | Out-Null
Start-Sleep 20
