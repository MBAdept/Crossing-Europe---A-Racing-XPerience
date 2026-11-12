"""AS5a (wave 5): the city buildings of props_cities (props/city_*) as real-time models (docs/modelle.md section 20).
Builder "city" - the builder "house" of AS4 (ce3d/buildings3d.py, used as it is and left unchanged: openings with
reveals, frames, glazing bars, sills and panes, doors with steps, gutters, chimney caps, lod1 with the far ring)
plus what the city buildings need:

  walls      props_cities.wallmat logs its grids (as for AS4's houseboat), its surface and its zones while the model
             builds (the file is not changed for that)
  shops      shop windows (grids of kind "shop"): frame and glazing bars in the glass plane near the facade, behind them
             a display on a deeper pane (shop_depth) - shelves with goods, a clothes rail or a counter, chosen per
             window; dim behind the glass by day, lit at night where the sprite lights that window (same random
             numbers as wallmat), never a flat white field
  timber     the half-timbering (surface kind "timber") as members 3.5 cm proud of the infill: posts, rails, sill and
             lintel rails, braces - clipped at the openings, flat-coloured (vpbr), only in lod0 (the painted timber of
             the atlas stays under them and carries lod1)
  railings   cut-out railings of the generator (lace_mat) stay in the atlas, class baked_cutout: their charts get
             `cut_ppm` texels per metre (bars at least 2.5 texels), mipmap-safe halo alpha; with single_cutout every
             baked part goes to the cut-out class (two surfaces: baked_cutout + vpbr)
  gardens    hedges and garden trees of the generator decimated (decimate) and baked with the walls
  far walls  vertical faces looking away from the road (+x) or to the back (+y) take the texels of the opposite wall
             of the same material (mirror image: the same windows, lit at night) instead of texels of their own -
             "reused walls on the far side" (contract 4.6.5, AS5a); a face without such a wall is baked as before
  floors     the walls are cut at floors["z"]: charts above it get floors["upper"] of the texel density (the ground and
             the first floor of a centre building at full density, >= 40 px/m)
  gates      door openings wider than gate_w are ribbed gates (garage doors)
  lamps      flat lamp materials become vpbr lamps with light anchors only when named in "lamps" (wall lamps, the
             crane's lights); every other lit material (dormer and turret windows) stays in the emission atlas - an
             unlit vpbr lamp shows half its light colour by day (AS4R)
  extent     extent_m is measured on the generator's model before anything is added or decimated: the sprite's

Catalog options (besides those of "house"): decimate, lamps, shop_depth (in openings), gate_w (in openings), timber
(dict: out, k - colour factor, vary), cut_ppm, single_cutout, far (bool, default True), floors (dict z, upper,
objects), levels, close3d (generator parameter: back gables of the timber houses).
Two surfaces per level (baked or baked_cutout + vpbr): city budget 10,000 triangles, 2 draw calls.
"""
import math
import time
import zlib

import numpy as np

from . import bake as BK
from . import buildings3d as H
from . import core, roles
from . import props3d as P
from .export import Lod, Part

SHOP_DEPTH = 0.3          # the display of a shop window lies this far behind the wall plane
SHOP_GLASS = 0.07         # frame and glazing bars of a shop window this far behind the wall plane (the glass)
GATE_W = 2.6              # door openings wider than this are gates (the house builder's threshold)
TIMBER_OUT = 0.035        # timber members stand this far proud of the infill
CUT_PPM = 150.0           # texel density of cut-out charts (railings): a 3 cm bar = 4.5 texels
FAR_MIN_N = 0.9           # a far face looks along +x or +y at least this much
NEAR_COVER_M = 0.3        # a near wall with another volume closer than this in front of it is covered


# --- the wall log ------------------------------------------------------------------------------------------------

def _log_walls(log):
    """props_cities.wallmat writes no window log, and the file is not ours to change for that: while a model builds
    the function is wrapped. Its grids go to the log as explicit rectangles (the cutter's format, as AS4's
    _log_city_walls), with the surface spec (timber framing), the zones, the seed and per-grid shutters.
    Returns the function that restores the original."""
    import inspect
    from cesprites import props_cities as C
    orig = C.wallmat
    sig = inspect.signature(orig)

    def logged(*args, **kw):
        ba = sig.bind(*args, **kw)
        ba.apply_defaults()
        a = ba.arguments
        grids = []
        shutters = None
        for g in a["grids"]:
            wu, wz = g["win"]
            kind = g.get("kind", "win")
            rects = [(u - wu / 2, u + wu / 2, zc - wz / 2, zc + wz / 2) for (u, zc, _i, _j) in C.centres(g)]
            lit = g.get("lit", a["lit"] if kind == "win" else (0.95 if kind == "shop" else 0.0))
            cols = g.get("color")
            light = (cols if isinstance(cols, str) else cols[0]) if cols else ("#ffcf8a" if kind != "win" else "#ffc46b")
            if g.get("shutters") and shutters is None:
                shutters = g["shutters"]
            grids.append(dict(g, rects=rects, lit=lit, color=light, arch=g.get("top") == "round",
                              top=None if g.get("top") == "round" else g.get("top"), shutters=bool(g.get("shutters")),
                              colors=cols, strength=g.get("strength", a["strength"] if kind == "win" else 1.05)))
        log.append(dict(material=a["name"], grids=grids, decals=[dict(d) for d in (a["decals"] or [])],
                        frame=a["frame"], glass=a["glass"], lit=a["lit"], warm="#ffc46b", frame_w=a["frame_w"],
                        shutters=shutters, surface=a["color"], zones=[dict(z) for z in (a["zones"] or ())],
                        seed=float(a["seed"])))
        return orig(*args, **kw)
    C.wallmat = logged

    def restore():
        C.wallmat = orig
    return restore


# --- shop displays -----------------------------------------------------------------------------------------------

GOODS = ("#b8432f", "#d9822b", "#e3c24a", "#5d8f3a", "#2f6d9e", "#7a4f8c", "#e9e4d6", "#6f7275", "#c46a8a", "#2f8a7c",
         "#3b3f46", "#a8885a")


