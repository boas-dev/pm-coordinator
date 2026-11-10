---
name: hades-request
description: Any session. Hand any ask that is Hades's to Hades - a missing or wrong credential, an env var's value or source, a GitHub App permission, a guard or sandbox block, a seat permission, a CLI or config the seat lacks, a token to mint. Every kind opens one tracked task: credential, env and permission asks are owned by the standing vault lane, app, guard and seat asks by Hades main, and the owner's pane gets one line. The owner Replies with hades-reply.sh; after a relaunch the seat runs `landed` to confirm the value arrived. Takes the symptom, never a value. Use instead of grepping env or config files, retrying a blocked read, or handing the operator commands or options. Keywords: hades request, config token, mint a token, missing cli, permission request, credential request, env var, env injection, app permission, guard block, vault guard blocked, missing credential, wrong credential.
allowed-tools: Bash
---

# Hades request

Permission, credential, env-injection and GitHub App asks are Hades's. Run from any session, resolving the script relative to this `SKILL.md`:

```bash
bash <skill-dir>/scripts/hades-request.sh <kind> "<consumer>" "<symptom>" [<NAME>] [<requester-pane>]
```

| kind | when | goes to |
|---|---|---|
| `credential` | a credential is missing, wrong or expired, or must be minted or rotated, even one only the operator can mint (a Slack config token): Hades checks the vault first and asks him itself if it must | the vault lane |
| `env` | an env var's value or source is wrong or unknown (what injects it, which seat has it) | the vault lane |
| `app` | a GitHub App lacks a permission, an installation or a repo | Hades main |
| `guard` | the vault guard or a sandbox blocked a step you need | Hades main |
| `permission` | a seat setting, permission mode or deny rule stops you, or you need a branch-protection or ruleset fact | the vault lane, which checks the premise first |
| `seat` | the seat lacks a CLI, its config or its wiring (no Slack CLI, no MCP entry) | Hades main |

- **`<consumer>`** is what reads it or what is blocked (`apollo main seat .mcp.json penpot entry`). **`<symptom>`** is what you see, in plain words (`PENPOT_MCP_URL points at the public cloud, MCP calls reach no plugin`). **`<NAME>`** is the variable name, required for `credential` and `env`. The pane defaults to `$HERDR_PANE_ID`.
- **Values never go in a request.** NAME is validated and 32+ character token-like runs in consumer/symptom are refused; shorter values are not caught, so never type one.
- **Do not hunt for it yourself.** Never grep `.envrc`, `.mcp.json`, shell rc files or the environment for a credential's name or value, and never retry a read the guard blocked: one block is the signal to file this request (two in a row is a hard stop).
- **Never hand the operator commands or options for it, and never ask him for the credential.** No `! <command>` for him to run, no 1/2/3 choice, no "please mint a token" message or push. Hades owns the fix; the operator is reached, when he must be, by Hades.

Two cases this replaces (#5963): a Penpot seat grepped `.mcp.json`, `.envrc` and shell rc for `PENPOT_MCP_*`, was blocked twice and handed the operator `!` commands (now `hades-request env "apollo .mcp.json penpot entry" "…" PENPOT_MCP_URL`); Metis asked the operator over Slack for a Slack config token and the Slack CLI (#5965; now `hades-request credential "metis seat apps.manifest.update" "no Slack config token pair" SLACK_CONFIG_TOKEN` and `hades-request seat "metis seat" "no Slack CLI"`).

What it does:
1. Opens one tracked task in `boas-dev/constellation-hades` (label `task`) holding `Hades request: <kind> | consumer: … | symptom: …` (`| name: <NAME>` when given), where it came from and a `Pane:` line. This is the record, for every kind. `Owner: vault lane` for `credential`, `env` and `permission`; `Owner: hades main` for `app`, `guard` and `seat`. A request that carries NAME is done when the vault lane has replied and the value landed in your seat.
2. Sends the owner's pane one line with the task link and the Reply tool: `reply with hades-reply.sh <N> …`. The vault lane is the one `*-vault-lane.lane.json` lane record (not fast, repo `constellation-hades`); its pane is the herdr agent whose cwd is `<hades main>/.worktrees/<slug>`. With no record or no pane, Hades main gets `vault request #N waits: no vault lane pane; bin/lane <slug> --resume`; with two records, the error names both and Hades main gets it too. Hades main's pane is the herdr agent whose cwd is the Hades main checkout. Every post goes through `scripts/ghapp-purpose.sh`.
3. The owner Replies with `scripts/hades-reply.sh <N> done|deposited|refused:<why> [--landed <NAME> --fp prefix6:… last4:… len:N] [--relaunch needed|not-needed]`: one `Reply:` comment, one `herdr-send <your pane> … --type Reply`, and the task closed unless a relaunch is needed (rule 22). `--fp` is refused for a value under 16 characters.
4. **After your own relaunch, run `landed`:** `bash <skill-dir>/scripts/hades-request.sh landed <N> <NAME>`. It compares your environment's NAME with the Reply's fingerprint inside one process and prints only `match` (posts it and closes the task) or `mismatch: <NAME unset|len differs|prefix differs|suffix differs>` (posts it, the task stays open). It never prints or passes the value. You pick the moment to relaunch; nobody relaunches you.
5. You keep working on whatever the request does not block. If nothing else is left, end on `blocked #<your issue> waiting on <request url>`.

Exit 0 recorded (a missing herdr, pane or failed prompt is said on stderr, the record stands) · 2 usage, refused input, or the record failed.
