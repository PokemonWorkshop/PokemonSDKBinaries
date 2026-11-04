# Linux dependencies

For commands, see [README.md](README.md). Build implementation details are in
[BUILD-NOTES.md](BUILD-NOTES.md).

## Pinned inputs

[config/linux-x86_64.conf](../../config/linux-x86_64.conf) pins component
repositories and revisions. [The source lock](../../config/linux-x86_64-sources.lock)
pins source archives by name, SHA-256 and URL. The shared fetcher verifies them;
Docker builders verify the hashes again before extraction.

## Library versions

Versions below match the source lock. The original selection notes were
recorded on 2026-09-13; subsequent patch updates retain the selected branches
and compatibility constraints. Descriptions such as "current" refer to the
original review rather than a claim about the latest upstream release.

| Dependency | Version | Selection |
| --- | --- | --- |
| Ruby | 3.4.10 | Current 3.4 patch release; retain the application ABI |
| OpenSSL | 3.5.9 | Retain the 3.5 LTS branch, supported until April 2030 |
| libyaml | 0.2.5 | Current stable release; exclude the 0.2.6 release candidate |
| zlib | 1.3.2 | Current stable release |
| libffi | 3.8.0 | Current stable release |
| SFML | 2.6.2 | Retain the SFML 2 API used by the bindings |
| Ogg | 1.3.6 | Current stable release |
| Vorbis | 1.3.7 | Current stable release |
| FLAC | 1.5.0 | Current stable release |
| OpenAL Soft | 1.23.1 | Baseline compiler compatibility; a previous Linux build with 1.24.3 failed on constexpr code |
| FreeType | 2.14.3 | Current stable release |
| HarfBuzz | 14.4.0 | Current stable release |
| FriBidi | 1.0.16 | Current stable release |
| libass | 0.17.5 | Current stable release |
| FFmpeg | 6.1.6 | Current 6.1 patch release; retain the 6.x library ABI |

FMOD Core is 2.02.20. LiteRGSS2/LiteCGSS, RubyFMOD, SFMLAudio, native sfeMovie
and its Ruby binding use the immutable component revisions in the configuration.

## System dependencies

OpenGL, X11, ALSA and the system C++ runtime remain host-provided. Fontconfig
and its configuration, Expat, JPEG and ancillary build-distribution libraries
follow AlmaLinux packages rather than independent source pins. The resolved
builder inventory is not a list of files all included in the runtime.

OpenSSL shared libraries are bundled. At launch, `setup.sh` selects the host CA
bundle and respects an explicitly set `SSL_CERT_FILE`.

## Build tools

The manylinux base is pinned by digest and retains glibc 2.28. The builder runs
`dnf upgrade --refresh` before installing tools and integration headers. GCC,
CMake and other RPM tools therefore follow the build distribution. Portable
libraries use `/usr/bin/gcc` and `/usr/bin/g++`.

Ruby build gems are pinned separately as `RAKE_VERSION` (13.2.1) and
`RAKE_COMPILER_VERSION` (1.3.1). This is not a full RPM/toolchain lock or a
claim of byte-for-byte reproducibility.

## Selection notes

Ruby and SFML major upgrades require coordinated ABI/API validation. FFmpeg
retains the 6.x library ABI. FMOD remains at the configured 2.02.20 SDK used by
RubyFMOD. Updating OpenAL requires validating the baseline compiler/toolchain;
the recorded 1.24.3 build failed on constexpr code.

Shared bundled libraries now use these versions on all three platforms. Windows
builds OpenSSL 3.5.9 from the same source archive; macOS keeps its OS-provided
OpenAL, zlib and libffi. The
[pin checker](../../.github/scripts/check-dependency-pins.py) compares source
archives and matching Windows package versions before CI builds. Build-tool
and OS-provided library versions remain platform-specific.

Upstream release references: [Ruby](https://www.ruby-lang.org/en/downloads/),
[OpenSSL](https://openssl-library.org/source/), [libyaml](https://github.com/yaml/libyaml/releases),
[zlib](https://zlib.net/), [libffi](https://github.com/libffi/libffi/releases),
[SFML](https://www.sfml-dev.org/download/), [Xiph codecs](https://xiph.org/downloads/),
[OpenAL](https://github.com/kcat/openal-soft/releases), [FreeType](https://freetype.org/),
[HarfBuzz](https://github.com/harfbuzz/harfbuzz/releases),
[FriBidi](https://github.com/fribidi/fribidi/releases),
[libass](https://github.com/libass/libass/releases), [FFmpeg](https://ffmpeg.org/download.html).
