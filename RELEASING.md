# Releasing Pokémon SDK Binaries

This guide is for maintainers configuring and publishing runtime releases.
For local builds, use the platform guides linked from
[CONTRIBUTING.md](CONTRIBUTING.md#getting-started).

## Repository configuration

### Required GitHub Actions secrets

Create these **repository Actions secrets** under **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
| --- | --- |
| `FMOD_USER` | FMOD account username or email authorized to download the SDK |
| `FMOD_PASSWORD` | Password for that FMOD account |

The release workflow passes these secrets to all three platform builders to obtain their FMOD SDKs. None of the platform workflows has a manual trigger. Never commit them, add them as Actions variables, or expose them to pull-request workflows. A dedicated FMOD account with the minimum required download entitlement is recommended.

### Protected release tags

Protect the `v*` tag pattern with a GitHub ruleset and allow only maintainers or the release team to create, update, or delete matching tags. This is essential because a tag push authorizes the workflow to access the FMOD secrets and publish a release.

An authorization job checks that the event is a `v*` tag push and GitHub reports
the tag as protected. It fails before any platform build starts if that check
fails. Configure an active tag ruleset in the release repository (and any fork
used for tagged CI testing); the workflow cannot create that repository setting
or determine who the ruleset permits solely from the protection flag.

`release.yml` has no branch-push, pull-request, or manual-dispatch trigger. The workflows pin component source commits and GitHub Actions by revision, restrict default permissions to read-only, and grant release-write permission only to the final publication job.

## Publish a release

Validate affected platforms before creating a release tag. From the revision
you intend to release, create and push a protected tag beginning with `v`:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Use the intended release version in place of the example. The tag triggers
[release.yml](.github/workflows/release.yml), which authorizes the release and
calls three reusable workflows:

| Target | Workflow | Build and verification environment |
| --- | --- | --- |
| Linux x86-64 | [build-linux-x86_64.yml](.github/workflows/build-linux-x86_64.yml) | manylinux glibc 2.28 containers on Ubuntu runners |
| macOS ARM64 | [build-macos-arm64.yml](.github/workflows/build-macos-arm64.yml) | Build/test on macOS 14; fresh archive verification on macOS 15 and 26 |
| Windows x86 | [build-windows-x86.yml](.github/workflows/build-windows-x86.yml) | Build/test and fresh archive verification on Windows Server 2022 |

Each platform builds from immutable component pins, assembles its runtime and
runs the [shared functional suite](tests/README.md) plus its binary audits.
A dependent verification job downloads the archive and SHA-256 sidecar,
checks the checksum, extracts the archive and verifies the extracted runtime
on a fresh runner. Publication waits for all platforms to pass both jobs.
Check the workflow results for the tagged revision before announcing a release.

The final job creates a GitHub Release with generated notes, or replaces the
listed assets on an existing release for that tag. It is the only job granted
release-write permission. Local `act` outputs are build results; publication
runs through GitHub Actions.

## Published files and checksums

The public assets are `Linux.7z`, `macOS.7z`, `Windows.7z` and `version.json`.
SHA-256 sidecars are internal CI artifacts and are not published.

`version.json` retains the consuming launchers' legacy format:

- `version` is the release tag without its leading `v`.
- `linux`, `macos` and `windows` are SHA-1 hashes of the corresponding final
  archive bytes.

The manifest is generated only after the final job checks all three archives
against their SHA-256 sidecars. When adding a release target, follow the
[release integration requirements](CONTRIBUTING.md#integrate-with-ci-and-publication),
including archive naming and launcher manifest compatibility.

## Dry-run behavior

`RELEASE_DRY_RUN=true` makes the final publication step print its intended
release and generated manifest, then exit without creating or changing a
GitHub Release. For a local `act` invocation of `release.yml`, pass:

```bash
--env RELEASE_DRY_RUN=true
```

This setting only suppresses publication. It does not bypass protected-tag
authorization, credentials, platform builds or verification. The complete
workflow needs native macOS and Windows jobs, which `act`'s Linux containers
cannot run. Use the [Linux workflow locally](linux/x86_64/README.md#build-and-package)
for independent Linux build and verification testing.

## FMOD distribution

Only the required platform FMOD runtime is included in releases. SDK headers,
static/import libraries and installers remain temporary build inputs. Confirm
applicable redistribution rights before publishing; see the
[FMOD runtime and licensing notes](LICENSING.md#fmod-runtime-and-licensing).

The authenticated SDK downloader was informed by the open-source
[utopia-rise/fmod-gdextension](https://github.com/utopia-rise/fmod-gdextension)
project. Thank you to its contributors for publishing that CI download example.
