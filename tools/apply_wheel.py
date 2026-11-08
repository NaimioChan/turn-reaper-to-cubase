#!/usr/bin/env python3
"""Write or remove the Cubase-style mousewheel bindings in REAPER's reaper-kb.ini.

Idempotent: re-running reports what already matched instead of duplicating lines.
No interactive prompts, machine-readable output with --json, safe to run while
REAPER is closed. REAPER rewrites this file on exit, so run it with REAPER closed
or it will be overwritten.

Usage:
    python apply_wheel.py                  # apply (detect resource path)
    python apply_wheel.py --dry-run        # show the plan, change nothing
    python apply_wheel.py --revert         # remove these bindings
    python apply_wheel.py --resource PATH  # explicit resource dir
    python apply_wheel.py --json           # machine-readable result
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import time

# KEY 255 <keycode> <action_id> <section>
# Section 0 = Main, 32060 = MIDI Editor.
# Trailing "\t\t # comment" is common; strip it before matching.
LINE_RE = re.compile(r"^KEY\s+255\s+(\d+)\s+(\d+)\s+(\d+)\s*$")


def parse_kb_line(line: str) -> tuple[int, int, int] | None:
    """Return (keycode, action_id, section) or None. Ignores trailing comments."""
    body = line.split("#", 1)[0].rstrip()
    match = LINE_RE.match(body)
    if not match:
        return None
    return int(match.group(1)), int(match.group(2)), int(match.group(3))

# keycode = 248 + modifier bits (ctrl=1, alt=2, shift=4), plus 9984 for the
# high form REAPER 7 writes. Both forms are accepted by REAPER; we write high.
WHEEL_BASE = 248
WHEEL_HIGH_OFFSET = 9984
CTRL, ALT, SHIFT = 1, 2, 4

# (label, modifier bits, action in Main, action in MIDI Editor)
BINDINGS = [
    ("ctrl+wheel",              CTRL,         990, 40431),  # zoom horizontally
    ("ctrl+shift+wheel",        CTRL | SHIFT, 991, 40430),  # zoom vertically
    ("shift+wheel",             SHIFT,        977, 40660),  # scroll horizontally (reversed)
    ("wheel",                   0,            989, 40432),  # scroll vertically
]

SECTIONS = {"Main": 0, "MIDI Editor": 32060}
SECTION_NAMES = {v: k for k, v in SECTIONS.items()}


def keycode(mod_bits: int) -> int:
    return WHEEL_BASE + mod_bits + WHEEL_HIGH_OFFSET


def detect_resource_path(explicit: str | None = None) -> str:
    """Locate REAPER's resource directory the way REAPER itself would."""
    if explicit:
        return os.path.abspath(os.path.expanduser(explicit))

    candidates = []
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA")
        if appdata:
            candidates.append(os.path.join(appdata, "REAPER"))
    elif sys.platform == "darwin":
        candidates.append(os.path.expanduser("~/Library/Application Support/REAPER"))
    else:
        config = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
        candidates.append(os.path.join(config, "REAPER"))

    for path in candidates:
        if os.path.isdir(path):
            return path

    raise SystemExit(
        "Could not find REAPER's resource directory. Pass --resource PATH.\n"
        "Inside REAPER: Options -> Show REAPER resource path in explorer/finder."
    )


def build_plan() -> list[dict]:
    plan = []
    for label, bits, action_main, action_midi in BINDINGS:
        for section_name, action in (("Main", action_main), ("MIDI Editor", action_midi)):
            plan.append(
                {
                    "label": label,
                    "section": SECTIONS[section_name],
                    "section_name": section_name,
                    "keycode": keycode(bits),
                    "action": action,
                }
            )
    return plan


