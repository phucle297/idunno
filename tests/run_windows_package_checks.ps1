param(
    [Parameter(Mandatory=$true)][string]$PackageDir,
    [Parameter(Mandatory=$true)][string]$GodotEditor,
    [Parameter(Mandatory=$true)][string]$OutputDir,
    [int]$Port = 29740
)
# External fixtures run against the exact shipped PCK, not the source project.
# This uses the native editor driver, NOT release-executable --script support.
$ErrorActionPreference = 'Stop'
$PackageDir = (Resolve-Path $PackageDir).Path
$GodotEditor = (Resolve-Path $GodotEditor).Path
if ($GodotEditor.StartsWith('\\')) { throw 'Copy the native editor to a Windows-local drive before running checks.' }
if (Test-Path $OutputDir) { throw 'Choose a fresh output directory.' }
New-Item -ItemType Directory $OutputDir | Out-Null
$OutputDir = (Resolve-Path $OutputDir).Path
$pack = Join-Path $PackageDir 'DisasterParty.pck'
$notes = Get-Content (Join-Path $PackageDir 'BUILD.txt') -Raw
$revision = [regex]::Match($notes, 'Source revision: ([0-9a-f]{40})').Groups[1].Value
if (-not $revision) { throw 'Missing build revision.' }
$versionProcess = Start-Process $GodotEditor -ArgumentList '--version' -PassThru -RedirectStandardOutput "$OutputDir\engine-version.txt"
$null = $versionProcess.Handle
$versionProcess.WaitForExit()
$version = (Get-Content "$OutputDir\engine-version.txt" -Raw).Trim()
if ($version -ne '4.7.2.stable.official.ed1daf0bf') { throw "Wrong fixture engine: $version" }
foreach ($line in Get-Content (Join-Path $PackageDir 'SHA256SUMS.txt')) {
    $parts = $line -split '\s+', 2
    $actual = (Get-FileHash (Join-Path $PackageDir $parts[1]) -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $parts[0]) { throw "Checksum mismatch: $($parts[1])" }
}
"Native editor-driver validation of exported PCK; not release-runtime or physical LAN evidence.`n$notes`n$version" | Set-Content (Join-Path $OutputDir 'evidence.txt')
function Start-Check($name, $fixture, $extra) {
    $script = Join-Path $PSScriptRoot $fixture
    $args = "--main-pack `"$pack`" --script `"$script`" --log-file `"$OutputDir\$name.log`" --windowed --resolution 1280x720 $extra"
    $p = Start-Process $GodotEditor -WorkingDirectory $PackageDir -ArgumentList $args -PassThru -RedirectStandardOutput "$OutputDir\$name.stdout" -RedirectStandardError "$OutputDir\$name.stderr"
    # Own the engine process directly, not the console-launcher wrapper.
    $null = $p.Handle
    return $p
}
function Finish-Check($process, $name, $marker) {
    if (-not $process.WaitForExit(90000)) {
        Stop-Process -Id $process.Id -Force
        throw "Timed out: $name"
    }
    $process.Refresh()
    $log = Get-Content "$OutputDir\$name.log" -Raw
    if ($process.ExitCode -ne 0 -or $log -notmatch $marker) { throw "Failed $name (exit $($process.ExitCode)): $log" }
    if ($log -notmatch "DISASTER_PARTY_BUILD revision=$revision") { throw "Wrong runtime identity: $name" }
    # Existing Dummy/audio shutdown resource diagnostics remain visible in logs.
    $errors = $log -split "`n" | Where-Object { $_ -match '^(SCRIPT ERROR|ERROR):' -and $_ -notmatch '^ERROR: [0-9]+ resources still in use at exit' }
    if ($errors) { throw "Runtime errors in ${name}: $errors" }
    Write-Output "$name $marker passed"
}
$settings = '-- --settings-path=user://windows-package-check.cfg'
$p = Start-Check 'settings-save' 'test_pause_settings.gd' "$settings --save-for-restart --capture-dir=`"$OutputDir`""
Finish-Check $p 'settings-save' 'PAUSE_SETTINGS_OK'
$p = Start-Check 'settings-restart' 'test_pause_settings.gd' "--headless $settings --verify-restart"
Finish-Check $p 'settings-restart' 'PAUSE_SETTINGS_OK checks=2'
$p = Start-Check 'recovery' 'test_session_lifecycle.gd' "$settings --capture-dir=`"$OutputDir`""
Finish-Check $p 'recovery' 'SESSION_LIFECYCLE_OK'
$server = Start-Check 'server' 'playable_scene_network_peer.gd' "--headless -- --settings-path=user://windows-package-host.cfg --role=server --port=$Port --host-port=$Port"
try {
    Start-Sleep -Milliseconds 500
    $client = Start-Check 'client' 'playable_scene_network_peer.gd' "-- --settings-path=user://windows-package-client.cfg --role=client --port=$Port --join-address=127.0.0.1 --join-port=$Port --capture=`"$OutputDir\client-overlap.png`""
    try { Finish-Check $client 'client' 'PLAYABLE_NETWORK_CLIENT_OK.*network_rematches=5' }
    finally { if (-not $client.HasExited) { Stop-Process -Id $client.Id -Force } }
    Finish-Check $server 'server' 'PLAYABLE_NETWORK_SERVER_OK.*network_rematches=5'
} finally { if (-not $server.HasExited) { Stop-Process -Id $server.Id -Force } }
Write-Output 'WINDOWS_EXPORTED_PCK_CHECKS_OK settings_restart=passed network_rematches=5 recovery=passed runtime=native_editor physical_lan=not_run'
