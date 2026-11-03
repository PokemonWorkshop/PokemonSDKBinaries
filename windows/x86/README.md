# Build the Windows x86 runtime

This guide builds `Windows.7z` with a 32-bit Ruby 3.4.10 runtime and the SDK's
native bindings. To use a prebuilt package, follow the
[installation instructions](../../USAGE.md#windows).

## Requirements

Use a 64-bit Windows 10/11 or Server 2022 host with Windows PowerShell and
`curl.exe`. Keep the checkout and FMOD SDK paths free of spaces. The bootstrap
installs a private, checksum-pinned MSYS2 toolchain; a host Ruby or compiler is
not needed.

Set `FMOD_SDK_DIR` to an authorized FMOD Core 2.02.20 SDK containing
`inc/fmod_common.h`, `lib/x86/fmod.dll` and `lib/x86/libfmod.a`.

## Build and package

Use a fresh `sources/` directory when switching targets or source locks; see
[shared build conventions](../../CONTRIBUTING.md#workflow-and-script-conventions).
Run from the repository root in PowerShell:

```powershell
./windows/x86/bootstrap.ps1
./windows/x86/run.ps1 fetch
$env:FMOD_SDK_DIR = 'D:/path/to/FMod-Core'
./windows/x86/run.ps1 dependencies
./windows/x86/run.ps1 ruby
./windows/x86/run.ps1 graphics
./windows/x86/run.ps1 movie
./windows/x86/run.ps1 fmod
./windows/x86/run.ps1 assemble
./windows/x86/run.ps1 verify
```

## Outputs

| Output | Path |
| --- | --- |
| Toolchain and build files | `generated/windows-x86/` |
| Assembled runtime | `generated/windows-x86/Windows-x86/` |
| Archive | `dist/Windows.7z` |
| Internal checksum | `dist/Windows.7z.sha256` |

The final `verify` stage tests the payload and creates the archive and checksum.

### Package layout

Extract the archive into the application directory, keeping this structure:

```text
ruby.exe
rubyw.exe
msvcrt-ruby340.dll
lib/
  cert.pem
  __gem.rb
  LiteRGSS.so
  RubyFmod.so
  SFEMovie.so
  SFMLAudio.so
  ruby/
    3.4.0/
    gems/3.4.0/
  psdk-runtime/                 # licenses, build information and smoke tests
ruby_builtin_dlls/
  ruby_builtin_dlls.manifest
  ...required native DLLs...
```

The runtime DLL stays beside the executables, and dependency DLLs stay in
`ruby_builtin_dlls/`. The SDK launcher and any additional native extensions must
support 32-bit Ruby 3.4. The `3.4.0` library directories are Ruby ABI directories;
the embedded interpreter is Ruby 3.4.10.

## Resume or rebuild

Dependency stages record success stamps. Use fresh generated build outputs
after changing pins or compiler flags. Assembly, relocation and archive creation
require fresh destinations; move previous results aside before repeating those
stages. Avoid changing scripts while a build runs.

## Verify a package

To test an assembled or extracted runtime directly:

```powershell
./windows/x86/verify-runtime.ps1 -Runtime generated/windows-x86/Windows-x86
```

Verification needs an OpenGL-capable session. It runs the
[shared functional suite](../../tests/README.md) through both `ruby.exe` and
`rubyw.exe`, checks normal shutdown and requires a success marker from the GUI
executable. Native dependencies must resolve without adding DLL directories
to PATH.

## Compatibility limits

The hosted workflow verifies on Windows Server 2022. Passing its tests does not
establish coverage of every Windows version, GPU driver or complete SDK game.
The SDK's gems-disabled launch mode is described in the
[build reference](BUILD-NOTES.md#native-build-adjustments).

## Reference documents

- [DEPENDENCIES.md](DEPENDENCIES.md): pinned inputs, library versions, system
  dependencies and selection rationale.
- [BUILD-NOTES.md](BUILD-NOTES.md): build internals, workarounds, binary audits
  and compatibility limits.
