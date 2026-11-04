# ferma-attivita.ps1 -- Claude 04/11/2026. Le attivita' Claude* create con "/sc once /st 23:59" sono partite TUTTE da sole
# alle 23:59 del 03/11. Le ferma (prima le compilazioni, che stavano per sovrascrivere il wsl.msi patchato con uno non
# patchato), chiude cmake/MSBuild, poi le cancella. claude-wsl e claude-wsl-guardia (sessione precedente) restano.
$t = Get-ScheduledTask | Where-Object { $_.TaskName -clike 'Claude*' }
foreach ($n in 'ClaudeCompilaWSL', 'ClaudeCompilaWSLPatch') { Stop-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue }
Get-Process cmake, MSBuild, cl, link -ErrorAction SilentlyContinue | Stop-Process -Force
"compilazioni fermate; MSBuild rimasti: " + @(Get-Process MSBuild -ErrorAction SilentlyContinue).Count
foreach ($x in $t) { Stop-ScheduledTask -TaskName $x.TaskName -ErrorAction SilentlyContinue }
Start-Sleep 3
foreach ($x in $t) { Unregister-ScheduledTask -TaskName $x.TaskName -Confirm:$false; "cancellata " + $x.TaskName }
'--- restano: ' + ((Get-ScheduledTask | Where-Object { $_.TaskName -like 'claude*' } | ForEach-Object TaskName) -join ', ')
'--- msi nel build: ' + (Get-Item C:\claude\src\WSL\bin\x64\Debug\wsl.msi | ForEach-Object { '{0} {1:N1} MB' -f $_.LastWriteTime, ($_.Length/1MB) })
'--- vmwp: ' + @(Get-Process vmwp -ErrorAction SilentlyContinue).Count + ', powershell: ' + @(Get-Process powershell -ErrorAction SilentlyContinue).Count
