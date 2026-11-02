param([Parameter(Mandatory = $true)][string]$Note)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$snapshotBase = Join-Path $projectRoot 'build\reader-checkpoints'
$snapshotPath = Join-Path $snapshotBase ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
New-Item -ItemType Directory -Path $snapshotPath -Force | Out-Null

# Only source and development records. Never copy assets, PDFs, keys, .env,
# automation, user storage, local SDK config or unrelated staged copy files.
$files = @('AGENTS.md', 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml')
$files += 'android/app/src/main/kotlin/com/example/recall/MainActivity.kt'
$files += 'docs/reader-mvp.md'
foreach ($directory in @('lib', 'test', 'tool', 'docs\development')) {
    $files += Get-ChildItem -LiteralPath (Join-Path $projectRoot $directory) -File -Recurse |
        Where-Object { $_.Extension -in @('.dart', '.ps1', '.md', '.cjs', '.py') -and $_.Name -notmatch '\uBCF5\uC0AC\uBCF8' } |
        ForEach-Object { $_.FullName.Substring($projectRoot.Length + 1) }
}
$records = foreach ($relativePath in ($files | Sort-Object -Unique)) {
    $source = [IO.Path]::GetFullPath((Join-Path $projectRoot $relativePath))
    if (-not $source.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Snapshot source escaped project root.'
    }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
    $destination = Join-Path (Join-Path $snapshotPath 'source') $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination
    [ordered]@{ path = $relativePath; sha256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash }
}
Push-Location -LiteralPath $projectRoot
try {
    $commit = git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Could not read source commit.' }
    $branch = git branch --show-current
    $manifest = [ordered]@{
        schema = 1
        createdUtc = [DateTime]::UtcNow.ToString('o')
        baseCommit = $commit
        branch = $branch
        note = $Note
        handoff = 'docs/development/HANDOFF.md'
        files = @($records)
    }
    $pendingManifest = Join-Path $snapshotPath 'manifest.pending.json'
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $pendingManifest -Encoding utf8
    # Publish the manifest last. An interrupted snapshot has no final manifest
    # and must be skipped by a future resume instead of appearing complete.
    Move-Item -LiteralPath $pendingManifest -Destination (Join-Path $snapshotPath 'manifest.json')
} finally { Pop-Location }
Write-Output "Checkpoint saved: $snapshotPath"
Write-Output "Source files: $(@($records).Count). No staging, commits, resets or restoration performed."
