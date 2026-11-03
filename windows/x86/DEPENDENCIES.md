# Windows dependencies

For commands, see [README.md](README.md). Build implementation details are in
[BUILD-NOTES.md](BUILD-NOTES.md).

## Pinned inputs

[config/windows-x86.conf](../../config/windows-x86.conf) pins component repositories,
revisions and target settings. [The source lock](../../config/windows-x86-sources.lock)
pins source archives by name, SHA-256 and URL.
[The package lock](../../config/windows-x86-packages.lock) pins the private
MSYS2 packages, including transitive prerequisites, by URL and SHA-256.
OpenSSL 3.5.9 is built from the shared source archive into the private dependency
prefix. The toolchain retains its locked OpenSSL 3.6.4 package for build tools;
that package does not supply the shipped Ruby runtime's OpenSSL.

## Library versions

| Dependency | Version | Supplied by |
| --- | --- | --- |
| Ruby | 3.4.10 | Source |
| SFML | 2.6.2 | Source |
| FFmpeg | 6.1.6 | Source |
| OpenAL Soft | 1.23.1 | Source |
| FriBidi | 1.0.16 | Source |
| libass | 0.17.5 | Source |
| OpenSSL | 3.5.9 | Source |
| libyaml | 0.2.5 | MSYS2 package |
| zlib | 1.3.2 | MSYS2 package |
| libffi | 3.8.0 | MSYS2 package |
| Ogg | 1.3.6 | MSYS2 package |
| Vorbis | 1.3.7 | MSYS2 package |
| FLAC | 1.5.0 | MSYS2 package |
| FreeType | 2.14.3 | MSYS2 package |
| HarfBuzz | 14.4.0 | MSYS2 package |
| FMOD Core | 2.02.20 | Authorized SDK |

Component Git revisions for LiteRGSS2/LiteCGSS, RubyFMOD, SFMLAudio, native
sfeMovie and its Ruby binding are recorded in the platform configuration.
Windows package revision suffixes, where applicable, remain in the package lock.

## System dependencies

Windows provides its system APIs, including OpenGL and window/audio integration.
Non-system DLL dependencies are staged into the private runtime assembly,
including required MinGW runtime DLLs. libass is built without Fontconfig.
The bundled certificate file is copied from the locked MSYS2 environment.

## Build tools

The pinned MSYS2 packages supply MinGW GCC 16.2.0, CMake 4.4.3, Ninja 1.13.2 and
pkgconf 3.0.7. The compiler targets `i686-w64-mingw32` with MSVCRT. A hashed
RubyInstaller 3.4.10 x86 package provides the bootstrap interpreter for the
source-built Ruby. Bootstrap also downloads pinned standalone 7-Zip 26.03 tools.

## Selection notes

Shared runtime libraries match the Linux source selections. Libraries supplied
by MSYS2 use the same upstream versions, even though their package release
suffixes and build options are platform-specific. OpenSSL is source-built so
all three runtimes use 3.5.9, while the private toolchain can keep its own 3.6.4
package. OpenAL Soft 1.23.1 retains the compiler include workaround documented
in the build notes.

[The pin checker](../../.github/scripts/check-dependency-pins.py) compares source
archives, matching MSYS2 runtime package versions and component configuration
pins before CI builds. The shared runtime suite checks OpenSSL's compiled and
loaded library versions and FFmpeg's loaded version. The aligned dependency
update still needs native Windows CI verification. Package pinning does not
by itself establish byte-for-byte reproducibility.