def _display_mat(base, g, gi, e, cache, sink):
    """The display behind a shop window (one material per facade material and shop grid): window-local coordinates
    from the grid, per window one of three contents - shelves with goods, a clothes rail, a counter with a shelf
    behind - from the same per-window random numbers wallmat uses (so the windows the sprite lights are lit here).
    Base colour: the dark glass of the sprite with the display dimmed behind it and a little sky reflection towards
    the top; light layer: the display lit (warm, brighter under the ceiling), the goods as coloured patches, shelves
    and frames of the furniture dark - never a flat white field."""
    key = (base.name, gi)
    if key in cache:
        return cache[key]
    from cesprites import materials as M
    m, nb = M.new_material("ce_disp%d_%s" % (gi, base.name))
    x, y, z = nb.coords()
    nx, ny, _nz = nb.normal()
    side = nb.gt(nb.absf(nx), nb.absf(ny))
    u = nb.mixf(side, x, y)
    u0, pu, z0, pz = float(g["u0"]), float(g["pu"]), float(g["z0"]), float(g["pz"])
    wu, wz = (float(v) for v in g["win"])
    sill = float(g.get("sill", (pz - wz) * 0.5))

    def mod(a, b):
        return nb.math("FLOORED_MODULO", a, b)
    fu = mod(nb.sub(u, u0), pu)
    sm = nb.sub(fu, (pu - wu) * 0.5)                  # metres from the window's left edge
    s = nb.mul(sm, 1.0 / wu)
    fz = mod(nb.sub(z, z0), pz)
    tm = nb.sub(fz, sill)                             # metres above the window's bottom
    t = nb.mul(tm, 1.0 / wz)
    iu = nb.math("FLOOR", nb.math("DIVIDE", nb.sub(u, u0), pu))
    iz = nb.math("FLOOR", nb.math("DIVIDE", nb.sub(z, z0), pz))
    # the random numbers of wallmat for this window (r1: lit, r2, r3)
    cmb = nb.node("ShaderNodeCombineXYZ")
    nb.feed(cmb.inputs[0], iu)
    nb.feed(cmb.inputs[1], iz)
    nb.feed(cmb.inputs[2], nb.add(nb.mul(nx, 3.1), nb.add(nb.mul(ny, 7.3), gi * 1.7 + float(e.get("seed", 0.0)))))
    wn = nb.node("ShaderNodeTexWhiteNoise", noise_dimensions="3D")
    nb.links.new(cmb.outputs[0], wn.inputs["Vector"])
    sep = nb.node("ShaderNodeSeparateColor")
    nb.links.new(wn.outputs["Color"], sep.inputs[0])
    r1, r2, r3 = wn.outputs["Value"], sep.outputs[0], sep.outputs[1]
    kind_a = nb.lt(r3, 0.45)                          # shelves with goods
    kind_b = nb.AND(nb.NOT(kind_a), nb.lt(r3, 0.72))  # clothes rail
    kind_c = nb.NOT(nb.OR(kind_a, kind_b))            # counter with a shelf behind it

    def cells(width, row_phase, scale_t=None):
        """(item index, fraction across the item) along the window for items `width` m wide."""
        q = nb.add(nb.mul(sm, 1.0 / width), row_phase)
        return nb.math("FLOOR", q), nb.math("FRACT", q)

    def palette(fac):
        """A colour of GOODS chosen by fac 0..1 (constant ramp)."""
        n = len(GOODS)
        node = nb.node("ShaderNodeValToRGB")
        cr = node.color_ramp
        cr.interpolation = "CONSTANT"
        while len(cr.elements) > n:
            cr.elements.remove(cr.elements[-1])
        while len(cr.elements) < n:
            cr.elements.new(0.5)
        for k, el in enumerate(cr.elements):
            el.position = k / n
            el.color = M.srgb(GOODS[k])
        nb.feed(node.inputs[0], fac)
        return node.outputs[0]

    def hash2(a, b, salt):
        c2 = nb.node("ShaderNodeCombineXYZ")
        nb.feed(c2.inputs[0], a)
        nb.feed(c2.inputs[1], b)
        nb.feed(c2.inputs[2], nb.add(nb.mul(r2, 13.7), salt))
        w2 = nb.node("ShaderNodeTexWhiteNoise", noise_dimensions="3D")
        nb.links.new(c2.outputs[0], w2.inputs["Vector"])
        return w2.outputs["Value"]

    wall_c = nb.mix(r2, M.srgb("#8c8072"), M.srgb("#a99a86"))
    col = wall_c
    lum = nb.add(0.75, nb.mul(t, 0.25))               # brightness of the lit interior (ceiling lights)
    # A: three shelves with goods of varied width and height
    shelf_z = (0.24, 0.47, 0.70, 0.93)
    goods_m = None
    for k in range(3):
        za, zb = shelf_z[k], shelf_z[k + 1]
        idx, fr = cells(0.17 + 0.05 * k, k * 0.37)
        hv = hash2(idx, float(k), 0.0)
        top = nb.add(za + 0.03, nb.mul(nb.add(0.45, nb.mul(hv, 0.45)), zb - za - 0.06))
        gm = nb.AND(nb.gt(t, za + 0.02), nb.lt(t, top), nb.gt(fr, 0.12), nb.lt(fr, 0.88))
        col = nb.mix(nb.mul(gm, kind_a), col, palette(hash2(idx, float(k), 5.0)))
        goods_m = gm if goods_m is None else nb.OR(goods_m, gm)
    boards = None
    for za in shelf_z[:3]:
        b = nb.lt(nb.absf(nb.sub(t, za)), 0.018 / (wz / 2.5))
        boards = b if boards is None else nb.OR(boards, b)
    upright = nb.OR(nb.lt(s, 0.035), nb.gt(s, 0.965))
    furn_a = nb.mul(nb.OR(boards, nb.mul(upright, nb.gt(t, 0.22))), kind_a)
    col = nb.mix(furn_a, col, M.srgb("#3a2e24"))
    # B: a clothes rail with garments, a low table in front
    gidx, gfr = cells(0.11, 0.0)
    gh = hash2(gidx, 7.0, 1.0)
    garment = nb.AND(nb.lt(t, 0.8), nb.gt(t, nb.add(0.28, nb.mul(gh, 0.2))), nb.gt(gfr, 0.06), nb.gt(s, 0.08),
                     nb.lt(s, 0.92))
    col = nb.mix(nb.mul(garment, kind_b), col, palette(hash2(gidx, 3.0, 2.0)))
    rail = nb.AND(nb.lt(nb.absf(nb.sub(t, 0.81)), 0.012), nb.gt(s, 0.06), nb.lt(s, 0.94))
    table = nb.AND(nb.lt(t, 0.2), nb.gt(s, 0.3), nb.lt(s, 0.7))
    col = nb.mix(nb.mul(nb.OR(rail, table), kind_b), col, M.srgb("#2f2a26"))
    # C: a counter (bakery, cafe) with items on it, a shelf with jars behind
    counter = nb.AND(nb.lt(t, 0.34), nb.gt(s, 0.06), nb.lt(s, 0.94))
    edge = nb.AND(nb.lt(nb.absf(nb.sub(t, 0.345)), 0.014), nb.gt(s, 0.05), nb.lt(s, 0.95))
    cidx, cfr = cells(0.26, 0.2)
    ch = hash2(cidx, 11.0, 3.0)
    item = nb.AND(nb.gt(t, 0.355), nb.lt(t, nb.add(0.4, nb.mul(ch, 0.08))), nb.gt(cfr, 0.15), nb.lt(cfr, 0.8))
    jidx, jfr = cells(0.09, 0.5)
    jar = nb.AND(nb.gt(t, 0.66), nb.lt(t, 0.75), nb.gt(jfr, 0.2), nb.lt(jfr, 0.8))
    jboard = nb.lt(nb.absf(nb.sub(t, 0.655)), 0.012)
    col = nb.mix(nb.mul(counter, kind_c), col, M.srgb("#5a3d28"))
    col = nb.mix(nb.mul(nb.OR(edge, jboard), kind_c), col, M.srgb("#d8cfbf"))
    col = nb.mix(nb.mul(item, kind_c), col, M.srgb("#c08a4a"))
    col = nb.mix(nb.mul(jar, kind_c), col, palette(hash2(jidx, 9.0, 4.0)))
    # floor and a darker rim (the room's corners)
    floor_m = nb.lt(t, 0.05)
    col = nb.mix(floor_m, col, M.srgb("#4b443d"))
    rim = nb.add(nb.mul(nb.absf(nb.sub(s, 0.5)), 2.0), 0.0)
    vign = nb.sub(1.0, nb.mul(nb.mul(rim, rim), 0.35))
    interior = nb.color_scale(col, vign)
    # by day: the sprite's glass, the display dimmed behind it, a sky reflection towards the top
    glass = M.srgb(g.get("glass", e.get("glass", "#2a3a3c")) if str(g.get("glass", "")).startswith("#") else "#2a3a3c")
    day = nb.mix(0.42, glass, nb.color_scale(interior, 0.55))
    sky = M.srgb("#8fa3b5")
    day = nb.mix(nb.mul(nb.math("POWER", nb.math("MAXIMUM", t, 0.0), 2.0), 0.16), day, sky)
    out = M.principled(nb, day, rough=0.12, spec=0.5)
    # at night: lit where wallmat lights this window (r1 < lit), light colour of the grid x strength x PANE_LIGHT_K
    lit = float(g.get("lit", 0.95))
    cols = g.get("colors") or ("#ffcf8a", "#ffdcaa")
    if isinstance(cols, str):
        cols = (cols,)
    st = float(g.get("strength", 1.05)) * float(H.PANE_LIGHT_K)
    light = M.srgb(cols[0])
    if len(cols) > 1:
        light = nb.mix(nb.gt(r2, 0.55), light, M.srgb(cols[1]))
    lit_m = nb.lt(r1, lit)
    glow = nb.color_scale(nb.color_scale(light, nb.mul(lum, st * 1.25)), lit_m)
    em = nb.color_scale(nb.vadd(nb.color_scale(interior, 0.8), (0.2, 0.2, 0.2)), 1.0)
    # multiply the lit interior by the light colour (vector multiply)
    mul = nb.node("ShaderNodeVectorMath", operation="MULTIPLY")
    nb.links.new(em, mul.inputs[0])
    nb.links.new(glow, mul.inputs[1])
    mat = M.finish(m, nb, out, {"lights": mul.outputs[0]})
    mat["ce_filler"] = 1
    mat["ce_pane"] = 1
    mat["ce_sink"] = float(sink)
    cache[key] = mat
    return mat


# --- openings (the cutter of AS4 with shops, gates and a record of every wall face) ------------------------------

def _door_city(geo, mats, h, p3, n, u_ax, depth, opt, step_mat, e):
    """H._door with the gate threshold of the catalog (gate_w): a garage door of 2.5 m is a ribbed gate, not a pair of
    wings with panels. A door whose sill lies above the ground (a raised ground floor: 0.05 .. 1.3 m) gets a flight
    of steps up to it (H._door draws steps only for doors at the ground)."""
    gate_w = float(opt.get("gate_w", GATE_W))
    a, b, c, d = h.rect
    if 0.05 < c < 1.3 and (b - a) <= gate_w and int(opt.get("steps", 1)) > 0:
        ns = max(1, int(round(c / 0.17)))
        sh = c / ns
        up = np.array([0.0, 0.0, 1.0])

        def q(u, z, dd):
            return p3(u, z, -dd)
        for k in range(ns):
            out = 0.3 * (ns - k)
            z1 = sh * (k + 1)
            u0, u1 = a - 0.15, b + 0.15
            geo.quad(step_mat, q(u0, z1, out), q(u1, z1, out), q(u1, z1, 0.0), q(u0, z1, 0.0), up)
            geo.quad(step_mat, q(u0, z1 - sh, out), q(u1, z1 - sh, out), q(u1, z1, out), q(u0, z1, out), n)
            geo.quad(step_mat, q(u0, z1 - sh, 0.0), q(u0, z1 - sh, out), q(u0, z1, out), q(u0, z1, 0.0), -u_ax)
            geo.quad(step_mat, q(u1, z1 - sh, 0.0), q(u1, z1 - sh, out), q(u1, z1, out), q(u1, z1, 0.0), u_ax)
    if (b - a) > gate_w and (b - a) <= GATE_W:
        # wider than gate_w but not wider than the house builder's threshold: draw it as a gate
        dcol = h.src.get("mat") if str(h.src.get("mat", "")).startswith("#") else opt.get("door_color", "#5a3a22")
        wing = mats.vpbr("ce_door_%s" % dcol.lstrip("#"), dcol, rough=0.5, metal=0.3)
        dark = mats.vpbr("ce_door_dark_%s" % dcol.lstrip("#"), H._scale_hex(dcol, 0.55), rough=0.75)
        geo.poly(wing, [p3(u, z, depth) for (u, z) in h.outline], n)
        z = c + 0.45
        while z < d - 0.2:
            span = H._half_width_at(h.outline, z)
            if span:
                geo.quad(dark, p3(span[0] + 0.05, z - 0.025, depth - 0.012), p3(span[1] - 0.05, z - 0.025, depth - 0.012),
                         p3(span[1] - 0.05, z + 0.025, depth - 0.012), p3(span[0] + 0.05, z + 0.025, depth - 0.012), n,
                         "lod0")
            z += 0.45
        return
    H._door(geo, mats, h, p3, n, u_ax, depth, opt, step_mat, e)


