import struct
import tempfile
import unittest
from pathlib import Path
from pe import inspect, audit


def fixture(path, imports=(), machine=0x14c, delay=False):
    data = bytearray(2048)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 0x3c, 0x80)
    data[0x80:0x84] = b'PE\0\0'
    struct.pack_into('<HH', data, 0x84, machine, 1)
    struct.pack_into('<H', data, 0x94, 224)
    opt = 0x98
    struct.pack_into('<H', data, opt, 0x10b)
    struct.pack_into('<I', data, opt+60, 512)
    struct.pack_into('<I', data, opt+92, 16)
    section = opt+224
    struct.pack_into('<IIII', data, section+8, 1536, 0x1000, 1536, 512)
    stride = 32 if delay else 20
    directory = 13 if delay else 1
    if imports:
        struct.pack_into('<II', data, opt+96+directory*8, 0x1000, (len(imports)+1)*stride)
    for index, name in enumerate(imports):
        entry = 512+index*stride
        if delay: struct.pack_into('<I', data, entry, 1)
        struct.pack_into('<I', data, entry+(4 if delay else 12), 0x1200+index*100)
        raw = name.encode() + b'\0'
        data[1024+index*100:1024+index*100+len(raw)] = raw
    path.write_bytes(data)


class PETests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root/'ruby_builtin_dlls').mkdir()
        self.exe = self.root/'ruby.exe'

    def test_architecture(self):
        fixture(self.exe, machine=0x8664)
        with self.assertRaisesRegex(ValueError, 'i386'): inspect(self.exe)

    def test_missing_dependency(self):
        fixture(self.exe, ['host-only.dll'])
        with self.assertRaisesRegex(ValueError, 'missing non-system'): audit(self.root)

    def test_delay_imports(self):
        fixture(self.exe, ['delayed.dll'], delay=True)
        self.assertEqual(inspect(self.exe), ['delayed.dll'])
        with self.assertRaisesRegex(ValueError, 'delayed.dll'): audit(self.root)

    def test_closure(self):
        with tempfile.TemporaryDirectory() as search:
            fixture(self.exe, ['private.dll', 'KERNEL32.dll'])
            fixture(Path(search)/'private.dll', ['transitive.dll'])
            fixture(Path(search)/'transitive.dll')
            self.assertEqual(len(audit(self.root, [search])), 3)
            self.assertEqual(len(audit(self.root)), 3)

    def test_absolute_import(self):
        fixture(self.exe, ['C:\\build\\private.dll'])
        with self.assertRaisesRegex(ValueError, 'path-containing'): inspect(self.exe)

    def test_embedded_build_path(self):
        fixture(self.exe)
        with self.exe.open('ab') as out: out.write(b'D:/workspace/build')
        with self.assertRaisesRegex(ValueError, 'embedded build path'): audit(self.root, forbidden=['D:/workspace'])

    def test_msys_path_with_native_audit_argument(self):
        fixture(self.exe)
        with self.exe.open('ab') as out: out.write(b'/d/workspace/build')
        with self.assertRaisesRegex(ValueError, 'embedded build path'): audit(self.root, forbidden=['D:/workspace'])


if __name__ == '__main__': unittest.main()
