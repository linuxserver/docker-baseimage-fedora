FROM alpine:3.16 as rootfs-stage

# environment
ENV ARCH=x86_64
ARG FEDORA_VERSION

# install packages
RUN \
  apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    patch \
    tar \
    tzdata \
    xz

# grab tarball root
RUN \
  mkdir /root-out && \
  git clone --depth 1 -b ${FEDORA_VERSION} https://github.com/fedora-cloud/docker-brew-fedora.git && \
  tar xf \
    docker-brew-fedora/${ARCH}/fedora-${FEDORA_VERSION}*.tar.xz -C \
    /root-out && \
  sed -i -e 's/^root::/root:!:/' /root-out/etc/shadow

# set version for s6 overlay
ARG S6_OVERLAY_VERSION="3.1.0.1"
ARG S6_OVERLAY_ARCH="x86_64"

# add s6 overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz

# add s6 optional symlinks
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz

# copy ci-checks
COPY ci-check/ /root-out/package/admin/s6-overlay-${S6_OVERLAY_VERSION}/etc/s6-rc/sources/top/contents.d

# patch cont-init for docker-mods
COPY patch/ /tmp/patch
RUN  patch -u /root-out/package/admin/s6-overlay-${S6_OVERLAY_VERSION}/etc/s6-linux-init/skel/rc.init -i /tmp/patch/package/admin/s6-overlay-@VERSION@/etc/s6-linux-init/skel/rc.init.patch

# Runtime stage
FROM scratch
COPY --from=rootfs-stage /root-out/ /
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="TheLamer"

# environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
HOME="/root" \
TERM="xterm" \
S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0"

RUN \
  echo "**** install base packages ****" && \
  dnf -y --setopt=install_weak_deps=False --best install \
    ca-certificates \
    coreutils \
    findutils \
    hostname \
    procps \
    shadow \
    tzdata \
    which && \
  echo "**** create abc user and make our folders ****" && \
  useradd -u 911 -U -d /config -s /bin/false abc && \
  usermod -G users abc && \
  mkdir -p \
    /app \
    /config \
    /defaults && \
  echo "**** cleanup ****" && \
  dnf autoremove -y && \
  dnf clean all && \
  rm -rf \
    /tmp/*

# add local files
COPY root/ /

ENTRYPOINT ["/init"]
