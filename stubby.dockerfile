FROM ubuntu:22.04 AS base

# amd64 / arm64 / armhf
ARG ARCH=amd64

ENV \
    ARCH=${ARCH} \
    GETDNS_TAG=v1.7.1-rc.1 \
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


FROM builder AS stubby

WORKDIR /tmp/stubby
RUN \
    echo "**** clone source ****" && \
    git clone --recurse-submodules https://github.com/getdnsapi/getdns . -b ${GETDNS_TAG} --depth=1
RUN \
    echo "**** install build-deps ****" && \
    apt-get install -yqq --no-install-recommends \
        cmake \
        libssl-dev:${ARCH} \
        libyaml-dev:${ARCH}
RUN \
    echo "**** build stubby ****" && \
    if [ $ARCH = "amd64" ]; then TARCH="x86_64"; \
    elif [ $ARCH = "arm64" ]; then TARCH="aarch64"; \
    else exit 1; fi && \
    cmake . \
        -DBUILD_GETDNS_QUERY=OFF \
        -DBUILD_GETDNS_SERVER_MON=OFF \
        -DBUILD_LIBEV=OFF \
        -DBUILD_LIBEVENT2=OFF \
        -DBUILD_LIBUV=OFF \
        -DBUILD_STUBBY=ON \
        -DBUILD_TESTING=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=${TARCH}-linux-gnu-gcc \
        -DCMAKE_PREFIX_PATH=/usr/bin/${TARCH}-linux-gnu- \
        -DENABLE_STUB_ONLY=ON \
        -DENABLE_SYSTEMD=OFF \
        -DUSE_LIBIDN2=OFF \
    && \
    make -j$(nproc)
RUN \
    echo "**** install stubby ****" && \
    make DESTDIR=/stubby install
RUN \
    echo "**** cleanup stubby ****" && \
    mv /stubby/usr/local/etc/stubby/stubby.yml /stubby/usr/local/etc/stubby/stubby.yml.example && \
    rm -rf \
        /stubby/usr/local/include \
        /stubby/usr/local/share \
        /stubby/usr/local/var


FROM scratch

COPY --from=stubby /stubby/ /
