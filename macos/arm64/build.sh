#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/config/macos-arm64.conf"
[[ "$(uname -s)-$(uname -m)" == Darwin-arm64 ]] || { echo 'An Apple Silicon macOS host is required.' >&2; exit 1; }
export MACOSX_DEPLOYMENT_TARGET
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
export CC=/usr/bin/clang CXX=/usr/bin/clang++
# CI selects private pinned tools; local Homebrew tools remain an alternative.
# Never discover Homebrew runtime libraries.
export PATH="${PSDK_BUILD_TOOLS_BIN:+$PSDK_BUILD_TOOLS_BIN:}/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
unset RUBYOPT RUBYLIB GEM_HOME GEM_PATH CPATH LIBRARY_PATH DYLD_LIBRARY_PATH DYLD_FALLBACK_LIBRARY_PATH
WORK="$ROOT/generated/macos-arm64"
PREFIX="$WORK/prefix"
RUBY="$WORK/ruby"
SOURCES="$ROOT/sources"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
mkdir -p "$WORK" "$PREFIX" "$WORK/stamps"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
export CPPFLAGS="-I$PREFIX/include"
export CFLAGS="-O2 -arch arm64 -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L$PREFIX/lib -arch arm64 -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET -Wl,-headerpad_max_install_names"
CMAKE_ARGS=(-G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_INSTALL_PREFIX=$PREFIX"
  -DCMAKE_OSX_ARCHITECTURES=arm64 "-DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
  "-DCMAKE_OSX_SYSROOT=$SDKROOT" "-DCMAKE_PREFIX_PATH=$PREFIX"
  '-DCMAKE_IGNORE_PREFIX_PATH=/opt/homebrew;/usr/local' -DCMAKE_FIND_FRAMEWORK=LAST
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_SHARED_LIBS=ON
  -DCMAKE_INSTALL_NAME_DIR=@rpath)
