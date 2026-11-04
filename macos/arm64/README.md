# Build the macOS ARM64 runtime

This guide builds `macOS.7z` for Apple Silicon, targeting macOS 11.0 with
Ruby 3.4.10. To use a prebuilt package, follow the
[installation instructions](../../USAGE.md#linux-and-macos).

## Requirements

- An Apple Silicon Mac with Xcode or Command Line Tools.
- Access to a working WindowServer/OpenGL session and CoreAudio for verification.
- An authorized FMOD Core 2.02.20 SDK.

The SDK directory must contain `inc/fmod_common.h` and `lib/libfmod.dylib`.
To extract an authorized installer without running it:

```bash
bash macos/arm64/extract-fmod.sh /path/to/fmodstudioapi20220mac-installer.dmg
```

Use the Core directory printed by that command as `FMOD_SDK_DIR` below.

## Build and package

Use a fresh `sources/` directory when changing targets or pins; see the
[shared build conventions](../../CONTRIBUTING.md#workflow-and-script-conventions).
Run from the repository root:

```bash
bash macos/arm64/bootstrap-tools.sh
export PSDK_BUILD_TOOLS_BIN="$PWD/generated/macos-arm64-tools/bin"
export SEVENZIP="$PSDK_BUILD_TOOLS_BIN/7zz"
bash .github/scripts/fetch-sources.sh config/macos-arm64.conf
export FMOD_SDK_DIR=/absolute/path/to/FMOD-core
bash macos/arm64/build.sh
ARCHIVE_PATH="$PWD/dist/macOS.7z" bash macos/arm64/assemble-release.sh
RELEASE_DIR="$PWD/generated/MacOS-arm64/ruby-dist" bash macos/arm64/verify-release.sh
```

## Outputs

| Output | Path |
| --- | --- |
| Build files | `generated/macos-arm64/` |
| Private tools | `generated/macos-arm64-tools/` |
| Assembled runtime | `generated/MacOS-arm64/ruby-dist/` |
| Archive | `dist/macOS.7z` |
| Internal checksum | `dist/macOS.7z.sha256` |

Set `JOBS` to limit compilation concurrency. Set `SEVENZIP` to an absolute `7zz`
path if using another extractor.

## Resume or rebuild

You can run compilation stages separately:

```bash
bash macos/arm64/build.sh dependencies
bash macos/arm64/build.sh ruby
bash macos/arm64/build.sh components
```

Dependency success stamps allow later stages to resume. After changing the
compiler, target, configuration or pins, move old build outputs aside and use
fresh source checkouts. Assembly requires an empty `OUTPUT_DIR`; omit
`ARCHIVE_PATH` to assemble without creating an archive.

## Verify a package

From the repository root, point the verifier at an assembled or extracted runtime:

```bash
RELEASE_DIR=/absolute/path/to/ruby-dist bash macos/arm64/verify-release.sh
```

The verifier audits ARM64 binaries, deployment targets, signatures and native
library paths. It then relocates the runtime to a path containing spaces and
runs the [shared functional suite](../../tests/README.md). Missing graphics
access fails verification.

## Compatibility limits

The workflow builds and tests on macOS 14 and verifies extracted archives on
macOS 15 and 26. macOS 11–13 and a complete Pokémon SDK game still need runtime
testing. Targeting macOS 11 does not establish testing on every supported OS
or hardware model. See [binary portability and signing](BUILD-NOTES.md) for
what the audits establish and what application distributors must handle.

## Reference documents

- [DEPENDENCIES.md](DEPENDENCIES.md): pinned inputs, library versions, system
  dependencies and selection rationale.
- [BUILD-NOTES.md](BUILD-NOTES.md): build internals, workarounds, binary audits
  and compatibility limits.
