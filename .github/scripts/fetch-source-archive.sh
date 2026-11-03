#!/usr/bin/env bash
# Shared by all platform source fetchers. Publish only checksum-verified files.
fetch_source_archive() (
  set -euo pipefail
  local checksum="$1" url="$2" archive="$3" candidate
  if [[ -f "$archive" ]]; then
    printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c -
    return
  fi

  local temporary="$archive.tmp"
  trap 'rm -f "$temporary"' EXIT
  local -a candidates=("$url")
  case "$url" in
    https://cache.ruby-lang.org/pub/ruby/*)
      # Same release archive via Ruby's alternate download hostname, with
      # independent hostname resolution and the original locked checksum.
      candidates+=("https://ftp.ruby-lang.org/pub/ruby/${url#https://cache.ruby-lang.org/pub/ruby/}")
      ;;
    https://ffmpeg.org/releases/ffmpeg-*.tar.xz)
      # MacPorts mirrors the release tarball, not a regenerated Git archive.
      candidates+=("https://distfiles.macports.org/ffmpeg/${url##*/}")
      ;;
  esac

  for candidate in "${candidates[@]}"; do
    printf 'Fetching %s\n' "$candidate"
    # These are idempotent GETs into a temporary output file. Also retry TLS
    # resets/connection failures, which --retry alone does not always cover.
    if curl -fLsS --retry 3 --retry-all-errors --retry-max-time 120 \
      --connect-timeout 30 --max-time 600 "$candidate" -o "$temporary"; then
      # A successful transfer with the wrong contents must fail immediately,
      # rather than treating a checksum mismatch as a reason to try a mirror.
      if ! printf '%s  %s\n' "$checksum" "$temporary" | shasum -a 256 -c -; then
        echo "Checksum mismatch; refusing downloaded archive: $candidate" >&2
        return 1
      fi
      mv "$temporary" "$archive"
      return 0
    fi
    rm -f "$temporary"
    echo "Download failed: $candidate" >&2
  done
  echo "Unable to download pinned source archive: $url" >&2
  return 1
)
