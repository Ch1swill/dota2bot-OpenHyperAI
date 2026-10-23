$ErrorActionPreference = 'Stop'
$taskRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskSource = Join-Path $taskRepo 'addons\ch1_inventory_lab'
$taskInstaller = Join-Path $taskRepo 'tools\install-nine-slot-addon.ps1'
$taskFixture = Join-Path $taskRepo ('node_modules\.cache\ch1-addon-install-' + [Guid]::NewGuid().ToString('N'))
$taskProduction = Join-Path $taskFixture 'game\dota_addons\ch1_inventory_lab'
$taskSettings = Join-Path $taskFixture 'game\dota\cfg\personal-settings.txt'
[void][IO.Directory]::CreateDirectory((Join-Path $taskFixture 'game\bin\win64'))
[void][IO.Directory]::CreateDirectory($taskProduction)
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($taskSettings))
[IO.File]::WriteAllText((Join-Path $taskFixture 'game\bin\win64\dota2.exe'), 'fixture')
[IO.File]::WriteAllText((Join-Path $taskProduction 'sentinel.txt'), 'existing production addon')
[IO.File]::WriteAllText($taskSettings, 'all personal settings must survive')
$taskSettingsHash = (Get-FileHash -LiteralPath $taskSettings).Hash

function Assert-Preserved {
    if ((Get-Content -LiteralPath (Join-Path $taskProduction 'sentinel.txt') -Raw) -ne 'existing production addon' -or
        @(Get-ChildItem -LiteralPath $taskProduction -File -Recurse).Count -ne 1) {
        throw 'Independent test deployment changed the production addon'
    }
    if ((Get-FileHash -LiteralPath $taskSettings).Hash -ne $taskSettingsHash) {
        throw 'Independent test deployment changed personal settings'
    }
}

$taskResult = & $taskInstaller -DotaRoot $taskFixture -TestOnly | ConvertFrom-Json
if ($taskResult.command -ne 'dota_launch_custom_game ch1_inventory_turbo_test dota') {
    throw 'Wrong independent test launch command'
}
foreach ($taskFile in Get-ChildItem -LiteralPath $taskSource -File -Recurse) {
    $taskRelative = $taskFile.FullName.Substring($taskSource.Length + 1)
    if ((Get-FileHash -LiteralPath (Join-Path $taskResult.addon $taskRelative)).Hash -ne (Get-FileHash -LiteralPath $taskFile.FullName).Hash) {
        throw "Test addon differs from source: $taskRelative"
    }
}
Assert-Preserved
Write-Output 'PASS test deployment copies source and preserves production and settings'

$taskCandidateSentinel = Join-Path $taskResult.addon 'addoninfo.txt'
[IO.File]::WriteAllText($taskCandidateSentinel, 'previous test revision')
$taskPreviousHash = (Get-FileHash -LiteralPath $taskCandidateSentinel).Hash
$taskResult = & $taskInstaller -DotaRoot $taskFixture -TestOnly | ConvertFrom-Json
if ((Get-FileHash -LiteralPath (Join-Path $taskResult.backup 'addoninfo.txt')).Hash -ne $taskPreviousHash) {
    throw 'Repeat test deployment did not preserve its previous revision'
}
Assert-Preserved
Write-Output 'PASS repeat test deployment backs up only the previous test revision'

$taskRejected = $false
try { & $taskInstaller -DotaRoot $taskFixture -TestOnly -CreateDesktopShortcut | Out-Null }
catch { $taskRejected = $true }
if (-not $taskRejected) { throw 'Automatic launch was unexpectedly enabled' }
Assert-Preserved
Write-Output 'PASS automatic launch remains disabled before any deployment'
