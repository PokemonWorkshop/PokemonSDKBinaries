#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SEVENZIP="${SEVENZIP:-7zz}"
RELEASE_DIR="${RELEASE_DIR:-$ROOT/generated/MacOS-arm64/ruby-dist}"
archive="${ARCHIVE_PATH:-$ROOT/dist/macOS.7z}"
mkdir -p "$(dirname "$archive")"
archive="$(cd "$(dirname "$archive")" && pwd)/$(basename "$archive")"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/stage"
cp -a "$RELEASE_DIR" "$temporary/stage/ruby-dist"
rm -f "$archive"
(cd "$temporary/stage"; "$SEVENZIP" a -t7z -snl "$archive" ruby-dist)
"$SEVENZIP" t "$archive"
"$SEVENZIP" x "$archive" "-o$temporary/extracted"
RELEASE_DIR="$temporary/extracted/ruby-dist" bash "$ROOT/macos/arm64/verify-release.sh"
(cd "$(dirname "$archive")"; shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256")
