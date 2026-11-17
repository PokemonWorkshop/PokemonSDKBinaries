# Portable Linux sfeMovie build

This build produces the native `libsfeMovie` library and its required FFmpeg
6.1.6 shared-library closure for `x86_64-linux-gnu` with a glibc 2.28 baseline.
It deliberately does not build or package a Ruby extension. It reuses the
already-built LiteRGSS image and its SFML 2.6.2 installation, avoiding a
second SFML build and ensuring both components use the same SFML ABI.

The FFmpeg source archive is SHA-256 pinned in `config/linux-x86_64-sources.lock`.
The shared source fetcher downloads it before the Docker build. Its
configuration builds shared libraries without external autodetected
dependencies or network support; this keeps the runtime closure predictable.

Fetch sources and build LiteRGSS with `linux/x86_64/litergss/build.sh` first,
then run from this repository (the Linux workflow performs these steps):

```sh
SOURCE_DIR=/path/to/sfeMovie \
linux/x86_64/sfemovie/build.sh
```

The builder reads `RUBY_VERSION` and `FFMPEG_VERSION` from
`config/linux-x86_64.conf`, overriding environment values for those settings.
Use the same configuration for the preceding LiteRGSS build.

Set `OUTPUT_DIR` to choose an empty output directory. The result contains the
native sfeMovie library, the FFmpeg libraries it uses, SFML, and any required
non-glibc runtime dependencies. Host-provided graphics drivers, ALSA, and the
C++ runtime are intentionally not bundled.
