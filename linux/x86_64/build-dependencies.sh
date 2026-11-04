#!/usr/bin/env bash
set -euo pipefail
source /opt/psdk/locked-source.sh
readonly prefix=/opt/psdk/deps
readonly jobs="$(nproc)"
# Use the baseline compiler for portable libraries, including their C++ ABI.
export CC=/usr/bin/gcc CXX=/usr/bin/g++
export CPPFLAGS="-I$prefix/include"
export LDFLAGS="-L$prefix/lib -Wl,-rpath,$prefix/lib"
export PKG_CONFIG_PATH="$prefix/lib/pkgconfig:$prefix/share/pkgconfig"
export LD_LIBRARY_PATH="$prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

cmake_build() {
  local name="$1"; shift
  extract_source "$name"
  cmake -S "/tmp/psdk-src/$name" -B "/tmp/psdk-build/$name" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_PREFIX_PATH="$prefix" \
    '-DCMAKE_INSTALL_RPATH=$ORIGIN' -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF "$@"
  cmake --build "/tmp/psdk-build/$name" --parallel "$jobs"
  cmake --install "/tmp/psdk-build/$name"
}
autotools_build() {
  local name="$1"; shift
  extract_source "$name"
  (cd "/tmp/psdk-src/$name"
    ./configure --prefix="$prefix" --libdir="$prefix/lib" --disable-static --enable-shared "$@"
    make -j"$jobs"
    make install)
}

extract_source openssl
(cd /tmp/psdk-src/openssl
  ./Configure linux-x86_64 shared no-tests no-module \
    --prefix="$prefix" --libdir=lib --openssldir=/etc/ssl
  make -j"$jobs"
  make install_sw)
extract_source zlib
(cd /tmp/psdk-src/zlib
  ./configure --prefix="$prefix" --shared
  make -j"$jobs"
  make install)
autotools_build yaml
# Otherwise GCC's multi-os directory can redirect libffi to lib/../lib64,
# outside the private lib directory registered with the runtime loader.
autotools_build libffi --disable-docs --disable-multi-os-directory
cmake_build ogg
cmake_build vorbis
cmake_build flac -DBUILD_CXXLIBS=OFF -DBUILD_PROGRAMS=OFF \
  -DBUILD_EXAMPLES=OFF -DINSTALL_MANPAGES=OFF
cmake_build openal -DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF -DALSOFT_TESTS=OFF \
  -DALSOFT_BACKEND_ALSA=ON -DALSOFT_REQUIRE_ALSA=ON -DALSOFT_BACKEND_PULSEAUDIO=OFF \
  -DALSOFT_BACKEND_PIPEWIRE=OFF -DALSOFT_BACKEND_JACK=OFF -DALSOFT_BACKEND_OSS=OFF \
  -DALSOFT_BACKEND_PORTAUDIO=OFF -DALSOFT_BACKEND_SNDIO=OFF \
  -DALSOFT_BACKEND_SDL2=OFF -DALSOFT_BACKEND_SDL3=OFF \
  -DALSOFT_INSTALL_CONFIG=OFF -DALSOFT_INSTALL_HRTF_DATA=OFF \
  -DALSOFT_INSTALL_AMBDEC_PRESETS=OFF
cmake_build freetype -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_PNG=ON \
  -DFT_DISABLE_BROTLI=ON -DFT_DISABLE_BZIP2=ON
cmake_build harfbuzz -DHB_HAVE_FREETYPE=ON -DHB_HAVE_GLIB=OFF -DHB_HAVE_ICU=OFF \
  -DHB_BUILD_UTILS=OFF -DHB_BUILD_TESTS=OFF -DHB_BUILD_SUBSET=OFF \
  -DHB_BUILD_RASTER=OFF -DHB_BUILD_VECTOR=OFF -DHB_BUILD_GPU=OFF
autotools_build fribidi --disable-docs
# Retain the distribution's font discovery integration and /etc/fonts config.
autotools_build libass --enable-fontconfig --disable-asm

# Minimal images need not include /etc/ld.so.conf.d from ld.so.conf.
# Register directly so Ruby's extensions and the staging ldd calls resolve
# source-built libraries even after this script's LD_LIBRARY_PATH is gone.
printf '\n%s\n' "$prefix/lib" >> /etc/ld.so.conf
ldconfig
rm -rf /tmp/psdk-src /tmp/psdk-build
