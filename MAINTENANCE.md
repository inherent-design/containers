# Containers maintenance plan

Investigated on September 30, 2026, from `20b3ea2a3e2d2bb77d109000f2c35b930cfc5286`. The PostgreSQL 18 refresh is implemented on `maintenance/container-refresh`. The follow-up moves to Debian Trixie while retaining the system tier and Barman compatibility. Both architectures now pass the fixable HIGH/CRITICAL gate. [PR #21](https://github.com/inherent-design/containers/pull/21) is open and Greptile review was explicitly requested. Hosted workflow linting passed; the first build exposed unavailable arm64 runtime emulation, so runtime validation now uses native Blacksmith architecture runners. Final hosted checks remain pending; production rollout still requires database and collation maintenance.

## Repository and conventions

The expected checkout was absent and was cloned into `production/inherent.design/containers`. The relevant bootstrap is `~/.atlas/bootstrap/inherent-design.md`, especially its Container Images section. It describes February versions; main already contained April updates. The related docs bootstrap concerns the broader documentation project, not another container offering.

This repository offers one image: `ghcr.io/inherent-design/cloudnative-pg-timescaledb`, supporting amd64 and arm64. No CONTRIBUTING.md or AGENTS.md exists on main or dev; organization default CONTRIBUTING lookup also returned 404. The requested commit convention comes from `production/playground/AGENTS.md`: a `feat:` subject, blank line, and 15–30 tagged lowercase body entries with messages at most 40 characters. Existing history mostly uses short conventional commits. There are no GitHub Releases; successful main builds publish GHCR images, signatures, attestations and Artifact Hub metadata.

## GitHub findings

The [open PRs](https://github.com/inherent-design/containers/pulls) are all Renovate updates:

| PR | Update | Disposition in this change |
| --- | --- | --- |
| 13 | github-script 8 to 9 | Updated; existing script uses injected APIs and no removed CommonJS import |
| 14 | paths-filter 3 to 4 | Updated; Node 24 runtime, PR read permission explicit |
| 15 | TimescaleDB 2.26.2 to 2.30.2 | Updated; database migration review still required |
| 16 | trivy-action 0.35 to 0.36 | Updated to verified v0.36.0 commit; scanner pinned to 0.74.0 |
| 17 | cosign-installer 4.1.1 to 4.1.2 | Updated |
| 18 | CNPG PG 18.3 to 18.6 | Superseded by 18.6-system-trixie after both-architecture migration tests |
| 19 | checkout 6 to 7 | Updated; no fork checkout in privileged events |
| 20 | Blacksmith builder 1 to 2 | Updated with required `cache-key`; version-only PR omitted it |

The last published rolling image is from May 11, 2026: `sha256:6de53e66e9c151e6395b09c3b2b43960abff760f169cd448c867ee0151cd745e`. Main has not changed since April 10 UTC. No open issues, Dependabot alerts, branch protection, or rulesets were returned. Absence of Dependabot alerts does not establish container safety.

The code-scanning API returned 221 open alert records: 3 critical, 43 high, 117 medium, 54 low, 4 without a severity. These are alert records, not necessarily distinct CVEs. The [September 28 build](https://github.com/inherent-design/containers/actions/runs/36420121142) failed with 30 OS and 7 Python fixable HIGH/CRITICAL findings. The [September 30 published-image scan](https://github.com/inherent-design/containers/actions/runs/36728336145) also failed.

The [Renovate approval run](https://github.com/inherent-design/containers/actions/runs/36627721623) fails with `GitHub Actions is not permitted to approve pull requests.` Repository settings confirm `can_approve_pull_request_reviews=false`; `allow_auto_merge=true`. The workflow now uses ordinary same-repository PR events and is opt-in through `RENOVATE_AUTO_APPROVE=true`; it stays skipped under current settings. Approval is bound to the PR head commit. Native platform automerge is disabled so Renovate waits for checks itself; TimescaleDB minor updates require human migration review. Repository settings were not changed.

## Implemented changes

- Update PG to 18.6, TimescaleDB to 2.30.2, Barman to 3.20.1 and Debian to Trixie; refresh inherited OS packages. Retain the system tier for existing Barman consumers.
- Explicitly update Barman with upstream cloud-provider extras and run `pip check`. Barman 3.20.1 fixes CVE-2026-93853 and the CNPG complete/partial WAL restore bug. The latter is reproduced against 3.20.0 and tested against the new image without cloud credentials; scan databases alone did not identify this gap.
- Pin the TimescaleDB loader and extension to the same package version. The published image's default `CREATE EXTENSION timescaledb` fails because its loader advertises 2.26.4 while its extension package is 2.26.2. The previous smoke test missed this because it only checked files.
- Match requested package versions literally and fail if unavailable.
- Execute PostgreSQL startup, extension creation, hypertable queries, vector operations and Barman commands on both architectures. Add a disposable 2.26.2 upgrade fixture with compressed data and a continuous aggregate.
- Scan both architectures before publication and in weekly scans. Keep the fixable HIGH/CRITICAL gate. Upload SARIF only after report generation succeeds.
- Pin direct Actions to verified commit SHAs, supply Blacksmith v2's required cache key, resolve fresh bases and refresh package installation on every build. Update Cosign to 3.1.3 and ORAS to 1.3.4 rather than retaining older installer defaults; both are tracked by Renovate. Their upstream releases fix signature-verification and registry-credential-scoping issues respectively.
- Restrict publication and registry login to a main-only job. PR validation has no package/OIDC publishing permissions and uses a native amd64/arm64 matrix. A stable `build` check aggregates both results. Upload a candidate without release tags, test and scan its exact digest on both architectures, attest and sign it, then promote stable tags after separate native release-candidate checks. Add a unique run/attempt tag; preserve latest, 18 and Artifact Hub tags during cleanup.
- Correct CNPG's preload field type and initialize extensions in the application database. Replace the unsupported Docker entrypoint example. Document mutable tags, digest pinning and extension migrations.

## API and operational changes

[CNPG upstream](https://github.com/cloudnative-pg/postgres-containers) deprecates the system tier; standard retains pgvector, PGAudit, locales and JIT, but removes bundled Barman binaries. Bookworm is now in its LTS period. Trixie is selected by this PR. Switching libc/locales requires collation and index validation against restored data. The fixture reproduces glibc collation version 2.36 to 2.41, rebuilds indexes, refreshes the database collation version and checks preserved data. TimescaleDB must be upgraded as the first command in a fresh session, before REINDEX; the opposite order was tested and fails by loading the old extension.

Local platform source at `infra/platform/pulumi/platform/index.ts:646` still references `:18`, and line 685 configures `backup.barmanObjectStore`. This is source evidence, not confirmation of deployed state. Its `postInitSQL` creates TimescaleDB in the maintenance database rather than the named application database; review downstream use separately.

[Plugin migration](https://github.com/cloudnative-pg/plugin-barman-cloud/blob/v0.15.1/web/docs/migration.md) requires a namespaced `barmancloud.cnpg.io/v1` ObjectStore. Move Barman configuration to `spec.configuration` and retention to ObjectStore `spec.retentionPolicy`. Atomically replace in-tree backup configuration with the Cluster plugin declaration, `isWALArchiver: true` and `barmanObjectName`. Update Backup/ScheduledBackup to `method: plugin` and `pluginConfiguration`, plus recovery/externalClusters references. Provision plugin controller, CRDs, RBAC and any certificate dependencies from the chosen supported installation method; budget sidecar CPU/memory and verify object-store credentials and CA settings. Older plugin installations before 0.8 also require the upstream resource-name migration. No plugin installation was observed locally.

Latest upstream API responses report CNPG 1.30.1 and Barman plugin 0.15.1. Older bootstrap removal deadlines are stale: the current plugin guide says removal in a future release, and the 1.30.1 API still exposes in-tree Barman fields. Select supported operator/plugin versions using their compatibility documentation when executing that migration; do not infer a fixed removal deadline from the bootstrap.

[TimescaleDB 2.27](https://github.com/timescale/timescaledb/releases/tag/2.27.0) blocks upgrades for affected bloom sparse indexes on compressed `int2` columns and changes composite bloom metadata. Review and apply the upstream migration to affected databases. [2.29](https://github.com/timescale/timescaledb/releases/tag/2.29.0) drops PG 15, which does not affect this PG 18 image. [2.30.2](https://github.com/timescale/timescaledb/releases/tag/2.30.2) renames granular refresh settings to `timescaledb.cagg_granular_refresh_*`. A binary/image update does not run `ALTER EXTENSION`; follow the image README's per-database procedure. No legacy TimescaleDB variant is justified by the fixture results.

## Decisions requiring owner input

1. **Release sequence:** this PR updates the system image to Trixie with a documented database/collation migration. Move to the standard tier only after Barman plugin backup/restore rehearsal. Keep one image offering now. If external consumers require overlap during migration, define an explicit, time-limited legacy tag; do not silently change the backup contract of `:18`.
2. **Repository governance:** configure required `build` and `actionlint` checks. Auto-approval is opt-in and must stay disabled until required checks and Actions approval permissions are configured. TimescaleDB minor updates now require human review. The default path works with the existing prohibition on Actions approvals. No administrative settings were changed.
3. **Production rollout:** choose a maintenance window and verified rollback backup. The local platform specifies one instance, so restart downtime is possible. Pin the tested digest, inventory extension versions per database, check bloom metadata, upgrade extensions, then test application queries, WAL archive and restore. Restoring a pre-upgrade backup is the safe rollback boundary after catalog migrations; swapping an old image alone is insufficient. No cluster was changed.

## Release sequence

1. Require the new PR's build and actionlint checks plus Greptile review. Local Trixie builds and scans pass on both architectures; no CVE suppressions were added.
2. Review the maintenance branch and the decisions above. Run GitHub PR validation on Blacksmith; local tests cannot verify hosted Action execution, OIDC signing, SARIF permissions or Artifact Hub publication.
3. After passing checks and authorization to publish, merge to main. The existing main build is the release mechanism and updates `18`, `latest` and the source tag. A GitHub Release/version tag is not an established requirement.
4. Verify both manifest architectures, signatures, provenance/SBOM, and Artifact Hub metadata on the published digest. Verify the published image itself on both architectures. All eight PR diffs (#13–20) were inspected and consist solely of version bumps covered here. Close them as superseded after this PR merges; none needs an independent rebase or merge. Leaving them open until then preserves the update queue if this PR changes direction.
5. Deploy the approved digest separately using the database migration/restore procedure. Review GHCR retention before promising long-term rollback availability: cleanup keeps 10 tagged versions and removes older untagged/partial artifacts.

## Verification and limits

Evidence is retained locally in `.local/audit/` (excluded from Git). Baseline and modified actionlint 1.7.12 checks pass; `shellcheck` and `sh -n` pass for both test scripts. Both final Docker builds pass. Runtime smoke tests pass on arm64 natively and amd64 under Docker emulation. The disposable 2.26.2 to 2.30.2 upgrade passes on both architectures, preserving compressed rows and aggregate totals and exercising English UTF-8 collation reindex/refresh. An intentionally wrong expected extension version is rejected, and a build requesting unavailable TimescaleDB 0.0.0 fails with the expected package error. The published-image default extension-creation failure was reproduced. Renovate 44.126.1 strict config validation passes on Node 24.21.0. Zizmor 1.30.1 reports no workflow security findings.

Trivy 0.74.0, `--scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1`: both Trixie architectures pass with zero matching findings. The earlier Bookworm candidate failed on six HIGH amd64 libexpat1 findings; the signed Bookworm index still lacks that architecture's fix. The supported Trixie upgrade resolves this without suppressing findings or adding ad hoc packages. Zero matching findings does not mean no lower-severity or unfixed vulnerabilities. The first concurrent Trivy attempt hit its local cache lock; scans were rerun sequentially.

[Cosign 3.1.3 release](https://github.com/sigstore/cosign/releases/tag/v3.1.3) fixes a legacy-bundle verification bypass. [ORAS 1.3.4](https://github.com/oras-project/oras/releases/tag/v1.3.4) fixes credential leakage across registry origins. Existing `cosign sign --yes` and `oras push` calls remain supported; OCI referrers/signatures are preserved by the current cleanup action. Direct Actions are SHA-pinned with version comments so Renovate can maintain them.

Commands used, from repository root:

```sh
mise exec aqua:rhysd/actionlint@1.7.12 -- actionlint
shellcheck cloudnative-pg-timescaledb/*test.sh
sh -n cloudnative-pg-timescaledb/smoke-test.sh cloudnative-pg-timescaledb/upgrade-test.sh
docker build --pull --platform linux/arm64 -t containers-refresh:trixie-arm64 cloudnative-pg-timescaledb
docker build --pull --platform linux/amd64 -t containers-refresh:trixie-amd64 cloudnative-pg-timescaledb
# Repeat runtime and scan commands for each architecture.
docker run --rm -i --platform linux/arm64 --entrypoint sh -e TIMESCALEDB_VERSION=2.30.2 containers-refresh:trixie-arm64 -s < cloudnative-pg-timescaledb/smoke-test.sh
mise exec aqua:aquasecurity/trivy@0.74.0 -- trivy image --platform linux/arm64 --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 containers-refresh:trixie-arm64
PLATFORM=linux/arm64 sh cloudnative-pg-timescaledb/upgrade-test.sh ghcr.io/inherent-design/cloudnative-pg-timescaledb@sha256:6de53e66e9c151e6395b09c3b2b43960abff760f169cd448c867ee0151cd745e containers-refresh:trixie-arm64
git diff --check
```

Final Trixie image IDs are recorded with the local scan JSON and Docker build logs in `.local/audit/`. No production database restore, live Kubernetes API validation, production upgrade or release publication has been performed. Local fixtures establish upgrade mechanics, not compatibility with uninspected application data. Push and PR creation are authorized; main merge/publication and production rollout are separate remaining actions.
