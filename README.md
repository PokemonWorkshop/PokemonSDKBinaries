# Pokémon SDK Binaries

Prebuilt runtime packages for projects made with [Pokémon SDK](https://gitlab.com/pokemonsdk). This repository builds, validates, and publishes the native libraries required by the SDK; it is not the Pokémon SDK source repository itself.

## Platform support

| Platform | Architecture | Status |
| --- | --- | --- |
| Linux | x86-64 | Tagged releases |
| Windows | x86 (32-bit) | Tagged releases |
| macOS | ARM64 (Apple Silicon) | Tagged releases |

The protected-tag release workflow builds and verifies all three packages before publication. Each package embeds **Ruby 3.4.10**.

The Linux package is built for a **glibc 2.28** baseline. It has been validated on distributions in the Ubuntu, Fedora, and Arch Linux families. The runtime expects a typical desktop graphics and audio stack: the system OpenGL driver, X11/XWayland libraries, and an ALSA-compatible audio stack.

The macOS package targets **macOS 11.0 and later**. CI builds and tests on macOS 14, with separate archive verification on macOS 15 and 26; macOS 11–13 still need runtime testing. Windows CI builds and verifies the 32-bit package on Windows Server 2022.

Build instructions and validation details: [Linux](linux/x86_64/DEPENDENCIES.md), [Windows](windows/x86/README.md), and [macOS](macos/arm64/README.md).

## Download and use

Download `Linux.7z`, `macOS.7z` or `Windows.7z` and `version.json` from the [latest release](../../releases/latest), verify the archive against its SHA-1 hash in the manifest, then extract it. The Linux and macOS archives contain one top-level directory named `ruby-dist/`:

```text
ruby-dist/
├── bin/
├── lib/
├── setup.sh
└── BUILD-INFO
```

Place `ruby-dist/` where your Pokémon SDK project expects its embedded Ruby runtime. Before starting the game, load the environment prepared by `setup.sh` from Bash:

```bash
source /path/to/ruby-dist/setup.sh
```

`setup.sh` selects the bundled Ruby and Ruby load path for the current shell. Linux also sets the native-library search path; macOS uses loader-relative library paths. `BUILD-INFO` records the component revisions used for that package.

The Windows archive contains `lib/` and `ruby_builtin_dlls/` directly, alongside the bundled `ruby.exe`, `rubyw.exe` and `msvcrt-ruby340.dll`. Extract them together into your application directory. Its DLL assembly manifest is generated from the packaged dependencies; see the [Windows documentation](windows/x86/README.md).

## Included Linux runtime

The Linux x86-64 package contains:

- LiteRGSS2 and LiteCGSS
- Embedded Ruby 3.4.10
- SFML and SFMLAudio
- RubyFMOD and FMOD Core 2.02.20
- sfeMovie, FFmpeg 6.1.6, and the `SFEMovie` Ruby binding

FFmpeg includes the `png` and `mov_text` decoders required by the SDK's movie support. Graphics drivers, X11 integration, ALSA, and the system C++ runtime remain host-provided so they can match the target distribution and desktop driver stack.

Linux source dependencies are pinned by URL and SHA-256 in
[config/linux-x86_64-sources.lock](config/linux-x86_64-sources.lock), using the
same format and archive fetcher as macOS. The repository-owned Linux Docker
builders consume these archives. See [Linux dependency notes](linux/x86_64/DEPENDENCIES.md)
for selected versions, compatibility constraints, and distribution packages.

## Releases

Releases are produced by GitHub Actions when a protected tag beginning with `v` is pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow checks out immutable component revisions, builds the runtime in a `manylinux_2_28` environment, assembles `Linux.7z`, and smoke-tests the completed payload in a separate glibc 2.28 container before publishing it.

Like macOS and Windows, Linux also has a separate `verify` job on a fresh runner.
It downloads the archive and SHA-256 sidecar, checks the checksum, extracts the
archive, and runs the existing glibc 2.28 functional checks. Publication waits
for both the build and verification jobs to succeed.

All three platforms run the same [runtime functional suite](tests/README.md), covering Ruby libraries, native bindings, audio decoding, movie playback and actual video pixels, alongside platform-specific binary audits.

The final publication job also generates `version.json`. It retains the legacy
manifest format: `version` is the release tag without its leading `v`, and
`linux`, `macos` and `windows` contain the SHA-1 hashes of their
respective `.7z` archives. Only the archives and `version.json` are published.
SHA-256 sidecars remain internal CI artifacts for verification.

Normal branch pushes and pull requests do not run the release workflow.

The same protected tag builds `macOS.7z` with Ruby **3.4.10** on Apple
Silicon, and `Windows.7z` for 32-bit Windows. All three platforms must pass
their checks before publication. See the
[macOS build documentation](macos/arm64/README.md) for local commands, build
tooling, upstream adjustments and compatibility-testing limits.

## Building locally

The workflow is the supported release path. For local CI-style testing, install Docker and [act](https://github.com/nektos/act), configure the FMOD credentials described below, then run the Linux job from this repository:

```bash
act workflow_call \
  -W .github/workflows/build-linux-x86_64.yml \
  -P ubuntu-24.04=ghcr.io/catthehacker/ubuntu:act-24.04 \
  --bind \
  -s FMOD_USER \
  -s FMOD_PASSWORD
```

`--bind` is required for this workflow because Docker build containers need access to component source directories created by `act`. Artifacts created by `act` are local test output; GitHub Releases are published only by GitHub Actions.

The build job deletes `sources/`, `generated/` and `dist/` before starting.
With `--bind`, these are directories in your local checkout. Move any source
edits or build results you want to keep outside those directories before running
the command.

The command runs both `build` and `verify`. Local runs skip artifact upload and
download, passing the archive through the shared `dist/` directory. Add `-j build`
only when you want to omit the separate archive verification job.

To exercise publication in a local run of `release.yml` without creating or
changing a GitHub Release, add:

```bash
--env RELEASE_DRY_RUN=true
```

`RELEASE_DRY_RUN` only suppresses publication in the final job; it does not
bypass protected-tag authorization or the platform builds and verification.
The complete release also requires native macOS and Windows jobs; `act`'s Linux
containers cannot run those jobs. The reusable Linux workflow can be tested
independently with the command above.

### Workflow and script conventions

Platform tooling lives in `linux/x86_64/`, `macos/arm64/` and `windows/x86/`.
The Linux directory includes its Docker builders and release scripts.

`release.yml` is the only protected-tag entry point and the only publisher.
It calls `build-linux-x86_64.yml`, `build-macos-arm64.yml` and
`build-windows-x86.yml`, all reusable workflows with read-only permissions
and explicit FMOD secrets.

| Responsibility | Linux | macOS | Windows |
| --- | --- | --- | --- |
| Configuration | `config/linux-x86_64.conf` | `config/macos-arm64.conf` | `config/windows-x86.conf` |
| Source fetching | `.github/scripts/fetch-sources.sh` | Same shared shell script | `windows/x86/run.ps1 fetch` |
| Authorized SDK download | `.github/scripts/download_fmod.py` | Same shared Python script | `windows/x86/run.ps1 download-fmod` |
| SDK extraction | `linux/x86_64/extract-fmod.sh` | `macos/arm64/extract-fmod.sh` | `windows/x86/download-fmod.sh` |
| Assembly | `linux/x86_64/assemble-release.sh` | `macos/arm64/assemble-release.sh` | `windows/x86/run.ps1 assemble` |
| Verification | `linux/x86_64/verify-release.sh` | `macos/arm64/verify-release.sh` | `windows/x86/verify-runtime.ps1` |

Linux and macOS assemblers take `OUTPUT_DIR` and optional `ARCHIVE_PATH`, and refuse non-empty
destinations. Their verifiers take `RELEASE_DIR`. Windows uses the commands and
payload paths documented in its [build guide](windows/x86/README.md).
Compilation remains platform-specific: Linux uses Docker component builders;
macOS uses native shell build stages; Windows uses a private, checksum-pinned
MSYS2 toolchain. macOS retains `mach_o.py` for binary path rewriting, signature
checks and safe symlink resolution. Its `archive-release.sh` helper tests archive
extraction on macOS. Those operations are separate from shell file assembly.

The scripts share `sources/`, including an archive cache whose filenames contain
the dependency name and extension, but not its version or platform. When changing
targets or source locks, use a fresh checkout or move the old `sources/` directory
aside before fetching again. Otherwise a cached archive from another target can
fail the new lock's checksum check. Source checkouts are disposable build inputs:
builders apply patches and refresh binding headers there.

Platform `.conf` assignments take precedence over environment values when a
script sources that configuration. In particular, the Linux LiteRGSS and native
sfeMovie builders read their Ruby version from `config/linux-x86_64.conf`.
The Linux RubyFMOD and SFEMovie Ruby binding builders instead take `RUBY_VERSION`
from the environment (RubyFMOD defaults to 3.4.10); it must match the LiteRGSS
image. Paths such as `OUTPUT_DIR` and `ARCHIVE_PATH` remain caller settings where
the corresponding script supports them.

Windows assembly copies the shared legacy require target from
`macos/arm64/clean_load_path.rb`. The shared binding-preparation script is used
by all three platforms. The pinned native sfeMovie revision includes the
channel-layout and fallback-texture lifetime fixes; no local patches are applied
to native sfeMovie.

## Maintainer notes

### Required GitHub Actions secrets

Create these **repository Actions secrets** under **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
| --- | --- |
| `FMOD_USER` | FMOD account username or email authorized to download the SDK |
| `FMOD_PASSWORD` | Password for that FMOD account |

The release workflow passes these secrets to all three platform builders to obtain their FMOD SDKs. None of the platform workflows has a manual trigger. Never commit them, add them as Actions variables, or expose them to pull-request workflows. A dedicated FMOD account with the minimum required download entitlement is recommended.

### Release security

Protect the `v*` tag pattern with a GitHub ruleset and allow only maintainers or the release team to create, update, or delete matching tags. This is essential because a tag push authorizes the workflow to access the FMOD secrets and publish a release.

An authorization job checks that the event is a `v*` tag push and GitHub reports
the tag as protected. It fails before any platform build starts if that check
fails. Configure an active tag ruleset in the release repository (and any fork
used for tagged CI testing); the workflow cannot create that repository setting
or determine who the ruleset permits solely from the protection flag.

`release.yml` has no branch-push, pull-request, or manual-dispatch trigger. The workflows pin component source commits and GitHub Actions by revision, restrict default permissions to read-only, and grant release-write permission only to the final publication job.

### FMOD runtime and licensing

The releases contain only the platform's FMOD runtime library (`libfmod.so`, `libfmod.dylib` or `fmod.dll`). They do **not** publish FMOD SDK headers, static libraries, import libraries, or other development files.

That separation alone does not automatically grant redistribution rights. FMOD is proprietary software, and the [FMOD EULA](https://www.fmod.com/legal) requires the FMOD Engine to be integrated and redistributed in a qualifying software application/product, subject to the licence tier and its conditions. In particular, the EULA's listed licence grants restrict distribution as part of a game engine or tool set. Maintainers and downstream projects must confirm that their intended distribution is covered by the applicable FMOD licence before publishing or redistributing a package.

The authenticated CI download approach was informed by the open-source [utopia-rise/fmod-gdextension](https://github.com/utopia-rise/fmod-gdextension) project. Thank you to its contributors for publishing a useful reference for downloading the FMOD SDK in CI.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for component-update guidelines and the
requirements for adding an OS or architecture, including packaging, verification
and release integration.

See [TODO.md](TODO.md) for remaining documentation and maintainability work.

## License

The build and release tooling in this repository is available under the [MIT License](LICENSE). Bundled third-party runtime libraries remain subject to their respective licences.
