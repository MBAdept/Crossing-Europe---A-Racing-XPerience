"""AS4 (wave 5): buildings, bridge parts and ships of the mode "Modern" as real-time models (docs/modelle.md
section 15). Builder "house" (catalog3d, export_models.BUILDERS):

  house   a building of the generators (props_buildings, props_road, props_cities) with depth - the builder
          "building" of AS1b (ce3d/props3d.py, unchanged) extended by:
            openings  rectangular and arched windows (round / segmental / pointed tops) cut into every wall that faces
                      along an axis, and into the faces of an octagonal tower ("octagon"); reveals (baked, with ambient
                      occlusion), frames, glazing bars per window kind, sills, panes. AS4R: a pane is the hole filler
                      of its window moved back into the reveal - in the atlas, by day the sprite's painted glass, at
                      night the sprite's light of that window (the same windows lit as in Arcade, x PANE_LIGHT_K) from
                      the emission atlas (AS4's vpbr lamps showed half their light colour by day: brown panes beside
                      blue ones); panes without a painted window behind them (curtain wall, octagon) are atlas patches
            shutters  the painted shutters of a facade as louvred panels in front of the wall (baked: slats in the atlas)
            louvres   belfry openings ("louvre": z range): slanted slats in front of a dark back panel
            clocks    decals marked "clock": a plate (lamp channel 14: its own colour by day, lit at night), frame, hour
                      ticks, hands
            doors     door decals cut in: wings in the decal's colour with a frame, steps; doors wider than 2.6 m are gates
                      with horizontal ribs
            gutters   the gutters and downpipes of props3d on pitched roofs, chimney caps
            sign      lettering as geometry (textgeo) on a panel, lit at night (channel 14)
            curtain   a glass curtain wall (building_tall): spandrel bands (baked), panes (vpbr, the lit ones lamps), mullion
                      fins
            lod1      a second level without the fine parts (frames, bars, sills, gutters, slats, ticks, rails): from the
                      props builder's first switch distance on (60 m at "Details: Mittel")
          Two surfaces: baked (walls, roofs, reveals, shutters, steps) + vpbr (everything else) - rural building budget
          2,000 triangles, city building 10,000, both <= 2 draw calls.

Catalog options of "house" (besides those of props3d's "building": atlas, ppm_max, roughness, view, params, ao, rotor):
  openings   dict: reveal_m, door_m, reveal_color, sill_color, door_color (default: the decal's colour), pane_k (lit
             colour = sprite light x pane_k), pane_lit (weight range), bars {kind: (vertical, horizontal)}, steps,
             skip_faces, louvre (z0, z1), shutter_color
  vpbr       material name prefixes that go to the vpbr surface as flat colours (railings, metal, a cross)
  baked_lamps  lamp materials that stay in the atlas (their light in the emission atlas: signs, lobbies)
  weights    texel density weights (road 1.0, roof, away, under)
  gutters    dict or False (props3d), caps (bool)
  sign       dict(text, face, u, z, h, panel, color, depth)
  curtain    dict(object, floor, band, mull, lit, light)
  octagon    dict(objects, rows (z centres), win (w, h), faces (normal angles in degrees), lit)
  rotate_deg turns the whole model about the vertical axis (the ferry: the sprite shows its side)
  lod1       True: a second level without the fine parts
"""
import math
import time
import zlib

import numpy as np

from . import bake as BK
from . import core, roles
from . import props3d as P
from .export import Lod, Part

REVEAL_M = 0.12
FRAME_W = 0.06
BAR_W = 0.045
SILL_M = 0.05
PANE_K = 0.47            # lit colour of a pane = the sprite's light colour x PANE_K (sRGB): dark by day, bright at night
LOD0_M = 60.0             # max_dist_m of lod0 when there is a lod1 (the props builder uses its own levels)
# AS4R (art review AS4, M3/M6): window panes are no vpbr lamps any more - an unlit lamp shows half its light colour,
# brown panes beside blue ones by day. A pane is the hole filler of its window moved back into the reveal: by day the
# sprite's painted glass (one colour for every pane of a facade, ambient occlusion of the reveal), at night the
# sprite's own light of that window (the same windows lit as in Arcade) from the emission atlas, times PANE_LIGHT_K -
# measured against Arcade at night (Paris - Tours km 131.3, 23:00).
PANE_LIGHT_K = 0.55
PANE_TINT = ("#8fa3b5", 0.08)     # the pane's glass a little towards the sky (see _filler_mat)


# --- small helpers -----------------------------------------------------------------------------------------------

def _hex(c):
    h = c.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def _scale_hex(c, k):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v * k)))) for v in _hex(c))


class Mats:
    """Materials of one build (the Blender scene is reset for every model: no module-level cache)."""

    def __init__(self):
        self.m = {}

    def vpbr(self, name, color, rough=0.5, metal=0.0, lamp=None):
        key = ("v", name)
        if key not in self.m:
            self.m[key] = P._vpbr_mat(name, color, rough=rough, metal=metal, lamp=lamp)
        return self.m[key]

    def baked(self, name, color, rough=0.85):
        key = ("b", name)
        if key not in self.m:
            self.m[key] = P._baked_flat(name, color)
        return self.m[key]

    def pane(self, name, glass, light=None, strength=1.0):
        """AS4R: a flat pane baked into a solid patch of the atlas (Patches): the glass colour by day; with a light, lit
        at night from the emission atlas (no vpbr lamp: unlit, a lamp shows half its light colour - brown glass)."""
        key = ("p", name)
        if key not in self.m:
            from cesprites import materials as M
            emit = {"lights": (light, float(strength))} if light else None
            m = M.basic(name, glass, rough=0.1, emit=emit)
            m["ce_atlas"] = 1
            self.m[key] = m
        return self.m[key]

    def slats(self, name, color, pitch=0.11):
        """Louvred shutter: horizontal dark joints every `pitch` m (procedural -> baked into the atlas)."""
        key = ("s", name)
        if key not in self.m:
            from cesprites import materials as M
            m, nb = M.new_material(name)
            _x, _y, z = nb.coords()
            c = M.srgb(color)
            line = nb.lt(nb.math("FLOORED_MODULO", z, pitch), pitch * 0.3)
            col = nb.mix(nb.mul(line, 0.6), c, (c[0] * 0.45, c[1] * 0.45, c[2] * 0.45, 1.0))
            self.m[key] = M.finish(m, nb, M.principled(nb, col, rough=0.6, spec=0.3))
        return self.m[key]


class Geo:
    """Triangles per (material, level) collected in root space; one object per pair. level: "both" (lod0 and
    lod1), "lod0" (fine parts, near level only) or "lod1" (far level only)."""

    def __init__(self):
        self.tris = {}
        self.xform = None           # 4x4 object -> root matrix for what is added (None = root space)

    def tri(self, mat, a, b, c, normal, level="both"):
        a, b, c = (np.asarray(v, dtype=np.float64) for v in (a, b, c))
        normal = np.asarray(normal, dtype=np.float64)
        if self.xform is not None:
            m = self.xform
            a, b, c = (m[:3, :3] @ v + m[:3, 3] for v in (a, b, c))
            normal = np.linalg.inv(m[:3, :3]).T @ normal
        if np.cross(b - a, c - a) @ normal < 0:
            b, c = c, b
        self.tris.setdefault((mat.name, level), (mat, []))[1].append((a, b, c))

    def quad(self, mat, a, b, c, d, normal, level="both"):
        self.tri(mat, a, b, c, normal, level)
        self.tri(mat, a, c, d, normal, level)

    def poly(self, mat, pts, normal, level="both"):
        """Convex polygon as a fan."""
        for i in range(1, len(pts) - 1):
            self.tri(mat, pts[0], pts[i], pts[i + 1], normal, level)

    def box(self, mat, lo, hi, level="both", skip=()):
        """Axis-aligned box; skip: faces left out ("-x", "+x", "-y", "+y", "-z", "+z")."""
        x0, y0, z0 = (float(v) for v in lo)
        x1, y1, z1 = (float(v) for v in hi)
        F = {"+z": ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1)),
             "-z": ([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], (0, 0, -1)),
             "-y": ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, -1, 0)),
             "+y": ([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], (0, 1, 0)),
             "-x": ([(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)], (-1, 0, 0)),
             "+x": ([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], (1, 0, 0))}
        for k, (q, n) in F.items():
            if k not in skip:
                self.quad(mat, q[0], q[1], q[2], q[3], n, level)

    def objects(self, rig, prefix):
        import bmesh
        from cesprites import meshutil as MU
        out = []
        for (name, level) in sorted(self.tris):
            mat, tris = self.tris[(name, level)]
            bm = bmesh.new()
            for (a, b, c) in tris:
                vs = [bm.verts.new(tuple(float(x) for x in p)) for p in (a, b, c)]
                try:
                    bm.faces.new(vs)
                except ValueError:
                    pass
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
            ob = MU.make("%s_%s_%s" % (prefix, level, name), bm, mat, parent=rig.root)
            MU.tag(ob, node_name="body")
            ob["ce_lvl"] = level
            out.append(ob)
        return out


class Patches:
    """AS4R: flat-coloured parts without a chart of their own (the panes of the curtain wall and of the octagonal
    tower: 840 panes of a tower would not fit the atlas). One small square per material, far below the model, is baked
    with the rest; afterwards every triangle of such a part takes the atlas coordinate of its square: the glass colour
    by day, the material's light at night. geo: the triangles (a Geo, levels as there)."""

    def __init__(self):
        self.geo = Geo()
        self.objs = {}

    def objects(self, rig):
        import bmesh
        from cesprites import meshutil as MU
        names = sorted({name for (name, _lvl) in self.geo.tris})
        for i, name in enumerate(names):
            mat = [m for (n, _l), (m, _t) in self.geo.tris.items() if n == name][0]
            bm = bmesh.new()
            x, z, s = -20.0 + i * 1.0, -60.0, 0.2
            vs = [bm.verts.new(p) for p in ((x - s, 0.0, z - s), (x + s, 0.0, z - s), (x + s, 0.0, z + s), (x - s, 0.0, z + s))]
            bm.faces.new(vs)
            ob = MU.make("ce_patch_%02d" % i, bm, mat, parent=rig.root)
            MU.tag(ob, node_name="body")
            ob["ce_lvl"] = "patch"
            self.objs[name] = ob
        return [self.objs[n] for n in names]

    def add_to(self, mb, lvl):
        """The triangles of level lvl into mb (class baked), each corner at the centre of its material's square."""
        for (name, level) in sorted(self.geo.tris):
            if level not in ("both", lvl):
                continue
            _mat, tris = self.geo.tris[(name, level)]
            ob = self.objs[name]
            lay = ob.data.uv_layers[BK.UV_NAME]
            uv = np.empty(len(ob.data.loops) * 2, dtype=np.float32)
            lay.data.foreach_get("uv", uv)
            c = uv.reshape(-1, 2).astype(np.float64).mean(axis=0)
            pos = np.array([[a, b, cc] for (a, b, cc) in tris], dtype=np.float64)
            n = np.cross(pos[:, 1] - pos[:, 0], pos[:, 2] - pos[:, 0])
            n /= np.maximum(1e-12, np.linalg.norm(n, axis=1))[:, None]
            mb.add("baked", pos, np.repeat(n[:, None, :], 3, axis=1), uv=np.array([float(c[0]), float(1.0 - c[1])]))


def _level(ob):
    return str(ob.get("ce_lvl", "both"))


# --- window outlines -----------------------------------------------------------------------------------------------

