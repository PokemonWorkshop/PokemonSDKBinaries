#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
python -u "$ROOT/.github/scripts/download_fmod.py" --version "$FMOD_DOWNLOAD_VERSION" \
  --platform windows --output "$WORK/fmod-download.exe"
mkdir -p "$WORK/fmod-sdk"
# FMOD distributes a Windows installer, not a zip. 7-Zip extracts the NSIS
# payload without running an installer or writing to Program Files (x86).
7z x -y "$WORK/fmod-download.exe" "-o$WORK/fmod-sdk"
core="$(find "$WORK/fmod-sdk" -path '*/core/inc/fmod_common.h' -print -quit)"
test -n "$core"
core="${core%/inc/fmod_common.h}"
test -f "$core/lib/x86/fmod.dll"
test -f "$core/lib/x86/libfmod.a"
printf '%s\n' "FMOD_SDK_DIR=$(cygpath -m "$core")" >> "${GITHUB_ENV:?Expected GitHub Actions environment file}"
