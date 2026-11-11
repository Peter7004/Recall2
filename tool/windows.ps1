param(
    [ValidateSet('Check', 'NativeSmoke', 'Test', 'Analyze', 'ApkDebug', 'Web')][string]$Action = 'Check',
    [string]$FlutterSdk = 'C:/Users/Public/Recall-windows-sdk',
    [string]$Stage = 'C:/Users/Public/Recall-windows-build'
)

# Keep Unicode/OneDrive sources untouched; compile an exact, owned ASCII copy.
# No machine environment, signing key, or production installation is modified.
$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Stage = [IO.Path]::GetFullPath($Stage)
if ($Stage -match '[^\x20-\x7e]' -or $Stage -eq $sourceRoot) { throw 'Stage must be a separate physical ASCII directory.' }
$marker = Join-Path $Stage '.recall-source-root'
if (Test-Path $Stage) {
    if (-not (Test-Path $marker) -or [IO.File]::ReadAllText($marker) -ne $sourceRoot) {
        throw "Stage is not owned by this project: $Stage"
    }
} else {
    New-Item -ItemType Directory -Path $Stage | Out-Null
    [IO.File]::WriteAllText($marker, $sourceRoot)
}
foreach ($path in @($Stage, $FlutterSdk, 'C:/Users/Public/Recall-gradle-toolchain/user-home')) {
    if ((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Use a physical directory, not a junction: $path"
    }
}
$manifestPath = Join-Path $Stage '.recall-source-manifest.json'
$previousFiles = if (Test-Path $manifestPath) { @(Get-Content $manifestPath -Raw | ConvertFrom-Json) } else { @() }
$files = @('pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml')
foreach ($folder in @('lib', 'test', 'assets', 'web', 'android', 'tool')) {
    $files += Get-ChildItem -LiteralPath (Join-Path $sourceRoot $folder) -File -Recurse -Force |
        Where-Object {
            $_.FullName -notmatch '[\\/](build|\.gradle|\.dart_tool|\.git)[\\/]' -and
            $_.Name -notmatch '\uBCF5\uC0AC\uBCF8|\.jks$|\.keystore$|\.p12$|\.pfx$|^key\.properties$|^local\.properties$'
        } | ForEach-Object { $_.FullName.Substring($sourceRoot.Length + 1) }
}
$files = @($files | Sort-Object -Unique)
foreach ($relative in $files) {
    $from = Join-Path $sourceRoot $relative
    $to = [IO.Path]::GetFullPath((Join-Path $Stage $relative))
    if (-not $to.StartsWith($Stage + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid staging path.' }
    New-Item -ItemType Directory -Force -Path (Split-Path $to) | Out-Null
    if (-not (Test-Path $to) -or (Get-FileHash $from).Hash -ne (Get-FileHash $to).Hash) {
        Copy-Item -LiteralPath $from -Destination $to
    }
}
# Remove only files previously recorded by this runner; never clear build caches.
foreach ($relative in $previousFiles) {
    if ($relative -in $files) { continue }
    $to = [IO.Path]::GetFullPath((Join-Path $Stage $relative))
    if (-not $to.StartsWith($Stage + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid old manifest.' }
    if (Test-Path -LiteralPath $to -PathType Leaf) { Remove-Item -LiteralPath $to }
}
[IO.File]::WriteAllText($manifestPath, (ConvertTo-Json -InputObject $files))
[IO.File]::WriteAllText((Join-Path $Stage 'android/local.properties'), "flutter.sdk=$FlutterSdk`nsdk.dir=C:/Users/Public/Recall-windows-android-sdk`n")
$temp = Join-Path $Stage 'build/windows-temp'
New-Item -ItemType Directory -Force $temp | Out-Null
$updates = @{
    JAVA_HOME = 'C:/Users/Public/Recall-windows-jdk'
    ANDROID_HOME = 'C:/Users/Public/Recall-windows-android-sdk'
    ANDROID_SDK_ROOT = 'C:/Users/Public/Recall-windows-android-sdk'
    GRADLE_USER_HOME = 'C:/Users/Public/Recall-gradle-toolchain/user-home'
    PUB_CACHE = 'C:/Users/Public/Recall-windows-pub-cache'
    TEMP = $temp; TMP = $temp
    RECALL_TEST_BUILD = 'true'
}
$previous = @{}
foreach ($name in $updates.Keys) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    [Environment]::SetEnvironmentVariable($name, $updates[$name], 'Process')
}
$code = 0
Push-Location $Stage
try {
    & "$FlutterSdk/bin/flutter.bat" pub get --offline
    if ($LASTEXITCODE -ne 0) { throw 'Dependency preparation failed.' }
    if ($Action -in @('Check', 'NativeSmoke', 'Test', 'Analyze')) {
        & ./tool/recall-windows.ps1 -Action $Action -FlutterSdk $FlutterSdk
        $code = $LASTEXITCODE
    } elseif ($Action -eq 'Web') {
        & "$FlutterSdk/bin/flutter.bat" build web --release --no-pub --no-wasm-dry-run
        $code = $LASTEXITCODE
    } else {
        & "$FlutterSdk/bin/flutter.bat" build apk --debug --no-pub
        $code = $LASTEXITCODE
        if ($code -eq 0) {
            $output = Join-Path $sourceRoot 'build/windows/Recall-debug.apk'
            New-Item -ItemType Directory -Force (Split-Path $output) | Out-Null
            Copy-Item build/app/outputs/flutter-apk/app-debug.apk $output
            Write-Output "Local test APK (separate from production app): $output"
        }
    }
} finally {
    Pop-Location
    foreach ($name in $previous.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
}
exit $code
