$src = @"
using System; using System.Runtime.InteropServices; using System.Text;
public static class Drv {
  [DllImport("psapi.dll")] public static extern bool EnumDeviceDrivers([Out] UIntPtr[] a, uint cb, out uint need);
  [DllImport("psapi.dll", CharSet=CharSet.Unicode)] public static extern uint GetDeviceDriverBaseNameW(UIntPtr b, StringBuilder n, uint sz);
}
"@
Add-Type $src
$need = 0; [Drv]::EnumDeviceDrivers($null, 0, [ref]$need) | Out-Null
$n = $need / 8; $a = New-Object UIntPtr[] $n
[Drv]::EnumDeviceDrivers($a, $need, [ref]$need) | Out-Null
$a | ForEach-Object { $sb = New-Object Text.StringBuilder 260; [Drv]::GetDeviceDriverBaseNameW($_, $sb, 260) | Out-Null; "{0:x16} {1}" -f $_.ToUInt64(), $sb } | Sort-Object
