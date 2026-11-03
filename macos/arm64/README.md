# macOS ARM64 runtime

This build targets ordinary **arm64** and **macOS 11.0**, with **Ruby 3.4.10**.
It uses the Linux release's component revisions. It does not use `-march=native`,
arm64e, or Homebrew runtime dylibs. Apple's frameworks, libSystem, libc++,
libiconv, libffi and zlib remain system-provided. Other dependencies are built
from pinned sources, except FMOD's official runtime (its ARM64 slice also
targets macOS 11.0).

`dist/macOS.7z` contains `ruby-dist/`. Like the legacy package it provides
`bin/ruby`, `lib/LiteRGSS.bundle`, `lib/RubyFmod.bundle`, and sourceable `setup.sh`.
It additionally includes `SFMLAudio.bundle`, `SFEMovie.bundle`, FFmpeg 6.0 and
subtitle support. Native extensions for legacy Ruby 3.2 must be rebuilt for 3.4.

```bash
source /path/to/ruby-dist/setup.sh
ruby /path/to/game/Game.rb
```

Source this script from Bash. It resolves its own directory, selects bundled
Ruby, sets UTF-8 defaults and excludes host gem paths. Ruby uses
`--enable-load-relative`; native dependencies use `@loader_path`.
No `DYLD_LIBRARY_PATH` is needed. The legacy `clean_load_path` require remains.

## Local build

Use an Apple Silicon Mac with Xcode or Command Line Tools.

