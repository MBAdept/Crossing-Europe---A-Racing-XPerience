"""The coach (bus) as a real-time model (contract 6, wave 4 "AS2b"; docs/modelle.md section 15).

The sprite bus of cesprites.heavy.build_bus is one textured box (render "box", one part "body", 12.8 x 2.55 x
3.65 m). This builder makes the same vehicle - footprint, axles, window band, livery stripes, lamp layout and the
colours of heavy.BUS_VARIANTS - as a rigid model with real parts:

  body     the shell of the sprite (rounded ends, roof edge, wheel arches cut out of the bottom) as a loft; window
           band with seals and seven panes, the double door on the right and the driver's window on the left,
           livery stripes (paint2 / paint3), luggage hatches, side markers, rear window, engine louvres, tall tail
           lamp clusters with indicator and reverse light, high brake light, red end-outline lamps, windscreen with
           destination display, headlights, indicators, grille - all cut INTO the shell (ce3d.decalgeo, one layer)
  parts    bumpers (the rear plate on the rear one, the front plate on the front one), wheel-arch liners, coach
           mirrors on their arms, wipers; wheel nodes (front single, rear twin: the truck's wheels at 0.5 m)
  levels   lod0 (60 m), lod1 (180 m): coarser loft and decals, wheels merged; lod2: a coarse loft, the window band
           as one pane per side, lamps, plates and the wide stripe; shadow: the coarse loft 3 cm inside, drums
Paint      paint = body, paint2 = lower stripe (s1), paint3 = upper stripe (s2); near-white paints are toned as the
           truck's (truck3d._tone)
Build space as cesprites: y = 0 at the rear, +y forward, x = 0 centre (+x right), z = 0 ground. Model space as every
vehicle: origin on the ground under the centre, nose at -Z.
"""
import math
import time

import bmesh
import numpy as np

from . import core, decalgeo, roles
from . import truck3d as TK
from .export import Lod, ModelData, Part

L, W2, H = 12.8, 1.275, 3.625          # body; the roof crown adds 0.025 -> 3.65 m (sprite object height)
ZB = 0.38                              # bottom of the body
Y_RA, Y_FA = 3.15, 10.0                # rear (twin) and front axle
R = 0.5
RA = R + 0.06                          # wheel arch radius
TW_FRONT, TW_REAR = 0.30, 0.28
X_WHEEL = W2 - 0.05                    # outer tyre face
R_END = (0.18, 0.4)                    # rounding of the rear / front end
PLASTIC_Z = 0.42                       # dark skirt below
LOD_DIST = {"lod0": 60, "lod1": 180, "lod2": 100000}
# stations and section points per level (3 = shadow caster)
STEP = {0: 0.4, 1: 1.6, 2: 12.8, 3: 6.4}
ARCH_N = {0: 12, 1: 6, 2: 2, 3: 3}
END_N = {0: (4, 6), 1: (2, 3), 2: (1, 1), 3: (1, 1)}
SECTION = {0: dict(side=4, top=6, bot=2, roof=3), 1: dict(side=2, top=3, bot=1, roof=1),
           2: dict(side=1, top=1, bot=1, roof=1), 3: dict(side=1, top=2, bot=1, roof=1)}
# heights of the long horizontal lines on the flanks (skirt, lower edge of the stripe, upper edge of the far stripe,
# window band) and the points between them per level (intervals z0 | 0.42 | 0.95 | 1.2 | 1.72 | 3.28 | z1)
ROWS = (PLASTIC_Z, 0.95, 1.2, 1.72, 3.28)
SIDE_SUB = {0: (0, 1, 0, 1, 2, 0), 1: (0, 0, 0, 0, 1, 0), 2: (0, 0, 0, 0, 0, 0)}
FAR_STRIPE = (0.95, 1.2)               # lod2: the wedge of the lower stripe as a band of its mean height
GLASS = dict(color="#2a343e", rough=0.02, metal=0.25)      # the traffic cars' glass (traffic3d.TRAFFIC_GLASS)
LINER = "#141516"
BUMPER = "#2a2c2f"
LED = "-on:0.55:#ffb030"               # destination display: amber LEDs, always on, no light anchor
SEAL_W = 0.008
FAR_PLATE = "#c4c4c1"                  # plates of the far levels: the mean of a plate with its characters (traffic3d)


