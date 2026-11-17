#!/usr/bin/env python3
"""Check that shared runtime dependencies use matching pins across platforms.

Linux's source lock is the reference for portable library versions. macOS keeps
its system OpenAL, zlib and libffi; Windows obtains some matching libraries from
locked MSYS2 packages. The toolchain's own OpenSSL package is not the runtime
OpenSSL: Windows builds the latter from the shared source pin.
"""
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
TARGETS = ("linux-x86_64", "macos-arm64", "windows-x86")
SYSTEM_MACOS = {"openal", "zlib", "libffi"}
WINDOWS_PACKAGES = {
    "yaml": "libyaml", "zlib": "zlib", "libffi": "libffi",
    "ogg": "libogg", "vorbis": "libvorbis", "flac": "flac",
    "freetype": "freetype", "harfbuzz": "harfbuzz",
}


def sources(target):
    result = {}
    path = ROOT / "config" / f"{target}-sources.lock"
    for line in path.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        name, checksum, url = line.split()
        if name in result or not re.fullmatch(r"[0-9a-f]{64}", checksum):
            raise ValueError(f"{path.name}: invalid or duplicate pin for {name}")
        result[name] = (checksum, url)
    return result


def configuration(target):
    path = ROOT / "config" / f"{target}.conf"
    return dict(line.split("=", 1) for line in path.read_text().splitlines()
                if line and not line.startswith("#"))


def version(url):
    match = re.search(r"\d+\.\d+(?:\.\d+)*", url.rsplit("/", 1)[-1])
    if not match:
        raise ValueError(f"Cannot identify archive version: {url}")
    return match.group()


def main():
    reference = sources(TARGETS[0])
    configs = [configuration(target) for target in TARGETS]
    for target in TARGETS[1:]:
        actual = sources(target)
        exceptions = SYSTEM_MACOS if target == "macos-arm64" else set(WINDOWS_PACKAGES)
        expected = set(reference) - exceptions
        if set(actual) != expected:
            raise ValueError(f"{target}: source coverage differs: {set(actual) ^ expected}")
        for name, pin in actual.items():
            if pin != reference[name]:
                raise ValueError(f"{target}: {name} URL/SHA-256 differs from Linux")

    package_lock = ROOT / "config/windows-x86-packages.lock"
    urls = [line.split()[1] for line in package_lock.read_text().splitlines()
            if line.strip() and not line.startswith("#")]
    for source, package in WINDOWS_PACKAGES.items():
        prefix = f"mingw-w64-i686-{package}-"
        matches = [url for url in urls if url.rsplit("/", 1)[-1].startswith(prefix)]
        expected = version(reference[source][1])
        if len(matches) != 1 or version(matches[0]) != expected:
            raise ValueError(f"Windows package {package} must match source version {expected}")

    keys = [key for key in configs[0] if key.endswith(("_REPOSITORY", "_REF"))]
    keys += ["RUBY_VERSION", "RUBY_SHA256", "FMOD_VERSION_HEX",
             "FMOD_DOWNLOAD_VERSION", "FFMPEG_VERSION", "OPENSSL_VERSION"]
    for key in keys:
        if len({config[key] for config in configs}) != 1:
            raise ValueError(f"Platform configurations disagree on {key}")
    for config in configs:
        if config["RUBY_VERSION"] != version(reference["ruby"][1]):
            raise ValueError("Ruby configuration does not match its source lock")
        if config["RUBY_SHA256"] != reference["ruby"][0]:
            raise ValueError("Ruby configuration checksum does not match its source lock")
        if config["FFMPEG_VERSION"] != version(reference["ffmpeg"][1]):
            raise ValueError("FFmpeg configuration does not match its source lock")
        if config["OPENSSL_VERSION"] != version(reference["openssl"][1]):
            raise ValueError("OpenSSL configuration does not match its source lock")
    print("Shared runtime dependency pins match across Linux, macOS and Windows.")


if __name__ == "__main__":
    main()
