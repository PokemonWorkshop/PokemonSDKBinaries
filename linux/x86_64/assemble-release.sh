#!/usr/bin/env bash

set -euo pipefail

: "${LITERGSS_DIR:?Set LITERGSS_DIR to the LiteRGSS runtime payload.}"
: "${RUBY_FMOD_DIR:?Set RUBY_FMOD_DIR to the RubyFMOD payload.}"
: "${SFEMOVIE_DIR:?Set SFEMOVIE_DIR to the sfeMovie payload.}"
: "${SFEMOVIE_RUBY_DIR:?Set SFEMOVIE_RUBY_DIR to the SFEMovie Ruby binding payload.}"

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=config/linux-x86_64.conf
source "${repository_root}/config/linux-x86_64.conf"
readonly output_dir="${OUTPUT_DIR:-${repository_root}/generated/${PLATFORM}}"
readonly archive_path="${ARCHIVE_PATH:-}"

litergss_dir="$(cd "${LITERGSS_DIR}" && pwd)"
ruby_fmod_dir="$(cd "${RUBY_FMOD_DIR}" && pwd)"
sfemovie_dir="$(cd "${SFEMOVIE_DIR}" && pwd)"
sfemovie_ruby_dir="$(cd "${SFEMOVIE_RUBY_DIR}" && pwd)"

if [[ -e "${output_dir}" ]] && [[ -n "$(find "${output_dir}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo "Refusing to assemble into non-empty output directory: ${output_dir}" >&2
  exit 1
fi

mkdir -p "${output_dir}/lib"
cp -a "${litergss_dir}/." "${output_dir}/"
# build-support is needed only by the preceding SFEMovie binding build. Do not
# ship a static developer library in the end-user runtime archive.
rm -rf "${output_dir}/build-support"

soname() {
  readelf -d "$1" 2>/dev/null | awk -F'[][]' '/SONAME/ { print $2; exit }'
}

merge_runtime_file() {
  local source_file="$1"
  local destination="${output_dir}/lib/$(basename "${source_file}")"

  if [[ ! -e "${destination}" && ! -L "${destination}" ]]; then
    cp -a "${source_file}" "${destination}"
    return
  fi

  if [[ -L "${source_file}" && -L "${destination}" ]] && [[ "$(readlink "${source_file}")" == "$(readlink "${destination}")" ]]; then
    return
  fi

  if [[ -f "${source_file}" && -f "${destination}" ]]; then
    local source_soname
    local destination_soname
    source_soname="$(soname "${source_file}")"
    destination_soname="$(soname "${destination}")"
    if [[ -n "${source_soname}" && "${source_soname}" == "${destination_soname}" ]]; then
      echo "Keeping LiteRGSS runtime copy of $(basename "${source_file}") (${source_soname})."
      return
    fi
  fi

  echo "Incompatible runtime collision: ${source_file} and ${destination}" >&2
  exit 1
}

while IFS= read -r -d '' runtime_file; do
  merge_runtime_file "${runtime_file}"
done < <(find "${sfemovie_dir}" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) -print0)

while IFS= read -r -d '' runtime_file; do
  merge_runtime_file "${runtime_file}"
done < <(find "${ruby_fmod_dir}" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) -print0)

sfemovie_ruby_extension="${sfemovie_ruby_dir}/SFEMovie.so"
test -f "${sfemovie_ruby_extension}" || {
  echo 'Error: the SFEMovie Ruby build did not produce SFEMovie.so.' >&2
  exit 1
}
install -m 0755 "${sfemovie_ruby_extension}" "${output_dir}/lib/SFEMovie.so"

# The Ruby binding is linked in a temporary build directory, so replace only
# its build-time RUNPATH.  Component builders already set the RPATH of their
# own binaries.  Rewriting every third-party dependency here is unnecessary
# and can produce invalid ELF program-header alignment with some patchelf
# versions (notably the Ubuntu runner package when applied to libz).
command -v patchelf >/dev/null || {
  echo 'Error: patchelf is required to make the release relocatable.' >&2
  exit 1
}
patchelf --force-rpath --set-rpath '$ORIGIN' "${output_dir}/lib/SFEMovie.so"

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

is_host_desktop_library() {
  case "$1" in
    # These select the target machine's X11, OpenGL driver and ALSA stack.
    # They are deliberately not bundled; verify-release.sh installs matching
    # host packages in its clean glibc-2.28 test container.
    libstdc++.so.*|libasound.so.*|libGL.so.*|libGLX.so.*|libGLdispatch.so.*|\
    libX11.so.*|libXau.so.*|libXcursor.so.*|libXext.so.*|libXfixes.so.*|\
    libXi.so.*|libXrandr.so.*|libXrender.so.*|libxcb.so.*|libudev.so.*)
      return 0
      ;;
  esac
  return 1
}

