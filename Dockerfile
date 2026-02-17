# renovate: datasource=docker depName=ghcr.io/cloudnative-pg/postgresql
ARG CNPG_TAG=18

FROM ghcr.io/cloudnative-pg/postgresql:${CNPG_TAG}

# renovate: datasource=github-releases depName=timescale/timescaledb
ARG TIMESCALEDB_VERSION=2.25.1
ARG PG_MAJOR=18

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && . /etc/os-release \
    && echo "deb https://packagecloud.io/timescale/timescaledb/debian/ ${VERSION_CODENAME} main" \
       > /etc/apt/sources.list.d/timescaledb.list \
    && curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
       | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       "timescaledb-2-postgresql-${PG_MAJOR}" \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

USER 26
