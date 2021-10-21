FROM alpine:3.14 as rootfs-stage

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
    tzdata \
    xz

# grab tarball root
RUN \
  mkdir /root-out && \
  git clone -b ${FEDORA_VERSION} https://github.com/fedora-cloud/docker-brew-fedora.git && \
  tar xf \
    docker-brew-fedora/${ARCH}/fedora-${FEDORA_VERSION}*.tar.xz -C \
    /root-out && \
  sed -i -e 's/^root::/root:!:/' /root-out/etc/shadow

# Runtime stage
FROM scratch
COPY --from=rootfs-stage /root-out/ /
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="TheLamer"

# set version for s6 overlay
ARG OVERLAY_VERSION="v2.2.0.3"
ARG OVERLAY_ARCH="amd64"

# add s6 overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-${OVERLAY_ARCH}-installer /tmp/
RUN chmod +x /tmp/s6-overlay-${OVERLAY_ARCH}-installer && /tmp/s6-overlay-${OVERLAY_ARCH}-installer / && rm /tmp/s6-overlay-${OVERLAY_ARCH}-installer
COPY patch/ /tmp/patch

# environment variables
ENV PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
HOME="/root" \
TERM="xterm"

RUN \
  echo "**** install base packages ****" && \
  dnf -y --setopt=install_weak_deps=False --best install \
    ca-certificates \
    coreutils \
    findutils \
    hostname \
    patch \
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
  mv /usr/bin/with-contenv /usr/bin/with-contenvb && \
  patch -u /etc/s6/init/init-stage2 -i /tmp/patch/etc/s6/init/init-stage2.patch && \
  echo "**** cleanup ****" && \
  dnf remove -y \
    patch && \
  dnf autoremove -y && \
  dnf clean all && \
  rm -rf \
    /tmp/*

# add local files
COPY root/ /

ENTRYPOINT ["/init"]