def _outline(a, b, c, d, top=None, inset=0.0, n_arc=8, rise=0.16):
    """Outline (u, z) of an opening, counter-clockwise: a rectangle, or with a round / segmental ("seg") / pointed top.
    inset > 0: the outline moved inwards by that much (concentric arcs) - frames are the ring between the two."""
    a, b, c, d = a + inset, b - inset, c + inset, d - inset
    if b - a < 0.02 or d - c < 0.02:
        return []
    if not top:
        return [(a, c), (b, c), (b, d), (a, d)]
    w = b - a
    um = (a + b) * 0.5
    pts = [(a, c), (b, c)]
    if top == "round":
        r = w * 0.5
        zc = d - r
        if zc < c:
            zc = c
        # the polygon circumscribes the painted circle (its chords would leave slivers of painted window - and of
        # its light at night - on the wall): the inner vertices lie at r / cos(half a step)
        rr = r / math.cos(math.pi / n_arc / 2.0)
        pts.append((b, zc))
        for k in range(n_arc):
            t = math.pi * (k + 0.5) / n_arc
            pts.append((um + rr * math.cos(t), zc + rr * math.sin(t)))
        pts.append((a, zc))
    elif top == "seg":
        s = max(0.02, (w + 2 * inset) * rise - inset * 0.0)
        R = ((w * 0.5) ** 2 + s * s) / (2 * s)
        zc = d - R
        half = math.asin(min(1.0, (w * 0.5) / R))
        pts.append((b, d - s))
        for k in range(1, n_arc):
            t = math.pi * 0.5 - half + 2 * half * k / n_arc
            pts.append((um + R * math.cos(t), zc + R * math.sin(t)))
        pts.append((a, d - s))
    elif top == "pointed":
        # two arcs of radius w springing at d - 0.866 w
        spring = d - 0.866 * w
        n = max(2, n_arc // 2)
        for k in range(n + 1):
            t = math.pi / 3 * k / n                    # right arc: centre (a, spring), from (b, spring) up to the apex
            pts.append((a + w * math.cos(t), spring + w * math.sin(t)))
        for k in range(1, n + 1):
            t = math.pi * 2 / 3 + math.pi / 3 * k / n  # left arc: centre (b, spring), from the apex down to (a, spring)
            pts.append((b + w * math.cos(t), spring + w * math.sin(t)))
    else:
        raise ValueError(top)
    return pts


def _area(pts):
    """Area of a polygon [(u, z)] (shoelace)."""
    s = 0.0
    for i in range(len(pts)):
        (u0, z0), (u1, z1) = pts[i], pts[(i + 1) % len(pts)]
        s += u0 * z1 - u1 * z0
    return abs(s) * 0.5


def _far_inset(a, b, c, d, top, frame_area):
    """Inset of the lod1 frame ring: the ring between the outline and this inset covers frame_area (the frame ring and
    the glazing bars of lod0). lod1 has no bars (under a pixel there, they would only flicker), but from afar the
    window keeps the mean colour of lod0, and at night the same share of a lit pane."""
    full = _area(_outline(a, b, c, d, top=top))
    lo, hi = FRAME_W, max(FRAME_W, min(b - a, d - c) * 0.3)
    for _i in range(24):
        mid = (lo + hi) * 0.5
        inner = _outline(a, b, c, d, top=top, inset=mid)
        if not inner or full - _area(inner) > frame_area:
            hi = mid
        else:
            lo = mid
    return lo


def _half_width_at(outline, z):
    """(u_min, u_max) of a convex outline at height z, or None."""
    xs = []
    n = len(outline)
    for i in range(n):
        (u0, z0), (u1, z1) = outline[i], outline[(i + 1) % n]
        if (z0 - z) * (z1 - z) <= 0 and abs(z1 - z0) > 1e-9:
            t = (z - z0) / (z1 - z0)
            xs.append(u0 + (u1 - u0) * t)
    if len(xs) < 2:
        return None
    return min(xs), max(xs)


def _top_at(outline, u):
    """Highest z of a convex outline above u (the arch over a vertical glazing bar), or None."""
    zs = []
    n = len(outline)
    for i in range(n):
        (u0, z0), (u1, z1) = outline[i], outline[(i + 1) % n]
        if (u0 - u) * (u1 - u) <= 0 and abs(u1 - u0) > 1e-9:
            t = (u - u0) / (u1 - u0)
            zs.append(z0 + (z1 - z0) * t)
    return max(zs) if zs else None


# --- the cut ------------------------------------------------------------------------------------------------------------

def _face_frame(n):
    """(class, u axis) of a wall face facing along an axis; None for roofs, floors and slanted walls."""
    if abs(n[2]) > 0.5:
        return None, None
    if max(abs(n[0]), abs(n[1])) < 0.95:
        return None, None
    if abs(n[1]) >= abs(n[0]):
        return ("front" if n[1] < 0 else "back"), np.array([1.0, 0.0, 0.0])
    return ("left" if n[0] < 0 else "right"), np.array([0.0, 1.0, 0.0])


def _decal_poly(d, cls):
    """Polygon (u, z) of a decal on a face of class cls, in the coordinates decal_mask paints it (world x on front and
    back - mirrored about x = 0 when sym, world y on the sides), or None when the decal is not on that face."""
    face = d.get("face", "front")
    if face == "side":
        if cls not in ("left", "right") or (d.get("only") and d["only"] != cls):
            return None
    elif face != cls:
        return None
    pts = [(float(x), float(y)) for (x, y) in d["poly"]]
    if face in ("front", "back") and d.get("sym", True):
        pts = pts + [(-x, y) for (x, y) in reversed(pts) if x > 1e-6]
        pts = [p for i, p in enumerate(pts) if i == 0 or abs(p[0] - pts[i - 1][0]) + abs(p[1] - pts[i - 1][1]) > 1e-6]
    # counter-clockwise
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    return pts if area > 0 else list(reversed(pts))


def _bars(kind, w, h, opt, g):
    """Glazing bars of a window w x h: ([u fractions of the vertical bars], [z fractions of the horizontal bars])."""
    if g.get("mull"):
        m = g["mull"]
        nv = int(m.get("v", 1))
        hs = m.get("h", 1)
        hf = list(hs) if isinstance(hs, (list, tuple)) else [(k + 1) / (hs + 1) for k in range(int(hs))]
        return [(k + 1) / (nv + 1) for k in range(nv)], hf
    bars = opt.get("bars", {})
    if kind in bars:
        nv, nh = bars[kind]
        vf = [(k + 1) / (nv + 1) for k in range(nv)]
        hf = list(nh) if isinstance(nh, (list, tuple)) else [(k + 1) / (nh + 1) for k in range(nh)]
        return vf, hf
    vf = [0.5] if w > 0.55 else []
    hf = [0.62] if h > 0.9 else []
    return vf, hf


def _window_kind(g, w, h):
    if g.get("kind") in ("shop", "door"):
        return g["kind"]
    if w >= 2.2 and h >= 1.8:
        return "large"
    return "win"


class Opening:
    """One opening of a face: outline (u, z), kind (window | door | louvre), its grid / decal."""

    def __init__(self, outline, kind, src, gi, rect, top=None):
        self.outline = outline
        self.kind = kind
        self.src = src
        self.gi = gi
        self.rect = rect                # (a, b, c, d) bounding box
        self.top = top


def _filler_mat(mat, cache, light_k=None, sink=0.0, tint=None):
    """Copy of a facade material for the hole fillers of the colour bake (see bake_house). light_k None: without its
    light - the filler of a door or a louvre, deleted after the colour bake. AS4R: light_k = k - with the sprite's
    light of the window times k: the filler becomes the pane, moved `sink` m back into its reveal after the bakes;
    tint = (hex, share): its base colour taken towards a sky colour (the reflection the vpbr glass of AS4 had - the
    flat baked pane came out 10 levels darker, and the edges of the frames flickered more against it)."""
    key = (mat.name, light_k)
    if key in cache:
        return cache[key]
    m = mat.copy()
    m.name = ("ce_pane_" if light_k is not None else "ce_fill_") + mat.name
    nt = m.node_tree
    if light_k is not None and tint:
        from cesprites import materials as M
        bsdf = [nd for nd in nt.nodes if nd.bl_idname == "ShaderNodeBsdfPrincipled"]
        if bsdf:
            inp = bsdf[0].inputs["Base Color"]
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.inputs["Factor"].default_value = float(tint[1])
            a_col, b_col = M._sock(mix.inputs, "A_Color"), M._sock(mix.inputs, "B_Color")
            if inp.is_linked:
                src = inp.links[0].from_socket
                nt.links.remove(inp.links[0])
                nt.links.new(src, a_col)
            else:
                a_col.default_value = tuple(inp.default_value)
            b_col.default_value = M.srgb(tint[0])
            nt.links.new(M._sock(mix.outputs, "Result_Color"), inp)
    for nd in list(nt.nodes):
        if nd.bl_idname != "ShaderNodeEmission":
            continue
        inp = nd.inputs["Color"]
        if light_k is None:
            for lk in list(inp.links):
                nt.links.remove(lk)
            inp.default_value = (0.0, 0.0, 0.0, 1.0)
        elif inp.is_linked:
            src = inp.links[0].from_socket
            nt.links.remove(inp.links[0])
            sc = nt.nodes.new("ShaderNodeVectorMath")
            sc.operation = "SCALE"
            nt.links.new(src, sc.inputs[0])
            sc.inputs["Scale"].default_value = float(light_k)
            nt.links.new(sc.outputs[0], inp)
        else:
            c = inp.default_value
            inp.default_value = (c[0] * light_k, c[1] * light_k, c[2] * light_k, 1.0)
    m["ce_filler"] = 1
    if light_k is not None:
        m["ce_pane"] = 1
        m["ce_sink"] = float(sink)
    cache[key] = m
    return m


def _pane_mask(objs, size, grow=1):
    """AS4R: texels (atlas size, top row first) covered by the panes (faces of a ce_pane material) - rasterised from
    their atlas coordinates and grown by `grow` texels. The ambient occlusion leaves them out: a pane darkened towards
    its frame gave the frame's edge more contrast, and at 120 m and more the windows flickered (1.7 % of the pixels per
    quarter-pixel step against 0.1 % with AS4's flat panes, measured)."""
    W, H = size
    mask = np.zeros((H, W), dtype=bool)
    for ob in objs:
        slots = [s.material for s in ob.material_slots]
        idx = {i for i, m in enumerate(slots) if m is not None and m.get("ce_pane")}
        if not idx or BK.UV_NAME not in ob.data.uv_layers:
            continue
        me = ob.data
        me.calc_loop_triangles()
        lay = me.uv_layers[BK.UV_NAME]
        uv = np.empty(len(me.loops) * 2, dtype=np.float64)
        lay.data.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2)
        for lt in me.loop_triangles:
            if lt.material_index not in idx:
                continue
            p = np.array([[uv[li][0] * W - 0.5, (1.0 - uv[li][1]) * H - 0.5] for li in lt.loops])
            x0, y0 = np.floor(p.min(axis=0)).astype(int) - 1
            x1, y1 = np.ceil(p.max(axis=0)).astype(int) + 1
            x0, y0, x1, y1 = max(0, x0), max(0, y0), min(W - 1, x1), min(H - 1, y1)
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
            (ax, ay), (bx, by), (cx, cy) = p
            den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(den) < 1e-12:
                continue
            l1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
            l2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
            l3 = 1.0 - l1 - l2
            inside = (l1 >= -1e-6) & (l2 >= -1e-6) & (l3 >= -1e-6)
            mask[y0:y1 + 1, x0:x1 + 1] |= inside
    for _ in range(grow):
        g = mask.copy()
        g[1:, :] |= mask[:-1, :]
        g[:-1, :] |= mask[1:, :]
        g[:, 1:] |= mask[:, :-1]
        g[:, :-1] |= mask[:, 1:]
        mask = g
    return mask


def _settle_fillers(objs):
    """After the colour and light bakes: deletes the fillers of doors and louvres, and moves the panes (fillers of a
    ce_pane material) back by their ce_sink along the inward wall normal - split off the wall first, so the opening's
    edge stays where it is; their atlas coordinates (the painted window, its light) stay. Returns (deleted, moved)."""
    import bmesh
    n_del = n_pane = 0
    for ob in objs:
        slots = [s.material for s in ob.material_slots]
        drop_idx = {i for i, m in enumerate(slots) if m is not None and m.get("ce_filler") and not m.get("ce_pane")}
        pane_idx = {i: float(m.get("ce_sink", 0.0)) for i, m in enumerate(slots) if m is not None and m.get("ce_pane")}
        if not drop_idx and not pane_idx:
            continue
        mw = np.array(ob.matrix_world, dtype=np.float64)
        m3 = mw[:3, :3]
        inv3 = np.linalg.inv(m3)
        nm = inv3.T
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        drop = [f for f in bm.faces if f.material_index in drop_idx]
        n_del += len(drop)
        if drop:
            bmesh.ops.delete(bm, geom=drop, context="FACES_ONLY")
        panes = [f for f in bm.faces if f.material_index in pane_idx]
        if panes:
            res = bmesh.ops.split(bm, geom=panes, use_only_faces=False)
            bm.verts.index_update()
            moved = set()
            for f in [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]:
                n_w = nm @ np.array(f.normal, dtype=np.float64)
                n_w /= max(1e-12, np.linalg.norm(n_w))
                off = inv3 @ (-n_w * pane_idx[f.material_index])
                for v in f.verts:
                    if v.index in moved:
                        continue
                    v.co = tuple(float(a) for a in (np.array(v.co, dtype=np.float64) + off))
                    moved.add(v.index)
                n_pane += 1
        bm.to_mesh(ob.data)
        bm.free()
        ob.data.update()
    return n_del, n_pane


