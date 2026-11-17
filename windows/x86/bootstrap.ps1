param()
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
$work = Join-Path $root 'generated/windows-x86'
New-Item -ItemType Directory -Force "$work/downloads" | Out-Null
function Fetch($Url, $Hash, $Destination) {
    Write-Host "[$(Get-Date -Format o)] Fetching $Url"
    if (!(Test-Path -LiteralPath $Destination)) {
        & "$env:SystemRoot/System32/curl.exe" -fL --retry 2 --connect-timeout 30 --max-time 300 --speed-time 60 --speed-limit 1024 $Url -o "$Destination.tmp"
        if ($LASTEXITCODE) { throw "Download failed: $Url" }
        Move-Item -LiteralPath "$Destination.tmp" -Destination $Destination
    }
    Write-Host "[$(Get-Date -Format o)] Verifying $Destination"
    if ((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -ne $Hash) {
        throw "Checksum mismatch: $Destination"
    }
}
Fetch 'https://repo.msys2.org/distrib/x86_64/msys2-base-x86_64-20250830.tar.xz' `
    '780d7546aa86b781e0ded37c7b8f71f1b8572219494fe88259d8d4b78752b2e2' "$work/downloads/msys2.tar.xz"
$extractionMarker = "$work/.msys2-extracted"
if (!(Test-Path -LiteralPath $extractionMarker)) {
    if (Test-Path -LiteralPath "$work/msys64") {
        throw 'MSYS2 directory exists without a completed extraction marker; use a fresh generated/windows-x86 directory.'
    }
    Fetch 'https://github.com/ip7z/7zip/releases/download/26.03/7zr.exe' `
        'ad4c82fadcbdf93c03b4fc440f300509c7d60c5c2f4d183e35d9d70d6957037d' "$work/downloads/7zr.exe"
    Fetch 'https://github.com/ip7z/7zip/releases/download/26.03/7z2603-extra.7z' `
        '191894e6acb3647ffb69ce630479ff318523b2e2b9890aa7f05c1127c2e59b8f' "$work/downloads/7z-extra.7z"
    function Extract($Tool, $Archive, $Destination, $Stage) {
        Write-Host "[$(Get-Date -Format o)] Extracting $Stage"
        $outLog = "$work/extract-msys2.$Stage.out.log"
        $errLog = "$work/extract-msys2.$Stage.err.log"
        $process = Start-Process -FilePath $Tool `
            -ArgumentList @('x', '-y', '-bb1', "`"$Archive`"", "`"-o$Destination`"") `
            -WindowStyle Hidden -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errLog
        $null = $process.Handle
        $timer = [Diagnostics.Stopwatch]::StartNew()
        while (!$process.WaitForExit(15000)) {
            Write-Host "[$(Get-Date -Format o)] $Stage running ($([int]$timer.Elapsed.TotalSeconds)s)"
            Get-Content $outLog -Tail 2
            Get-Content $errLog -Tail 2
            if ($timer.Elapsed.TotalMinutes -ge 5) {
                $process.Kill()
                $process.WaitForExit()
                throw "$Stage exceeded five minutes; inspect extract-msys2.$Stage.*.log."
            }
        }
        Get-Content $outLog -Tail 8
        if ($process.ExitCode -ne 0) {
            Get-Content $errLog -Tail 30
            throw "$Stage failed: $($process.ExitCode)"
        }
    }
    # Standalone tools are downloaded and checksum-pinned; never use the
    # runner's installed 7-Zip or Windows tar for bootstrap extraction.
    Extract "$work/downloads/7zr.exe" "$work/downloads/7z-extra.7z" "$work/extractor" '7zip'
    $sevenZip = "$work/extractor/x64/7za.exe"
    Extract $sevenZip "$work/downloads/msys2.tar.xz" "$work/downloads/unpacked" 'xz'
    Extract $sevenZip "$work/downloads/unpacked/msys2.tar" $work 'tar'
    if (!(Test-Path -LiteralPath "$work/msys64/usr/bin/bash.exe")) { throw 'Extracted MSYS2 shell is missing' }
    New-Item -ItemType File -Path $extractionMarker | Out-Null
    Write-Host "[$(Get-Date -Format o)] MSYS2 extraction complete"
}
Fetch 'https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-3.4.10-1/rubyinstaller-3.4.10-1-x86.7z' `
    'be323ac7b8342de16edcceb1ee04a90023c39aa7e7a544e628c6360fffb602da' "$work/downloads/rubyinstaller.7z"
$env:MSYSTEM = 'MINGW32'
$env:CHERE_INVOKING = '1'
$env:MSYS2_PATH_TYPE = 'strict'
Push-Location $root
try {
    Write-Host "[$(Get-Date -Format o)] Starting isolated MSYS2 package installation"
    # Merge native diagnostics inside bash: Windows PowerShell 5 otherwise
    # promotes pacman warnings to terminating errors when logs are redirected.
    & "$work/msys64/usr/bin/bash.exe" -lc 'bash windows/x86/install-packages.sh 2>&1'
    if ($LASTEXITCODE) { throw 'CI package installation failed' }
} finally { Pop-Location }
