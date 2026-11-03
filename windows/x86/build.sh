#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
extract() {
  local name="$1" checksum url archive
  read -r _ checksum url < <(awk -v n="$name" '$1 == n {print}' "$ROOT/config/windows-x86-sources.lock")
  archive="$SOURCES/archives/$name.tar.${url##*.}"
  printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c -
  mkdir -p "$WORK/src/$name"
  tar -xf "$archive" --exclude='*/extlibs/libs-osx' --strip-components=1 -C "$WORK/src/$name"
}
cmake_build() {
  local name="$1"; shift
  cmake -S "$WORK/src/$name" -B "$WORK/build/$name" "${CMAKE_ARGS[@]}" "$@"
  cmake --build "$WORK/build/$name" --parallel "$JOBS"
  cmake --install "$WORK/build/$name"
}
dependency() {
  local name="$1"; shift
  if [[ ! -f "$WORK/stamps/$name" ]]; then
    extract "$name"
    "$@"
    touch "$WORK/stamps/$name"
  fi
}
autotools_build() {
  local name="$1"; shift
  (cd "$WORK/src/$name"
    ./configure --host=i686-w64-mingw32 --prefix="$PREFIX" --enable-shared --disable-static "$@"
    make -j"$JOBS"; make install)
}
ffmpeg_build() {
  (cd "$WORK/src/ffmpeg"
    ./configure --prefix="$PREFIX" --arch=x86 --target-os=mingw32 --cc=gcc --cxx=g++ \
      --enable-shared --disable-static --disable-programs --disable-doc --disable-network \
      --disable-autodetect --disable-avfilter --disable-postproc --disable-x86asm --disable-inline-asm \
      --enable-zlib --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS"
    python "$ROOT/windows/x86/normalize-ffmpeg-config.py" config.h "$ROOT" "$(cygpath -m "$ROOT")"
    make -j"$JOBS"; make install)
}
dependencies() {
  # OpenAL 1.23.1 relies on a transitive stdint include removed in newer GCC.
  dependency openal cmake_build openal -DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF -DALSOFT_TESTS=OFF "-DCMAKE_CXX_FLAGS=$CXXFLAGS -include cstdint"
  dependency fribidi autotools_build fribidi --disable-docs
  dependency libass autotools_build libass --disable-fontconfig --disable-asm
  dependency sfml cmake_build sfml -DSFML_USE_SYSTEM_DEPS=ON -DSFML_BUILD_EXAMPLES=OFF \
    -DSFML_BUILD_DOC=OFF -DSFML_BUILD_TEST_SUITE=OFF
  dependency ffmpeg ffmpeg_build
}
ruby_build() {
  extract ruby
  local bootstrap="$WORK/bootstrap/rubyinstaller-3.4.10-1-x86/bin/ruby.exe"
  "$bootstrap" -e 'abort unless RUBY_VERSION == "3.4.10" && [0].pack("J").bytesize == 4'
  mkdir -p "$WORK/build/ruby"
  (cd "$WORK/build/ruby"
    "$WORK/src/ruby/configure" --host=i686-w64-mingw32 --prefix="$(cygpath -m "$RUBY")" \
      --with-baseruby="$bootstrap" --enable-shared --enable-load-relative \
      --disable-install-doc --disable-dtrace --disable-yjit --disable-rjit \
      --with-openssl-dir="$(cygpath -m /mingw32)" --with-libyaml-dir="$(cygpath -m /mingw32)" --with-libffi-dir="$(cygpath -m /mingw32)" \
      --with-out-ext=dbm,gdbm,readline
    make -j"$JOBS"; make install)
}
graphics() {
  local cgss="$SOURCES/litergss/external/litecgss"
  cmake -S "$cgss" -B "$WORK/build/litecgss" "${CMAKE_ARGS[@]}" -DBUILD_SHARED_LIBS=ON \
    -DLITECGSS_NO_TEST=ON -DCGSS_NO_LOGS=ON
  cmake --build "$WORK/build/litecgss" --target LiteCGSS_engine --parallel "$JOBS"
  mkdir -p "$cgss/lib" "$PREFIX/bin" "$PREFIX/lib"
  cp "$WORK/build/litecgss/lib/"*.a "$cgss/lib/"
  cp "$WORK/build/litecgss/bin/"*.dll "$PREFIX/bin/"
  cp "$WORK/build/litecgss/lib/"*.a "$PREFIX/lib/"
  (cd "$SOURCES/litergss/ext/LiteRGSS"; "$RUBY/bin/ruby" extconf.rb; make -j"$JOBS")
  (cd "$SOURCES/sfmlaudio/ext/SFMLAudio"; "$RUBY/bin/ruby" extconf.rb --with-opt-dir="$(cygpath -m "$PREFIX")"; make -j"$JOBS")
}
movie() {
  local cgss="$SOURCES/litergss/external/litecgss"
  cmake -S "$SOURCES/sfemovie" -B "$WORK/build/sfemovie" "${CMAKE_ARGS[@]}" \
    -DSFEMOVIE_ENABLE_ASS_SUBTITLES=ON -DSFEMOVIE_BUILD_UNIT_TESTS=OFF -DSFEMOVIE_BUILD_DOC=OFF \
    "-DSFML_ROOT=$PREFIX" "-DFFMPEG_ROOT=$PREFIX" "-DLIBASS_ROOT=$PREFIX" \
    -DHARBUZZ_LIBRARY=/mingw32/lib/libharfbuzz.dll.a
  cmake --build "$WORK/build/sfemovie" --target sfeMovie --parallel "$JOBS"
  cp "$WORK/build/sfemovie/bin/"*.dll "$PREFIX/bin/"
  cp "$WORK/build/sfemovie/bin/"*.dll.a "$PREFIX/lib/"
  bash "$ROOT/.github/scripts/prepare-sfemovie-ruby.sh" "$SOURCES/sfemovie-ruby" "$SOURCES/litergss"
  (cd "$SOURCES/sfemovie-ruby/ext/SFEMovie"
    "$RUBY/bin/ruby" extconf.rb --with-sfeMovie-include="$SOURCES/sfemovie/include" --with-sfeMovie-lib="$PREFIX/lib" \
      --with-LiteCGSS_engine-include="$cgss/src" --with-LiteCGSS_engine-lib="$cgss/lib" \
      --with-LiteRGSS-include="$SOURCES/litergss/ext/LiteRGSS" \
      --with-sfml-system-include="$PREFIX/include" --with-sfml-system-lib="$PREFIX/lib" \
      --with-sfml-graphics-include="$PREFIX/include" --with-sfml-graphics-lib="$PREFIX/lib"
    make -j"$JOBS")
}
fmod() {
  : "${FMOD_SDK_DIR:?Set FMOD_SDK_DIR to the downloaded FMOD api/core directory}"
  FMOD_SDK_DIR="$(cygpath -u "$FMOD_SDK_DIR")"
  test "$(awk '/^#define FMOD_VERSION / {print $3}' "$FMOD_SDK_DIR/inc/fmod_common.h")" = "$FMOD_VERSION_HEX"
  cp "$FMOD_SDK_DIR/lib/x86/fmod.dll" "$PREFIX/bin/"
  cp "$FMOD_SDK_DIR/lib/x86/libfmod.a" "$PREFIX/lib/libfmod.a"
  (cd "$SOURCES/ruby-fmod/ext/RubyFmod"
    "$RUBY/bin/ruby" extconf.rb --with-opt-dir="$(cygpath -m "$PREFIX")" --with-cppflags="-I$(cygpath -m "$FMOD_SDK_DIR/inc")"
    make -j"$JOBS")
}
case "${1:-all}" in
  dependencies) dependencies;;
  ruby) ruby_build;;
  graphics) graphics;;
  movie) movie;;
  fmod) fmod;;
  all) dependencies; ruby_build; graphics; movie; fmod;;
  *) echo 'Usage: build.sh [dependencies|ruby|graphics|movie|fmod|all]' >&2; exit 2;;
esac
