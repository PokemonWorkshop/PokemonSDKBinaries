# Pokémon SDK Binaries

Ready-to-use Ruby runtimes for [Pokémon SDK](https://gitlab.com/pokemonsdk)
games on Linux, macOS and Windows. Each package includes Ruby **3.4.10** and
the native graphics, audio and movie libraries used by the SDK.

## Download

Get the archive for your platform and `version.json` from the
[latest release](../../releases/latest).

| Platform | Architecture | Download | Requirements |
| --- | --- | --- | --- |
| Linux | x86-64 | `Linux.7z` | glibc 2.28+, OpenGL, X11/XWayland and ALSA-compatible audio |
| macOS | Apple Silicon (ARM64) | `macOS.7z` | Targets macOS 11+; runtime testing on macOS 11–13 remains outstanding |
| Windows | x86 (32-bit) | `Windows.7z` | SDK launcher compatible with the bundled 32-bit Ruby 3.4 runtime |

[Installation instructions](USAGE.md) cover checksum verification, extraction
and launching a game. You do not need to build these packages to use them.

## Component glossary

All three platforms include these components:

| Component | Role |
| --- | --- |
| **Ruby** | The interpreter that runs the SDK and game code, with its standard libraries and bundled gems. |
| **LiteRGSS2** | The SDK's Ruby graphics binding, loaded as `LiteRGSS`. Provides APIs such as bitmaps, sprites and windows. |
| **LiteCGSS** | The native graphics engine used by LiteRGSS2. Included as a submodule of the LiteRGSS2 source repository. |
| **SFML** | Native multimedia libraries used by the graphics, audio and movie components. |
| **SFMLAudio** | The Ruby binding for SFML audio, loaded as `SFMLAudio`. |
| **FMOD Core** | The proprietary native audio engine used through RubyFMOD. |
| **RubyFMOD** | The Ruby binding for FMOD Core, loaded as `RubyFmod` and exposing the `FMOD` API. |
| **FFmpeg** | Native libraries for reading media containers, decoding audio/video and converting media formats in the movie pipeline. |
| **sfeMovie** | The native movie playback library, using FFmpeg for decoding and SFML for presentation. |
| **SFEMovie** | The Ruby binding for sfeMovie, loaded as `SFEMovie` and exposing `SFE::Movie`. Its source checkout is named `sfemovie-ruby` in the build scripts. |

The interpreter and native bindings are built together. Additional native
extensions must match the package's Ruby ABI and architecture. Supporting
library versions and OS-provided dependencies are described in the platform
build guides.

## Build from source

Choose your target platform:

- [Linux x86-64](linux/x86_64/README.md)
- [macOS ARM64](macos/arm64/README.md)
- [Windows x86](windows/x86/README.md)

[CONTRIBUTING.md](CONTRIBUTING.md) explains how to update components, verify
changes and add platforms. [RELEASING.md](RELEASING.md) covers publication for
maintainers. The [runtime test guide](tests/README.md) describes the checks run
on release packages.

## License

The build tooling is [MIT-licensed](LICENSE). Runtime libraries have their own
licences, including FMOD's proprietary terms. Read the
[licensing and redistribution notes](LICENSING.md) before distributing a package.
