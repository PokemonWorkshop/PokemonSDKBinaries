#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/config/windows-x86.conf"
WORK="$ROOT/generated/windows-x86"
PREFIX="$WORK/prefix"
RUBY="$WORK/ruby"
SOURCES="$ROOT/sources"
export PATH="$RUBY/bin:$PREFIX/bin:/mingw32/bin:/usr/bin:/c/Windows/System32:/c/Windows"
unset RUBYOPT RUBYLIB GEM_HOME GEM_PATH CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH
export CC=gcc CXX=g++
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:/mingw32/lib/pkgconfig:/mingw32/share/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
export CPPFLAGS="-I$PREFIX/include"
export CFLAGS="-O2 -ffile-prefix-map=$ROOT=/psdk-build -ffile-prefix-map=$(cygpath -m "$ROOT")=/psdk-build"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L$PREFIX/lib"
export SFML_DIR="$(cygpath -m "$PREFIX")"
JOBS="${JOBS:-8}"
[[ "$(gcc -dumpmachine)" == i686-w64-mingw32 ]] || { echo 'Expected the isolated i686 MinGW compiler' >&2; exit 1; }
mkdir -p "$PREFIX" "$WORK/build" "$WORK/src" "$WORK/stamps"
CMAKE_ARGS=(-G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_INSTALL_PREFIX=$PREFIX"
  "-DCMAKE_PREFIX_PATH=$PREFIX;/mingw32" -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DBUILD_SHARED_LIBS=ON
  "-DCMAKE_C_FLAGS=$CFLAGS" "-DCMAKE_CXX_FLAGS=$CXXFLAGS"
  -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF)
