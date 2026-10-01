# renovate: datasource=docker depName=ghcr.io/cloudnative-pg/postgresql
ARG CNPG_TAG=18.6-system-trixie

FROM ghcr.io/cloudnative-pg/postgresql:${CNPG_TAG}

# renovate: datasource=github-releases depName=timescale/timescaledb
ARG TIMESCALEDB_VERSION=2.30.2
ARG PG_MAJOR=18

# renovate: datasource=pypi depName=barman
ARG BARMAN_VERSION=3.20.1

USER root

RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && . /etc/os-release \
    && echo "deb https://packagecloud.io/timescale/timescaledb/debian/ ${VERSION_CODENAME} main" \
       > /etc/apt/sources.list.d/timescaledb.list \
    && curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
       | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg \
    && apt-get update \
    && TS_PACKAGE="timescaledb-2-postgresql-${PG_MAJOR}" \
    && TS_PACKAGE_VERSION="$(apt-cache madison "${TS_PACKAGE}" | awk -v want="${TIMESCALEDB_VERSION}" '$3 == want || (index($3, want) == 1 && substr($3, length(want) + 1, 1) ~ /^[+~.-]$/) { print $3; exit }')" \
    && if [ -z "${TS_PACKAGE_VERSION}" ]; then \
         echo "Requested ${TS_PACKAGE} version ${TIMESCALEDB_VERSION} is not available" >&2; \
         apt-cache madison "${TS_PACKAGE}" >&2; \
         exit 1; \
       fi \
    && apt-get install -y --no-install-recommends \
       "${TS_PACKAGE}=${TS_PACKAGE_VERSION}" \
       "timescaledb-2-loader-postgresql-${PG_MAJOR}=${TS_PACKAGE_VERSION}" \
    && python3 -m pip install --no-cache-dir \
       "barman[cloud,azure,snappy,google,zstandard,lz4]==${BARMAN_VERSION}" \
    && python3 -m pip check \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

USER 26
