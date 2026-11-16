"""AS4 scratch: fast export of models for looking at the geometry (low bake quality). Writes into the real cache
folder of the model but with the key "debug" - a normal export never takes it for current.
   /home/user/tools/bpyenv/bin/python dbg_build.py <worktree> <model id>[,<model id>...] [--full]
--full: the real bake settings (only the key differs)."""
import os
import sys
import time

WT = sys.argv[1]
IDS = sys.argv[2].split(",")
FULL = "--full" in sys.argv
sys.path.insert(0, os.path.join(WT, "tools", "blender"))
import bpy  # noqa: E402,F401

from ce3d import bake as BK  # noqa: E402
from ce3d import catalog3d  # noqa: E402

if not FULL:
    BK.SUPERSAMPLE = 1
    BK.SAMPLES = 4
    _orig = BK.bake_atlas

    def fast(rig, objs, mats, size, weight_fn=None, ppm_max=512.0, layers=("lights",), cutout=False, supersample=2,
             samples=16, ao=None):
        k = 2
        size2 = (max(64, size[0] // k), max(64, size[1] // k))
        if ao:
            ao = dict(ao, samples=6)
        return _orig(rig, objs, mats, size2, weight_fn, ppm_max / k, layers, cutout, 1, 4, ao)
    BK.bake_atlas = fast

import export_models as EM  # noqa: E402

for mid in IDS:
    spec = dict(catalog3d.MODELS[mid])
    if not FULL and spec["builder"] == "house":
        a = spec.get("atlas", (1024, 1024))
        spec["atlas"] = (a[0] // 2, a[1] // 2)
        spec["ppm_max"] = spec.get("ppm_max", 128.0) / 2
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
    print("   lights:", len(model.lights), [(l["role"], l["pos"]) for l in model.lights][:6])
    for lod in meta["model"]["lods"]:
        print("   ", lod["name"], lod["max_dist_m"], lod["tris"], [p["classes"] for p in lod["parts"]])
