$Username = "$env:USERDOMAIN`\$env:USERNAME"
$right = "SeCreateSymbolicLinkPrivilege"

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
    return
}

$tempPath = [System.IO.Path]::GetTempPath()
$import = Join-Path -Path $tempPath -ChildPath "import.inf"
if (Test-Path $import) { Remove-Item -Path $import -Force }
$export = Join-Path -Path $tempPath -ChildPath "export.inf"
if (Test-Path $export) { Remove-Item -Path $export -Force }
$secedt = Join-Path -Path $tempPath -ChildPath "secedt.sdb"
if (Test-Path $secedt) { Remove-Item -Path $secedt -Force }
$Error.Clear()

if ($Username -match "^S-.*-.*-.*$|^S-.*-.*-.*-.*-.*-.*$|^S-.*-.*-.*-.*-.*$|^S-.*-.*-.*-.*$") {
    $sid = $Username
}
else {
    $sid = ((New-Object System.Security.Principal.NTAccount($Username)).Translate([System.Security.Principal.SecurityIdentifier])).Value
}
secedit /export /cfg $export | Out-Null
$sids = (Select-String $export -Pattern "$right").Line
if ($null -eq $sids) {
    $sids = "$right = *$sid"
    $sidList = $sids
}
else {
    $sidList = "$sids,*$sid"
}
foreach ($line in @("[Unicode]", "Unicode=yes", "[System Access]", "[Event Audit]", "[Registry Values]", "[Version]", "signature=`"`$CHICAGO$`"", "Revision=1", "[Profile Description]", "Description=$ActionType `"$right`" right fouser account: $Username", "[Privilege Rights]", "$sidList")) {
    Add-Content $import $line
}
    
secedit /import /db $secedt /cfg $import | Out-Null
secedit /configure /db $secedt | Out-Null
gpupdate /force | Out-Null

Remove-Item -Path $import -Force | Out-Null
Remove-Item -Path $export -Force | Out-Null
Remove-Item -Path $secedt -Force | Out-Null
