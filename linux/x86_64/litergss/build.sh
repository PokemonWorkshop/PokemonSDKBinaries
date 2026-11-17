#!/usr/bin/env bash
set -euo pipefail
readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$repository_root/config/linux-x86_64.conf"
readonly source_dir="$repository_root/sources/litergss"
readonly output_dir="${OUTPUT_DIR:-$repository_root/generated/litergss}"
readonly image_name="litergss-linux-gnu:$RUBY_VERSION"
if [[ -e "$output_dir" ]] && [[ -n "$(find "$output_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo "Refusing to merge a distribution into non-empty output directory: $output_dir" >&2
  exit 1
fi
mkdir -p "$output_dir"
docker build --pull \
  --build-arg "RUBY_VERSION=$RUBY_VERSION" --build-arg "RUBY_SHA256=$RUBY_SHA256" \
  --build-arg "RAKE_VERSION=$RAKE_VERSION" --build-arg "RAKE_COMPILER_VERSION=$RAKE_COMPILER_VERSION" \
  -f "$repository_root/linux/x86_64/litergss/Dockerfile" \
  -t "$image_name" "$repository_root"
docker run --rm -v "$source_dir:/source:ro" -v "$output_dir:/output" "$image_name"