def _corner(d, r):
    """Inset of a rounded end of radius r at distance d from the end (cesprites.vehicles.corner)."""
    if r <= 0 or d >= r:
        return 0.0
    d = max(d, 0.0)
    return r - math.sqrt(max(0.0, r * r - (r - d) ** 2))


def _bottom(y):
    zb = ZB
    for ya in (Y_RA, Y_FA):
        dy = abs(y - ya)
        if dy < RA:
            zb = max(zb, R + math.sqrt(RA * RA - dy * dy))
    return zb


def _frame(y, inset=0.0):
    """(half width, bottom, top) of the shell at station y (cesprites.heavy.build_bus)."""
    e = _corner(y, R_END[0]) + _corner(L - y, R_END[1])
    w = W2 - e * 0.6 - inset
    zb = _bottom(y) + e * 0.4 + inset
    zt = H - e * 0.5 - 0.12 * max(0.0, (y - (L - 1.2)) / 1.2) ** 2 - inset
    return w, zb, zt


def _half(y, lv, inset=0.0):
    """Half section [(x, z)] from the bottom centre over the right side to the roof centre. The flank runs through
    the heights of the long horizontal lines of the livery (ROWS: skirt, stripe, window band) - they are edges of the
    loft and cost no cut - with SIDE_SUB[level] points between them. Every station has the same number of points:
    where the flank does not reach a row (over a wheel arch, at the rounded ends) the row point sits on the end of the
    flank (zero-length quads, dropped later)."""
    s = SECTION[lv]
    w, zb, zt = _frame(y, inset)
    rb = min(0.03, 0.4 * (zt - zb))
    rt = min(0.28, 0.4 * (zt - zb))
    pts = [(0.0, zb)] + ([(max(0.02, w - rb) * 0.5, zb)] if lv <= 1 else [])
    for i in range(s["bot"] + 1):
        a = math.radians(-90.0 + 90.0 * i / s["bot"])
        pts.append((w - rb + rb * math.cos(a), zb + rb + rb * math.sin(a)))
    z0, z1 = zb + rb, zt - rt
    rows = ROWS if lv <= 2 else ()
    anchors = [z0] + [min(z1, max(z0, r)) for r in rows] + [z1]
    sub = SIDE_SUB[lv] if rows else (s["side"] - 1,)
    for k in range(len(anchors) - 1):
        a, b = anchors[k], anchors[k + 1]
        n = sub[k] if k < len(sub) else 0
        for j in range(1, n + 1):
            pts.append((w, a + (b - a) * j / (n + 1)))
        if k + 1 < len(anchors) - 1:
            pts.append((w, b))
    for i in range(s["top"] + 1):
        a = math.radians(90.0 * i / s["top"])
        pts.append((w - rt + rt * math.cos(a), zt - rt + rt * math.sin(a)))
    xr = w - rt
    for i in range(1, s["roof"] + 1):
        x = xr * (1.0 - i / s["roof"])
        pts.append((x, zt + 0.025 * (1.0 - (x / max(xr, 1e-6)) ** 2)))
    return pts


def _stations(lv):
    ys = set()
    n = max(2, int(math.ceil(L / STEP[lv])))
    for i in range(n + 1):
        ys.add(round(L * i / n, 5))
    nr, nf = END_N[lv]
    for i in range(1, nr + 1):
        ys.add(round(R_END[0] * (1 - math.cos(0.5 * math.pi * i / nr)), 5))
    for i in range(1, nf + 1):
        ys.add(round(L - R_END[1] * (1 - math.cos(0.5 * math.pi * i / nf)), 5))
    an = ARCH_N[lv]
    for ya in (Y_RA, Y_FA):
        for i in range(an + 1):
            ys.add(round(ya + RA * math.cos(math.pi * i / an), 5))
        ys.update((round(ya - RA - 0.003, 5), round(ya + RA + 0.003, 5)))
    out = []
    for y in sorted(ys):
        if 0.0 <= y <= L and (not out or y - out[-1] > 0.002):
            out.append(y)
    return out


