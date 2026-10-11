# Integrity checking is not a digital signature; obtain the ZIP from a trusted source.
$ErrorActionPreference = 'Stop'
try {
    $required = @('DisasterParty.exe', 'DisasterParty.pck', 'BUILD.txt', 'PLAYTEST.txt', 'Play.cmd', 'Verify-Package.ps1')
    $seen = @{}
    foreach ($line in Get-Content -LiteralPath (Join-Path $PSScriptRoot 'SHA256SUMS.txt')) {
        if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { throw 'Invalid checksum manifest.' }
        $digest = $Matches[1]
        $name = $Matches[2]
        if ($name -cnotin $required -or $seen.ContainsKey($name)) { throw 'Unexpected or duplicate manifest entry.' }
        $seen[$name] = $true
        $actual = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $name) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne $digest) { throw "Checksum mismatch: $name" }
    }
    if ($seen.Count -ne $required.Count) { throw 'Incomplete checksum manifest.' }
    # Fail before launching if the package directory cannot hold the runtime log.
    $probe = Join-Path $PSScriptRoot ([System.IO.Path]::GetRandomFileName())
    [System.IO.File]::WriteAllText($probe, '')
    Remove-Item -LiteralPath $probe
    Write-Output 'PACKAGE_INTEGRITY_OK'
    exit 0
} catch {
    Write-Output "Package verification failed: $($_.Exception.Message)"
    Write-Output 'Re-extract the complete ZIP into a writable local folder. Do not mix builds or run inside the ZIP.'
    exit 1
}
