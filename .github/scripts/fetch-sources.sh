#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
configuration="${1:?Usage: fetch-sources.sh config/<platform>.conf}"
source "$ROOT/$configuration"
source "$ROOT/.github/scripts/fetch-source-archive.sh"
mkdir -p "$ROOT/sources"

# All platforms fetch locked archives here; builders verify them again before
# extraction. Component checkouts follow the same path below.
lock="$ROOT/${configuration%.conf}-sources.lock"
if [[ -f "$lock" ]]; then
  mkdir -p "$ROOT/sources/archives"
  while read -r name checksum url; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    archive="$ROOT/sources/archives/$name.tar.${url##*.}"
    fetch_source_archive "$checksum" "$url" "$archive"
  done < "$lock"
fi

checkout() {
  local repository="$1" revision="$2" destination="$ROOT/sources/$3"
  if [[ ! -d "$destination" ]]; then
    # Reviewed pins can live on integration branches, not just the default.
    git clone --no-checkout --no-single-branch "$repository" "$destination"
  fi
  if [[ ! -e "$destination/.git" ]]; then
    echo "Expected a Git checkout at $destination; use a fresh sources directory." >&2
    exit 1
  fi
  git -C "$destination" rev-parse --verify "${revision}^{commit}" >/dev/null
  git -C "$destination" checkout --detach "$revision"
  test "$(git -C "$destination" rev-parse HEAD)" = "$revision"
  git -C "$destination" submodule update --init --recursive
}
checkout "$LITERGSS_REPOSITORY" "$LITERGSS_REF" litergss
checkout "$RUBY_FMOD_REPOSITORY" "$RUBY_FMOD_REF" ruby-fmod
checkout "$SFEMOVIE_REPOSITORY" "$SFEMOVIE_REF" sfemovie
checkout "$SFEMOVIE_RUBY_REPOSITORY" "$SFEMOVIE_RUBY_REF" sfemovie-ruby
if [[ -n "${SFML_AUDIO_REF:-}" ]]; then
  checkout "$SFML_AUDIO_REPOSITORY" "$SFML_AUDIO_REF" sfmlaudio
fi
test -f "$ROOT/sources/litergss/Rakefile"
test -f "$ROOT/sources/litergss/external/litecgss/Rakefile"
