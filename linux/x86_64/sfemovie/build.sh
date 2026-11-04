#!/usr/bin/env bash

set -euo pipefail

: "${SOURCE_DIR:?Set SOURCE_DIR to the sfeMovie source checkout.}"

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${repository_root}/config/linux-x86_64.conf"
readonly source_dir="$(cd "${SOURCE_DIR}" && pwd)"
readonly output_dir="${OUTPUT_DIR:-${repository_root}/generated/linux-x86_64-gnu-sfemovie}"
: "${RUBY_VERSION:?Set RUBY_VERSION to the embedded Ruby version of the LiteRGSS image.}"
readonly litergss_image="litergss-linux-gnu:${RUBY_VERSION}"
readonly image_name="pokemonsdk-sfemovie-linux-gnu:ffmpeg-${FFMPEG_VERSION}-ruby-${RUBY_VERSION}"

if [[ -e "${output_dir}" ]] && [[ -n "$(find "${output_dir}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo "Refusing to merge a distribution into non-empty output directory: ${output_dir}" >&2
  echo 'Choose a new OUTPUT_DIR or empty the existing build output yourself.' >&2
  exit 1
fi

mkdir -p "${output_dir}"

if ! docker image inspect "${litergss_image}" >/dev/null; then
  echo "Error: required LiteRGSS build image ${litergss_image} is unavailable." >&2
  echo 'Build LiteRGSS before building sfeMovie.' >&2
  exit 1
fi

docker build \
  --build-arg "LITERGSS_IMAGE=${litergss_image}" \
  --build-arg "FFMPEG_VERSION=${FFMPEG_VERSION}" \
  -f "${repository_root}/linux/x86_64/sfemovie/Dockerfile" \
  -t "${image_name}" \
  "${repository_root}"

docker run --rm \
  -v "${source_dir}:/source:ro" \
  -v "${output_dir}:/output" \
  "${image_name}"