def cut_openings(rig, objs, log, opt, geo, mats, stats):
    """buildings3d.cut_openings (AS4) with: shop windows (deeper pane with a display, frame and bars in the glass plane
    near the facade, no sill), gates from gate_w, and a record of every wall face with a logged material (its plane,
    outline and openings - the timber members are placed with it). Returns that record."""
    import bmesh
    by_mat = {e["material"]: e for e in log}
    reveal_m = float(opt.get("reveal_m", H.REVEAL_M))
    shop_depth = float(opt.get("shop_depth", SHOP_DEPTH))
    shop_glass = float(opt.get("shop_glass", SHOP_GLASS))
    reveal = mats.baked("ce_reveal", opt.get("reveal_color", "#d9d2c6"))
    shop_reveal = mats.baked("ce_shop_reveal", opt.get("shop_reveal_color", "#3d362f"))
    sill = mats.vpbr("ce_sill", opt.get("sill_color", "#bdb8ae"), rough=0.8)
    step_mat = mats.baked("ce_step", opt.get("step_color", "#b3ada3"))
    pane_light = opt.get("pane_light", H.PANE_LIGHT_K)
    far_ring = bool(opt.get("far_ring", True))
    n_arc = int(opt.get("n_arc", 8))          # segments of an arched top (8 in the house builder; 4 for small windows)
    louvre = opt.get("louvre")
    record = []
    fac = [o for o in objs if any(s.material is not None and s.material.name in by_mat for s in o.material_slots)]
    if not fac:
        return record
    cover = H.Cover(objs)
    fill_cache = {}
    disp_cache = {}
    n_open = n_shut = n_louvre = n_door = n_clock = n_skip = n_hidden = n_shop = 0
    for ob in fac:
        mats_ob = [s.material for s in ob.material_slots]
        mw = np.array(ob.matrix_world, dtype=np.float64)
        geo.xform = mw
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.faces.ensure_lookup_table()
        new_faces = []
        drop = []
        for f in list(bm.faces):
            mat = mats_ob[f.material_index] if f.material_index < len(mats_ob) else None
            if mat is None or mat.name not in by_mat:
                continue
            e = by_mat[mat.name]
            n = np.array(f.normal, dtype=np.float64)
            cls, u_ax = H._face_frame(n)
            if cls is None or cls in opt.get("skip_faces", ()):
                continue
            vs = [np.array(v.co, dtype=np.float64) for v in f.verts]
            w = float(np.mean([v @ n for v in vs]))
            poly = [(float(v @ u_ax), float(v[2])) for v in vs]
            wn = np.linalg.inv(mw[:3, :3]).T @ n
            wn /= max(1e-9, np.linalg.norm(wn))

            def p3(u, z, depth=0.0, _u=u_ax, _n=n, _w=w):
                base = _u * u + np.array([0.0, 0.0, z])
                return base - _n * (base @ _n) + _n * (_w - depth)

            def hidden(rect, _p3=p3, _wn=wn, _mw=mw):
                a, b, c, d = rect
                for (u, z) in (((a + b) * 0.5, (c + d) * 0.5), (a + 0.05, c + 0.05), (b - 0.05, d - 0.05)):
                    if cover.covered(_mw[:3, :3] @ _p3(u, z) + _mw[:3, 3], _wn):
                        return True
                return False

            def inside(rect, m_in=0.04, m_out=0.03, _poly=poly):
                a, b, c, d = rect
                inner = [(a + m_in, c + m_in), (b - m_in, c + m_in), (b - m_in, d - m_in), (a + m_in, d - m_in)]
                outer = [(a - m_out, c - m_out), (b + m_out, c - m_out), (b + m_out, d + m_out), (a - m_out, d + m_out)]
                return all(P._inside_poly(q, _poly) for q in inner) and all(P._inside_poly(q, _poly) for q in outer)
            doors = []
            for d in e["decals"]:
                if not d.get("door"):
                    continue
                pts = H._decal_poly(d, cls)
                if pts is None:
                    continue
                zmin = min(q[1] for q in poly)
                pts = [(x, y - 0.02 if y <= zmin + 0.04 else y) for (x, y) in pts]
                us = [q[0] for q in pts]
                zs = [q[1] for q in pts]
                rect = (min(us), max(us), min(zs), max(zs))
                if P._inside_poly(((rect[0] + rect[1]) * 0.5, (rect[2] + rect[3]) * 0.5), poly):
                    if hidden((rect[0], rect[1], max(rect[2], min(zs) + 0.1), rect[3])):
                        n_hidden += 1
                        continue
                    doors.append(H.Opening(pts, "door", d, -1, rect))
            holes = list(doors)
            for gi, g in enumerate(e["grids"]):
                if g.get("kind") != "door" or cls not in P.GRID_FACES.get(g.get("face", "front"), ("front", "back")):
                    continue
                for rect in g.get("rects") or []:
                    if not P._inside_poly(((rect[0] + rect[1]) * 0.5, (rect[2] + rect[3]) * 0.5), poly) or hidden(rect):
                        continue
                    src = dict(mat=g.get("glass", "#5a3a22") if str(g.get("glass", "")).startswith("#") else "#5a3a22")
                    holes.append(H.Opening(H._outline(*rect, top=g.get("top"), n_arc=n_arc), "door", src, gi, rect,
                                           g.get("top")))
            for gi, g in enumerate(e["grids"]):
                if g.get("kind") == "door" or cls not in P.GRID_FACES.get(g.get("face", "front"), ("front", "back")):
                    continue
                top = "round" if g.get("arch") else g.get("top")
                for rect in (g["rects"] if "rects" in g else P._grid_windows(g)):
                    if not inside(rect):
                        continue
                    if any(H._overlaps(rect, h.rect) for h in holes):
                        n_skip += 1
                        continue
                    if hidden(rect):
                        n_hidden += 1
                        continue
                    zc = (rect[2] + rect[3]) * 0.5
                    if g.get("kind") == "shop" and shop_depth > 0.0:
                        kind = "shop"
                    else:
                        kind = "louvre" if louvre and louvre[0] <= zc <= louvre[1] else "window"
                    holes.append(H.Opening(H._outline(*rect, top=top, n_arc=n_arc), kind, g, gi, rect, top))
            clocks = [d for d in e["decals"] if d.get("clock") and H._decal_poly(d, cls) is not None]
            for d in clocks:
                pts = H._decal_poly(d, cls)
                us = [q[0] for q in pts]
                zs = [q[1] for q in pts]
                rect = (min(us), max(us), min(zs), max(zs))
                if P._inside_poly(((rect[0] + rect[1]) * 0.5, (rect[2] + rect[3]) * 0.5), poly) and not hidden(rect):
                    H._clock(geo, mats, d, rect, p3, n, u_ax, opt)
                    n_clock += 1
            record.append(dict(ob=ob.name, mat=mat.name, cls=cls, n=n.copy(), u_ax=u_ax.copy(), w=w, poly=list(poly),
                               holes=[h.rect for h in holes], mw=mw.copy()))
            if not holes:
                continue
            tris = P._cdt_with_holes(poly, [h.outline for h in holes])
            if not tris:
                continue
            for (a2, b2, c2) in tris:
                new_faces.append((p3(*a2), p3(*b2), p3(*c2), n, f.material_index))
            drop.append(f)
            fmat = H._filler_mat(mat, fill_cache)
            pmat = (H._filler_mat(mat, fill_cache, light_k=pane_light, sink=reveal_m, tint=opt.get("pane_tint", H.PANE_TINT))
                    if pane_light is not None else None)
            # shop windows without a display (shop_depth 0: the lobby of the office tower) light at shop_light of a pane
            smat = None
            if pmat is not None and any(h.kind == "window" and str(h.src.get("kind", "")) == "shop" for h in holes) \
                    and float(opt.get("shop_light", 1.0)) != 1.0:
                smat = H._filler_mat(mat, fill_cache, light_k=pane_light * float(opt["shop_light"]), sink=reveal_m,
                                     tint=opt.get("pane_tint", H.PANE_TINT))
                smat.name = "ce_panes_" + mat.name
            names_ob = [m.name if m is not None else "" for m in ob.data.materials]
            for m_ in [x for x in (fmat, pmat, smat) if x is not None]:
                if m_.name not in names_ob:
                    ob.data.materials.append(m_)
                    names_ob.append(m_.name)
            for h in holes:
                if h.kind == "shop":
                    use = _display_mat(mat, h.src, h.gi, e, disp_cache, shop_depth)
                    if use.name not in names_ob:
                        ob.data.materials.append(use)
                        names_ob.append(use.name)
                elif smat is not None and h.kind == "window" and str(h.src.get("kind", "")) == "shop":
                    use = smat
                else:
                    use = pmat if (pmat is not None and h.kind == "window") else fmat
                slot = names_ob.index(use.name)
                q = [p3(u, z) for (u, z) in h.outline]
                for i in range(1, len(q) - 1):
                    new_faces.append((q[0], q[i], q[i + 1], n, slot))
            for h in holes:
                n_open += 1
                if h.kind == "shop":
                    depth = shop_depth
                elif h.kind == "door":
                    depth = float(opt.get("door_m", 0.1))
                else:
                    depth = reveal_m
                if h.kind == "shop":
                    # the reveal: wall-coloured to the glass, the dark inside of the shop behind it
                    _reveal_span(geo, reveal, h.outline, p3, n, u_ax, 0.0, shop_glass)
                    _reveal_span(geo, shop_reveal, h.outline, p3, n, u_ax, shop_glass, depth)
                else:
                    H._reveal(geo, reveal, h.outline, p3, n, u_ax, depth)
                if h.kind == "door":
                    _door_city(geo, mats, h, p3, n, u_ax, depth, opt, step_mat, e)
                    n_door += 1
                    continue
                g = h.src
                a, b, c, d = h.rect
                if h.kind == "louvre":
                    H._louvre(geo, mats, h, p3, n, u_ax, depth, opt)
                    n_louvre += 1
                    continue
                kind = H._window_kind(g, b - a, d - c)
                fcol = g.get("frame", e.get("frame", "#e9e6de"))
                fm = mats.vpbr("ce_frame_%s" % fcol.lstrip("#"), fcol, rough=0.55)
                fd = (shop_glass if h.kind == "shop" else depth) - 0.015
                inner = H._outline(a, b, c, d, top=h.top, inset=H.FRAME_W, n_arc=n_arc)
                if len(inner) == len(h.outline):
                    m2 = len(h.outline)
                    for i in range(m2):
                        j = (i + 1) % m2
                        geo.quad(fm, p3(*h.outline[i], fd), p3(*h.outline[j], fd), p3(*inner[j], fd), p3(*inner[i], fd), n,
                                 "lod0")
                vf, hf = H._bars(kind, b - a, d - c, opt, g)
                bw = float(opt.get("bar_w", H.BAR_W)) * 0.5
                bar_area = 0.0
                for fu in vf:
                    um = a + (b - a) * fu
                    top_z = H._top_at(inner, um) if inner else None
                    if top_z is None:
                        top_z = d - H.FRAME_W
                    geo.quad(fm, p3(um - bw, c + H.FRAME_W, fd - 0.002), p3(um + bw, c + H.FRAME_W, fd - 0.002),
                             p3(um + bw, top_z, fd - 0.002), p3(um - bw, top_z, fd - 0.002), n, "lod0")
                    bar_area += 2.0 * bw * max(0.0, top_z - c - H.FRAME_W)
                for fz in hf:
                    zt = c + (d - c) * fz
                    span = H._half_width_at(inner, zt)
                    if span is None:
                        continue
                    geo.quad(fm, p3(span[0], zt - bw, fd - 0.003), p3(span[1], zt - bw, fd - 0.003),
                             p3(span[1], zt + bw, fd - 0.003), p3(span[0], zt + bw, fd - 0.003), n, "lod0")
                    bar_area += 2.0 * bw * (span[1] - span[0]) - (4.0 * bw * bw) * len(vf)
                if far_ring and len(inner) == len(h.outline):
                    ring = H._area(h.outline) - H._area(inner) + max(0.0, bar_area)
                    inner1 = H._outline(a, b, c, d, top=h.top, inset=H._far_inset(a, b, c, d, h.top, ring), n_arc=n_arc)
                    if len(inner1) == len(h.outline):
                        for i in range(len(h.outline)):
                            j = (i + 1) % len(h.outline)
                            geo.quad(fm, p3(*h.outline[i], fd), p3(*h.outline[j], fd), p3(*inner1[j], fd),
                                     p3(*inner1[i], fd), n, "lod1")
                if h.kind == "shop":
                    n_shop += 1
                    continue
                if e.get("shutters") and g.get("shutters", True) and kind == "win":
                    H._shutters(geo, mats, e["shutters"], (a, b, c, d), g, e, p3, n, u_ax)
                    n_shut += 1
                if c >= 0.3 and kind != "shop":
                    H._sill(geo, sill, (a, b, c, d), p3, n, u_ax, depth)
        geo.xform = None
        if not drop:
            bm.free()
            continue
        for (a, b, c, nrm, mi) in new_faces:
            vs = [bm.verts.new(tuple(float(x) for x in p)) for p in (a, b, c)]
            try:
                f2 = bm.faces.new(vs)
            except ValueError:
                continue
            f2.material_index = mi
            f2.normal_update()
            if np.array(f2.normal) @ nrm < 0:
                f2.normal_flip()
        bmesh.ops.delete(bm, geom=drop, context="FACES_ONLY")
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bm.to_mesh(ob.data)
        bm.free()
        ob.data.update()
    stats.update(openings=n_open, doors=n_door, shops=n_shop, shutters=n_shut, louvres=n_louvre, clocks=n_clock,
                 skipped=n_skip, hidden=n_hidden)
    return record


