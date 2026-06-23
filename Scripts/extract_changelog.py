#!/usr/bin/env python3
"""Extract release notes for a given tag from CHANGELOG.md.

Usage: extract_changelog.py vX.Y.Z

Prints a descriptive release body (the matching CHANGELOG section) followed by
a single "Full Changelog" compare link to the previous tag. Used by the release
workflow so GitHub Releases are descriptive instead of a bare list of commits.
"""
import re
import subprocess
import sys

REPO = "kxdrsrt/conduct-app"


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: extract_changelog.py <tag>", file=sys.stderr)
        return 2
    tag = sys.argv[1]
    version = tag.lstrip("v")

    try:
        text = open("CHANGELOG.md", encoding="utf-8").read()
    except FileNotFoundError:
        text = ""

    pat = re.compile(
        r"^##\s*\[?" + re.escape(version) + r"\]?[^\n]*\n(.*?)(?=^##\s|\Z)",
        re.M | re.S,
    )
    m = pat.search(text)
    notes = m.group(1).strip() if m else "_See the commit history for details._"

    # Determine the previous tag (semver-descending), excluding the current one.
    tags = subprocess.run(
        ["git", "tag", "--sort=-v:refname"],
        capture_output=True, text=True,
    ).stdout.split()
    prev = None
    if tag in tags:
        i = tags.index(tag)
        if i + 1 < len(tags):
            prev = tags[i + 1]

    out = [f"## Conduct {tag}", "", notes]
    if prev:
        out += [
            "",
            f"**Full Changelog**: https://github.com/{REPO}/compare/{prev}...{tag}",
        ]
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
