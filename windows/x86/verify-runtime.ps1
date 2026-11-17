param([Parameter(Mandatory=$true)][string]$Runtime)
$ErrorActionPreference = 'Stop'
$runtimePath = (Resolve-Path -LiteralPath $Runtime).Path
& "$PSScriptRoot/assert-runtime-layout.ps1" -Runtime $runtimePath
$env:PATH = "$env:SystemRoot/System32;$env:SystemRoot"
# The root-level Ruby DLL locates its standard library itself. Only the PSDK
# extension directory needs adding; no host Ruby or gem directories are used.
$env:RUBYLIB = "$runtimePath/lib"
$env:GEM_HOME = "$runtimePath/lib/ruby/gems/3.4.0"
$env:GEM_PATH = $env:GEM_HOME
$env:SSL_CERT_FILE = "$runtimePath/lib/cert.pem"
Remove-Item Env:RUBYOPT -ErrorAction SilentlyContinue
$marker = Join-Path $runtimePath '.rubyw-smoke-passed'
if (Test-Path -LiteralPath $marker) { throw 'GUI smoke marker already exists' }
Remove-Item Env:PSDK_SMOKE_RESULT -ErrorAction SilentlyContinue
Remove-Item Env:PSDK_EXPECT_NO_GEMS -ErrorAction SilentlyContinue
Push-Location $runtimePath
try {
    & ./ruby.exe lib/psdk-runtime/smoke.rb
    if ($LASTEXITCODE) { throw "ruby.exe smoke failed with exit code $LASTEXITCODE" }
    & ./ruby.exe lib/__gem.rb gem --version
    if ($LASTEXITCODE) { throw 'Legacy RubyGems entry point failed' }
    $env:PSDK_SMOKE_RESULT = $marker
    $gui = Start-Process -FilePath "$runtimePath/rubyw.exe" -ArgumentList 'lib/psdk-runtime/smoke.rb' -WorkingDirectory $runtimePath -WindowStyle Hidden -Wait -PassThru
    if ($gui.ExitCode -ne 0 -or !(Test-Path -LiteralPath $marker)) {
        throw "rubyw.exe smoke failed with exit code $($gui.ExitCode)"
    }
    Remove-Item -LiteralPath $marker -Force
    Remove-Item Env:PSDK_SMOKE_RESULT
    $env:PSDK_EXPECT_NO_GEMS = '1'
    & ./ruby.exe --disable=gems,rubyopt,did_you_mean lib/psdk-runtime/smoke.rb
    if ($LASTEXITCODE) { throw 'Legacy psdk.bat launch mode failed' }
    $env:PSDK_SMOKE_RESULT = $marker
    $gui = Start-Process -FilePath "$runtimePath/rubyw.exe" -ArgumentList '--disable=gems,rubyopt,did_you_mean lib/psdk-runtime/smoke.rb' -WorkingDirectory $runtimePath -WindowStyle Hidden -Wait -PassThru
    if ($gui.ExitCode -ne 0 -or !(Test-Path -LiteralPath $marker)) {
        throw "Legacy rubyw.exe smoke failed with exit code $($gui.ExitCode)"
    }
    Write-Output 'Packaged ruby.exe and rubyw.exe passed'
} finally {
    Remove-Item Env:PSDK_EXPECT_NO_GEMS -ErrorAction SilentlyContinue
    Remove-Item Env:PSDK_SMOKE_RESULT -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }
    Pop-Location
}
