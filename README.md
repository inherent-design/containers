# containers

CloudNativePG images with extensions for inherent.design infrastructure.

## Images

| Image | Base | Extensions |
|-------|------|------------|
| `ghcr.io/inherent-design/cnpg-timescale:18` | `ghcr.io/cloudnative-pg/postgresql:18` (standard) | TimescaleDB, pgVector, PGAudit |

The CNPG `standard` base includes pgVector and PGAudit. This image adds TimescaleDB from the official Timescale apt repository.

## Usage

### CloudNativePG Cluster

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-main
spec:
  instances: 1
  imageName: ghcr.io/inherent-design/cnpg-timescale:18

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
  -e POSTGRES_INITDB_ARGS="-c shared_preload_libraries=timescaledb" \
  -p 5432:5432 \
  ghcr.io/inherent-design/cnpg-timescale:18
```

## Tags

| Tag | Description |
|-----|-------------|
| `18` | Rolling latest for PostgreSQL 18 |
| `18-YYYYMMDD` | Weekly scheduled rebuild |
| `18-<sha>` | Git commit reference |

## Build

Images are built automatically on push to `main` and on a weekly schedule (Monday 06:00 UTC). Multi-arch: `linux/amd64`, `linux/arm64`.

## License

Apache 2.0
