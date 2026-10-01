# containers

[![Build](https://img.shields.io/github/actions/workflow/status/inherent-design/containers/build.yml?style=flat&label=build)](https://github.com/inherent-design/containers/actions/workflows/build.yml) [![Security Scan](https://img.shields.io/github/actions/workflow/status/inherent-design/containers/security-scan.yml?style=flat&label=security%20scan)](https://github.com/inherent-design/containers/actions/workflows/security-scan.yml) [![License](https://img.shields.io/github/license/inherent-design/containers?style=flat)](LICENSE)

Container images for inherent.design infrastructure.

## Images

| Directory | Image | Description |
|---|---|---|
| [`cloudnative-pg-timescaledb`](cloudnative-pg-timescaledb/) | `ghcr.io/inherent-design/cloudnative-pg-timescaledb` | CloudNativePG PostgreSQL with TimescaleDB, pgVector, PGAudit |

Each directory contains a Dockerfile and README with image-specific documentation, usage examples, and version details.

See the [maintenance plan](MAINTENANCE.md) for the September 2026 audit, upgrade decisions, validation results, and release blockers.

## Workflows

| Workflow | Trigger | Schedule | Purpose |
|---|---|---|---|
| Build | Pull requests to main, push to main (path-filtered), manual dispatch | Monday 06:00 UTC | Workflow linting, image build, smoke test, Trivy scan, and publishing on main |
| Renovate Auto Approve | Renovate pull_request events | — | Opt-in approval of eligible same-repository Renovate updates |
| Security Scan | Weekly, manual dispatch | Wednesday 08:00 UTC | Trivy scan of both published architectures, upload SARIF to GitHub Security |
| Cleanup | Weekly | Sunday 03:00 UTC | Prune untagged and old GHCR images, keep 10 most recent tagged |

## Dependency Management

Renovate tracks base image tags and extension versions via regex custom managers.

- Patch, minor, digest, and pin updates are eligible for Renovate-managed automerge after checks pass. Native platform automerge is disabled because this repository currently has no required-check rules.
- TimescaleDB minor updates require human migration review; they are not eligible for automerge.
- Actions are pinned to commit SHAs, and Trivy, Cosign and ORAS binary versions are tracked explicitly.
- Auto-approval is disabled unless the repository variable `RENOVATE_AUTO_APPROVE` is `true`. Before enabling it, configure required `build` and `actionlint` checks and allow Actions to approve PRs in repository settings.
- Major updates are opened as draft PRs with `needs-review`.
- Failure surfacing stays in GitHub Actions and GitHub Security only; no issue automation is used for scan failures.

## License

Apache 2.0
