# Contributing

This repository builds and releases the native runtime used by Pokémon SDK.
Contributions should preserve the SDK's runtime and launcher contracts and make
the resulting packages reproducible, relocatable and verifiable. Platform build
commands belong in the platform documentation; this guide describes what a
contribution needs to establish.

## Getting started

Choose the guide for the target you want to build:

- [Linux x86-64](linux/x86_64/README.md), including local workflow execution
- [macOS ARM64](macos/arm64/README.md), using native Apple tools
- [Windows x86](windows/x86/README.md), using the private MSYS2 toolchain

Make component changes in their upstream repositories first, then update this
repository's pins and any required build adjustments. Run the affected platform
checks described in its guide and report the environments and results with
your contribution. Ordinary branch pushes and pull requests do not trigger the
release workflow; contributors need to run those checks explicitly.

For GitHub secrets, protected tags and publishing, see
[RELEASING.md](RELEASING.md).

Each platform directory uses the same documentation layout:

| Document | Contents |
| --- | --- |
| `README.md` | Requirements, build commands, outputs, rebuilding, verification and compatibility limits |
| `DEPENDENCIES.md` | Pinned inputs, library versions, system dependencies, build tools and selection notes |
| `BUILD-NOTES.md` | Toolchain layout, native build adjustments, binary audits and compatibility limits |

Keep those responsibilities consistent when updating a platform or adding one.
Linux's component-level READMEs provide additional inputs for its separate
builders.

## Workflow and script conventions

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
MSYS2 toolchain. macOS uses `mach_o.py` for binary path rewriting, signature
checks and safe symlink resolution. Its `archive-release.sh` helper tests archive
extraction on macOS. Those operations are separate from shell file assembly.

The scripts share `sources/`, including an archive cache whose filenames contain
the dependency name and extension, but not its version or platform. When changing
targets or source locks, use a fresh checkout or move the old `sources/` directory
aside before fetching again. Otherwise a cached archive from another target can
fail the new lock's checksum check. Source checkouts are disposable build inputs:
builders apply patches and refresh binding headers there.

Platform `.conf` assignments take precedence over environment values when a
script sources that configuration. Paths such as `OUTPUT_DIR` and `ARCHIVE_PATH`
remain caller settings where the corresponding script supports them.

Windows assembly copies the shared legacy require target from
`macos/arm64/clean_load_path.rb`. The shared binding-preparation script is used
by all three platforms. The pinned native sfeMovie revision includes the
channel-layout and fallback-texture lifetime fixes; no local patches are applied
to native sfeMovie.

## Changes to existing components

Merge component changes upstream first, then update immutable repository URLs
and commit pins consistently across the platform configurations in `config/`.
Update source and package locks when dependencies change. Keep shared runtime
library versions aligned; macOS's OS-provided OpenAL, zlib and libffi are explicit
exceptions. Run `python3 .github/scripts/check-dependency-pins.py` to check source
pins, matching Windows package versions and platform configurations. All three
CI builders run this check. Document any necessary platform differences instead
of silently letting ports diverge.

Keep Ruby version and ABI changes coordinated across platforms, launchers and
tests. A dependency update also needs compatibility validation: a newer release
can require a newer compiler, OS baseline or library ABI. The
[Linux dependency notes](linux/x86_64/DEPENDENCIES.md) describe examples of these
constraints. Validate every affected platform before maintainers publish a new
protected `v*` tag.

## Adding an OS or architecture

Treat each OS/architecture pair as a separate release target. An additional
architecture on an existing OS needs the same build, packaging and verification
evidence as a new OS.

### Define the support contract

Describe the intended architecture, minimum OS or libc version, Ruby ABI,
launcher interface and required host graphics/audio libraries. Distinguish the
compatibility target from the OS versions and hardware actually tested. For
example, macOS targets 11.0, while its hosted workflow runs on newer releases;
a deployment-target flag alone does not establish runtime coverage.

Establish that a suitable toolchain, CI runner or execution environment and
authorized FMOD SDK/runtime exist for the target. Explain whether builds are
native or cross-compiled and how the resulting binaries will run during
verification. Cross-compilation alone does not validate the runtime. Document
hardware, driver and full-game testing that remains outstanding.

