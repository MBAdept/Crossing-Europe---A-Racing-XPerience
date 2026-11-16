"""AS4 scratch: triangles per object of a sprite set's generator build (with modifiers).
   /home/user/tools/bpyenv/bin/python objtris.py <worktree> <set id> [params json]"""
import json
import os
import sys

WT = sys.argv[1]
SID = sys.argv[2]
sys.path.insert(0, os.path.join(WT, "tools", "blender"))
import bpy  # noqa: E402,F401

from ce3d import core  # noqa: E402
from ce3d import props3d as P  # noqa: E402

spec = dict(source=SID)
if len(sys.argv) > 3:
    spec["params"] = json.loads(sys.argv[3])
rig, info, sspec = P._build_source(spec)
objs = P._objects(rig)
tot = 0
rows = []
for s in core.soups_of(objs):
    rows.append((s.n, s.name, [m.name for m in s.mats]))
    tot += s.n
for n, name, mats in sorted(rows, reverse=True):
    print("%6d  %-28s %s" % (n, name, ",".join(mats)[:80]))
print("TOTAL", tot, info.get("object"))
