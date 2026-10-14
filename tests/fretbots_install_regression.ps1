# Run from PowerShell: .\tests\fretbots_install_regression.ps1
$ErrorActionPreference = 'Stop'
$taskRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskFixture = Join-Path $taskRepo ('node_modules\.cache\fretbots-install-test-' + [Guid]::NewGuid().ToString('N'))
$taskGame = Join-Path $taskFixture 'game\dota\scripts\vscripts\game'
$taskBin = Join-Path $taskFixture 'game\bin\win64'
[void](New-Item -ItemType Directory -Path $taskGame, $taskBin)
[IO.File]::WriteAllText((Join-Path $taskBin 'dota2.exe'), 'test fixture')
$taskInit = Join-Path $taskGame 'gameinit.lua'
$taskLoader = Join-Path $taskGame 'ch1_fretbots_autostart.lua'
$taskPattern = '(?s)-- BEGIN OHA\.Ch1 FretBots autostart\r?\n.*?-- END OHA\.Ch1 FretBots autostart'
$taskOriginal = "-- Existing Valve bindings and installation-specific additions`r`nfunction HasBaseClass(a, b) return a == b end`r`n"
[IO.File]::WriteAllText($taskInit, $taskOriginal, [Text.UTF8Encoding]::new($false))
[void](New-Item -ItemType Directory -Path (Join-Path $taskGame 'Customize'))
$taskCustomize = Join-Path $taskGame 'Customize\general.lua'
[IO.File]::WriteAllText($taskCustomize, 'return {Fretbots = {Default_Difficulty = 6}}')
$taskCustomizeHash = (Get-FileHash -LiteralPath $taskCustomize).Hash

$taskFirst = & (Join-Path $taskRepo 'tools\install-fretbots-autostart.ps1') -DotaRoot $taskFixture | ConvertFrom-Json
$taskInstalled = [IO.File]::ReadAllText($taskInit)
if (-not $taskInstalled.StartsWith($taskOriginal, [StringComparison]::Ordinal)) { throw 'Original initialization code was modified.' }
if ([regex]::Matches($taskInstalled, $taskPattern).Count -ne 1) { throw 'First installation did not add exactly one hook.' }
if ($taskInstalled.Replace("`r`n", '').Contains("`n")) { throw 'Original CRLF style was not preserved.' }
if ([IO.File]::ReadAllText((Join-Path $taskFirst.backup 'gameinit.lua')) -cne $taskOriginal) { throw 'Original initialization backup is incorrect.' }
$taskSourceLoader = Join-Path $taskRepo 'game\ch1_fretbots_autostart.lua'
if ((Get-FileHash -LiteralPath $taskLoader).Hash -ne (Get-FileHash -LiteralPath $taskSourceLoader).Hash) { throw 'Loader copy is incorrect.' }
Write-Output 'PASS installer preserves existing bindings, line endings, and backup'

$taskSecond = & (Join-Path $taskRepo 'tools\install-fretbots-autostart.ps1') -DotaRoot $taskFixture | ConvertFrom-Json
if ([IO.File]::ReadAllText($taskInit) -cne $taskInstalled) { throw 'Repeated installation changed the initialization script.' }
if ($taskFirst.backup -eq $taskSecond.backup) { throw 'Repeated installation reused a backup.' }
if ((Get-FileHash -LiteralPath (Join-Path $taskSecond.backup 'ch1_fretbots_autostart.lua')).Hash -ne (Get-FileHash -LiteralPath $taskSourceLoader).Hash) { throw 'Existing loader backup is incorrect.' }
Write-Output 'PASS repeated installation keeps one hook and creates a new backup'

$taskOldHook = "-- BEGIN OHA.Ch1 FretBots autostart`r`n-- obsolete hook`r`n-- END OHA.Ch1 FretBots autostart"
$taskOldInit = $taskOriginal + $taskOldHook + "`r`n-- preserve code after the hook`r`n"
[IO.File]::WriteAllText($taskInit, $taskOldInit, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($taskLoader, '-- obsolete loader')
$taskThird = & (Join-Path $taskRepo 'tools\install-fretbots-autostart.ps1') -DotaRoot $taskFixture | ConvertFrom-Json
$taskUpdated = [IO.File]::ReadAllText($taskInit)
if (-not $taskUpdated.StartsWith($taskOriginal, [StringComparison]::Ordinal) -or -not $taskUpdated.EndsWith("-- preserve code after the hook`r`n", [StringComparison]::Ordinal)) { throw 'Hook update modified surrounding code.' }
if ($taskUpdated.Contains('obsolete hook') -or [regex]::Matches($taskUpdated, $taskPattern).Count -ne 1) { throw 'Existing hook was not replaced.' }
if ([IO.File]::ReadAllText((Join-Path $taskThird.backup 'ch1_fretbots_autostart.lua')) -cne '-- obsolete loader') { throw 'Existing loader was not backed up.' }
if ((Get-FileHash -LiteralPath $taskLoader).Hash -ne (Get-FileHash -LiteralPath $taskSourceLoader).Hash) { throw 'Existing loader was not updated.' }
Write-Output 'PASS installer updates an older hook and loader while preserving surrounding code'

if ((Get-FileHash -LiteralPath $taskCustomize).Hash -ne $taskCustomizeHash) { throw 'Installer modified custom difficulty settings.' }
Write-Output 'PASS installer preserves custom difficulty settings'
Write-Output 'FretBots installer regression: 4 passed, 0 failed'