Use a fresh `sources/` directory when switching targets or source locks; see
the shared [workspace and configuration conventions](../../README.md#workflow-and-script-conventions).

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

The bootstrap uses fixed upstream downloads verified against
`config/macos-arm64-tools.lock`: CMake 4.4.4, Ninja 1.13.2, pkgconf 3.0.7 and
7-Zip 26.03. pkgconf and 7-Zip are built from source using Apple's compiler;
CMake and Ninja use upstream macOS binaries. 7-Zip is built for macOS 11.0
because the upstream 26.03 Mac binary requires macOS 26 and cannot run on the
older CI runners. The tools live under `generated/macos-arm64-tools/` and
are not shipped. Installations are keyed by the lock and bootstrap script's
SHA-256, so pin or build-recipe changes do not reuse old tool stamps.
CI uses these tools rather than current Homebrew
formulas. Local builds may still use installed `cmake`, `ninja`, `pkgconf` and
`sevenzip` when `PSDK_BUILD_TOOLS_BIN` is unset.

Fresh verification runners use `bootstrap-tools.sh archive` to build only the
pinned extractor with Apple's tools, without CMake, Ninja or pkgconf.

`FMOD_SDK_DIR` must contain `inc/fmod_common.h` and `lib/libfmod.dylib`, version
2.02.20. Alternatively, run `bash macos/arm64/extract-fmod.sh /path/to/fmodstudioapi20220mac-installer.dmg`
and use the printed Core directory. Extraction mounts the DMG read-only and
unpacks package payloads without running the installer.

Build output is in `generated/macos-arm64/`. Local dependency stamps allow
resuming failed later stages. After changing the compiler, target, configuration
or pins, remove that generated directory and use fresh source checkouts.
CI uses fresh runners, without shared build caches.

Individual stages: `build.sh dependencies`, `build.sh ruby`, `build.sh components`.
`build.sh` only compiles. Assembly: `bash macos/arm64/assemble-release.sh`.
Validation: `bash macos/arm64/verify-release.sh`. As on Linux, assembly requires
an empty `OUTPUT_DIR`; omit `ARCHIVE_PATH` to assemble without archiving.
Set `JOBS` to limit compilation concurrency; set `SEVENZIP` to an absolute `7zz`
path when necessary. Native validation needs WindowServer/OpenGL and CoreAudio
access; restricted execution sandboxes may block these services.

## Build tooling

Paths are relative to this repository. Existing upstream `extconf.rb`, Rakefiles
and CMake files are retained. There are no replacement extension definitions or
CMake projects.

| File | Responsibility |
| --- | --- |
| `config/macos-arm64.conf` | Component pins, Ruby/FMOD versions and deployment target. |
| `config/macos-arm64-sources.lock` | Source archive URLs and SHA-256 hashes. |
| `config/macos-arm64-tools.lock` | Fixed build-tool downloads and SHA-256 hashes. |
| `macos/arm64/bootstrap-tools.sh` | Private pinned build tools; archive-only mode installs just 7-Zip. |
| `.github/scripts/fetch-sources.sh` | Fetches pinned component checkouts and verifies dependency archives for all three platforms. |
| `.github/scripts/prepare-sfemovie-ruby.sh` | Prepares disposable Ruby binding checkouts on all three platforms: copies matching LiteRGSS headers and links matching LiteCGSS headers. |
| `tests/sfemovie-texture.rb` | Generates an uncompressed green AVI and reference PNG; checks actual movie pixels, Bitmap subclasses, snapshots and disposed/uninitialized objects in the shared suite on all three platforms. |
| `macos/arm64/build.sh` | Runs upstream configure/CMake/extconf builds with ARM64/macOS 11 flags; isolates dependencies; builds Ruby, SFML and LiteCGSS once. |
| `macos/arm64/assemble-release.sh` | Assembles runtime files and optionally archives them, using `OUTPUT_DIR` and `ARCHIVE_PATH`. |
| `macos/arm64/mach_o.py` | Relocates and signs binaries, normalizes symlinks and audits portability. |
| `macos/arm64/setup.sh` | Sourceable legacy launcher interface for relocated Ruby 3.4. |
| `macos/arm64/clean_load_path.rb` | Legacy require target, also copied into Windows packages; Ruby and setup.sh handle macOS path isolation. |
| `macos/arm64/verify-release.sh` | Audits and relocates the package to a path containing spaces, then runs tests with a clean environment. |
| `macos/arm64/smoke.rb` | Repository-side macOS adapter that runs the packaged shared functional suite; coverage is documented in `tests/README.md`. |
| `macos/arm64/archive-release.sh` | Creates `.7z`, tests its extracted contents and writes the internal SHA-256 sidecar. |
| `macos/arm64/extract-fmod.sh` | Unpacks an authorized FMOD installer without a system-wide installation. |
| `.github/workflows/build-macos-arm64.yml` | Builds on ARM64 macOS 14, verifies the archive on fresh macOS 15/26 runners and uploads runtime artifacts. |
| `.github/workflows/build-linux-x86_64.yml` | Reusable Linux build and fresh-archive verification workflow. |
| `.github/workflows/release.yml` | Authorizes protected-tag releases, calls all three platform workflows and publishes their verified archives plus `version.json`. |
| `linux/x86_64/extract-fmod.sh` | Extracts the authorized Linux SDK download. |
| `macos/arm64/README.md` | Reproduction, compatibility, validation and file rationale. |

The shared downloader supports Linux, macOS and Windows. The protected-tag
release workflow waits for all three platforms to finish their build and
verification jobs before publishing. Build workflows have read-only permissions
and actions are pinned by commit. `release.yml` is the only tag entry point and
publisher.

## Upstream build adjustments

FMOD's extracted `FMOD Programmers API` path contains spaces. The build escapes
the include/library paths inside the flags passed to the existing `extconf.rb`,
so both mkmf's probes and the generated Makefile preserve them. Quoting only
the outer command-line argument is insufficient. Failed FMOD configuration
prints `mkmf.log` before CI removes the temporary SDK.

1. **LiteRGSS Clang flag:** upstream extconf adds
   `-frelaxed-template-template-args`. Apple Clang 21 rejects this removed flag.
   The build probes support and, only when necessary, omits this flag using a
   `make CXXFLAGS=...` override. No source file is edited.
2. **sfeMovie framework:** the original CMake framework target is built normally.
   Its Mach-O image is staged as `libsfeMovie.dylib` with an updated install name,
   allowing the existing Ruby binding to link with `-lsfeMovie`.
3. **FFmpeg resampler correction:** sfeMovie passes `AVChannelLayout` structures
   to `av_opt_set_chlayout` using `in_channel_layout`/`out_channel_layout`. In
   FFmpeg 6.0 these names identify deprecated integer mask fields. The setter
   writes to the wrong fields and corrupts the resampler configuration. The
   upstream correction changes the names to `in_chlayout`/`out_chlayout`.
   Actual audio loading reproduced the failure; simply loading the extension
   did not. All three platforms now pin native sfeMovie revision
   `0fbc65d67a1bb02b233c1c527dffff04dd38fe67`, which includes this correction
   and the fallback-texture lifetime fix. Local patches are no longer needed.
4. **SFEMovie texture ABI:** all three platform configurations currently pin the
   Ruby binding to `d90a4fbae5d7973e8475f97f5498de13fb6f203a`. The binding's
   TypedData access, disposed-object handling and snapshots are exercised by the
   shared texture regression. The preparation helper copies matching LiteRGSS
   headers and links matching LiteCGSS headers; builders also supply the LiteRGSS
   include directory. The native sfeMovie revision also ties fallback texture
   lifetime to its movie, addressing an observed Windows/NVIDIA shutdown crash
   without a local patch.

Ruby configure options disable DTrace/JIT build dependencies and optional native
dbm/gdbm/readline extensions; Ruby 3.4's Reline is still bundled. Font rendering
uses source-built FreeType/HarfBuzz/FriBidi/libass with Apple's CoreText provider.
FFmpeg uses generic ARM64 code and shared libraries, disables autodetection and
networking, and enables PNG/mov_text decoding. It does not enable
GPL/nonfree codecs. macOS pins FFmpeg 6.0; Linux pins 6.1.6.

## Validation and limits

Every Mach-O, including native standard-library and gem extensions, is checked:
only ARM64, minimum OS at most 11.0, valid ad-hoc signature, private or system
dependencies only, and no escaping/broken symlinks. The extracted archive is
checked again. An explicit smoke-test completion marker catches premature exits.
Library symlink chains are flattened to direct relative links while retaining
all aliases, so 7-Zip's safe extraction accepts the archive.

The shared movie regression compares exported texture pixels with a reference
image, including a Bitmap subclass like PSDK's Texture. It also checks snapshots
and disposed/uninitialized textures. All three platform verifiers run this
regression through `tests/runtime-functional.rb`; audio-only loading does not
exercise these interfaces. The macOS verifier requires a completion marker to
detect premature exits.

The deployment target is a compatibility constraint, not proof of testing on
every OS/hardware model. The hosted workflow is configured to build and test on
macOS 14 and verify extracted archives on macOS 15 and 26. Results must be checked
for the revision being released. macOS 11/12/13
machines and a complete Pokémon SDK game still need testing before claiming
coverage of every Apple Silicon macOS release.

Signing is ad-hoc, required after modifying ARM64 binaries. Developer ID signing
and notarization belong to the distributable game/application and are not
performed here. Only `libfmod.dylib` is packaged from FMOD; SDK files remain
ignored build inputs. The repository's existing FMOD licensing conditions apply.
