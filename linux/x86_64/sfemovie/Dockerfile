ARG LITERGSS_IMAGE=litergss-linux-gnu:3.4.10
FROM ${LITERGSS_IMAGE}

ARG FFMPEG_VERSION

# Font/subtitle dependencies are already built from the Linux lock in the base.
COPY config/linux-x86_64-sources.lock /opt/psdk/sources.lock
COPY sources/archives/ffmpeg.tar.xz /opt/psdk/archives/ffmpeg.tar.xz
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN source /opt/psdk/locked-source.sh \
 && test "$(awk '$1 == "ffmpeg" {print $3}' /opt/psdk/sources.lock)" = "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" \
 && extract_source ffmpeg \
 && cd /tmp/psdk-src/ffmpeg \
 && CC=/usr/bin/gcc CXX=/usr/bin/g++ ./configure \
      --prefix=/opt/sfemovie/ffmpeg \
      --extra-cflags=-I/opt/psdk/deps/include \
      --extra-ldflags=-L/opt/psdk/deps/lib \
      --enable-shared \
      --disable-static \
      --disable-programs \
      --disable-doc \
      --disable-network \
      --disable-autodetect \
      --disable-avfilter \
      --disable-postproc \
      --disable-inline-asm \
      --disable-x86asm \
      --enable-zlib \
      --enable-decoder=png \
      --enable-decoder=movtext \
 && make -j"$(nproc)" \
 && make install \
 && rm -rf /tmp/psdk-src/ffmpeg /opt/psdk/archives

COPY linux/x86_64/sfemovie/entrypoint.sh /usr/local/bin/sfemovie-entrypoint.sh
RUN chmod +x /usr/local/bin/sfemovie-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/sfemovie-entrypoint.sh"]
