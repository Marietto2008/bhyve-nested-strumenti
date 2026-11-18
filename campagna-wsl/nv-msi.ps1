param([string]$Id, [int]$Valore)
$k = "HKLM:\SYSTEM\CurrentControlSet\Enum\$Id\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
if ($Valore -ge 0) { New-Item -Path $k -Force | Out-Null; Set-ItemProperty -Path $k -Name MSISupported -Value $Valore -Type DWord }
else { Remove-ItemProperty -Path $k -Name MSISupported -ErrorAction SilentlyContinue }
"MSISupported ora: " + (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue).MSISupported
pnputil /restart-device "$Id" | Out-Null
Start-Sleep 6
$pc = (Get-PnpDeviceProperty -InstanceId $Id -KeyName DEVPKEY_Device_ProblemCode).Data
$ps = (Get-PnpDeviceProperty -InstanceId $Id -KeyName DEVPKEY_Device_ProblemStatus -ErrorAction SilentlyContinue).Data
"problema $pc NTSTATUS 0x{0:X8}" -f $ps
