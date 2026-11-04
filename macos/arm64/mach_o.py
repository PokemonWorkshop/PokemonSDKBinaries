#!/usr/bin/env python3
"""Relocate, sign and audit Mach-O files in an assembled macOS runtime."""
import argparse
import os
from pathlib import Path
import re
import subprocess

SYSTEM = ('/usr/lib/', '/System/Library/')


def output(*args):
    return subprocess.check_output([str(a) for a in args], text=True)


def run(*args):
    subprocess.run([str(a) for a in args], check=True)


def machos(root):
    for path in sorted(root.rglob('*')):
        if path.is_file() and not path.is_symlink():
            with path.open('rb') as stream:
                magic = stream.read(4)
            if magic in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'):
                yield path


def dependencies(path):
    # otool -L includes the dylib's own ID; handle it separately.
    ids = output('otool', '-D', path).splitlines()[1:]
    return [line.strip().split(' (compatibility version', 1)[0]
            for line in output('otool', '-L', path).splitlines()[1:]
            if line.strip() not in ids and line.strip().split(' (compatibility version', 1)[0] not in ids]


def audit(root):
    count = 0
    for link in root.rglob('*'):
        if link.is_symlink():
            if not link.exists() or not link.resolve().is_relative_to(root.resolve()):
                raise RuntimeError(f'Broken or external symlink: {link}')
    for path in machos(root):
        count += 1
        if output('lipo', '-archs', path).strip() != 'arm64':
            raise RuntimeError(f'Not exclusively arm64: {path}')
        commands = output('otool', '-l', path)
        minimums = re.findall(r'\bminos ([0-9.]+)', commands)
        minimums += re.findall(r'cmd LC_VERSION_MIN_MACOSX\s+cmdsize \d+\s+version ([0-9.]+)', commands)
        if not minimums or any(tuple(map(int, v.split('.'))) > (11, 0, 0) for v in minimums):
            raise RuntimeError(f'Invalid macOS 11.0 deployment target: {path}: {minimums}')
        for dep in dependencies(path):
            if dep.startswith(SYSTEM):
                continue
            if not dep.startswith('@loader_path/'):
                raise RuntimeError(f'Nonportable dependency: {path}: {dep}')
            target = (path.parent / dep[len('@loader_path/'):]).resolve()
            if not target.is_relative_to(root.resolve()) or not target.is_file():
                raise RuntimeError(f'Missing/private dependency escapes package: {path}: {dep}')
        for rpath in re.findall(r'cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset', commands):
            if not rpath.startswith(('@loader_path', '@executable_path')):
                raise RuntimeError(f'Build rpath remains: {path}: {rpath}')
        run('codesign', '--verify', '--strict', path)
    if count < 20:
        raise RuntimeError('Runtime is incomplete: too few Mach-O files')
    print(f'Verified {count} signed arm64 Mach-O files: macOS 11.0 or older, private/system dependencies only.')



def relocate(root):
    lib = root / 'lib'
    # 7-Zip rejects symlink chains during safe extraction. Preserve every
    # library alias, but point it straight at the packaged physical file.
    for link in root.rglob('*'):
        if link.is_symlink():
            target = link.resolve(strict=True)
            if not target.is_relative_to(root.resolve()):
                raise RuntimeError(f'External symlink cannot be packaged: {link}')
            link.unlink()
            link.symlink_to(os.path.relpath(target, link.parent))
    for path in machos(root):
        path.chmod(0o755)
        args = ['install_name_tool']
        if path.suffix == '.dylib':
            args += ['-id', '@rpath/' + path.name]
        for dep in dependencies(path):
            if dep.startswith(SYSTEM):
                continue
            target = lib / Path(dep).name
            if not target.exists():
                raise RuntimeError(f'Refusing to copy an unbuilt host dependency: {path}: {dep}')
            args += ['-change', dep, '@loader_path/' + os.path.relpath(target, path.parent)]
        commands = output('otool', '-l', path)
        for rpath in set(re.findall(r'cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset', commands)):
            args += ['-delete_rpath', rpath]
        if len(args) > 1:
            run(*args, path)
        run('codesign', '--force', '--sign', '-', path)
    audit(root)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--verify', type=Path)
    action.add_argument('--relocate', type=Path)
    args = parser.parse_args()
    if args.verify:
        audit(args.verify.resolve())
    else:
        relocate(args.relocate.resolve())