def _shell(b, lv, inset=0.0):
    """The shell as a Blender object (node "none": its triangles are cut and added as a panel)."""
    rings = []
    for y in _stations(lv):
        half = _half(y, lv, inset)
        ring = [(x, y, z) for (x, z) in half] + [(-x, y, z) for (x, z) in reversed(half[1:-1])]
        rings.append(ring)
    bm = b.MU.loft(rings)
    # the end caps as a beauty triangulation (an n-gon fan put long slivers under every decal of the ends)
    caps = [f for f in bm.faces if len(f.verts) > 4]
    bmesh.ops.triangulate(bm, faces=caps, quad_method="BEAUTY", ngon_method="BEAUTY")
    with b.node("none"):
        ob = b.MU.make("bus_shell", bm, b.paint_mat("paint"), smooth=lv <= 1, sharp_deg=40.0, parent=b.root)
    return ob


def _rect(u0, v0, u1, v1):
    return [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]


def _side_items(b, lv, sgn, m):
    """Decals of one flank in (y, z): [(poly, mat, rank)]."""
    it = []
    # livery stripes (the sprite's wedges) - under everything else
    if lv <= 1:
        it.append(([(0.0, 0.95), (L, 0.95), (L, 1.12), (0.0, 1.32)], b.i_acc2, 1))
    else:
        it.append((_rect(0.0, FAR_STRIPE[0], L, FAR_STRIPE[1]), b.i_acc2, 1))
    if lv <= 1:
        it.append(([(0.0, 1.38), (L, 1.18), (L, 1.26), (0.0, 1.46)], b.i_acc3, 1))
    # window band: seal, seven panes with pillars
    if lv <= 1:
        it.append((_rect(0.9, 1.72, 11.25, 3.28), b.i_seal, 10))
        for i in range(7):
            y0 = 0.95 + i * 1.47
            it.append((_rect(y0, 1.76, y0 + 1.4, 3.24), m["glass"], 11))
    else:
        it.append((_rect(0.9, 1.72, 11.25, 3.28), m["glass"], 11))
    if sgn > 0:
        # double door (right side): frame, two leaves, a step light strip of dark rubber at the bottom
        if lv <= 1:
            it.append((_rect(11.28, 0.46, 12.24, 3.28), b.i_seal, 10))
        it.append((_rect(11.32, 0.5, 12.2, 3.24), m["glass"], 11))
        if lv == 0:
            it.append((_rect(11.76 - SEAL_W / 2, 0.5, 11.76 + SEAL_W / 2, 3.24), b.i_seal, 12))
            for yy in (11.34, 11.78):
                it.append((_rect(yy, 1.6, yy + 0.4, 1.63), m["handle"], 13))
    else:
        if lv <= 1:
            it.append((_rect(11.28, 1.72, 12.54, 3.28), b.i_seal, 10))
        it.append((_rect(11.32, 1.76, 12.5, 3.24), m["glass"], 11))
    if lv == 0:
        # luggage hatches between the axles: shut lines and handles
        for y0, y1 in ((3.95, 5.75), (5.79, 7.59), (7.63, 9.36)):
            for yy in (y0, y1):
                it.append((_rect(yy - SEAL_W / 2, 0.45, yy + SEAL_W / 2, 0.92), b.i_seal, 6))
            it.append((_rect(y0, 0.92 - SEAL_W / 2, y1, 0.92 + SEAL_W / 2), b.i_seal, 6))
            it.append((_rect(0.5 * (y0 + y1) - 0.1, 0.84, 0.5 * (y0 + y1) + 0.1, 0.87), m["handle"], 7))
    if lv <= 1:
        for i in range(4):
            y = 1.2 + i * 2.6
            it.append((_rect(y, 0.45, y + 0.09, 0.505), m["marker_side"], 20))
    return it


