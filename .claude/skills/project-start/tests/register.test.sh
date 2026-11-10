#!/usr/bin/env bash
# project-start register.py (#6175): the dry run prints the entry and writes nothing; a write refuses a taken slug or number.
set -u
here=$(cd "$(dirname "$0")" && pwd)
reg="$here/../scripts/register.py"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/directr/projects"
printf '{"name":"planr","dir":"directr/projects/planr","project":{"id":"PVT_x","number":43,"title":"planr","url":"https://github.com/orgs/boas-dev/projects/43"}}\n' > "$t/directr/projects/planr.json"
fails=0
ok() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails+1)); fi; }
before=$(find "$t" | sort)
out=$(python3 -I "$reg" scratch-proof --title "Scratch proof" --dry-run --root "$t"); rc=$?
ok "dry run exits 0" '[ $rc -eq 0 ]'
ok "dry run prints the entry path" 'grep -q "would write directr/projects/scratch-proof.json" <<<"$out"'
ok "dry run prints the entry" 'grep -q "\"name\": \"scratch-proof\"" <<<"$out" && grep -q "\"title\": \"Scratch proof\"" <<<"$out" && grep -q "\"dir\": \"directr/projects/scratch-proof\"" <<<"$out"'
ok "dry run names what is registered" 'grep -q "registered now: planr #43" <<<"$out"'
ok "dry run writes nothing" '[ "$(find "$t" | sort)" = "$before" ]'
python3 -I "$reg" planr --title planr --dry-run --root "$t" >/dev/null 2>&1; rc=$?
ok "dry run on a registered slug is refused" '[ $rc -eq 1 ]'
python3 -I "$reg" Bad_Slug --title x --dry-run --root "$t" >/dev/null 2>&1; rc=$?
ok "a non-kebab slug is refused" '[ $rc -eq 1 ]'
python3 -I "$reg" s --title x --dry-run --number 5 --root "$t" >/dev/null 2>&1; rc=$?
ok "dry run with --number is usage" '[ $rc -eq 64 ]'
python3 -I "$reg" s --title x --root "$t" >/dev/null 2>&1; rc=$?
ok "a write without the Project's id is usage" '[ $rc -eq 64 ]'
python3 -I "$reg" other --title other --id PVT_y --number 43 --url https://github.com/orgs/boas-dev/projects/43 --root "$t" >/dev/null 2>&1; rc=$?
ok "a write of a registered number is refused" '[ $rc -eq 1 ] && [ ! -e "$t/directr/projects/other.json" ]'
python3 -I "$reg" newp --title "New P" --id PVT_z --number 60 --url https://github.com/orgs/boas-dev/projects/60 --root "$t" >/dev/null; rc=$?
ok "a write lands in the planr.json shape" '[ $rc -eq 0 ] && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));assert d==dict(name=\"newp\",dir=\"directr/projects/newp\",project=dict(id=\"PVT_z\",number=60,title=\"New P\",url=\"https://github.com/orgs/boas-dev/projects/60\"))" "$t/directr/projects/newp.json"'
[ $fails -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
