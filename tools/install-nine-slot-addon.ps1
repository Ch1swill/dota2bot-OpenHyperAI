param(
    [Parameter(Mandatory = $true)]
    [string]$DotaRoot,
    [switch]$CreateDesktopShortcut,
    [string]$SteamExe
)

$ErrorActionPreference = 'Stop'
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
$taskShortcut = $null
if ($CreateDesktopShortcut) {
    if (-not $SteamExe) {
        $SteamExe = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -Name SteamExe).SteamExe
    }
    $taskSteamExe = [IO.Path]::GetFullPath($SteamExe)
    if (-not (Test-Path -LiteralPath $taskSteamExe -PathType Leaf)) {
        throw 'Steam.exe was not found; specify -SteamExe.'
    }
    $taskShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Open Hyper AI Ch1 - 真人九格.lnk'
    $taskShell = New-Object -ComObject WScript.Shell
    $taskLink = $taskShell.CreateShortcut($taskShortcut)
    # Let Steam apply the user's launch options, regional client and Cloud profile.
    $taskLink.TargetPath = $taskSteamExe
    $taskLink.WorkingDirectory = [IO.Path]::GetDirectoryName($taskSteamExe)
    $taskLink.Arguments = '-applaunch 570 +dota_per_unit_keybindings_disabled_during_custom_games 0 +dota_launch_custom_game ch1_inventory_lab dota'
    $taskLink.IconLocation = $taskExecutable + ',0'
    $taskLink.Description = 'Exit Dota 2 first, then open the human-only nine-slot custom map.'
    $taskLink.Save()
}
[PSCustomObject]@{ addon = $taskTarget; backup = $taskBackup; shortcut = $taskShortcut } | ConvertTo-Json -Compress
