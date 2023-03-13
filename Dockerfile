ARG UBUNTU_VER=22.04
ARG AGH_BUILD

FROM ghcr.io/by275/base:ubuntu${UBUNTU_VER} AS base
FROM ghcr.io/by275/base:ubuntu AS prebuilt
FROM adguard/adguardhome:${AGH_BUILD} AS adguardhome

# 
# COLLECT
# 
FROM base AS collector

ARG TARGETARCH

# add s6 overlay
COPY --from=prebuilt /s6/ /bar/
ADD https://raw.githubusercontent.com/by275/docker-base/main/_/etc/cont-init.d/adduser /bar/etc/cont-init.d/10-adduser

# add unbound
ADD unbound-${TARGETARCH}.tar.gz /bar/

# add adguardhome
COPY --from=adguardhome /opt/adguardhome/AdGuardHome /bar/usr/local/bin/

# add adguardhome-sync
COPY --from=ghcr.io/bakito/adguardhome-sync:latest /opt/go/adguardhome-sync /bar/usr/local/bin/

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
        gettext-base \
        ldnsutils \
        net-tools \
        `# unbound` \
        libevent-2.1-7 \
        libexpat1 \
        libnghttp2-14 \
    && \
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
    TZ=Asia/Seoul \
    UNBOUND_ENABLED=0 \
    UNBOUND_CONFIG=/usr/local/etc/unbound/unbound.conf \
    UNBOUND_VERBOSITY=0 \
    UNBOUND_UPSTREAMS="1.1.1.1@853#cloudflare-dns.com 1.0.0.1@853#cloudflare-dns.com" \
    AGH_ENABLED=1

EXPOSE 80
EXPOSE 53/tcp
EXPOSE 53/udp

VOLUME /config

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 \
    CMD /usr/local/bin/healthcheck

ENTRYPOINT ["/init"]
