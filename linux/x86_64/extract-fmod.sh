#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
archive="${1:?Usage: extract-fmod.sh downloaded-archive}"
destination="$ROOT/sources/fmod-sdk"
mkdir -p "$destination"
tar -xzf "$archive" -C "$destination"
inner_archive="$(find "$destination" -maxdepth 1 -type f -name 'fmodstudioapi*linux.tar.gz' -print -quit)"
if [[ -n "$inner_archive" ]]; then
  tar -xzf "$inner_archive" -C "$destination"
  rm -f "$inner_archive"
fi
header="$(find "$destination" -type f -name fmod_common.h -print -quit)"
if [[ -z "$header" ]]; then
  echo 'FMOD SDK extracted, but fmod_common.h was not found.' >&2
  exit 1
fi
core="$(cd "$(dirname "$header")/.." && pwd)"
test -f "$core/lib/x86_64/libfmod.so"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'FMOD_SDK_DIR=%s\n' "$core" >> "$GITHUB_ENV"
fi
printf 'FMOD Core extracted to %s\n' "$core"
