import tempfile
import unittest
from pathlib import Path
from layout import manifest, verify


class LayoutTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ('ruby.exe', 'rubyw.exe', 'msvcrt-ruby340.dll'):
            (self.root / name).touch()
        (self.root / 'lib/ruby/3.4.0').mkdir(parents=True)
        (self.root / 'lib/ruby/gems/3.4.0').mkdir(parents=True)
        for name in ('cert.pem', '__gem.rb', 'LiteRGSS.so', 'RubyFmod.so', 'SFEMovie.so', 'SFMLAudio.so'):
            (self.root / 'lib' / name).touch()
        (self.root / 'ruby_builtin_dlls').mkdir()
        (self.root / 'ruby_builtin_dlls/current.dll').touch()
        manifest(self.root, write=True)

    def test_legacy_layout(self):
        verify(self.root)

    def test_unlisted_dll(self):
        (self.root / 'ruby_builtin_dlls/additional.dll').touch()
        with self.assertRaisesRegex(ValueError, 'exactly match'):
            verify(self.root)

    def test_missing_dll(self):
        (self.root / 'ruby_builtin_dlls/other.dll').touch()
        (self.root / 'ruby_builtin_dlls/current.dll').unlink()
        with self.assertRaisesRegex(ValueError, 'exactly match'):
            verify(self.root)

    def test_old_bin_layout_rejected(self):
        (self.root / 'bin').mkdir()
        with self.assertRaisesRegex(ValueError, 'exactly lib/'):
            verify(self.root)

    def test_missing_certificate(self):
        (self.root / 'lib/cert.pem').unlink()
        with self.assertRaisesRegex(ValueError, 'cert.pem'):
            verify(self.root)

    def test_missing_launchers_or_runtime(self):
        for name in ('ruby.exe', 'rubyw.exe', 'msvcrt-ruby340.dll'):
            with self.subTest(name=name):
                (self.root / name).unlink()
                with self.assertRaises(ValueError):
                    verify(self.root)
                (self.root / name).touch()


if __name__ == '__main__':
    unittest.main()
