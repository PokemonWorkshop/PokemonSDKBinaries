# Portable Linux RubyFMOD build

This builder compiles `RubyFmod.so` for the Ruby version in the already-built
LiteRGSS Linux image (3.4.10 by default) and stages the FMOD Core 2.02 x86_64
runtime. It deliberately reuses that image rather than compiling Ruby again,
which guarantees it builds against the exact Ruby ABI shipped in the release.
It is intentionally offline with respect to FMOD: pass an extracted SDK you
are authorized to use and redistribute.

The supplied SDK must contain:

```text
inc/fmod.h
inc/fmod_errors.h
inc/fmod_common.h       # FMOD_VERSION must be 0x00020220
lib/x86_64/libfmod.so.13.20
```

Build LiteRGSS first, then run from this repository:

```sh
SOURCE_DIR=/path/to/Ruby-Fmod \
FMOD_SDK_DIR=/path/to/fmod-core \
RUBY_VERSION=3.4.10 \
linux/x86_64/rubyfmod/build.sh
```

Set `OUTPUT_DIR` to choose an empty destination. The result contains
`RubyFmod.so`, `libfmod.so.13.20`, its SONAME symlink, and `libgcc_s.so.1`.
It intentionally does not duplicate `libruby.so.3.4`: the final release gets
that shared library from LiteRGSS's embedded Ruby payload. The C++ runtime and
the host audio stack remain host-provided.

For another embedded Ruby version, update `config/linux-x86_64.conf` and the
matching source lock, then rebuild LiteRGSS and pass the same version as
`RUBY_VERSION` here. The LiteRGSS builder reads the configuration directly;
setting its environment alone does not change its Ruby version. Coordinate
the remaining platform and test changes described in
[CONTRIBUTING.md](../../../CONTRIBUTING.md).
