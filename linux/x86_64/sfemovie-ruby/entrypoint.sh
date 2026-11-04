#!/usr/bin/env bash

set -euo pipefail

readonly work_dir="$(mktemp -d /tmp/sfemovie-ruby-linux-gnu.XXXXXX)"
readonly ruby_binding_dir="${work_dir}/ruby-binding"

cleanup() {
  rm -rf "${work_dir}"
}
trap cleanup EXIT

test -f /litergss-build/libLiteCGSS_engine.a

cp -a /sfemovie-ruby/. "${ruby_binding_dir}"
bash /config/.github/scripts/prepare-sfemovie-ruby.sh "${ruby_binding_dir}" /litergss-source
cd "${ruby_binding_dir}"
export PATH=/opt/litergss/ruby/bin:"${PATH}"

SFEMOVIE_INCLUDE_DIR=/sfemovie-source/include \
SFEMOVIE_LIBRARY_DIR=/sfemovie-runtime \
LITECGSS_INCLUDE_DIR=/litergss-source/external/litecgss/src \
LITECGSS_LIBRARY_DIR=/litergss-build \
LITERGSS_INCLUDE_DIR=/litergss-source/ext/LiteRGSS \
SFML_INCLUDE_DIR=/opt/litergss/sfml/include \
SFML_LIBRARY_DIR=/opt/litergss/sfml/lib64 \
rake compile

install -m 0755 "${ruby_binding_dir}/lib/SFEMovie.so" /output/SFEMovie.so
