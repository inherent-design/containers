# cloudnative-pg-timescaledb

CloudNativePG PostgreSQL image with TimescaleDB, pgVector, and PGAudit.

## Image

```
ghcr.io/inherent-design/cloudnative-pg-timescaledb
```

The CNPG `system` base (Debian Trixie) includes pgVector, PGAudit, and the Barman backup toolchain. This image adds TimescaleDB from the official Timescale apt repository and updates Barman with the same cloud-provider extras as the upstream base. Barman is tracked explicitly because base-image rebuilds can lag backup security fixes.

The upstream `system` tier is deprecated. It is retained here for existing clusters using `spec.backup.barmanObjectStore`. Migration to the `standard` tier requires the Barman Cloud plugin and a validated backup/restore migration; removing the bundled backup commands from the rolling `18` tag would break those clusters.

## Versions

Exact version numbers are not maintained manually in this README.

- The intended CNPG base tag, TimescaleDB version and Barman version live in [Dockerfile](Dockerfile).
- The resolved installed package versions are reported in the GitHub Actions build summary for each run.
- The published image remains the source of truth for the runtime package versions that were actually shipped.

Versions are managed by Renovate. The CNPG base tag, TimescaleDB and Barman are tracked independently and updated via automated PRs.

## Tags

| Tag | Description |
|---|---|
| `latest` | Most recent build from main |
| `18` | Rolling latest for PostgreSQL 18 |
| `18-YYYYMMDD` | Weekly scheduled rebuild |
| `18-build-<run>-<attempt>` | Unique build reference; also pin its digest |
| `18-<sha>` | Source reference; rebuilds of the same commit can replace this tag |

Pin production deployments to a tested image digest. Rolling tags and source tags are mutable because upstream images and OS packages receive updates.

Cleanup preserves `latest`, `18` and `artifacthub.io`, keeps the 10 most recent tagged versions, and removes eligible artifacts older than 30 days. Preserve required rollback images separately before relying on long-term availability.

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
    shared_preload_libraries:
      - timescaledb

  bootstrap:
    initdb:
      database: app
      owner: app
      postInitApplicationSQL:
        - "CREATE EXTENSION IF NOT EXISTS timescaledb;"
        - "CREATE EXTENSION IF NOT EXISTS vector;"

  storage:
    size: 50Gi
```

### Docker validation

CNPG operand images do not provide the Docker Official Image initialization entrypoint or process `POSTGRES_PASSWORD`. Use [smoke-test.sh](smoke-test.sh) to check a built image locally or in CI. It runs inside the container as the default postgres user (UID 26), starts a temporary database on a local Unix socket, creates TimescaleDB, pgVector and PGAudit, executes basic hypertable and vector queries, and checks that the five Barman cloud commands start.

The script stops PostgreSQL and removes its temporary data on exit. A failed check returns a nonzero exit code. It does not exercise production data, database upgrades or cloud backup/restore operations.

```bash
# From the repository root; initializes temporary data without exposing a port.
docker build --pull -t containers-refresh:local cloudnative-pg-timescaledb
docker run --rm -i --entrypoint sh \
  containers-refresh:local \
  -s < cloudnative-pg-timescaledb/smoke-test.sh
```

`PG_MAJOR` selects the installed PostgreSQL binaries (default `18`). Set `TIMESCALEDB_VERSION` with Docker's `-e` option to require a specific extension version; CI takes that value from the Dockerfile.

## Dockerfile

Starts from the CNPG system base, refreshes inherited OS packages, installs TimescaleDB and its loader at the same exact package version, updates Barman and checks its Python dependencies, then drops back to UID 26 (the postgres user in CNPG images). Renovate tracks `CNPG_TAG`, `TIMESCALEDB_VERSION` and `BARMAN_VERSION`; `PG_MAJOR` stays at 18. The build fails if a requested version is unavailable.

## Build

Image, test, workflow and dependency-configuration changes are validated on pull requests and pushes to `main`. Pushes publish only when the Dockerfile, image `.dockerignore`, or `artifacthub-repo.yml` changes. Images are also rebuilt and published weekly (Monday 06:00 UTC) or by manual dispatch on `main`. Multi-arch: `linux/amd64`, `linux/arm64`.

The build includes:

- a separate validation workflow with `actionlint`, ShellCheck and shell syntax checks
- fresh base resolution and uncached package installation on every build
- native amd64 and arm64 image builds and PostgreSQL startup tests
- extension creation and SQL checks, plus startup checks for all five Barman cloud commands
- Trivy scanning of both architectures, blocking fixable HIGH/CRITICAL findings, with SARIF upload and Actions summaries
- main-only jobs that upload an untagged multiarch candidate, test and scan that exact digest, attest and sign it, then promote release tags and update Artifact Hub metadata
- commit-pinned Actions with Renovate updates and no publishing credentials in PR validation

Manual dispatch on other branches validates images but cannot publish stable tags. Candidates are scanned again because the publication build can resolve different upstream packages.

## Upgrading existing databases

Replacing the image updates binaries; it does not update installed SQL extensions. Before rollout, record each database's `pg_extension` versions and rehearse on a restored backup. After installing the new image, use a fresh `psql -X` session in each database that has TimescaleDB, with no preceding query that loads the old extension:

```sql
ALTER EXTENSION timescaledb UPDATE;
```

Update `vector` and `pgaudit` in databases where they are installed, then validate application queries, compressed chunks, continuous aggregates, WAL archiving and restore. An image rollback alone is not a database rollback after extension catalog migrations; retain a tested pre-upgrade backup.

The [TimescaleDB 2.27 upgrade notes](https://github.com/timescale/timescaledb/releases/tag/2.27.0) identify blocked upgrades involving bloom sparse indexes on compressed `int2` columns and a metadata migration for 2.26 composite bloom filters. Inspect these before upgrading from 2.26. The [2.30.2 release](https://github.com/timescale/timescaledb/releases/tag/2.30.2) renames granular refresh settings to `timescaledb.cagg_granular_refresh_*`; review custom settings.

### Bookworm to Trixie

Moving from Debian 12 to Debian 13 changes libc and locale data. Before resuming application traffic, rebuild objects affected by changed libc or ICU sort rules, then refresh their recorded collation versions. Refreshing the version alone does not repair indexes. See [PostgreSQL collation guidance](https://www.postgresql.org/docs/18/sql-altercollation.html).

For a database named `postgres`, the sequence after the extension updates is:

```sql
REINDEX DATABASE postgres;
ALTER DATABASE postgres REFRESH COLLATION VERSION;
```

Inventory every application database and explicitly used collation in production; adapt names, reindex affected objects and refresh explicit collations as needed. Do not run these maintenance commands before `ALTER EXTENSION timescaledb UPDATE` in the same session: doing so loads the old TimescaleDB version and prevents its update. Rehearse this procedure against a restored application backup before rollout.

### Barman fixes

[Barman 3.20.1](https://github.com/EnterpriseDB/barman/releases/tag/release/3.20.1) fixes CVE-2026-93853 (snapshot deletion trusting catalog identifiers) and CloudNativePG WAL restores when complete and partial files coexist. Serial restore no longer requires a writable spool directory. Validate archive and restore operations against your backup store before rollout.
