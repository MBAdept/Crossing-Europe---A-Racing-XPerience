"""Road furniture and infrastructure: streetlight, delineator (German Leitpfosten), radar camera,
wind turbine, power pylon, fuel station + pump island, customs booth, ferry ship (side view)."""
import math
import random

import bmesh
from mathutils import Vector

from . import materials as M
from . import meshutil as MU
from .props_buildings import facade, obj_size

LAMP = "#fff0cf"


def _galv(name="galv"):
    return M.basic(name, "#9ea3a8", rough=0.45, metal=0.7, color2="#868b90", var_scale=2.0)


def streetlight(rig, p):
    pole = _galv("sl_pole")
    bm = MU.bm_cyl(0.11, 0.065, 8.6, center=(0.0, 0.0, 4.3), segs=12)
    MU.bm_cyl(0.16, 0.16, 0.6, center=(0.0, 0.0, 0.3), segs=12, bm=bm)
    pts = [(0.0, 0.0, 8.5), (-0.25, 0.0, 9.05), (-0.8, 0.0, 9.3), (-1.7, 0.0, 9.35)]
    for a, b in zip(pts[:-1], pts[1:]):
        MU.bm_beam(a, b, 0.09, 0.09, bm=bm)
    MU.make("sl_pole", bm, pole, parent=rig.root, smooth=True, sharp_deg=40)
    head = M.basic("sl_head", "#5d6268", rough=0.4, metal=0.5)
    bm = MU.bm_box(0.75, 0.32, 0.12, (-1.95, 0.0, 9.33))
    ob = MU.make("sl_head", bm, head, parent=rig.root)
    MU.bevel(ob, 0.04, 2)
    lens = M.basic("sl_lens", "#e9e6da", rough=0.2, coat=0.4, emit={"lights": (LAMP, 14.0)})
    bm = MU.bm_sphere(1.0, center=(-1.97, 0.0, 9.24), scale=(0.3, 0.13, 0.07), subdiv=2)
    MU.make("sl_lens", bm, lens, parent=rig.root, smooth=True)
    light_cone(rig, "sl_cone", (-1.97, 0.0, 9.17), 9.17, 2.3, 0.038)
    return dict(object=obj_size(2.4, 9.45))


def light_cone(rig, name, apex, height, radius, strength):
    """Faint cone of light under a lamp: transparent by day, soft glow in the 'lights' layer."""
    m, nb = M.new_material(name)
    x, y, z = nb.coords()
    tr = nb.node("ShaderNodeBsdfTransparent")
    t = nb.math("DIVIDE", nb.sub(apex[2], z), height)          # 0 at the lamp, 1 at the ground
    fade = nb.mul(nb.math("POWER", nb.sub(1.0, t), 1.4), nb.madd(t, 0.0, 1.0))
    col = nb.color_scale(M.emit_col(LAMP, strength), fade)
    mat = M.finish(m, nb, tr.outputs[0], {"lights": col})
    bm = MU.bm_cyl(radius, 0.12, height, center=(apex[0], apex[1], apex[2] - height / 2), segs=20, caps=False)
    ob = MU.make(name, bm, mat, parent=rig.root, smooth=True)
    ob.visible_shadow = False
    return ob


def delineator(rig, p):
    m, nb = M.new_material("leitpfosten")
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    band = nb.gt(z, 0.72)
    col = nb.mix(band, M.srgb("#f1f1ec"), M.srgb("#141414"))
    refl = nb.AND(nb.lt(ny, -0.5), nb.band(z, 0.80, 0.97), nb.lt(nb.absf(x), 0.022))
    col = nb.mix(refl, col, M.srgb("#e8b25a"))
    out = M.principled(nb, col, rough=nb.mixf(refl, 0.45, 0.15), spec=0.5)
    mat = M.finish(m, nb, out, {"lights": nb.color_scale(M.emit_col("#ffc070", 5.0), refl)})
    # trapezoid cross-section (12 cm wide at the road side), sloped top
    pts = [(-0.06, -0.02), (0.06, -0.02), (0.035, 0.08), (-0.035, 0.08)]
    bm = bmesh.new()
    bot = [bm.verts.new((px, py, 0.0)) for (px, py) in pts]
    top = [bm.verts.new((px, py, 1.0 - (py + 0.02) * 0.6)) for (px, py) in pts]
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    MU.make("leitpfosten", bm, mat, parent=rig.root)
    return dict(object=obj_size(0.12, 1.0, 0.1))


