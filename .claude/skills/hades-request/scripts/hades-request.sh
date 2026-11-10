#!/usr/bin/env bash
# hades-request.sh KIND "<consumer>" "<symptom>" [NAME] [<pane>] — hand any Hades ask to Hades (#5963, seat-requests B1 #6021).
# Every kind opens one tracked task in boas-dev/constellation-hades (scripts/task-open.sh) as the record:
#   credential|env|permission -> Owner: vault lane. A missing, wrong, expired or to-be-minted credential, an env var's value
#     or source (NAME required), a seat setting, permission mode, deny rule or a branch-protection/ruleset fact. The vault
#     lane is the one ${PLANR_LANES:-~/.local/state/pantheon/lanes}/*-vault-lane.lane.json record (fast false, repo = the
#     Hades checkout's basename); its worktree is <hades main>/.worktrees/<slug>, its pane the herdr agent with that cwd.
#   app|guard|seat -> Owner: hades main. A GitHub App permission, a guard or sandbox block, a CLI or config the seat lacks;
#     the pane is the herdr agent whose cwd is the Hades main checkout.
# The owner Replies with hades-reply.sh, which closes the task (or leaves it open until the value lands).
# hades-request.sh landed <task#> <NAME> — the requesting seat, after its relaunch, compares its own NAME with the Reply's
#   `landed:` fingerprint inside one python3 -I process and prints only `match` or `mismatch: <reason>`; a match closes the task.
# Never takes a value: NAME is a variable name, and 32+ character token-like runs in consumer/symptom are refused.
# Every GitHub call goes through scripts/ghapp-purpose.sh, from the Hades main checkout.
# Overrides for tests: HADES_REQUEST_GH (wrapper command), HADES_REQUEST_HERDR, PANTHEON_HADES_ROOT, PLANR_LANES.
set -uo pipefail
usage() { echo 'usage: hades-request.sh credential|env|permission|app|guard|seat "<consumer>" "<symptom>" [NAME] [<pane>]' >&2
  echo '       hades-request.sh landed <task#> <NAME>' >&2; exit 2; }
repo=boas-dev/constellation-hades
here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hades="${PANTHEON_HADES_ROOT:-@HADES_ROOT@}"
[[ -f "$hades/scripts/task-open.sh" ]] || hades="$(cd -P "$here/../../../../.." && pwd)"
hades_main="$(git -C "$hades" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; hades_main="${hades_main%/.git}"
[[ -n "$hades_main" && -f "$hades_main/scripts/task-open.sh" ]] || { echo "hades-request: no Hades checkout with scripts/task-open.sh" >&2; exit 2; }
gh="${HADES_REQUEST_GH:-bash $hades_main/scripts/ghapp-purpose.sh}"
ghc() { (cd "$hades_main" && $gh "$@"); }  # word-split on purpose: the wrapper is a command line, as TASK_OPEN_GH