Use the existing naming conventions consistently:

| Purpose | Current examples | Convention for a new target |
| --- | --- | --- |
| Platform tooling | `linux/x86_64/`, `macos/arm64/`, `windows/x86/` | `<os>/<architecture>/` |
| Configuration | `config/linux-x86_64.conf` | `config/<os>-<architecture>.conf` |
| Source lock | `config/linux-x86_64-sources.lock` | Adjacent to the configuration |
| Reusable workflow | `.github/workflows/build-linux-x86_64.yml` | `build-<os>-<architecture>.yml` |
| Internal CI artifact | `Linux-x86-64`, `MacOS-arm64`, `Windows-x86` | A unique OS/architecture name |
| Public archive | `Linux.7z`, `macOS.7z`, `Windows.7z` | The public OS name with a `.7z` extension |
| Release manifest key | `linux`, `macos`, `windows` | The public archive name lowercased, without `.7z` |

Directory/configuration names and public archive names use the existing spellings
shown above; do not rename established targets as part of adding a port.

### Keep sources and builds controlled

Centralize versions, component repository URLs, immutable commit pins and target
settings in the platform configuration. Match the existing component revisions
and embedded Ruby version unless a difference is explicitly justified. The
runtime includes LiteRGSS2/LiteCGSS, SFML, SFMLAudio, RubyFMOD/FMOD Core,
sfeMovie/FFmpeg and the SFEMovie Ruby binding.

Pin source archives by URL and SHA-256 using the existing
`name sha256 source-url` lock format. Pin downloaded toolchains and package
dependencies where those form the private build environment, as Windows does.
Reuse [source fetching](.github/scripts/fetch-sources.sh),
[FMOD downloading](.github/scripts/download_fmod.py) and
[Ruby binding preparation](.github/scripts/prepare-sfemovie-ruby.sh) where
applicable. Extend their target handling when necessary; do not assume the
current scripts already support another OS or architecture.

Separate source fetching, compilation, assembly and verification. Retain upstream
build definitions, and apply necessary patches to disposable build checkouts.
Explain each workaround, its upstream status and the behavior it fixes. Preserve
existing regressions, including sfeMovie channel-layout handling and texture
lifetime/ABI checks; determine which adjustments apply to the new target.

Keep generated sources, SDKs, outputs and caches in ignored working directories.
Use fresh outputs when configuration or toolchain changes invalidate build
stamps. Assembly should refuse to merge into an existing non-empty payload.
Limit cleanup to generated inputs/outputs and preserve useful failure diagnostics.
If Docker is used, check its build context, `COPY` paths and ignore filters as
well as shell paths.

Document what is pinned and what follows the build OS's maintained packages.
Pinned inputs do not by themselves guarantee byte-for-byte reproducibility.

### Package a usable, relocatable runtime

Preserve the consuming SDK's expected layout and launch mode. Linux and macOS
archives wrap the runtime in `ruby-dist/` with `bin/`, `lib/`, `setup.sh` and
`BUILD-INFO`. Windows has a legacy layout with root Ruby executables and runtime
DLL, `lib/` and a private `ruby_builtin_dlls/` assembly. Use the appropriate
contract for the new target and document any required launcher changes.

Build extensions against the bundled Ruby and matching LiteRGSS/LiteCGSS headers.
Include the necessary standard libraries, bundled gems and transitive native
dependencies. Keep system integration libraries host-provided where required
by the target's graphics/audio stack, and document that boundary. Preserve
certificate handling and isolation from host Ruby/gem paths.

Audit the complete payload for architecture, ABI and minimum OS/libc requirements,
unresolved native dependencies, build-machine paths and unsafe or broken
symlinks. Use the target's loader conventions: Linux library paths, macOS
loader-relative install names and signatures, or Windows PE imports and private
assembly manifests. Archives must preserve the files, permissions and links
needed after extraction, including extraction into a path containing spaces.