def radar_camera(rig, p):
    m, nb = M.new_material("radar_body")
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    col = M.srgb("#c9ccd0")
    win = nb.AND(nb.band(z, 2.05, 2.75), nb.lt(ny, -0.3))
    col = nb.mix(win, col, M.srgb("#16191c"))
    stripe = nb.AND(nb.band(z, 0.25, 0.55), nb.gt(nb.math("FLOORED_MODULO", nb.add(z, x), 0.16), 0.08))
    col = nb.mix(stripe, col, M.srgb("#e0b21c"))
    stripe2 = nb.AND(nb.band(z, 0.25, 0.55), nb.lt(nb.math("FLOORED_MODULO", nb.add(z, x), 0.16), 0.08))
    col = nb.mix(stripe2, col, M.srgb("#1a1a1a"))
    out = M.principled(nb, col, rough=nb.mixf(win, 0.35, 0.05), metal=0.4, spec=0.7)
    mat = M.finish(m, nb, out)
    prof = [(0.0, 0.0), (0.3, 0.0), (0.3, 0.25), (0.24, 0.3), (0.24, 2.9), (0.2, 3.02), (0.0, 3.05)]
    bm = MU.bm_lathe(prof, segs=16)
    for v in bm.verts:
        v.co.y *= 0.8
    MU.make("radar", bm, mat, parent=rig.root, smooth=True, sharp_deg=40)
    lens = M.basic("radar_lens", "#30363c", rough=0.05, metal=0.8)
    bm = bmesh.new()
    for (xx, zz, r) in ((-0.08, 2.5, 0.055), (0.09, 2.5, 0.045), (0.0, 2.22, 0.06)):
        MU.bm_cyl(r, r, 0.04, center=(xx, -0.2, zz), axis="Y", segs=14, bm=bm)
    MU.make("radar_lens", bm, lens, parent=rig.root)
    base = M.basic("radar_base", "#8f8f8a", rough=0.9)
    bm = MU.bm_box(0.9, 0.8, 0.12, (0.0, 0.0, 0.06))
    MU.make("radar_base", bm, base, parent=rig.root)
    return dict(object=obj_size(0.9, 3.05, 0.8))


def wind_turbine(rig, p):
    white = M.basic("wt_white", "#eef0f1", rough=0.35, spec=0.5)
    H = 88.0
    prof = [(0.0, 0.0), (2.2, 0.0), (2.15, 0.4), (1.25, H), (0.0, H)]
    bm = MU.bm_lathe(prof, segs=20)
    MU.make("wt_tower", bm, white, parent=rig.root, smooth=True, sharp_deg=40)
    bm = MU.bm_box(3.6, 10.5, 3.8, (0.0, 3.6, H + 1.6))
    ob = MU.make("wt_nacelle", bm, white, parent=rig.root)
    MU.bevel(ob, 0.8, 3)
    bm = MU.bm_sphere(1.6, center=(0.0, -2.2, H + 1.6), scale=(1.0, 1.6, 1.0), subdiv=3)
    MU.make("wt_hub", bm, white, parent=rig.root, smooth=True)
    bm = bmesh.new()
    hub = Vector((0.0, -2.6, H + 1.6))
    for k in range(3):
        a = math.radians(90 + 120 * k)
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        n = Vector((-d.z, 0.0, d.x))
        segs = 12
        lead, trail = [], []
        for i in range(segs + 1):
            t = i / segs
            r = 1.4 + t * 43.0
            chord = (3.6 * (1 - t) ** 1.2 + 0.4) * (0.6 + 0.4 * min(1.0, t * 6))
            c = hub + d * r
            tw = math.radians(15 * (1 - t))
            lead.append(c + n * chord * 0.35 + Vector((0, -math.sin(tw) * chord * 0.3, 0)))
            trail.append(c - n * chord * 0.65 + Vector((0, math.sin(tw) * chord * 0.3, 0)))
        vl = [bm.verts.new(v) for v in lead]
        vt = [bm.verts.new(v) for v in trail]
        for i in range(segs):
            bm.faces.new((vl[i], vt[i], vt[i + 1], vl[i + 1]))
    ob = MU.make("wt_blades", bm, white, parent=rig.root, smooth=True, sharp_deg=60)
    MU.solidify(ob, 0.35, offset=0.0)
    red = M.basic("wt_red", "#a31212", rough=0.3, emit={"lights": ("#ff1a10", 10.0)})
    # aviation light on a short mast at the rear of the nacelle roof, left of the upward blade root
    bm = MU.bm_cyl(0.06, 0.06, 1.6, center=(-1.25, 7.2, H + 4.2), segs=6)
    MU.bm_cyl(0.34, 0.34, 0.45, center=(-1.25, 7.2, H + 5.2), segs=10, bm=bm)
    MU.make("wt_light", bm, red, parent=rig.root)
    return dict(object=obj_size(88.0, H + 45.6, 12.0))


