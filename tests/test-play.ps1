param([string]$Launcher = "$PSScriptRoot\..\scripts\play.ps1")

$ErrorActionPreference = "Stop"
$root = Join-Path ([IO.Path]::GetTempPath()) ("victory launcher [" + [guid]::NewGuid() + "]")
[void][IO.Directory]::CreateDirectory($root)
$exe = Join-Path $root "fake.cmd"
$game = Join-Path $root "test title.exe"
$log = Join-Path $root "logs\first run.log"
[IO.File]::WriteAllText($game, "")
[IO.File]::WriteAllLines($exe, @(
    "@echo off", "echo arg1=%~1", "echo arg2=%~2", "echo arg3=%~3",
    "echo cache=%VICTORY_CACHE_DIR%", "echo data=%VICTORY_DATA_DIR%",
    "if defined VICTORY_KEYS exit /b 99", "echo fake stderr 1>&2", "exit /b 23"
))
$original = $env:VICTORY_KEYS
try {
    $env:VICTORY_KEYS = "fixture"
    $options = @{ Game=$game; Exe=$exe; Cache=(Join-Path $root "cache"); Data=(Join-Path $root "data"); Log=$log }
    & $Launcher @options
    if ($LASTEXITCODE -ne 23) { throw "Expected runtime exit code 23, got $LASTEXITCODE" }
    if ($env:VICTORY_KEYS -ne "fixture") { throw "Launcher changed the caller's environment" }
    $lines = Get-Content -LiteralPath $log
    foreach ($expected in "arg1=run","arg2=$game","arg3=--execute","cache=$($options.Cache)","data=$($options.Data)") {
        if ($expected -notin $lines) { throw "Missing log line: $expected" }
    }
    if (-not ($lines -match "fake stderr")) { throw "Missing stderr" }
    $message = $null
    try { & $Launcher @options -ErrorAction Stop } catch { $message = $_ }
    if (-not $message) { throw "Launcher overwrote an existing log" }
    $options.Game = Join-Path $root "missing.exe"
    $message = $null
    try { & $Launcher @options } catch { $message = $_ }
    if ("$message" -notlike "File not found:*") { throw "Missing input was not diagnosed" }
} finally {
    [Environment]::SetEnvironmentVariable("VICTORY_KEYS", $original)
    [IO.Directory]::Delete($root, $true)
}
Write-Output "Launcher smoke test passed"
exit 0
