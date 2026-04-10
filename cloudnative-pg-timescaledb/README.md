# cloudnative-pg-timescaledb

CloudNativePG PostgreSQL image with TimescaleDB, pgVector, and PGAudit.

## Image

```
ghcr.io/inherent-design/cloudnative-pg-timescaledb
```

The CNPG `system` base (Debian bookworm) includes pgVector, PGAudit, and the Barman backup toolchain. This image adds TimescaleDB from the official Timescale apt repository.

## Versions

Exact version numbers are not maintained manually in this README.

- The intended CNPG base tag and TimescaleDB target version live in [Dockerfile](Dockerfile).
- The resolved installed package versions are reported in the GitHub Actions build summary for each run.
- The published image remains the source of truth for the runtime package versions that were actually shipped.

Versions are managed by Renovate. The CNPG base tag and TimescaleDB target version are tracked independently and updated via automated PRs.

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

Starts from the CNPG system base, switches to root to install TimescaleDB from the official Timescale apt repository, then drops back to UID 26 (the postgres user in CNPG images). `PG_MAJOR` and `TIMESCALEDB_VERSION` build args are tracked by Renovate for automated version bumps, and the Dockerfile now fails if the requested TimescaleDB version is not available in the apt repository.

## Build

Images are validated on pull requests to `main`, published on push to `main`, and rebuilt on a weekly schedule (Monday 06:00 UTC). Multi-arch: `linux/amd64`, `linux/arm64`.

The build includes:

- workflow linting with `actionlint`
- a single-platform smoke-test image build
- validation of TimescaleDB, pgVector, PGAudit, and the Barman toolchain
- Trivy scanning with SARIF upload and Actions summaries
- multi-arch publish, attestation, signing, and Artifact Hub metadata push on `main`
