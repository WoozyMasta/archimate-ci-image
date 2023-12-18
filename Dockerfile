FROM docker.io/ubuntu:22.04 AS base

WORKDIR /archi

ARG TZ=UTC

# DL3015 ignored for suppress org.freedesktop.DBus.Error.ServiceUnknown
# hadolint ignore=DL3008,DL3015
RUN set -eux; \
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime; \
    echo "$TZ" > /etc/timezone; \
    apt-get update; \
    apt-get install -y \
      ca-certificates \
      language-pack-en-base \
      libgtk2.0-cil \
      libswt-gtk-4-jni \
      dbus-x11 \
      xvfb \
      curl \
      git \
      openssh-client \
      unzip; \
    apt-get clean; \
    update-ca-certificates; \
    rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8

FROM base AS archi
ARG ARCHI_VERSION=5.0.2

# Download & extract Archimate tool
RUN set -eux; \
    curl -#Lo archi.tgz \
      "https://www.archimatetool.com/downloads/archi-5.php?/$ARCHI_VERSION/Archi-Linux64-$ARCHI_VERSION.tgz"; \
    tar zxf archi.tgz -C /opt/; \
    rm archi.tgz; \
    chmod +x /opt/Archi/Archi; \
    mkdir -p /root/.archi/dropins /archi/report /archi/project

FROM archi AS coarchi
ARG COARCHI_VERSION=0.8.7

# Download & extract Archimate coArchi plugin
RUN set -eux; \
    curl -#Lo coarchi.zip --request POST \
      "https://www.archimatetool.com/downloads/coarchi/coArchi_$COARCHI_VERSION.archiplugin"; \
    unzip coarchi.zip -d /root/.archi/dropins/ && \
    rm coarchi.zip

FROM coarchi

COPY entrypoint.sh /opt/Archi/
ENTRYPOINT [ "/opt/Archi/entrypoint.sh" ]