verify_dynamic_dependencies() {
  local binary="$1"
  local dependency
  local -a unresolved=()

  while IFS= read -r dependency; do
    [[ -z "${dependency}" ]] && continue
    is_host_desktop_library "${dependency}" || unresolved+=("${dependency}")
  done < <(LD_LIBRARY_PATH="${output_dir}/lib" ldd "${binary}" | awk '/not found/ { print $1 }')

  if (( ${#unresolved[@]} == 0 )); then
    return
  fi

  echo "Error: ${binary} has unresolved dynamic dependencies:" >&2
  printf '%s\n' "${unresolved[@]}" >&2
  exit 1
}

while IFS= read -r -d '' binary; do
  verify_glibc_baseline "${binary}"
  verify_dynamic_dependencies "${binary}"
done < <(
  printf '%s\0' "${output_dir}/bin/ruby"
  find "${output_dir}/lib" -type f -name '*.so*' -print0
)

ruby_library_dir="$(find "${output_dir}/lib/ruby" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*' -print -quit)"
ruby_arch_library_dir="$(find "${ruby_library_dir}" -mindepth 1 -maxdepth 1 -type d -name '*-linux*' -print -quit)"
test -n "${ruby_library_dir}" && test -n "${ruby_arch_library_dir}"
install -m 0644 "${repository_root}/linux/x86_64/clean_load_path.rb" \
  "${ruby_library_dir}/clean_load_path.rb"

LD_LIBRARY_PATH="${output_dir}/lib" "${output_dir}/bin/ruby" \
  -I"${output_dir}/lib" -I"${ruby_library_dir}" -I"${ruby_arch_library_dir}" -e '
  require "clean_load_path"
  require "LiteRGSS"
  require "SFMLAudio"
  require "RubyFmod"
  require "SFEMovie"
  abort "Unexpected FMOD API version" unless FMOD::VERSION == 0x00020220
  abort "SFEMovie extension did not define SFE::Movie" unless defined?(SFE::Movie)
  puts "LiteRGSS, SFMLAudio and RubyFMOD loaded successfully"
'

sfemovie_library="$(find "${output_dir}/lib" -maxdepth 1 -type f -name 'libsfeMovie.so.*' -print -quit)"
test -n "${sfemovie_library}" || {
  echo 'Error: the assembled release does not contain libsfeMovie.' >&2
  exit 1
}
LD_LIBRARY_PATH="${output_dir}/lib" "${output_dir}/bin/ruby" \
  -I"${ruby_library_dir}" -I"${ruby_arch_library_dir}" -e '
  require "fiddle"
  Fiddle.dlopen(ARGV.fetch(0))
  puts "sfeMovie loaded successfully"
' "${sfemovie_library}"

LD_LIBRARY_PATH="${output_dir}/lib" "${output_dir}/bin/ruby" \
  -I"${ruby_library_dir}" -I"${ruby_arch_library_dir}" -e '
  require "fiddle/import"
  module AVCodec
    extend Fiddle::Importer
    dlload ARGV.fetch(0)
    extern "void *avcodec_find_decoder_by_name(const char *)"
  end
  %w[png mov_text].each do |decoder|
    abort "Missing required FFmpeg decoder: #{decoder}" if AVCodec.avcodec_find_decoder_by_name(decoder).to_i == 0
  end
  puts "Required FFmpeg decoders loaded successfully"
' "${output_dir}/lib/libavcodec.so.60"

printf 'Platform: %s\nRuby: %s\nFMOD API: %s\nFFmpeg: %s\nLiteRGSS revision: %s\nRubyFMOD revision: %s\nsfeMovie revision: %s\n' \
  "${PLATFORM}" "${RUBY_VERSION}" "${FMOD_VERSION_HEX}" "${FFMPEG_VERSION}" \
  "${LITERGSS_REF}" "${RUBY_FMOD_REF}" "${SFEMOVIE_REF}" \
  > "${output_dir}/BUILD-INFO"

mkdir -p "${output_dir}/lib/psdk-runtime"
cp "${repository_root}/tests/runtime-functional.rb" "${repository_root}/tests/sfemovie-texture.rb" "${output_dir}/lib/psdk-runtime/"

if [[ -n "${archive_path}" ]]; then
  command -v 7z >/dev/null || {
    echo 'Error: ARCHIVE_PATH requires the 7z command.' >&2
    exit 1
  }
  mkdir -p "$(dirname "${archive_path}")"
  archive_work_dir="$(mktemp -d /tmp/pokemonsdk-ruby-dist.XXXXXX)"
  mkdir -p "${archive_work_dir}/ruby-dist"
  cp -a "${output_dir}/." "${archive_work_dir}/ruby-dist/"
  if ! (cd "${archive_work_dir}" && 7z a -t7z "${archive_path}" ruby-dist); then
    rm -rf "${archive_work_dir}"
    exit 1
  fi
  rm -rf "${archive_work_dir}"
fi

echo "Verified assembled ${PLATFORM} release payload."
