#!/usr/bin/env bash
set -euo pipefail
readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$repository_root/config/macos-arm64.conf"
readonly work_dir="$repository_root/generated/macos-arm64"
readonly source_dir="$repository_root/sources"
readonly output_dir="${OUTPUT_DIR:-$repository_root/generated/$PLATFORM/ruby-dist}"
readonly archive_path="${ARCHIVE_PATH:-}"
: "${FMOD_SDK_DIR:?Set FMOD_SDK_DIR to the FMOD Core SDK directory.}"

# Same contract as the Linux assembler: assemble into an empty directory and
# create an archive only when ARCHIVE_PATH is supplied.
if [[ -e "$output_dir" ]] && [[ -n "$(find "$output_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo "Refusing to assemble into non-empty output directory: $output_dir" >&2
  exit 1
fi
mkdir -p "$output_dir"
cp -a "$work_dir/ruby/bin" "$work_dir/ruby/lib" "$output_dir/"
cp -a "$work_dir/prefix/lib/"*.dylib "$output_dir/lib/"
for component in litergss:LiteRGSS ruby-fmod:RubyFmod sfmlaudio:SFMLAudio sfemovie-ruby:SFEMovie; do
  repository="${component%%:*}"
  extension="${component#*:}"
  install -m 0755 "$source_dir/$repository/ext/$extension/$extension.bundle" "$output_dir/lib/"
done
lipo "$FMOD_SDK_DIR/lib/libfmod.dylib" -thin arm64 -output "$output_dir/lib/libfmod.dylib"
find "$output_dir" -type d -name '*.dSYM' -prune -exec rm -rf {} +
find "$output_dir" -type f \( -name '*.a' -o -name '*.la' -o -name '*.h' -o -name '*.hpp' -o -name '*.pc' \) -delete
rm -rf "$output_dir/lib/pkgconfig"
install -m 0755 "$repository_root/macos/arm64/setup.sh" "$output_dir/setup.sh"
install -m 0644 "$repository_root/macos/arm64/clean_load_path.rb" "$output_dir/lib/clean_load_path.rb"
for script in "$output_dir/bin/"*; do
  [[ "$(basename "$script")" == ruby ]] && continue
  if [[ "$(head -c 2 "$script")" == '#!' ]]; then
    chmod 0755 "$script"
    sed -i '' '1s|.*|#!/usr/bin/env ruby|' "$script"
  fi
done

# Python handles only Mach-O paths/signatures and symlink resolution, not
# payload assembly. Both platforms expose shell assembly/verification steps.
python3 "$repository_root/macos/arm64/mach_o.py" --relocate "$output_dir"

copy_licenses() {
  local source="$1" name="$2" license_file
  while IFS= read -r -d '' license_file; do
    mkdir -p "$output_dir/licenses/$name"
    cp -p "$license_file" "$output_dir/licenses/$name/"
  done < <(find "$source" -maxdepth 1 -type f \( -iname 'copying*' -o -iname 'license*' -o -iname 'licence*' -o -iname 'notice*' -o -iname 'authors*' \) -print0)
}
for source in "$work_dir/src/"*; do
  copy_licenses "$source" "$(basename "$source")"
done
for component in litergss ruby-fmod sfmlaudio sfemovie-ruby sfemovie; do
  copy_licenses "$source_dir/$component" "$component"
done
copy_licenses "$repository_root" psdk-build-tooling
cp -p "$work_dir/src/freetype/docs/FTL.TXT" "$output_dir/licenses/freetype/"
cp "$repository_root/config/macos-arm64.conf" "$output_dir/BUILD-INFO"
xcrun clang --version >> "$output_dir/BUILD-INFO"
cp "$repository_root/config/macos-arm64-sources.lock" "$output_dir/source-archives.txt"
mkdir -p "$output_dir/lib/psdk-runtime"
cp "$repository_root/tests/runtime-functional.rb" "$repository_root/tests/sfemovie-texture.rb" "$output_dir/lib/psdk-runtime/"

if [[ -n "$archive_path" ]]; then
  RELEASE_DIR="$output_dir" ARCHIVE_PATH="$archive_path" bash "$repository_root/macos/arm64/archive-release.sh"
fi
echo "Verified assembled $PLATFORM release payload."
