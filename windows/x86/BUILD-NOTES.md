# Windows build reference

For commands, see [README.md](README.md). Versions and dependency policy are
listed in [DEPENDENCIES.md](DEPENDENCIES.md).

## Toolchain and build layout

Windows PowerShell and curl.exe bootstrap a private, checksum-pinned
MSYS2 environment under `generated/windows-x86`. Bootstrap downloads pinned
standalone 7-Zip 26.03 tools and extracts XZ and TAR in separate bounded stages;
it does not use Windows tar or a preinstalled 7-Zip for this operation.
Each stage reports progress and saves `extract-msys2.*.log` diagnostics, which
CI uploads on failure. An extraction completion marker prevents a partial
extraction from being mistaken for a usable toolchain.

Bootstrap installs the locked packages with `pacman -U` rather than resolving
against rolling repositories. RubyInstaller supplies the bootstrap interpreter;
the released Ruby is built from source. SDK downloads are extracted without
system-wide installation and removed after CI jobs; local builds may use an
already extracted, authorized SDK.

## Native build adjustments

OpenSSL 3.5.9 is built first with upstream's 32-bit `mingw` target, shared
libraries, and tests, loadable modules and assembly disabled. The build uses
fixed `/mingw32` install paths to avoid embedding checkout paths, stages the
installation into the private prefix, then updates its pkg-config files to
point to that prefix. Ruby's `--with-openssl-dir` selects this source build;
DLL assembly searches the private prefix before toolchain packages. The
packaged runtime tests require OpenSSL 3.5.9, rejecting an accidental fallback
to the toolchain's 3.6.4 DLLs.

This follows the [upstream MinGW build instructions](https://github.com/openssl/openssl/blob/openssl-3.5/NOTES-WINDOWS.md#native-builds-using-mingw).

- OpenAL Soft is compiled with `-include cstdint` because its source relies on
  a transitive include removed in newer GCC.
- FFmpeg uses portable C implementations with x86 and inline assembly disabled.
  Its generated configuration keeps feature flags but replaces workspace paths
  with `/psdk-build`.
- SFEMovie's Ruby binding uses matching LiteRGSS/LiteCGSS headers. The pinned
  upstream native sfeMovie already includes the channel-layout and fallback
  texture lifetime fixes; no local movie patches are applied.

### SDK launch mode

The SDK's Windows batch launcher passes `--disable=gems,rubyopt,did_you_mean`.
Assembly stages former standard-library gems (including CSV, REXML, Base64,
BigDecimal and the net libraries) into `site_ruby/3.4.0` so they are available
without RubyGems. They come from the pinned source-built Ruby, including native
extensions. Normal gem installations remain available as well.

Both executables are tested with gems enabled and with the SDK flags, including
CSV parsing and a check that RubyGems remains unloaded.

## Binary audits

`layout.py` enforces the two top-level directories and three root binaries, required legacy entry
points, current Ruby directories, DLL placement and an exact manifest/DLL
match. `pe.py` checks i386 architecture, ordinary/delay import closure and
workspace-path leaks, resolving dependencies from the root and `ruby_builtin_dlls`.
Assembly strips debug sections and reruns the audit without external DLL
search directories. Vendor FMOD/gettext DLLs retain upstream diagnostic
source filenames; these are not loader search paths.

### DLL loading and launcher compatibility

The manifest uses the private-assembly identity:
`ruby_builtin_dlls`, version `1.0.0.0`, type `win32`. Its file entries are
regenerated from exactly the DLLs staged in that directory. Both bundled
executables embed this dependency, while preserving their other manifest settings.
The shared Ruby DLL is at the package root. DLL filenames
must match their actual PE imports; do not rename them to obsolete names.
`lib/__gem.rb` preserves the legacy command convention: the first argument is
`gem`, followed by the RubyGems arguments. The certificate bundle is at
`lib/cert.pem`.

## Compatibility limits

The workflow builds on Windows Server 2022, then downloads the archive and
checksum to a fresh runner and tests both executables again. This covers the
packaged launch modes and the configured runner's OpenGL environment, not every
Windows release, GPU driver or full SDK game.

Publication and checksum formats are described in
[RELEASING.md](../../RELEASING.md); redistribution terms are described in
[LICENSING.md](../../LICENSING.md).
