#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT="$WORK/Windows-x86"
[[ ! -e "$OUT" ]] || { echo "Assembly destination exists: $OUT; move it aside before assembling again" >&2; exit 1; }
mkdir -p "$OUT/ruby_builtin_dlls"
cp -a "$RUBY/lib" "$OUT/"
python "$ROOT/windows/x86/stage-legacy-gems.py" "$OUT"
cp "$RUBY/bin/ruby.exe" "$RUBY/bin/rubyw.exe" "$RUBY/bin/msvcrt-ruby340.dll" "$OUT/"
for extension in litergss/LiteRGSS sfmlaudio/SFMLAudio ruby-fmod/RubyFmod sfemovie-ruby/SFEMovie; do
  repo="${extension%/*}"; name="${extension#*/}"
  cp "$SOURCES/$repo/ext/$name/$name.so" "$OUT/lib/"
done
META="$OUT/lib/psdk-runtime"
mkdir -p "$META/licenses"
cp /mingw32/etc/ssl/cert.pem "$OUT/lib/cert.pem"
cp "$ROOT/windows/x86/__gem.rb" "$OUT/lib/__gem.rb"
cp "$ROOT/windows/x86/smoke.rb" "$ROOT/tests/sfemovie-texture.rb" "$META/"
cp "$ROOT/tests/runtime-functional.rb" "$META/"
cp "$ROOT/config/windows-x86"* "$META/licenses/"
cp "$ROOT/config/windows-x86.conf" "$META/BUILD-INFO"
gcc --version >> "$META/BUILD-INFO"
cp "$WORK/src/ruby/COPYING" "$META/licenses/Ruby-COPYING"
cp "$WORK/src/ffmpeg/COPYING.LGPLv2.1" "$META/licenses/FFmpeg-COPYING.LGPLv2.1"
cp -a /mingw32/share/licenses "$META/licenses/MSYS2"
for source in "$WORK/src/"* "$SOURCES/litergss" "$SOURCES/litergss/external/litecgss" \
  "$SOURCES/litergss/external/litecgss/external/skalog" "$SOURCES/ruby-fmod" \
  "$SOURCES/sfmlaudio" "$SOURCES/sfemovie" "$SOURCES/sfemovie-ruby"; do
  name="$(basename "$source")"
  mkdir -p "$META/licenses/$name"
  find "$source" -maxdepth 1 -type f \( -iname 'license*' -o -iname 'copying*' -o -iname 'notice*' \) \
    -exec cp '{}' "$META/licenses/$name/" \;
done
cp "$ROOT/macos/arm64/clean_load_path.rb" "$OUT/lib/clean_load_path.rb"
# Build metadata and development libraries are not runtime payloads.
find "$OUT" -type f \( -name '*.a' -o -name '*.h' -o -name 'mkmf.log' \) -delete
python "$ROOT/windows/x86/pe.py" "$OUT" --search "$PREFIX/bin" --search /mingw32/bin \
  --report "$META/pe-manifest.json"
while IFS= read -r -d '' binary; do strip --strip-debug "$binary"; done < <(find "$OUT" -type f \( -name '*.exe' -o -name '*.dll' -o -name '*.so' \) -print0)
# Windows resource updates must follow stripping MinGW debug sections.
python "$ROOT/windows/x86/embed-manifest.py" "$OUT/ruby.exe" "$OUT/rubyw.exe"
# Recheck with no external DLL search directories after closure is staged.
python "$ROOT/windows/x86/pe.py" "$OUT" --forbid "$(cygpath -m "$ROOT")" --forbid "$ROOT" --report "$META/pe-manifest.json"
python "$ROOT/windows/x86/layout.py" "$OUT" --write-manifest
echo "Assembled $OUT"
