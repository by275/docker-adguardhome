FROM ubuntu:22.04 AS base

# amd64 / arm64 / armhf
ARG ARCH=amd64

ENV \
    ARCH=${ARCH} \
    OPENSSL_TAG=openssl-3.0.6 \
    UNBOUND_TAG=release-1.17.0 \
    DEBIAN_FRONTEND=noninteractive

# 
# BUILD
# 
FROM base AS builder

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN \
    echo "**** setup cross-compile source ****" && \
    CODENAME=$(. /etc/os-release && echo $VERSION_CODENAME) && \
    sed -i 's/^deb http/deb [arch=amd64] http/' /etc/apt/sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME} main restricted" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME}-updates main restricted" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME} universe" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME}-updates universe" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME} multiverse" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME}-updates multiverse" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME}-backports main restricted universe multiverse" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    dpkg --add-architecture armhf && \
    dpkg --add-architecture arm64

RUN \
    echo "**** install build-deps ****" && \
    apt-get update -qq && \
    apt-get upgrade -qq && \
    apt-get install -yqq --no-install-recommends \
        ca-certificates \
        curl \
        git

RUN \
    echo "**** install cross-build-deps ****" && \
    apt-get install -yqq --no-install-recommends crossbuild-essential-$ARCH


FROM builder AS openssl

WORKDIR /tmp/openssl
RUN \
    echo "**** clone source ****" && \
    git clone https://github.com/openssl/openssl.git . -b ${OPENSSL_TAG} --depth=1
RUN \
    echo "**** build openssl ****" && \
    if [ $ARCH = "amd64" ]; then TARCH="x86_64"; \
    elif [ $ARCH = "arm64" ]; then TARCH="aarch64"; \
    else exit 1; fi && \
    ECFLAG="$(if ${TARCH}-linux-gnu-gcc -dM -E - </dev/null | grep -q __SIZEOF_INT128__; then echo "enable-ec_nistp_64_gcc_128"; fi)" && \
    ./Configure linux-$TARCH \
        --cross-compile-prefix=${TARCH}-linux-gnu- \
        $ECFLAG \
        -DOPENSSL_NO_HEARTBEATS \
        -fstack-protector-strong \
        no-shared \
        no-ssl3 \
        no-weak-ssl-ciphers \
    && \
    make -j$(nproc)
RUN \
    echo "**** install openssl ****" && \
    make DESTDIR=/openssl install_sw


FROM builder AS unbound

WORKDIR /tmp/unbound
RUN \
    echo "**** clone source ****" && \
    git clone https://github.com/NLnetLabs/unbound . -b ${UNBOUND_TAG} --depth=1
RUN \
    echo "**** install build-deps ****" && \
    apt-get install -yqq --no-install-recommends \
        bison \
        flex \
        libevent-dev:${ARCH} \
        libexpat-dev:${ARCH} \
        libnghttp2-dev:${ARCH}
COPY --from=openssl /openssl/ /
RUN \
    echo "**** build unbound ****" && \
    if [ $ARCH = "amd64" ]; then TARCH="x86_64"; \
    elif [ $ARCH = "arm64" ]; then TARCH="aarch64"; \
    else exit 1; fi && \
    ./configure \
        --build=x86_64-linux-gnu \
        --host=${TARCH}-linux-gnu \
        --disable-debug \
        --enable-event-api \
        --enable-subnet \
        --enable-tfo-client \
        --enable-tfo-server \
        --with-libevent \
        --with-libnghttp2 \
        --with-pthreads \
    && \
    make -j$(nproc)
RUN \
    echo "**** install unbound ****" && \
    make DESTDIR=/unbound install
RUN \
    echo "**** cleanup unbound ****" && \
    mv /unbound/usr/local/etc/unbound/unbound.conf \
        /unbound/usr/local/etc/unbound/unbound.conf.example && \
    rm -rf \
        /unbound/usr/local/include \
        /unbound/usr/local/share


FROM scratch

COPY --from=unbound /unbound/ /
