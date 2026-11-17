"""Expose former stdlib gems to PSDK's --disable=gems launcher.

Use only gems shipped with the checksum-pinned Ruby source build. Keep their
normal gem installations too, for applications that enable RubyGems.
"""
from pathlib import Path
import shutil
import sys

RUNTIME_GEMS = (
    'csv', 'rexml', 'rss', 'matrix', 'prime', 'net-ftp', 'net-imap',
    'net-pop', 'net-smtp', 'mutex_m', 'getoptlong', 'base64', 'bigdecimal',
    'observer', 'abbrev', 'resolv-replace', 'rinda', 'drb', 'nkf', 'racc',
)


def stage(root):
    gems = root / 'lib/ruby/gems/3.4.0'
    destination = root / 'lib/ruby/site_ruby/3.4.0'

    def copy(source, relative):
        target = destination / relative
        if target.exists() and target.read_bytes() != source.read_bytes():
            raise ValueError(f'Conflicting compatibility library: {target}')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)

    for name in RUNTIME_GEMS:
        specs = list((gems / 'specifications').glob(f'{name}-[0-9]*.gemspec'))
        if len(specs) != 1:
            raise ValueError(f'Expected one source-built bundled gem: {name}')
        full_name = specs[0].stem
        library = gems / 'gems' / full_name / 'lib'
        if not library.is_dir():
            raise ValueError(f'Missing bundled gem library: {full_name}')
        for source in library.rglob('*'):
            if source.is_file():
                copy(source, source.relative_to(library))
        for extension in (gems / 'extensions').glob(f'*/*/{full_name}'):
            for source in extension.rglob('*.so'):
                copy(source, source.relative_to(extension))
        print(f'Staged legacy require paths: {full_name}')


if __name__ == '__main__':
    stage(Path(sys.argv[1]))
