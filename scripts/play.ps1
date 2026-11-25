param(
    [Parameter(Mandatory = $true)][string]$Game,
    [switch]$Fast,
    [string]$Cache = "$env:LOCALAPPDATA\ztrx\cache",
    [string]$Data = "$env:LOCALAPPDATA\ztrx\data",
    [string]$Exe = "$PSScriptRoot\..\target\release\victory.exe",
    [string]$Log = "$env:TEMP\ztrx-$(Get-Date -Format 'yyyyMMdd-HHmmss-fffffff')-$PID.log"
)

$ErrorActionPreference = 'Stop'
foreach ($file in @($Exe, $Game)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "File not found: $file"
    }
}
$exePath = (Get-Item -LiteralPath $Exe).FullName
$runtime = $exePath
if ($PSVersionTable.PSVersion.Major -le 5) {
    $runtime = Get-Command -Name ([WildcardPattern]::Escape($exePath)) -CommandType Application
}
$gamePath = (Get-Item -LiteralPath $Game).FullName
$cachePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Cache)
$dataPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Data)
$logPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Log)
[void][IO.Directory]::CreateDirectory($cachePath)
[void][IO.Directory]::CreateDirectory($dataPath)
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($logPath))

$settings = @{
    VICTORY_CACHE_DIR = $cachePath
    VICTORY_DATA_DIR = $dataPath
    VICTORY_KEYS = $null
    VICTORY_CAPTURE = $null
    VICTORY_CAPTURE_FRAMES = $null
    VICTORY_DUMP_TARGETS = $null
}
$saved = @{}
if ($Fast) {
    $settings.VICTORY_RELAY = '2'
    $settings.VICTORY_LATE_WAIT = '3'
}
try {
    foreach ($key in $settings.Keys) {
        $saved[$key] = [Environment]::GetEnvironmentVariable($key)
        [Environment]::SetEnvironmentVariable($key, $settings[$key])
    }
    Write-Host "Log: $logPath"
    $ErrorActionPreference = 'Continue'
    & $runtime run $gamePath --execute 2>&1 | Out-File -LiteralPath $logPath -Encoding utf8 -NoClobber -ErrorAction Stop
    $code = $LASTEXITCODE
} finally {
    foreach ($key in $saved.Keys) {
        [Environment]::SetEnvironmentVariable($key, $saved[$key])
    }
}
Write-Host "Exited with $code"
exit $code
