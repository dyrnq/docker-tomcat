
#FROM adoptopenjdk/openjdk11:jdk-11.0.9.1_1-debian as build
#FROM openjdk:11.0.10-jdk-buster as build
FROM debian:10 as build

ENV DEBIAN_FRONTEND=noninteractive \
    TOMCAT_MAJOR=8 \
    TOMCAT_VERSION=8.5.61 \
    OPENSSL_VERSION=1.1.1i \
    APR_VERSION=1.7.0 \
    APR_UTIL_VERSION=1.6.1 \
    APR_ICONV_VERSION=1.2.2 \
    JAVA_HOME=/usr/local/java

RUN set -eux;\
    sed -i "s@deb.debian.org@mirrors.huaweicloud.com@g" /etc/apt/sources.list && \
    sed -i "s@security.debian.org@mirrors.huaweicloud.com@g" /etc/apt/sources.list && \
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
    curl -fksSL https://mirrors.tuna.tsinghua.edu.cn/AdoptOpenJDK/11/jdk/x64/linux/OpenJDK11U-jdk_x64_linux_hotspot_11.0.9.1_1.tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory ${JAVA_HOME}}; \
    curl -fksSL https://mirrors.huaweicloud.com/apache/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory /usr/local/tomcat; \
    curl -fksSL https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz |tar --extract --gunzip --verbose --strip-components 1 --directory /opt/src/openssl; \
    curl -fksSL https://mirrors.huaweicloud.com/apache/apr/apr-${APR_VERSION}.tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory /opt/src/apr; \
    curl -fksSL https://mirrors.huaweicloud.com/apache/apr/apr-util-${APR_UTIL_VERSION}.tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory /opt/src/apr-util; \
    curl -fksSL https://mirrors.huaweicloud.com/apache/apr/apr-iconv-${APR_ICONV_VERSION}.tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory /opt/src/apr-iconv;




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







#FROM adoptopenjdk/openjdk11:jre-11.0.9.1_1-debian
#FROM openjdk:11.0.10-jre-buster

FROM debian:10

ENV DEBIAN_FRONTEND=noninteractive \
    TOMCAT_MAJOR=8 \
    TOMCAT_VERSION=8.5.61 \
    JAVA_HOME=/usr/local/java

ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $JAVA_HOME/bin:$CATALINA_HOME/bin:$PATH
RUN mkdir -p "$JAVA_HOME"
RUN mkdir -p "$CATALINA_HOME"
WORKDIR $CATALINA_HOME


RUN \
    sed -i "s@deb.debian.org@mirrors.huaweicloud.com@g" /etc/apt/sources.list && \
    sed -i "s@security.debian.org@mirrors.huaweicloud.com@g" /etc/apt/sources.list && \
    apt-get clean && \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y ca-certificates curl vim git psmisc procps iproute2 net-tools -q; \
    curl -fksSL https://mirrors.tuna.tsinghua.edu.cn/AdoptOpenJDK/11/jre/x64/linux/OpenJDK11U-jre_x64_linux_hotspot_11.0.9.1_1.tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory ${JAVA_HOME}; \
    curl -fksSL https://mirrors.huaweicloud.com/apache/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz | tar --extract --gunzip --verbose --strip-components 1 --directory ${CATALINA_HOME};

COPY --from=build /usr/local/apr /usr/local/apr
COPY --from=build /usr/local/openssl /usr/local/openssl

RUN \
    echo "LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/apr/lib" >> ${CATALINA_HOME}/bin/setenv.sh; \
    echo "export LD_LIBRARY_PATH" >> ${CATALINA_HOME}/bin/setenv.sh; \
    sed -i 's@Connector port="8080" protocol="HTTP/1.1"@Connector port="8080" protocol="org.apache.coyote.http11.Http11AprProtocol"@g' ${CATALINA_HOME}/conf/server.xml; \
    find ./bin/ -name '*.sh' -exec sed -ri 's|^#!/bin/sh$|#!/usr/bin/env bash|' '{}' +; \
    chmod -R +rX .; \
    chmod 777 logs temp work; \
    catalina.sh version    

RUN ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && dpkg-reconfigure --frontend noninteractive tzdata



EXPOSE 8080
CMD ["catalina.sh", "run"]
