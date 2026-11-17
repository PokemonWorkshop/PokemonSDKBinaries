#!/usr/bin/env bash

set -euo pipefail

readonly work_dir="$(mktemp -d /tmp/rubyfmod-linux-gnu.XXXXXX)"
readonly source_dir="${work_dir}/source"
readonly ruby_dir=/opt/litergss/ruby
readonly fmod_dir=/fmod
readonly fmod_header="${fmod_dir}/inc/fmod_common.h"
readonly fmod_library="${fmod_dir}/lib/x86_64/libfmod.so.13.20"
readonly output_dir=/output

cleanup() {
  rm -rf "${work_dir}"
}
trap cleanup EXIT

test -f "${fmod_dir}/inc/fmod.h"
test -f "${fmod_dir}/inc/fmod_errors.h"
test -f "${fmod_header}"
test -f "${fmod_library}"
grep -Eq '^#define FMOD_VERSION +0x00020220' "${fmod_header}"
file "${fmod_library}" | grep -Fq 'ELF 64-bit LSB shared object, x86-64'

cp -a /source/. "${source_dir}"
cd "${source_dir}"
patch -p1 < /config/linux/x86_64/rubyfmod/fmod-sdk.patch

export PATH="${ruby_dir}/bin:${PATH}"

rake clean
rake compile

readonly extension="${source_dir}/lib/RubyFmod.so"
test -f "${extension}"

install -m 0755 "${extension}" "${output_dir}/RubyFmod.so"
install -m 0755 "${fmod_library}" "${output_dir}/libfmod.so.13.20"
ln -sfn libfmod.so.13.20 "${output_dir}/libfmod.so.13"

runtime_library="$(gcc -print-file-name=libgcc_s.so.1)"
test -f "${runtime_library}"
install -m 0755 "$(readlink -f "${runtime_library}")" "${output_dir}/libgcc_s.so.1"

patchelf --force-rpath --set-rpath '$ORIGIN' "${output_dir}/RubyFmod.so"
patchelf --force-rpath --set-rpath '$ORIGIN' "${output_dir}/libfmod.so.13.20"

"${ruby_dir}/bin/ruby" -I"${output_dir}" -e '
  require "RubyFmod"
  abort "Unexpected FMOD API version" unless FMOD::VERSION == 0x00020220
  puts "RubyFMOD loaded against FMOD 2.02"
'

verify_glibc_baseline() {
  local binary="$1"
  if ! readelf --version-info "${binary}" | awk '
    /GLIBC_[0-9]+\.[0-9]+/ {
      version = $0
      sub(/^.*GLIBC_/, "", version)
      sub(/[^0-9.].*$/, "", version)
      split(version, parts, ".")
      if (parts[1] > 2 || (parts[1] == 2 && parts[2] > 28)) exit 1
    }
  '; then
    echo "Error: ${binary} requires a glibc version newer than 2.28." >&2
    exit 1
  fi
}

verify_dynamic_dependencies() {
  local binary="$1"
  local unresolved
  unresolved="$(LD_LIBRARY_PATH="${output_dir}" ldd "${binary}" | awk '/not found/ { print $1 }')"

  if [[ -z "${unresolved}" || "${unresolved}" == 'libruby.so.3.4' ]]; then
    return
  fi

  echo "Error: ${binary} has unresolved dynamic dependencies:" >&2
  printf '%s\\n' "${unresolved}" >&2
  exit 1
}

while IFS= read -r -d '' binary; do
  verify_glibc_baseline "${binary}"
  verify_dynamic_dependencies "${binary}"
done < <(find "${output_dir}" -maxdepth 1 -type f -name '*.so*' -print0)

echo 'Verified: RubyFMOD and FMOD 2.02 target glibc 2.28 or older.'