def _rear_items(b, lv, m):
    """Decals of the rear end in (x, z), right half (mirrored) unless noted: [(poly, mat, rank, sym)]."""
    it = [(_rect(0.0, 0.95, 1.4, 1.12), b.i_acc2, 1, True)]
    if lv <= 1:
        it.append((_rect(0.0, 2.62, 1.0, 3.32), b.i_seal, 10, True))
        it.append((_rect(0.0, 2.66, 0.96, 3.28), m["glass"], 11, True))
        it.append((_rect(0.0, 0.62, 1.12, 0.66), b.i_dark, 5, True))
    else:
        it.append((_rect(0.0, 2.62, 1.0, 3.32), m["glass"], 11, True))
    if lv <= 1:
        # engine louvres (lod1 too: at 60 - 180 m they blend into the grey panel the sprite shows there)
        for i in range(6):
            z = 1.35 + i * 0.12
            it.append((_rect(0.0, z, 0.8, z + 0.035), b.i_dark, 7, True))
    # lamp clusters at the corners: a dark housing, tail + brake, indicator, reverse light
    if lv <= 1:
        it.append((_rect(1.03, 0.71, 1.23, 2.31), m["housing"], 19, True))
    it.append((_rect(1.04, 0.72, 1.22, 1.95), m["tail"], 20, True))
    it.append((_rect(1.04, 1.98, 1.22, 2.12), m["ind"], 22, True))
    if lv <= 1:
        it.append((_rect(1.04, 2.15, 1.22, 2.30), m["reverse"], 21, True))
    it.append((_rect(0.0, 3.40, 0.35, 3.46), m["brake"], 20, True))
    if lv <= 1:
        it.append((_rect(0.86, 3.41, 1.0, 3.48), m["marker"], 20, True))
    return it


def _front_items(b, lv, m):
    it = []
    if lv <= 1:
        it.append((_rect(0.0, 1.21, 1.2, 3.44), b.i_seal, 10, True))
    it.append((_rect(0.0, 1.25, 1.16, 3.4), m["glass"], 11, True))
    if lv == 0:
        it.append((_rect(0.0, 1.25, SEAL_W / 2, 3.4), b.i_seal, 12, True))
    # destination display behind the top of the windscreen: dark panel, amber "text"
    if lv <= 1:
        it.append((_rect(0.0, 3.12, 0.9, 3.36), b.i_seal, 13, True))
    if lv <= 1:
        x = -0.8
        k = 0
        while x < 0.8:
            wd = 0.05 if k % 4 != 3 else 0.0
            if wd > 0.0:
                it.append((_rect(x, 3.19, x + wd, 3.29), m["led"], 14, False))
            x += 0.075
            k += 1
    # lights: dark housing, headlight, indicator at the outer end; grille
    if lv <= 1:
        it.append((_rect(0.58, 0.56, 1.15, 0.80), m["housing"], 19, True))
    it.append((_rect(0.60, 0.58, 0.98, 0.78), m["head"], 20, True))
    it.append((_rect(0.99, 0.58, 1.13, 0.78), m["ind"], 22, True))
    it.append((_rect(0.0, 0.5, 0.5, 0.9), b.i_dark, 15, True))
    if lv == 0:
        for z in (0.58, 0.66, 0.74, 0.82):
            it.append((_rect(0.0, z, 0.46, z + 0.025), m["grille_bar"], 16, True))
    return it


def _cut_shell(b, lv, ob):
    """Cuts the decals into the shell; the result is a panel of the node "body"."""
    s = core.soups_of([ob])[0]
    t = decalgeo.Tris(s.pos, s.nor)
    t.mat[:] = b.i_paint
    t.paint_below(PLASTIC_Z, b.i_plastic)
    # over the wheel arches the bottom of the shell looks down into the wheel: dark like the liners
    fn = t.face_normals()
    zc = t.pos[:, :, 2].mean(axis=1)
    t.mat[(fn[:, 2] < -0.5) & (zc > PLASTIC_Z + 0.03)] = b.i_liner
    m = b.bus_mats
    groups = {}
    for sgn in (1, -1):
        groups[("side", sgn)] = [dict(poly=p, mat=mt, rank=rk, n_min=0.55) for (p, mt, rk) in _side_items(b, lv, sgn, m)]
    for key, items in ((("rear", 1), _rear_items(b, lv, m)), (("front", 1), _front_items(b, lv, m))):
        lst = []
        for (p, mt, rk, sym) in items:
            lst.append(dict(poly=p, mat=mt, rank=rk, n_min=0.3))
            if sym:
                lst.append(dict(poly=[(-u, v) for (u, v) in p], mat=mt, rank=rk, n_min=0.3))
        groups[key] = lst
    area0 = decalgeo._area3(t.pos)
    for key in sorted(groups, key=lambda g: (g[0], -g[1])):
        items = sorted(groups[key], key=lambda d: d["rank"])
        t.apply(key[0], key[1], items, cut=True)
    lost = area0 - decalgeo._area3(t.pos)
    if abs(lost) > 2.0e-4:
        raise RuntimeError("bus: the decal cut changed the shell by %.1f cm2" % (lost * 1e4))
    t.normalize()
    b.panels.setdefault("body", []).append(t)
    import bpy
    bpy.data.objects.remove(ob)


