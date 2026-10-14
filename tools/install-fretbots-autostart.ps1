param(
    [Parameter(Mandatory = $true)]
    [string]$DotaRoot
)

$ErrorActionPreference = 'Stop'
$taskDotaRoot = [IO.Path]::GetFullPath($DotaRoot).TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $taskDotaRoot 'game\bin\win64\dota2.exe') -PathType Leaf)) {
    throw 'DotaRoot must be the installed dota 2 beta directory.'
}
$taskScripts = [IO.Path]::GetFullPath((Join-Path $taskDotaRoot 'game\dota\scripts\vscripts'))
$taskGame = Join-Path $taskScripts 'game'
$taskInit = Join-Path $taskGame 'gameinit.lua'
$taskLoader = Join-Path $taskGame 'ch1_fretbots_autostart.lua'
foreach ($taskDirectory in @($taskScripts, $taskGame)) {
    $taskItem = Get-Item -LiteralPath $taskDirectory -Force
    if (-not $taskItem.PSIsContainer -or ($taskItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Unexpected scripts directory: $taskDirectory"
    }
}
foreach ($taskPath in @($taskInit, $taskLoader)) {
    if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($taskPath)) -ine $taskGame) {
        throw 'A deployment path escaped the game scripts directory.'
    }
    if ((Test-Path -LiteralPath $taskPath) -and ((Get-Item -LiteralPath $taskPath).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Refusing to overwrite a linked script: $taskPath"
    }
}

$taskRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskSourceLoader = Join-Path $taskRepo 'game\ch1_fretbots_autostart.lua'
$taskSourceInit = [IO.File]::ReadAllText((Join-Path $taskRepo 'game\gameinit.lua'))
$taskPattern = '(?s)-- BEGIN OHA\.Ch1 FretBots autostart\r?\n.*?-- END OHA\.Ch1 FretBots autostart'
$taskHook = [regex]::Match($taskSourceInit, $taskPattern)
if (-not $taskHook.Success) { throw 'The repository autostart hook is missing.' }
$taskOldInit = [IO.File]::ReadAllText($taskInit)
$taskNewline = if ($taskOldInit.Contains("`r`n")) { "`r`n" } else { "`n" }
$taskNormalizedHook = $taskHook.Value -replace '\r?\n', $taskNewline
if ([regex]::IsMatch($taskOldInit, $taskPattern)) {
    $taskNewInit = [regex]::Replace($taskOldInit, $taskPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($taskMatch) $taskNormalizedHook })
} else {
    $taskNewInit = $taskOldInit + $taskNewline + $taskNewline + $taskNormalizedHook + $taskNewline
}

$taskTimestamp = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, [TimeZoneInfo]::FindSystemTimeZoneById('Singapore Standard Time')).ToString('yyyyMMdd_HHmmss') + '_' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$taskBackup = [IO.Path]::GetFullPath((Join-Path $taskScripts "fretbots_autostart_backup_$taskTimestamp"))
if ([IO.Path]::GetDirectoryName($taskBackup) -ine $taskScripts -or (Test-Path -LiteralPath $taskBackup)) {
    throw 'Invalid backup path.'
}
[void](New-Item -Path $taskBackup -ItemType Directory)
$taskInitHash = (Get-FileHash -LiteralPath $taskInit).Hash
Copy-Item -LiteralPath $taskInit -Destination (Join-Path $taskBackup 'gameinit.lua')
if ((Get-FileHash -LiteralPath (Join-Path $taskBackup 'gameinit.lua')).Hash -ne $taskInitHash) {
    throw 'The original gameinit backup failed verification.'
}
$taskHadLoader = Test-Path -LiteralPath $taskLoader
if ($taskHadLoader) {
    $taskLoaderHash = (Get-FileHash -LiteralPath $taskLoader).Hash
    Copy-Item -LiteralPath $taskLoader -Destination (Join-Path $taskBackup 'ch1_fretbots_autostart.lua')
    if ((Get-FileHash -LiteralPath (Join-Path $taskBackup 'ch1_fretbots_autostart.lua')).Hash -ne $taskLoaderHash) {
        throw 'The existing loader backup failed verification.'
    }
}

try {
    Copy-Item -LiteralPath $taskSourceLoader -Destination $taskLoader -Force
    [IO.File]::WriteAllText($taskInit, $taskNewInit, [Text.UTF8Encoding]::new($false))
    if ((Get-FileHash -LiteralPath $taskSourceLoader).Hash -ne (Get-FileHash -LiteralPath $taskLoader).Hash) {
        throw 'Autostart script copy verification failed.'
    }
    if ([IO.File]::ReadAllText($taskInit) -cne $taskNewInit) { throw 'The gameinit hook did not persist.' }
} catch {
    Copy-Item -LiteralPath (Join-Path $taskBackup 'gameinit.lua') -Destination $taskInit -Force
    if ($taskHadLoader) { Copy-Item -LiteralPath (Join-Path $taskBackup 'ch1_fretbots_autostart.lua') -Destination $taskLoader -Force }
    elseif (Test-Path -LiteralPath $taskLoader -PathType Leaf) { Remove-Item -LiteralPath $taskLoader }
    throw
}

[PSCustomObject]@{installed_hook = $taskInit; installed_loader = $taskLoader; backup = $taskBackup} | ConvertTo-Json -Compress
