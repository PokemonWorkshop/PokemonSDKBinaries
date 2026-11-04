#!/usr/bin/env python3
"""Audit i386 PE imports, and optionally stage their dependency closure.

Only explicit Windows system DLLs are exempt. Merely existing in System32 or
on PATH does not make a third-party DLL a system dependency.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct

SYSTEM = set('''advapi32 avrt bcrypt bcryptprimitives cabinet cfgmgr32 comctl32
comdlg32 crypt32 cryptbase cryptsp d2d1 d3d9 d3d11 dbghelp dnsapi dsound dwmapi imagehlp
dwrite dxgi gdi32 glu32 hid imm32 iphlpapi kernel32 kernelbase ksuser mpr msacm32
msimg32 msvcrt ncrypt netapi32 normaliz ntdll ole32 oleacc oleaut32 opengl32
powrprof propsys psapi rasapi32 rpcrt4 secur32 setupapi shell32 shlwapi user32
userenv usp10 uxtheme version winhttp wininet winmm winscard winspool wintrust
ws2_32 wtsapi32'''.split())


def system(name):
    return name.lower().removesuffix('.dll') in SYSTEM or name.lower().startswith(('api-ms-win-', 'ext-ms-win-'))


def inspect(path):
    data = path.read_bytes()
    def u16(offset): return struct.unpack_from('<H', data, offset)[0]
    def u32(offset): return struct.unpack_from('<I', data, offset)[0]
    if data[:2] != b'MZ':
        raise ValueError(f'{path}: not a PE image')
    pe = u32(0x3c)
    if data[pe:pe+4] != b'PE\0\0' or u16(pe+4) != 0x14c:
        raise ValueError(f'{path}: expected i386 PE (32-bit)')
    opt = pe + 24
    if u16(opt) != 0x10b:
        raise ValueError(f'{path}: expected PE32 optional header')
    sections = pe + 24 + u16(pe+20)
    def rva(address):
        if address < u32(opt+60): return address
        for index in range(u16(pe+6)):
            start = sections + index * 40
            size, va, raw_size, raw = struct.unpack_from('<IIII', data, start+8)
            if va <= address < va + max(size, raw_size): return raw + address - va
        raise ValueError(f'{path}: invalid RVA {address:#x}')
    def string(address):
        start = rva(address)
        return data[start:data.index(b'\0', start)].decode('ascii')
    imports = []
    for directory, stride, name_offset in ((1, 20, 12), (13, 32, 4)):
        if u32(opt+92) <= directory: continue
        address, size = struct.unpack_from('<II', data, opt+96+directory*8)
        if not address: continue
        entry = rva(address)
        end = min(len(data), entry+size)
        while entry + stride <= end and any(data[entry:entry+stride]):
            name_rva = u32(entry+name_offset)
            if directory == 13 and not u32(entry) & 1:
                name_rva -= u32(opt+28)
            name = string(name_rva)
            if '/' in name or '\\' in name or ':' in name:
                raise ValueError(f'{path}: absolute/path-containing DLL import {name}')
            imports.append(name.lower())
            entry += stride
    return sorted(set(imports))


def images(root):
    return sorted(p for p in root.rglob('*') if p.suffix.lower() in ('.exe', '.dll', '.so'))


def audit(root, search=(), forbidden=()):
    root = root.resolve()
    bindir = root / 'ruby_builtin_dlls'
    available = {}
    for folder in search:
        for path in Path(folder).glob('*.dll'):
            available.setdefault(path.name.lower(), path)
    pending = images(root)
    seen = set()
    report = {}
    while pending:
        path = pending.pop()
        if path in seen: continue
        seen.add(path)
        dependencies = inspect(path)
        data = path.read_bytes().lower()
        for token in forbidden:
            variants = {token, token.replace('\\', '/'), token.replace('/', '\\')}
            native = token.replace('\\', '/')
            if len(native) > 2 and native[1:3] == ':/':
                variants.add('/' + native[0].lower() + '/' + native[3:])
            for value in variants:
                if value and (value.lower().encode() in data or value.lower().encode('utf-16le') in data):
                    raise ValueError(f'{path}: embedded build path {value}')
        for name in dependencies:
            if system(name): continue
            local = next((p for d in (path.parent, root, bindir) for p in d.glob('*') if p.name.lower() == name), None)
            if local is None:
                if name not in available:
                    raise ValueError(f'{path.relative_to(root)}: missing non-system dependency {name}')
                source = available[name]
                inspect(source)
                local = bindir / source.name
                shutil.copy2(source, local)
            pending.append(local)
        report[path.relative_to(root).as_posix()] = {
            'machine': 'i386', 'imports': dependencies,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        }
    if not report: raise ValueError('No PE images found')
    return dict(sorted(report.items()))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--search', action='append', default=[])
    parser.add_argument('--forbid', action='append', default=[])
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    result = audit(args.root, args.search, args.forbid)
    if args.report: args.report.write_text(json.dumps(result, indent=2) + '\n')
    print(f'Validated {len(result)} i386 PE images and their DLL closure')
