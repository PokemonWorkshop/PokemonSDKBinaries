# Linux dependency policy

`config/linux-x86_64-sources.lock` uses `name sha256 source-url`, like the macOS
source lock. `.github/scripts/fetch-sources.sh` downloads and checks these archives;
the Docker builders check the hashes again before extraction. No runtime source
archive is selected through a moving `latest` URL.

The Linux workflow uses `litergss/build.sh` in this repository. It reuses the pinned
LiteRGSS staging script, but owns the dependency builds instead of inheriting the
upstream Dockerfile's old distribution libraries. RubyFMOD and SFEMovie's Ruby
binding reuse that image; the native sfeMovie image inherits it too.

## Source versions selected on 2026-09-13

| Dependency | Version | Selection |
| --- | --- | --- |
| Ruby | 3.4.10 | Current 3.4 patch release; retain the application ABI |
| OpenSSL | 3.5.8 | Current 3.5 LTS release, supported until April 2030 |
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

Upstream release references: [Ruby](https://www.ruby-lang.org/en/downloads/),
[OpenSSL](https://openssl-library.org/source/), [libyaml](https://github.com/yaml/libyaml/releases),
[zlib](https://zlib.net/), [libffi](https://github.com/libffi/libffi/releases),
[SFML](https://www.sfml-dev.org/download/), [Xiph codecs](https://xiph.org/downloads/),
[OpenAL](https://github.com/kcat/openal-soft/releases), [FreeType](https://freetype.org/),
[HarfBuzz](https://github.com/harfbuzz/harfbuzz/releases),
[FriBidi](https://github.com/fribidi/fribidi/releases),
[libass](https://github.com/libass/libass/releases), [FFmpeg](https://ffmpeg.org/download.html).

Ruby/SFML major upgrades and an OpenAL compiler/toolchain migration require separate
compatibility work. FMOD remains the explicitly configured 2.02.20 SDK required
by the existing RubyFMOD binding. Component Git revisions remain in
`config/linux-x86_64.conf`, including SFMLAudio.

## Distribution and host dependencies

The manylinux base remains pinned by digest and retains glibc 2.28. The builder
runs `dnf upgrade --refresh` before installing build tools and system integration
headers. Fontconfig and its system configuration, Expat, JPEG, and ancillary
distribution libraries follow AlmaLinux's maintained packages, rather than
independent upstream source releases. Distribution build tools remain outside
the runtime source lock; Ruby build gems are pinned separately as `RAKE_VERSION`
and `RAKE_COMPILER_VERSION` in `config/linux-x86_64.conf`. This is not a complete RPM/toolchain lock or a
claim of bit-for-bit reproducibility.

A source-lock change invalidates the package-update Docker layer. To refresh
distribution packages alone when reusing local Docker caches, discard the cached
builder layers before the next local build.

The released `lib/psdk-runtime/` directory records `linux-sources.lock` and
`linux-distribution-packages.txt`. The latter is the full resolved builder RPM
inventory, not a list of libraries all bundled into the game.

Portable source libraries use the baseline `/usr/bin/gcc` and `/usr/bin/g++`.
OpenGL, X11, ALSA, and the C++ runtime continue to come from the player's system.
OpenSSL's shared libraries are bundled, while `setup.sh` selects the host CA
bundle and respects an explicitly set `SSL_CERT_FILE`.

## Validation evidence

A previous local `act` run was reported to pass assembly and the shared
functional suite in the glibc 2.28 container. That report did not identify a
revision or execution date, so it does not establish validation of later changes.
The workflow defines build and fresh-archive verification jobs; their presence
alone does not establish that a particular revision passed hosted CI.

Local runs skip GitHub artifact upload and retain `dist/Linux.7z`.
Run the Linux `act workflow_call` command in the repository README to exercise
the complete build and existing runtime checks.
