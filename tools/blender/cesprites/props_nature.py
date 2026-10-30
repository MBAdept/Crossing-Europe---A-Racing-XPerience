"""Trees, bushes, heather, rocks, cliff, hay bales. Origin = trunk base / near ground centre."""
import math
import random

import bmesh
from mathutils import Vector

from . import materials as M
from . import meshutil as MU


# --- materials ----------------------------------------------------------------------------------

def leaves(name, c1, c2, scale=1.4, bump=0.35):
    m, nb = M.new_material(name)
    fac = nb.ramp(nb.noise(scale, detail=3.0), [(0.35, (0, 0, 0, 1)), (0.7, (1, 1, 1, 1))])
    col = nb.mix(fac, M.srgb(c1), M.srgb(c2))
    # darker in the crevices of the leaf texture
    leafy = nb.voronoi(9.0, feature="F1", out="Distance")
    col = nb.mix(nb.math("MULTIPLY", leafy, 0.35), col, (0.02, 0.03, 0.01, 1.0))
    normal = nb.bump(leafy, strength=bump, distance=0.08)
    out = M.principled(nb, col, rough=0.75, spec=0.35, normal=normal, sheen=0.25)
    return M.finish(m, nb, out)


def bark(name, c1, c2, scale=4.0, rings=None):
    m, nb = M.new_material(name)
    fac = nb.ramp(nb.noise(scale, detail=4.0), [(0.3, (0, 0, 0, 1)), (0.75, (1, 1, 1, 1))])
    col = nb.mix(fac, M.srgb(c1), M.srgb(c2))
    if rings:
        x, y, z = nb.coords()
        r = nb.math("SINE", nb.mul(z, rings))
        col = nb.mix(nb.mul(nb.gt(r, 0.6), 0.6), col, (0.05, 0.035, 0.02, 1.0))
    normal = nb.bump(nb.noise(scale * 3, detail=3.0), strength=0.4, distance=0.03)
    out = M.principled(nb, col, rough=0.85, spec=0.25, normal=normal)
    return M.finish(m, nb, out)


def birch_bark(name):
    m, nb = M.new_material(name)
    x, y, z = nb.coords()
    n = nb.noise(2.5, detail=2.0)
    stretch = nb.node("ShaderNodeMapping")
    nb.links.new(nb.texco(), stretch.inputs["Vector"])
    stretch.inputs["Scale"].default_value = (3.0, 3.0, 0.6)
    marks = nb.noise(4.0, detail=1.0, vec=stretch.outputs[0])
    dark = nb.gt(marks, 0.62)
    col = nb.mix(dark, M.srgb("#e8e6df"), M.srgb("#2a2622"))
    col = nb.mix(nb.mul(nb.gt(n, 0.7), 0.4), col, M.srgb("#b8b0a2"))
    out = M.principled(nb, col, rough=0.7, spec=0.3)
    return M.finish(m, nb, out)


def rock(name, c1="#8b8780", c2="#6c6963", moss=None):
    m, nb = M.new_material(name)
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    fac = nb.ramp(nb.noise(1.2, detail=4.0), [(0.3, (0, 0, 0, 1)), (0.7, (1, 1, 1, 1))])
    col = nb.mix(fac, M.srgb(c1), M.srgb(c2))
    cracks = nb.voronoi(1.3, feature="DISTANCE_TO_EDGE", out="Distance")
    crack_m = nb.mul(nb.lt(cracks, 0.018), nb.gt(nb.noise(0.7, detail=1.0), 0.45))
    col = nb.mix(nb.mul(crack_m, 0.7), col, M.srgb("#45413c"))
    strata = nb.math("SINE", nb.add(nb.mul(z, 2.2), nb.mul(nb.noise(0.5, detail=2.0), 4.0)))
    col = nb.mix(nb.mul(nb.gt(strata, 0.75), 0.25), col, M.srgb("#5d5953"))
    if moss:
        mfac = nb.mul(nb.gt(nz, 0.55), nb.gt(nb.noise(0.8, detail=2.0), 0.48))
        col = nb.mix(mfac, col, M.srgb(moss))
    normal = nb.bump(nb.add(nb.noise(2.5, detail=5.0), nb.mul(crack_m, -0.5)), strength=0.45, distance=0.1)
    out = M.principled(nb, col, rough=0.85, spec=0.3, normal=normal)
    return M.finish(m, nb, out)


