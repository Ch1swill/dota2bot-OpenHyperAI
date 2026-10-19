param(
    [Parameter(Mandatory = $true)]
    [string]$DotaRoot,
    [switch]$CreateDesktopShortcut
)

$ErrorActionPreference = 'Stop'
if ($CreateDesktopShortcut) {
    throw 'Automatic addon launch is disabled after a reported global hotkey reset. Restore and back up the complete personal settings before further native testing.'
}
$taskDotaRoot = [IO.Path]::GetFullPath($DotaRoot).TrimEnd('\')
$taskExecutable = Join-Path $taskDotaRoot 'game\bin\win64\dota2.exe'
if (-not (Test-Path -LiteralPath $taskExecutable -PathType Leaf)) {
    throw 'DotaRoot must be the installed dota 2 beta directory.'
}
$taskSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\addons\ch1_inventory_lab'))
$taskAddons = Join-Path $taskDotaRoot 'game\dota_addons'
$taskTarget = Join-Path $taskAddons 'ch1_inventory_lab'
foreach ($taskPath in @($taskAddons, $taskTarget)) {
    if ((Test-Path -LiteralPath $taskPath) -and ((Get-Item -LiteralPath $taskPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Refusing to install through a linked directory: $taskPath"
    }
}
$taskBackup = $null
if (Test-Path -LiteralPath $taskTarget) {
    $taskBackupRoot = Join-Path $taskDotaRoot 'game\ch1_addon_backups'
    $taskBackup = Join-Path $taskBackupRoot ('ch1_inventory_lab_' + [DateTime]::Now.ToString('yyyyMMdd_HHmmss') + '_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    [void][IO.Directory]::CreateDirectory($taskBackupRoot)
    Copy-Item -LiteralPath $taskTarget -Destination $taskBackup -Recurse
}
foreach ($taskFile in Get-ChildItem -LiteralPath $taskSource -File -Recurse) {
    $taskRelative = $taskFile.FullName.Substring($taskSource.Length + 1)
    $taskDestination = Join-Path $taskTarget $taskRelative
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($taskDestination))
    Copy-Item -LiteralPath $taskFile.FullName -Destination $taskDestination -Force
    if ((Get-FileHash -LiteralPath $taskFile.FullName).Hash -ne (Get-FileHash -LiteralPath $taskDestination).Hash) {
        throw "Addon copy verification failed: $taskRelative"
    }
}
[PSCustomObject]@{ addon = $taskTarget; backup = $taskBackup } | ConvertTo-Json -Compress
