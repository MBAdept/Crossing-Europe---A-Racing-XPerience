#!/usr/bin/env python3
"""Integration helper (not part of the repository): which keys of config/game_config.json differ between two
versions of the file. Usage: cfg_diff.py <old.json> <new.json>"""
import json
import sys


def walk(a, b, path, out):
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a:
                out.append("+ " + ".".join(path + [k]))
            elif k not in b:
                out.append("- " + ".".join(path + [k]))
            else:
                walk(a[k], b[k], path + [k], out)
    elif a != b:
        out.append("~ " + ".".join(path))


old = json.load(open(sys.argv[1], encoding="utf-8"))
new = json.load(open(sys.argv[2], encoding="utf-8"))
res = []
walk(old, new, [], res)
print("\n".join(res) if res else "keine Unterschiede")
