import sys
import bpy
sys.path.insert(0, "tools/blender")
from ce3d import traffic3d as T
for name in ("suv", "van", "sports", "sedan", "hatch", "wagon"):
    d = T.traffic_design(name)
    for key in ("tail_lamps", "head_lamps", "body_decals", "bumper_decals", "cabin_decals"):
        lst = d.get(key, [])
        info = []
        for e in lst:
            polys = e["poly"] if isinstance(e["poly"][0][0], (list, tuple)) else [e["poly"]]
            info.append("%s:%s:%d" % (e.get("part", e.get("lamp", "?")), e.get("face", "rear")[:2], sum(len(p) for p in polys)))
        print(name, key, " ".join(info))
