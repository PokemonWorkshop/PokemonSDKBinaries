#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
OUT="$WORK/Windows-x86"
python "$ROOT/windows/x86/layout.py" "$OUT"
python "$ROOT/windows/x86/pe.py" "$OUT" --forbid "$(cygpath -m "$ROOT")" --forbid "$ROOT"
RELOCATED="$WORK/relocated smoke/payload"
[[ ! -e "$RELOCATED" ]] || { echo 'Relocation destination already exists' >&2; exit 1; }
mkdir -p "$(dirname "$RELOCATED")"
cp -a "$OUT" "$RELOCATED"
"$(cygpath -u "$SYSTEMROOT")/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -m "$ROOT/windows/x86/verify-runtime.ps1")" -Runtime "$(cygpath -m "$RELOCATED")"
python "$ROOT/windows/x86/layout.py" "$RELOCATED"
mkdir -p "$ROOT/dist"
[[ ! -e "$ROOT/dist/Windows.7z" ]] || { echo 'Archive already exists; move it aside before archiving again' >&2; exit 1; }
(cd "$OUT"; 7z a -t7z "$ROOT/dist/Windows.7z" lib ruby_builtin_dlls ruby.exe rubyw.exe msvcrt-ruby340.dll)
(cd "$ROOT/dist"; sha256sum Windows.7z > Windows.7z.sha256)
