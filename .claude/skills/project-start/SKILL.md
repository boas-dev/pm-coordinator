---
name: project-start
description: First skill run in a new project repo, by the operator. Defines the product into docs/product.md, checks the repo's credentials by name (present or missing, length only, never a value), creates the GitHub Project with first epics and milestones through the domain App, registers it with directr (directr/projects/<slug>.json and a first PRD) and runs /project-status. Installed by the project-init build's skills step.
allowed-tools: Bash, Write
---

# project-start — define the product, check credentials by name, create the Project

Run once, first, in the new repo. It never reads, prints or asks for a credential value. Names and counts only.

## 0. Dry run (`/project-start --dry-run <slug> <title>`)

A dry run prints the registration entry a slug would get and stops. It asks nothing, checks no credential, and creates no Project, repo file, issue, milestone or board:

```bash
python3 -I <skill-dir>/scripts/register.py <slug> --title "<title>" --dry-run --root <repo>
```

It prints `would write directr/projects/<slug>.json`, the entry in the shape of `directr/projects/planr.json` (with `id`, `number` and `url` null, since only `createProjectV2` sets them), the PRD path it would write and the slugs already registered. A slug that is not lowercase kebab, or one already registered, is refused (exit 1). Use it on a scratch name to prove the skill before a real run.

## 1. Define the product

Ask the operator in chat, one block at a time (never a modal: seat settings deny AskUserQuestion, #2526): problem, users, scope, first milestone. For a fresh start also ask what to bring over from elsewhere and what to remove there. Write the answers to `docs/product.md` with Write.

## 2. Check credentials by name

The names are listed in the repo's `AGENTS.md` under `## Seat` (`Credentials (names only, profile agent-<repo>)`). For each name, inside the seat:

```bash
name=EXAMPLE_NAME
[[ -n ${!name} ]] && echo present || echo MISSING
v=${!name}; echo ${#v}
```

- Presence is `[[ -n ${!name} ]]`. Length is `v=${!name}; echo ${#v}`: the number only. `${#name}` measures the name, not the value, so never use it.
- Never print the variable, list the environment, or read a keychain value.
- A missing name is a `/vault` deposit through Hades: file it on the Hades Vault Guard board (#6), never a value in chat.

Report a table: name, present or MISSING, length.

## 3. Create the GitHub Project

Through the domain App wrapper named in `AGENTS.md` (Hard rules), never a personal token:

1. Create the Project (`api graphql` `createProjectV2`) and link it to the repo.
2. Write `directr/projects/<slug>.json` with `python3 -I <skill-dir>/scripts/register.py <slug> --title "<title>" --id <PVT_…> --number <N> --url <url> --root <repo>`: the shape of `directr/projects/planr.json` less its `setup_run`, which directr adds (`name` the slug, `dir` set to `directr/projects/<slug>`, `project` with the new Project's `id`, `number`, `title` and `url`). It refuses a slug or a Project number that is already registered.
3. Write a first `directr/projects/<slug>/PRD.md` from `docs/product.md`: frontmatter `project: <number>` and `artifact: prd`; `## Vision` from the product's problem, users and scope; `## Roadmap` with a `Now:` line naming the first milestone; an empty `## Features` table (`| id | feature | status | version | operator words | issue |`); `## Not known`; and `## Revisions` as a table `| date | run | PR | change |` with one row: today, `project-start` as the run, `-` as the PR, `first PRD` (directr's menu shows the last row's run as "last revised by …"). directr files no run without a PRD.
4. Run `herdr-directr sync pull`, so directr, planr and Executr read the new Project.
5. File the first epics as issues in the repo, typed Feature, and add them to the Project. Each batch under an epic is its sub-issue, typed Task and labelled `batch`.
6. Set the main seat's focus epic: `git -C <main checkout> config pantheon.focus <first epic number>`. session-context and the operator panel read it; a main seat without it shows no epic (#4145).
7. Create the first milestones from the product's first milestone.
8. Run `/project-status <slug>`: it writes the Project's README from the PRD and posts its first status update.
9. Print the Project title and number, its registration file, and the focus epic.

### 3.1 The Project's shape

- The title follows `docs/reference/github-structure.md` `## Projects`: the product name only, and the slug is the repo or plugin name in lowercase kebab.
- The Project is created with #30's six Status columns: Backlog, Ready, In Progress, In Review, Blocked, Done.

## 4. Report

Comment the result (names, counts, pass/fail, never values) on the project definition issue.