def _hide_covered(charts, objs, weight=0.03, rays=14, samples=96):
    """bake.hide_covered without the hole fillers in the ray test: a filler closes its opening, and every reveal
    behind it would count as covered (no texels for the reveals)."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    verts, polys = [], []
    for ob in objs:
        mw = ob.matrix_world
        fill = {i for i, s in enumerate(ob.material_slots) if s.material is not None and s.material.get("ce_filler")}
        base = len(verts)
        verts += [mw @ v.co for v in ob.data.vertices]
        polys += [[base + i for i in p.vertices] for p in ob.data.polygons if p.material_index not in fill]
    bvh = BVHTree.FromPolygons(verts, polys, all_triangles=False)
    dirs = [(0.0, 0.0, 1.0)]
    for el, n in ((25.0, rays // 2), (65.0, rays - rays // 2 - 1)):
        for k in range(n):
            a = 2 * math.pi * (k + 0.5) / n
            ce = math.cos(math.radians(90.0 - el))
            se = math.sin(math.radians(90.0 - el))
            dirs.append((math.cos(a) * ce, math.sin(a) * ce, se))
    hidden = 0
    for c in charts:
        n = c["normal"]
        up = np.array([0.0, 0.0, 1.0]) if abs(n[2]) < 0.9 else np.array([0.0, 1.0, 0.0])
        u = np.cross(up, n)
        u /= np.linalg.norm(u)
        v = np.cross(n, u)
        pts = c["centres"]
        step = max(1, -(-len(pts) // samples))
        free = False
        for p, fn in pts[::step]:
            o = Vector(p + fn * 0.03)
            for d in dirs:
                w = u * d[0] + v * d[1] + n * d[2]
                if float(np.dot(w, fn)) <= 0.05:
                    continue
                if bvh.ray_cast(o, Vector(w), 2000.0)[0] is None:
                    free = True
                    break
            if free:
                break
        if not free:
            c["weight"] = min(c["weight"], weight)
            c["hidden"] = True
            hidden += 1
    return hidden


def bake_house(rig, objs, mats, size, weight_fn=None, ppm_max=512.0, cutout=False, ao=None):
    """bake.bake_atlas with hole fillers. The openings are cut before the bake; every hole is closed by a filler face
    (a copy of the facade material) while the colour is baked, so the texels inside a hole carry the window the sprite
    paints there - not the frame colour that dilation would spread into it: mipmaps average the wall with its
    windows, and at a distance no light halo surrounds the openings. AS4R: the filler of a window keeps the sprite's
    light of that window (x PANE_LIGHT_K) and becomes the pane - after the colour and light bakes it is moved back
    into the reveal (_settle_fillers), before the ambient occlusion, which then darkens the pane towards its reveal;
    the fillers of doors and louvres bake black and are deleted there."""
    names = {m.name for m in mats}
    t0 = time.time()
    charts = BK.box_unwrap(objs, lambda m: m is not None and m.name in names, weight_fn)
    hidden = _hide_covered(charts, objs)
    ppm = BK.pack(charts, size, gutter=2, ppm_max=ppm_max)
    BK.write_uvs(charts, size)
    stats = dict(atlas=list(size), charts=len(charts), hidden=hidden, ppm=round(ppm, 2),
                 area_m2=round(float(sum(c["area"] for c in charts)), 1), unwrap_s=round(time.time() - t0, 2))
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
    stats["fillers"], stats["panes"] = _settle_fillers(objs)
    if ao:
        t_ao = time.time()
        ao_bk = BK.Baker(rig, objs, mats, size, 1, BK.SAMPLES)
        a = ao_bk.ambient_occlusion(ao.get("distance", 1.5), ao.get("samples", 16), ao.get("ground", True))
        a = BK.downsample(BK._blur_covered(a, 1), 1)
        cov_ao = a[..., 3] > 0.5
        k = float(ao.get("floor", 0.45)) + (1.0 - float(ao.get("floor", 0.45))) * np.power(
            np.clip(a[..., 0], 0.0, 1.0), float(ao.get("gamma", 1.0)))
        # texels of the removed fillers have no occlusion value of their own: they keep their colour (they are only
        # ever seen through the mipmaps, as the painted window of the sprite)
        k = np.where(cov_ao, k, 1.0)
        # AS4R: neither do the panes (flat glass as AS4's panes were: see _pane_mask)
        pm = _pane_mask(objs, size)
        k = np.where(pm, 1.0, k)
        stats["pane_texels"] = int(pm.sum())
        base = base.copy()
        base[..., :3] *= k[..., None]
        stats["ao_s"] = round(time.time() - t_ao, 2)
        stats["ao_mean"] = round(float((k * cov_ao).sum() / max(1.0, cov_ao.sum())), 3)
    out["albedo"] = BK.dilate(base)[..., :3]
    stats["bake_s"] = round(time.time() - t0, 2)
    out["stats"] = stats
    return out


def _overlaps(r1, r2, m=0.05):
    return not (r1[1] + m <= r2[0] or r2[1] + m <= r1[0] or r1[3] + m <= r2[2] or r2[3] + m <= r1[2])


class Cover:
    """Is a point of a wall covered by another volume of the model? A ray from the point along the wall normal: when
    the first face it meets looks the same way, the point lies inside a volume (the back of a church tower inside the
    nave); a face looking back within `near` metres stands right in front of it (a wall against a wall)."""

    def __init__(self, objs):
        from mathutils.bvhtree import BVHTree
        verts, polys = [], []
        for ob in objs:
            mw = ob.matrix_world
            base = len(verts)
            verts += [mw @ v.co for v in ob.data.vertices]
            polys += [[base + i for i in p.vertices] for p in ob.data.polygons]
        self.bvh = BVHTree.FromPolygons(verts, polys, all_triangles=False)

    def covered(self, p, n, near=0.3):
        from mathutils import Vector
        o = Vector(tuple(float(v) for v in (np.asarray(p) + np.asarray(n) * 0.02)))
        hit = self.bvh.ray_cast(o, Vector(tuple(float(v) for v in n)), 200.0)
        if hit[0] is None:
            return False
        if float(np.asarray(hit[1]) @ np.asarray(n)) > 0.0:
            return True                 # inside a volume
        return hit[3] < near


def cut_openings(rig, objs, log, opt, geo, mats, stats):
    """Cuts the windows and doors of the facade materials into their walls; reveals, frames, bars, sills, panes, shutters,
    louvres, doors and steps go to geo. Clocks are placed too (they are no openings)."""
    import bmesh
    by_mat = {e["material"]: e for e in log}
    reveal_m = float(opt.get("reveal_m", REVEAL_M))
    reveal = mats.baked("ce_reveal", opt.get("reveal_color", "#d9d2c6"))
    sill = mats.vpbr("ce_sill", opt.get("sill_color", "#bdb8ae"), rough=0.8)
    step_mat = mats.baked("ce_step", opt.get("step_color", "#b3ada3"))
    lit_w = opt.get("pane_lit", (0.55, 0.9))
    pane_k = float(opt.get("pane_k", PANE_K))
    pane_light = opt.get("pane_light", PANE_LIGHT_K)      # None: AS4's vpbr panes
    far_ring = bool(opt.get("far_ring", True))
    louvre = opt.get("louvre")
    fac = [o for o in objs if any(s.material is not None and s.material.name in by_mat for s in o.material_slots)]
    if not fac:
        return
    cover = Cover(objs)
    fill_cache = {}
    n_open = n_shut = n_louvre = n_door = n_clock = n_skip = n_hidden = 0
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
            cls, u_ax = _face_frame(n)
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
                """An opening that would open into another volume of the model (inner faces, the tower inside the
                nave): its centre and corners tested with a ray along the wall normal."""
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
            # doors first: windows that overlap a door give way to it
            doors = []
            for d in e["decals"]:
                if not d.get("door"):
                    continue
                pts = _decal_poly(d, cls)
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
                    doors.append(Opening(pts, "door", d, -1, rect))
            holes = list(doors)
            # door grids of props_cities walls (kind "door"): door openings, before the windows
            for gi, g in enumerate(e["grids"]):
                if g.get("kind") != "door" or cls not in P.GRID_FACES.get(g.get("face", "front"), ("front", "back")):
                    continue
                for rect in g.get("rects") or []:
                    if not P._inside_poly(((rect[0] + rect[1]) * 0.5, (rect[2] + rect[3]) * 0.5), poly) or hidden(rect):
                        continue
                    src = dict(mat=g.get("glass", "#5a3a22") if str(g.get("glass", "")).startswith("#") else "#5a3a22")
                    holes.append(Opening(_outline(*rect, top=g.get("top")), "door", src, gi, rect, g.get("top")))
            for gi, g in enumerate(e["grids"]):
                if g.get("kind") == "door" or cls not in P.GRID_FACES.get(g.get("face", "front"), ("front", "back")):
                    continue
                top = "round" if g.get("arch") else g.get("top")
                for rect in (g["rects"] if "rects" in g else P._grid_windows(g)):
                    if not inside(rect):
                        continue
                    if any(_overlaps(rect, h.rect) for h in holes):
                        n_skip += 1
                        continue
                    if hidden(rect):
                        n_hidden += 1
                        continue
                    zc = (rect[2] + rect[3]) * 0.5
                    kind = "louvre" if louvre and louvre[0] <= zc <= louvre[1] else "window"
                    holes.append(Opening(_outline(*rect, top=top), kind, g, gi, rect, top))
            clocks = [d for d in e["decals"] if d.get("clock") and _decal_poly(d, cls) is not None]
            for d in clocks:
                pts = _decal_poly(d, cls)
                us = [q[0] for q in pts]
                zs = [q[1] for q in pts]
                rect = (min(us), max(us), min(zs), max(zs))
                if P._inside_poly(((rect[0] + rect[1]) * 0.5, (rect[2] + rect[3]) * 0.5), poly) and not hidden(rect):
                    _clock(geo, mats, d, rect, p3, n, u_ax, opt)
                    n_clock += 1
            if not holes:
                continue
            tris = P._cdt_with_holes(poly, [h.outline for h in holes])
            if not tris:
                continue
            for (a2, b2, c2) in tris:
                new_faces.append((p3(*a2), p3(*b2), p3(*c2), n, f.material_index))
            drop.append(f)
            # hole fillers: the painted window inside every hole for the colour bake; the fillers of doors and louvres
            # are deleted again in bake_house, those of windows become the panes (AS4R: moved back into the reveal)
            fmat = _filler_mat(mat, fill_cache)
            pmat = (_filler_mat(mat, fill_cache, light_k=pane_light, sink=reveal_m, tint=opt.get("pane_tint", PANE_TINT))
                    if pane_light is not None else None)
            names_ob = [m.name if m is not None else "" for m in ob.data.materials]
            for m_ in [x for x in (fmat, pmat) if x is not None]:
                if m_.name not in names_ob:
                    ob.data.materials.append(m_)
                    names_ob.append(m_.name)
            for h in holes:
                use = pmat if (pmat is not None and h.kind == "window") else fmat
                slot = names_ob.index(use.name)
                q = [p3(u, z) for (u, z) in h.outline]
                for i in range(1, len(q) - 1):
                    new_faces.append((q[0], q[i], q[i + 1], n, slot))
            for h in holes:
                n_open += 1
                depth = reveal_m if h.kind != "door" else float(opt.get("door_m", 0.1))
                _reveal(geo, reveal, h.outline, p3, n, u_ax, depth)
                if h.kind == "door":
                    _door(geo, mats, h, p3, n, u_ax, depth, opt, step_mat, e)
                    n_door += 1
                    continue
                g = h.src
                a, b, c, d = h.rect
                if h.kind == "louvre":
                    _louvre(geo, mats, h, p3, n, u_ax, depth, opt)
                    n_louvre += 1
                    continue
                kind = _window_kind(g, b - a, d - c)
                fcol = g.get("frame", e.get("frame", "#e9e6de"))
                fm = mats.vpbr("ce_frame_%s" % fcol.lstrip("#"), fcol, rough=0.55)
                if pane_light is None:
                    # AS4's panes (vpbr; the lit ones lamps of channel 12) - only when a catalog entry asks for them
                    gcol = g.get("glass", e.get("glass", "#26313b"))
                    hsh = zlib.crc32(("%s|%d|%.2f|%.2f|%.2f" % (ob.name, h.gi, a, c, w)).encode()) / 2.0 ** 32
                    if hsh < float(g.get("lit", e.get("lit", 0.45))):
                        wgt = lit_w[0] + (lit_w[1] - lit_w[0]) * ((hsh * 7.31) % 1.0)
                        light = g.get("color", e.get("warm", "#ffc46b"))
                        if isinstance(light, (list, tuple)):
                            light = light[0]
                        lcol = _scale_hex(light, pane_k)
                        pm = mats.vpbr("ce_pane_lit_%s_%02d" % (lcol.lstrip("#"), int(wgt * 100)), lcol, rough=0.12,
                                       metal=0.1, lamp="-lights:%.2f:%s" % (wgt, lcol))
                    else:
                        pm = mats.vpbr("ce_pane_%s" % gcol.lstrip("#"), gcol, rough=0.08, metal=0.25)
                    geo.poly(pm, [p3(u, z, depth) for (u, z) in h.outline], n)
                # frame: the ring between the outline and its inset, just in front of the pane; glazing bars
                fd = depth - 0.015
                inner = _outline(a, b, c, d, top=h.top, inset=FRAME_W)
                if len(inner) == len(h.outline):
                    m2 = len(h.outline)
                    for i in range(m2):
                        j = (i + 1) % m2
                        geo.quad(fm, p3(*h.outline[i], fd), p3(*h.outline[j], fd), p3(*inner[j], fd), p3(*inner[i], fd), n,
                                 "lod0")
                vf, hf = _bars(kind, b - a, d - c, opt, g)
                bw = float(opt.get("bar_w", BAR_W)) * 0.5
                bar_area = 0.0
                for fu in vf:
                    um = a + (b - a) * fu
                    top_z = _top_at(inner, um) if inner else None      # up to the frame - under an arch to the arch
                    if top_z is None:
                        top_z = d - FRAME_W
                    geo.quad(fm, p3(um - bw, c + FRAME_W, fd - 0.002), p3(um + bw, c + FRAME_W, fd - 0.002),
                             p3(um + bw, top_z, fd - 0.002), p3(um - bw, top_z, fd - 0.002), n, "lod0")
                    bar_area += 2.0 * bw * max(0.0, top_z - c - FRAME_W)
                for fz in hf:
                    zt = c + (d - c) * fz
                    span = _half_width_at(inner, zt)
                    if span is None:
                        continue
                    geo.quad(fm, p3(span[0], zt - bw, fd - 0.003), p3(span[1], zt - bw, fd - 0.003),
                             p3(span[1], zt + bw, fd - 0.003), p3(span[0], zt + bw, fd - 0.003), n, "lod0")
                    bar_area += 2.0 * bw * (span[1] - span[0]) - (4.0 * bw * bw) * len(vf)
                # lod1: one wider frame ring with the area of frame and bars (no pop of the window colour at the switch)
                if far_ring and len(inner) == len(h.outline):
                    ring = _area(h.outline) - _area(inner) + max(0.0, bar_area)
                    inner1 = _outline(a, b, c, d, top=h.top, inset=_far_inset(a, b, c, d, h.top, ring))
                    if len(inner1) == len(h.outline):
                        for i in range(len(h.outline)):
                            j = (i + 1) % len(h.outline)
                            geo.quad(fm, p3(*h.outline[i], fd), p3(*h.outline[j], fd), p3(*inner1[j], fd),
                                     p3(*inner1[i], fd), n, "lod1")
                if e.get("shutters") and g.get("shutters", True) and kind == "win":
                    _shutters(geo, mats, e["shutters"], (a, b, c, d), g, e, p3, n, u_ax)
                    n_shut += 1
                if c >= 0.3 and kind != "shop":
                    _sill(geo, sill, (a, b, c, d), p3, n, u_ax, depth)
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
    stats.update(openings=n_open, doors=n_door, shutters=n_shut, louvres=n_louvre, clocks=n_clock, skipped=n_skip,
                 hidden=n_hidden)


def _reveal(geo, mat, outline, p3, n, u_ax, depth):
    """Reveal of an opening: from the wall plane inwards, normals into the opening."""
    m2 = len(outline)
    cu = float(np.mean([q[0] for q in outline]))
    cz = float(np.mean([q[1] for q in outline]))
    for i in range(m2):
        (ua, za), (ub, zb) = outline[i], outline[(i + 1) % m2]
        # inward normal of the edge in the face plane: perpendicular to the edge, towards the centre
        eu, ez = ub - ua, zb - za
        nu, nz = -ez, eu
        if nu * (cu - (ua + ub) * 0.5) + nz * (cz - (za + zb) * 0.5) < 0:
            nu, nz = -nu, -nz
        nn = u_ax * nu + np.array([0.0, 0.0, nz])
        nn = nn - n * (nn @ n)
        ln = np.linalg.norm(nn)
        if ln < 1e-9:
            continue
        geo.quad(mat, p3(ua, za), p3(ub, zb), p3(ub, zb, depth), p3(ua, za, depth), nn / ln)


def _sill(geo, mat, rect, p3, n, u_ax, depth):
    a, b, c, _d = rect
    s0, s1 = a - 0.05, b + 0.05
    top, bot = c, c - 0.06
    up = np.array([0.0, 0.0, 1.0])
    geo.quad(mat, p3(s0, top, -SILL_M), p3(s1, top, -SILL_M), p3(s1, top, depth * 0.5), p3(s0, top, depth * 0.5), up, "lod0")
    geo.quad(mat, p3(s0, bot, -SILL_M), p3(s1, bot, -SILL_M), p3(s1, top, -SILL_M), p3(s0, top, -SILL_M), n, "lod0")
    geo.quad(mat, p3(s0, bot, -SILL_M), p3(s0, bot, 0.0), p3(s0, top, 0.0), p3(s0, top, -SILL_M), -u_ax, "lod0")
    geo.quad(mat, p3(s1, bot, -SILL_M), p3(s1, bot, 0.0), p3(s1, top, 0.0), p3(s1, top, -SILL_M), u_ax, "lod0")


def _shutters(geo, mats, color, rect, g, e, p3, n, u_ax):
    """Open shutters beside a window where the facade paints them: louvred panels 3 cm thick, 1 cm off the wall."""
    a, b, c, d = rect
    wu = b - a
    fw = g.get("frame_w", e.get("frame_w", 0.07))
    sw = wu * 0.5
    mat = mats.slats("ce_shutter_%s" % color.lstrip("#"), color)
    edge = mats.vpbr("ce_shutter_edge_%s" % color.lstrip("#"), _scale_hex(color, 0.8), rough=0.6)
    up = np.array([0.0, 0.0, 1.0])
    for (u0, u1) in ((a - fw - sw, a - fw), (b + fw, b + fw + sw)):
        f0, f1 = -0.01, -0.04            # depth: negative = in front of the wall
        geo.quad(mat, p3(u0, c, f1), p3(u1, c, f1), p3(u1, d, f1), p3(u0, d, f1), n)
        geo.quad(edge, p3(u0, d, f0), p3(u1, d, f0), p3(u1, d, f1), p3(u0, d, f1), up, "lod0")
        geo.quad(edge, p3(u0, c, f0), p3(u0, c, f1), p3(u0, d, f1), p3(u0, d, f0), -u_ax, "lod0")
        geo.quad(edge, p3(u1, c, f0), p3(u1, c, f1), p3(u1, d, f1), p3(u1, d, f0), u_ax, "lod0")


def _louvre(geo, mats, h, p3, n, u_ax, depth, opt):
    """Belfry opening: a dark back panel and slanted slats (front edge lower) across the opening."""
    back = mats.vpbr("ce_louvre_back", "#101112", rough=0.9)
    slat = mats.vpbr("ce_louvre_slat", opt.get("louvre_color", "#5d5751"), rough=0.8)
    geo.poly(back, [p3(u, z, depth) for (u, z) in h.outline], n)
    a, b, c, d = h.rect
    pitch = 0.2
    z = c + 0.1
    while z < d - 0.08:
        span = _half_width_at(h.outline, z + 0.06)
        if span is not None and span[1] - span[0] > 0.1:
            u0, u1 = span[0] + 0.01, span[1] - 0.01
            f_front, f_back = 0.04, depth - 0.03
            q = [p3(u0, z, f_front), p3(u1, z, f_front), p3(u1, z + 0.13, f_back), p3(u0, z + 0.13, f_back)]
            sn = np.cross(q[1] - q[0], q[3] - q[0])
            sn = sn / max(1e-9, np.linalg.norm(sn))
            if sn @ n < 0:
                sn = -sn
            geo.quad(slat, q[0], q[1], q[2], q[3], sn, "lod0")
        z += pitch


def _door(geo, mats, h, p3, n, u_ax, depth, opt, step_mat, e):
    """Door in its opening: wings in the decal's colour, a frame and a gap - or a ribbed gate when wide; steps in front
    of a door at the foot of the wall."""
    a, b, c, d = h.rect
    dcol = h.src.get("mat") if str(h.src.get("mat", "")).startswith("#") else opt.get("door_color", "#5a3a22")
    dcol = opt.get("door_color", dcol) if opt.get("door_color_force") else dcol
    gate = (b - a) > 2.6
    wing = mats.vpbr("ce_door_%s" % dcol.lstrip("#"), dcol, rough=0.7 if not gate else 0.5, metal=0.0 if not gate else 0.3)
    dark = mats.vpbr("ce_door_dark_%s" % dcol.lstrip("#"), _scale_hex(dcol, 0.55), rough=0.75)
    pts3 = [p3(u, z, depth) for (u, z) in h.outline]
    geo.poly(wing, pts3, n)
    if gate:
        # sectional / roller gate: horizontal ribs 1 cm proud every 0.5 m
        z = c + 0.5
        while z < d - 0.2:
            span = _half_width_at(h.outline, z)
            if span:
                geo.quad(dark, p3(span[0] + 0.05, z - 0.03, depth - 0.012), p3(span[1] - 0.05, z - 0.03, depth - 0.012),
                         p3(span[1] - 0.05, z + 0.03, depth - 0.012), p3(span[0] + 0.05, z + 0.03, depth - 0.012), n, "lod0")
            z += 0.5
    else:
        cu = (a + b) * 0.5
        top = d - 0.25 if not h.src.get("sym", True) else d - 0.3
        span = _half_width_at(h.outline, top)
        top = top if span else (c + d) * 0.5
        geo.quad(dark, p3(cu - 0.025, c + 0.02, depth - 0.006), p3(cu + 0.025, c + 0.02, depth - 0.006),
                 p3(cu + 0.025, top, depth - 0.006), p3(cu - 0.025, top, depth - 0.006), n, "lod0")
        # panels: two darker fields per wing
        for (u0, u1) in ((a + 0.12, cu - 0.1), (cu + 0.1, b - 0.12)):
            if u1 - u0 < 0.15:
                continue
            for (z0, z1) in ((c + 0.2, c + (d - c) * 0.42), (c + (d - c) * 0.5, c + (d - c) * 0.78)):
                s0 = _half_width_at(h.outline, z1)
                if not s0 or s0[0] > u0 + 0.01 or s0[1] < u1 - 0.01:
                    continue
                geo.quad(dark, p3(u0, z0, depth - 0.005), p3(u1, z0, depth - 0.005), p3(u1, z1, depth - 0.005),
                         p3(u0, z1, depth - 0.005), n, "lod0")
    # steps at the foot of a door (not in front of a gate: vehicles drive in)
    if c <= 0.05 and not gate and int(opt.get("steps", 1)) > 0:
        ns = int(opt.get("steps", 1))
        sh = float(opt.get("step_h", 0.15))

        def q(u, z, dd):
            return p3(u, z, -dd)          # dd metres in front of the wall
        for k in range(ns):
            out = 0.3 * (ns - k)
            z1 = sh * (k + 1)
            u0, u1 = a - 0.15 - 0.1 * (ns - 1 - k), b + 0.15 + 0.1 * (ns - 1 - k)
            geo.quad(step_mat, q(u0, z1, out), q(u1, z1, out), q(u1, z1, 0.0), q(u0, z1, 0.0), np.array([0.0, 0.0, 1.0]))
            geo.quad(step_mat, q(u0, z1 - sh, out), q(u1, z1 - sh, out), q(u1, z1, out), q(u0, z1, out), n)
            geo.quad(step_mat, q(u0, z1 - sh, 0.0), q(u0, z1 - sh, out), q(u0, z1, out), q(u0, z1, 0.0), -u_ax)
            geo.quad(step_mat, q(u1, z1 - sh, 0.0), q(u1, z1 - sh, out), q(u1, z1, out), q(u1, z1, 0.0), u_ax)


def _clock(geo, mats, d, rect, p3, n, u_ax, opt):
    """Clock face: a plate 4 cm proud of the wall (lamp channel 14: its colour by day, lit at night), a dark frame,
    twelve hour ticks, an hour hand to 9 and a minute hand to 3 (the sprite's bar across the face)."""
    a, b, c, dd = rect
    col = d.get("mat", "#e9e3cf") if str(d.get("mat", "")).startswith("#") else "#e9e3cf"
    plate = mats.vpbr("ce_clock_face", col, rough=0.5, lamp="-flood:%.2f" % float(opt.get("clock_flood", 0.9)))
    frame = mats.vpbr("ce_clock_frame", opt.get("clock_frame", "#3b3127"), rough=0.5, metal=0.4)
    ink = mats.vpbr("ce_clock_ink", "#1c1b1a", rough=0.6)
    gold = mats.vpbr("ce_clock_gold", opt.get("clock_hands", "#b8973e"), rough=0.35, metal=0.8)
    up = np.array([0.0, 0.0, 1.0])
    f_plate, f_frame = -0.04, -0.07
    geo.quad(plate, p3(a, c, f_plate), p3(b, c, f_plate), p3(b, dd, f_plate), p3(a, dd, f_plate), n)
    fw = 0.09
    for (u0, u1, z0, z1) in ((a - 0.02, b + 0.02, c - 0.02, c + fw - 0.02), (a - 0.02, b + 0.02, dd - fw + 0.02, dd + 0.02),
                             (a - 0.02, a + fw - 0.02, c, dd), (b - fw + 0.02, b + 0.02, c, dd)):
        geo.quad(frame, p3(u0, z0, f_frame), p3(u1, z0, f_frame), p3(u1, z1, f_frame), p3(u0, z1, f_frame), n)
    # sides of the frame (seen from the road at an angle)
    for (u0, u1, z) in ((a - 0.02, b + 0.02, dd + 0.02),):
        geo.quad(frame, p3(u0, z, 0.0), p3(u1, z, 0.0), p3(u1, z, f_frame), p3(u0, z, f_frame), up, "lod0")
    geo.quad(frame, p3(a - 0.02, c - 0.02, 0.0), p3(a - 0.02, dd + 0.02, 0.0), p3(a - 0.02, dd + 0.02, f_frame),
             p3(a - 0.02, c - 0.02, f_frame), -u_ax, "lod0")
    geo.quad(frame, p3(b + 0.02, c - 0.02, 0.0), p3(b + 0.02, dd + 0.02, 0.0), p3(b + 0.02, dd + 0.02, f_frame),
             p3(b + 0.02, c - 0.02, f_frame), u_ax, "lod0")
    cu, cz = (a + b) * 0.5, (c + dd) * 0.5
    r = min(b - a, dd - c) * 0.5 - fw
    f_ink = f_plate - 0.008
    for k in range(12):
        t = 2 * math.pi * k / 12
        ru, rz = math.sin(t), math.cos(t)
        l0, l1 = r * (0.72 if k % 3 else 0.62), r * 0.9
        wt = 0.025 if k % 3 else 0.04
        pu, pz = -rz, ru
        q = [(cu + ru * l0 + pu * wt, cz + rz * l0 + pz * wt), (cu + ru * l1 + pu * wt, cz + rz * l1 + pz * wt),
             (cu + ru * l1 - pu * wt, cz + rz * l1 - pz * wt), (cu + ru * l0 - pu * wt, cz + rz * l0 - pz * wt)]
        geo.quad(ink, *[p3(u, z, f_ink) for (u, z) in q], n, "lod0")
    f_hand = f_plate - 0.016
    for (ang, ln, wd) in ((-90.0, r * 0.52, 0.06), (90.0, r * 0.8, 0.04)):
        t = math.radians(ang)
        ru, rz = math.sin(t), math.cos(t)
        pu, pz = -rz, ru
        q = [(cu - ru * 0.1 + pu * wd, cz - rz * 0.1 + pz * wd), (cu + ru * ln + pu * wd * 0.5, cz + rz * ln + pz * wd * 0.5),
             (cu + ru * ln - pu * wd * 0.5, cz + rz * ln - pz * wd * 0.5), (cu - ru * 0.1 - pu * wd, cz - rz * 0.1 - pz * wd)]
        geo.quad(gold, *[p3(u, z, f_hand) for (u, z) in q], n)
    geo.quad(gold, p3(cu - 0.05, cz - 0.05, f_hand - 0.004), p3(cu + 0.05, cz - 0.05, f_hand - 0.004),
             p3(cu + 0.05, cz + 0.05, f_hand - 0.004), p3(cu - 0.05, cz + 0.05, f_hand - 0.004), n)


# --- extras ---------------------------------------------------------------------------------------------------------------

def _gutters(objs, opt, geo, mats):
    """Half-round gutters under the longest eaves of the roofs (objects named *roof*), downpipes near their ends down
    to the ground - props3d's routine with the walls named in opt["walls"] (prefixes; default: "wall" in the name), so
    that a nave or a tower brings its downpipes to its own wall."""
    gutter = mats.vpbr("ce_gutter", opt.get("color", "#7d8287"), rough=0.4, metal=0.6)
    prefixes = tuple(opt.get("walls", ()))
    walls = [o for o in objs if (any(o.name.startswith(p) for p in prefixes) if prefixes else "wall" in o.name)
             and "roof" not in o.name]
    boxes = []
    for o in walls:
        wp = np.array([tuple(o.matrix_world @ v.co) for v in o.data.vertices])
        boxes.append((wp.min(axis=0), wp.max(axis=0)))
    n_pipes = 0
    for ob in objs:
        if "roof" not in ob.name or any(k in ob.name for k in opt.get("skip", ("shop",))):
            continue
        mw = ob.matrix_world
        pts = np.array([tuple(mw @ v.co) for v in ob.data.vertices])
        if pts.shape[0] < 4:
            continue
        zmin = float(pts[:, 2].min())
        eaves = []
        for e in ob.data.edges:
            a = np.array(tuple(mw @ ob.data.vertices[e.vertices[0]].co))
            b = np.array(tuple(mw @ ob.data.vertices[e.vertices[1]].co))
            if a[2] < zmin + 0.04 and b[2] < zmin + 0.04 and np.linalg.norm(b - a) > 2.0:
                eaves.append((round(float(np.linalg.norm(b - a)), 4), tuple(a), tuple(b)))
        eaves.sort(key=lambda t: (-t[0], t[1], t[2]))
        cen = pts.mean(axis=0)
        used = []
        for (_ln, a, b) in eaves:
            a, b = np.array(a), np.array(b)
            mid = (a + b) / 2
            if any(np.linalg.norm(mid - m) < 0.5 for m in used):
                continue
            if len(used) >= int(opt.get("per_roof", 2)):
                break
            used.append(mid)
            d = b - a
            d /= np.linalg.norm(d)
            out = mid - cen
            out[2] = 0.0
            out -= d * (out @ d)
            out /= max(1e-9, np.linalg.norm(out))
            c0 = a + out * (P.GUTTER_R * 0.9) - np.array([0.0, 0.0, P.GUTTER_R * 0.6])
            c1 = b + out * (P.GUTTER_R * 0.9) - np.array([0.0, 0.0, P.GUTTER_R * 0.6])
            segs = 5
            prev = None
            for k in range(segs + 1):
                ang = math.pi * k / segs
                off = out * math.cos(ang) * P.GUTTER_R - np.array([0.0, 0.0, math.sin(ang) * P.GUTTER_R])
                cur = (c0 + off, c1 + off)
                if prev is not None:
                    am = ang - math.pi / segs / 2
                    nn = out * math.cos(am) - np.array([0.0, 0.0, math.sin(am)])
                    geo.quad(gutter, prev[0], prev[1], cur[1], cur[0], nn, "lod0")
                prev = cur
            # downpipes near both ends: a goose-neck back to the wall under the eave, then down to the ground
            for end in (a + d * 0.3, b - d * 0.3):
                top = end + out * (P.GUTTER_R * 0.9) - np.array([0.0, 0.0, P.GUTTER_R * 1.6])
                box = None
                for (lo, hi) in boxes:
                    if lo[0] - 1.0 <= top[0] <= hi[0] + 1.0 and lo[1] - 1.0 <= top[1] <= hi[1] + 1.0 and hi[2] > top[2] - 1.5:
                        box = (lo, hi)
                        break
                if box is None:
                    continue
                lo, hi = box
                wall_pt = np.array([np.clip(top[0], lo[0], hi[0]), np.clip(top[1], lo[1], hi[1]), top[2]])
                wall_pt += out * 0.07
                knee = np.array([wall_pt[0], wall_pt[1], min(top[2] - 0.35, hi[2] - 0.2)])
                foot = np.array([wall_pt[0], wall_pt[1], max(0.05, float(lo[2]) + 0.05)])
                for i in range(2):
                    pa, pb = [top, knee, foot][i], [top, knee, foot][i + 1]
                    dd = pb - pa
                    ln = np.linalg.norm(dd)
                    if ln < 1e-6:
                        continue
                    dd /= ln
                    up = np.array([0.0, 0.0, 1.0]) if abs(dd[2]) < 0.95 else np.array([1.0, 0.0, 0.0])
                    uu = np.cross(dd, up)
                    uu /= np.linalg.norm(uu)
                    vv = np.cross(dd, uu)
                    for k in range(6):
                        a0, a1 = 2 * math.pi * k / 6, 2 * math.pi * (k + 1) / 6
                        n0 = uu * math.cos(a0) + vv * math.sin(a0)
                        n1 = uu * math.cos(a1) + vv * math.sin(a1)
                        geo.quad(gutter, pa + n0 * 0.045, pa + n1 * 0.045, pb + n1 * 0.045, pb + n0 * 0.045, (n0 + n1) / 2,
                                 "lod0")
                n_pipes += 1
    return n_pipes

def _gear_logo(geo, ink, pt, nrm, us, zs, off, spec):
    """A works sign that reads the same in a mirror: a gear wheel between two bars, symmetric about the vertical axis.
    The props builder mirrors sets tagged mirror_left on the left roadside (D24) - lettering would read backwards
    there. Returns the triangle count."""
    u0, u1 = us
    z0, z1 = zs
    cu, cz = (u0 + u1) * 0.5, (z0 + z1) * 0.5
    r_tip = (z1 - z0) * 0.38
    r_root, r_hole = r_tip * 0.78, r_tip * 0.36
    teeth = int(spec.get("teeth", 10))
    outline = []
    for k in range(teeth):
        tc = math.pi * 0.5 + 2.0 * math.pi * k / teeth      # a tooth at the top: the wheel is mirror-symmetric
        hw = math.pi / teeth
        for (da, r) in ((-hw, r_root), (-hw * 0.45, r_tip), (hw * 0.45, r_tip), (hw * 0.55, r_root)):
            outline.append((tc + da, r))
    n_tri = 0
    for i in range(len(outline)):
        (a0, r0), (a1, r1) = outline[i], outline[(i + 1) % len(outline)]
        p0 = pt(cu + r0 * math.cos(a0), cz + r0 * math.sin(a0), off)
        p1 = pt(cu + r1 * math.cos(a1), cz + r1 * math.sin(a1), off)
        h0 = pt(cu + r_hole * math.cos(a0), cz + r_hole * math.sin(a0), off)
        h1 = pt(cu + r_hole * math.cos(a1), cz + r_hole * math.sin(a1), off)
        geo.quad(ink, h0, p0, p1, h1, nrm)
        n_tri += 2
    bar_h = (z1 - z0) * 0.16
    gap = r_tip * 1.35
    for sgn_u in (-1.0, 1.0):
        a, b = cu + sgn_u * gap, cu + sgn_u * ((u1 - u0) * 0.42)
        lo, hi = min(a, b), max(a, b)
        for dz in (-bar_h * 1.2, bar_h * 1.2):
            geo.quad(ink, pt(lo, cz + dz - bar_h * 0.5, off), pt(hi, cz + dz - bar_h * 0.5, off),
                     pt(hi, cz + dz + bar_h * 0.5, off), pt(lo, cz + dz + bar_h * 0.5, off), nrm)
            n_tri += 2
    return n_tri


def _bag_logo(geo, ink, pt, nrm, us, zs, off, spec):
    """AS4R (art review AS4, M9): the shop's sign emblem - a shopping bag with an arched handle between two bars, read
    the same in a mirror (the shop is tagged mirror_left). Returns the triangle count."""
    u0, u1 = us
    z0, z1 = zs
    cu = (u0 + u1) * 0.5
    h = z1 - z0
    bw_top, bw_bot, bh = h * 0.62, h * 0.7, h * 0.55
    zb0 = z0 + h * 0.12
    zb1 = zb0 + bh
    n_tri = 0
    geo.quad(ink, pt(cu - bw_bot * 0.5, zb0, off), pt(cu + bw_bot * 0.5, zb0, off), pt(cu + bw_top * 0.5, zb1, off),
             pt(cu - bw_top * 0.5, zb1, off), nrm)
    n_tri += 2
    # the handle: a half ring over the bag
    r_out, r_in = bw_top * 0.32, bw_top * 0.32 - h * 0.07
    zc = zb1
    segs = 8
    for k in range(segs):
        a0, a1 = math.pi * k / segs, math.pi * (k + 1) / segs
        q = [pt(cu + r * math.cos(a), zc + r * math.sin(a), off) for (r, a) in ((r_in, a0), (r_out, a0), (r_out, a1),
                                                                                  (r_in, a1))]
        geo.quad(ink, q[0], q[1], q[2], q[3], nrm)
        n_tri += 2
    # two bars to both sides
    bar_h = h * 0.12
    zm = (z0 + z1) * 0.5
    for sgn in (-1.0, 1.0):
        a, b = cu + sgn * bw_bot * 0.9, cu + sgn * (u1 - u0) * 0.42
        lo, hi = min(a, b), max(a, b)
        geo.quad(ink, pt(lo, zm - bar_h * 0.5, off), pt(hi, zm - bar_h * 0.5, off), pt(hi, zm + bar_h * 0.5, off),
                 pt(lo, zm + bar_h * 0.5, off), nrm)
        n_tri += 2
    return n_tri


def _sign(rig, geo, mats, spec):
    """Lettering as geometry on a panel in front of a wall (factory): letters of textgeo flattened onto the panel,
    lamp channel 14 (their colour by day, lit at night)."""
    from cesprites import textgeo as T
    face = spec.get("face", "front")
    u0, u1 = spec["u"]
    z0, z1 = spec["z"]
    wall = float(spec.get("wall", 0.0))           # the wall plane: y (front/back) or x (sides)
    sgn = -1.0 if face in ("front", "left") else 1.0
    panel = mats.vpbr("ce_sign_panel", spec.get("panel") or "#2b3640", rough=0.5, metal=0.3)
    ink = mats.vpbr("ce_sign_ink", spec.get("color", "#eceae2"), rough=0.4,
                    lamp="-flood:%.2f" % float(spec.get("flood", 1.0)))
    out0, out1 = 0.06, 0.12

    def pt(u, z, off):
        if face in ("front", "back"):
            return np.array([u, wall + sgn * off, z])
        return np.array([wall + sgn * off, u, z])
    nrm = np.array([0.0, sgn, 0.0]) if face in ("front", "back") else np.array([sgn, 0.0, 0.0])
    side = np.array([1.0, 0.0, 0.0]) if face in ("front", "back") else np.array([0.0, 1.0, 0.0])
    if spec.get("panel", "") is None:
        out1 = 0.0                  # AS4R: on a sign board of the generator (the shop) - no panel of its own
    else:
        geo.quad(panel, pt(u0, z0, out1), pt(u1, z0, out1), pt(u1, z1, out1), pt(u0, z1, out1), nrm)
        geo.quad(panel, pt(u0, z1, out0), pt(u1, z1, out0), pt(u1, z1, out1), pt(u0, z1, out1), np.array([0.0, 0.0, 1.0]))
        geo.quad(panel, pt(u0, z0, out0), pt(u1, z0, out0), pt(u1, z0, out1), pt(u0, z0, out1),
                 np.array([0.0, 0.0, -1.0]), "lod0")
        geo.quad(panel, pt(u0, z0, out0), pt(u0, z1, out0), pt(u0, z1, out1), pt(u0, z0, out1), -side, "lod0")
        geo.quad(panel, pt(u1, z0, out0), pt(u1, z1, out0), pt(u1, z1, out1), pt(u1, z0, out1), side, "lod0")
    if spec.get("logo") == "gear":
        return _gear_logo(geo, ink, pt, nrm, (u0, u1), (z0, z1), out1 + 0.012, spec)
    if spec.get("logo") == "bag":
        return _bag_logo(geo, ink, pt, nrm, (u0, u1), (z0, z1), out1 + 0.012, spec)
    # the text: a mesh in the XY plane (reading +X, up +Y), centred; scaled to the letter height
    txt = T.text_mesh(rig, spec["text"], float(spec.get("h", 0.8)), ink, bold=0.04, extrude=0.0, name="ce_sign_txt")
    T.fit(txt, (u1 - u0) * 0.9)
    me = txt.data
    sx = float(txt.scale[0])
    cu, cz = (u0 + u1) * 0.5, (z0 + z1) * 0.5
    me.calc_loop_triangles()
    n_tri = 0
    for lt in me.loop_triangles:
        q = []
        for vi in lt.vertices:
            co = me.vertices[vi].co
            # reading direction: +u on the front face (seen from -y), -u on the back, +u on the left side seen from
            # -x reads along -y ...
            rd = 1.0 if face in ("front", "right") else -1.0
            q.append(pt(cu + rd * co.x * sx, cz + co.y * sx, out1 + 0.012))
        geo.tri(ink, q[0], q[1], q[2], nrm)
        n_tri += 1
    import bpy
    bpy.data.objects.remove(txt)
    return n_tri


def _hash01(text):
    """Stable, well spread number 0..1 of a text (crc32 of similar texts runs in stripes: lit panes stood in columns)."""
    import hashlib
    return int(hashlib.sha1(text.encode()).hexdigest()[:8], 16) / 2.0 ** 32


def _mix_hex(a, b, t):
    ca, cb = _hex(a), _hex(b)
    return "#%02x%02x%02x" % tuple(int(round(x + (y - x) * t)) for x, y in zip(ca, cb))


def _curtain(rig, objs, geo, mats, spec, stats, patches=None):
    """Glass curtain wall of a tower box (building_tall): the faces of the box between 'base' and 'top' are replaced by
    spandrel bands (baked: the tower's own material in the atlas), recessed panes per bay and floor and mullion fins
    (vpbr). AS4R (art review AS4, M3/M8): the panes are atlas patches (Patches) - the sprite's glass gradient in
    `bands` steps (glass .. glass_top), the same by day for lit and unlit panes; the lit ones (share `lit`, drawn per
    face, floor and bay with a well spread hash - no columns) carry the light (x PANE_LIGHT_K) in the emission atlas
    at three strengths. lobby = dict(object, k (factor on its light), posts (m), w): the lit lobby dimmed, with
    mullions in front of it."""
    import bmesh
    name = spec["object"]
    ob = [o for o in objs if o.name == name][0]
    floor, band = float(spec.get("floor", 3.5)), float(spec.get("band", 0.9))
    pitch, mull = float(spec.get("mull", 1.6)), float(spec.get("mull_w", 0.12))
    z_base, recess = float(spec.get("base", 4.0)), float(spec.get("recess", 0.18))
    fin = float(spec.get("fin", 0.22))
    lit = float(spec.get("lit", 0.34))
    light = spec.get("light", "#ffe4b8")
    lcol = _scale_hex(light, float(spec.get("pane_k", PANE_K)))
    glass = spec.get("glass", "#3a5468")
    glass_top = spec.get("glass_top", glass)
    n_bands = max(1, int(spec.get("bands", 1)))
    strength = float(spec.get("strength", 0.75)) * float(spec.get("light_k", PANE_LIGHT_K))
    fin_mat = mats.vpbr("ce_fin", spec.get("fin_color", "#b9bec3"), rough=0.4, metal=0.6)
    pane_mats = {}
    mw = np.array(ob.matrix_world, dtype=np.float64)
    pts = np.array([tuple(ob.matrix_world @ v.co) for v in ob.data.vertices])
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    H = float(hi[2])
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    drop = [f for f in bm.faces if abs(f.normal[2]) < 0.5]
    keep_mat = ob.material_slots[0].material
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    n_pane = n_lit = 0
    # (name, outward normal, u axis (horizontal, to the right seen from outside), plane offset along the normal, u range)
    faces = (("front", np.array([0.0, -1.0, 0.0]), np.array([1.0, 0.0, 0.0]), -lo[1], lo[0], hi[0]),
             ("back", np.array([0.0, 1.0, 0.0]), np.array([-1.0, 0.0, 0.0]), hi[1], -hi[0], -lo[0]),
             ("left", np.array([-1.0, 0.0, 0.0]), np.array([0.0, -1.0, 0.0]), -lo[0], -hi[1], -lo[1]),
             ("right", np.array([1.0, 0.0, 0.0]), np.array([0.0, 1.0, 0.0]), hi[0], lo[1], hi[1]))
    post = float(spec.get("post", 0.35))
    for (fname, nrm, uax, pd, ua, ub) in faces:
        def p(u, z, out=0.0, _n=nrm, _u=uax, _pd=pd):
            return _u * u + np.array([0.0, 0.0, z]) + _n * (_pd + out)
        # corner posts (aluminium) at both ends of every face: close the corners where two glass strips meet
        for (c0, c1) in ((ua, ua + post), (ub - post, ub)):
            q = [p(c0, 0.0, 0.02), p(c1, 0.0, 0.02), p(c1, H, 0.02), p(c0, H, 0.02)]
            geo.quad(fin_mat, q[0], q[1], q[2], q[3], nrm)
        # ground floor (lobby height) stays a solid band, then floors of `floor` m: a band, then glass
        geo.quad(keep_mat, p(ua, 0.0), p(ub, 0.0), p(ub, z_base), p(ua, z_base), nrm)
        z = z_base
        k = 0
        while z < H - 0.01:
            zb = min(z + band, H)
            geo.quad(keep_mat, p(ua, z), p(ub, z), p(ub, zb), p(ua, zb), nrm)
            zg = min(z + floor, H)
            if zg - zb > 0.3:
                # the reveal of the glass strip: top and bottom edges of the bands
                geo.quad(keep_mat, p(ua, zb, -recess), p(ub, zb, -recess), p(ub, zb), p(ua, zb), np.array([0.0, 0.0, 1.0]))
                geo.quad(keep_mat, p(ua, zg, -recess), p(ub, zg, -recess), p(ub, zg), p(ua, zg), np.array([0.0, 0.0, -1.0]))
                # panes per bay
                nb_ = max(1, int(round((ub - ua) / pitch)))
                bw = (ub - ua) / nb_
                for i in range(nb_):
                    u0, u1 = ua + i * bw, ua + (i + 1) * bw
                    q4 = (p(u0, zb, -recess), p(u1, zb, -recess), p(u1, zg, -recess), p(u0, zg, -recess))
                    if patches is None:
                        # AS4's panes (vpbr; the lit ones lamps of channel 12)
                        hsh = zlib.crc32(("%s|%d|%d" % (fname, k, i)).encode()) / 2.0 ** 32
                        if hsh < lit:
                            wgt = 0.5 + 0.45 * ((hsh * 7.31) % 1.0)
                            key = round(wgt, 1)
                            if key not in pane_mats:
                                pane_mats[key] = mats.vpbr("ce_cw_lit_%02d" % int(key * 100), lcol, rough=0.1,
                                                           metal=0.2, lamp="-lights:%.2f:%s" % (key, lcol))
                            pm = pane_mats[key]
                            n_lit += 1
                        else:
                            pm = mats.vpbr("ce_cw_glass", glass, rough=0.06, metal=0.6)
                        geo.quad(pm, *q4, nrm)
                    else:
                        bi = min(n_bands - 1, int(n_bands * ((zb + zg) * 0.5) / max(1e-6, H)))
                        gc = _mix_hex(glass, glass_top, bi / max(1, n_bands - 1))
                        hsh = _hash01("%s|%d|%d" % (fname, k, i))
                        if hsh < lit:
                            lv = int(3.0 * _hash01("lvl|%s|%d|%d" % (fname, k, i)))
                            pm = mats.pane("ce_cw_lit_%d_%d" % (bi, lv), gc, light=light,
                                           strength=strength * (0.75, 1.05, 1.4)[lv])
                            n_lit += 1
                        else:
                            pm = mats.pane("ce_cw_glass_%d" % bi, gc)
                        patches.geo.quad(pm, *q4, nrm)
                    n_pane += 1
            z = zg
            k += 1
        # mullion fins over the whole glass height, at the bay borders (not at the corners)
        nb_ = max(1, int(round((ub - ua) / pitch)))
        bw = (ub - ua) / nb_
        for i in range(1, nb_):
            u = ua + i * bw
            q = [p(u - mull * 0.5, z_base, fin), p(u + mull * 0.5, z_base, fin), p(u + mull * 0.5, H, fin),
                 p(u - mull * 0.5, H, fin)]
            geo.quad(fin_mat, q[0], q[1], q[2], q[3], nrm)
            # the sides of the fins stay in lod1: seen at a grazing angle they hide most of the glass of a face (without
            # them the side of the tower turned from grey to blue at the switch - 18 % of the pixels changed at 60 m)
            geo.quad(fin_mat, p(u - mull * 0.5, z_base, -recess), p(u - mull * 0.5, z_base, fin), p(u - mull * 0.5, H, fin),
                     p(u - mull * 0.5, H, -recess), -uax)
            geo.quad(fin_mat, p(u + mull * 0.5, z_base, -recess), p(u + mull * 0.5, z_base, fin), p(u + mull * 0.5, H, fin),
                     p(u + mull * 0.5, H, -recess), uax)
    lob = spec.get("lobby")
    n_post = 0
    if lob:
        # AS4R (M8): mullions in front of the lit lobby (its light is dimmed by the catalog's light_scale)
        lo_ob = [o for o in objs if o.name.startswith(lob["object"])]
        if lo_ob:
            lp = np.array([tuple(lo_ob[0].matrix_world @ v.co) for v in lo_ob[0].data.vertices])
            l0, l1 = lp.min(axis=0), lp.max(axis=0)
            step, pw, dep = float(lob.get("posts", 1.6)), float(lob.get("w", 0.12)), float(lob.get("depth", 0.08))
            nps = max(1, int(round((l1[0] - l0[0]) / step)))
            y0 = float(l0[1])
            for kp in range(nps + 1):
                x = float(l0[0]) + (float(l1[0]) - float(l0[0])) * kp / nps
                xa, xb = max(float(l0[0]), x - pw * 0.5), min(float(l1[0]), x + pw * 0.5)
                za, zb_ = float(l0[2]), float(l1[2])
                q = [np.array([xa, y0 - dep, za]), np.array([xb, y0 - dep, za]), np.array([xb, y0 - dep, zb_]),
                     np.array([xa, y0 - dep, zb_])]
                geo.quad(fin_mat, q[0], q[1], q[2], q[3], np.array([0.0, -1.0, 0.0]))
                geo.quad(fin_mat, np.array([xa, y0, za]), q[0], q[3], np.array([xa, y0, zb_]), np.array([-1.0, 0.0, 0.0]),
                         "lod0")
                geo.quad(fin_mat, q[1], np.array([xb, y0, za]), np.array([xb, y0, zb_]), q[2], np.array([1.0, 0.0, 0.0]),
                         "lod0")
                n_post += 1
            # a transom bar across the lobby at door height
            zt = float(l0[2]) + 2.4
            geo.quad(fin_mat, np.array([float(l0[0]), y0 - dep, zt - 0.06]), np.array([float(l1[0]), y0 - dep, zt - 0.06]),
                     np.array([float(l1[0]), y0 - dep, zt + 0.06]), np.array([float(l0[0]), y0 - dep, zt + 0.06]),
                     np.array([0.0, -1.0, 0.0]))
    stats.update(panes=n_pane, panes_lit=n_lit, lobby_posts=n_post)


def _skylight(objs, spec):
    """AS4R (art review AS4, M4): the glazing of the factory's sawtooth roof lit at night as one pure white field (2.8
    x 22 m per shed, seen over the slope of the next shed as a white triangle). The objects named in spec["objects"]
    get a glazing material instead: the sprite's glass colour with mullions every `pitch` m along y and a transom,
    the light (sprite colour x strength x k) only in the panes and fading towards the top (`fade`: share lost at the
    top). spec = dict(objects, glass, frame, light, strength, k, pitch, bar, fade, z=(z0, z1))."""
    from cesprites import materials as M
    m, nb = M.new_material("ce_skylight")
    _x, y, z = nb.coords()
    pitch, bar = float(spec.get("pitch", 1.4)), float(spec.get("bar", 0.1))
    z0, z1 = spec.get("z", (9.1, 11.9))
    zm = (float(z0) + float(z1)) * 0.5
    mull = nb.lt(nb.math("FLOORED_MODULO", y, pitch), bar)
    tran = nb.lt(nb.absf(nb.sub(z, zm)), bar * 0.5)
    edge = nb.OR(nb.lt(z, float(z0) + bar), nb.gt(z, float(z1) - bar))
    frame = nb.OR(mull, tran, edge)
    col = nb.mix(frame, M.srgb(spec.get("glass", "#5d7486")), M.srgb(spec.get("frame", "#4a4f55")))
    out = M.principled(nb, col, rough=nb.mixf(frame, 0.1, 0.6), metal=nb.mixf(frame, 0.3, 0.5), spec=0.5)
    t = nb.math("DIVIDE", nb.sub(z, float(z0)), float(z1) - float(z0))
    fade = nb.sub(1.0, nb.mul(nb.math("MINIMUM", nb.math("MAXIMUM", t, 0.0), 1.0), float(spec.get("fade", 0.5))))
    lit = nb.mul(nb.NOT(frame), fade)
    s = float(spec.get("strength", 0.9)) * float(spec.get("k", 0.45))
    em = nb.color_scale(M.emit_col(spec.get("light", "#cfe0ff"), s), lit)
    mat = M.finish(m, nb, out, {"lights": em})      # role "proc": baked into the atlas
    n = 0
    for ob in objs:
        if any(ob.name.startswith(p) for p in spec["objects"]):
            for slot in ob.material_slots:
                slot.material = mat
            n += 1
    return n


def _scale_lights(objs, table):
    """AS4R: the light of the materials of some objects times a factor (table: {object name prefix: k}) - a copy of
    each material with its emission scaled (the tower's lobby: an over-exposed white field at night, art review M8)."""
    copies = {}
    n = 0
    for ob in objs:
        k = next((float(v) for pre, v in sorted(table.items()) if ob.name.startswith(pre)), None)
        if k is None:
            continue
        for slot in ob.material_slots:
            mat = slot.material
            if mat is None or mat.get("ce_filler"):
                continue
            key = (mat.name, k)
            if key not in copies:
                copies[key] = _filler_mat(mat, {}, light_k=k)
                copies[key].name = mat.name + "_lscale"       # keeps the name prefix (baked_lamps routes by it)
                for prop in ("ce_filler", "ce_pane", "ce_sink"):
                    if prop in copies[key]:
                        del copies[key][prop]
            slot.material = copies[key]
            n += 1
    return n


def _octagon_windows(rig, objs, geo, mats, spec, opt, stats, patches=None):
    """Openings in the middle of the faces of a lathed polygonal tower (the windmill: its painted grid straddles a
    corner). spec: objects (names), faces (normal angles in degrees about the tower axis), rows (window centre heights),
    win (w, h), lit, light, frame, glass. AS4R: with patches the panes are atlas patches - glass by day for all,
    the lit ones with the sprite's window light (strength x PANE_LIGHT_K) in the emission atlas."""
    import bmesh
    names = spec["objects"]
    w_win, h_win = spec["win"]
    reveal = mats.baked("ce_reveal", opt.get("reveal_color", "#d9d2c6"))
    fcol = spec.get("frame", "#e9e6de")
    fm = mats.vpbr("ce_frame_%s" % fcol.lstrip("#"), fcol, rough=0.55)
    lcol = _scale_hex(spec.get("light", "#ffc46b"), PANE_K)
    sill = mats.vpbr("ce_sill", opt.get("sill_color", "#bdb8ae"), rough=0.8)
    count = 0
    for ob in objs:
        if not any(ob.name.startswith(nm) for nm in names):
            continue
        mw = np.array(ob.matrix_world, dtype=np.float64)
        geo.xform = mw
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        new_faces, drop = [], []
        for f in list(bm.faces):
            nv = np.array(f.normal, dtype=np.float64)
            if abs(nv[2]) > 0.3:
                continue
            ang = math.degrees(math.atan2(nv[1], nv[0])) % 360.0
            if not any(abs(((ang - a) + 180.0) % 360.0 - 180.0) < 6.0 for a in spec["faces"]):
                continue
            vs = [np.array(v.co, dtype=np.float64) for v in f.verts]
            cen = np.mean(vs, axis=0)
            n = nv / np.linalg.norm(nv)
            u_ax = np.cross(np.array([0.0, 0.0, 1.0]), n)
            u_ax /= np.linalg.norm(u_ax)
            w = float(cen @ n)
            uc = float(cen @ u_ax)
            poly = [(float(v @ u_ax), float(v[2])) for v in vs]
            holes = []
            for zc in spec["rows"]:
                rect = (uc - w_win / 2, uc + w_win / 2, zc - h_win / 2, zc + h_win / 2)
                corners = [(rect[0] - 0.05, rect[2] - 0.05), (rect[1] + 0.05, rect[2] - 0.05),
                           (rect[1] + 0.05, rect[3] + 0.05), (rect[0] - 0.05, rect[3] + 0.05)]
                if all(P._inside_poly(q, poly) for q in corners):
                    holes.append(rect)
            if not holes:
                continue

            def p3(u, z, depth=0.0, _u=u_ax, _n=n, _w=w):
                base = _u * u + np.array([0.0, 0.0, z])
                return base - _n * (base @ _n) + _n * (_w - depth)
            tris = P._cdt_with_holes(poly, [_outline(*r) for r in holes])
            if not tris:
                continue
            for (a2, b2, c2) in tris:
                new_faces.append((p3(*a2), p3(*b2), p3(*c2), n, f.material_index))
            drop.append(f)
            for rect in holes:
                a, b, c, d = rect
                outline = _outline(*rect)
                depth = float(spec.get("reveal_m", 0.25))
                _reveal(geo, reveal, outline, p3, n, u_ax, depth)
                hsh = zlib.crc32(("%s|%.2f|%.2f" % (ob.name, ang, c)).encode()) / 2.0 ** 32
                gl = spec.get("glass", "#26313b")
                if patches is not None:
                    if hsh < float(spec.get("lit", 0.5)):
                        pm = mats.pane("ce_oct_lit", gl, light=spec.get("light", "#ffc46b"),
                                       strength=float(spec.get("strength", 1.5)) * PANE_LIGHT_K)
                    else:
                        pm = mats.pane("ce_oct_glass", gl)
                    patches.geo.poly(pm, [p3(u, z, depth) for (u, z) in outline], n)
                else:
                    if hsh < float(spec.get("lit", 0.5)):
                        pm = mats.vpbr("ce_pane_lit_oct", lcol, rough=0.12, metal=0.1, lamp="-lights:0.80:%s" % lcol)
                    else:
                        pm = mats.vpbr("ce_pane_%s" % gl.lstrip("#"), gl, rough=0.08, metal=0.25)
                    geo.poly(pm, [p3(u, z, depth) for (u, z) in outline], n)
                fd = depth - 0.015
                inner = _outline(*rect, inset=FRAME_W)
                for i in range(4):
                    j = (i + 1) % 4
                    geo.quad(fm, p3(*outline[i], fd), p3(*outline[j], fd), p3(*inner[j], fd), p3(*inner[i], fd), n, "lod0")
                um = (a + b) * 0.5
                geo.quad(fm, p3(um - 0.022, c + FRAME_W, fd - 0.002), p3(um + 0.022, c + FRAME_W, fd - 0.002),
                         p3(um + 0.022, d - FRAME_W, fd - 0.002), p3(um - 0.022, d - FRAME_W, fd - 0.002), n, "lod0")
                zt = c + (d - c) * 0.6
                geo.quad(fm, p3(a + FRAME_W, zt - 0.022, fd - 0.003), p3(b - FRAME_W, zt - 0.022, fd - 0.003),
                         p3(b - FRAME_W, zt + 0.022, fd - 0.003), p3(a + FRAME_W, zt + 0.022, fd - 0.003), n, "lod0")
                _sill(geo, sill, rect, p3, n, u_ax, depth)
                count += 1
        geo.xform = None
        if drop:
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
            ob.data.update()
        bm.free()
    stats["octagon_windows"] = count


# --- texel weights --------------------------------------------------------------------------------------------------------

def weight_fn(view, w):
    """Texel density by visibility (contract 4.6.5) with tunable factors: w = dict(roof, away, under, front)."""
    roof = float(w.get("roof", 1.0))
    away = float(w.get("away", 0.3))
    under = float(w.get("under", 0.05))
    front = float(w.get("front", 1.0))

    def fn(n, _ob):
        if n[2] < -0.5:
            return under
        if n[2] > 0.3:
            return roof
        if view == "allround":
            return front
        if n[0] < -0.5 or n[1] < -0.5:
            return front
        return away
    return fn


# --- the builder --------------------------------------------------------------------------------------------------------

def _split_planes(objs, spec):
    """Cuts objects (name prefixes) by planes across a world axis and splits the cut edges: the box unwrap then makes
    one chart per piece. A 182 m hull side in one chart limits the atlas to 1024 px / 182 m = 5.6 px/m.
    spec = dict(objects=(prefixes), axis=0|1|2 (world), at=(positions))."""
    import bmesh
    from mathutils import Vector
    axis = int(spec.get("axis", 0))
    n = 0
    for ob in objs:
        if not any(ob.name.startswith(p) for p in spec["objects"]):
            continue
        mw = np.array(ob.matrix_world, dtype=np.float64)
        inv = np.linalg.inv(mw)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        for c in spec["at"]:
            wp = np.zeros(3)
            wp[axis] = float(c)
            wn = np.zeros(3)
            wn[axis] = 1.0
            co = inv[:3, :3] @ wp + inv[:3, 3]
            no = mw[:3, :3].T @ wn
            no /= np.linalg.norm(no)
            res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-4,
                                         plane_co=Vector(tuple(co)), plane_no=Vector(tuple(no)))
            cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
            if cut:
                bmesh.ops.split_edges(bm, edges=cut)
                n += len(cut)
        bm.to_mesh(ob.data)
        bm.free()
        ob.data.update()
    return n


