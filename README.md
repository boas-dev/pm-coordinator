# pm-coordinator

Coordinator workflows for internal project-management automation.

## Why this repo is public

This repository is intentionally public. The workflows hosted here run on GitHub Actions, and **public repositories receive unlimited free Linux Actions minutes**. Private repositories share a finite monthly minute quota; hosting orchestration here keeps that quota available for repo-specific work.

## What's here

- `.github/workflows/` — automation that reads org Project boards and dispatches work to other repositories.
- `LICENSE` — see below.

## What's NOT here

- Application code, business logic, or production services.
- Issue tracking, task content, or development history.
- Secrets, credentials, or any sensitive configuration.

Work itself lives in private repositories; this repo only contains the orchestration glue that ties their issue events to org-level Project boards.

## Workflow conventions

- All cross-repository writes use GitHub App tokens minted at job runtime; no long-lived PATs are stored or referenced.
- Workflows triggered by `issues` events gate at the job level (`jobs.<id>.if`) before any runner is provisioned, to avoid unnecessary minute consumption.
- New workflows are reviewed against an explicit per-month minute budget before merge.

## License

MIT — see [`LICENSE`](./LICENSE).