def power_pylon(rig, p):
    steel = M.basic("pyl_steel", "#8e959b", rough=0.5, metal=0.6)
    bm = bmesh.new()
    H = 44.0

    def half(z):
        # half width of the tower body at height z
        if z < 24.0:
            return 3.6 - (3.6 - 1.1) * z / 24.0
        return 1.1 - 0.35 * (z - 24.0) / (H - 24.0)

    levels = [0.0, 4.5, 9.0, 13.0, 17.0, 20.5, 24.0, 27.0, 30.0, 33.0, 36.5, 40.0, H]
    for i in range(len(levels) - 1):
        z0, z1 = levels[i], levels[i + 1]
        h0, h1 = half(z0), half(z1)
        corners0 = [(-h0, -h0), (h0, -h0), (h0, h0), (-h0, h0)]
        corners1 = [(-h1, -h1), (h1, -h1), (h1, h1), (-h1, h1)]
        for k in range(4):
            a0 = (*corners0[k], z0)
            a1 = (*corners1[k], z1)
            MU.bm_beam(a0, a1, 0.22, 0.22, bm=bm)
            b0 = (*corners0[(k + 1) % 4], z0)
            b1 = (*corners1[(k + 1) % 4], z1)
            MU.bm_beam(a0, b1, 0.09, 0.09, bm=bm)
            MU.bm_beam(b0, a1, 0.09, 0.09, bm=bm)
            MU.bm_beam(a1, b1, 0.11, 0.11, bm=bm)
    # cross arms (Donau type: wide lower arm, narrower upper arm), earth wire peak
    for (z, span) in ((24.0, 8.5), (33.0, 6.0)):
        for side in (-1, 1):
            tip = (side * span, 0.0, z)
            for yy in (-0.9, 0.9):
                MU.bm_beam((side * half(z), yy, z), (side * span, yy * 0.2, z), 0.14, 0.14, bm=bm)
                MU.bm_beam((side * half(z + 2.6), yy, z + 2.6), (side * span, yy * 0.2, z), 0.1, 0.1, bm=bm)
            for t in (0.35, 0.7):
                x = side * (half(z) + (span - half(z)) * t)
                MU.bm_beam((x, -0.6, z), (x, 0.6, z), 0.07, 0.07, bm=bm)
    MU.bm_beam((-1.0, 0, H), (0.0, 0.0, H + 3.0), 0.12, 0.12, bm=bm)
    MU.bm_beam((1.0, 0, H), (0.0, 0.0, H + 3.0), 0.12, 0.12, bm=bm)
    MU.make("pylon", bm, steel, parent=rig.root)
    glass = M.basic("pyl_ins", "#5f6f7d", rough=0.2, metal=0.2)
    bm = bmesh.new()
    for (z, span) in ((24.0, 8.5), (33.0, 6.0)):
        for side in (-1, 1):
            for xo in (0.0, -side * (span * 0.45)):
                x = side * span + xo
                for i in range(8):
                    MU.bm_cyl(0.22, 0.22, 0.12, center=(x, 0.0, z - 0.4 - i * 0.38), segs=10, bm=bm)
                MU.bm_cyl(0.04, 0.04, 3.3, center=(x, 0.0, z - 1.7), segs=6, bm=bm)
    MU.make("pylon_ins", bm, glass, parent=rig.root)
    return dict(object=obj_size(17.5, H + 3.0, 7.2))