def _liners(b, lv):
    """Wheel-arch liners: a dark half drum over each wheel from the inner wall to the side, and the inner wall."""
    n = {0: 16, 1: 8, 2: 2}[lv]
    mat = b.mat("liner", LINER, 0.9)
    bm = bmesh.new()
    for ya in (Y_RA, Y_FA):
        for sgn in (1, -1):
            x_in, x_out = sgn * (W2 - 0.34), sgn * (W2 - 0.012)
            ring = [(ya + RA * math.cos(math.pi * i / n), R + RA * math.sin(math.pi * i / n)) for i in range(n + 1)]
            va = [bm.verts.new((x_in, y, z)) for (y, z) in ring]
            vb = [bm.verts.new((x_out, y, z)) for (y, z) in ring]
            for i in range(n):
                f = (va[i], vb[i], vb[i + 1], va[i + 1])       # seen from below / from the wheel
                bm.faces.new(f if sgn > 0 else f[::-1])
            # inner wall: the half disc at x_in, facing out (one cannot look through the arch to the other side)
            c = bm.verts.new((x_in, ya, R))
            for i in range(n):
                f = (c, va[i], va[i + 1])
                bm.faces.new(f if sgn > 0 else f[::-1])
    bm.normal_update()
    return b.obj("liners", bm, mat, smooth=False)


def _bumpers(b, lv):
    """Rear and front bumper: panels (plates cut into their faces)."""
    i_bump = b.flat(BUMPER, 0.5, 0.1)
    i_plate = b.flat("#eeeeea", 0.45, 0.0, "plate:0.6")
    i_plate_front = b.flat("#e4e4e0", 0.45, 0.0)
    i_blue = b.flat("#1d3c9c", 0.45)
    i_text = b.flat("#151515", 0.5)
    # rear bumper: y -0.03 .. 0.07, the plate on its rear face
    xr = W2 - 0.03
    f = TK._box_faces(-xr, xr, -0.03, 0.07, 0.37, 0.59)
    items = [dict(poly=_rect(-0.268, 0.417, 0.268, 0.543), mat=b.i_seal),
             dict(poly=_rect(-0.26, 0.425, 0.26, 0.535), mat=i_plate if lv <= 1 else b.flat(FAR_PLATE, 0.45, 0.0, "plate:0.6")),
             dict(poly=_rect(-0.26, 0.425, -0.222, 0.535), mat=i_blue)]
    if lv == 0:
        x = -0.2
        for c in (1, 1, 0, 1, 1, 0, 1, 1, 1):
            if c:
                items.append(dict(poly=_rect(x, 0.447, x + 0.034, 0.513), mat=i_text))
                x += 0.047
            else:
                x += 0.03
    b.panel("body", i_bump, [f["r"]], {("rear", 1): items})
    b.panel("body", i_bump, [f[k] for k in "lRtb"])
    # front bumper: narrower (the front end is rounded with 0.4 m), the front plate
    xf = W2 - 0.12
    f = TK._box_faces(-xf, xf, L - 0.07, L + 0.03, 0.375, 0.625)
    items = [dict(poly=_rect(-0.26, 0.44, 0.26, 0.55), mat=i_plate_front if lv <= 1 else b.flat(FAR_PLATE, 0.45)),
             dict(poly=_rect(0.222, 0.44, 0.26, 0.55), mat=i_blue)]
    b.panel("body", i_bump, [f["f"]], {("front", 1): items})
    b.panel("body", i_bump, [f[k] for k in "lRtb"])


