# renovate: datasource=docker depName=ghcr.io/cloudnative-pg/postgresql
ARG CNPG_TAG=18.3-system-bookworm

FROM ghcr.io/cloudnative-pg/postgresql:${CNPG_TAG}

# renovate: datasource=github-releases depName=timescale/timescaledb
ARG TIMESCALEDB_VERSION=2.26.3
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
    && TS_PACKAGE="timescaledb-2-postgresql-${PG_MAJOR}" \
    && TS_PACKAGE_VERSION="$(apt-cache madison "${TS_PACKAGE}" | awk -v want="${TIMESCALEDB_VERSION}" '$3 ~ ("^" want "([+~.-]|$)") { print $3; exit }')" \
    && if [ -z "${TS_PACKAGE_VERSION}" ]; then \
         echo "Requested ${TS_PACKAGE} version ${TIMESCALEDB_VERSION} is not available" >&2; \
         apt-cache madison "${TS_PACKAGE}" >&2; \
         exit 1; \
       fi \
    && apt-get install -y --no-install-recommends \
       openssl \
       libssl3 \
       "${TS_PACKAGE}=${TS_PACKAGE_VERSION}" \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

USER 26
