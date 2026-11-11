param(
    [ValidateSet('Check', 'Env', 'Test', 'NativeSmoke', 'Analyze')][string]$Action = 'Check',
    [string]$MsvcRoot = 'C:/Users/Public/BeforeAfterAndroidToolchain/recall-native/msvc',
    [string]$FlutterSdk = 'C:/Users/Public/Recall-windows-sdk',
    [string]$PubCache = 'C:/Users/Public/Recall-windows-pub-cache',
    [string[]]$TestPath = @(),
    [string]$TestName
)

# Local native-test environment only. Does not install Visual Studio, change
# machine settings, patch Flutter/packages, or change Android/signing settings.
# Env deliberately leaves process variables set; other actions restore them.
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$auditRoot = Join-Path $projectRoot 'build/windows-toolchain-audit'
$MsvcRoot = [IO.Path]::GetFullPath($MsvcRoot)
if ($MsvcRoot -match '[^\x20-\x7e]|[%!"&|<>^]') {
    throw 'Use a plain ASCII portable MSVC path without cmd metacharacters.'
}
$msvcVersion = Get-ChildItem -LiteralPath (Join-Path $MsvcRoot 'VC/Tools/MSVC') -Directory |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1 -ExpandProperty Name
$sdkVersion = Get-ChildItem -LiteralPath (Join-Path $MsvcRoot 'Windows Kits/10/Include') -Directory |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1 -ExpandProperty Name
$compilerBin = Join-Path $MsvcRoot "VC/Tools/MSVC/$msvcVersion/bin/Hostx64/x64"
$sdkRoot = Join-Path $MsvcRoot 'Windows Kits/10'
foreach ($path in @(
    "$compilerBin/cl.exe", "$compilerBin/link.exe", "$compilerBin/lib.exe",
    "$MsvcRoot/VC/Tools/MSVC/$msvcVersion/include/vcruntime.h",
    "$sdkRoot/Include/$sdkVersion/um/Windows.h",
    "$sdkRoot/Include/$sdkVersion/ucrt/stdio.h",
    "$sdkRoot/Lib/$sdkVersion/um/x64/kernel32.lib",
    "$sdkRoot/Lib/$sdkVersion/ucrt/x64/ucrt.lib",
    "$FlutterSdk/bin/flutter.bat"
)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing prerequisite: $path" }
}

$shimDir = Join-Path $auditRoot 'portable-msvc-locator'
$tempDir = Join-Path $auditRoot 'temp'
$batchDir = Join-Path $MsvcRoot 'VC/Auxiliary/Build'
New-Item -ItemType Directory -Force -Path $shimDir, $tempDir, $batchDir | Out-Null
$include = "$MsvcRoot\VC\Tools\MSVC\$msvcVersion\include;$sdkRoot\Include\$sdkVersion\ucrt;$sdkRoot\Include\$sdkVersion\shared;$sdkRoot\Include\$sdkVersion\um;$sdkRoot\Include\$sdkVersion\winrt"
$lib = "$MsvcRoot\VC\Tools\MSVC\$msvcVersion\lib\x64;$sdkRoot\Lib\$sdkVersion\ucrt\x64;$sdkRoot\Lib\$sdkVersion\um\x64"
$batch = @"
@echo off
rem Recall portable x64 compiler environment; no Visual Studio registration.
set "PATH=$compilerBin;%PATH%"
set "INCLUDE=$include"
set "LIB=$lib"
set "VCToolsInstallDir=$MsvcRoot\VC\Tools\MSVC\$msvcVersion\"
set "VCToolsVersion=$msvcVersion"
set "WindowsSDKVersion=$sdkVersion\"
set "VSCMD_ARG_HOST_ARCH=x64"
set "VSCMD_ARG_TGT_ARCH=x64"
"@
[IO.File]::WriteAllText((Join-Path $batchDir 'vcvars64.bat'), ($batch -replace '\r?\n', "`r`n") + "`r`n", [Text.Encoding]::ASCII)