def apply_plan(ini_path: str, plan: list[dict], dry_run: bool, revert: bool) -> dict:
    raw = ""
    if os.path.exists(ini_path):
        with open(ini_path, "rb") as fh:
            raw = fh.read().decode("utf-8", "replace")

    newline = "\r\n" if "\r\n" in raw else "\n"
    lines = raw.splitlines()

    targets = {(item["section"], item["keycode"]) for item in plan}
    kept: list[str] = []
    removed: list[str] = []
    for line in lines:
        parsed = parse_kb_line(line.strip())
        if parsed:
            keycode_seen, _, section_seen = parsed
            if (section_seen, keycode_seen) in targets:
                removed.append(line.strip())
                continue
        kept.append(line)

    added: list[str] = []
    if not revert:
        for item in plan:
            added.append(
                f'KEY 255 {item["keycode"]} {item["action"]} {item["section"]}'
                f'\t\t # {SECTION_NAMES[item["section"]]} : {item["label"]}'
            )
        kept.extend(added)

    body = newline.join(kept) + newline

    def norm(line: str) -> str:
        """Compare only KEY fields; ignore trailing comments and whitespace."""
        return " ".join(line.split("#", 1)[0].split())

    # Ordered comparison would flag a re-run as a change just because the new
    # lines land at the end of the file; REAPER does not care about order.
    unchanged = sorted(norm(l) for l in body.splitlines() if norm(l)) == \
                sorted(norm(l) for l in raw.splitlines() if norm(l))

    result = {
        "ini": ini_path,
        "dry_run": dry_run,
        "revert": revert,
        "removed": removed,
        "added": added,
        "changed": not unchanged,
    }

    if dry_run or unchanged:
        return result

    if os.path.exists(ini_path):
        backup = f"{ini_path}.bak-{time.strftime('%Y%m%d-%H%M%S')}"
        shutil.copyfile(ini_path, backup)
        result["backup"] = backup

    with open(ini_path, "wb") as fh:
        fh.write(body.encode("utf-8"))
    return result


def verify_plan(ini_path: str, plan: list[dict], expect_absent: bool = False) -> dict:
    """Read the file back and report which bindings are present (or absent)."""
    if not os.path.exists(ini_path):
        return {"ini": ini_path, "present": [], "missing": plan, "ok": False}

    with open(ini_path, "rb") as fh:
        text = fh.read().decode("utf-8", "replace")

    found: dict[tuple[int, int], int] = {}
    for line in text.splitlines():
        parsed = parse_kb_line(line.strip())
        if parsed:
            keycode_seen, action_seen, section_seen = parsed
            found[(section_seen, keycode_seen)] = action_seen

    present, missing = [], []
    for item in plan:
        actual = found.get((item["section"], item["keycode"]))
        record = {
            "label": item["label"],
            "section_name": item["section_name"],
            "keycode": item["keycode"],
            "expected_action": item["action"],
            "actual_action": actual,
        }
        matched = actual != item["action"] if expect_absent else actual == item["action"]
        (present if matched else missing).append(record)

    if expect_absent:
        return {"ini": ini_path, "absent": present, "still_present": missing, "ok": not missing}
    return {"ini": ini_path, "present": present, "missing": missing, "ok": not missing}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--resource", help="REAPER resource directory (auto-detected by default)")
    parser.add_argument("--dry-run", action="store_true", help="print the plan without writing")
    parser.add_argument("--revert", action="store_true", help="remove these bindings")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--verify-only", action="store_true", help="only check current state")
    args = parser.parse_args(argv)

    resource = detect_resource_path(args.resource)
    ini_path = os.path.join(resource, "reaper-kb.ini")
    plan = build_plan()

    if args.verify_only:
        result = verify_plan(ini_path, plan)
    else:
        result = apply_plan(ini_path, plan, args.dry_run, args.revert)
        result["verify"] = verify_plan(ini_path, plan, expect_absent=args.revert) if not args.dry_run else None

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0 if (result.get("verify") or {}).get("ok", True) else 1

    print(f"resource: {resource}")
    print(f"ini:      {ini_path}")

    if args.verify_only:
        ok = result["ok"]
        print(f"verify:   {'OK' if ok else 'MISSING ' + str(len(result['missing']))}")
        for item in result["present"]:
            print(f"  ok  {item['section_name']:12s} {item['label']}")
        for item in result["missing"]:
            print(f"  --  {item['section_name']:12s} {item['label']} (expected {item['expected_action']}, got {item['actual_action']})")
        return 0 if ok else 1

    if result.get("backup"):
        print(f"backup:   {result['backup']}")

    if args.dry_run:
        if not result.get("changed"):
            print("dry run: already up to date, nothing would change")
            return 0
        print("dry run: nothing written")
        for line in result["removed"]:
            print(f"  would remove: {line}")
        for line in result["added"]:
            print(f"  would add:    {line}")
        return 0

    if not result.get("changed"):
        print("already up to date, nothing written")
    else:
        print(f"removed {len(result['removed'])} stale line(s), added {len(result['added'])} line(s)")
    verify = result.get("verify") or {}
    verdict = "OK" if verify.get("ok") else "FAILED"
    print(f"verify:   {verdict}" + ("  (bindings absent as requested)" if args.revert and verify.get("ok") else ""))
    return 0 if verify.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
