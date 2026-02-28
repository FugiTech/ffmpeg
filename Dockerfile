FROM debian:bookworm-slim AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  # Base packages
  ca-certificates pkg-config openssl \
  # Building FFMPEG
  build-essential zlib1g-dev cmake clang nasm curl git gnupg \
  # Keep the image as slim as possible
  && rm -rf /var/lib/apt/lists/*
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /app
COPY keys keys
RUN gpg --dearmor -o keys/ffmpeg.gpg keys/ffmpeg.asc
RUN gpg --dearmor -o keys/libaom.gpg keys/libaom.asc

FROM base AS aom
WORKDIR /app
RUN mkdir aom
RUN curl -fL -o aom.tgz https://storage.googleapis.com/aom-releases/libaom-3.13.1.tar.gz
RUN curl -fL -o aom.tgz.asc https://storage.googleapis.com/aom-releases/libaom-3.13.1.tar.gz.asc
RUN gpgv --keyring ./keys/libaom.gpg aom.tgz.asc aom.tgz
RUN tar -xzf aom.tgz
RUN rm -rf libaom-3.13.1/CMakeCache.txt libaom-3.13.1/CMakeFiles
RUN cmake -S libaom-3.13.1 -B aom -DCMAKE_INSTALL_PREFIX=/app/ffmpeg
RUN make -C aom -j $(nproc)

FROM base AS svt
WORKDIR /app
RUN curl -fL -o svt.tgz https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v4.0.1/SVT-AV1-v4.0.1.tar.gz
# SVT-AV1 doesn't provide a GPG signature. Instead, we verify the download using a SHA256 checksum.
# From: https://github.com/msys2/MINGW-packages/blob/master/mingw-w64-svt-av1/PKGBUILD
RUN echo "9c0f9a4327334c40a76d2f39940d8a1b2dd8b1358375a11c4715d516b90a65cb  svt.tgz" | sha256sum -c -
RUN tar -xzf svt.tgz
RUN mv SVT-AV1-v4.0.1/Build svt
RUN cmake -S SVT-AV1-v4.0.1 -B svt -DCMAKE_INSTALL_PREFIX=/app/ffmpeg -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release
RUN make -C svt -j $(nproc)

FROM base AS ffmpeg
ENV LD_LIBRARY_PATH=/app/ffmpeg/lib PKG_CONFIG_PATH=/app/ffmpeg/lib/pkgconfig
WORKDIR /app
COPY --from=aom /app/aom aom
COPY --from=aom /app/libaom-3.13.1 libaom-3.13.1
COPY --from=svt /app/svt svt
COPY --from=svt /app/SVT-AV1-v4.0.1 SVT-AV1-v4.0.1
RUN mkdir ffmpeg
RUN make -C aom install
RUN make -C svt install
RUN curl -fL -o ffmpeg.tar.xz https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz
RUN curl -fL -o ffmpeg.tar.xz.asc https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz.asc
RUN gpgv --keyring ./keys/ffmpeg.gpg ffmpeg.tar.xz.asc ffmpeg.tar.xz
RUN tar -xf ffmpeg.tar.xz
WORKDIR /app/ffmpeg-8.0.1
COPY ffmpeg-patch.diff patch.diff
RUN git apply patch.diff
RUN ./configure --prefix=/app/ffmpeg --enable-libaom --enable-libsvtav1
RUN make -j $(nproc)
RUN make install

FROM debian:bookworm-slim AS runtime
LABEL org.opencontainers.image.source="https://github.com/FugiTech/ffmpeg"
COPY --from=ffmpeg /app/ffmpeg /app/ffmpeg
ENV LD_LIBRARY_PATH=/app/ffmpeg/lib
ENV PATH=/app/ffmpeg/bin:$PATH
ENTRYPOINT ["ffmpeg"]
