"""Add the DLL assembly dependency to the source-built Ruby executables.

Preserve the existing executable code, GUI/console subsystem, version
resources and manifest settings. Update every manifest language variant.
"""
import ctypes as c
from ctypes import wintypes as w
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
from layout import NS, IDENTITY

k = c.WinDLL('kernel32', use_last_error=True)
callback_type = c.WINFUNCTYPE(w.BOOL, w.HMODULE, c.c_void_p, c.c_void_p, w.WORD, c.c_ssize_t)
signatures = {
    'LoadLibraryExW': ([w.LPCWSTR, w.HANDLE, w.DWORD], w.HMODULE),
    'FreeLibrary': ([w.HMODULE], w.BOOL),
    'EnumResourceLanguagesW': ([w.HMODULE, c.c_void_p, c.c_void_p, callback_type, c.c_ssize_t], w.BOOL),
    'FindResourceExW': ([w.HMODULE, c.c_void_p, c.c_void_p, w.WORD], w.HANDLE),
    'LoadResource': ([w.HMODULE, w.HANDLE], w.HANDLE),
    'SizeofResource': ([w.HMODULE, w.HANDLE], w.DWORD),
    'LockResource': ([w.HANDLE], c.c_void_p),
    'BeginUpdateResourceW': ([w.LPCWSTR, w.BOOL], w.HANDLE),
    'UpdateResourceW': ([w.HANDLE, c.c_void_p, c.c_void_p, w.WORD, c.c_void_p, w.DWORD], w.BOOL),
    'EndUpdateResourceW': ([w.HANDLE, w.BOOL], w.BOOL),
}
for name, (args, result) in signatures.items():
    getattr(k, name).argtypes = args
    getattr(k, name).restype = result


def embed(path):
    module = k.LoadLibraryExW(str(path.resolve()), None, 2)
    if not module: raise c.WinError(c.get_last_error())
    resources = []
    languages = []
    callback = callback_type(lambda module, kind, name, lang, param: languages.append(lang) or True)
    try:
        if not k.EnumResourceLanguagesW(module, 24, 1, callback, 0):
            raise c.WinError(c.get_last_error())
        for lang in languages:
            resource = k.FindResourceExW(module, 24, 1, lang)
            loaded = k.LoadResource(module, resource)
            pointer = k.LockResource(loaded)
            size = k.SizeofResource(module, resource)
            if not pointer or not size: raise c.WinError(c.get_last_error())
            tree = ET.fromstring(c.string_at(pointer, size).rstrip(b'\0'))
            existing = tree.findall(f'{{{NS}}}dependency/{{{NS}}}dependentAssembly/{{{NS}}}assemblyIdentity')
            if not any(node.attrib == IDENTITY for node in existing):
                dependency = ET.SubElement(tree, f'{{{NS}}}dependency')
                assembly = ET.SubElement(dependency, f'{{{NS}}}dependentAssembly')
                ET.SubElement(assembly, f'{{{NS}}}assemblyIdentity', IDENTITY)
            resources.append((lang, ET.tostring(tree, encoding='utf-8', xml_declaration=True)))
    finally:
        k.FreeLibrary(module)
    handle = k.BeginUpdateResourceW(str(path.resolve()), False)
    if not handle: raise c.WinError(c.get_last_error())
    try:
        for lang, data in resources:
            buffer = c.create_string_buffer(data)
            if not k.UpdateResourceW(handle, 24, 1, lang, buffer, len(data)):
                raise c.WinError(c.get_last_error())
    except BaseException:
        k.EndUpdateResourceW(handle, True)
        raise
    if not k.EndUpdateResourceW(handle, False): raise c.WinError(c.get_last_error())


if __name__ == '__main__':
    for filename in sys.argv[1:]:
        embed(Path(filename))
