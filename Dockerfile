
#FROM adoptopenjdk/openjdk11:jdk-11.0.9.1_1-debian as build
#FROM openjdk:11.0.10-jdk-buster as build
FROM debian:10 as build

ARG TOMCAT_MAJOR
ARG TOMCAT_VERSION
ARG OPENSSL_VERSION
ARG APR_VERSION
ARG APR_UTIL_VERSION
ARG APR_ICONV_VERSION
ARG JDK11_VERSION="11.0.13+8"

ENV DEBIAN_FRONTEND=noninteractive \
    TOMCAT_MAJOR=${TOMCAT_MAJOR:-8} \
    TOMCAT_VERSION=${TOMCAT_VERSION:-8.5.73} \
    OPENSSL_VERSION=${OPENSSL_VERSION:-1.1.1m} \
    APR_VERSION=${APR_VERSION:-1.7.0} \
    APR_UTIL_VERSION=${APR_UTIL_VERSION:-1.6.1} \
    APR_ICONV_VERSION=${APR_ICONV_VERSION:-1.2.2} \
    JAVA_HOME=/usr/local/java

RUN set -eux;\
    apt-get clean && \
    apt-get update && \
    apt-get install \
    jq \
    gnupg2 \
    lsb-release \
    git \
    locales \
    ca-certificates \
    curl \
    vim \
    psmisc \
    procps \
    autoconf \
    gcc \
    make \
    libexpat1-dev \
    -yq; \
    mkdir -p "$JAVA_HOME"; \
    mkdir -p /usr/local/tomcat; \
    mkdir -p /opt/src/openssl; \
    mkdir -p /opt/src/apr; \
    mkdir -p /opt/src/apr-util; \
    mkdir -p /opt/src/apr-iconv; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
       aarch64|arm64) \
         javaArch="aarch64"; \
         ;; \
       armhf|armv7l) \
         javaArch="arm"; \
         ;; \
       ppc64el|ppc64le) \
         javaArch="ppc64le"; \
         ;; \
       amd64|x86_64) \
         javaArch="x64"; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
    esac; \
    curl -fsSL https://github.com/adoptium/temurin11-binaries/releases/download/jdk-$(printf '%s' $JDK11_VERSION | sed -e 's@+@%2B@g')/OpenJDK11U-jdk_${javaArch}_linux_hotspot_$(printf '%s' $JDK11_VERSION | sed -e 's@+@_@g').tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory ${JAVA_HOME}; \
    curl -fsSL https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory /usr/local/tomcat; \
    curl -fsSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz |tar --extract --gunzip --verbose --strip-components 1 --directory /opt/src/openssl; \
    curl -fsSL https://archive.apache.org/dist/apr/apr-${APR_VERSION}.tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory /opt/src/apr; \
    curl -fsSL https://archive.apache.org/dist/apr/apr-util-${APR_UTIL_VERSION}.tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory /opt/src/apr-util; \
    curl -fsSL https://archive.apache.org/dist/apr/apr-iconv-${APR_ICONV_VERSION}.tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory /opt/src/apr-iconv;




WORKDIR /opt/src/openssl
RUN pwd; ls -l; ./config --prefix=/usr/local/openssl; make -j "$(nproc)" && make install;


WORKDIR /opt/src/apr
RUN ./configure --prefix=/usr/local/apr; make -j "$(nproc)" && make install;


WORKDIR /opt/src/apr-iconv
RUN ./configure --prefix=/usr/local/apr-iconv --with-apr=/usr/local/apr; make -j "$(nproc)" && make install;

WORKDIR /opt/src/apr-util
RUN ./configure --prefix=/usr/local/apr --with-apr=/usr/local/apr --with-openssl=/usr/local/openssl --with-apr-iconv=../apr-iconv; make -j "$(nproc)" && make install;

WORKDIR /usr/local/tomcat/bin
RUN mkdir ./tcnative; tar -xvf tomcat-native.tar.gz --strip-components 1 --directory ./tcnative;

WORKDIR /usr/local/tomcat/bin/tcnative/native
RUN ./configure --with-apr=/usr/local/apr --with-java-home=${JAVA_HOME} --with-ssl=/usr/local/openssl; make -j "$(nproc)" && make install;






#https://github.com/docker-library/tomcat/blob/master/8.5/jdk11/adoptopenjdk-hotspot/Dockerfile
#FROM adoptopenjdk/openjdk11:jre-11.0.9.1_1-debian
#FROM openjdk:11.0.10-jre-buster

FROM debian:10

ARG TOMCAT_MAJOR
ARG TOMCAT_VERSION
ARG GOSU_VERSION
ARG JDK11_VERSION="11.0.13+8"

ENV DEBIAN_FRONTEND=noninteractive \
    TOMCAT_MAJOR=${TOMCAT_MAJOR:-8} \
    TOMCAT_VERSION=${TOMCAT_VERSION:-8.5.73} \
    GOSU_VERSION=${GOSU_VERSION:-1.14} \
    JAVA_HOME=/usr/local/java \
    CATALINA_HOME=/usr/local/tomcat

ENV PATH $JAVA_HOME/bin:$CATALINA_HOME/bin:$PATH
RUN mkdir -p "$JAVA_HOME" && mkdir -p "$CATALINA_HOME"

WORKDIR $CATALINA_HOME

COPY --from=build /usr/local/apr /usr/local/apr
COPY --from=build /usr/local/openssl /usr/local/openssl

RUN \
    apt-get clean && \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y ca-certificates curl vim git psmisc procps iproute2 net-tools libfreetype6 fontconfig fonts-dejavu -q; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
       aarch64|arm64) \
         javaArch="aarch64"; \
         gosuArch="arm64"; \
         ;; \
       armhf|armv7l) \
         javaArch="arm"; \
         gosuArch="armhf"; \
         ;; \
       ppc64el|ppc64le) \
         javaArch="ppc64le"; \
         gosuArch="ppc64el"; \
         ;; \
       amd64|x86_64) \
         javaArch="x64"; \
         gosuArch="amd64"; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/gosu https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${gosuArch}; \
    curl -fsSL https://github.com/adoptium/temurin11-binaries/releases/download/jdk-$(printf '%s' $JDK11_VERSION | sed -e 's@+@%2B@g')/OpenJDK11U-jre_${javaArch}_linux_hotspot_$(printf '%s' $JDK11_VERSION | sed -e 's@+@_@g').tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory ${JAVA_HOME}; \
    curl -fsSL https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory ${CATALINA_HOME}; \
    echo "LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/apr/lib" >> ${CATALINA_HOME}/bin/setenv.sh; \
    echo "export LD_LIBRARY_PATH" >> ${CATALINA_HOME}/bin/setenv.sh; \
    sed -i 's@Connector port="8080" protocol="HTTP/1.1"@Connector port="8080" protocol="org.apache.coyote.http11.Http11AprProtocol"@g' ${CATALINA_HOME}/conf/server.xml; \
    find ./bin/ -name '*.sh' -exec sed -ri 's|^#!/bin/sh$|#!/usr/bin/env bash|' '{}' +; \
    chmod -R +rX .; \
    chmod 777 logs temp work; \
    catalina.sh version; \
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && dpkg-reconfigure --frontend noninteractive tzdata; \
    rm -rf /var/lib/apt/lists/*; \
    chmod +x /usr/local/bin/gosu; \
    gosu --version;



EXPOSE 8080

COPY ./docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["catalina.sh", "run"]
