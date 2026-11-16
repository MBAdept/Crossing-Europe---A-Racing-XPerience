"""AS5a1 scratch: fast export of models for looking at them (low bake quality by default). Writes into the real
cache folder of the model with the key "debug" (a normal export never takes it for current).
   /home/user/tools/bpyenv/bin/python probe.py <worktree> <model id>[,<model id>...] [--full] [--q=2]
--full: the real bake settings (only the key differs). --q=k: atlas / k (default 2).
Catalog entries come from ce3d.catalog3d (the worktree's own)."""
import os
import sys
import time

WT = sys.argv[1]
IDS = sys.argv[2].split(",")
FULL = "--full" in sys.argv
Q = 2
for a in sys.argv:
    if a.startswith("--q="):
        Q = int(a[4:])
sys.path.insert(0, os.path.join(WT, "tools", "blender"))
import bpy  # noqa: E402,F401

from ce3d import bake as BK  # noqa: E402
from ce3d import catalog3d  # noqa: E402

if not FULL:
    BK.SUPERSAMPLE = 1
    BK.SAMPLES = 4

import export_models as EM  # noqa: E402

for mid in IDS:
    spec = dict(catalog3d.MODELS[mid])
    if not FULL:
        a = spec.get("atlas", (1024, 1024))
        spec["atlas"] = (a[0] // Q, a[1] // Q)
        spec["ppm_max"] = spec.get("ppm_max", 128.0) / Q
        if spec.get("ao"):
            spec["ao"] = dict(spec["ao"], samples=6)
    t0 = time.time()
    model = EM.builder(spec["builder"])(mid, spec)
    meta = model.write(os.path.join(EM.CACHE, mid), "debug")
    lods = ", ".join("%s %d" % (l["name"], l["tris"]) for l in meta["model"]["lods"])
    print("DEBUG-EXPORT %-26s %6.1f s  %s  glb %.0f kB" % (mid, time.time() - t0, lods, meta["glb_bytes"] / 1024.0))
    st = dict(model.stats)
    bk = st.pop("bake", {})
    print("   stats:", st)
    print("   bake:", bk)
    print("   lights:", len(model.lights), [(l["role"], l["pos"]) for l in model.lights][:8])
    for lod in meta["model"]["lods"]:
        print("   ", lod["name"], lod["max_dist_m"], lod["tris"], [p["classes"] for p in lod["parts"]])
