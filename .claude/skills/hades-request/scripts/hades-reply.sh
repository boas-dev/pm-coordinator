#!/usr/bin/env bash
# hades-reply.sh <task#> done|deposited|refused:<why> [--landed <NAME> --fp prefix6:<p> last4:<l> len:<n>] [--relaunch needed|not-needed]
# The owner of a hades-request task (the vault lane or Hades main) Replies (seat-requests B1.3, #6027; rule 22):
#   1. reads the task body's `Pane:` line, 2. posts one `Reply: <status>` comment (with `landed: <NAME> prefix6:… last4:… len:…`
#   and `relaunch: …` when given), 3. sends `herdr-send <pane> "<status> — <url>[; relaunch needed, then run hades-request
#   landed <N> <NAME>]" --type Reply`, 4. closes the task as completed unless --relaunch needed (the requesting seat's
#   `hades-request.sh landed` closes it then). With no herdr-send or no Pane: line it still posts and closes, and says so.
# Never a value: --fp carries only prefix6, last4 and len (rule 04), and a 32+ character token-like run is refused.
# Every GitHub call goes through scripts/ghapp-purpose.sh. Overrides for tests: HADES_REQUEST_GH, HADES_REPLY_HERDR_SEND,
# PANTHEON_HADES_ROOT.
set -uo pipefail
usage() { echo 'usage: hades-reply.sh <task#> done|deposited|refused:<why> [--landed <NAME> --fp prefix6:<p> last4:<l> len:<n>] [--relaunch needed|not-needed]' >&2; exit 2; }
repo=boas-dev/constellation-hades
[[ $# -ge 2 ]] || usage
n="$1"; status="$2"; shift 2
[[ "$n" =~ ^[0-9]+$ ]] || { echo "hades-reply: the task number must be digits" >&2; exit 2; }
[[ "$status" =~ ^(done|deposited|refused:.+)$ ]] || { echo "hades-reply: status is done, deposited or refused:<why>" >&2; exit 2; }
landed=""; fp=(); relaunch=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --landed) landed="${2:-}"; shift 2 || usage ;;
    --fp) [[ $# -ge 4 ]] || usage; fp=("$2" "$3" "$4"); shift 4 ;;
    --relaunch) relaunch="${2:-}"; shift 2 || usage ;;
    *) usage ;;
  esac
done
status="$(python3 -I -c 'import re,sys
q = re.sub(r"[\x00-\x1f\x7f]", " ", sys.argv[1])
print(re.sub(r" +", " ", q).strip()[:200].rstrip())' "$status")"
if grep -Eq '[A-Za-z0-9_+/=-]{32,}' <<<"$status"; then
  echo "hades-reply: the status holds a 32+ character token-like run; values never go in a Reply" >&2; exit 2; fi
[[ -z "$relaunch" || "$relaunch" =~ ^(needed|not-needed)$ ]] || { echo "hades-reply: --relaunch is needed or not-needed" >&2; exit 2; }
if [[ -n "$landed" || ${#fp[@]} -gt 0 ]]; then
  [[ "$landed" =~ ^[A-Z][A-Z0-9_]{1,80}$ ]] || { echo "hades-reply: --landed takes the variable NAME" >&2; exit 2; }
  [[ ${#fp[@]} -eq 3 && "${fp[0]}" =~ ^prefix6:[^[:space:]]{6}$ && "${fp[1]}" =~ ^last4:[^[:space:]]{4}$ && "${fp[2]}" =~ ^len:[0-9]+$ ]] \
    || { echo "hades-reply: --landed needs --fp prefix6:<6 chars> last4:<4 chars> len:<digits>" >&2; exit 2; }
  # prefix6 + last4 of a short value is most or all of it: never post a fingerprint below 16 characters (rule 04).
  [[ "${fp[2]#len:}" -ge 16 ]] || { echo "hades-reply: len under 16: prefix6+last4 would disclose the value; Reply without --landed and verify another way" >&2; exit 2; }
fi
[[ "$relaunch" != needed || -n "$landed" ]] || { echo "hades-reply: --relaunch needed needs --landed <NAME> --fp …, so the seat can run landed" >&2; exit 2; }

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hades="${PANTHEON_HADES_ROOT:-@HADES_ROOT@}"
[[ -f "$hades/scripts/task-open.sh" ]] || hades="$(cd -P "$here/../../../../.." && pwd)"
hades_main="$(git -C "$hades" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; hades_main="${hades_main%/.git}"
[[ -n "$hades_main" && -d "$hades_main" ]] || { echo "hades-reply: no Hades checkout" >&2; exit 2; }
gh="${HADES_REQUEST_GH:-bash $hades_main/scripts/ghapp-purpose.sh}"
ghc() { (cd "$hades_main" && $gh "$@"); }  # word-split on purpose: the wrapper is a command line

# A failed read is not "no Pane: line": stop before anything is posted or closed.
view="$(ghc issue view "$n" --repo "$repo" --json body)" || { echo "hades-reply: reading #$n failed; nothing was posted" >&2; exit 2; }
pane="$(python3 -I -c 'import json, re, sys
try: b = json.loads(sys.stdin.read()).get("body") or ""
except Exception: sys.exit(1)
m = re.search(r"^Pane: ([A-Za-z0-9][A-Za-z0-9:_@-]{0,59})\s*$", b, re.M)
print(m.group(1) if m else "")' <<<"$view")" || { echo "hades-reply: #$n body unreadable; nothing was posted" >&2; exit 2; }
url="https://github.com/$repo/issues/$n"

body="$(mktemp "${TMPDIR:-/tmp}/hades-reply-XXXXXX")" || exit 2
trap 'rm -f "$body"' EXIT
{ printf 'Reply: %s\n' "$status"
  [[ -z "$landed" ]] || printf 'landed: %s %s %s %s\n' "$landed" "${fp[@]}"
  [[ -z "$relaunch" ]] || printf 'relaunch: %s\n' "$relaunch"
} >"$body"
ghc issue comment "$n" --repo "$repo" --body-file "$body" >/dev/null || { echo "hades-reply: the comment on #$n failed; nothing was sent or closed" >&2; exit 2; }
echo "hades-reply: posted on $url"

msg="$status — $url"
[[ "$relaunch" != needed ]] || msg+="; relaunch needed, then run hades-request landed $n $landed"
send="${HADES_REPLY_HERDR_SEND:-herdr-send}"
if [[ -z "$pane" ]]; then echo "hades-reply: #$n has no Pane: line; the Reply is the comment only" >&2
elif ! command -v "$send" >/dev/null 2>&1; then echo "hades-reply: no herdr-send; the Reply is the comment only" >&2
elif "$send" "$pane" "$msg" --type Reply --issue "$n" >/dev/null 2>&1; then echo "hades-reply: Reply sent to $pane"
else rc=$?
  if [[ $rc -eq 3 ]]; then echo "hades-reply: NOT ACTED/NOT DELIVERED (exit 3) at $pane: send a clearer step or escalate (rule 22); the comment stands" >&2
  else echo "hades-reply: herdr-send to $pane exited $rc; the comment stands" >&2; fi
fi

if [[ "$relaunch" == needed ]]; then echo "hades-reply: #$n stays open until the seat runs landed"; exit 0; fi
ghc issue close "$n" --repo "$repo" --reason completed >/dev/null || { echo "hades-reply: closing #$n failed" >&2; exit 2; }
echo "hades-reply: #$n closed"
