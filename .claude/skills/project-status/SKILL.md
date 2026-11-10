---
name: project-status
description: Any seat. Keep a registered Project's README and status current - for a slug in directr/projects/, print the Project's README, rebuild it from the PRD (Vision, Roadmap Now:, Features), write it with factory-board.py describe --readme-file and post one status-update with its state and the Roadmap line, through the board App. Use after project-start, after a release, or when the operator says project status, update the README, status update. Keywords: project-status, project README, status update, Project status, describe.
allowed-tools: Bash, Read, Write
---

# project-status — the Project's README and status, from its PRD

Run from the repo checkout (or a lane worktree) that holds `directr/projects/<slug>.json`. The standard it keeps is `docs/reference/github-structure.md` `## Projects`. Only `scripts/factory-board.py` verbs, through the board App (`pantheon-gh board`); never a personal token, never `GH_TOKEN`.

`<hades>` is the constellation-hades checkout that holds `scripts/factory-board.py`.

## 1. Read

```bash
slug=<slug>
reg=directr/projects/$slug.json
n=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["project"]["number"])' "$reg")
dir=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["dir"])' "$reg")
```

- The slug resolves to its number through `directr/projects/<slug>.json` only; a slug with no file is not registered: stop and say so (`/project-start` registers it).
- The PRD is `<dir>/PRD.md`. A missing PRD stops the skill: there is nothing to build the README from.

## 2. Show

Print the Project's current README from directr's local mirror, so the operator sees what is replaced. No GitHub read of its own:

```bash
main=$(git worktree list --porcelain | sed -n '1s/^worktree //p')   # the main checkout, also from a lane worktree
(cd "$main" && herdr-directr sync pull)
m=$main/directr/board/projects/$slug.json; [ -f "$m" ] || m=$main/directr/board/projects/$n.json
python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["title"]); print(d.get("readme") or "(empty)")' "$m"
```

The mirror lives in the repo's main checkout, so the pull and the read both run there, never in a lane worktree. It names a file by the slug, or by the number for a Project it holds unregistered.

## 3. Write README

Build the README in a scratch file from `<dir>/PRD.md`, in this order and nothing else:

1. `# <title>`, the Project title.
2. The PRD's `## Vision`, as written.
3. `## Now`: the Roadmap's `Now:` line, as written. With no `Now:` line, write `Now: not set in the PRD` and say so in the report; never pick a Roadmap entry by guess.
4. `## Features`: the PRD's Features table, as written.
5. One last line: `Source: <dir>/PRD.md`.

Then write it:

```bash
FACTORY_GH="pantheon-gh board" python3 -I <hades>/scripts/factory-board.py --project $n describe --readme-file <scratch README>
```

## 4. Post status

One status update. Its body is the Roadmap line from step 3. The state is `ON_TRACK` unless the PRD or the open batches say otherwise: `AT_RISK` when a Now item is blocked, `OFF_TRACK` when it is past its date.

```bash
FACTORY_GH="pantheon-gh board" python3 -I <hades>/scripts/factory-board.py --project $n status-update --file <scratch status> --state ON_TRACK|AT_RISK|OFF_TRACK
```

## 5. Report

One line per step: the slug and number, the README replaced (lines before and after), the status state and its line, each verb's exit code. A non-zero exit is reported as it is, never as done.
