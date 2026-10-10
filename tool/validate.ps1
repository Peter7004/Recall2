param(
    [switch]$BuildWeb,
    [string]$ValidationRoot = "$env:SystemDrive\codex-work\recall-validation"
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$validationBase = [IO.Path]::GetFullPath($ValidationRoot).TrimEnd('\')
$validationPath = Join-Path $validationBase (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
if ($validationPath -match '[^\x00-\x7F]' -or $validationBase -eq $projectRoot -or
    $validationBase.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Use a separate ASCII-only validation directory.'
}
$runtimeRoot = Split-Path -Parent $validationPath
$tempPath = Join-Path $runtimeRoot 'recall-temp'
$sdkPath = Split-Path -Parent (Split-Path -Parent (Get-Command flutter.bat).Source)
$sdkLink = Join-Path $runtimeRoot 'recall-flutter-sdk'
$cachePath = if ($env:PUB_CACHE) { $env:PUB_CACHE } else { Join-Path $env:LOCALAPPDATA 'Pub\Cache' }
$cacheLink = Join-Path $runtimeRoot 'recall-pub-cache'
New-Item -ItemType Directory -Path $validationPath, $tempPath -Force | Out-Null
foreach ($link in @(@{ Path = $sdkLink; Target = $sdkPath }, @{ Path = $cacheLink; Target = $cachePath })) {
    if (-not (Test-Path -LiteralPath $link.Path)) {
        New-Item -ItemType Junction -Path $link.Path -Target $link.Target | Out-Null
    }
}

foreach ($directory in @('lib', 'test', 'web')) {
    $sourceDirectory = Join-Path $projectRoot $directory
    foreach ($file in Get-ChildItem -LiteralPath $sourceDirectory -File -Recurse) {
        if ($file.Name -match ' - \uBCF5\uC0AC\uBCF8') { continue }
        $relativePath = $file.FullName.Substring($projectRoot.Length + 1)
        $destination = Join-Path $validationPath $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    }
}
foreach ($file in @('pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $validationPath -Force
}

$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$previousCache = $env:PUB_CACHE
$flutterExecutable = Join-Path $sdkLink 'bin\flutter.bat'
function Invoke-FlutterCheck([string[]]$Arguments) {
    & $flutterExecutable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter command failed: $($Arguments -join ' ')" }
}
Push-Location -LiteralPath $validationPath
try {
    $env:TEMP = $tempPath
    $env:TMP = $tempPath
    $env:PUB_CACHE = $cacheLink
    Invoke-FlutterCheck -Arguments @('pub', 'get')
    Invoke-FlutterCheck -Arguments @('analyze')
    Invoke-FlutterCheck -Arguments @('test', '--concurrency=1')
    if ($BuildWeb) { Invoke-FlutterCheck -Arguments @('build', 'web', '--release') }
    Write-Output "Validated source copy: $validationPath"
} finally {
    Pop-Location
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    $env:PUB_CACHE = $previousCache
}
