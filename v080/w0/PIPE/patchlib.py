"""Tiny exact-replacement helper for the hook patches (scratch tool, not part of the repository)."""
import os
import sys

ROOT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-2"


def patch(rel, pairs):
    path = os.path.join(ROOT, rel)
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    for old, new in pairs:
        n = text.count(old)
        if n != 1:
            print("FEHLER %s: %d Treffer fuer:\n%s" % (rel, n, old[:200]))
            sys.exit(1)
        text = text.replace(old, new)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    print("ok", rel, len(pairs))
