#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PATH=/usr/bin:/bin
packages=()
count=0
total=$(awk 'NF && $1 !~ /^#/ {n++} END {print n}' "$ROOT/config/windows-x86-packages.lock")
while read -r checksum url; do
  [[ -z "$checksum" || "$checksum" == \#* ]] && continue
  archive="/var/cache/pacman/pkg/${url##*/}"
  count=$((count + 1))
  printf '[%s] Package %s/%s: %s\n' "$(date -u +%FT%TZ)" "$count" "$total" "${url##*/}"
  if [[ ! -f "$archive" ]]; then
    curl -fL --retry 2 --connect-timeout 30 --max-time 300 --speed-time 60 --speed-limit 1024 "$url" -o "$archive.tmp"
    mv "$archive.tmp" "$archive"
  fi
  printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c -
  packages+=("$archive")
done < "$ROOT/config/windows-x86-packages.lock"
# Install one closed, checksum-locked transaction. Do not resolve rolling repo
# versions or use dependencies from an existing host MSYS2 installation.
echo 'Installing the verified package transaction'
pacman -U --needed --noconfirm "${packages[@]}"
mkdir -p "$ROOT/generated/windows-x86/bootstrap"
bootstrap="$ROOT/generated/windows-x86/bootstrap"
archive_hash="$(sha256sum "$ROOT/generated/windows-x86/downloads/rubyinstaller.7z" | cut -d ' ' -f 1)"
if [[ ! -f "$bootstrap/.archive-sha256" ]] || [[ "$(cat "$bootstrap/.archive-sha256")" != "$archive_hash" ]]; then
  echo 'Extracting RubyInstaller bootstrap'
  7z x -y "$ROOT/generated/windows-x86/downloads/rubyinstaller.7z" "-o$bootstrap" >/dev/null
  printf '%s\n' "$archive_hash" > "$bootstrap/.archive-sha256"
fi
pacman -Q > "$ROOT/generated/windows-x86/packages.txt"
echo 'Isolated toolchain bootstrap complete'