# --- landed: the requesting seat's in-process check of the value it now holds ---
if [[ "${1:-}" == landed ]]; then
  [[ $# -eq 3 && "$2" =~ ^[0-9]+$ && "$3" =~ ^[A-Z][A-Z0-9_]{1,80}$ ]] || { echo 'usage: hades-request.sh landed <task#> <NAME>' >&2; exit 2; }
  n="$2"; name="$3"
  comments="$(ghc issue view "$n" --repo "$repo" --json comments)" || { echo "hades-request: reading #$n failed" >&2; exit 2; }
  expect="$(python3 -I -c 'import json, re, sys
name = sys.argv[1]
try: cs = json.loads(sys.stdin.read()).get("comments") or []
except Exception: cs = []
pat = re.compile(r"^landed: " + re.escape(name) + r" prefix6:(\S{6}) last4:(\S{4}) len:([0-9]+)\s*$", re.M)
hit = ""
for c in cs:  # only a Reply comment (hades-reply.sh) carries the fingerprint
    b = c.get("body") or ""
    if not b.startswith("Reply: "): continue
    for m in pat.finditer(b):
        hit = m.group(0).strip()
print(hit)' "$name" <<<"$comments")"
  [[ -n "$expect" ]] || { echo "hades-request: #$n has no 'landed: $name prefix6:… last4:… len:…' Reply" >&2; exit 2; }
  # The value is read from this process's own environment inside Python, and only the verdict leaves it.
  verdict="$(python3 -I -c 'import os, re, sys
line, name = sys.argv[1], sys.argv[2]
m = re.match(r"landed: \S+ prefix6:(\S{6}) last4:(\S{4}) len:([0-9]+)$", line)
v = os.environ.get(name)
if not m: print("mismatch: no fingerprint")
elif v is None or v == "": print(f"mismatch: {name} unset")
elif len(v) != int(m.group(3)): print("mismatch: len differs")
elif v[:6] != m.group(1): print("mismatch: prefix differs")
elif v[-4:] != m.group(2): print("mismatch: suffix differs")
else: print("match")' "$expect" "$name")"
  [[ "$verdict" == match || "$verdict" == mismatch:* ]] || { echo "hades-request: the compare failed" >&2; exit 2; }
  echo "$verdict"
  body="$(mktemp "${TMPDIR:-/tmp}/hades-landed-XXXXXX")" || exit 2
  trap 'rm -f "$body"' EXIT
  if [[ "$verdict" == match ]]; then printf 'landed: %s match\n' "$name" >"$body"
  else printf 'landed: %s %s\n' "$name" "$verdict" >"$body"; fi
  ghc issue comment "$n" --repo "$repo" --body-file "$body" >/dev/null || { echo "hades-request: the comment on #$n failed" >&2; exit 2; }
  if [[ "$verdict" == match ]]; then
    ghc issue close "$n" --repo "$repo" --reason completed >/dev/null || { echo "hades-request: closing #$n failed" >&2; exit 2; }
    echo "hades-request: #$n closed"
  else echo "hades-request: #$n stays open; the vault lane reads the mismatch"; fi
  exit 0
fi

# --- a request ---
[[ $# -ge 3 && $# -le 5 ]] || usage
kind="$1"; name=""; pane=""
case "$kind" in credential|env|permission) owner="vault lane" ;; app|guard|seat) owner="hades main" ;; *) usage ;; esac
# The 4th argument is NAME when it looks like a variable name, else the pane.
if [[ $# -ge 4 ]]; then
  if [[ "$4" =~ ^[A-Z][A-Z0-9_]{1,80}$ ]]; then name="$4"; pane="${5:-}"
  elif [[ $# -eq 4 ]]; then pane="$4"
  else echo "hades-request: NAME must be an upper-case variable name, never a value" >&2; exit 2; fi
fi
case "$kind" in credential|env)
  [[ -n "$name" ]] || { echo "hades-request: $kind needs the variable NAME (never its value)" >&2; exit 2; } ;;
esac
pane="${pane:-${HERDR_PANE_ID:-}}"
[[ -z "$pane" || "$pane" =~ ^[A-Za-z0-9][A-Za-z0-9:_@-]{0,59}$ ]] || { echo "hades-request: bad pane id" >&2; exit 2; }

flat() { python3 -I -c 'import re,sys
q = re.sub(r"[\x00-\x1f\x7f]", lambda m: " " if m.group() in "\r\n\t" else "", sys.argv[1])
print(re.sub(r" +", " ", q).strip()[:200].rstrip())' "$1"; }
consumer="$(flat "$2")"; symptom="$(flat "$3")"
[[ -n "$consumer" && -n "$symptom" ]] || { echo "hades-request: consumer and symptom are required" >&2; exit 2; }
if grep -Eq '[A-Za-z0-9_+/=-]{32,}' <<<"$consumer $symptom"; then
  echo "hades-request: consumer/symptom hold a 32+ character token-like run; values never go in a request" >&2; exit 2; fi

wt="$(git rev-parse --show-toplevel 2>/dev/null)" || wt="$PWD"
from="$(git -C "$wt" remote get-url origin 2>/dev/null | sed -nE 's#.*github\.com[:/]([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$#\1#p' | sed 's/\.git$//')"
br="$(git -C "$wt" branch --show-current 2>/dev/null)"

if [[ "$owner" == "vault lane" ]]; then
  if [[ -n "$name" ]]; then done_when="the vault lane has replied and the value landed in the requesting seat ($name)"
  else done_when="the vault lane has fixed or refused: $symptom, and replied to the requester"; fi
else done_when="Hades main has fixed or refused: $symptom, and replied to the requester"; fi

body="$(mktemp "${TMPDIR:-/tmp}/hades-request-XXXXXX")" || exit 2
trap 'rm -f "$body"' EXIT
{ printf 'Hades request: %s | consumer: %s | symptom: %s%s\n' "$kind" "$consumer" "$symptom" "${name:+ | name: $name}"
  printf 'From: %s%s\n' "${from:-$wt}" "${br:+ ($br)}"
  [[ -z "$pane" ]] || printf 'Pane: %s\n' "$pane"
  printf '\nThe %s fixes it (or refuses it) and Replies with `hades-reply.sh <this task> done|deposited|refused:<why>` (a deposit adds `--landed <NAME> --fp prefix6:… last4:… len:N --relaunch needed|not-needed`). With a relaunch needed, the requesting seat runs `hades-request.sh landed <this task> <NAME>` once it has relaunched. The requesting seat never hands the operator commands or options for it.\n' "$owner"
} >"$body"
n="$(cd "$hades_main" && TASK_OPEN_GH="$gh" bash scripts/task-open.sh --repo "$repo" \
  --title "Hades request: $kind — $consumer${name:+ ($name)}" --done-when "$done_when" \
  --owner "$owner" --body-file "$body" | tail -1)"
[[ "$n" =~ ^[0-9]+$ ]] || { echo "hades-request: opening the task failed; nothing was forwarded" >&2; exit 2; }
url="https://github.com/$repo/issues/$n"
echo "hades-request: recorded as $url"

herdr="${HADES_REQUEST_HERDR:-herdr}"
command -v "$herdr" >/dev/null 2>&1 || { echo "hades-request: no herdr; the $owner reads the task" >&2; exit 0; }
list="$("$herdr" agent list 2>/dev/null)"
find_pane() { python3 -I -c 'import json,sys
try: a = json.loads(sys.argv[2])["result"]["agents"]
except Exception: a = []
print(next((x["pane_id"] for x in a if x.get("cwd") == sys.argv[1]), ""))' "$1" "$list"; }
main_pane="$(find_pane "$hades_main")"
prompt() {  # prompt <pane> <who> <line>: one line into a pane; a failure is said, the task stands
  "$herdr" agent prompt "$1" "$3" >/dev/null 2>&1 || { echo "hades-request: herdr agent prompt to $1 failed; the task stands" >&2; return 1; }
  echo "hades-request: forwarded to $2 ($1)"; }
to_main() {  # to_main <line>
  [[ -n "$main_pane" ]] || { echo "hades-request: no Hades main pane; the task stands and the task monitor nudges it" >&2; return 0; }
  prompt "$main_pane" "Hades main" "$1"; }
reply="reply with hades-reply.sh $n done|deposited|refused:<why>${name:+ [--landed $name --fp prefix6:… last4:… len:N --relaunch needed|not-needed]}"
line="hades request #$n $kind: $consumer${name:+ ($name)} — $url${pane:+ (requester pane: $pane)}; $reply"

if [[ "$owner" == "hades main" ]]; then to_main "$line"; exit 0; fi

# The vault lane: found by its lane record only (a topic branch carries no git config, #6006).
slugs="$(python3 -I -c 'import glob, json, os, sys
d, repo = sys.argv[1], sys.argv[2]
out = []
for p in sorted(glob.glob(os.path.join(d, "*-vault-lane.lane.json"))):
    try: r = json.load(open(p))
    except Exception: continue
    if r.get("fast") is False and r.get("repo") == repo and r.get("slug"):
        out.append(r["slug"])
print("\n".join(out))' "${PLANR_LANES:-$HOME/.local/state/pantheon/lanes}" "$(basename "$hades_main")")"
count="$(grep -c . <<<"$slugs")"
if [[ "$count" -ge 2 ]]; then
  two="$(head -2 <<<"$slugs" | paste -sd, - | sed 's/,/, /')"
  msg="hades-request: two vault lane records: $two; close one with bin/lane-close"
  echo "$msg" >&2; to_main "$msg (vault request #$n waits: $url)"; exit 0
fi
slug="${slugs:-}"
target=""; [[ -z "$slug" ]] || target="$(find_pane "$hades_main/.worktrees/$slug")"
if [[ -z "$target" ]]; then
  echo "hades-request: no vault lane pane${slug:+ for $slug}; Hades main gets the resume line" >&2
  to_main "vault request #$n waits: no vault lane pane; bin/lane ${slug:-sonnet-vault-lane} --resume — $url"; exit 0
fi
prompt "$target" "vault lane" "$line"
exit 0
