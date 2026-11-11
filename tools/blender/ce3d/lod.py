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
    "show": dict(ring=0.7, step=2.0, off=1.0, min_off=0.0, wheel=0.75, graze=0.22, conform=True, crease=0.007,
                 arch_r=0.012, seam=1.3, arch_n=36, gstep=2.2, lamp_depth=1.0, bumper_clamp=True, plate_bold=1.4,
                 bumper_end_r=0.05),
    # race: 9 m in front of the camera, about 200 px wide (1 px = 1 cm). Seams 8 mm and bolder plate characters:
    # thinner ones shimmered while the car turned (art review of AS1)
    "lod0": dict(ring=0.45, step=3.2, off=1.0, min_off=0.0, wheel=0.4, graze=0.22, conform=True, crease=0.007,
                 arch_r=0.012, seam=1.8, wheel_plain=True, arch_n=20, gstep=4.0, lamp_depth=1.0, bumper_clamp=True,
                 plate_bold=1.5, bumper_end_r=0.05),
    # shadow caster: bare body shells
    "shadow": dict(ring=0.2, step=9.0, res=12.0, off=4.0, wheel=0.2, min_off=0.0),
}
#   conform  patches triangulated with the body faces under them: they keep the heights of the design (off 1.0)
#   crease   undercut under the shoulder line (m)        arch_r  edge radius of the wheel-arch openings (m)
#   seam     scale of the width of panel gaps            wheel_plain  tyres without grooves, short spokes
#   arch_n   stations per wheel arch at equal angles     gstep   station spacing of the greenhouse
#   lamp_depth  lamp units as recesses in the body (scale of their depth; 0 = parts stacked on the body)
#   bumper_clamp  bumpers end at the wheel arch (no station of the end rounding beyond it)
#   bumper_end_r  the bumper rounds into the body at its wheel-arch end (radius, m) instead of a flat cap
#   plate_bold  stroke width of the plate characters (scale)

# --- traffic cars on SmoothCar lofts (ce3d.traffic3d; the parameters of PLAYER_DETAIL) -----------------------
#   ring_min  smallest point count of a cross-section segment
TRAFFIC_DETAIL = {
    # up to 40 m: every decal cut in, spoked wheels with brake discs
    "lod0": dict(ring=0.3, step=6.6, wheel=0.3, wheel_plain=True, arch_n=9, gstep=7.0, crease=0.006, arch_r=0.012,
                 ends_n=6, bumper_clamp=True, bumper_end_r=0.05, tyre_lite=True),
    # 40 - 120 m: coarser lofts, drum wheels, plain mirrors, no seams and handles
    "lod1": dict(ring=0.15, step=13.5, wheel=0.3, arch_n=5, gstep=18.0, crease=0.006, arch_r=0.012, ends_n=3,
                 bumper_clamp=True),
    # beyond: 14-point sections, the body runs to the full length, only lamps, plates and dark panes
    "lod2": dict(ring=0.1, ring_min=1, step=60.0, wheel=0.22, arch_n=2, gstep=40.0, ends_n=2),
    "shadow": dict(ring=0.1, ring_min=1, step=60.0, wheel=0.22, arch_n=2, gstep=40.0, ends_n=2),
}

# --- traffic cars (cesprites.vehicles.Car, hook parameter "detail"; not used by the models any more: the lofts
#     of the sprite generator crumple at the coarse levels - see ce3d.traffic3d) ------------------------------
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
