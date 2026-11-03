# Build the Linux x86-64 runtime

This guide builds `Linux.7z` with Ruby 3.4.10 and a glibc 2.28 baseline.
To use a prebuilt package, follow the
[installation instructions](../../USAGE.md#linux-and-macos).

## Requirements

- Docker and [act](https://github.com/nektos/act) for local workflow execution.
- An FMOD account authorized to download the Core 2.02.20 SDK.

Supply `FMOD_USER` and `FMOD_PASSWORD` as local workflow secrets; see
[credential handling](../../RELEASING.md#required-github-actions-secrets).
The build downloads its sources, SDK and container dependencies.

## Build and package

The build job deletes `sources/`, `generated/` and `dist/` before starting.
With `--bind`, those are directories in your checkout. Move any edits or results
you want to retain outside them first. Run from the repository root:

```bash
act workflow_call \
  -W .github/workflows/build-linux-x86_64.yml \
  -P ubuntu-24.04=ghcr.io/catthehacker/ubuntu:act-24.04 \
  --bind \
  -s FMOD_USER \
  -s FMOD_PASSWORD
```

`--bind` gives nested Docker builders access to sources in the shared checkout.
The command runs both `build` and `verify`. Local runs pass the archive through
`dist/` instead of GitHub artifact upload/download. Add `-j build` only to omit
the separate archive verification job. This command does not publish a release.

## Outputs

| Output | Path |
| --- | --- |
| Component builds | `generated/litergss/`, `generated/rubyfmod/`, `generated/sfemovie/`, `generated/sfemovie-ruby/` |
| Assembled runtime | `generated/Linux-x86-64/` |
| Archive | `dist/Linux.7z` |
| Internal checksum | `dist/Linux.7z.sha256` |

The archive wraps the runtime in `ruby-dist/`, with `bin/`, `lib/`, `setup.sh`
and `BUILD-INFO`.

## Resume or rebuild

The complete `act` build starts from clean generated directories. To work with
individual stages, follow the [build layout](BUILD-NOTES.md#toolchain-and-build-layout)
and the component guides for [RubyFMOD](rubyfmod/README.md) and
[native sfeMovie](sfemovie/README.md).

Assembly requires an empty `OUTPUT_DIR` and accepts an optional `ARCHIVE_PATH`.
When changing targets or pins, use fresh sources and outputs; see
[shared build conventions](../../CONTRIBUTING.md#workflow-and-script-conventions).

## Verify a package

From the repository root:

```bash
RELEASE_DIR=/absolute/path/to/ruby-dist bash linux/x86_64/verify-release.sh
```

Point `RELEASE_DIR` at the assembled runtime or an extracted archive's
`ruby-dist/`. The verifier requires Docker and downloads the test image and
system packages as needed. It relocates the payload to a path containing spaces
and runs the [shared functional suite](../../tests/README.md) with Xvfb/Mesa
and silent audio in a glibc 2.28 container.

## Compatibility limits

The runtime expects host OpenGL drivers, X11/XWayland and ALSA-compatible audio.
Software-rendered CI and silent audio do not establish physical device, driver
or complete-game coverage. See [recorded evidence](BUILD-NOTES.md#compatibility-limits)
for the limits of previous validation reports.

## Reference documents

- [DEPENDENCIES.md](DEPENDENCIES.md): pinned inputs, library versions, system
  dependencies and selection rationale.
- [BUILD-NOTES.md](BUILD-NOTES.md): build internals, workarounds, binary audits
  and compatibility limits.