# --- fuel station ---------------------------------------------------------------------------------

def _dispenser(rig, name, x, y, z0=0.15, accent="#1f8a4c", rot=0.0):
    m, nb = M.new_material(name)
    xx, yy, zz = nb.coords()
    nx, ny, nz = nb.normal()
    col = M.srgb("#eceeef")
    top = nb.gt(zz, z0 + 1.55)
    col = nb.mix(top, col, M.srgb(accent))
    disp = nb.AND(nb.band(zz, z0 + 1.05, z0 + 1.4), nb.lt(nb.absf(nb.sub(xx, x)), 0.3), nb.gt(nb.absf(ny), 0.5))
    col = nb.mix(disp, col, M.srgb("#1b2228"))
    holst = nb.AND(nb.band(zz, z0 + 0.55, z0 + 0.9), nb.lt(nb.absf(nb.sub(xx, x)), 0.32), nb.gt(nb.absf(ny), 0.5))
    col = nb.mix(holst, col, M.srgb("#2b2d30"))
    out = M.principled(nb, col, rough=0.35, spec=0.5)
    em = nb.color_scale(M.emit_col("#bfe8ff", 2.5), disp)
    em = nb.vadd(em, nb.color_scale(M.emit_col(accent, 1.2), top))
    mat = M.finish(m, nb, out, {"lights": em})
    bm = MU.bm_box(0.95, 0.5, 1.85, (x, y, z0 + 0.925))
    ob = MU.make(name, bm, mat, parent=rig.root)
    MU.bevel(ob, 0.04, 2)
    return ob


def _island(rig, name, x, y, length=3.8):
    conc = M.basic(name + "_c", "#b5b3ad", rough=0.85, color2="#9f9d97", var_scale=2.0)
    bm = MU.bm_box(1.1, length, 0.15, (x, y, 0.075))
    ob = MU.make(name, bm, conc, parent=rig.root)
    MU.bevel(ob, 0.04, 2)
    m, nb = M.new_material(name + "_bol")
    xx, yy, zz = nb.coords()
    stripe = nb.lt(nb.math("FLOORED_MODULO", zz, 0.3), 0.15)
    col = nb.mix(stripe, M.srgb("#e7b917"), M.srgb("#1b1b1b"))
    bol = M.finish(m, nb, M.principled(nb, col, rough=0.4, spec=0.4))
    bm = bmesh.new()
    for yy_ in (y - length / 2 + 0.2, y + length / 2 - 0.2):
        MU.bm_cyl(0.07, 0.07, 1.0, center=(x, yy_, 0.65), segs=10, bm=bm)
    MU.make(name + "_bollards", bm, bol, parent=rig.root, smooth=True)