Ship component build information and applicable third-party license notices.
Only the required FMOD runtime belongs in the payload; SDK headers, static/import
libraries and installers remain build inputs. Follow the existing
[FMOD runtime and licensing notes](LICENSING.md#fmod-runtime-and-licensing).
Document signing requirements and distinguish runtime build signing from any
game/application distribution signing or notarization.

For shell-based ports, follow the Linux/macOS interfaces where practical:
assemblers accept `OUTPUT_DIR` and optional `ARCHIVE_PATH`; verifiers accept
`RELEASE_DIR`. Other interfaces should remain explicit and documented, as on
Windows.

### Verify the shipped package

Run the [shared functional suite](tests/README.md) from the relocated runtime
using its bundled Ruby. Extend the target expectations in
[runtime-functional.rb](tests/runtime-functional.rb), including Ruby platform,
pointer size and codec/utility-library paths. The current expectations are specific to
the three existing targets; adding an architecture may require changing how the
test selects a target. Preserve assertions for existing platforms.

Verification must exercise standard libraries and gems, all native bindings,
the fixed shader pipeline, FMOD/SFML audio decoding, sfeMovie playback and
required FFmpeg decoders, actual video pixels, texture subclasses, snapshots,
disposed/uninitialized objects and normal shutdown. Loading an extension alone
does not establish that its native interfaces work.

Provide a working graphics environment; graphics regressions must fail rather
than be silently skipped. Use silent audio backends where appropriate for CI.
Test the actual SDK launch modes, including GUI launchers and gems-disabled
flags when relevant. Isolate the payload from development tools, host gems and
build-library search paths. Use completion markers when a launcher can exit
before the test finishes.

Keep binary/layout audits alongside functional checks. Verify the assembled
payload, then download the archive on a fresh runner, check its internal SHA-256
sidecar, extract it and verify the extracted runtime again without relying on
the build toolchain. Explain coverage limits in the platform documentation.

### Integrate with CI and publication

Add a reusable workflow with `workflow_call`, explicit required FMOD secrets,
read-only permissions and GitHub Actions pinned by commit. Follow the existing
separate `build` and dependent `verify` jobs. Upload the `.7z` archive and SHA-256
sidecar as internal CI artifacts; unsuccessful checks must prevent publication.

Keep [release.yml](.github/workflows/release.yml) as the sole protected-tag entry
point and publisher. Do not add an independent tag publisher or broaden its
trigger to branch pushes, pull requests or manual dispatch. Platform workflows
have no manual triggers. Preserve the release authorization job and make new
platform callers depend on it; unprotected tags must fail before builds start.
Keep authenticated SDK downloads out of untrusted workflows, avoid exposing
credentials in logs, and remove temporary SDK material from CI workspaces.

Release integration currently requires explicit updates in several places:

- Call the reusable workflow after `authorize_release` and pass its required secrets.
- Add the target to the final publication job's `needs`, so its build and fresh
  verification both gate the release.
- Download its artifact into `dist/` and check the archive and SHA-256 sidecar.
- Add its public archive basename (without `.7z`) to the `version.json` generation loop and the
  archive to the publication `assets` array.
- Keep dry-run output accurate and include the target in documentation.

The release publishes runtime archives and one `version.json`. Its `version`
is the tag with the leading `v` removed; each lowercased OS key
contains the SHA-1 of the corresponding final `.7z` bytes. These are legacy OS
keys (`linux`, `macos`, `windows`), without architecture suffixes. If adding a
second architecture for an existing OS, agree on its public archive name and
manifest key with maintainers and consuming launchers so packages cannot collide;
preserve existing public names and keys. Generate the manifest only after
all archive checks pass. SHA-256 sidecars stay internal to CI. Preserve both
release creation and existing-release upload behavior and the
`RELEASE_DRY_RUN=true` path; do not introduce release cleanup or migration steps.

### Make the contribution reviewable

Add platform documentation covering prerequisites, local entry points, output
layout, dependency choices, upstream adjustments, verification and known limits.
Update the README's platform table, download instructions and workflow/script
references, plus shared test documentation if target handling changes.

In the contribution, state the support contract and rationale, the relevant
component/dependency changes, checks actually run and their environments, and
remaining gaps. Include build/verification results for the new target and checks
for existing targets affected by shared changes. Clearly separate local testing,
hosted CI results and full Pokémon SDK game testing. A port is ready for tagged
releases when its complete archive can pass the required audits and functional
checks on the documented target environment.