def _mirrors(b, lv):
    """Coach mirrors: arms from the roof edge forward and down, housings with dark glass looking back."""
    MU = b.MU
    dark = b.mat("dark", TK.DARK, 0.6)
    bm = bmesh.new()
    for sgn in (1, -1):
        p0, p1, p2 = (sgn * 1.1, L - 0.2, 3.2), (sgn * 1.45, L + 0.35, 3.0), (sgn * 1.45, L + 0.4, 2.56)
        if lv <= 1:
            MU.bm_beam(p0, p1, 0.05, bm=bm)
            MU.bm_beam(p1, p2, 0.05, bm=bm)
        else:
            MU.bm_beam(p0, p2, 0.05, bm=bm)          # far: one straight arm (the housing keeps the outline)
        MU.bm_box(0.11, 0.07, 0.4, (sgn * 1.45, L + 0.4, 2.36), bm=bm)
    b.obj("mirrors", bm, dark, bevel=0.012 if lv == 0 else 0.0, segs=1)
    if lv <= 1:
        bm = bmesh.new()
        for sgn in (1, -1):
            MU.bm_box(0.09, 0.006, 0.36, (sgn * 1.45, L + 0.4 - 0.036, 2.36), bm=bm)
        b.obj("mirrorglass", bm, b.mat("mglass", "#3a4148", 0.05, 0.9))
    if lv == 0:
        # wipers on the windscreen
        bm = bmesh.new()
        for x in (-0.6, 0.35):
            MU.bm_beam((x, L + 0.012, 1.32), (x + 0.45, L - 0.01, 2.2), 0.022, 0.014, bm=bm)
        b.obj("wipers", bm, dark)


def _wheels(b):
    pivots = {}
    for name, kind, y, tw in (("wheel_0", "front", Y_FA, TW_FRONT), ("wheel_1", "drive", Y_RA, TW_REAR)):
        if b.split:
            with b.node(name + "r"):
                pivots[name] = TK._wheel(b, kind, (X_WHEEL, y, R), radius=R, tw=tw)
        else:
            with b.node("body"):
                TK._wheel(b, kind, (X_WHEEL, y, R), radius=R, tw=tw)
                TK._wheel(b, kind, (X_WHEEL, y, R), left=True, radius=R, tw=tw)
    return pivots


def _shadow(b):
    """Shadow caster: the coarse shell 3 cm inside the skin (its bottom follows the arches), wheel drums."""
    ob = _shell(b, 3, inset=TK.SHADOW_IN)
    ob["ce_node"] = "body"
    grey = b.mat("grey", TK.GREY)
    ob.data.materials.clear()
    ob.data.materials.append(grey)
    MU = b.MU
    bm = bmesh.new()
    r = R * 0.97
    for y, tw, twin in ((Y_FA, TW_FRONT, False), (Y_RA, TW_REAR, True)):
        width = tw * 2 + 0.035 if twin else tw
        x0, x1 = X_WHEEL - width, X_WHEEL - (0.2 if twin else 0.11)
        for sx in (-1, 1):
            MU.bm_cyl(r, r, x1 - x0, center=(sx * (x0 + x1) / 2, y, R), axis="X", segs=8, bm=bm)
    with b.node("body"):
        b.obj("shadow_wheels", bm, grey)
    return {}


def _materials(b):
    """Palette entries of the bus (the truck's _Build gives paint, paint2, paint3, dark, seal, glass ...)."""
    b.i_acc2 = b.i_cab                 # paint2: lower stripe
    b.i_acc3 = b.i_acc                 # paint3: upper stripe
    b.i_plastic = b.flat("#1a1b1d", 0.6)
    b.i_liner = b.flat(LINER, 0.9)
    b.bus_mats = dict(
        glass=b.pal.add("bus_glass", "glass", dict(GLASS)),
        handle=b.flat("#2c2e31", 0.4, 0.4),
        marker_side=b.flat("#c86a12", 0.2, 0.0, "-marker:1:" + TK.AMBER),
        marker=b.flat("#8a0c0a", 0.2, 0.0, "marker:1:" + TK.LAMP_RED),
        housing=b.flat("#0b0c0d", 0.12, 0.0),
        tail=b.flat("#8a0c0a", 0.15, 0.0, "tail_brake"),
        brake=b.flat("#5a0a08", 0.15, 0.0, "brake:1:#ff2414"),
        ind=b.flat("#c86a12", 0.15, 0.0, "ind"),
        reverse=b.flat("#b9bec4", 0.15, 0.3, "reverse"),
        head=b.flat("#dfe6ec", 0.1, 0.3, "head"),
        led=b.flat("#3a2a10", 0.3, 0.0, LED),
        grille_bar=b.flat("#3a3d42", 0.4, 0.4),
    )