def _reveal_span(geo, mat, outline, p3, n, u_ax, d0, d1):
    """Reveal of an opening between the depths d0 and d1 behind the wall plane (H._reveal starts at the plane)."""
    m2 = len(outline)
    cu = float(np.mean([q[0] for q in outline]))
    cz = float(np.mean([q[1] for q in outline]))
    for i in range(m2):
        (ua, za), (ub, zb) = outline[i], outline[(i + 1) % m2]
        eu, ez = ub - ua, zb - za
        nu, nz = -ez, eu
        if nu * (cu - (ua + ub) * 0.5) + nz * (cz - (za + zb) * 0.5) < 0:
            nu, nz = -nu, -nz
        nn = u_ax * nu + np.array([0.0, 0.0, nz])
        nn = nn - n * (nn @ n)
        ln = np.linalg.norm(nn)
        if ln < 1e-9:
            continue
        geo.quad(mat, p3(ua, za, d0), p3(ub, zb, d0), p3(ub, zb, d1), p3(ua, za, d1), nn / ln)


# --- timber framing -----------------------------------------------------------------------------------------------

def _intervals_minus(a, b, cuts):
    """[a, b] minus the intervals cuts [(c0, c1)] -> list of (x0, x1)."""
    out = [(a, b)]
    for (c0, c1) in cuts:
        nxt = []
        for (x0, x1) in out:
            if c1 <= x0 or c0 >= x1:
                nxt.append((x0, x1))
                continue
            if c0 > x0:
                nxt.append((x0, c0))
            if c1 < x1:
                nxt.append((c1, x1))
        out = nxt
    return [(x0, x1) for (x0, x1) in out if x1 - x0 > 0.05]


def _poly_span_z(poly, u):
    """(z_min, z_max) of a polygon on the vertical line at u, or None."""
    zs = []
    n = len(poly)
    for i in range(n):
        (u0, z0), (u1, z1) = poly[i], poly[(i + 1) % n]
        if (u0 - u) * (u1 - u) <= 0 and abs(u1 - u0) > 1e-9:
            zs.append(z0 + (z1 - z0) * (u - u0) / (u1 - u0))
        elif abs(u0 - u) < 1e-9:
            zs.append(z0)
    if len(zs) < 2:
        return None
    return min(zs), max(zs)


def _poly_span_u(poly, z):
    span = H._half_width_at(poly, z)
    return span


def timber_members(record, log, opt, geo, mats, stats, objs=None):
    """The half-timbering of the walls whose surface is of kind "timber" (props_cities._timber) as members in front of
    the infill: posts every `pitch` from u0, rails at the floor lines (bottom and top of every floor band), sill and
    lintel rails, braces in the bays wallmat paints them - the same positions and widths as the painted timber,
    TIMBER_OUT proud, clipped to the wall's outline and cut at the openings (with their frames). Zones that paint
    another surface over the timber (the stone ground floor) are left out. vpbr, timber colour x a small variation per
    member; level lod0 only (lod1 keeps the painted timber of the atlas)."""
    spec = dict(opt or {})
    out = float(spec.get("out", TIMBER_OUT))
    faces = tuple(spec.get("faces", ("front", "left")))
    by_mat = {e["material"]: e for e in log}
    n_mem = 0
    up = np.array([0.0, 0.0, 1.0])
    cover = H.Cover(objs) if objs else None
    for r in record:
        e = by_mat.get(r["mat"])
        if e is None or r["cls"] not in faces:
            continue
        s = e.get("surface")
        if not isinstance(s, dict) or s.get("kind") != "timber":
            continue
        if cover is not None:
            # a wall that leans against the next house (no point of it free) gets no members
            pts = [(float(np.mean([q[0] for q in r["poly"]])), float(np.mean([q[1] for q in r["poly"]])))]
            pts += [(q[0] * 0.8 + pts[0][0] * 0.2, q[1] * 0.8 + pts[0][1] * 0.2) for q in r["poly"]]
            wn = np.linalg.inv(r["mw"][:3, :3]).T @ r["n"]
            wn /= max(1e-9, np.linalg.norm(wn))
            free = False
            for (pu, pz) in pts:
                base = r["u_ax"] * pu + np.array([0.0, 0.0, pz])
                loc = base - r["n"] * (base @ r["n"]) + r["n"] * r["w"]
                wp = r["mw"][:3, :3] @ loc + r["mw"][:3, 3]
                if not cover.covered(wp, wn, near=NEAR_COVER_M):
                    free = True
                    break
            if not free:
                continue
        tc = s.get("timber", "#3d2a1d")
        u0, p, wd = float(s["u0"]), float(s["pitch"]), float(s.get("w", 0.2))
        ua, ub = s.get("u_range", (-1e4, 1e4))
        za_, zb_ = s.get("z_range", (-1e4, 1e4))
        poly = r["poly"]
        n, u_ax, w = r["n"], r["u_ax"], r["w"]
        geo.xform = r["mw"]
        umin, umax = min(q[0] for q in poly), max(q[0] for q in poly)
        zmin, zmax = min(q[1] for q in poly), max(q[1] for q in poly)
        # z bands where a zone paints over the timber (zones spanning the whole wall in x and y)
        zcut = []
        for zn in e.get("zones") or []:
            (xa, xb), (ya, yb), (z0z, z1z) = zn["box"]
            if xa <= -50 and xb >= 50 and ya <= -50 and yb >= 50:
                zcut.append((float(z0z), float(z1z)))
        margin = float(e.get("frame_w", 0.07)) + 0.02
        holes = [(a - margin, b + margin, c - margin, d + margin) for (a, b, c, d) in r["holes"]]
        k_var = float(spec.get("vary", 0.12))

        def mat_for(key):
            hv = zlib.crc32(key.encode()) / 2.0 ** 32
            k = float(spec.get("k", 1.0)) * (1.0 - k_var * 0.5 + k_var * hv)
            col = H._scale_hex(tc, k)
            # three shades per wall are enough (one material each)
            q = int(hv * 3.0)
            col = H._scale_hex(tc, float(spec.get("k", 1.0)) * (1.0 - k_var * 0.5 + k_var * (q + 0.5) / 3.0))
            return mats.vpbr("ce_timber_%s_%d" % (tc.lstrip("#"), q), col, rough=0.8)

        def member(pts2, key):
            """A member from its outline (u, z) (convex, counter-clockwise): front face, side faces."""
            nonlocal n_mem
            m = mat_for(key)
            q = [geo_p(u, z, -out) for (u, z) in pts2]
            for i in range(1, len(q) - 1):
                geo.tri(m, q[0], q[i], q[i + 1], n, "lod0")
            k2 = len(pts2)
            for i in range(k2):
                (ua2, za2), (ub2, zb2) = pts2[i], pts2[(i + 1) % k2]
                eu, ez = ub2 - ua2, zb2 - za2
                ln = math.hypot(eu, ez)
                if ln < 1e-6:
                    continue
                nu, nz = ez / ln, -eu / ln            # outward of a counter-clockwise outline
                nn = u_ax * nu + up * nz
                geo.quad(m, geo_p(ua2, za2, 0.0), geo_p(ub2, zb2, 0.0), geo_p(ub2, zb2, -out), geo_p(ua2, za2, -out), nn,
                         "lod0")
            n_mem += 1

        def geo_p(u, z, depth, _u=u_ax, _n=n, _w=w):
            base = _u * u + np.array([0.0, 0.0, z])
            return base - _n * (base @ _n) + _n * (_w - depth)

        def free_z(z0, z1):
            return _intervals_minus(z0, z1, zcut + [(-1e4, za_), (zb_, 1e4)])

        # posts
        k0 = int(math.floor((umin - u0) / p)) - 1
        k1 = int(math.ceil((umax - u0) / p)) + 1
        for k in range(k0, k1 + 1):
            uc = u0 + k * p
            a, b = uc - wd * 0.5, uc + wd * 0.5
            a, b = max(a, umin, ua), min(b, umax, ub)
            if b - a < wd * 0.4:
                continue
            spans = [_poly_span_z(poly, a + 0.01), _poly_span_z(poly, b - 0.01)]
            if spans[0] is None or spans[1] is None:
                continue
            z0, z1 = max(spans[0][0], spans[1][0]), min(spans[0][1], spans[1][1])
            for (pz0, pz1) in free_z(z0, z1):
                cuts = [(c, d) for (ha, hb, c, d) in holes if ha < b and hb > a]
                for (q0, q1) in _intervals_minus(pz0, pz1, cuts):
                    member([(a, q0), (b, q0), (b, q1), (a, q1)], "p%d|%s" % (k, r["ob"]))
        # rails
        rails = []
        for (fz0, fz1) in s.get("floors", []):
            fz0, fz1 = float(fz0), float(fz1)
            rails += [(fz0, fz0 + wd), (fz1 - wd, fz1)]
            for zz in (s.get("sill"), s.get("lintel")):
                if zz is not None and fz0 + float(zz) < fz1 - wd:
                    rails.append((fz0 + float(zz) - wd * 0.35, fz0 + float(zz) + wd * 0.35))
        for ri, (rz0, rz1) in enumerate(rails):
            if rz1 <= zmin + 0.01 or rz0 >= zmax - 0.01:
                continue
            if not free_z(rz0, rz1) or abs(sum(b2 - a2 for (a2, b2) in free_z(rz0, rz1)) - (rz1 - rz0)) > 1e-6:
                continue
            s0, s1 = _poly_span_u(poly, rz0 + 0.005), _poly_span_u(poly, rz1 - 0.005)
            if s0 is None or s1 is None:
                continue
            a, b = max(s0[0], s1[0], ua), min(s0[1], s1[1], ub)
            if b - a < 0.1:
                continue
            cuts = [(ha, hb) for (ha, hb, c, d) in holes if c < rz1 and d > rz0]
            for (q0, q1) in _intervals_minus(a, b, cuts):
                member([(q0, rz0), (q1, rz0), (q1, rz1), (q0, rz1)], "r%d|%s" % (ri, r["ob"]))
        # braces: "/" or "\" across a bay and a floor band, in every brace_every-th bay
        if s.get("brace", True):
            every = int(s.get("brace_every", 2))
            phase = int(s.get("brace_phase", 0))
            for fi, (fz0, fz1) in enumerate(s.get("floors", [])):
                fz0, fz1 = float(fz0), float(fz1)
                hgt = fz1 - fz0
                if not free_z(fz0, fz1) or abs(sum(b2 - a2 for (a2, b2) in free_z(fz0, fz1)) - hgt) > 1e-6:
                    continue
                hw = wd * 0.55 / max(p, hgt) * p          # horizontal half width of the painted brace
                for k in range(k0, k1 + 1):
                    if (k + phase) % every != 0:
                        continue
                    ua0 = u0 + k * p
                    par = (k + fi) % 2
                    # the brace's centre line from (ua0, fz0) to (ua0 + p, fz1) ("/"), mirrored for "\"
                    if par == 0:
                        pa, pb = (ua0, fz0), (ua0 + p, fz1)
                    else:
                        pa, pb = (ua0 + p, fz0), (ua0, fz1)
                    # between the posts and the rails (the painted brace is hidden under them)
                    z_lo, z_hi = fz0 + wd, fz1 - wd
                    if z_hi - z_lo < 0.3:
                        continue

                    def at(zq):
                        t_ = (zq - fz0) / hgt
                        return pa[0] + (pb[0] - pa[0]) * t_
                    c_lo, c_hi = at(z_lo), at(z_hi)
                    out_pts = [(c_lo - hw, z_lo), (c_lo + hw, z_lo), (c_hi + hw, z_hi), (c_hi - hw, z_hi)]
                    bu0 = min(q[0] for q in out_pts)
                    bu1 = max(q[0] for q in out_pts)
                    if bu0 < max(umin, ua) or bu1 > min(umax, ub):
                        continue
                    if not all(P._inside_poly(q, poly) for q in out_pts):
                        continue
                    if any(ha < bu1 and hb > bu0 and c < z_hi and d > z_lo for (ha, hb, c, d) in holes):
                        continue
                    member(out_pts, "b%d_%d|%s" % (k, fi, r["ob"]))
        geo.xform = None
    stats["timber_members"] = n_mem
    return n_mem