def straw(name):
    m, nb = M.new_material(name)
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    # spiral rings on the bale faces (bale axis = Y)
    rr = nb.math("SQRT", nb.add(nb.mul(x, x), nb.mul(z, z)))
    rings = nb.math("SINE", nb.mul(rr, 42.0))
    face = nb.gt(nb.absf(ny), 0.7)
    fac = nb.ramp(nb.noise(6.0, detail=3.0), [(0.3, (0, 0, 0, 1)), (0.7, (1, 1, 1, 1))])
    col = nb.mix(fac, M.srgb("#c9a24e"), M.srgb("#a9823a"))
    col = nb.mix(nb.mul(face, nb.mul(nb.gt(rings, 0.3), 0.5)), col, M.srgb("#7a5a26"))
    normal = nb.bump(nb.noise(25.0, detail=2.0), strength=0.5, distance=0.02)
    out = M.principled(nb, col, rough=0.9, spec=0.2, normal=normal, sheen=0.3)
    return M.finish(m, nb, out)


# --- geometry helpers ---------------------------------------------------------------------------

def _rand_in_ellipsoid(rng, a, b, c, shell=0.55):
    while True:
        v = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
        if v.length <= 1.0 and v.length >= shell * rng.random():
            return Vector((v.x * a, v.y * b, v.z * c))


def crown(rig, name, center, a, b, c, n, r0, r1, mat, seed, disp=0.35, shell=0.6, subdiv=2, flat_bottom=None):
    rng = random.Random(seed)
    bm = bmesh.new()
    for i in range(n):
        p = _rand_in_ellipsoid(rng, a, b, c, shell)
        if flat_bottom is not None and p.z < flat_bottom:
            p.z = flat_bottom + (p.z - flat_bottom) * 0.3
        r = rng.uniform(r0, r1) * (0.75 + 0.25 * (1 - abs(p.z) / c))
        MU.bm_sphere(r, center=(center[0] + p.x, center[1] + p.y, center[2] + p.z),
                     scale=(1.0, 1.0, rng.uniform(0.75, 1.0)), subdiv=subdiv, bm=bm)
    ob = MU.make(name, bm, mat, parent=rig.root, smooth=True, sharp_deg=80)
    if disp > 0:
        MU.displace(ob, disp, size=max(0.4, (r0 + r1) * 0.35), kind="CLOUDS", depth=2, seed=seed)
    return ob


def trunk(rig, name, pts, radii, mat, segs=10, bm=None):
    """Tapered tube through points with radii (lathe-like rings)."""
    own = bm is None
    bm = bm or bmesh.new()
    rings = []
    for i, (p, r) in enumerate(zip(pts, radii)):
        p = Vector(p)
        if i < len(pts) - 1:
            d = (Vector(pts[i + 1]) - p).normalized()
        else:
            d = (p - Vector(pts[i - 1])).normalized()
        up = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
        u = d.cross(up).normalized()
        w = d.cross(u).normalized()
        rings.append([p + (u * math.cos(2 * math.pi * k / segs) + w * math.sin(2 * math.pi * k / segs)) * r
                      for k in range(segs)])
    MU.loft(rings, bm=bm, cap0=True, cap1=True)
    if own:
        return MU.make(name, bm, mat, parent=rig.root, smooth=True, sharp_deg=70)
    return bm


def branch_set(rig, name, base_z, top, n, length, mat, seed, r=0.12, spread=0.9, up=0.6):
    rng = random.Random(seed)
    bm = bmesh.new()
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.4, 0.4)
        z0 = rng.uniform(base_z, top)
        ln = length * rng.uniform(0.6, 1.0)
        p0 = (0.0, 0.0, z0)
        p1 = (math.cos(a) * ln * 0.5 * spread, math.sin(a) * ln * 0.5 * spread, z0 + ln * up * 0.5)
        p2 = (math.cos(a) * ln * spread, math.sin(a) * ln * spread, z0 + ln * up)
        trunk(rig, name, [p0, p1, p2], [r, r * 0.6, r * 0.25], mat, segs=6, bm=bm)
    return MU.make(name, bm, mat, parent=rig.root, smooth=True, sharp_deg=70)


def obj_size(w, h, d=None):
    o = {"width_m": round(w, 2), "height_m": round(h, 2)}
    if d is not None:
        o["length_m"] = round(d, 2)
    return o


# --- trees --------------------------------------------------------------------------------------