def _decimate(objs, ratios):
    """Collapse decimation of organic parts that the budget cannot afford (the potted plants of the houseboat):
    {name prefix: ratio}. Never on lamps or parts with decals."""
    import bpy
    n = 0
    for ob in objs:
        r = next((float(v) for k, v in sorted(ratios.items()) if ob.name.startswith(k)), None)
        if r is None:
            continue
        m = ob.modifiers.new("ce_decimate", "DECIMATE")
        m.decimate_type = "COLLAPSE"
        m.ratio = r
        n += 1
    bpy.context.view_layer.update()
    core.realize(objs)
    return n


def _railings(objs, spec, geo, mats):
    """Railings of cut-out panels (props_cities.Rails: bars of 3 cm drawn by a mask) rebuilt as geometry: the panels'
    boxes give the run of each railing; posts every `post` m, a top rail, a middle and a bottom rail (vpbr). Bars of 3 cm
    are a sixth of a texel in the atlas and break up in the bake, and at a distance they would only shimmer.
    spec = dict(objects=(prefixes), post (m), color, w (post / rail width)). The panel objects leave the model."""
    from .bridges3d import boxes
    col = spec.get("color", "#1f2321")
    mat = mats.vpbr("ce_rail_%s" % col.lstrip("#"), col, rough=0.5, metal=0.4)
    w = float(spec.get("w", 0.05))
    step = float(spec.get("post", 1.0))
    keep, n = [], 0
    for ob in objs:
        if not any(ob.name.startswith(p) for p in spec["objects"]):
            keep.append(ob)
            continue
        for bx in boxes(ob):
            ax = bx["axis"]
            # the panel: long axis horizontal, height along z
            hdir = bx["ew"] if abs(bx["ew"][2]) > abs(bx["eh"][2]) else bx["eh"]
            hgt = bx["w"] if hdir is bx["ew"] else bx["h"]
            base = bx["c"] - np.array([0.0, 0.0, 1.0]) * hgt * 0.5
            a = base - ax * bx["length"] * 0.5
            b = base + ax * bx["length"] * 0.5
            side = np.cross(ax, np.array([0.0, 0.0, 1.0]))
            side /= max(1e-9, np.linalg.norm(side))
            up = np.array([0.0, 0.0, 1.0])
            k = max(1, int(round(bx["length"] / step)))
            for i in range(k + 1):
                p = a + (b - a) * (i / k)
                _box_beam(geo, mat, p, p + up * hgt, w, w, side, np.cross(up, side), "both" if i in (0, k) else "lod0")
            for (zf, ww, lvl) in ((hgt, w * 1.2, "both"), (hgt * 0.5, w * 0.6, "lod0"), (0.08, w * 0.6, "lod0")):
                _box_beam(geo, mat, a + up * zf, b + up * zf, ww, ww, side, up, lvl)
            n += 1
        ob.hide_render = True
    objs[:] = keep
    return n


