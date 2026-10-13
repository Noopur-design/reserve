<#
.SYNOPSIS
  Builds the Reserve web app and packages it for upload to any folder of a website.

.DESCRIPTION
  Run from anywhere:   powershell -ExecutionPolicy Bypass -File tool\build_web.ps1

  1. flutter build web --release --no-source-maps
       Default JavaScript + CanvasKit build. No --wasm: the phone code paths
       import dart:io, and the JS build runs in every current browser.
       No --pwa-strategy: that flag is deprecated, and web/flutter_bootstrap.js
       doesn't register a service worker at all (no stale caches on a demo site).
       CanvasKit is loaded from the upload itself when the server sends .wasm
       as application/wasm, else from Google's CDN (see web/flutter_bootstrap.js).
  2. Sets <base href="./"> in build/web/index.html. Flutter only accepts an
     absolute base ("/folder/"), but a relative one lets the same build run
     from any folder (site root, /reserve/, /apps/demo/...). The app uses
     hash URLs (#/...), so a relative base is safe.
  3. Copies the result to dist/reserve-web/ without what a JS + CanvasKit
     build never loads (the Wasm-only renderers skwasm / wimp, the opt-in
     "webparagraph" CanvasKit and *.symbols debug files), which roughly halves
     the upload, and zips its contents to dist/Reserve-web-v<version>.zip
     (forward-slash paths, so it unzips correctly on Linux hosting too).

  Flutter is taken from PATH, or from C:\src\flutter if it isn't on PATH.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $env:Path = "C:\src\flutter\bin;$env:Path"
}

$version = (Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^version:\s*([0-9][0-9.]*)').Matches[0].Groups[1].Value
Write-Host "Building Reserve web v$version ..."

# 1. Build ------------------------------------------------------------------
flutter build web --release --no-source-maps
if ($LASTEXITCODE -ne 0) { throw "flutter build web failed (exit code $LASTEXITCODE)" }

$build = Join-Path $root 'build\web'
$utf8 = New-Object System.Text.UTF8Encoding $false

# 2. Relative base href -----------------------------------------------------
$index = Join-Path $build 'index.html'
$html = [IO.File]::ReadAllText($index, $utf8)
$patched = [regex]::Replace($html, '<base href="[^"]*">', '<base href="./">')
if ($patched -notmatch '<base href="\./">') { throw "No <base href> tag found in $index" }
[IO.File]::WriteAllText($index, $patched, $utf8)
Write-Host 'Set <base href="./"> in build\web\index.html'

foreach ($required in 'index.html', 'flutter_bootstrap.js', 'main.dart.js', 'manifest.json',
    'canvaskit\canvaskit.js', 'canvaskit\canvaskit.wasm', 'canvaskit\chromium\canvaskit.js', 'canvaskit\chromium\canvaskit.wasm') {
    if (-not (Test-Path (Join-Path $build $required))) { throw "Build output is missing $required" }
}

# 3. Package ----------------------------------------------------------------
$dist = Join-Path $root 'dist'
$out = Join-Path $dist 'reserve-web'
New-Item -ItemType Directory -Force $dist | Out-Null
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
Copy-Item $build $out -Recurse
# Build bookkeeping, not needed on a web server.
Get-ChildItem $out -Recurse -Force -File | Where-Object { $_.Name.StartsWith('.') } | Remove-Item -Force
# Files a JS + CanvasKit build never requests. Only pruned if the build has no
# Wasm variant (which would need skwasm).
$bootstrap = [IO.File]::ReadAllText((Join-Path $out 'flutter_bootstrap.js'), $utf8)
if ($bootstrap -match '"compileTarget":"dart2wasm"') {
    Write-Warning 'Build includes a Wasm variant; keeping all renderer files.'
} else {
    $ck = Join-Path $out 'canvaskit'
    Get-ChildItem $ck -File | Where-Object { $_.Name -like 'skwasm*' -or $_.Name -like 'wimp*' } | Remove-Item -Force
    if (Test-Path (Join-Path $ck 'webparagraph')) { Remove-Item (Join-Path $ck 'webparagraph') -Recurse -Force }
    Get-ChildItem $out -Recurse -File -Filter '*.symbols' | Remove-Item -Force
}

$zip = Join-Path $dist "Reserve-web-v$version.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [IO.File]::Open($zip, [IO.FileMode]::CreateNew)
try {
    $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $outFull = (Resolve-Path $out).Path.TrimEnd('\')
        Get-ChildItem $out -Recurse -File | Sort-Object FullName | ForEach-Object {
            $entry = $_.FullName.Substring($outFull.Length + 1).Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $_.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally {
        $archive.Dispose()
    }
} finally {
    $stream.Dispose()
}

$files = (Get-ChildItem $out -Recurse -File).Count
$sizeMb = [math]::Round(((Get-ChildItem $out -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1)
$zipMb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host ""
Write-Host "Done."
Write-Host "  Web build : $out  ($files files, $sizeMb MB)"
Write-Host "  Zip       : $zip  ($zipMb MB)"