def fuel_pump(rig, p):
    _island(rig, "fp_island", 0.0, 1.9)
    _dispenser(rig, "fp_disp", 0.0, 1.9)
    hose = M.basic("fp_hose", "#151515", rough=0.6)
    bm = bmesh.new()
    for side in (-1, 1):
        MU.bm_beam((side * 0.4, 1.64, 1.3), (side * 0.6, 1.5, 0.75), 0.04, bm=bm)
        MU.bm_beam((side * 0.6, 1.5, 0.75), (side * 0.48, 1.62, 0.9), 0.04, bm=bm)
    MU.make("fp_hose", bm, hose, parent=rig.root)
    # slim lamp column with a small roof light: makes the fuel lane readable at night
    pole = _galv("fp_pole")
    bm = MU.bm_box(0.12, 0.12, 4.2, (0.0, 3.6, 2.1))
    MU.bm_box(1.2, 0.5, 0.18, (0.0, 3.4, 4.25), bm=bm)
    MU.make("fp_pole", bm, pole, parent=rig.root)
    lens = M.basic("fp_lens", "#e8e6dd", rough=0.2, emit={"lights": (LAMP, 10.0)})
    bm = MU.bm_box(1.0, 0.4, 0.03, (0.0, 3.4, 4.15))
    MU.bm_box(1.0, 0.03, 0.12, (0.0, 3.14, 4.22), bm=bm)
    MU.make("fp_lens", bm, lens, parent=rig.root)
    return dict(object=obj_size(1.3, 4.35, 3.8))


def fuel_station(rig, p):
    accent = "#1f8a4c"
    # canopy
    cw, cd, ch = 15.0, 9.0, 4.9
    m, nb = M.new_material("fs_canopy")
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    band = nb.AND(nb.band(z, ch + 0.25, ch + 0.75), nb.lt(nb.absf(nz), 0.5))
    col = nb.mix(band, M.srgb("#f2f2ee"), M.srgb(accent))
    stripe = nb.AND(nb.band(z, ch + 0.08, ch + 0.2), nb.lt(nb.absf(nz), 0.5))
    col = nb.mix(stripe, col, M.srgb("#e8c21c"))
    lamps = nb.AND(nb.band(z, ch - 0.01, ch + 0.06), nb.lt(ny, -0.5),
                   nb.lt(nb.math("FLOORED_MODULO", x, 1.5), 0.9))
    col = nb.mix(lamps, col, M.srgb("#fff8e6"))
    out = M.principled(nb, col, rough=0.35, spec=0.5)
    em = nb.vadd(nb.color_scale(M.emit_col(accent, 1.6), band), nb.color_scale(M.emit_col(LAMP, 12.0), lamps))
    em = nb.vadd(em, nb.color_scale(M.emit_col("#ffe27a", 1.2), stripe))
    can = M.finish(m, nb, out, {"lights": em})
    bm = MU.bm_box(cw, cd, 0.9, (0.0, 1.2 + cd / 2, ch + 0.45))
    ob = MU.make("fs_canopy", bm, can, parent=rig.root)
    MU.bevel(ob, 0.06, 2)
    col_m = M.basic("fs_col", "#e9e9e5", rough=0.5)
    bm = bmesh.new()
    for xx in (-4.2, 4.2):
        for yy in (3.0, 8.4):
            MU.bm_box(0.45, 0.45, ch, (xx, yy, ch / 2), bm=bm)
    MU.make("fs_columns", bm, col_m, parent=rig.root)
    for i, xx in enumerate((-4.2, 0.0, 4.2)):
        _island(rig, "fs_isl%d" % i, xx, 5.7, length=4.2)
        _dispenser(rig, "fs_disp%d" % i, xx, 5.7, accent=accent)
    # light haze under the canopy (invisible by day, warm glow in the night layer)
    hm, hb = M.new_material("fs_haze")
    hx, hy, hz = hb.coords()
    tr = hb.node("ShaderNodeBsdfTransparent")
    grad = hb.math("POWER", hb.math("DIVIDE", hz, ch), 1.6)
    edge = hb.math("MINIMUM", 1.0, hb.math("DIVIDE", hb.sub(cw / 2, hb.absf(hx)), 1.5))
    hcol = hb.color_scale(M.emit_col(LAMP, 0.16), hb.mul(hb.math("POWER", grad, 1.5), edge))
    haze = M.finish(hm, hb, tr.outputs[0], {"lights": hcol})
    bm = bmesh.new()
    v = [bm.verts.new(q) for q in [(-cw / 2 + 0.3, 2.0, 0.0), (cw / 2 - 0.3, 2.0, 0.0), (cw / 2 - 0.3, 2.0, ch), (-cw / 2 + 0.3, 2.0, ch)]]
    bm.faces.new(v)
    hob = MU.make("fs_haze", bm, haze, parent=rig.root)
    hob.visible_shadow = False
    # shop
    shop = facade("fs_shop", "#eeeeea", [
        dict(face="front", u=(-5.3, 5.3), z=(0.2, 3.0), pitch=(3.5, 3.0), win=(3.2, 2.6), lit=1.0,
             color="#ffe9c4", strength=1.25, frame="#3a3d40", glass="#34434e"),
    ], frame="#3a3d40", decals=[dict(face="front", sym=True, poly=[(0.0, 3.25), (5.6, 3.25), (5.6, 3.85), (0.0, 3.85)],
                                     mat=accent, emit={"lights": (accent, 1.5)})])
    bm = MU.bm_box(11.0, 9.0, 4.1, (14.0, 7.5, 2.05))
    ob = MU.make("fs_shop", bm, shop, parent=rig.root)
    ob.location = (0, 0, 0)
    # the facade grid uses object coordinates: shift the mesh so the shop front is centred at x=0
    for vtx in ob.data.vertices:
        vtx.co.x -= 14.0
    ob.location = (14.0, 0.0, 0.0)
    roof = M.basic("fs_shoproof", "#7d8187", rough=0.6)
    bm = MU.bm_box(11.4, 9.4, 0.3, (14.0, 7.5, 4.25))
    MU.make("fs_shoproof", bm, roof, parent=rig.root)
    # price pylon (blank panels, lit at night)
    m, nb = M.new_material("fs_pylon")
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    pan = nb.AND(nb.lt(ny, -0.5), nb.band(z, 2.2, 5.6), nb.lt(nb.math("FLOORED_MODULO", z, 0.85), 0.62),
                 nb.lt(nb.absf(nb.add(x, 9.0)), 0.65))
    head = nb.AND(nb.lt(ny, -0.5), nb.band(z, 5.9, 6.8))
    col = nb.mix(head, M.srgb(accent), M.srgb(accent))
    col = nb.mix(pan, col, M.srgb("#1c1f22"))
    out = M.principled(nb, col, rough=0.4, spec=0.5)
    em = nb.vadd(nb.color_scale(M.emit_col("#ffb347", 3.0), pan), nb.color_scale(M.emit_col("#ffffff", 0.8), head))
    pyl = M.finish(m, nb, out, {"lights": em})
    bm = MU.bm_box(1.6, 0.5, 7.0, (-9.0, 1.5, 3.5))
    ob = MU.make("fs_pylon", bm, pyl, parent=rig.root)
    MU.bevel(ob, 0.05, 2)
    return dict(object=obj_size(31.0, 7.0, 12.0))


