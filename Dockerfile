FROM docker.io/ubuntu:20.04

ARG ARCHI_VERSION=4.9.1
ARG COARCHI_VERSION=0.8.1.202112061132
ARG TZ=UTC

SHELL ["/bin/bash", "-o", "pipefail", "-x", "-e", "-u", "-c"]

# DL3015 ignored for suppress org.freedesktop.DBus.Error.ServiceUnknown
# hadolint ignore=DL3008,DL3015
RUN ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && \
    echo "$TZ" > /etc/timezone && \
    # Install dependecies \
    apt-get update && \
    apt-get install -y \
      ca-certificates \
      libgtk2.0-cil \
      libswt-gtk-4-jni \
      dbus-x11 \
      xvfb \
      curl \
      git \
      openssh-client \
      unzip && \
    apt-get clean && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    # Download & extract Archimate tool \
    curl 'https://www.archimatetool.com/downloads/archi/' --request POST \
      --data-raw "dl=$ARCHI_VERSION/Archi-Linux64-$ARCHI_VERSION.tgz" \
      --output - | \
      tar zxf - -C /opt/ && \
    chmod +x /opt/Archi/Archi && \
    # Install Collaboration plugin \
    mkdir -p /archi/.archi4/dropins/ && \
    curl "https://www.archimatetool.com/downloads/coarchi1/coArchi_$COARCHI_VERSION.archiplugin" \
       --output modelrepository.archiplugin && \
    unzip modelrepository.archiplugin -d /archi/.archi4/dropins/ && \
    rm modelrepository.archiplugin

COPY entrypoint.sh /opt/Archi/

WORKDIR /archi

ENTRYPOINT [ "/opt/Archi/entrypoint.sh" ]
