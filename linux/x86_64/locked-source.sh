#!/usr/bin/env bash
# Sourced inside the Linux builders. Archives are fetched by fetch-sources.sh.
extract_source() {
  local name="$1" checksum url archive
  read -r checksum url < <(awk -v name="$name" '$1 == name {print $2, $3}' /opt/psdk/sources.lock) || return 1
  : "${checksum:?Missing source checksum for $name}" "${url:?Missing source URL for $name}"
  archive="/opt/psdk/archives/$name.tar.${url##*.}"
  printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c - || return 1
  mkdir -p "/tmp/psdk-src/$name" || return 1
  tar -xf "$archive" --strip-components=1 -C "/tmp/psdk-src/$name"
}
