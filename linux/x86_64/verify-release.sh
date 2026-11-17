#!/usr/bin/env bash

set -euo pipefail

: "${RELEASE_DIR:?Set RELEASE_DIR to the assembled Linux release payload.}"

readonly release_dir="$(cd "${RELEASE_DIR}" && pwd)"
readonly manylinux_image="quay.io/pypa/manylinux_2_28_x86_64@sha256:4dc41da7df20400310c80d162a2fe2d2c2f3d9734d8dec20f6b9843711618deb"

docker run --rm --entrypoint /bin/bash \
  -v "${release_dir}:/release:ro" \
  "${manylinux_image}" \
  -ceu '
    # These are intentionally host-provided by the release: they select the
    # target desktop X11/GL driver and ALSA device stack.
    dnf install -y --setopt=install_weak_deps=False \
      alsa-lib libX11 libXcursor libXi libXrandr libstdc++ mesa-libGL \
      mesa-dri-drivers xorg-x11-server-Xvfb
    # SFML creates an OpenGL context even for an audio-only Movie. Provide a
    # virtual display and silent OpenAL backend on headless CI/act runners.
    export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 ALSOFT_DRIVERS=null
    Xvfb "$DISPLAY" -screen 0 640x480x24 -nolisten tcp >/tmp/psdk-xvfb.log 2>&1 &
    xvfb_pid=$!
    trap "kill $xvfb_pid 2>/dev/null || true" EXIT
    for attempt in {1..50}; do
      test ! -S /tmp/.X11-unix/X99 || break
      kill -0 "$xvfb_pid" 2>/dev/null || { cat /tmp/psdk-xvfb.log; exit 1; }
      sleep 0.1
    done
    test -S /tmp/.X11-unix/X99 || { cat /tmp/psdk-xvfb.log; exit 1; }
    # Exercise relocation and the packaged setup script in a path with spaces.
    mkdir -p "/tmp/relocated game"
    cp -a /release "/tmp/relocated game/ruby-dist"
    cd "/tmp/relocated game/ruby-dist"
    unset RUBYOPT RUBYLIB GEM_HOME GEM_PATH
    export HOME=/tmp/psdk-home
    mkdir -p "$HOME"
    source ./setup.sh
    export PSDK_TEST_PLATFORM=linux
    ruby -I"$PWD/lib" lib/psdk-runtime/runtime-functional.rb
  '
