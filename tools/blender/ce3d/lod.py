"""Levels of detail of the real-time models (contract D21).

LODs are never made by decimating a finished model: every level is its own generator build with coarser
detail parameters (the "detail" hooks of cesprites.carbody / cardetail / vehicles; their defaults give the
sprite model). The tables below are those parameters per level; the builders in vehicles3d use them.

Godot's automatic mesh LOD is a decimation, too. It is only switched on (flag auto_lod of a mesh) for
models without decal patches: buildings, landmarks, terrain props, wheels.
"""
import numpy as np

from . import core

# --- player cars (cesprites.carbody.SmoothCar, hook parameter "detail") ---------------------------------
#   ring   points per cross-section segment (x N_* of carbody)      step  station spacing along the car
#   res    grid of the conformal patches                            off   height of patches over the body
#   wheel  segments of the lathed wheel parts                       min_off  smallest patch height (m)
#   graze  patches end where the body turns away from their projection (cosine; sprites: 0 = never)
PLAYER_DETAIL = {
    # showroom: close-up, turning slowly
    "show": dict(ring=0.6, step=2.0, res=2.0, off=1.5, wheel=0.75, min_off=0.0, graze=0.22),
    # race: 9 m in front of the camera, about 250 px wide
    "lod0": dict(ring=0.4, step=3.5, res=3.5, off=2.5, wheel=0.5, min_off=0.0015, graze=0.22),
    # shadow caster: bare body shells
    "shadow": dict(ring=0.2, step=9.0, res=12.0, off=4.0, wheel=0.2, min_off=0.0),
}

# --- traffic cars (cesprites.vehicles.Car, hook parameter "detail") ----------------------------------------
#   subsurf  subdivision level of the body lofts (sprite: 1)         ring  refinement of the cross-section
#   step     scale of the station spacing                            wheel segments of tyres and rims
CAR_DETAIL = {
    # up to 40 m: finer cross-sections than the sprite's control polygon, all decals cut in
    "lod0": dict(subsurf=0, ring=2, step=1.9, wheel=0.65),
    # 40 - 120 m: the control polygon, no seams and handles, plain mirrors, drum wheels
    "lod1": dict(subsurf=0, ring=1, step=2.5, wheel=0.45, bevel=False, small=False),
    # beyond: 5-point cross-sections, a station every 30 cm at most, no mirrors
    "lod2": dict(subsurf=0, ring=0, step=6.0, wheel=0.2, bevel=False, mirrors=False, small=False),
    "shadow": dict(subsurf=0, ring=0, step=6.0, wheel=0.2, bevel=False, mirrors=False, small=False),
}
# default swap distances (m) of the manifest; the renderer scales them with the "Details" level
VEHICLE_LOD_DIST = {"lod0": 40, "lod1": 120, "lod2": 100000}
PROP_LOD_DIST = {"lod0": 60, "lod1": 200}


def merge_surfaces(parts):
    """Merges the surfaces of posed parts [(surfaces, pos | None, yaw_deg)] into one list of class surfaces
    (model space). Used for lod1 / lod2 (one mesh incl. the wheels) and for shadow casters."""
    import math
    by_cls = {}
    for surfaces, pos, yaw_deg in parts:
        off = np.zeros(3) if pos is None else np.asarray(pos, dtype=np.float64)
        a = math.radians(yaw_deg or 0.0)
        ca, sa = math.cos(a), math.sin(a)
        for cls, s in surfaces:
            p, n = s["pos"], s["nor"]
            if yaw_deg:
                p = np.stack([p[:, 0] * ca + p[:, 2] * sa, p[:, 1], -p[:, 0] * sa + p[:, 2] * ca], axis=1)
                n = np.stack([n[:, 0] * ca + n[:, 2] * sa, n[:, 1], -n[:, 0] * sa + n[:, 2] * ca], axis=1)
            e = by_cls.setdefault(cls, dict(pos=[], nor=[], col=[], uv=[], uv2=[], idx=[], n=0))
            e["pos"].append(p + off)
            e["nor"].append(n)
            for k in ("col", "uv", "uv2"):
                e[k].append(s.get(k))
            e["idx"].append(np.asarray(s["idx"], dtype=np.int64) + e["n"])
            e["n"] += p.shape[0]
    out = []
    for cls in core.CLASS_ORDER:
        e = by_cls.get(cls)
        if not e:
            continue
        d = dict(pos=np.concatenate(e["pos"]), nor=np.concatenate(e["nor"]),
                 idx=np.concatenate(e["idx"]).astype(np.uint32))
        for k in ("col", "uv", "uv2"):
            d[k] = np.concatenate(e[k]) if all(x is not None for x in e[k]) else None
        out.append((cls, d))
    return out