def _level(level, paints):
    from cesprites import meshutil as MU
    b = TK._Build(level)
    _materials(b)
    MU.tagging(True)
    try:
        if level <= 2:
            _cut_shell(b, level, _shell(b, level))
            with b.node("body"):
                if level <= 1:
                    _liners(b, level)       # (far: the shell is closed over the wheels, dark from below)
                _mirrors(b, level)
            _bumpers(b, level)
            pivots = _wheels(b)
        else:
            pivots = _shadow(b)
    finally:
        MU.tagging(False)
    soups = core.soups_of(core.model_objects(b.rig))
    tr = roles.Translator(overrides={"tk_paint2": dict(slot="paint2")}, glass_class=(level == 0), glass_opacity=1.0,
                          default_paint=paints)
    nodes = {}
    from .vehicles3d import _add_soup
    for s in soups:
        node = roles.node_of(s.ob)
        if node == "none":
            continue
        _add_soup(nodes, tr, s, node)
    for node, lst in b.panels.items():
        mb = nodes.setdefault(node, core.MeshBuilder())
        for t in lst:
            for mi in np.unique(t.mat):
                role, data, lamp = b.pal.items[int(mi)]
                sel = t.mat == mi
                tr.add_role(mb, role, dict(data), t.pos[sel], t.nor[sel], lamp)
    return b, nodes, pivots, tr


def build_bus(model_id, spec3d):
    from cesprites import catalog, heavy

    from .vehicles3d import SLIVER_M, _sprite_spec
    t0 = time.time()
    colours = dict(catalog.TRAFFIC_COLORS["bus"])
    set_ids = list(spec3d.get("sets") or [])
    first = set_ids[0].split("_", 1)[1]

    def livery(cname):
        v = heavy.BUS_VARIANTS[cname]
        return {"paint": TK._tone(colours[cname]), "paint2": TK._tone(v["s1"]), "paint3": TK._tone(v["s2"]), "metal": 0.25}
    paints = {k: v for k, v in livery(first).items() if k != "metal"}
    sspec = _sprite_spec(spec3d["source"])
    origin = np.array([0.0, L / 2.0, 0.0])
    model = ModelData(model_id, spec3d["kind"], {"width_m": 2 * W2, "length_m": L, "height_m": 3.65})
    lods = []
    for level in (0, 1, 2):
        b, nodes, pivots, tr = _level(level, paints)
        name = "lod%d" % level
        if level == 0:
            model.lights = tr.lights(origin=origin)
            parts = [Part("body", "lod0_body", nodes["body"].finish(origin=origin, min_height=SLIVER_M))]
            meshes = {}
            for wname, kind in (("wheel_0", "front"), ("wheel_1", "drive")):
                meshes[wname] = nodes[wname + "r"].finish(origin=np.array(pivots[wname]), min_height=SLIVER_M)
                xc, y = pivots[wname][0], pivots[wname][1]
                for side in ("l", "r"):
                    p = np.array([xc if side == "r" else -xc, y, R]) - origin
                    parts.append(Part(wname + side, "wheel_" + kind, meshes[wname], pos=core.model_point(p),
                                      yaw_deg=180.0 if side == "l" else 0.0,
                                      wheel={"radius": R, "steer": wname == "wheel_0"}, auto_lod=False))
            lods.append(Lod(name, LOD_DIST[name], parts))
        else:
            lods.append(Lod(name, LOD_DIST[name], [Part("body", name + "_body",
                                                        nodes["body"].finish(origin=origin, min_height=SLIVER_M))]))
    b, nodes, _p, _tr = _level(3, paints)
    model.shadow = Part("body", "shadow", nodes["body"].finish(origin=origin))
    model.lods = lods
    model.paint = livery(first)
    model.tags = list(sspec.get("tags", []))
    for sid in set_ids:
        model.sets[sid] = {"model": model_id, "paint": livery(sid.split("_", 1)[1])}
    model.stats = dict(build_s=round(time.time() - t0, 2))
    return model
