FROM debian:bullseye

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       netbase \
       wget \
  && rm -rf /var/lib/apt/lists/*

RUN set -ex; \
  if ! command -v gpg > /dev/null; then \
    apt-get update; \
    apt-get install -y --no-install-recommends  \
      gnupg \
      dirmngr \
      ; \
    rm -rf /var/lib/apt/lists/*; \
  fi

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       bzr \
       git \
       mercurial \
       openssh-client \
       subversion \
       procps \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    bzip2 \
    unzip \
    xz-utils \
    ca-certificates \
    p11-kit \
    fontconfig \
    libfreetype6 \
    ; \
  rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8
ENV JAVA_HOME=/usr/local/openjdk-8
ENV PATH=/usr/local/openjdk-8/bin:${PATH}

RUN { echo '#/bin/sh'; echo 'echo "$JAVA_HOME"'; } > /usr/local/bin/docker-java-home \
  && chmod +x /usr/local/bin/docker-java-home \
  && [ "$JAVA_HOME" = "$(docker-java-home)" ]

ENV JAVA_VERSION=8u242
ENV JAVA_BASE_URL=https://github.com/AdoptOpenJDK/openjdk8-upstream-binaries/releases/download/jdk8u242-b08/OpenJDK8U-jdk_
ENV JAVA_URL_VERSION=8u242b08

RUN set -eux; \
  dpkgArch="$(dpkg --print-architecture)"; \
  case "$dpkgArch" in \
    amd64) upstreamArch='x64' ;; \
    arm64) upstreamArch='aarch64' ;; \
    *) echo >&2 "error: unsupported architecture: $dpkgArch" ;; \
  esac; \
  wget -O openjdk.tgz.asc "${JAVA_BASE_URL}${upstreamArch}_linux_${JAVA_URL_VERSION}.tar.gz.sign"; \
  wget -O openjdk.tgz "${JAVA_BASE_URL}${upstreamArch}_linux_${JAVA_URL_VERSION}.tar.gz" --progress=dot:giga; \
  export GNUPGHOME="$(mktemp -d)"; \
  gpg --batch --keyserver ha.pool.sks-keyservers.net --keyserver-options no-self-sigs-only --recv-keys CA5F11C6CE22644D42C6AC4492EF8D39DC13168F; \
  gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys EAC843EBD3EFDB98CC772FADA5CD6035332FA671; \
  gpg --batch --list-sigs --keyid-format 0xLONG CA5F11C6CE22644D42C6AC4492EF8D39DC13168F   | tee /dev/stderr   | grep '0xA5CD6035332FA671'   | grep 'Andrew Haley'; \
  gpg --batch --verify openjdk.tgz.asc openjdk.tgz; \
  gpgconf --kill all; \
  rm -rf "$GNUPGHOME"; \
  mkdir -p "$JAVA_HOME"; \
  tar --extract   --file openjdk.tgz   --directory "$JAVA_HOME"   --strip-components 1   --no-same-owner  ; \
  rm openjdk.tgz*; \
  { \
    echo '#!/usr/bin/env bash'; \
    echo 'set -Eeuo pipefail'; \
    echo 'if ! [ -d "$JAVA_HOME" ]; then echo >&2 "error: missing JAVA_HOME environment variable"; exit 1; fi'; \
    echo 'cacertsFile=; for f in "$JAVA_HOME/lib/security/cacerts" "$JAVA_HOME/jre/lib/security/cacerts"; do if [ -e "$f" ]; then cacertsFile="$f"; break; fi; done'; \
    echo 'if [ -z "$cacertsFile" ] || ! [ -f "$cacertsFile" ]; then echo >&2 "error: failed to find cacerts file in $JAVA_HOME"; exit 1; fi'; \
    echo 'trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "$cacertsFile"'; \
  } > /etc/ca-certificates/update.d/docker-openjdk; \
  chmod +x /etc/ca-certificates/update.d/docker-openjdk; \
  /etc/ca-certificates/update.d/docker-openjdk; \
  find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
  ldconfig; \
  javac -version; \
  java -version


