# Install and use a runtime

Download the archive for your platform and `version.json` from the
[latest release](../../releases/latest). Use files from the same release.
The manifest records the release version and each archive's SHA-1 hash.

## Verify the download

Run the command for your platform in the download directory:

| Platform | Command | Compare with this `version.json` field |
| --- | --- | --- |
| Linux | `sha1sum Linux.7z` | `linux` |
| macOS | `shasum -a 1 macOS.7z` | `macos` |
| Windows PowerShell | `Get-FileHash Windows.7z -Algorithm SHA1` | `windows` |

The computed hash must match the manifest value; uppercase and lowercase hex
letters represent the same hash. If it differs, download the matching archive
and manifest again before extracting. The public manifest uses SHA-1 for SDK
launcher compatibility; the release pipeline's SHA-256 sidecars are internal
CI artifacts.

Extract with a 7-Zip-compatible tool. Keep the archive's directory structure
and, on Linux/macOS, file permissions and symbolic links.

## Linux and macOS

These archives contain `ruby-dist/`. Keep the directory intact and place it
where your SDK launcher expects its embedded runtime:

```text
ruby-dist/
├── bin/
├── lib/
├── setup.sh
└── BUILD-INFO
```

From Bash, source the runtime environment before launching the game:

```bash
source /path/to/ruby-dist/setup.sh
```

This selects the bundled Ruby and Ruby library paths for the current shell.
Linux also sets the native-library search path. macOS resolves native libraries
relative to the packaged binaries and does not need `DYLD_LIBRARY_PATH`.

For a project whose entry point is `Game.rb`, a direct launch looks like:

```bash
cd /path/to/game
source /path/to/ruby-dist/setup.sh
ruby Game.rb
```

Use your project's actual entry point or existing SDK launcher. The required
runtime placement is determined by that launcher; this repository does not
supply a game launcher.

Linux needs the host's OpenGL driver, X11/XWayland libraries and ALSA-compatible
audio stack. macOS packages target Apple Silicon; Intel Macs are not covered
by this runtime.

## Windows

Extract the archive into your application directory. Its root contains:

```text
ruby.exe
rubyw.exe
msvcrt-ruby340.dll
lib/
ruby_builtin_dlls/
```

Keep these files and folders together, then start the game with its SDK launcher.
`ruby.exe` is the console executable; `rubyw.exe` is the GUI executable. Both are
32-bit and require extensions built for the same architecture and Ruby ABI.

The runtime DLL and `ruby_builtin_dlls/` directory must remain alongside the
executables. Do not flatten that directory or move its DLLs into `lib/`.
The package includes its certificate bundle at `lib/cert.pem`.

See the [Windows runtime guide](windows/x86/README.md) for the full file layout
and the SDK's gems-disabled launch mode.

## Replacing an older runtime

Use a package compatible with your SDK version and launcher. Native extensions
built for older Ruby ABIs must be rebuilt for Ruby 3.4; preserving an older
archive's layout does not make its binaries compatible.

Package build information is in `BUILD-INFO` on Linux/macOS and
`lib/psdk-runtime/BUILD-INFO` on Windows. Include it, your OS/architecture and
the launch error when reporting a runtime problem.

Before redistributing the runtime with a game, read the
[licensing notes](LICENSING.md).
