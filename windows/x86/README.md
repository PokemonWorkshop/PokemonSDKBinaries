# Windows x86 runtime

The Windows archive follows the `legacy-binaries` layout. Extract it into the
application directory, including the source-built Ruby launchers:

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

There is no `ruby-dist/` wrapper, `bin/`, `ssl/` or `setup.cmd` in this archive.
Both top-level directories match the legacy package. Ruby 3.4.10, its gem ABI
folders, SFMLAudio and the current dependency closure are retained; obsolete
Ruby 3.0 files and unused legacy DLLs are not copied. All runtime PE images
are **32-bit i386**. The consuming launcher must support this Ruby 3.4 ABI;
this is a layout-compatible package, not an ABI downgrade to legacy Ruby 3.0.

The manifest retains the legacy private-assembly identity:
`ruby_builtin_dlls`, version `1.0.0.0`, type `win32`. Its file entries are
regenerated from exactly the DLLs staged in that directory. Both bundled
executables embed this dependency, preserving their existing manifest settings.
The shared Ruby DLL is at the package root. DLL filenames
must match their actual PE imports; do not rename them to obsolete names.
`lib/__gem.rb` preserves the legacy command convention: the first argument is
`gem`, followed by the RubyGems arguments. The certificate bundle is at
`lib/cert.pem`.

## Local build

Use a 64-bit Windows 10/11 or Server 2022 host and a checkout path without
spaces. No host Ruby, compiler, Python, CMake or native dependencies are used.
Windows PowerShell and curl.exe bootstrap a private, checksum-pinned
MSYS2 environment under `generated/windows-x86`. Bootstrap downloads pinned
standalone 7-Zip 26.03 tools and extracts XZ and TAR in separate bounded stages;
it does not use Windows tar or a preinstalled 7-Zip for this operation.
Each stage reports progress and saves `extract-msys2.*.log` diagnostics, which
CI uploads on failure. An extraction completion marker prevents a partial
extraction from being mistaken for a usable toolchain.

Use a fresh `sources/` directory when switching targets or source locks; see
the shared [workspace and configuration conventions](../../README.md#workflow-and-script-conventions).

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

`FMOD_SDK_DIR` contains `inc/fmod_common.h`, `lib/x86/fmod.dll` and
`lib/x86/libfmod.a` from FMOD Studio API **2.02.20**. Copy SDKs installed in
`Program Files (x86)` into a path without spaces before building. RubyFMOD is
compiled against the proprietary SDK's supplied library.

The payload is `generated/windows-x86/Windows-x86/`. Verification creates
`dist/Windows.7z` and its SHA-256 checksum. To test a payload directly:

```powershell
./windows/x86/verify-runtime.ps1 -Runtime generated/windows-x86/Windows-x86
```

This tests both bundled executables with only Windows system directories on
PATH. Their embedded manifests load the private DLL assembly; the root Ruby
DLL locates its standard library automatically. The script sets the project
extension and gem paths relative to the payload and checks
`lib/__gem.rb gem --version`. A temporary success marker verifies that the
GUI executable completed the same smoke test and is removed afterward.

PSDK's Windows batch launcher passes `--disable=gems,rubyopt,did_you_mean`.
Assembly therefore also stages former standard-library gems (including CSV,
REXML, Base64, BigDecimal and the net libraries) into Ruby's built-in
`site_ruby/3.4.0` search directory. These come from the pinned Ruby source
build, including its compiled native extensions; no extra gem downloads or
host gems are used. Their normal gem installations remain available.
Both executables are tested with gems enabled and with the exact PSDK flags,
including CSV parsing and a check that RubyGems remains unloaded.

Dependency stages have success stamps. Use a fresh generated build directory
when changing pins or compiler flags. Do not edit scripts while a build runs.
Assembly and verification refuse existing output directories/archives; move
old results aside before repeating those stages. Caches and logs are retained
for diagnostics.

## Reproducibility

* `config/windows-x86.conf` pins the same component revisions as Linux/macOS.
* Source archives and all private MSYS2 packages, including their transitive
  dependencies, have explicit URLs and SHA-256 hashes in the adjacent lock
  files. Bootstrap uses `pacman -U`, not rolling repository resolution.
* The compiler targets `i686-w64-mingw32` with MSVCRT. A downloaded, hashed
  RubyInstaller x86 package bootstraps the source-built Ruby 3.4.10 runtime.
* SFML 2.6.2, FFmpeg 6.0, OpenAL Soft 1.23.1, FriBidi 1.0.16 and libass 0.17.3
  are built from source. Other prerequisites come from the locked packages.
* FFmpeg uses portable C implementations instead of incompatible old inline
  assembly. Its configuration retains feature flags with normalized paths.
* The SFEMovie TypedData fix is pinned in the Ruby binding; the builder retains
  the explicit matching LiteRGSS include path.
* Native sfeMovie includes the upstream channel-layout correction and fallback
  texture lifetime fix for an observed NVIDIA OpenGL shutdown crash. Neither
  requires a local patch.

## Validation and CI

`layout.py` enforces the two top-level directories and three root binaries, required legacy entry
points, current Ruby directories, DLL placement and an exact manifest/DLL
match. `pe.py` checks i386 architecture, ordinary/delay import closure and
workspace-path leaks, resolving dependencies from the root and `ruby_builtin_dlls`.
Assembly strips debug sections and reruns the audit without external DLL
search directories. Vendor FMOD/gettext DLLs retain upstream diagnostic
source filenames; these are not loader search paths.

The smoke test covers standard-library native extensions, all four project
extensions, FMOD initialization, FMOD/SFML PCM decoding, required FFmpeg
decoders and sfeMovie audio loading. Mandatory graphics tests check actual
video pixels, snapshots, bitmap subclasses and disposed/uninitialized objects.
They require an OpenGL-capable session. All launch modes check normal shutdown.
All platforms run the same [functional suite](../../tests/README.md).

The Windows workflow uploads the runtime archive and checksum, then downloads
and tests both bundled executables on a fresh Windows runner. The protected-tag
release publishes `Windows.7z` and its SHA-1 hash in `version.json`; the SHA-256
sidecar remains an internal CI artifact. The release waits
for successful Windows, Linux and macOS builds and verification.

CI uses `FMOD_USER` and `FMOD_PASSWORD` to download
`fmodstudioapi20220win-installer.exe`. 7-Zip extracts its NSIS payload into the
workspace without installing into Program Files. Temporary SDK files are
removed in an `always()` step. Authenticated download/extraction and hosted
GitHub execution have not been exercised locally; local builds use the
supplied FMOD Core 2.02.20 SDK.

On 2026-09-11, the legacy-shaped package passed the PE/layout audits and all
runtime, audio, video texture and RubyGems-entry checks using its bundled
`ruby.exe` and `rubyw.exe`, without adding DLL directories to PATH.
