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
| OpenSSL | 3.5.8 | Source |
| libyaml | 0.2.5 | Source |
| SFML | 2.6.2 | Source |
| Ogg | 1.3.5 | Source |
| Vorbis | 1.3.7 | Source |
| FLAC | 1.4.3 | Source |
| FreeType | 2.13.3 | Source |
| HarfBuzz | 10.4.0 | Source |
| FriBidi | 1.0.16 | Source |
| libass | 0.17.3 | Source |
| FFmpeg | 6.0 | Source |
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

SFML stays on the 2.x API and Ruby stays on the shared 3.4 ABI. Font libraries
are built from source with Apple's CoreText integration. FFmpeg 6.0 and the
older Ogg, FLAC, FreeType, HarfBuzz and libass selections differ from Linux;
the repository does not record a compatibility requirement for every difference.
Do not infer that those exact versions are mandatory.
