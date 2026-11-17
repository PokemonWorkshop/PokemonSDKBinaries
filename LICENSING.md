# Licensing and redistribution

The build and release tooling in this repository is available under the
[MIT License](LICENSE). Bundled third-party libraries retain their own licences;
consult the notices included in each runtime package before redistribution.

## FMOD runtime and licensing

The releases contain only the platform's FMOD runtime library (`libfmod.so`, `libfmod.dylib` or `fmod.dll`). They do **not** publish FMOD SDK headers, static libraries, import libraries, or other development files.

That separation alone does not automatically grant redistribution rights. FMOD is proprietary software, and the [FMOD EULA](https://www.fmod.com/legal) requires the FMOD Engine to be integrated and redistributed in a qualifying software application/product, subject to the licence tier and its conditions. In particular, the EULA's listed licence grants restrict distribution as part of a game engine or tool set. Maintainers and downstream projects must confirm that their intended distribution is covered by the applicable FMOD licence before publishing or redistributing a package.
