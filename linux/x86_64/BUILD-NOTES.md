# Linux build reference

For commands, see [README.md](README.md). Versions and dependency policy are
listed in [DEPENDENCIES.md](DEPENDENCIES.md).

## Toolchain and build layout

The [Linux workflow](../../.github/workflows/build-linux-x86_64.yml) defines the
complete build order and arguments. The LiteRGSS image contains the common Ruby,
SFML and source-built dependencies. RubyFMOD and the SFEMovie Ruby binding reuse
it; the native sfeMovie image inherits it.

| Stage | Entry point |
| --- | --- |
| Fetch sources | `.github/scripts/fetch-sources.sh config/linux-x86_64.conf` |
| Extract the authorized SDK | `linux/x86_64/extract-fmod.sh` |
| Build LiteRGSS, LiteCGSS and SFMLAudio | `linux/x86_64/litergss/build.sh` |
| Build RubyFMOD | `linux/x86_64/rubyfmod/build.sh` |
| Build native sfeMovie | `linux/x86_64/sfemovie/build.sh` |
| Build the Ruby movie binding | `linux/x86_64/sfemovie-ruby/build.sh` |
| Assemble and archive | `linux/x86_64/assemble-release.sh` |
| Verify | `linux/x86_64/verify-release.sh` |

Assembly takes `LITERGSS_DIR`, `RUBY_FMOD_DIR`, `SFEMOVIE_DIR` and
`SFEMOVIE_RUBY_DIR`. The workflow sets each explicitly. The LiteRGSS and native
sfeMovie builders source `config/linux-x86_64.conf`, overriding matching
environment values. RubyFMOD and the movie binding take `RUBY_VERSION` from the
environment (RubyFMOD defaults to 3.4.10); it must match the common image.

A source-lock change invalidates the distribution-package update Docker layer.
To refresh distribution packages alone, discard cached builder layers before
the next build. The package records `linux-sources.lock` and
`linux-distribution-packages.txt` under `lib/psdk-runtime/`; the latter is the
builder's full RPM inventory, not a list of shipped libraries.

## Native build adjustments

- RubyFMOD's [SDK patch](rubyfmod/fmod-sdk.patch) adds `/fmod/inc` and
  `/fmod/lib/x86_64` to its build flags inside the container.
- SFMLAudio's `extconf.rb` receives an explicit `sfml-audio` link dependency.
- The shared binding-preparation script supplies matching LiteRGSS/LiteCGSS
  headers to SFEMovie's Ruby binding.
- libffi disables multi-OS library directories so installation remains under
  the private dependency prefix. The builder registers that prefix with the
  loader for Ruby configuration probes and dependency staging.
- The pinned native sfeMovie includes the upstream channel-layout and fallback
  texture lifetime corrections; no local movie patches are applied.

## Binary audits

Assembly checks the glibc 2.28 symbol baseline and native dependency resolution.
Packaged libraries use `$ORIGIN`-relative loader paths. The movie binding's
build-time path is rewritten during assembly; component builders relocate their
own libraries. Broadly rewriting third-party ELF files is avoided because some
patchelf versions can produce invalid program-header alignment.

Desktop driver/audio integration and the system C++ runtime stay host-provided.
The verifier installs matching host packages into its test container, uses
Xvfb/Mesa and silent audio, then runs the relocated runtime's shared suite.
A separate job checks the archive checksum and repeats verification after
extraction on a fresh runner.

## Compatibility limits

Linux validation has been reported on Ubuntu, Fedora and Arch Linux families.
A previous local `act` run was reported to pass assembly and the shared suite
in glibc 2.28, but its report did not identify a revision or date. It does not
establish validation of later changes. Check CI results for the release revision.
Software rendering and silent audio do not cover physical devices, all drivers
or complete SDK games.
