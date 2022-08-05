ARG UBUNTU_VER=22.04

FROM ghcr.io/by275/base:ubuntu AS prebuilt
FROM ghcr.io/by275/base:ubuntu${UBUNTU_VER} AS base

ENV \
    OPENSSL_VER=3.0.5 \
    UNBOUND_VER=1.16.2 \
    GETDNS_VER=1.7.0

ENV \
    OPENSSL_TAG=openssl-${OPENSSL_VER} \
    UNBOUND_TAG=release-${UNBOUND_VER} \
    GETDNS_TAG=v${GETDNS_VER}

# 
# BUILD
# 
FROM base AS builder

ARG DEBIAN_FRONTEND=noninteractive

RUN \
    echo "**** install build-deps ****" && \
    apt-get update -qq && \
    apt-get install -yqq --no-install-recommends \
        bison \
        build-essential \
        ca-certificates \
        curl \
        git


FROM builder AS openssl

ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /tmp/openssl

RUN \
    echo "**** clone source ****" && \
    git clone https://github.com/openssl/openssl.git . -b ${OPENSSL_TAG} --depth=1
RUN \
    echo "**** build openssl v${OPENSSL_VER} ****" && \
    ./config \
        -DOPENSSL_NO_HEARTBEATS \
        -fstack-protector-strong \
        enable-ec_nistp_64_gcc_128 \
        no-shared \
        no-ssl3 \
        no-weak-ssl-ciphers \
    && \
    make depend && make
RUN \
    echo "**** install openssl v${OPENSSL_VER} ****" && \
    make DESTDIR=/openssl install_sw


FROM builder AS unbound

ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /tmp/unbound

RUN \
    echo "**** clone source ****" && \
    git clone https://github.com/NLnetLabs/unbound . -b ${UNBOUND_TAG} --depth=1
RUN \
    echo "**** install build-deps ****" && \
    apt-get install -yqq --no-install-recommends \
        libevent-dev \
        libexpat-dev \
        libnghttp2-dev \
        libprotobuf-c-dev \
        protobuf-c-compiler
COPY --from=openssl /openssl /
RUN \
    echo "**** build unbound v${UNBOUND_VER} ****" && \
    ./configure \
        --enable-dnstap \
        --enable-event-api \
        --enable-subnet \
        --enable-tfo-client \
        --enable-tfo-server \
        --with-libevent \
        --with-libnghttp2 \
        --with-pthreads \
    && \
    make
RUN \
    echo "**** install unbound v${UNBOUND_VER} ****" && \
    make DESTDIR=/unbound install
RUN \
    echo "**** cleanup unbound ****" && \
    rm -rf \
        /unbound/usr/local/include \
        /unbound/usr/local/share


FROM builder AS stubby

ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /tmp/stubby

RUN \
    echo "**** clone source ****" && \
    git clone https://github.com/getdnsapi/getdns . -b ${GETDNS_TAG} --depth=1 && \
    git submodule update --init
RUN \
    echo "**** install build-deps ****" && \
    apt-get install -yqq --no-install-recommends \
        check \
        cmake \
        libssl-dev \
        libyaml-dev
RUN \
    echo "**** build stubby ****" && \
    cmake \
        -DBUILD_GETDNS_QUERY=OFF \
        -DBUILD_GETDNS_SERVER_MON=OFF \
        -DBUILD_LIBEV=OFF \
        -DBUILD_LIBEVENT2=OFF \
        -DBUILD_LIBUV=OFF \
        -DBUILD_STUBBY=ON \
        -DENABLE_STUB_ONLY=ON \
        -DENABLE_SYSTEMD=OFF \
        -DUSE_LIBIDN2=OFF \
        . \
    && \
    make
RUN \
    echo "**** install stubby ****" && \
    make DESTDIR=/stubby install
RUN \
    echo "**** cleanup stubby ****" && \
    rm -rf \
        /stubby/usr/local/include \
        /stubby/usr/local/share \
        /stubby/usr/local/var


FROM builder AS adguardhome

RUN \
    echo "**** install adguardhome ****" && \
    curl -sSL https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

# 
# COLLECT
# 
FROM builder AS collector

# add s6 overlay
COPY --from=prebuilt /s6/ /bar/
ADD https://raw.githubusercontent.com/by275/docker-base/main/_/etc/cont-init.d/adduser /bar/etc/cont-init.d/10-adduser

# add unbound
COPY --from=unbound /unbound/ /bar/

# add stubby
COPY --from=stubby /stubby/ /bar/

# add adguardhome
COPY --from=adguardhome /opt/AdGuardHome/AdGuardHome /bar/usr/local/bin/

# add local files
COPY root/ /bar/

RUN \
    echo "**** directories ****" && \
    mkdir -p \
        /bar/defaults \
        /bar/config \
        && \
    echo "**** permissions ****" && \
    chmod a+x \
        /bar/usr/local/bin/* \
        /bar/etc/cont-init.d/* \
        /bar/etc/s6-overlay/s6-rc.d/*/run \
        /bar/etc/s6-overlay/s6-rc.d/*/data/*

RUN \
    echo "**** s6: resolve dependencies ****" && \
    for dir in /bar/etc/s6-overlay/s6-rc.d/*; do mkdir -p "$dir/dependencies.d"; done && \
    for dir in /bar/etc/s6-overlay/s6-rc.d/*; do touch "$dir/dependencies.d/legacy-cont-init"; done && \
    echo "**** s6: create a new bundled service ****" && \
    mkdir -p /tmp/app/contents.d && \
    for dir in /bar/etc/s6-overlay/s6-rc.d/*; do touch "/tmp/app/contents.d/$(basename "$dir")"; done && \
    echo "bundle" > /tmp/app/type && \
    mv /tmp/app /bar/etc/s6-overlay/s6-rc.d/app && \
    echo "**** s6: deploy services ****" && \
    rm /bar/package/admin/s6-overlay/etc/s6-rc/sources/top/contents.d/legacy-services && \
    touch /bar/package/admin/s6-overlay/etc/s6-rc/sources/top/contents.d/app

# 
# RELEASE
# 
FROM base
LABEL maintainer="by275"
LABEL org.opencontainers.image.source https://github.com/by275/docker-adguardhome

ARG DEBIAN_FRONTEND=noninteractive

RUN \
    echo "**** install runtime-pkgs ****" && \
    apt-get update -qq && \
    apt-get install -yqq --no-install-recommends \
        ca-certificates \
        ldnsutils \
        `# unbound` \
        libevent-2.1-7 \
        libexpat1 \
        libnghttp2-14 \
        libprotobuf-c1 \
        `# stubby` \
        libyaml-0-2 \
    && \
    echo "**** useradd unbound ****" && \
    groupadd unbound && \
    useradd -g unbound -s /usr/sbin/nologin -d /dev/null unbound && \
    echo "**** cleanup ****" && \
    rm -rf \
        /tmp/* \
        /var/tmp/* \
        /var/cache/* \
        /var/lib/apt/lists/*

COPY --from=collector /bar/ /

# environment settings
ENV \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    TZ=Asia/Seoul

EXPOSE 53/tcp
EXPOSE 53/udp

VOLUME /config

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 \
    CMD drill @127.0.0.1 cloudflare.com || exit 1

ENTRYPOINT ["/init"]