def _box_beam(geo, mat, a, b, w, h, ew, eh, level):
    """Four sides of a beam from a to b (cross-section w along ew, h along eh) into geo."""
    a, b = np.asarray(a, dtype=np.float64), np.asarray(b, dtype=np.float64)
    hw, hh = np.asarray(ew) * w * 0.5, np.asarray(eh) * h * 0.5
    corners = [hw + hh, -hw + hh, -hw - hh, hw - hh]
    for i in range(4):
        p, q = corners[i], corners[(i + 1) % 4]
        nn = p + q
        geo.quad(mat, a + p, b + p, b + q, a + q, nn / max(1e-9, np.linalg.norm(nn)), level)


def _floodlight(objs, spec):
    """A floodlit tower (the village church): the walls of the named objects get a copy of their material whose light
    layer adds the wall's own colour x tint x strength, fading with height (floodlights at its foot, (1 - t)^1.5 with t
    = (z - z0) / (z1 - z0), at least `top` of it at the top). It lands in the emission atlas: nothing by day, the
    soft light of the tower at night. Applied after the openings are cut (the window log knows the original names).
    spec = dict(objects=(prefixes), strength, z=(z0, z1), tint, top)."""
    from cesprites import materials as M
    copies = {}
    n = 0
    for ob in objs:
        if not any(ob.name.startswith(p) for p in spec["objects"]):
            continue
        for slot in ob.material_slots:
            mat = slot.material
            if mat is None or mat.get("ce_filler"):
                continue
            if mat.name not in copies:
                m = mat.copy()
                m.name = "ce_flood_" + mat.name
                nt = m.node_tree
                em = [nd for nd in nt.nodes if nd.bl_idname == "ShaderNodeEmission"]
                bsdf = [nd for nd in nt.nodes if nd.bl_idname == "ShaderNodeBsdfPrincipled"]
                grp = [nd for nd in nt.nodes if nd.bl_idname == "ShaderNodeGroup" and "lights" in nd.outputs]
                if not em or not bsdf or not grp:
                    copies[mat.name] = None
                    continue
                em, bsdf, grp = em[0], bsdf[0], grp[0]
                tc = nt.nodes.new("ShaderNodeTexCoord")
                sep = nt.nodes.new("ShaderNodeSeparateXYZ")
                nt.links.new(tc.outputs["Object"], sep.inputs[0])
                z0, z1 = spec.get("z", (0.0, 30.0))
                t = nt.nodes.new("ShaderNodeMapRange")
                t.clamp = True
                nt.links.new(sep.outputs[2], t.inputs["Value"])
                t.inputs["From Min"].default_value = float(z0)
                t.inputs["From Max"].default_value = float(z1)
                t.inputs["To Min"].default_value = 1.0
                t.inputs["To Max"].default_value = 0.0
                pw = nt.nodes.new("ShaderNodeMath")
                pw.operation = "POWER"
                nt.links.new(t.outputs[0], pw.inputs[0])
                pw.inputs[1].default_value = 1.5
                top = nt.nodes.new("ShaderNodeMapRange")
                nt.links.new(pw.outputs[0], top.inputs["Value"])
                top.inputs["To Min"].default_value = float(spec.get("top", 0.25))
                top.inputs["To Max"].default_value = 1.0
                k = nt.nodes.new("ShaderNodeMath")
                k.operation = "MULTIPLY"
                nt.links.new(top.outputs[0], k.inputs[0])
                nt.links.new(grp.outputs["lights"], k.inputs[1])
                tint = M.srgb(spec.get("tint", "#ffe2b0"))
                s = float(spec.get("strength", 0.1))
                base = nt.nodes.new("ShaderNodeMix")
                base.data_type = "RGBA"
                base.blend_type = "MULTIPLY"
                base.inputs["Factor"].default_value = 1.0
                a_col, b_col = M._sock(base.inputs, "A_Color"), M._sock(base.inputs, "B_Color")
                src = bsdf.inputs["Base Color"]
                if src.is_linked:
                    nt.links.new(src.links[0].from_socket, a_col)
                else:
                    a_col.default_value = tuple(src.default_value)
                b_col.default_value = (tint[0] * s, tint[1] * s, tint[2] * s, 1.0)
                scaled = nt.nodes.new("ShaderNodeVectorMath")
                scaled.operation = "SCALE"
                nt.links.new(M._sock(base.outputs, "Result_Color"), scaled.inputs[0])
                nt.links.new(k.outputs[0], scaled.inputs["Scale"])
                add = nt.nodes.new("ShaderNodeVectorMath")
                add.operation = "ADD"
                ein = em.inputs["Color"]
                if ein.is_linked:
                    nt.links.new(ein.links[0].from_socket, add.inputs[0])
                else:
                    add.inputs[0].default_value = tuple(ein.default_value)[:3]
                nt.links.new(scaled.outputs[0], add.inputs[1])
                nt.links.new(add.outputs[0], ein)
                copies[mat.name] = m
            if copies[mat.name] is not None:
                slot.material = copies[mat.name]
                n += 1
    return n


