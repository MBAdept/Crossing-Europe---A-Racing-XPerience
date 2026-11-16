"""AS5a1 scratch: models whose cache key (code, catalog entry, sprite data) differs from the key of their last export.
   /home/user/tools/bpyenv/bin/python stale.py <worktree>"""
import json
import os
import sys

WT = sys.argv[1]
sys.path.insert(0, os.path.join(WT, "tools", "blender"))
import bpy  # noqa: E402,F401

from ce3d import catalog3d  # noqa: E402

stale = []
for mid in catalog3d.model_ids():
    meta = os.path.join(WT, "tools", "blender", "_cache3d", mid, "model_meta.json")
    have = json.load(open(meta)).get("key") if os.path.exists(meta) else None
    want = catalog3d.cache_key(mid)
    if have != want:
        stale.append((mid, have, want))
for mid, have, want in stale:
    print("VERALTET %-34s Cache %s  jetzt %s" % (mid, have, want))
print("%d von %d Modellen veraltet" % (len(stale), len(catalog3d.model_ids())))
