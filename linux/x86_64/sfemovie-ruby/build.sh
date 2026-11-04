#!/usr/bin/env bash

set -euo pipefail

: "${RUBY_VERSION:?Set RUBY_VERSION to the embedded Ruby version.}"
: "${SFEMOVIE_RUBY_SOURCE_DIR:?Set SFEMOVIE_RUBY_SOURCE_DIR to the SFEMovie Ruby source checkout.}"
: "${SFEMOVIE_SOURCE_DIR:?Set SFEMOVIE_SOURCE_DIR to the native sfeMovie source checkout.}"
: "${LITERGSS_SOURCE_DIR:?Set LITERGSS_SOURCE_DIR to the LiteRGSS source checkout.}"
: "${LITERGSS_BUILD_DIR:?Set LITERGSS_BUILD_DIR to LiteRGSS build-support output.}"
: "${SFEMOVIE_RUNTIME_DIR:?Set SFEMOVIE_RUNTIME_DIR to the native sfeMovie runtime payload.}"

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly output_dir="${OUTPUT_DIR:-${repository_root}/generated/linux-x86_64-gnu-sfemovie-ruby}"
readonly image_name="litergss-linux-gnu:${RUBY_VERSION}"
readonly ruby_source_dir="$(cd "${SFEMOVIE_RUBY_SOURCE_DIR}" && pwd)"
readonly sfemovie_source_dir="$(cd "${SFEMOVIE_SOURCE_DIR}" && pwd)"
readonly litergss_source_dir="$(cd "${LITERGSS_SOURCE_DIR}" && pwd)"
readonly litergss_build_dir="$(cd "${LITERGSS_BUILD_DIR}" && pwd)"
readonly sfemovie_runtime_dir="$(cd "${SFEMOVIE_RUNTIME_DIR}" && pwd)"

if [[ -e "${output_dir}" ]] && [[ -n "$(find "${output_dir}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo "Refusing to build into non-empty output directory: ${output_dir}" >&2
  exit 1
fi
mkdir -p "${output_dir}"

docker run --rm --entrypoint /bin/bash \
  -v "${repository_root}:/config:ro" \
  -v "${ruby_source_dir}:/sfemovie-ruby:ro" \
  -v "${sfemovie_source_dir}:/sfemovie-source:ro" \
  -v "${litergss_source_dir}:/litergss-source:ro" \
  -v "${litergss_build_dir}:/litergss-build:ro" \
  -v "${sfemovie_runtime_dir}:/sfemovie-runtime:ro" \
  -v "${output_dir}:/output" \
  "${image_name}" \
  /config/linux/x86_64/sfemovie-ruby/entrypoint.sh
