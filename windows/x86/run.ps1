param([Parameter(Mandatory=$true)][string]$Stage)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
$allowed = @('fetch', 'dependencies', 'ruby', 'graphics', 'movie', 'fmod', 'assemble', 'verify', 'download-fmod')
if ($Stage -notin $allowed) { throw "Unknown stage: $Stage" }
$env:MSYSTEM = 'MINGW32'
$env:CHERE_INVOKING = '1'
$env:MSYS2_PATH_TYPE = 'strict'
$commands = @{
    'fetch' = 'bash .github/scripts/fetch-sources.sh config/windows-x86.conf'
    'assemble' = 'bash windows/x86/assemble.sh'
    'verify' = 'bash windows/x86/verify.sh'
    'download-fmod' = 'bash windows/x86/download-fmod.sh'
}
$command = if ($commands.ContainsKey($Stage)) { $commands[$Stage] } else { "bash windows/x86/build.sh $Stage" }
Push-Location $root
try {
    & "$root/generated/windows-x86/msys64/usr/bin/bash.exe" -lc "$command 2>&1"
    if ($LASTEXITCODE) { throw "Windows x86 stage failed: $Stage" }
} finally { Pop-Location }
