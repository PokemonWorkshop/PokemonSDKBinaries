# Shared runtime functional tests

`runtime-functional.rb` is packaged at `lib/psdk-runtime/` on all three
platforms, alongside `sfemovie-texture.rb`. Each release verifier runs this
same suite from its relocated payload, using only the bundled Ruby/runtime.

The suite checks:

* Ruby version, platform and pointer size; loaded Ruby files remain in the payload.
* Standard-library and bundled-gem loading, CSV/XML parsing, YAML, zlib and OpenSSL.
* All four native bindings and the LiteCGSS fixed shader-pipeline constant.
* FMOD initialization, version and PCM decoding; SFMLAudio PCM decoding.
* sfeMovie PCM loading, duration and playback updates, exercising resampler setup.
* Availability of PNG, mov_text, H.264, Vorbis and AAC decoders.
* Actual video pixels, texture subclasses, disposed/uninitialized textures and snapshots.

Fixtures are generated locally without downloads or an encoder. FMOD uses
NOSOUND and OpenAL uses its null backend. Graphics are mandatory: Linux starts
Xvfb with Mesa software rendering; Windows and macOS need working OpenGL.
Missing graphics support fails verification rather than skipping coverage.

Platform wrappers retain their binary audits and setup checks. Windows also
runs the suite through both ruby.exe and rubyw.exe, with RubyGems enabled and
with PSDK's gems-disabled flags. These extra launcher checks are intentional.

The Linux CI run reproduced the resampler failure when opening the generated
PCM fixture. The pinned native sfeMovie revision includes the upstream
channel-layout correction, so builders no longer apply a local patch.
The fixture remains a regression test for this failure.
