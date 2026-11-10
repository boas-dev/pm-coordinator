#!/usr/bin/env python3
"""project-start's directr registration entry (#6175): directr/projects/<slug>.json in the shape of planr.json.

  register.py <slug> --title <T> --dry-run [--root <repo>]
      print the entry this slug would get and the paths it would write; writes nothing and calls nothing.
  register.py <slug> --title <T> --id <PVT_…> --number <N> --url <https://…> [--root <repo>]
      write the entry after createProjectV2; refuses to overwrite a registered slug.

Exit: 0 printed or written · 1 refused (bad slug, slug taken, number taken) · 64 usage.
"""
import argparse
import json
import os
import re
import sys

SLUG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def registered(d):
    out = {}
    try:
        names = sorted(os.listdir(d))
    except OSError:
        return out
    for f in names:
        if not f.endswith(".json"):
            continue
        try:
            with open(os.path.join(d, f)) as h:
                p = (json.load(h) or {}).get("project")
        except (OSError, ValueError, AttributeError):
            continue
        if isinstance(p, dict) and isinstance(p.get("number"), int):
            out[f[:-5]] = p["number"]
    return out


def main(argv):
    a = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    a.add_argument("slug")
    a.add_argument("--title", required=True)
    a.add_argument("--dry-run", action="store_true")
    a.add_argument("--id")
    a.add_argument("--number", type=int)
    a.add_argument("--url")
    a.add_argument("--root", default=".")
    try:
        o = a.parse_args(argv)
    except SystemExit as e:
        return 64 if e.code else 0
    if not SLUG.match(o.slug):
        print("refused: slug %r is not lowercase kebab (docs/reference/github-structure.md ## Projects)" % o.slug, file=sys.stderr)
        return 1
    if not o.title.strip():
        print("refused: empty title", file=sys.stderr)
        return 1
    d = os.path.join(o.root, "directr", "projects")
    path = os.path.join(d, o.slug + ".json")
    reg = registered(d)
    if os.path.exists(path):
        print("refused: %s exists; %s is registered" % (os.path.relpath(path, o.root), o.slug), file=sys.stderr)
        return 1
    if o.dry_run:
        if o.id or o.number is not None or o.url:
            print("usage: --dry-run takes no --id, --number or --url (no Project is created)", file=sys.stderr)
            return 64
        proj = {"id": None, "number": None, "title": o.title, "url": None}
    else:
        if not (o.id and o.id.startswith("PVT_") and o.number and o.number > 0 and o.url and o.url.startswith("https://")):
            print("usage: a write needs --id PVT_…, --number N and --url https://… from createProjectV2 (or --dry-run)", file=sys.stderr)
            return 64
        taken = [s for s, n in reg.items() if n == o.number]
        if taken:
            print("refused: Project #%d is already registered as %s" % (o.number, taken[0]), file=sys.stderr)
            return 1
        proj = {"id": o.id, "number": o.number, "title": o.title, "url": o.url}
    entry = {"name": o.slug, "dir": "directr/projects/" + o.slug, "project": proj}
    text = json.dumps(entry, indent=1) + "\n"
    rel = os.path.relpath(path, o.root)
    if o.dry_run:
        print("dry run: would write %s (id, number and url come from createProjectV2, which a dry run does not call)" % rel)
        sys.stdout.write(text)
        print("dry run: would write directr/projects/%s/PRD.md; creates no Project, repo file, issue, milestone or board" % o.slug)
        print("dry run: registered now: %s" % (", ".join("%s #%d" % (s, n) for s, n in sorted(reg.items(), key=lambda x: x[1])) or "none"))
        return 0
    os.makedirs(d, exist_ok=True)
    with open(path, "x") as h:
        h.write(text)
    print("wrote %s" % rel)
    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