# native_toolchain_c 0.19.2 discovers MSVC through vswhere, not cl on PATH.
# This scoped adapter reports only the verified portable compiler directory.
# Flutter's system Visual Studio discovery is left unchanged. The adapter is
# visible only in this process/its children and identifies itself explicitly.
$locatorSource = @'
using System;
using System.IO;
using System.Text;
class RecallPortableMsvcLocator {
    static string Json(string s) { return "\"" + s.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\""; }
    static int Main(string[] args) {
        Console.OutputEncoding = new UTF8Encoding(false);
        if (args.Length == 0) {
            Console.WriteLine("Recall portable MSVC locator 1.0.0 (not a Visual Studio installation)");
            return 0;
        }
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string root = File.ReadAllText(Path.Combine(dir, "msvc-root.txt")).Trim();
        string version = File.ReadAllText(Path.Combine(dir, "msvc-version.txt")).Trim();
        string bin = Path.Combine(root, "VC", "Tools", "MSVC", version, "bin", "Hostx64", "x64");
        foreach (string exe in new string[] { "cl.exe", "link.exe", "lib.exe" }) {
            if (!File.Exists(Path.Combine(bin, exe))) { Console.Error.WriteLine("Missing portable " + exe); return 1; }
        }
        if (Array.IndexOf(args, "json") < 0) { Console.Error.WriteLine("Only JSON discovery is supported."); return 2; }
        Console.WriteLine("[{\"installationPath\":" + Json(root) + ",\"installationVersion\":" + Json(version) + ",\"displayName\":\"Recall portable MSVC toolset (not Visual Studio)\"}]");
        return 0;
    }
}
'@
$locatorCs = Join-Path $shimDir 'RecallPortableMsvcLocator.cs'
$locatorExe = Join-Path $shimDir 'vswhere.exe'
$oldSource = if (Test-Path -LiteralPath $locatorCs) { [IO.File]::ReadAllText($locatorCs) } else { '' }
if (-not (Test-Path -LiteralPath $locatorExe) -or $oldSource -ne $locatorSource) {
    [IO.File]::WriteAllText($locatorCs, $locatorSource)
    $csc = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    if (-not (Test-Path -LiteralPath $csc)) { throw "Missing .NET Framework C# compiler: $csc" }
    & $csc /nologo /target:exe "/out:$locatorExe" $locatorCs
    if ($LASTEXITCODE -ne 0) { throw 'Could not compile the portable compiler locator.' }
}
[IO.File]::WriteAllText((Join-Path $shimDir 'msvc-root.txt'), $MsvcRoot)
[IO.File]::WriteAllText((Join-Path $shimDir 'msvc-version.txt'), $msvcVersion)

$updates = @{
    PATH = "$shimDir;$compilerBin;$FlutterSdk/bin;$env:PATH"
    PUB_CACHE = $PubCache
    TEMP = $tempDir
    TMP = $tempDir
    INCLUDE = $include
    LIB = $lib
}
$previous = @{}
foreach ($name in $updates.Keys) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    [Environment]::SetEnvironmentVariable($name, $updates[$name], 'Process')
}
$exitCode = 0
Push-Location -LiteralPath $projectRoot
try {
    Write-Output "MSVC $msvcVersion / Windows SDK $sdkVersion / x64"
    Write-Output "Compiler: $compilerBin/cl.exe"
    if ($Action -eq 'Check' -or $Action -eq 'Env') {
        & $locatorExe -format json -utf8 -latest -products '*'
        if ($LASTEXITCODE -ne 0) { throw 'Portable compiler discovery failed.' }
        & "$compilerBin/cl.exe"
        if ($LASTEXITCODE -ne 0) { throw 'MSVC could not run.' }
        if ($Action -eq 'Env') { Write-Output 'Process environment is configured. Run flutter test --no-pub --reporter expanded.' }
    } else {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $log = Join-Path $auditRoot "$($Action.ToLowerInvariant())-$stamp.log"
        $arguments = if ($Action -eq 'NativeSmoke') {
            @('test', '--no-pub', '--reporter', 'expanded', 'tool/native_pdf_smoke_test.dart')
        } elseif ($Action -eq 'Test') {
            @('test', '--no-pub', '--reporter', 'expanded') + $TestPath
        } else { @('analyze', '--no-pub') }
        if ($TestName -and $Action -eq 'Test') { $arguments += @('--plain-name', $TestName) }
        Write-Output "Command: $FlutterSdk/bin/flutter.bat $($arguments -join ' ')"
        & "$FlutterSdk/bin/flutter.bat" @arguments 2>&1 | Tee-Object -FilePath $log
        $exitCode = $LASTEXITCODE
        Write-Output "Exit: $exitCode; log: $log"
    }
} finally {
    Pop-Location
    if ($Action -ne 'Env') {
        foreach ($name in $previous.Keys) {
            if ($null -eq $previous[$name]) {
                [Environment]::SetEnvironmentVariable($name, [NullString]::Value, 'Process')
            } else {
                [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
            }
        }
    }
}
if ($Action -ne 'Env') { exit $exitCode }