def customs_booth(rig, p):
    W, D, H = 3.2, 2.6, 2.7
    wall = facade("cb_wall", "#e9e9e4", [
        dict(face="front", u=(-1.5, 1.5), z=(0.95, 2.35), pitch=(3.0, 1.4), win=(2.7, 1.25), lit=1.0,
             color="#ffeccc", strength=1.4, frame="#4a4f55"),
        dict(face="side", u=(0.1, 2.5), z=(0.95, 2.35), pitch=(2.4, 1.4), win=(2.1, 1.25), lit=1.0,
             color="#ffeccc", strength=1.4, frame="#4a4f55"),
    ], frame="#4a4f55", decals=[dict(face="front", sym=True, poly=[(0.0, 0.0), (1.6, 0.0), (1.6, 0.35), (0.0, 0.35)], mat="#5d6268")])
    walls(rig, "cb_walls", W, D, H, wall)
    m, nb = M.new_material("cb_roof")
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    stripe = nb.AND(nb.lt(nb.absf(nz), 0.5), nb.lt(nb.math("FLOORED_MODULO", nb.add(x, y), 0.8), 0.4))
    col = nb.mix(stripe, M.srgb("#f1f1ed"), M.srgb("#c1272d"))
    roof = M.finish(m, nb, M.principled(nb, col, rough=0.5, spec=0.4))
    bm = MU.bm_box(4.4, 3.8, 0.35, (0.0, D / 2, H + 0.18))
    ob = MU.make("cb_roof", bm, roof, parent=rig.root)
    MU.bevel(ob, 0.03, 1)
    lamp = M.basic("cb_lamp", "#fff1c9", rough=0.3, emit={"lights": ("#ffe2a0", 9.0)})
    bm = MU.bm_box(0.5, 0.2, 0.15, (0.0, -0.6, H + 0.02))
    MU.make("cb_lamp", bm, lamp, parent=rig.root)
    return dict(object=obj_size(4.4, H + 0.35, 3.8))