def _rotate(objs, deg):
    """Turns every object of the model about the vertical axis through the origin (the ferry)."""
    import bpy
    from mathutils import Matrix
    rot = Matrix.Rotation(math.radians(deg), 4, "Z")
    for ob in objs:
        if ob.parent is not None and ob.parent in objs:
            continue
        ob.matrix_world = rot @ ob.matrix_world
    bpy.context.view_layer.update()


def _log_city_walls(log):
    """props_cities.wallmat (the walls of the city sets, the houseboat) writes no window log - and the file is not
    ours to change. While a model builds, the function is wrapped: its grids go to the log as explicit rectangles
    (props_cities.centres), in the cutter's format. Returns the function that restores the original."""
    import inspect
    from cesprites import props_cities as C
    orig = C.wallmat
    sig = inspect.signature(orig)

    def logged(*args, **kw):
        ba = sig.bind(*args, **kw)
        ba.apply_defaults()
        a = ba.arguments
        grids = []
        for g in a["grids"]:
            wu, wz = g["win"]
            kind = g.get("kind", "win")
            rects = [(u - wu / 2, u + wu / 2, zc - wz / 2, zc + wz / 2) for (u, zc, _i, _j) in C.centres(g)]
            lit = g.get("lit", a["lit"] if kind == "win" else (0.95 if kind == "shop" else 0.0))
            cols = g.get("color")
            light = (cols if isinstance(cols, str) else cols[0]) if cols else ("#ffcf8a" if kind != "win" else "#ffc46b")
            grids.append(dict(g, rects=rects, lit=lit, color=light, arch=g.get("top") == "round",
                              top=None if g.get("top") == "round" else g.get("top")))
        log.append(dict(material=a["name"], grids=grids, decals=[dict(d) for d in (a["decals"] or [])],
                        frame=a["frame"], glass=a["glass"], lit=a["lit"], warm="#ffc46b", frame_w=a["frame_w"],
                        shutters=None))
        return orig(*args, **kw)
    C.wallmat = logged

    def restore():
        C.wallmat = orig
    return restore


