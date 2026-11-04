param([Parameter(Mandatory=$true)][string]$Runtime)
$ErrorActionPreference = 'Stop'
$expected = @{
    'lib' = 'Container'
    'ruby_builtin_dlls' = 'Container'
    'ruby.exe' = 'Leaf'
    'rubyw.exe' = 'Leaf'
    'msvcrt-ruby340.dll' = 'Leaf'
}
$actual = @(Get-ChildItem -LiteralPath $Runtime -Force)
$missing = @($expected.Keys | Where-Object { $_ -cnotin $actual.Name })
$unexpected = @($actual.Name | Where-Object { $_ -cnotin @($expected.Keys) })
if ($missing.Count -or $unexpected.Count) {
    throw "Invalid Windows runtime layout. Missing: [$($missing -join ', ')]. Unexpected: [$($unexpected -join ', ')]. Actual: [$($actual.Name -join ', ')]."
}
foreach ($name in $expected.Keys) {
    if (!(Test-Path -LiteralPath (Join-Path $Runtime $name) -PathType $expected[$name])) {
        throw "Invalid Windows runtime entry: $name must be a $($expected[$name])."
    }
}
