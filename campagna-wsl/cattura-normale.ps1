# cattura-schermo.ps1 -- Claude 03/11/2026. Foto dello schermo della sessione interattiva (va lanciato con schtasks /it)
# in C:\claude\schermo-normale.png, piu' l'elenco delle finestre visibili in C:\claude\finestre.txt.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$b = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)  # senza CaptureBlt (per confronto)
$bmp.Save("C:\claude\schermo-normale.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Get-Process | Where-Object { $_.MainWindowTitle } | ForEach-Object { "{0} {1}: {2}" -f $_.ProcessName, $_.Id, $_.MainWindowTitle } |
    Out-File -Encoding utf8 C:\claude\finestre.txt