# --- the flat lod1 ---------------------------------------------------------------------------------------------------
#
# lod1 of a city building (from the props builder's first switch distance on: 60 m at "Details: Mittel", and the level
# of everything farther away - there is no impostor) is the cut wall flattened again: a copy of every cut wall object,
# its coplanar faces dissolved back into the generator's wall polygons, with the atlas coordinates of the cut wall (the
# hole fillers baked the sprite's window into the atlas: glass, glazing bars, curtains, blinds by day, its light at
# night). No reveals, frames, bars or sills in lod1: at 60 m and more they are under a pixel and only shimmer (AS4R:
# block B at 120 m 1.0 % against the sprite's 0.2 %), and a window-rich facade (the Speicher: 143 openings) spends
# 10,000 triangles on them. lod1 keeps silhouette, storeys, roofs, cornices, dormers and the window rhythm of the sprite.

FLAT_LOD0_PREFIXES = ("ce_reveal", "ce_shop_reveal", "ce_door_", "ce_louvre_")


def _lod0_only(geo, prefixes):
    """Cutter geometry that the flat lod1 wall covers (reveals, door wings, louvres) moves to level lod0."""
    n = 0
    for key in sorted(list(geo.tris)):
        name, level = key
        if level == "both" and any(name.startswith(p) for p in prefixes):
            mat, tris = geo.tris.pop(key)
            geo.tris.setdefault((name, "lod0"), (mat, []))[1].extend(tris)
            n += len(tris)
    return n


def _flat_copies(objs):
    """lod1 copies of the cut walls (objects with a filler, pane or display material), their coplanar faces dissolved
    (delimit UV: one chart stays one polygon), the atlas coordinates kept; the originals become lod0. Called after the
    packing (the atlas coordinates exist) and before the panes are moved back. Returns the copies."""
    import bmesh
    import bpy
    out = []
    for ob in objs:
        if H._level(ob) != "both":
            continue
        if not any(s.material is not None and s.material.get("ce_filler") for s in ob.material_slots):
            continue
        fo = ob.copy()
        fo.data = ob.data.copy()
        fo.name = ob.name + "_flat"
        ob.users_collection[0].objects.link(fo)
        bm = bmesh.new()
        bm.from_mesh(fo.data)
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), use_dissolve_boundaries=False, verts=bm.verts[:],
                                 edges=bm.edges[:], delimit={"UV"})
        bm.to_mesh(fo.data)
        bm.free()
        fo.data.update()
        fo["ce_lvl"] = "lod1"
        ob["ce_lvl"] = "lod0"
        out.append(fo)
    bpy.context.view_layer.update()
    return out


# --- far walls: the texels of the opposite wall ------------------------------------------------------------------

def _base_name(name):
    """The facade material of a filler, pane or display copy (ce_fill_<m>, ce_pane_<m>, ce_disp<k>_<m>)."""
    import re
    for pre in ("ce_panes_", "ce_pane_", "ce_fill_"):
        if name.startswith(pre):
            return name[len(pre):]
    mt = re.match(r"^ce_disp\d+_(.*)$", name)
    return mt.group(1) if mt else name


