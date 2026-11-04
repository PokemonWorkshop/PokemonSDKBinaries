# macOS dependencies

For commands, see [README.md](README.md). Build implementation details are in
[BUILD-NOTES.md](BUILD-NOTES.md).

## Pinned inputs

[config/macos-arm64.conf](../../config/macos-arm64.conf) pins component repositories,
revisions and target settings. [The source lock](../../config/macos-arm64-sources.lock)
pins source archives by name, SHA-256 and URL.
[The tool lock](../../config/macos-arm64-tools.lock) pins bootstrap downloads.

## Library versions

| Dependency | Version | Supplied by |
| --- | --- | --- |
| Ruby | 3.4.10 | Source |
| OpenSSL | 3.5.9 | Source |
| libyaml | 0.2.5 | Source |
| SFML | 2.6.2 | Source |
| Ogg | 1.3.6 | Source |
| Vorbis | 1.3.7 | Source |
| FLAC | 1.5.0 | Source |
| FreeType | 2.14.3 | Source |
| HarfBuzz | 14.4.0 | Source |
| FriBidi | 1.0.16 | Source |
| libass | 0.17.5 | Source |
| FFmpeg | 6.1.6 | Source |
| FMOD Core | 2.02.20 | Authorized SDK |
| OpenAL | OS version | Apple framework |
| zlib / libffi | OS version | Apple system libraries |

Component Git revisions for LiteRGSS2/LiteCGSS, RubyFMOD, SFMLAudio, native
sfeMovie and its Ruby binding are recorded in the platform configuration.

## System dependencies

Apple frameworks, libSystem, libc++, libiconv, libffi and zlib are system-provided.
SFML uses Apple's OpenAL framework; subtitle font discovery uses CoreText.
Homebrew runtime libraries are excluded from dependency discovery.

## Build tools

Apple Clang and the macOS SDK come from Xcode/Command Line Tools. Bootstrap pins
CMake 4.4.4, Ninja 1.13.2, pkgconf 3.0.7 and 7-Zip 26.03. Tools are private build
inputs and are not shipped. Local alternative tool selection is described in
[BUILD-NOTES.md](BUILD-NOTES.md#toolchain-and-build-layout).

## Selection notes

Shared bundled libraries use the same versions as Linux and Windows. Source
archives shared with Linux have identical URLs and SHA-256 hashes. macOS keeps
Apple's OpenAL, zlib and libffi for system integration; those remain OS-versioned.
Font rendering uses source-built FreeType/HarfBuzz/FriBidi/libass with CoreText.

[The pin checker](../../.github/scripts/check-dependency-pins.py) enforces this
boundary before CI builds. It does not claim that compiler, SDK or OS-provided
library versions are identical between platforms. The aligned dependency update
still needs native CI verification on the documented macOS targets.
