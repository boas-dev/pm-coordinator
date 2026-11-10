# pm-coordinator — unassigned
A public repo for coordinator workflows that tie the private repos' issue events to the org's Project boards; it names no owner agent yet.

## Purpose
This repo holds only orchestration glue: no application code, no task content and no secrets. It is public so its Actions minutes are free; the work itself lives in the private repos, and the boards are theirs. Credentials and GitHub App wiring are Hades's. Today it holds a README and a licence and no workflow. Operations references in `~/.claude/rules/` load with this file.

## Orientation
Start at [README.md](README.md): why the repo is public, what belongs here and the workflow conventions. Workflows go in the .github workflows folder when they are added. This file follows Hades's AGENTS.md standard.

## Hard rules
- Nothing private is committed here: no secret, credential, task content, client name or internal host, since anyone can read this repo.
- No credential value ever enters context; credentials are Hades's. A workflow mints a GitHub App token at job runtime; no long-lived token is stored or referenced.
- Permission, credential, env-injection and GitHub App requests go to Hades through the `hades-request` skill: the symptom, never a value, and never commands or options handed to the operator for it.
- Every GitHub call goes through a Pantheon GitHub App identity (`pantheon-gh dev`, or `read` for reads), with bodies in `--body-file`; no personal token, no ambient `gh` login.
- `main` takes every change by PR, rebase merge, verified on the remote.
- A workflow triggered by `issues` events gates at the job level before a runner starts, and a new workflow is checked against the monthly minute budget before it merges.
- Two guard or sandbox rejections in a row: stop and report.
- Ask the operator only about a change to the original directive; every technical question is the seat's: decide, act, record it on the issue.
