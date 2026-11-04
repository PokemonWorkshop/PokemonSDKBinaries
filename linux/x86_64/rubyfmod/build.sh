#!/usr/bin/env bash

set -euo pipefail

: "${SOURCE_DIR:?Set SOURCE_DIR to the Ruby-Fmod source checkout.}"
: "${FMOD_SDK_DIR:?Set FMOD_SDK_DIR to the extracted FMOD Core 2.02 SDK.}"

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly source_dir="$(cd "${SOURCE_DIR}" && pwd)"
readonly fmod_sdk_dir="$(cd "${FMOD_SDK_DIR}" && pwd)"
readonly output_dir="${OUTPUT_DIR:-${repository_root}/generated/linux-x86_64-gnu-rubyfmod}"
readonly ruby_version="${RUBY_VERSION:-3.4.10}"
# The preceding LiteRGSS build creates this image, including the exact Ruby
# runtime and development headers shipped in the release.  Reuse it instead
# of compiling Ruby a second time solely to build RubyFMOD.
readonly image_name="litergss-linux-gnu:${ruby_version}"

if [[ -e "${output_dir}" ]] && [[ -n "$(find "${output_dir}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo "Refusing to merge a distribution into non-empty output directory: ${output_dir}" >&2
  echo 'Choose a new OUTPUT_DIR or empty the existing build output yourself.' >&2
  exit 1
fi

mkdir -p "${output_dir}"

if ! docker image inspect "${image_name}" >/dev/null; then
  echo "Error: required LiteRGSS build image ${image_name} is unavailable." >&2
  echo 'Build LiteRGSS before building RubyFMOD.' >&2
  exit 1
fi

docker run --rm --entrypoint /bin/bash \
  -v "${repository_root}:/config:ro" \
  -v "${source_dir}:/source:ro" \
  -v "${fmod_sdk_dir}:/fmod:ro" \
  -v "${output_dir}:/output" \
  "${image_name}" \
  /config/linux/x86_64/rubyfmod/entrypoint.sh
