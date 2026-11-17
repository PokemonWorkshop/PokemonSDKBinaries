"""Keep FFmpeg's reported feature flags, replacing machine-specific paths."""
import sys
from pathlib import Path

path = Path(sys.argv[1])
roots = set(sys.argv[2:])
for root in tuple(roots):
    if len(root) > 2 and root[1:3] == ':/':
        roots.add('/' + root[0].lower() + '/' + root[3:])
lines = path.read_text().splitlines(keepends=True)
found = False
for index, line in enumerate(lines):
    if line.startswith('#define FFMPEG_CONFIGURATION '):
        found = True
        for root in sorted(roots, key=len, reverse=True):
            line = line.replace(root, '/psdk-build')
        lines[index] = line
if not found:
    raise SystemExit('Missing FFMPEG_CONFIGURATION definition')
path.write_text(''.join(lines))
