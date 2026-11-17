#!/usr/bin/env bash
set -euo pipefail
readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly mode="${1:-build}"
case "$mode" in
  build|archive) ;;
  *) echo 'Usage: bootstrap-tools.sh [build|archive]' >&2; exit 1 ;;
esac
[[ "$(uname -s)-$(uname -m)" == Darwin-arm64 ]] || { echo 'An Apple Silicon macOS host is required.' >&2; exit 1; }
# Bootstrap against Apple's tools rather than any installed Homebrew toolchain.
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
unset CPPFLAGS LDFLAGS CFLAGS CXXFLAGS CPATH LIBRARY_PATH PKG_CONFIG_PATH PKG_CONFIG_LIBDIR
readonly lock="$root/config/macos-arm64-tools.lock"
readonly work="$root/generated/macos-arm64-tools"
readonly lock_digest="$(cat "$lock" "$root/macos/arm64/bootstrap-tools.sh" | shasum -a 256 | awk '{print $1}')"
readonly tools="$work/$lock_digest"
readonly prefix="$tools/prefix"
mkdir -p "$work/archives" "$prefix/bin"

fetch() {
  local name="$1" checksum url
  read -r checksum url < <(awk -v name="$name" '$1 == name {print $2, $3}' "$lock")
  : "${checksum:?Missing checksum for $name}" "${url:?Missing URL for $name}"
  archive="$work/archives/${url##*/}"
  if [[ ! -f "$archive" ]]; then
    curl -fLsS --retry 3 --connect-timeout 30 --max-time 600 "$url" -o "$archive.tmp"
    printf '%s  %s\n' "$checksum" "$archive.tmp" | shasum -a 256 -c -
    mv "$archive.tmp" "$archive"
  else
    printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c -
  fi
}

# Fresh verification runners need only the extractor, built with Apple's tools.
fetch sevenzip
if [[ ! -f "$tools/sevenzip-installed" ]]; then
  rm -rf -- "$tools/sevenzip"
  mkdir -p "$tools/sevenzip"
  tar -xf "$archive" -C "$tools/sevenzip"
  (
    cd "$tools/sevenzip/CPP/7zip/Bundles/Alone2"
    # Upstream's macOS binary requires macOS 26; build for all our CI runners.
    # Keep Apple's default ARM features, including AES, as upstream does.
    MACOSX_DEPLOYMENT_TARGET=11.0 make -j"${JOBS:-$(sysctl -n hw.ncpu)}" \
      -f ../../cmpl_mac_arm64.mak DISABLE_RAR_COMPRESS=1 \
      'MY_ARCH=-arch arm64 -mmacosx-version-min=11.0'
    install -m 0755 b/m_arm64/7zz "$prefix/bin/7zz"
  )
  touch "$tools/sevenzip-installed"
fi

if [[ "$mode" == build ]]; then
  fetch cmake
  if [[ ! -f "$tools/cmake-installed" ]]; then
    mkdir -p "$tools/cmake"
    tar -xf "$archive" --strip-components=1 -C "$tools/cmake"
    for command in cmake ctest cpack; do
      ln -sf "$tools/cmake/CMake.app/Contents/bin/$command" "$prefix/bin/$command"
    done
    touch "$tools/cmake-installed"
  fi
  fetch ninja
  if [[ ! -f "$tools/ninja-installed" ]]; then
    mkdir -p "$tools/ninja"
    /usr/bin/ditto -x -k "$archive" "$tools/ninja"
    install -m 0755 "$tools/ninja/ninja" "$prefix/bin/ninja"
    touch "$tools/ninja-installed"
  fi
  fetch pkgconf
  if [[ ! -f "$tools/pkgconf-installed" ]]; then
    # Recreate a partial source build before retrying it.
    rm -rf -- "$tools/pkgconf"
    mkdir -p "$tools/pkgconf"
    tar -xf "$archive" --strip-components=1 -C "$tools/pkgconf"
    (
      cd "$tools/pkgconf"
      CC=/usr/bin/clang CXX=/usr/bin/clang++ ./configure --prefix="$prefix" \
        --disable-shared --enable-static --with-pkg-config-dir=/usr/lib/pkgconfig
      make -j"${JOBS:-$(sysctl -n hw.ncpu)}"
      make install
    )
    ln -sf pkgconf "$prefix/bin/pkg-config"
    touch "$tools/pkgconf-installed"
  fi
fi

# Lock or bootstrap changes select a new installation instead of old tool stamps.
ln -sfn "$prefix/bin" "$work/bin"
if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "$work/bin" >> "$GITHUB_PATH"
fi
if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'PSDK_BUILD_TOOLS_BIN=%s\nSEVENZIP=%s\n' "$work/bin" "$work/bin/7zz" >> "$GITHUB_ENV"
fi
if [[ "$mode" == build ]]; then
  "$work/bin/cmake" --version
  "$work/bin/ninja" --version
  "$work/bin/pkgconf" --version
fi
"$work/bin/7zz" i | sed -n '2,3p'