def _far_split(objs, bake_names, stats):
    """Finds the vertical faces of baked materials that look away from the road (+x) or to the back (+y) and the wall
    of the same material that faces them from the other side (-x / -y; the same plane coordinates: a mirror image) -
    a wall that is not covered by another volume. Such far faces are moved into objects of their own (no texels;
    their atlas coordinates are set after the packing from the opposite wall's chart, far_uvs()). Returns
    (far objects, matches: [(far object name, near object name, axis, sample (u, z))])."""
    import bmesh
    import bpy
    from cesprites import meshutil as MU
    cover = H.Cover(objs)
    # near triangles by (base material, axis): [(object name, tri (3, 2) in (u, z), plane w, centre world)]
    near = {}
    infos = []
    for ob in objs:
        mw = np.array(ob.matrix_world, dtype=np.float64)
        m3 = mw[:3, :3]
        nm = np.linalg.inv(m3).T
        mats = [s.material for s in ob.material_slots]
        me = ob.data
        me.calc_loop_triangles()
        co = np.array([tuple(v.co) for v in me.vertices], dtype=np.float64) @ m3.T + mw[:3, 3]
        for lt in me.loop_triangles:
            m = mats[lt.material_index] if lt.material_index < len(mats) else None
            if m is None or m.name not in bake_names:
                continue
            nrm = nm @ np.array(lt.normal, dtype=np.float64)
            nrm /= max(1e-12, np.linalg.norm(nrm))
            if abs(nrm[2]) > 0.1:
                continue
            for ax in (0, 1):
                if nrm[ax] < -FAR_MIN_N:
                    p = co[list(lt.vertices)]
                    uz = np.stack([p[:, 1 - ax], p[:, 2]], axis=1)
                    near.setdefault((_base_name(m.name), ax), []).append((ob.name, uz, float(p[:, ax].mean()),
                                                                           p.mean(axis=0)))
        infos.append((ob, mw, nm, mats))
    # a near wall (object, plane) is covered when no triangle centre of it is free (another volume stands right in
    # front of it or around it: the side of a house that leans against the next one) - as bake.hide_covered judges
    # charts: one free point is enough (the front wall behind an oriel stays usable)
    walls = {}
    for (bname, ax), lst in near.items():
        for c in lst:
            walls.setdefault((c[0], round(c[2], 3), ax), []).append(c[3])
    covered = {}
    for key, cens in walls.items():
        nvec = np.zeros(3)
        nvec[key[2]] = -1.0
        step = max(1, len(cens) // 48)
        covered[key] = all(cover.covered(p, nvec, near=NEAR_COVER_M) for p in cens[::step])

    def is_covered(entry, ax):
        return covered.get((entry[0], round(entry[2], 3), ax), False)

    def inside_tri(pt, tri, eps=2e-3):
        (ax_, az), (bx_, bz), (cx, cz) = tri
        den = (bz - cz) * (ax_ - cx) + (cx - bx_) * (az - cz)
        if abs(den) < 1e-12:
            return False
        l1 = ((bz - cz) * (pt[0] - cx) + (cx - bx_) * (pt[1] - cz)) / den
        l2 = ((cz - az) * (pt[0] - cx) + (ax_ - cx) * (pt[1] - cz)) / den
        l3 = 1.0 - l1 - l2
        tol = eps / max(1e-6, math.sqrt(abs(den)))
        return l1 >= -tol and l2 >= -tol and l3 >= -tol

    far_objs = []
    matches = []
    n_far = n_kept = 0
    for (ob, mw, nm, mats) in infos:
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.faces.ensure_lookup_table()
        picked = []
        for f in bm.faces:
            m = mats[f.material_index] if f.material_index < len(mats) else None
            if m is None or m.name not in bake_names or m.get("ce_filler"):
                continue
            nrm = nm @ np.array(f.normal, dtype=np.float64)
            nrm /= max(1e-12, np.linalg.norm(nrm))
            if abs(nrm[2]) > 0.1:
                continue
            ax = 0 if nrm[0] > FAR_MIN_N else (1 if nrm[1] > FAR_MIN_N else -1)
            if ax < 0:
                continue
            pts = np.array([tuple(v.co) for v in f.verts], dtype=np.float64) @ mw[:3, :3].T + mw[:3, 3]
            uz = np.stack([pts[:, 1 - ax], pts[:, 2]], axis=1)
            cands = near.get((_base_name(m.name), ax), [])
            # the opposite wall: the farthest plane first (a wall inside the model lies between)
            planes = sorted({round(c[2], 3) for c in cands if c[2] < float(pts[:, ax].mean()) - 0.05})
            found = None
            samples = list(uz) + [uz.mean(axis=0)]
            # points pulled 2 cm into the face: corners on a near wall's edge stay inside
            ctr = uz.mean(axis=0)
            samples = [q + (ctr - q) * min(1.0, 0.02 / max(1e-6, float(np.linalg.norm(ctr - q)))) for q in samples]
            for pl in planes:
                tris = [c for c in cands if abs(c[2] - pl) < 2e-3]
                tris = [c for c in tris if not is_covered(c, ax)]
                if not tris:
                    continue
                per_ob = {}
                for c in tris:
                    per_ob.setdefault(c[0], []).append(c)
                for oname in sorted(per_ob):
                    ts = per_ob[oname]
                    if all(any(inside_tri(q, c[1]) for c in ts) for q in samples):
                        found = (oname, (float(ctr[0]), float(ctr[1])))
                        break
                if found:
                    break
            if found is None:
                n_kept += 1
                continue
            picked.append((f, ax, found))
        if not picked:
            bm.free()
            continue
        # the far faces into an object of their own (same material slots, world = the object's transform)
        fb = bmesh.new()
        vmap = {}
        for (f, ax, found) in picked:
            vs = []
            for v in f.verts:
                if v.index not in vmap:
                    vmap[v.index] = fb.verts.new(v.co)
                vs.append(vmap[v.index])
            try:
                nf = fb.faces.new(vs)
                nf.material_index = f.material_index
            except ValueError:
                continue
        me = bpy.data.meshes.new("ce_far_" + ob.name)
        fb.to_mesh(me)
        fb.free()
        for m in ob.data.materials:
            me.materials.append(m)
        fo = bpy.data.objects.new("ce_far_" + ob.name, me)
        ob.users_collection[0].objects.link(fo)
        fo.parent = ob.parent
        fo.matrix_world = ob.matrix_world.copy()
        MU.tag(fo, node_name="body")
        fo["ce_lvl"] = H._level(ob)
        bmesh.ops.delete(bm, geom=[f for (f, _a, _x) in picked], context="FACES_ONLY")
        bm.to_mesh(ob.data)
        bm.free()
        ob.data.update()
        far_objs.append(fo)
        axes = {ax for (_f, ax, _x) in picked}
        for ax in sorted(axes):
            for (f_, a_, found) in picked:
                if a_ == ax:
                    matches.append((fo.name, found[0], ax, found[1]))
        n_far += len(picked)
    bpy.context.view_layer.update()
    stats["far_faces"] = n_far
    stats["far_kept"] = n_kept
    return far_objs, matches


def far_uvs(charts, far_objs, matches, size):
    """Atlas coordinates of the far faces: every vertex (u, z) (u = y for faces along x, x for faces along y) takes the
    coordinate the opposite wall's chart gives the same (u, z) - an affine map fitted to the chart's corners (the
    chart is planar: exact). Returns the number of faces mapped; a far face whose corners do not land in one chart
    takes the chart of its centre."""
    meshes = {}

    def mesh_data(ob):
        """(world corner positions per loop, uv per loop) of an object (cached)."""
        if ob.name not in meshes:
            me = ob.data
            mw = np.array(ob.matrix_world, dtype=np.float64)
            lv = np.empty(len(me.loops), dtype=np.int64)
            me.loops.foreach_get("vertex_index", lv)
            co = np.array([tuple(v.co) for v in me.vertices], dtype=np.float64) @ mw[:3, :3].T + mw[:3, 3]
            uv = np.empty(len(me.loops) * 2, dtype=np.float64)
            me.uv_layers[BK.UV_NAME].data.foreach_get("uv", uv)
            meshes[ob.name] = (co[lv], uv.reshape(-1, 2))
        return meshes[ob.name]

    # the candidate charts: walls looking along -x or -y, their (u, z) box and an affine map (u, z, 1) -> atlas uv
    cand = []
    for c in charts:
        nrm = c["normal"]
        for ax in (0, 1):
            if nrm[ax] > -FAR_MIN_N:
                continue
            pl, uvl = mesh_data(c["ob"])
            p = pl[c["loops"]]
            A = np.stack([p[:, 1 - ax], p[:, 2], np.ones(len(p))], axis=1)
            M_, _res, _rk, _sv = np.linalg.lstsq(A, uvl[c["loops"]], rcond=None)
            lo = np.array([p[:, 1 - ax].min(), p[:, 2].min()])
            hi = np.array([p[:, 1 - ax].max(), p[:, 2].max()])
            cand.append((c["ob"].name, ax, lo, hi, M_, float((hi - lo).prod())))

    def chart_of(oname, ax, pt):
        best = None
        for (on, a2, lo, hi, M_, area) in cand:
            if on != oname or a2 != ax:
                continue
            if lo[0] - 1e-3 <= pt[0] <= hi[0] + 1e-3 and lo[1] - 1e-3 <= pt[1] <= hi[1] + 1e-3:
                if best is None or area > best[0]:
                    best = (area, M_)
        return best[1] if best else None

    n = 0
    by_far = {}
    for (fname, oname, ax, pt) in matches:
        by_far.setdefault(fname, []).append((oname, ax, pt))
    for fo in far_objs:
        me = fo.data
        if BK.UV_NAME not in me.uv_layers:
            me.uv_layers.new(name=BK.UV_NAME)
        lay = me.uv_layers[BK.UV_NAME]
        mw = np.array(fo.matrix_world, dtype=np.float64)
        nm = np.linalg.inv(mw[:3, :3]).T
        co = np.array([tuple(v.co) for v in me.vertices], dtype=np.float64) @ mw[:3, :3].T + mw[:3, 3]
        uv = np.zeros((len(me.loops), 2), dtype=np.float32)
        refs = by_far.get(fo.name, [])
        for poly in me.polygons:
            nrm = nm @ np.array(poly.normal, dtype=np.float64)
            ax = 0 if abs(nrm[0]) >= abs(nrm[1]) else 1
            pts = co[list(poly.vertices)]
            ctr = np.array([pts[:, 1 - ax].mean(), pts[:, 2].mean()])
            # the reference of this face: the match with the same axis whose sample lies nearest
            refs_ax = [r for r in refs if r[1] == ax]
            if not refs_ax:
                continue
            ref = min(refs_ax, key=lambda r: (r[2][0] - ctr[0]) ** 2 + (r[2][1] - ctr[1]) ** 2)
            M_ = chart_of(ref[0], ax, ctr)
            if M_ is None:
                M_ = chart_of(ref[0], ax, np.array(ref[2]))
            if M_ is None:
                continue
            for li in poly.loop_indices:
                v = co[me.loops[li].vertex_index]
                uv[li] = np.array([v[1 - ax], v[2], 1.0]) @ M_
            n += 1
        lay.data.foreach_set("uv", uv.reshape(-1))
        me.update()
    return n


# --- the bake (buildings3d.bake_house with far walls, floors and cut-out density) ----------------------------------

def bake_city(rig, objs, mats, size, weight_fn=None, ppm_max=512.0, cutout=False, ao=None, far=None, floors=None,
              cut_ppm=CUT_PPM, cut_names=(), flat_lod1=False):
    """H.bake_house plus: charts of cut-out materials get cut_ppm texels per metre (as a weight on the packing's
    density), wall charts above floors["z"] get floors["upper"] of the density, and the far faces (far = (objects,
    matches)) take the atlas coordinates of the opposite walls after the packing (they are not baked)."""
    names = {m.name for m in mats}
    t0 = time.time()
    charts = BK.box_unwrap(objs, lambda m: m is not None and m.name in names, weight_fn)
    if floors:
        zs = sorted(float(z) for z in floors.get("z", ()))
        up = float(floors.get("upper", 0.7))
        for c in charts:
            if abs(c["normal"][2]) > 0.5 or not zs:
                continue
            zc = float(np.mean([p[2] for p, _n in c["centres"]]))
            if zc > zs[0]:
                c["weight"] *= up
    cut_set = set(cut_names)
    if cut_set:
        for c in charts:
            ms = {s.material.name for s in c["ob"].material_slots if s.material is not None}
            if ms & cut_set and not (ms - cut_set):
                c["cut"] = True
    hidden = H._hide_covered(charts, objs + list(far[0] if far else []))
    # cut-out charts: a fixed density (as a weight relative to the density the walls get): two passes
    ppm = BK.pack(charts, size, gutter=2, ppm_max=ppm_max)
    if cut_set and any(c.get("cut") for c in charts):
        for c in charts:
            if c.get("cut"):
                c["weight"] = max(c["weight"], float(cut_ppm) / max(ppm, 1.0))
        ppm = BK.pack(charts, size, gutter=2, ppm_max=ppm_max)
    BK.write_uvs(charts, size)
    stats = dict(atlas=list(size), charts=len(charts), hidden=hidden, ppm=round(ppm, 2),
                 area_m2=round(float(sum(c["area"] for c in charts)), 1), unwrap_s=round(time.time() - t0, 2))
    if far:
        stats["far_mapped"] = far_uvs(charts, far[0], far[1], size)
    flat = _flat_copies(objs) if flat_lod1 else []
    stats["flat_copies"] = len(flat)
    # texel density per wall chart (road walls): the minimum over the charts of the near walls with weight >= 0.5
    dens = [c["ppm"] for c in charts if abs(c["normal"][2]) < 0.5 and c["weight"] >= 0.5 and not c.get("hidden")
            and (c["normal"][0] < -0.5 or c["normal"][1] < -0.5)]
    if dens:
        stats["ppm_road_min"] = round(float(min(dens)), 2)
        stats["ppm_road_max"] = round(float(max(dens)), 2)
    bk = BK.Baker(rig, objs, mats, size, BK.SUPERSAMPLE, BK.SAMPLES)
    t0 = time.time()
    base = BK.downsample(bk.base_color(), BK.SUPERSAMPLE)
    stats["coverage"] = round(float(base[..., 3].mean()), 3)
    out = dict(albedo=None, alpha=None, emit={})
    if cutout:
        op = BK.downsample(bk.opacity(), BK.SUPERSAMPLE)
        out["alpha"] = BK.dilate(op)[..., 0]
    em = BK.downsample(bk.layer("lights"), BK.SUPERSAMPLE)
    if float(em[..., :3].max()) > 0.004:
        out["emit"]["lights"] = BK.dilate(em)[..., :3]
    stats["fillers"], stats["panes"] = H._settle_fillers(objs)
    if ao:
        t_ao = time.time()
        for fo in flat:
            fo.hide_render = True           # the flat copy would close every opening for the occlusion rays
        ao_bk = BK.Baker(rig, objs, mats, size, 1, BK.SAMPLES)
        a = ao_bk.ambient_occlusion(ao.get("distance", 1.5), ao.get("samples", 16), ao.get("ground", True))
        a_far = None
        if far:
            # texels inside another volume (the wall behind an oriel) are never seen from outside - but a far wall
            # reuses them: they keep their colour instead of a dark, noisy grey. Inside = no ray escapes even over
            # 100 m (the occlusion of 2 m lets the rays that run along the inside of the oriel count as open)
            a_far = BK.downsample(ao_bk.ambient_occlusion(100.0, 8, False), 1)
        for fo in flat:
            fo.hide_render = False
        a = BK.downsample(BK._blur_covered(a, 1), 1)
        cov_ao = a[..., 3] > 0.5
        k = float(ao.get("floor", 0.45)) + (1.0 - float(ao.get("floor", 0.45))) * np.power(
            np.clip(a[..., 0], 0.0, 1.0), float(ao.get("gamma", 1.0)))
        k = np.where(cov_ao, k, 1.0)
        if a_far is not None:
            enc = (a_far[..., 3] > 0.5) & (a_far[..., 0] < 0.02)
            k = np.where(enc, 1.0, k)
            stats["enclosed_texels"] = int(enc.sum())
        pm = H._pane_mask(objs, size)
        k = np.where(pm, 1.0, k)
        stats["pane_texels"] = int(pm.sum())
        base = base.copy()
        base[..., :3] *= k[..., None]
        stats["ao_s"] = round(time.time() - t_ao, 2)
        stats["ao_mean"] = round(float((k * cov_ao).sum() / max(1.0, cov_ao.sum())), 3)
    out["albedo"] = BK.dilate(base)[..., :3]
    stats["bake_s"] = round(time.time() - t0, 2)
    out["stats"] = stats
    out["flat"] = flat
    return out


# --- the builder --------------------------------------------------------------------------------------------------

def _caps(objs, geo, mats):
    """A cover slab on every chimney: per mesh island of the objects named *chim* (props3d._caps lays one slab over the
    bounding box of the whole object - over the three chimneys of the Mietshaus a bar from the first to the last)."""
    import bmesh
    cap = mats.vpbr("ce_cap", "#6d6862", rough=0.85)
    n = 0
    for ob in objs:
        if "chim" not in ob.name or "pots" in ob.name:
            continue
        mw = np.array(ob.matrix_world, dtype=np.float64)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.verts.ensure_lookup_table()
        seen = set()
        for v0 in bm.verts:
            if v0.index in seen:
                continue
            stack, isl = [v0], []
            seen.add(v0.index)
            while stack:
                v = stack.pop()
                isl.append(v)
                for e in v.link_edges:
                    w = e.other_vert(v)
                    if w.index not in seen:
                        seen.add(w.index)
                        stack.append(w)
            pts = np.array([tuple(v.co) for v in isl]) @ mw[:3, :3].T + mw[:3, 3]
            lo, hi = pts.min(axis=0), pts.max(axis=0)
            if hi[2] - lo[2] < 0.3:
                continue                # a loose cap plate of the generator, not a chimney shaft
            geo.box(cap, (lo[0] - 0.06, lo[1] - 0.06, hi[2]), (hi[0] + 0.06, hi[1] + 0.06, hi[2] + 0.08), skip=("-z",))
            n += 1
        bm.free()
    return n


def _drop_covered_slopes(objs, wall_names):
    """Removes the sloped faces of walls (gable prisms: the faces along the roof's slopes) that lie on another surface:
    a ray from just under such a face along its normal meets another object within 6 cm - the roof, whose top surface
    runs through the gable's edge, or the coping over it. The sprite never shows them; in real time they fought with
    the roof for the same depth (white stripes along the verges of the house, measured in lod1)."""
    import bmesh
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    n_drop = 0
    for ob in objs:
        mats = [s.material for s in ob.material_slots]
        if not any(m is not None and m.name in wall_names for m in mats):
            continue
        others = [o for o in objs if o is not ob]
        if not others:
            continue
        verts, polys = [], []
        for o in others:
            mw = o.matrix_world
            base = len(verts)
            verts += [mw @ v.co for v in o.data.vertices]
            polys += [[base + i for i in p.vertices] for p in o.data.polygons]
        bvh = BVHTree.FromPolygons(verts, polys, all_triangles=False)
        mw = np.array(ob.matrix_world, dtype=np.float64)
        nm = np.linalg.inv(mw[:3, :3]).T
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        drop = []
        for f in bm.faces:
            m = mats[f.material_index] if f.material_index < len(mats) else None
            if m is None or m.name not in wall_names:
                continue
            n = nm @ np.array(f.normal, dtype=np.float64)
            n /= max(1e-12, np.linalg.norm(n))
            if not 0.15 < n[2] < 0.99:
                continue
            c = mw[:3, :3] @ np.array(f.calc_center_median(), dtype=np.float64) + mw[:3, 3]
            hit = bvh.ray_cast(Vector(tuple(c - n * 0.01)), Vector(tuple(n)), 0.07)
            if hit[0] is not None:
                drop.append(f)
        if drop:
            bmesh.ops.delete(bm, geom=drop, context="FACES")
            bm.to_mesh(ob.data)
            ob.data.update()
            n_drop += len(drop)
        bm.free()
    return n_drop


def _route(spec3d, objs):
    """(materials by name, names of the vpbr materials). As buildings3d._route, but a flat lamp material becomes a
    vpbr lamp (light anchor) only when named in spec3d["lamps"]; the other lit materials (dormer and turret windows)
    keep their light in the emission atlas."""
    mats = {}
    for ob in objs:
        for s in ob.material_slots:
            if s.material is not None:
                if s.material.get("ce_role") is None and BK.has_cutout(s.material):
                    s.material["ce_role"] = "proc"
                roles.tag(s.material)
                mats[s.material.name] = s.material
    force = tuple(spec3d.get("vpbr", ()))
    lamps = tuple(spec3d.get("lamps", ()))
    vpbr = set()
    for name, m in mats.items():
        role, d = roles.tag(m)
        if m.get("ce_atlas"):
            continue
        if m.get("ce_vpbr"):
            vpbr.add(name)
        elif role == "flat" and roles.lamp_from_emit(d.get("emit")) is not None:
            if any(name.startswith(k) for k in lamps):
                vpbr.add(name)
        elif role == "flat" and any(name.startswith(k) for k in force):
            vpbr.add(name)
    return mats, vpbr


def build_city(model_id, spec3d):
    """City buildings with depth (see the module text)."""
    from cesprites import props_buildings as PB
    t0 = time.time()
    PB.WINDOW_LOG = []
    log = []
    restore = _log_walls(log)
    try:
        rig, info, sspec = P._build_source(spec3d)
    finally:
        PB.WINDOW_LOG = None
        restore()
    for e in log:
        for d in e["decals"]:
            pts = d.get("poly") or []
            if pts and not isinstance(pts[0][0], (list, tuple)) and str(d.get("mat", "")).startswith("#") \
                    and not d.get("clock"):
                xs = [p[0] for p in pts]
                ys = [p[1] for p in pts]
                if (max(xs) - min(xs)) * (max(ys) - min(ys)) > 0.75 and min(ys) < 0.05:
                    d["door"] = True
    objs = P._objects(rig)
    core.realize(objs)
    # the sprite's extent: measured on the generator's model before anything is decimated or added
    src_pts = np.concatenate([np.array([tuple(o.matrix_world @ v.co) for v in o.data.vertices]) for o in objs
                              if len(o.data.vertices)])
    stats = {}
    if spec3d.get("decimate"):
        stats["decimated"] = H._decimate(objs, spec3d["decimate"])
        # the decimated crowns shade smooth (flat-shaded facets made the hedge a heap of crystals)
        for ob in objs:
            if any(ob.name.startswith(k) for k in spec3d["decimate"]):
                ob.data.shade_smooth()
    stats["covered_slopes"] = _drop_covered_slopes(objs, {e["material"] for e in log})
    mats = H.Mats()
    geo = H.Geo()
    patches = H.Patches()
    if spec3d.get("railings"):
        stats["railings"] = H._railings(objs, spec3d["railings"], geo, mats)
    opt = dict(spec3d.get("openings") or {})
    flat = bool(spec3d.get("lod1_flat", True)) and bool(spec3d.get("lod1"))
    if flat:
        opt.setdefault("far_ring", False)
    record = []
    if spec3d.get("openings", True) is not False:
        record = cut_openings(rig, objs, log, opt, geo, mats, stats)
    if flat:
        stats["lod0_only_parts"] = _lod0_only(geo, FLAT_LOD0_PREFIXES)
    if spec3d.get("timber"):
        timber_members(record, log, spec3d["timber"], geo, mats, stats, objs)
    if spec3d.get("light_scale"):
        stats["light_scaled"] = H._scale_lights(objs, spec3d["light_scale"])
    if spec3d.get("levels"):
        for ob in objs:
            for pre, lvl in sorted(spec3d["levels"].items()):
                if ob.name.startswith(pre):
                    ob["ce_lvl"] = lvl
    if spec3d.get("gutters", True) is not False:
        stats["pipes"] = H._gutters(objs, dict(spec3d.get("gutters") or {}), geo, mats)
    if spec3d.get("caps", False):
        # props_cities.chimneys() lays its own cap plate on every shaft: off by default
        stats["caps"] = _caps(objs, geo, mats)
    floors = spec3d.get("floors")
    if floors:
        pre = tuple(floors.get("objects", ()))
        stats["floor_cuts"] = H._split_planes(objs, dict(objects=pre, axis=2, at=tuple(floors.get("z", ()))))
    objs = objs + geo.objects(rig, model_id.split("/")[-1])
    objs = objs + patches.objects(rig)
    return _finish_city(model_id, spec3d, rig, info, sspec, objs, stats, t0, patches, src_pts, log)


def _has_light(mat):
    """True when an Emission node of the material is fed or not black."""
    for nd in mat.node_tree.nodes:
        if nd.bl_idname == "ShaderNodeEmission":
            inp = nd.inputs["Color"]
            if inp.is_linked or max(tuple(inp.default_value)[:3]) > 1e-6:
                return True
    return False


def _scale_emission(mat, k):
    """The light of a material x k, in place (an Emission colour fed by a socket gets a scale node)."""
    nt = mat.node_tree
    n = 0
    for nd in list(nt.nodes):
        if nd.bl_idname != "ShaderNodeEmission":
            continue
        inp = nd.inputs["Color"]
        if inp.is_linked:
            src = inp.links[0].from_socket
            nt.links.remove(inp.links[0])
            sc = nt.nodes.new("ShaderNodeVectorMath")
            sc.operation = "SCALE"
            nt.links.new(src, sc.inputs[0])
            sc.inputs["Scale"].default_value = float(k)
            nt.links.new(sc.outputs[0], inp)
        else:
            c = inp.default_value
            inp.default_value = (c[0] * k, c[1] * k, c[2] * k, 1.0)
        n += 1
    return n


def _mul_base(mat, rgb):
    """The base colour of a material x rgb (linear factors), in place: a multiply node before the Principled BSDF."""
    from cesprites import materials as M
    nt = mat.node_tree
    n = 0
    for nd in list(nt.nodes):
        if nd.bl_idname != "ShaderNodeBsdfPrincipled":
            continue
        inp = nd.inputs["Base Color"]
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        a_col, b_col = M._sock(mix.inputs, "A_Color"), M._sock(mix.inputs, "B_Color")
        if inp.is_linked:
            src = inp.links[0].from_socket
            nt.links.remove(inp.links[0])
            nt.links.new(src, a_col)
        else:
            a_col.default_value = tuple(inp.default_value)
        b_col.default_value = (float(rgb[0]), float(rgb[1]), float(rgb[2]), 1.0)
        nt.links.new(M._sock(mix.outputs, "Result_Color"), inp)
        n += 1
    return n


def _finish_city(model_id, spec3d, rig, info, sspec, objs, stats, t0, patches, src_pts, log):
    from .export import sprite_extent
    mats, vpbr_names = _route(spec3d, objs)
    # albedo_mul {material name prefix: (r, g, b)}: a baked material darker or cooler than the generator's (the glass of
    # the office tower: the sprite's metallic glass mirrors a grey sky, the baked base colour alone came out cyan)
    for pre, rgb in sorted((spec3d.get("albedo_mul") or {}).items()):
        for name in sorted(mats):
            if name.startswith(pre) and name not in vpbr_names:
                _mul_base(mats[name], rgb)
    # every light that stays in the atlas x LIGHT_K: the windows the cutter could not open (a window over an eave, a
    # stairwell running into the gable), dormer and turret windows - as the panes of the cut windows (light_k at their
    # creation): AS4R balanced that factor against Arcade at night (PANE_LIGHT_K); at 1.0 a painted window glowed
    # nearly twice as bright as the cut ones beside it
    k_light = float(spec3d.get("light_k", H.PANE_LIGHT_K))
    n_scaled = 0
    for name in sorted(mats):
        m = mats[name]
        if name in vpbr_names or m.get("ce_filler") or m.get("ce_atlas"):
            continue
        # light_mul {material name prefix: factor}: a facade whose painted windows the cutter cannot all open (the
        # lobby of the office tower runs round its chamfered corners) at the factor of its cut panes (shop_light)
        k_m = k_light * next((float(v) for pre, v in sorted((spec3d.get("light_mul") or {}).items())
                              if name.startswith(pre)), 1.0)
        n_scaled += _scale_emission(m, k_m) if _has_light(m) else 0
    stats["lights_scaled"] = n_scaled
    P._open_lamp_boxes(objs, [mats[n] for n in sorted(vpbr_names) if not mats[n].get("ce_vpbr")])
    lod0_objs = [o for o in objs if H._level(o) != "lod1"]
    bake_objs = [o for o in lod0_objs if any(s.material is not None and s.material.name not in vpbr_names
                                             for s in o.material_slots)]
    bake_mats = sorted({s.material.name for o in bake_objs for s in o.material_slots
                        if s.material is not None and s.material.name not in vpbr_names})
    bake_mats = [mats[k] for k in bake_mats]
    cut_names = {m.name for m in bake_mats if BK.has_cutout(m)}
    rail_names = set(cut_names)
    if cut_names and spec3d.get("single_cutout"):
        cut_names = {m.name for m in bake_mats}
    far = None
    far_objs = []
    if spec3d.get("far", True):
        # the walls of the log (and their filler copies) only: roofs, crowns and trims bake as before
        walls = {e["material"] for e in log}
        far_names = {m.name for m in bake_mats if m.name not in rail_names and _base_name(m.name) in walls}
        far_objs, matches = _far_split(bake_objs, far_names, stats)
        if far_objs:
            far = (far_objs, matches)
    size = tuple(spec3d.get("atlas", (1024, 1024)))
    wf = H.weight_fn(spec3d.get("view", "roadside"), dict(spec3d.get("weights") or {}))
    baked = bake_city(rig, bake_objs, bake_mats, size, weight_fn=wf, ppm_max=spec3d.get("ppm_max", 128.0),
                      cutout=bool(cut_names), ao=spec3d.get("ao"), far=far, floors=spec3d.get("floors"),
                      cut_ppm=float(spec3d.get("cut_ppm", CUT_PPM)), cut_names=rail_names,
                      flat_lod1=bool(spec3d.get("lod1_flat", True)) and bool(spec3d.get("lod1")))
    if baked["alpha"] is not None:
        from PIL import Image
        from . import leafatlas
        a8 = np.clip(np.round(baked["alpha"] * 255.0), 0, 255).astype(np.uint8)
        rgb8 = np.zeros(a8.shape + (3,), dtype=np.uint8)
        img = leafatlas.halo(Image.fromarray(np.concatenate([rgb8, a8[..., None]], axis=2), "RGBA"), alpha=0.33, px=2,
                             scissor=0.5)
        baked["alpha"] = np.array(img).astype(np.float64)[:, :, 3] / 255.0
    over = spec3d.get("overrides")
    tr = roles.Translator(glass_class=False, overrides=over)
    levels = ["lod0", "lod1"] if spec3d.get("lod1") else ["lod0"]
    objs = objs + far_objs + baked.get("flat", [])
    lods = []
    pts0 = None
    for li, lvl in enumerate(levels):
        mb = core.MeshBuilder()
        level_objs = [o for o in objs if H._level(o) in ("both", lvl)]
        tl = tr if li == 0 else roles.Translator(glass_class=False, overrides=over)
        for soup in core.soups_of(level_objs, uv_layer=BK.UV_NAME):
            for mi in np.unique(soup.mi):
                mat = soup.material(int(mi))
                sel = soup.mi == mi
                if mat.name in vpbr_names:
                    tl.add_object(mb, P._SubSoup(soup, sel))
                    continue
                if soup.uv is None:
                    raise RuntimeError("%s: %s has no atlas coordinates (only lod0 parts are baked)" % (model_id, soup.name))
                uv = soup.uv[sel].copy()
                uv[:, :, 1] = 1.0 - uv[:, :, 1]
                mb.add("baked_cutout" if mat.name in cut_names else "baked", soup.pos[sel], soup.nor[sel], uv=uv)
        if patches is not None:
            patches.add_to(mb, lvl)
        if li == 0:
            pts0 = mb.points()
        max_d = H.LOD0_M if (li == 0 and len(levels) > 1) else 100000
        lods.append(Lod(lvl, max_d, [Part("body", "%s_body" % lvl, mb.finish(min_height=1e-4), auto_lod=False)]))
    model = P._finish_model(model_id, spec3d, sspec, info, pts0)
    model.extent_m = sprite_extent(src_pts, sspec["camera"].get("view_yaw", 0.0))
    model.auto_lod = False
    model.lods = lods
    model.lights = tr.lights(split_x=0.0)
    model.roughness = float(spec3d.get("roughness", 0.9))
    size = tuple(spec3d.get("atlas", (1024, 1024)))
    big = max(size) > 1024
    alb_name = "albedo.webp" if big else "albedo.png"
    model.texture_files[alb_name] = BK.encode(baked["albedo"], baked["alpha"], "webp" if big else "png")
    model.textures["albedo"] = alb_name
    em = baked["emit"].get("lights")
    if em is not None and float(em.max()) > 0.05:
        model.texture_files["emit.png"] = BK.encode(BK.half(em), None, "png")
        model.textures["emit"] = "emit.png"
    stats["emit_max"] = round(float(em.max()), 3) if em is not None else 0.0
    stats["far_objects"] = len(far_objs)
    model.stats = dict(build_s=round(time.time() - t0, 2), objects=len(objs), bake=baked["stats"], **stats)
    return model
