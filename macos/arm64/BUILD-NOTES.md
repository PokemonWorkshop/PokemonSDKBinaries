# macOS build reference

For commands, see [README.md](README.md). Versions and dependency policy are
listed in [DEPENDENCIES.md](DEPENDENCIES.md).

## Toolchain and build layout

`bootstrap-tools.sh` installs private tools under `generated/macos-arm64-tools/`.
CMake and Ninja use upstream binaries; pkgconf and 7-Zip are built with Apple's
compiler. 7-Zip is built for macOS 11.0 because the pinned upstream Mac binary
requires macOS 26 and cannot run on older CI runners.

Installations are keyed by the tool lock and bootstrap script's SHA-256, so
changes select a new installation rather than reuse old success stamps. Fresh
verification runners use `bootstrap-tools.sh archive` to install only 7-Zip.

CI uses these pinned tools. With `PSDK_BUILD_TOOLS_BIN` unset, local builds can
use installed `cmake`, `ninja`, `pkgconf` and `sevenzip`. Runtime library discovery
still excludes Homebrew prefixes. The build uses ordinary ARM64 flags and a
macOS 11.0 deployment target, without `-march=native` or arm64e.

## Native build adjustments

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

Ruby configure options disable DTrace/JIT build dependencies and optional native
dbm/gdbm/readline extensions; Ruby 3.4's Reline is still bundled. Font rendering
uses source-built FreeType/HarfBuzz/FriBidi/libass with Apple's CoreText provider.
FFmpeg uses generic ARM64 code and shared libraries, disables autodetection and
networking, and enables PNG/mov_text decoding. It does not enable
GPL/nonfree codecs. macOS pins FFmpeg 6.0; Linux pins 6.1.6.

## Binary audits

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

### Distribution signing

Signing is ad-hoc, required after modifying ARM64 binaries. Developer ID signing
and notarization belong to the distributable game/application and are not
performed here. Only `libfmod.dylib` is packaged from FMOD; SDK development files
remain build inputs. See the [licensing notes](../../LICENSING.md).

## Compatibility limits

The deployment target and binary audits constrain architecture, loader paths
and minimum OS requirements. They do not establish runtime coverage on every
macOS release or device. CI is configured for macOS 14, 15 and 26; macOS 11–13
and full SDK game execution remain outstanding. Check results for the revision
being released rather than treating configured jobs as completed validation.
