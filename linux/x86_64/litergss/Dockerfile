FROM quay.io/pypa/manylinux_2_28_x86_64@sha256:4dc41da7df20400310c80d162a2fe2d2c2f3d9734d8dec20f6b9843711618deb

ARG RUBY_VERSION
ARG RUBY_SHA256
ARG RAKE_VERSION
ARG RAKE_COMPILER_VERSION
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
# A lock change also invalidates the distro package update layer.
COPY config/linux-x86_64-sources.lock /opt/psdk/sources.lock
RUN dnf upgrade -y --refresh \
 && dnf install -y --setopt=install_weak_deps=False \
      cmake curl gcc-c++ git make patchelf tar gzip xz patch perl-core pkgconf-pkg-config \
      bzip2-devel gdbm-devel ncurses-devel readline-devel \
      libX11-devel libXcursor-devel libXi-devel libXrandr-devel \
      libjpeg-turbo-devel mesa-libGL-devel systemd-devel alsa-lib-devel fontconfig-devel \
 && dnf clean all \
 && rpm -qa --qf '%{NAME} %{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort > /opt/psdk/distribution-packages.txt

COPY sources/archives/ /opt/psdk/archives/
COPY linux/x86_64/locked-source.sh linux/x86_64/build-dependencies.sh /opt/psdk/
RUN bash /opt/psdk/build-dependencies.sh
ENV PKG_CONFIG_PATH=/opt/psdk/deps/lib/pkgconfig:/opt/psdk/deps/share/pkgconfig
ENV CMAKE_PREFIX_PATH=/opt/psdk/deps

RUN source /opt/psdk/locked-source.sh \
 && test "$(awk '$1 == "ruby" {print $2}' /opt/psdk/sources.lock)" = "$RUBY_SHA256" \
 && test "$(awk '$1 == "ruby" {print $3}' /opt/psdk/sources.lock)" = "https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.gz" \
 && extract_source ruby \
 && cd /tmp/psdk-src/ruby \
 && CPPFLAGS=-I/opt/psdk/deps/include LDFLAGS='-L/opt/psdk/deps/lib -Wl,-rpath,/opt/psdk/deps/lib' \
      ./configure --prefix=/opt/litergss/ruby --disable-install-doc --enable-shared \
      --with-openssl-dir=/opt/psdk/deps --with-libyaml-dir=/opt/psdk/deps \
      --with-libffi-dir=/opt/psdk/deps --with-zlib-dir=/opt/psdk/deps \
 && make -j"$(nproc)" && make install \
 && rm -rf /tmp/psdk-src/ruby

# The image uses AlmaLinux's CA bundle; the shipped setup selects the host bundle.
RUN SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt \
      /opt/litergss/ruby/bin/gem install --no-document --minimal-deps rake --version "$RAKE_VERSION" \
 && SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt \
      /opt/litergss/ruby/bin/gem install --no-document --ignore-dependencies rake-compiler --version "$RAKE_COMPILER_VERSION" \
 && /opt/litergss/ruby/bin/ruby -e 'gem "rake", ENV.fetch("RAKE_VERSION"); gem "rake-compiler", ENV.fetch("RAKE_COMPILER_VERSION"); require "rake/extensiontask"'

RUN source /opt/psdk/locked-source.sh \
 && extract_source sfml \
 && cmake -S /tmp/psdk-src/sfml -B /tmp/sfml-build \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/litergss/sfml \
      -DCMAKE_INSTALL_LIBDIR=lib64 -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -DBUILD_SHARED_LIBS=ON -DSFML_BUILD_AUDIO=ON -DSFML_BUILD_NETWORK=OFF \
      -DSFML_BUILD_DOC=OFF -DSFML_BUILD_EXAMPLES=OFF -DSFML_BUILD_TEST_SUITE=OFF \
      -DFREETYPE_LIBRARY=/opt/psdk/deps/lib/libfreetype.so \
      -DFREETYPE_INCLUDE_DIR_freetype2=/opt/psdk/deps/include/freetype2 \
      -DFREETYPE_INCLUDE_DIR_ft2build=/opt/psdk/deps/include/freetype2 \
      -DOPENAL_LIBRARY=/opt/psdk/deps/lib/libopenal.so -DOPENAL_INCLUDE_DIR=/opt/psdk/deps/include/AL \
      -DOGG_LIBRARY=/opt/psdk/deps/lib/libogg.so -DOGG_INCLUDE_DIR=/opt/psdk/deps/include \
      -DVORBIS_LIBRARY=/opt/psdk/deps/lib/libvorbis.so -DVORBIS_INCLUDE_DIR=/opt/psdk/deps/include \
      -DVORBISFILE_LIBRARY=/opt/psdk/deps/lib/libvorbisfile.so \
      -DVORBISENC_LIBRARY=/opt/psdk/deps/lib/libvorbisenc.so \
      -DFLAC_LIBRARY=/opt/psdk/deps/lib/libFLAC.so -DFLAC_INCLUDE_DIR=/opt/psdk/deps/include \
 && cmake --build /tmp/sfml-build --parallel "$(nproc)" \
 && cmake --install /tmp/sfml-build \
 && ln -s lib64 /opt/litergss/sfml/lib \
 && rm -rf /tmp/psdk-src/sfml /tmp/sfml-build

COPY sources/sfmlaudio/ /tmp/sfmlaudio/
RUN cd /tmp/sfmlaudio/ext/SFMLAudio \
 && sed -i '/^create_makefile/i $libs = append_library($libs, "sfml-audio")' extconf.rb \
 && SFML_DIR=/opt/litergss/sfml /opt/litergss/ruby/bin/ruby extconf.rb \
 && make -j"$(nproc)" \
 && readelf -d SFMLAudio.so | grep -F 'Shared library: [libsfml-audio.so.2.6]' \
 && install -D -m 0755 SFMLAudio.so /opt/litergss/sfmlaudio/SFMLAudio.so \
 && rm -rf /tmp/sfmlaudio /opt/psdk/archives

# Reuse the pinned component's staging logic, with Linux dependency relocation.
COPY sources/litergss/docker/linux-gnu/entrypoint.sh /usr/local/bin/upstream-entrypoint.sh
COPY sources/litergss/docker/linux-gnu/setup.sh /usr/local/bin/setup.sh
COPY linux/x86_64/litergss/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY linux/x86_64/litergss/setup-ca.sh /tmp/setup-ca.sh
RUN cat /tmp/setup-ca.sh >> /usr/local/bin/setup.sh \
 && chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/upstream-entrypoint.sh /usr/local/bin/setup.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