def build_house(model_id, spec3d):
    """Buildings with depth (see the module text)."""
    from cesprites import props_buildings as B
    t0 = time.time()
    B.WINDOW_LOG = []
    restore = _log_city_walls(B.WINDOW_LOG) if spec3d.get("city_walls") else None
    try:
        rig, info, sspec = P._build_source(spec3d)
        log = list(B.WINDOW_LOG)
    finally:
        B.WINDOW_LOG = None
        if restore is not None:
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
    stats = {}
    if spec3d.get("decimate"):
        stats["decimated"] = _decimate(objs, spec3d["decimate"])
    if spec3d.get("rotate_deg"):
        _rotate(objs, float(spec3d["rotate_deg"]))
        core.realize(objs)
    if spec3d.get("split"):
        stats["split_edges"] = _split_planes(objs, spec3d["split"])
    mats = Mats()
    geo = Geo()
    patches = Patches()
    if spec3d.get("railings"):
        stats["railings"] = _railings(objs, spec3d["railings"], geo, mats)
    opt = dict(spec3d.get("openings") or {})
    if spec3d.get("curtain"):
        _curtain(rig, objs, geo, mats, spec3d["curtain"], stats, patches)
    if spec3d.get("openings", True) is not False:
        cut_openings(rig, objs, log, opt, geo, mats, stats)
    if spec3d.get("octagon"):
        _octagon_windows(rig, objs, geo, mats, spec3d["octagon"], opt, stats, patches)
    if spec3d.get("skylight"):
        stats["skylight"] = _skylight(objs, spec3d["skylight"])
    if spec3d.get("light_scale"):
        stats["light_scaled"] = _scale_lights(objs, spec3d["light_scale"])
    if spec3d.get("levels"):
        for ob in objs:
            for pre, lvl in sorted(spec3d["levels"].items()):
                if ob.name.startswith(pre):
                    ob["ce_lvl"] = lvl
    if spec3d.get("flood"):
        stats["floodlit"] = _floodlight(objs, spec3d["flood"])
    if spec3d.get("sign"):
        stats["sign_tris"] = _sign(rig, geo, mats, spec3d["sign"])
    if spec3d.get("gutters", True) is not False:
        stats["pipes"] = _gutters(objs, dict(spec3d.get("gutters") or {}), geo, mats)
    if spec3d.get("caps", True):
        cap_geo = P._Geo()
        stats["caps"] = P._caps(rig, objs, cap_geo)
        objs = objs + cap_geo.objects(rig, model_id.split("/")[-1] + "_cap")
    objs = objs + geo.objects(rig, model_id.split("/")[-1])
    objs = objs + patches.objects(rig)
    return _finish_house(model_id, spec3d, rig, info, sspec, objs, stats, t0, patches)