extract() {
  local name="$1" archive checksum
  archive="$(find "$SOURCES/archives" -name "$name.tar.*" -maxdepth 1 -print -quit)"
  test -n "$archive"
  checksum="$(awk -v name="$name" '$1 == name {print $2}' "$ROOT/config/macos-arm64-sources.lock")"
  test -n "$checksum"
  printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c -
  mkdir -p "$WORK/src/$name"
  tar -xf "$archive" --strip-components=1 -C "$WORK/src/$name"
}
cmake_build() {
  local name="$1"; shift
  cmake -S "$WORK/src/$name" -B "$WORK/build/$name" "${CMAKE_ARGS[@]}" "$@"
  cmake --build "$WORK/build/$name" --parallel "$JOBS"
  cmake --install "$WORK/build/$name"
}
autotools_build() {
  local name="$1"; shift
  (cd "$WORK/src/$name"; ./configure --prefix="$PREFIX" --disable-static --enable-shared "$@"
    make -j"$JOBS"; make install)
}
dependency() {
  local name="$1"; shift
  if [[ ! -f "$WORK/stamps/$name" ]]; then
    extract "$name"
    "$@"
    touch "$WORK/stamps/$name"
  fi
}
openssl_build() {
  (cd "$WORK/src/openssl"
    ./Configure darwin64-arm64-cc shared no-tests no-module --prefix="$PREFIX" --openssldir=/etc/ssl
    make -j"$JOBS"; make install_sw)
}
dependencies() {
  dependency openssl openssl_build
  dependency yaml autotools_build yaml
  dependency ogg cmake_build ogg -DBUILD_TESTING=OFF
  dependency vorbis cmake_build vorbis -DBUILD_TESTING=OFF
  dependency flac cmake_build flac -DBUILD_CXXLIBS=OFF -DBUILD_PROGRAMS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF -DINSTALL_MANPAGES=OFF
  dependency freetype cmake_build freetype -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_PNG=ON -DFT_DISABLE_BROTLI=ON -DFT_DISABLE_BZIP2=ON
  dependency harfbuzz cmake_build harfbuzz -DHB_HAVE_FREETYPE=ON -DHB_HAVE_GLIB=OFF -DHB_HAVE_ICU=OFF -DHB_BUILD_UTILS=OFF -DHB_BUILD_TESTS=OFF
  dependency fribidi autotools_build fribidi --disable-docs
  # The Apple SDK provides zlib without a pkg-config file. Supply the known
  # source-built font libraries explicitly instead of searching Homebrew.
  FREETYPE_CFLAGS="-I$PREFIX/include/freetype2" FREETYPE_LIBS="-L$PREFIX/lib -lfreetype" \
  HARFBUZZ_CFLAGS="-I$PREFIX/include/harfbuzz" HARFBUZZ_LIBS="-L$PREFIX/lib -lharfbuzz" \
    dependency libass autotools_build libass --disable-fontconfig --disable-require-system-font-provider
  dependency sfml cmake_build sfml -DSFML_BUILD_FRAMEWORKS=OFF -DSFML_BUILD_AUDIO=ON -DSFML_BUILD_NETWORK=ON \
    -DSFML_BUILD_EXAMPLES=OFF -DSFML_BUILD_DOC=OFF -DSFML_BUILD_TEST_SUITE=OFF \
    "-DFREETYPE_LIBRARY=$PREFIX/lib/libfreetype.dylib" "-DFREETYPE_INCLUDE_DIR_freetype2=$PREFIX/include/freetype2" \
    "-DFREETYPE_INCLUDE_DIR_ft2build=$PREFIX/include/freetype2" \
    "-DOGG_LIBRARY=$PREFIX/lib/libogg.dylib" "-DOGG_INCLUDE_DIR=$PREFIX/include" \
    "-DVORBIS_LIBRARY=$PREFIX/lib/libvorbis.dylib" "-DVORBISFILE_LIBRARY=$PREFIX/lib/libvorbisfile.dylib" \
    "-DVORBISENC_LIBRARY=$PREFIX/lib/libvorbisenc.dylib" "-DVORBIS_INCLUDE_DIR=$PREFIX/include" \
    "-DFLAC_LIBRARY=$PREFIX/lib/libFLAC.dylib" "-DFLAC_INCLUDE_DIR=$PREFIX/include" \
    "-DOPENAL_LIBRARY=$SDKROOT/System/Library/Frameworks/OpenAL.framework" \
    "-DOPENAL_INCLUDE_DIR=$SDKROOT/System/Library/Frameworks/OpenAL.framework/Headers"
}
ruby_build() {
  extract ruby
  mkdir -p "$WORK/build/ruby"
  (cd "$WORK/build/ruby"
    "$WORK/src/ruby/configure" --prefix="$RUBY" --enable-shared --enable-load-relative \
      --disable-install-doc --disable-dtrace --disable-yjit --disable-rjit --without-gmp \
      --with-openssl-dir="$PREFIX" --with-libyaml-dir="$PREFIX" --with-out-ext=dbm,gdbm,readline
    make -j"$JOBS"; make install)
}
ffmpeg_build() {
  (cd "$WORK/src/ffmpeg"
    ./configure --prefix="$PREFIX" --cc="$CC" --cxx="$CXX" --arch=aarch64 --cpu=generic --target-os=darwin \
      --enable-shared --disable-static --disable-programs --disable-doc --disable-network \
      --disable-autodetect --disable-avfilter --disable-postproc --disable-inline-asm \
      --enable-zlib --enable-decoder=png --enable-decoder=movtext \
      --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS" --install-name-dir="$PREFIX/lib"
    make -j"$JOBS"; make install)
}
components() {
  dependency ffmpeg ffmpeg_build
  export PATH="$RUBY/bin:$PATH" SFML_DIR="$PREFIX"
  # These are dedicated source copies; never modify sibling developer checkouts.
  local cgss="$SOURCES/litergss/external/litecgss"
  cmake -S "$cgss" -B "$WORK/build/litecgss" "${CMAKE_ARGS[@]}" -DBUILD_SHARED_LIBS=OFF \
    -DLITECGSS_NO_TEST=ON -DCGSS_NO_LOGS=ON
  cmake --build "$WORK/build/litecgss" --target LiteCGSS_engine --parallel "$JOBS"
  mkdir -p "$cgss/lib"
  cp "$WORK/build/litecgss/lib/"*.a "$cgss/lib/"
  (cd "$SOURCES/litergss/ext/LiteRGSS"
    ruby extconf.rb
    if "$CXX" -frelaxed-template-template-args -x c++ -c /dev/null -o /dev/null 2>/dev/null; then
      make -j"$JOBS"
    else
      # New Apple Clang removed this upstream compatibility flag. Override
      # only this make variable; leave the repository's extconf.rb untouched.
      make -j"$JOBS" CXXFLAGS="$(sed -n 's/^CXXFLAGS = //p' Makefile | sed 's/-frelaxed-template-template-args//g')"
    fi)
  (cd "$SOURCES/sfmlaudio/ext/SFMLAudio"
    ruby extconf.rb
    make -j"$JOBS")
  : "${FMOD_SDK_DIR:?Set FMOD_SDK_DIR to the FMOD Core directory containing inc/ and lib/.}"
  test "$(awk '/^#define FMOD_VERSION / {print $3}' "$FMOD_SDK_DIR/inc/fmod_common.h")" = "$FMOD_VERSION_HEX"
  # mkmf embeds these strings in shell commands and the generated Makefile.
  # Quoting the extconf argument alone does not protect spaces inside a flag.
  local fmod_include fmod_library
  printf -v fmod_include '%q' "$FMOD_SDK_DIR/inc"
  printf -v fmod_library '%q' "$FMOD_SDK_DIR/lib"
  (cd "$SOURCES/ruby-fmod/ext/RubyFmod"
    ruby extconf.rb --with-cppflags="$CPPFLAGS -I$fmod_include" \
      --with-ldflags="$LDFLAGS -L$fmod_library" || {
        # mkmf's generic "install development tools" message hides linker
        # errors. Print the diagnostic before CI cleans up the SDK.
        [[ ! -f mkmf.log ]] || cat mkmf.log >&2
        exit 1
      }
    make -j"$JOBS")
  # Use the upstream framework target, then stage its Mach-O image as a
  # private dylib so the existing Ruby extconf can link with -lsfeMovie.
  cmake -S "$SOURCES/sfemovie" -B "$WORK/build/sfemovie" "${CMAKE_ARGS[@]}" \
    -DSFEMOVIE_ENABLE_ASS_SUBTITLES=ON -DSFEMOVIE_BUILD_UNIT_TESTS=OFF -DSFEMOVIE_BUILD_DOC=OFF \
    "-DSFML_ROOT=$PREFIX" "-DFFMPEG_ROOT=$PREFIX"
  cmake --build "$WORK/build/sfemovie" --target sfeMovie --parallel "$JOBS"
  cp "$WORK/build/sfemovie/bin/sfeMovie.framework/Versions/2.0/sfeMovie" "$PREFIX/lib/libsfeMovie.dylib"
  install_name_tool -id "$PREFIX/lib/libsfeMovie.dylib" "$PREFIX/lib/libsfeMovie.dylib"
  codesign --force --sign - "$PREFIX/lib/libsfeMovie.dylib"
  bash "$ROOT/.github/scripts/prepare-sfemovie-ruby.sh" "$SOURCES/sfemovie-ruby" "$SOURCES/litergss"
  (cd "$SOURCES/sfemovie-ruby/ext/SFEMovie"
    ruby extconf.rb --with-sfeMovie-include="$SOURCES/sfemovie/include" --with-sfeMovie-lib="$PREFIX/lib" \
      --with-LiteCGSS_engine-include="$cgss/src" --with-LiteCGSS_engine-lib="$cgss/lib" \
      --with-LiteRGSS-include="$SOURCES/litergss/ext/LiteRGSS" \
      --with-sfml-system-include="$PREFIX/include" --with-sfml-system-lib="$PREFIX/lib" \
      --with-sfml-graphics-include="$PREFIX/include" --with-sfml-graphics-lib="$PREFIX/lib"
    make -j"$JOBS")
}
case "${1:-all}" in
  dependencies) dependencies ;;
  ruby) ruby_build ;;
  components) components ;;
  all) dependencies; ruby_build; components ;;
  *) echo "Usage: $0 [all|dependencies|ruby|components]" >&2; exit 2 ;;
esac
