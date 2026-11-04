param(
    [Parameter(Mandatory=$true)][string]$Archive,
    [Parameter(Mandatory=$true)][string]$Destination
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
$toolDirectory = Join-Path $root 'generated/release-extractor'
New-Item -ItemType Directory -Force -Path $toolDirectory | Out-Null
$extractor = Join-Path $toolDirectory '7zr-26.03.exe'
$expectedHash = 'ad4c82fadcbdf93c03b4fc440f300509c7d60c5c2f4d183e35d9d70d6957037d'
if (!(Test-Path -LiteralPath $extractor)) {
    & "$env:SystemRoot/System32/curl.exe" -fL --retry 2 --connect-timeout 30 --max-time 300 --speed-time 60 --speed-limit 1024 `
        https://github.com/ip7z/7zip/releases/download/26.03/7zr.exe -o "$extractor.tmp"
    if ($LASTEXITCODE) { throw 'Release extractor download failed' }
    Move-Item -LiteralPath "$extractor.tmp" -Destination $extractor
}
if ((Get-FileHash -LiteralPath $extractor -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'Release extractor checksum mismatch'
}
$archivePath = (Resolve-Path -LiteralPath $Archive).Path
if (Test-Path -LiteralPath $Destination) {
    if (!(Test-Path -LiteralPath $Destination -PathType Container) -or
        (Get-ChildItem -LiteralPath $Destination -Force | Select-Object -First 1)) {
        throw 'Release extraction destination must be empty'
    }
} else {
    New-Item -ItemType Directory -Path $Destination | Out-Null
}
$destinationPath = (Resolve-Path -LiteralPath $Destination).Path
& $extractor x -y $archivePath "-o$destinationPath"
if ($LASTEXITCODE) { throw "Archive extraction failed: $LASTEXITCODE" }