def tree_oak(rig, p):
    s = p.get("seed", 11)
    b = bark("oak_bark", "#4a3b2c", "#2f261d")
    lv = leaves("oak_leaves", "#3d6b25", "#5c8a30")
    trunk(rig, "oak_trunk", [(0, 0, 0), (0.1, 0, 2.5), (0.0, 0.1, 4.5), (-0.2, 0, 6.0)], [0.42, 0.34, 0.28, 0.2], b)
    branch_set(rig, "oak_br", 3.6, 6.5, 7, 4.5, b, s, r=0.16, spread=1.0, up=0.55)
    crown(rig, "oak_crown", (0, 0, 8.6), 5.4, 5.0, 3.9, 70, 0.95, 1.8, lv, s, disp=0.75, flat_bottom=-2.6)
    return dict(object=obj_size(12.0, 13.5))


def tree_beech(rig, p):
    s = p.get("seed", 23)
    b = bark("beech_bark", "#7d7b74", "#5d5b55", scale=2.0)
    lv = leaves("beech_leaves", "#4a7a2a", "#6a9a35")
    trunk(rig, "beech_trunk", [(0, 0, 0), (0, 0, 3), (0.1, 0, 6), (0, 0.05, 9)], [0.32, 0.27, 0.22, 0.14], b)
    branch_set(rig, "beech_br", 4.5, 8.5, 6, 3.6, b, s, r=0.11, spread=0.8, up=0.9)
    crown(rig, "beech_crown", (0, 0, 10.0), 4.3, 4.1, 5.0, 64, 0.95, 1.7, lv, s, disp=0.6, flat_bottom=-3.6)
    return dict(object=obj_size(9.5, 15.5))


def tree_birch(rig, p):
    s = p.get("seed", 5)
    b = birch_bark("birch_bark")
    lv = leaves("birch_leaves", "#6f9a32", "#93b84a", scale=2.0)
    trunk(rig, "birch_trunk", [(0, 0, 0), (0.15, 0, 3), (0.0, 0.1, 6.5), (0.2, 0, 10.0), (0.15, 0, 12.2)],
          [0.2, 0.17, 0.13, 0.08, 0.04], b)
    branch_set(rig, "birch_br", 5.0, 10.0, 7, 2.6, b, s, r=0.06, spread=0.9, up=1.0)
    crown(rig, "birch_crown", (0.1, 0, 9.0), 2.4, 2.3, 3.6, 34, 0.6, 1.1, lv, s, disp=0.35, shell=0.75)
    return dict(object=obj_size(5.2, 12.8))


def tree_pine(rig, p):
    s = p.get("seed", 31)
    b = bark("pine_bark", "#a35c2e", "#6e3e22", scale=3.0)
    lower = bark("pine_bark_low", "#4d3a2a", "#2e231a")
    lv = leaves("pine_needles", "#2c4f2a", "#3f6634", scale=1.8)
    trunk(rig, "pine_trunk", [(0, 0, 0), (0.0, 0, 4)], [0.32, 0.26], lower)
    trunk(rig, "pine_trunk2", [(0, 0, 3.9), (0.15, 0, 9), (0.0, 0.1, 13), (0.2, 0, 16.5)], [0.26, 0.2, 0.15, 0.07], b)
    branch_set(rig, "pine_br", 11.0, 15.5, 6, 3.2, b, s, r=0.08, spread=1.0, up=0.35)
    rng = random.Random(s)
    bm = bmesh.new()
    # irregular flat-topped crown: clusters at the ends of the upper branches + a dome on top
    for i in range(34):
        a = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0.3, 3.1) ** 0.9
        z = 13.0 + 3.6 * (1.0 - (rr / 3.2) ** 2) * rng.uniform(0.55, 1.0) + rng.uniform(-0.4, 0.3)
        r = rng.uniform(0.6, 1.05)
        MU.bm_sphere(r, center=(0.15 + math.cos(a) * rr, math.sin(a) * rr, z), scale=(1.35, 1.35, 0.62), subdiv=2, bm=bm)
    for i in range(5):
        a = rng.uniform(0, 2 * math.pi)
        MU.bm_sphere(rng.uniform(0.5, 0.8), center=(math.cos(a) * 1.8, math.sin(a) * 1.8, rng.uniform(10.8, 12.2)),
                     scale=(1.4, 1.4, 0.6), subdiv=2, bm=bm)
    ob = MU.make("pine_crown", bm, lv, parent=rig.root, smooth=True, sharp_deg=80)
    MU.displace(ob, 0.55, size=0.45, seed=s)
    return dict(object=obj_size(7.0, 18.0))


