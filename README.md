# containers

[![Build](https://img.shields.io/github/actions/workflow/status/inherent-design/containers/build.yml?style=flat&label=build)](https://github.com/inherent-design/containers/actions/workflows/build.yml) [![Security Scan](https://img.shields.io/github/actions/workflow/status/inherent-design/containers/security-scan.yml?style=flat&label=security%20scan)](https://github.com/inherent-design/containers/actions/workflows/security-scan.yml) [![License](https://img.shields.io/github/license/inherent-design/containers?style=flat)](LICENSE)

Container images for inherent.design infrastructure.

## Images

| Directory | Image | Description |
|---|---|---|
| [`cloudnative-pg-timescaledb`](cloudnative-pg-timescaledb/) | `ghcr.io/inherent-design/cloudnative-pg-timescaledb` | CloudNativePG PostgreSQL with TimescaleDB, pgVector, PGAudit |

Each directory contains a Dockerfile and README with image-specific documentation, usage examples, and version details.

## Workflows

| Workflow | Trigger | Schedule | Purpose |
|---|---|---|---|
| Build | Pull requests to main, push to main (path-filtered), manual dispatch | Monday 06:00 UTC | Workflow linting, image build, smoke test, Trivy scan, and publishing on main |
| Renovate Auto Approve | Renovate pull_request_target events | — | Auto-approve safe Renovate patch/minor/digest updates after policy checks |
| Security Scan | Weekly | Wednesday 08:00 UTC | Trivy scan of published images, upload SARIF to GitHub Security |
| Cleanup | Weekly | Sunday 03:00 UTC | Prune untagged and old GHCR images, keep 10 most recent tagged |

## Dependency Management

Renovate tracks base image tags and extension versions via regex custom managers.

- Patch, minor, digest, and pin updates are labeled `safe-automerge` and are intended to auto-merge after checks pass.
- Major updates are opened as draft PRs with `needs-review`.
- Failure surfacing stays in GitHub Actions and GitHub Security only; no issue automation is used for scan failures.

## License

Apache 2.0
