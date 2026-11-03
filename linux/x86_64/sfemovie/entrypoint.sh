#!/usr/bin/env bash

set -euo pipefail

readonly work_dir="$(mktemp -d /tmp/sfemovie-linux-gnu.XXXXXX)"
readonly source_dir="${work_dir}/source"
readonly stage_dir="${work_dir}/stage"
readonly output_dir=/output
readonly sfml_dir=/opt/litergss/sfml
readonly ffmpeg_dir=/opt/sfemovie/ffmpeg

sfml_lib_dir="${sfml_dir}/lib"
if [[ -d "${sfml_dir}/lib64" ]]; then
  sfml_lib_dir="${sfml_dir}/lib64"
fi
readonly sfml_lib_dir

cleanup() {
  rm -rf "${work_dir}"
}
trap cleanup EXIT

cp -a /source/. "${source_dir}"

cmake -S "${source_dir}" -B "${work_dir}/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DSFEMOVIE_BUILD_STATIC=OFF \
  -DSFEMOVIE_BUILD_UNIT_TESTS=OFF \
  -DSFEMOVIE_BUILD_DOC=OFF \
  -DSFEMOVIE_ENABLE_ASS_SUBTITLES=ON \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DSFML_ROOT="${sfml_dir}" \
  -DFFMPEG_ROOT="${ffmpeg_dir}"
cmake --build "${work_dir}/build" --parallel "$(nproc)"
cmake --install "${work_dir}/build" --prefix "${stage_dir}"

cp -a "${stage_dir}/lib"/libsfeMovie.so* "${output_dir}/"
cp -a "${sfml_lib_dir}"/libsfml-*.so* "${output_dir}/"
cp -a "${ffmpeg_dir}/lib"/libavcodec.so* "${ffmpeg_dir}/lib"/libavdevice.so* \
  "${ffmpeg_dir}/lib"/libavformat.so* \
  "${ffmpeg_dir}/lib"/libavutil.so* "${ffmpeg_dir}/lib"/libswresample.so* \
  "${ffmpeg_dir}/lib"/libswscale.so* "${output_dir}/"

is_glibc_library() {
  case "$(basename "$1")" in
    ld-linux-*.so.*|libc.so.*|libdl.so.*|libm.so.*|libpthread.so.*|libresolv.so.*|librt.so.*|libutil.so.*)
      return 0
      ;;
  esac
  return 1
}

is_host_library() {
  case "$(basename "$1")" in
    # Keep the graphics driver and X11 integration on the target host, as the
    # LiteRGSS package does. Bundling these can make Mesa select an invalid
    # driver/visual combination on a different distribution.
    libstdc++.so.*|libasound.so.*|libGL.so.*|libGLX.so.*|libGLdispatch.so.*|\
    libX11.so.*|libXau.so.*|libXcursor.so.*|libXext.so.*|libXfixes.so.*|\
    libXrandr.so.*|libXrender.so.*|libxcb.so.*|libudev.so.*)
      return 0
      ;;
  esac
  return 1
}

copy_runtime_library() {
  local library="$1"
  local resolved_library
  local library_name
  local resolved_name

  is_glibc_library "${library}" && return
  is_host_library "${library}" && return
  resolved_library="$(readlink -f "${library}")"
  library_name="$(basename "${library}")"
  resolved_name="$(basename "${resolved_library}")"

  if [[ "${resolved_library}" == "${output_dir}/${resolved_name}" ]]; then
    return
  fi

  install -m 0755 "${resolved_library}" "${output_dir}/${resolved_name}"
  if [[ "${library_name}" != "${resolved_name}" ]]; then
    ln -sfn "${resolved_name}" "${output_dir}/${library_name}"
  fi
}

while IFS= read -r -d '' binary; do
  while IFS= read -r library; do
    [[ -n "${library}" ]] && copy_runtime_library "${library}"
  done < <(LD_LIBRARY_PATH="${output_dir}" ldd "${binary}" | awk '
    /=> \/[^ ]+/ { print $3 }
    /^\// { print $1 }
  ')
done < <(find "${output_dir}" -maxdepth 1 -type f -name '*.so*' -print0)

while IFS= read -r -d '' binary; do
  patchelf --force-rpath --set-rpath '$ORIGIN' "${binary}"
done < <(find "${output_dir}" -maxdepth 1 -type f -name '*.so*' -print0)

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
  if ! LD_LIBRARY_PATH="${output_dir}" ldd "${binary}" | grep -q 'not found'; then
    return
  fi

  echo "Error: ${binary} has unresolved dynamic dependencies:" >&2
  LD_LIBRARY_PATH="${output_dir}" ldd "${binary}" | grep 'not found' >&2
  exit 1
}

while IFS= read -r -d '' binary; do
  verify_glibc_baseline "${binary}"
  verify_dynamic_dependencies "${binary}"
done < <(find "${output_dir}" -maxdepth 1 -type f -name '*.so*' -print0)

echo 'Verified: sfeMovie and its staged ELF dependencies target glibc 2.28 or older.'
