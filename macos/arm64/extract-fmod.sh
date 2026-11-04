#!/bin/bash
# Unpack the authorized installer; never run installer or copy SDK to /Library.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
archive="${1:?Usage: extract-fmod.sh downloaded-archive}"
destination="$ROOT/sources/fmod-sdk"
mkdir -p "$destination"
mountpoint=""
cleanup() { if [[ -n "$mountpoint" ]]; then hdiutil detach "$mountpoint"; fi; }
trap cleanup EXIT
# The endpoint can wrap the platform installer in a tar archive.
if tar -tf "$archive" >/dev/null 2>&1; then
  tar -xf "$archive" -C "$destination"
  archive="$(find "$destination" -name '*.dmg' -type f -print -quit)"
fi
if [[ -n "$archive" ]]; then
  hdiutil attach -readonly -nobrowse -plist "$archive" > "$destination/mount.plist"
  mountpoint="$(python3 - "$destination/mount.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as stream:
    print(next(e['mount-point'] for e in plistlib.load(stream)['system-entities'] if 'mount-point' in e))
PY
)"
  package="$(find "$mountpoint" -name '*.pkg' -print -quit)"
  if [[ -n "$package" ]]; then
    pkgutil --expand-full "$package" "$destination/expanded"
  else
    cp -R "$mountpoint/." "$destination/contents"
  fi
fi
header="$(find "$destination" -name fmod_common.h -type f -print -quit)"
test -n "$header"
core="$(cd "$(dirname "$header")/.." && pwd)"
test -f "$core/lib/libfmod.dylib"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'FMOD_SDK_DIR=%s\n' "$core" >> "$GITHUB_ENV"
fi
printf 'FMOD Core extracted to %s\n' "$core"
