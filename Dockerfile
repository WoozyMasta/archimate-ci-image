FROM docker.io/ubuntu:20.04

ARG ARCHI_VERSION=4.8.1
ARG COARCHI_VERSION=0.7.1.202102021056
ARG TZ=UTC
ARG UID=1000

RUN set -xeu&& \
    # Add grou and user archi
    groupadd --gid "$UID" archi && \
    useradd --uid "$UID" --gid archi --shell /bin/bash \
      --home-dir /archi --create-home archi && \
    # Set timezone
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && \
    echo "$TZ" > /etc/timezone && \
    # Install dependecies
    apt-get update && \
    apt-get install -y \
      libgtk2.0-cil \
      libswt-gtk-4-jni \
      dbus-x11 \
      xvfb \
      curl \
      git \
      unzip && \
    apt-get clean && \
    # Download & extract Archimate tool
    curl "https://www.archimatetool.com/downloads/archi/" \
      --data-raw "dl=$ARCHI_VERSION/Archi-Linux64-$ARCHI_VERSION.tgz" \
      --output - | \
      tar zxf - -C /opt/ && \
    chmod +x /opt/Archi/Archi && \
    # Install Collaboration plugin
    curl "https://www.archimatetool.com/downloads/coarchi/org.archicontribs.modelrepository_$COARCHI_VERSION.archiplugin" \
       --output modelrepository.archiplugin && \
    unzip modelrepository.archiplugin -d /opt/Archi/plugins/ && \
    rm modelrepository.archiplugin && \
    chown -R "$UID:0" /archi && \
    chmod -R g+rw /archi

COPY docker-entrypoint.sh /opt/Archi/

USER archi
WORKDIR /archi

ENTRYPOINT [ "/opt/Archi/docker-entrypoint.sh" ]
