FROM debian:stretch-slim
LABEL maintainer="Tobias Armbruster <git@tobasium.de>"

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8

# Default versions
ENV INFLUXDB_VERSION=2.0.4
ENV CHRONOGRAF_VERSION=1.8.10
ENV GRAFANA_VERSION=7.5.3

# Grafana database type
#ENV GF_DATABASE_TYPE=sqlite3

# Fix bad proxy issue
COPY system/99fixbadproxy /etc/apt/apt.conf.d/99fixbadproxy

WORKDIR /root

# Clear previous sources
RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" && \
    case "${dpkgArch##*-}" in \
      amd64) ARCH='amd64';; \
      arm64) ARCH='arm64';; \
      armhf) ARCH='armhf';; \
      armel) ARCH='armel';; \
      *)     echo "Unsupported architecture: ${dpkgArch}"; exit 1;; \
    esac && \
    rm /var/lib/apt/lists/* -vf \
# Base dependencies
    && apt-get -y update \
    && apt-get -y dist-upgrade \
    && apt-get -y --force-yes install \
        apt-utils \
        ca-certificates \
        curl \
        git \
        htop \
        libfontconfig \
        nano \
        net-tools \
#        supervisor \
        wget \
        gnupg \
        procps \
    && curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    && apt-get install -y nodejs \
    && mkdir -p /var/log/supervisor \
    && rm -rf .profile \
    # Install InfluxDB
    && wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb2-${INFLUXDB_VERSION}-${ARCH}.deb \
    && dpkg -i influxdb2-${INFLUXDB_VERSION}-${ARCH}.deb \
    && rm influxdb2-${INFLUXDB_VERSION}-${ARCH}.deb \
    # Install Chronograf
    && wget https://dl.influxdata.com/chronograf/releases/chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb \
    && dpkg -i chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb && rm chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb \
    # Install Grafana
    #&& wget https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_${ARCH}.deb \
    #&& dpkg -i grafana_${GRAFANA_VERSION}_${ARCH}.deb \
    #&& rm grafana_${GRAFANA_VERSION}_${ARCH}.deb \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install gosu for easy step-down from root.
# https://github.com/tianon/gosu/releases
ENV GOSU_VER 1.12
RUN set -eux; \
  dpkgArch="$(dpkg --print-architecture)" && \
  wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VER/gosu-$dpkgArch" && \
  wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VER/gosu-$dpkgArch.asc" && \
  export GNUPGHOME="$(mktemp -d)" && \
  gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
  gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
  gpgconf --kill all && \
  rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc && \
  chmod +x /usr/local/bin/gosu && \
  gosu --version && \
  gosu nobody true

# Configure Grafana
#COPY grafana/grafana.ini /etc/grafana/grafana.ini

# Port
#EXPOSE 3003
#EXPOSE 8086

# Create standard directories expected by the entry-point.
RUN mkdir /docker-entrypoint-initdb.d && \
  mkdir -p /var/lib/influxdb2 && \
  chown -R influxdb:influxdb /var/lib/influxdb2 && \
  mkdir -p /etc/influxdb2 && \
  chown -R influxdb:influxdb /etc/influxdb2
VOLUME /var/lib/influxdb2 /etc/influxdb2

# Configure Start
COPY run.sh /run.sh
RUN ["chmod", "+x", "/run.sh"]

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["influxd"]