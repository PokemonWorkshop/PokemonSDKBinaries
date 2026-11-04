"""Generate and validate the legacy Windows payload and private assembly."""
import argparse
from pathlib import Path
import xml.etree.ElementTree as ET

NS = 'urn:schemas-microsoft-com:asm.v1'
IDENTITY = {'type': 'win32', 'name': 'ruby_builtin_dlls', 'version': '1.0.0.0'}
ET.register_namespace('', NS)


def manifest(root, write=False):
    folder = root / 'ruby_builtin_dlls'
    path = folder / 'ruby_builtin_dlls.manifest'
    names = sorted(p.name for p in folder.glob('*.dll'))
    if not names:
        raise ValueError('No DLLs in ruby_builtin_dlls')
    if write:
        assembly = ET.Element(f'{{{NS}}}assembly', manifestVersion='1.0')
        ET.SubElement(assembly, f'{{{NS}}}assemblyIdentity', IDENTITY)
        for name in names:
            ET.SubElement(assembly, f'{{{NS}}}file', name=name)
        ET.indent(assembly)
        ET.ElementTree(assembly).write(path, encoding='utf-8', xml_declaration=True)
    assembly = ET.parse(path).getroot()
    if assembly.tag != f'{{{NS}}}assembly' or assembly.get('manifestVersion') != '1.0':
        raise ValueError('Invalid private assembly manifest')
    identity = assembly.find(f'{{{NS}}}assemblyIdentity')
    if identity is None or identity.attrib != IDENTITY:
        raise ValueError('Private assembly identity differs from the legacy launcher contract')
    entries = [node.get('name') for node in assembly.findall(f'{{{NS}}}file')]
    if sorted(entries) != names:
        raise ValueError('Manifest DLL entries do not exactly match packaged DLLs')


def verify(root):
    if {p.name for p in root.iterdir()} != {'lib', 'ruby_builtin_dlls', 'ruby.exe', 'rubyw.exe', 'msvcrt-ruby340.dll'}:
        raise ValueError('Windows payload must contain exactly lib/, ruby_builtin_dlls/, ruby.exe, rubyw.exe and msvcrt-ruby340.dll')
    for name in ('ruby.exe', 'rubyw.exe', 'msvcrt-ruby340.dll'):
        if not (root / name).is_file():
            raise ValueError(f'Missing {name}')
    for name in ('cert.pem', '__gem.rb', 'LiteRGSS.so', 'RubyFmod.so', 'SFEMovie.so', 'SFMLAudio.so'):
        if not (root / 'lib' / name).is_file():
            raise ValueError(f'Missing lib/{name}')
    for folder in ('3.4.0', 'gems/3.4.0'):
        if not (root / 'lib/ruby' / folder).is_dir():
            raise ValueError(f'Missing Ruby directory: {folder}')
    if list((root / 'lib').rglob('*.dll')) or {p.relative_to(root).as_posix() for p in root.rglob('*.exe')} != {'ruby.exe', 'rubyw.exe'}:
        raise ValueError('Unexpected nested DLL or executable')
    if (root / 'ruby_builtin_dlls/msvcrt-ruby340.dll').exists():
        raise ValueError('Ruby runtime DLL must exist only at the payload root')
    manifest(root)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--write-manifest', action='store_true')
    args = parser.parse_args()
    if args.write_manifest:
        manifest(args.root, write=True)
    verify(args.root)
    print('Legacy Windows layout and DLL assembly manifest validated')
