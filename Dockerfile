FROM oracle/jdk:15

LABEL org.opencontainers.image.authors="Geoff Bourne <itzgeoff@gmail.com>"

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive \
  apt-get upgrade -y

RUN DEBIAN_FRONTEND=noninteractive \
  apt-get install -y \
    openssl \
    imagemagick \
    lsof \
    gosu \
    bash \
    curl iputils wget \
    git \
    jq \
    dos2unix \
    mysql-client \
    tzdata \
    rsync \
    nano \
    sudo \
    unzip \
    knockd \
    ttf-dejavu \
    && apt-get clean

RUN addgroup --gid 1000 minecraft \
  && adduser --system --shell /bin/false --uid 1000 --ingroup minecraft --home /home/minecraft minecraft \
  && mkdir -m 777 /data \
  && chown minecraft:minecraft /data /home/minecraft

COPY files/sudoers* /etc/sudoers.d

EXPOSE 25565 25575

# hook into docker BuildKit --platform support
# see https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

ARG EASY_ADD_VER=0.7.1
ADD https://github.com/itzg/easy-add/releases/download/${EASY_ADD_VER}/easy-add_${TARGETOS}_${TARGETARCH}${TARGETVARIANT} /usr/bin/easy-add
RUN chmod +x /usr/bin/easy-add

RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
  --var version=1.2.0 --var app=restify --file {{.app}} \
  --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz

RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
 --var version=1.4.7 --var app=rcon-cli --file {{.app}} \
 --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz

RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
 --var version=0.1.7 --var app=mc-monitor --file {{.app}} \
 --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz

RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
 --var version=1.5.0 --var app=mc-server-runner --file {{.app}} \
 --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz

RUN easy-add --var os=${TARGETOS} --var arch=${TARGETARCH}${TARGETVARIANT} \
 --var version=0.1.1 --var app=maven-metadata-release --file {{.app}} \
 --from https://github.com/itzg/{{.app}}/releases/download/{{.version}}/{{.app}}_{{.version}}_{{.os}}_{{.arch}}.tar.gz

COPY mcstatus /usr/local/bin

VOLUME ["/data"]
COPY server.properties /tmp/server.properties
COPY log4j2.xml /tmp/log4j2.xml
WORKDIR /data

ENV UID=1000 GID=1000 \
  JVM_XX_OPTS="-XX:+UseG1GC" MEMORY="1G" \
  TYPE=VANILLA VERSION=LATEST FORGEVERSION=RECOMMENDED SPONGEBRANCH=STABLE SPONGEVERSION= FABRICVERSION=LATEST LEVEL=world \
  PVP=true DIFFICULTY=easy ENABLE_RCON=true RCON_PORT=25575 RCON_PASSWORD=minecraft \
  LEVEL_TYPE=DEFAULT SERVER_PORT=25565 ONLINE_MODE=TRUE SERVER_NAME="Dedicated Server" \
  ENABLE_AUTOPAUSE=false AUTOPAUSE_TIMEOUT_EST=3600 AUTOPAUSE_TIMEOUT_KN=120 AUTOPAUSE_TIMEOUT_INIT=600 AUTOPAUSE_PERIOD=10

COPY start* /
COPY health.sh /
ADD files/autopause /autopause

RUN dos2unix /start* && chmod 444 /start* && chmod +x /start*
RUN dos2unix /health.sh && chmod 444 /health.sh && chmod +x /health.sh
RUN dos2unix /autopause/* && chmod 444 /autopause/*.sh && chmod +x /autopause/*.sh

ENTRYPOINT [ "/start" ]
HEALTHCHECK --start-period=1m CMD /health.sh
