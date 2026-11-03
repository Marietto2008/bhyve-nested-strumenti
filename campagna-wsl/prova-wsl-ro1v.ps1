# prova-wsl-ro1v.ps1 -- Claude 03/11/2026. Come prova-wsl-ro1.ps1 ma con avvio VERBOSO (il non verboso si ferma dopo vtcon0).
& C:\claude\prova-wsl-fbsd.ps1 -SystemDistro "C:\\claude\\wsl-fbsd\\fbsd152-wsl-ro1.vhd" -Riga "console=comconsole rootdev=disk0p4: boot_verbose=YES"