def tree_spruce(rig, p):
    s = p.get("seed", 7)
    rng = random.Random(s)
    b = bark("spruce_bark", "#4a3626", "#2d2018")
    lv = leaves("spruce_needles", "#1e3d22", "#2d5530", scale=2.5, bump=0.5)
    H = 19.0
    trunk(rig, "spruce_trunk", [(0, 0, 0), (0, 0, H * 0.95)], [0.32, 0.05], b)
    bm = bmesh.new()
    tiers = 15
    for i in range(tiers):
        t = i / (tiers - 1)
        z0 = 1.6 + t * (H - 3.0)
        rad = (1.0 - t) ** 0.95 * 3.2 + 0.35
        hgt = 1.9 - t * 0.6
        segs = 16
        ring_b, ring_t = [], []
        for k in range(segs):
            a = 2 * math.pi * k / segs + rng.uniform(-0.12, 0.12)
            rk = rad * (1.0 if k % 2 == 0 else 0.78) * rng.uniform(0.85, 1.12)
            ring_b.append(Vector((math.cos(a) * rk, math.sin(a) * rk, z0 - rng.uniform(0.0, 0.35))))
        top = bm.verts.new((0, 0, z0 + hgt))
        vb = [bm.verts.new(v) for v in ring_b]
        for k in range(segs):
            bm.faces.new((vb[k], vb[(k + 1) % segs], top))
        inner = bm.verts.new((0, 0, z0 + 0.2))
        for k in range(segs):
            bm.faces.new((vb[(k + 1) % segs], vb[k], inner))
    MU.bm_cyl(0.25, 0.0, 1.6, center=(0, 0, H - 0.5), segs=8, bm=bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = MU.make("spruce_tiers", bm, lv, parent=rig.root, smooth=True, sharp_deg=50)
    MU.displace(ob, 0.25, size=0.35, seed=s)
    return dict(object=obj_size(7.0, H + 0.3))


def tree_poplar(rig, p):
    s = p.get("seed", 13)
    b = bark("poplar_bark", "#6b665c", "#4b4740")
    lv = leaves("poplar_leaves", "#43712a", "#5f8f35", scale=1.6)
    trunk(rig, "poplar_trunk", [(0, 0, 0), (0, 0, 6), (0, 0, 16)], [0.3, 0.22, 0.08], b)
    crown(rig, "poplar_crown", (0, 0, 12.0), 1.55, 1.5, 9.3, 95, 0.8, 1.3, lv, s, disp=0.45, shell=0.35)
    return dict(object=obj_size(4.0, 21.8))


def tree_cypress(rig, p):
    s = p.get("seed", 3)
    lv = leaves("cypress_leaves", "#1f3a1f", "#2f4e28", scale=2.2, bump=0.55)
    b = bark("cyp_bark", "#4a3626", "#2d2018")
    trunk(rig, "cyp_trunk", [(0, 0, 0), (0, 0, 1.4)], [0.18, 0.15], b)
    H = 14.0
    prof = []
    for i in range(25):
        t = i / 24
        r = 1.25 * math.sin(math.pi * min(1.0, t * 1.15) ** 0.6) * (1 - t) ** 0.35 + 0.02
        prof.append((max(r, 0.02), 0.9 + t * (H - 0.9)))
    prof[0] = (0.25, 0.9)
    prof[-1] = (0.01, H)
    bm = MU.bm_lathe(prof, segs=20)
    ob = MU.make("cypress", bm, lv, parent=rig.root, smooth=True, sharp_deg=80)
    MU.displace(ob, 0.35, size=0.45, seed=s)
    return dict(object=obj_size(2.8, H))


def tree_olive(rig, p):
    s = p.get("seed", 17)
    b = bark("olive_bark", "#5c5246", "#3a332b", scale=5.0)
    lv = leaves("olive_leaves", "#6f7d4f", "#9aa77a", scale=2.4)
    trunk(rig, "olive_t1", [(0, 0, 0), (0.25, 0.1, 0.8), (0.0, 0.0, 1.6), (0.45, 0.1, 2.4)], [0.42, 0.3, 0.26, 0.16], b)
    trunk(rig, "olive_t2", [(0.05, 0, 0.6), (-0.5, 0.1, 1.5), (-0.9, 0.0, 2.3)], [0.22, 0.17, 0.12], b)
    branch_set(rig, "olive_br", 1.8, 2.6, 6, 2.6, b, s, r=0.09, spread=1.2, up=0.45)
    crown(rig, "olive_crown", (0, 0, 3.6), 3.4, 3.0, 1.6, 40, 0.7, 1.2, lv, s, disp=0.3, shell=0.7)
    return dict(object=obj_size(7.4, 5.4))


def tree_palm(rig, p):
    s = p.get("seed", 29)
    rng = random.Random(s)
    b = bark("palm_bark", "#8a7458", "#5e4d38", scale=3.0, rings=26.0)
    lv = leaves("palm_leaves", "#3f7a2a", "#6f9a38", scale=3.0, bump=0.3)
    pts, rad = [], []
    for i in range(10):
        t = i / 9
        pts.append((0.9 * math.sin(t * 1.4) - 0.2 * t, 0.0, t * 9.6))
        rad.append(0.24 - 0.07 * t)
    trunk(rig, "palm_trunk", pts, rad, b, segs=12)
    top = Vector(pts[-1])
    bm = bmesh.new()
    nfr = 13
    for k in range(nfr):
        a = 2 * math.pi * k / nfr + rng.uniform(-0.15, 0.15)
        ln = rng.uniform(3.6, 4.6)
        lift = rng.uniform(0.6, 1.4)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        side = Vector((-d.y, d.x, 0.0))
        segs = 12
        left, mid, right = [], [], []
        for i in range(segs + 1):
            t = i / segs
            pos = top + d * (ln * t) + Vector((0, 0, lift * math.sin(t * math.pi * 0.8) - 1.6 * t * t))
            w = 0.55 * math.sin(math.pi * min(1.0, t * 1.1)) + 0.03
            jag = 0.18 if i % 2 else 0.0
            mid.append(pos)
            left.append(pos + side * (w - jag * w) + Vector((0, 0, -0.12 * w)))
            right.append(pos - side * (w - jag * w) + Vector((0, 0, -0.12 * w)))
        vl = [bm.verts.new(v) for v in left]
        vm = [bm.verts.new(v) for v in mid]
        vr = [bm.verts.new(v) for v in right]
        for i in range(segs):
            bm.faces.new((vl[i], vm[i], vm[i + 1], vl[i + 1]))
            bm.faces.new((vm[i], vr[i], vr[i + 1], vm[i + 1]))
    ob = MU.make("palm_fronds", bm, lv, parent=rig.root, smooth=True, sharp_deg=70)
    MU.solidify(ob, 0.03)
    bm = bmesh.new()
    for k in range(5):
        a = k * 1.3
        MU.bm_sphere(0.16, center=(top.x + math.cos(a) * 0.25, math.sin(a) * 0.25, top.z - 0.35), subdiv=1, bm=bm)
    MU.make("palm_nuts", bm, M.basic("palm_nut", "#5a4a22", rough=0.6), parent=rig.root, smooth=True)
    return dict(object=obj_size(8.5, 11.0))


# --- bushes, heather, rocks, cliff, hay -----------------------------------------------------------

def bush_round(rig, p):
    lv = leaves("bush_leaves", "#3f6b28", "#5f8a33", scale=2.2)
    crown(rig, "bush", (0, 0, 1.0), 1.4, 1.3, 1.05, 22, 0.55, 0.85, lv, p.get("seed", 41), disp=0.25, flat_bottom=-0.9)
    return dict(object=obj_size(3.0, 2.2))


def bush_low(rig, p):
    lv = leaves("bushl_leaves", "#466f2c", "#6a9037", scale=2.4)
    crown(rig, "bushl", (0, 0, 0.55), 2.3, 1.2, 0.55, 26, 0.45, 0.7, lv, p.get("seed", 43), disp=0.2, flat_bottom=-0.45)
    return dict(object=obj_size(5.0, 1.3))


def heather(rig, p):
    rng = random.Random(p.get("seed", 47))
    pink = leaves("heather_pink", "#8a4a86", "#b46aa8", scale=4.0, bump=0.5)
    green = leaves("heather_green", "#4d5a2c", "#6b7034", scale=4.0, bump=0.5)
    for mat, n in ((pink, 26), (green, 14)):
        bm = bmesh.new()
        for i in range(n):
            x = rng.uniform(-2.4, 2.4)
            y = rng.uniform(-0.2, 2.2)
            r = rng.uniform(0.28, 0.5)
            MU.bm_sphere(r, center=(x, y, r * 0.45), scale=(1.3, 1.3, 0.8), subdiv=2, bm=bm)
        ob = MU.make("heather", bm, mat, parent=rig.root, smooth=True, sharp_deg=80)
        MU.displace(ob, 0.15, size=0.18, seed=n)
    return dict(object=obj_size(5.6, 0.75, 2.6))


def _boulder(rig, name, center, scale, mat, seed, disp=0.5, subdiv=3):
    bm = MU.bm_sphere(1.0, center=center, scale=scale, subdiv=subdiv)
    ob = MU.make(name, bm, mat, parent=rig.root, smooth=True, sharp_deg=60)
    MU.displace(ob, disp, size=0.9, kind="CLOUDS", depth=3, seed=seed)
    m = ob.modifiers.new("vor", "DISPLACE")
    import bpy
    tex = bpy.data.textures.new(name + "_v", "VORONOI")
    tex.noise_scale = 0.8
    m.texture = tex
    m.strength = disp * 0.6
    return ob


def rock_a(rig, p):
    mat = rock("rock_a", "#8f8b83", "#6f6b65", moss="#5d6b3a")
    _boulder(rig, "rock_a", (0, 1.0, 0.55), (1.45, 1.2, 1.0), mat, 3, disp=0.45)
    _boulder(rig, "rock_a2", (1.35, 0.5, 0.2), (0.55, 0.5, 0.42), mat, 5, disp=0.2)
    return dict(object=obj_size(3.6, 1.6, 2.4))


def rock_b(rig, p):
    mat = rock("rock_b", "#9a9387", "#77716a")
    _boulder(rig, "rock_b1", (-0.6, 0.8, 0.3), (1.2, 0.9, 0.55), mat, 7, disp=0.35)
    _boulder(rig, "rock_b2", (0.9, 0.6, 0.25), (0.8, 0.7, 0.45), mat, 9, disp=0.3)
    _boulder(rig, "rock_b3", (0.2, 1.4, 0.55), (0.7, 0.6, 0.75), mat, 11, disp=0.3)
    return dict(object=obj_size(3.8, 1.3, 2.4))


def cliff(rig, p):
    mat = rock("cliff_rock", "#8c857a", "#6a645c", moss="#56633a")
    bm = bmesh.new()
    res = bmesh.ops.create_grid(bm, x_segments=60, y_segments=36, size=1.0)
    for v in res["verts"]:
        x = v.co.x * 13.0
        z = (v.co.y + 1.0) * 7.0
        edge = max(0.0, 1.0 - (abs(x) / 13.0) ** 4)
        top = 14.0 * (0.75 + 0.25 * math.sin(x * 0.45) * math.cos(x * 0.17)) * (0.35 + 0.65 * edge)
        zz = min(z, top)
        lean = 1.5 + 2.5 * (zz / 14.0)
        v.co = Vector((x, lean, zz))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.y > 0:
            f.normal_flip()
    ob = MU.make("cliff", bm, mat, parent=rig.root, smooth=True, sharp_deg=60)
    MU.solidify(ob, 2.0, offset=1.0)
    MU.displace(ob, 1.6, size=2.2, kind="CLOUDS", depth=3, seed=5)
    import bpy
    m = ob.modifiers.new("vor", "DISPLACE")
    tex = bpy.data.textures.new("cliff_v", "VORONOI")
    tex.noise_scale = 1.8
    m.texture = tex
    m.strength = 1.1
    _boulder(rig, "cliff_rb", (-5.0, 0.4, 0.4), (1.1, 0.9, 0.7), mat, 13, disp=0.3)
    _boulder(rig, "cliff_rb2", (6.5, 0.6, 0.3), (0.8, 0.7, 0.5), mat, 15, disp=0.25)
    lv = leaves("cliff_shrub", "#4a6a2c", "#6a8a36", scale=2.0)
    crown(rig, "cliff_shrubs", (2.0, 2.0, 11.0), 8.0, 1.0, 1.5, 12, 0.5, 0.9, lv, 17, disp=0.2)
    return dict(object=obj_size(26.0, 14.0, 5.0))


def haybale(rig, p):
    mat = straw("straw")
    prof = [(0.0, -0.6), (0.68, -0.6), (0.74, -0.55), (0.76, -0.4), (0.76, 0.4), (0.74, 0.55), (0.68, 0.6), (0.0, 0.6)]
    for (x, y) in ((-0.85, 0.75), (0.85, 0.9)):
        bm = MU.bm_lathe(prof, segs=28, axis="Y")
        MU.make("bale", bm, mat, parent=rig.root, smooth=True, sharp_deg=50, loc=(x, y, 0.75))
    return dict(object=obj_size(3.4, 1.5, 1.4))
