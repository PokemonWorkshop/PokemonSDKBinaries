#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RELEASE_DIR="${RELEASE_DIR:-$ROOT/generated/MacOS-arm64/ruby-dist}"
python3 "$ROOT/macos/arm64/mach_o.py" --verify "$RELEASE_DIR"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/relocated game"
cp -a "$RELEASE_DIR" "$temporary/relocated game/ruby-dist"
env -i HOME="$temporary" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  /bin/bash -eu -c '
    cd "$1"
    source ./setup.sh
    ruby "$2"
    test -f smoke-passed
  ' bash "$temporary/relocated game/ruby-dist" "$ROOT/macos/arm64/smoke.rb"