def _route(spec3d, objs):
    """(materials by name, names of the vpbr materials, names of the lamps kept in the atlas)."""
    mats = {}
    for ob in objs:
        for s in ob.material_slots:
            if s.material is not None:
                if s.material.get("ce_role") is None and BK.has_cutout(s.material):
                    # props_cities.lace_mat (railings) builds its node tree without cesprites.materials.finish and so
                    # without a role: a cut-out mask is procedural by construction - it is baked (not a name guess)
                    s.material["ce_role"] = "proc"
                roles.tag(s.material)
                mats[s.material.name] = s.material
    force = tuple(spec3d.get("vpbr", ()))
    keep = tuple(spec3d.get("baked_lamps", ()))
    vpbr = set()
    for name, m in mats.items():
        role, d = roles.tag(m)
        if m.get("ce_atlas"):
            continue                    # AS4R: panes of an atlas patch (their light in the emission atlas)
        if m.get("ce_vpbr"):
            vpbr.add(name)
        elif role == "flat" and any(name.startswith(k) for k in force):
            vpbr.add(name)
        elif role == "flat" and roles.lamp_from_emit(d.get("emit")) is not None and not any(name.startswith(k) for k in keep):
            vpbr.add(name)
    return mats, vpbr


def _finish_house(model_id, spec3d, rig, info, sspec, objs, stats, t0, patches=None):
    mats, vpbr_names = _route(spec3d, objs)
    P._open_lamp_boxes(objs, [mats[n] for n in sorted(vpbr_names) if not mats[n].get("ce_vpbr")])
    rotor = spec3d.get("rotor") or {}
    rotor_obs = {o.name for o in objs if any(o.name.startswith(n) for n in rotor.get("objects", ()))}
    for o in objs:
        if o.name in rotor_obs:
            for s in o.material_slots:
                if s.material is not None:
                    vpbr_names.add(s.material.name)
    lod0_objs = [o for o in objs if _level(o) != "lod1"]
    bake_objs = [o for o in lod0_objs if any(s.material is not None and s.material.name not in vpbr_names
                                             for s in o.material_slots)]
    bake_mats = sorted({s.material.name for o in bake_objs for s in o.material_slots
                        if s.material is not None and s.material.name not in vpbr_names})
    bake_mats = [mats[k] for k in bake_mats]
    cut_names = {m.name for m in bake_mats if BK.has_cutout(m)}
    if cut_names and spec3d.get("single_cutout"):
        # railings (cut-out) + walls + vpbr would be three draw calls: everything baked goes to the cut-out class (its
        # opaque texels have alpha 1) - two surfaces, at the price of a BC3 atlas
        cut_names = {m.name for m in bake_mats}
    size = tuple(spec3d.get("atlas", (1024, 1024)))
    wf = weight_fn(spec3d.get("view", "roadside"), dict(spec3d.get("weights") or {}))
    baked = bake_house(rig, bake_objs, bake_mats, size, weight_fn=wf, ppm_max=spec3d.get("ppm_max", 128.0),
                       cutout=bool(cut_names), ao=spec3d.get("ao"))
    if baked["alpha"] is not None:
        # mipmap-safe alpha (railings): transparent texels next to a bar get the halo alpha 0.33
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
    lods = []
    pts0 = None
    for li, lvl in enumerate(levels):
        mb = core.MeshBuilder()
        level_objs = [o for o in objs if _level(o) in ("both", lvl)]
        # the light anchors come from lod0 only; the far level translates its own copy
        tl = tr if li == 0 else roles.Translator(glass_class=False, overrides=over)
        for soup in core.soups_of(level_objs, uv_layer=BK.UV_NAME):
            for mi in np.unique(soup.mi):
                mat = soup.material(int(mi))
                sel = soup.mi == mi
                if soup.name in rotor_obs:
                    rb = core.MeshBuilder()
                    tl.add_object(rb, P._SubSoup(soup, sel))
                    P._mark_rotor(rb, rotor)
                    mb.merge(rb)
                    continue
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
        max_d = LOD0_M if (li == 0 and len(levels) > 1) else 100000
        lods.append(Lod(lvl, max_d, [Part("body", "%s_body" % lvl, mb.finish(min_height=1e-4), auto_lod=False)]))
    model = P._finish_model(model_id, spec3d, sspec, info, pts0)
    if spec3d.get("extent_view") is not None:
        from .export import sprite_extent
        model.extent_m = sprite_extent(pts0, float(spec3d["extent_view"]))
    model.auto_lod = False
    model.lods = lods
    model.lights = tr.lights(split_x=0.0)
    model.roughness = float(spec3d.get("roughness", 0.9))
    big = max(size) > 1024
    alb_name = "albedo.webp" if big else "albedo.png"
    model.texture_files[alb_name] = BK.encode(baked["albedo"], baked["alpha"], "webp" if big else "png")
    model.textures["albedo"] = alb_name
    em = baked["emit"].get("lights")
    if em is not None and float(em.max()) > 0.05:
        model.texture_files["emit.png"] = BK.encode(BK.half(em), None, "png")
        model.textures["emit"] = "emit.png"
    stats["emit_max"] = round(float(em.max()), 3) if em is not None else 0.0
    model.stats = dict(build_s=round(time.time() - t0, 2), objects=len(objs), bake=baked["stats"], **stats)
    return model