def walls(rig, name, w, d, h, mat, y0=0.0):
    bm = MU.bm_box(w, d, h, (0.0, y0 + d / 2, h / 2))
    ob = MU.make(name, bm, mat, parent=rig.root)
    MU.bevel(ob, 0.03, 1)
    return ob


# --- ferry ----------------------------------------------------------------------------------------

def ferry_ship(rig, p):
    """Ro-pax ferry, length along +y (bow at +y), origin at the waterline mid-ship."""
    L, B = 182.0, 28.0
    y0 = -L / 2
    hull_top = 11.0
    m, nb = M.new_material("ferry_hull")
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    col = M.srgb("#f1f1ed")
    col = nb.mix(nb.lt(z, 7.0), col, M.srgb("#1d3557"))
    col = nb.mix(nb.lt(z, 1.1), col, M.srgb("#9b2222"))
    # portholes row
    ph = nb.AND(nb.band(z, 8.0, 9.0), nb.lt(nb.math("FLOORED_MODULO", y, 3.0), 1.2), nb.band(y, -70, 75))
    col = nb.mix(ph, col, M.srgb("#20262c"))
    stripe = nb.band(z, 10.0, 10.5)
    col = nb.mix(stripe, col, M.srgb("#2a6db0"))
    out = M.principled(nb, col, rough=0.4, spec=0.5)
    hull_em = nb.color_scale(M.emit_col(WARM_SHIP, 1.8), nb.mul(ph, nb.lt(nb.math("FLOORED_MODULO", nb.mul(y, 0.37), 1.0), 0.7)))
    hull = M.finish(m, nb, out, {"lights": hull_em})
    stations = []
    for i in range(61):
        t = i / 60.0
        yy = y0 + t * L
        stations.append(yy)
    rings = []
    for yy in stations:
        t = (yy - y0) / L
        # plan: transom at the stern, fine bow
        if t > 0.8:
            k = (t - 0.8) / 0.2
            w = B / 2 * (1 - k ** 1.8 * 0.97)
        elif t < 0.05:
            w = B / 2 * (0.92 + 0.08 * t / 0.05)
        else:
            w = B / 2
        bot = -1.0 + (t > 0.9) * 0.0
        top = hull_top + (2.5 * ((t - 0.75) / 0.25) ** 2 if t > 0.75 else 0.0)
        half = [(0.0, bot), (w * 0.95, bot), (w, bot + 0.6), (w, top - 0.3), (w * 0.98, top), (0.0, top)]
        rings.append([(xx, yy, zz) for (xx, zz) in MU.mirror_ring(half)])
    MU.make("ferry_hull", MU.loft(rings), hull, parent=rig.root, smooth=True, sharp_deg=35)
    # superstructure decks
    sup = facade("ferry_sup", "#f3f3ef", [
        dict(face="side", u=(-62.0, 58.0), z=(hull_top + 0.6, hull_top + 14.0), pitch=(2.2, 2.8), win=(1.6, 1.3),
             lit=0.55, glass="#25313b", frame="#f3f3ef"),
        dict(face="back", u=(-12.0, 12.0), z=(hull_top + 9.0, hull_top + 16.4), pitch=(1.6, 2.6), win=(1.4, 1.5),
             lit=0.6, glass="#25313b"),
    ], frame="#f3f3ef", strength=2.0)
    decks = [(-64.0, 60.0, hull_top, hull_top + 8.6), (-58.0, 54.0, hull_top + 8.6, hull_top + 14.2),
             (20.0, 52.0, hull_top + 14.2, hull_top + 17.2)]
    for i, (ya, yb, za, zb) in enumerate(decks):
        bm = MU.bm_box(B - 2.0 - i * 2.0, yb - ya, zb - za, (0.0, (ya + yb) / 2, (za + zb) / 2))
        ob = MU.make("ferry_deck%d" % i, bm, sup, parent=rig.root)
        MU.bevel(ob, 0.6, 2)
    # bridge windows (front of the top deck)
    bridge = M.basic("ferry_bridge", "#1e2830", rough=0.05, metal=0.3, emit={"lights": ("#ffd9a0", 1.5)})
    bm = MU.bm_box(B - 5.0, 0.4, 1.6, (0.0, 52.1, hull_top + 15.9))
    MU.make("ferry_bridge", bm, bridge, parent=rig.root)
    # funnel
    fun = M.surface("ferry_funnel", "#f3f3ef", metal=0.1, rough=0.4, coat=0.2,
                    livery=[dict(z=(hull_top + 20.5, hull_top + 23.0), color="#2a6db0"),
                            dict(z=(hull_top + 24.5, hull_top + 26.5), color="#1b1c1e")])
    bm = MU.bm_box(5.0, 9.0, 12.0, (0.0, -30.0, hull_top + 20.5))
    ob = MU.make("ferry_funnel", bm, fun, parent=rig.root)
    MU.bevel(ob, 1.2, 3)
    # lifeboats along the upper deck
    boat = M.basic("ferry_boat", "#e86d1c", rough=0.4, coat=0.4)
    bm = bmesh.new()
    for i in range(7):
        yy = -50.0 + i * 13.0
        for side in (-1, 1):
            MU.bm_sphere(1.0, center=(side * (B / 2 - 2.6), yy, hull_top + 9.6), scale=(1.3, 4.2, 1.0), subdiv=2, bm=bm)
    MU.make("ferry_boats", bm, boat, parent=rig.root, smooth=True)
    # mast + nav lights
    mast = M.basic("ferry_mast", "#d7d9db", rough=0.4, metal=0.5)
    bm = MU.bm_cyl(0.35, 0.2, 9.0, center=(0.0, 38.0, hull_top + 21.7), segs=8)
    MU.bm_beam((-3.0, 38.0, hull_top + 24.0), (3.0, 38.0, hull_top + 24.0), 0.25, bm=bm)
    MU.make("ferry_mast", bm, mast, parent=rig.root)
    for (name, col_, pos, s) in (("nav_g", "#18ff50", (B / 2 - 1.0, 50.0, hull_top + 16.4), 9.0),
                                 ("nav_w", "#ffffff", (0.0, 38.0, hull_top + 26.4), 9.0),
                                 ("nav_w2", "#ffffff", (0.0, -80.0, hull_top + 3.0), 6.0)):
        lm = M.basic("ferry_" + name, col_, rough=0.3, emit={"lights": (col_, s)})
        bm = MU.bm_sphere(0.45, center=pos, subdiv=1)
        MU.make("ferry_" + name, bm, lm, parent=rig.root)
    # deck lights along the top of the hull
    dl = M.basic("ferry_deckl", "#fff0c0", rough=0.3, emit={"lights": ("#ffe2a0", 5.0)})
    bm = bmesh.new()
    for i in range(16):
        yy = -80.0 + i * 10.5
        MU.bm_sphere(0.25, center=(B / 2 - 0.4, yy, hull_top + (0.4 if yy < 40 else 1.4)), subdiv=1, bm=bm)
    MU.make("ferry_deckl", bm, dl, parent=rig.root)
    return dict(object=obj_size(L, hull_top + 27.0, B))


WARM_SHIP = "#ffd590"
