# cloudnative-pg-timescaledb

CloudNativePG PostgreSQL image with TimescaleDB, pgVector, and PGAudit.

## Image

```
ghcr.io/inherent-design/cloudnative-pg-timescaledb
```

Base: `ghcr.io/cloudnative-pg/postgresql:18.1-system-bookworm`

The CNPG `system` base (Debian bookworm) includes pgVector, PGAudit, and the Barman backup toolchain. This image adds TimescaleDB from the official Timescale apt repository.

## Versions

| Component | Version | Source |
|---|---|---|
| PostgreSQL | 18.1 | CNPG base image |
| TimescaleDB | 2.25.1 | Timescale apt repository |
| pgVector | included | CNPG system image |
| PGAudit | included | CNPG system image |
| Barman Cloud | included | CNPG system image |

Versions are managed by Renovate. The CNPG base tag and TimescaleDB version are tracked as separate dependencies and updated via automated PRs.

## Tags

| Tag | Description |
|---|---|
| `latest` | Most recent build from main |
| `18` | Rolling latest for PostgreSQL 18 |
| `18-YYYYMMDD` | Weekly scheduled rebuild |
| `18-<sha>` | Git commit reference |

## Usage

### CloudNativePG Cluster

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-main
spec:
  instances: 1
  imageName: ghcr.io/inherent-design/cloudnative-pg-timescaledb:18

  postgresql:
    parameters:
      shared_preload_libraries: timescaledb

  bootstrap:
    initdb:
      database: app
      owner: app
      postInitSQL:
        - "CREATE EXTENSION IF NOT EXISTS timescaledb;"
        - "CREATE EXTENSION IF NOT EXISTS vector;"

  storage:
    size: 50Gi
```

### Docker (local development)

```bash
docker run -d \
  -e POSTGRES_PASSWORD=dev \
  -p 5432:5432 \
  ghcr.io/inherent-design/cloudnative-pg-timescaledb:18 \
  -c shared_preload_libraries=timescaledb
```

## Dockerfile

Starts from the CNPG system base, switches to root to install TimescaleDB from the official Timescale apt repository, then drops back to UID 26 (the postgres user in CNPG images). `PG_MAJOR` and `TIMESCALEDB_VERSION` build args are tracked by Renovate for automated version bumps.

## Build

Images are built automatically on push to `main` (when files in `cloudnative-pg-timescaledb/` change) and on a weekly schedule (Monday 06:00 UTC). Multi-arch: `linux/amd64`, `linux/arm64`.

Build includes a single-platform smoke test before the multi-arch push. The smoke test validates that TimescaleDB .so files, extension control files (timescaledb, vector), and all Barman backup binaries are present. Images are signed with cosign (keyless, via GitHub OIDC).
