"""Exercise source download fallback and checksum enforcement without a network."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
URL = "https://cache.ruby-lang.org/pub/ruby/3.4/ruby-3.4.10.tar.gz"
FALLBACK = URL.replace("cache.ruby-lang.org", "ftp.ruby-lang.org")
FFMPEG_URL = "https://ffmpeg.org/releases/ffmpeg-6.1.6.tar.xz"
FFMPEG_FALLBACK = "https://distfiles.macports.org/ffmpeg/ffmpeg-6.1.6.tar.xz"
PAYLOAD = b"pinned source archive\n"


class SourceDownloadTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.archive = self.directory / "ruby.tar.gz"
        self.log = self.directory / "requests.log"
        shim = self.directory / "curl"
        shim.write_text("""#!/usr/bin/env bash
set -eu
url='' output='' retry_all='' retry_limit=''
while (( $# )); do
  case "$1" in
    https://*) url="$1" ;;
    -o) shift; output="$1" ;;
    --retry-all-errors) retry_all=yes ;;
    --retry-max-time) shift; retry_limit="$1" ;;
  esac
  shift
done
[[ "$retry_all" == yes && "$retry_limit" == 120 ]] || exit 99
printf '%s\\n' "$url" >> "$TEST_REQUEST_LOG"
if [[ "$TEST_MODE" == all_down ]] || {
  [[ "$TEST_MODE" == primary_down || "$TEST_MODE" == fallback_corrupt ]] &&
  [[ "$url" == https://cache.ruby-lang.org/* || "$url" == https://ffmpeg.org/* ]]
}; then
  printf 'partial download' > "$output"
  exit "$TEST_FAILURE_CODE"
fi
if [[ "$TEST_MODE" == corrupt || "$TEST_MODE" == fallback_corrupt ]]; then
  printf 'wrong contents' > "$output"
else
  printf 'pinned source archive\\n' > "$output"
fi
""")
        shim.chmod(0o755)

    def fetch(self, mode="success", url=URL, failure_code=6):
        environment = dict(os.environ, TEST_MODE=mode, TEST_REQUEST_LOG=str(self.log),
                           TEST_FAILURE_CODE=str(failure_code))
        environment["PATH"] = str(self.directory) + os.pathsep + environment["PATH"]
        return subprocess.run(
            ["bash", "-c", 'source "$1"; fetch_source_archive "$2" "$3" "$4"',
             "test", str(ROOT / ".github/scripts/fetch-source-archive.sh"),
             hashlib.sha256(PAYLOAD).hexdigest(), url, str(self.archive)],
            env=environment, capture_output=True, text=True,
        )

    def requests(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def assert_clean(self):
        self.assertFalse(self.archive.with_name(self.archive.name + ".tmp").exists())

    def test_primary_success(self):
        result = self.fetch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.archive.read_bytes(), PAYLOAD)
        self.assertEqual(self.requests(), [URL])
        self.assert_clean()

    def test_dns_failure_uses_checksum_verified_fallback(self):
        result = self.fetch("primary_down")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.requests(), [URL, FALLBACK])
        self.assertEqual(self.archive.read_bytes(), PAYLOAD)
        self.assert_clean()

    def test_wrong_checksum_is_not_cached_or_retried(self):
        result = self.fetch("corrupt")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Checksum mismatch", result.stderr)
        self.assertEqual(self.requests(), [URL])
        self.assertFalse(self.archive.exists())
        self.assert_clean()

    def test_ffmpeg_timeout_uses_checksum_verified_mirror(self):
        result = self.fetch("primary_down", FFMPEG_URL, failure_code=28)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.requests(), [FFMPEG_URL, FFMPEG_FALLBACK])
        self.assertEqual(self.archive.read_bytes(), PAYLOAD)
        self.assert_clean()

    def test_ffmpeg_tls_reset_uses_checksum_verified_mirror(self):
        result = self.fetch("primary_down", FFMPEG_URL, failure_code=35)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.requests(), [FFMPEG_URL, FFMPEG_FALLBACK])
        self.assertEqual(self.archive.read_bytes(), PAYLOAD)
        self.assert_clean()

    def test_ffmpeg_mirror_with_wrong_checksum_is_rejected(self):
        result = self.fetch("fallback_corrupt", FFMPEG_URL)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Checksum mismatch", result.stderr)
        self.assertEqual(self.requests(), [FFMPEG_URL, FFMPEG_FALLBACK])
        self.assertFalse(self.archive.exists())
        self.assert_clean()

    def test_all_ffmpeg_hosts_fail_without_caching_partial_download(self):
        result = self.fetch("all_down", FFMPEG_URL)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.requests(), [FFMPEG_URL, FFMPEG_FALLBACK])
        self.assertFalse(self.archive.exists())
        self.assert_clean()

    def test_all_hosts_fail_without_caching_partial_download(self):
        result = self.fetch("all_down")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.requests(), [URL, FALLBACK])
        self.assertFalse(self.archive.exists())
        self.assert_clean()

    def test_valid_cached_archive_does_not_download(self):
        self.archive.write_bytes(PAYLOAD)
        result = self.fetch("all_down")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.requests(), [])

    def test_invalid_cached_archive_fails_without_overwriting(self):
        self.archive.write_bytes(b"corrupt cache")
        result = self.fetch()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.requests(), [])
        self.assertEqual(self.archive.read_bytes(), b"corrupt cache")

    def test_non_ruby_download_does_not_use_ruby_fallback(self):
        url = "https://example.com/dependency.tar.gz"
        result = self.fetch("all_down", url)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.requests(), [url])
        self.assertFalse(self.archive.exists())
        self.assert_clean()


if __name__ == "__main__":
    unittest.main()
