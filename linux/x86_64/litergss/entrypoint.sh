#!/usr/bin/env bash
set -euo pipefail
/usr/local/bin/upstream-entrypoint.sh
# Source-built libraries must not retain the private builder prefix at runtime.
while IFS= read -r -d '' library; do
  patchelf --force-rpath --set-rpath '$ORIGIN' "$library"
done < <(find /output/lib -maxdepth 1 -type f -name '*.so*' -print0)
mkdir -p /output/lib/psdk-runtime
cp /opt/psdk/sources.lock /output/lib/psdk-runtime/linux-sources.lock
cp /opt/psdk/distribution-packages.txt /output/lib/psdk-runtime/linux-distribution-packages.txt
