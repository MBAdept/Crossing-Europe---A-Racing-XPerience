"""AS4 (wave 5): bridge parts of the mode "Modern" (docs/modelle.md section 15). Builders (catalog3d,
export_models.BUILDERS):

  pylon   the pylon of a cable-stayed bridge (props/bridge_pylon, category pylon: one draw call): concrete leg, head,
          anchor plates and aviation light in ONE baked atlas; the stay cables rebuilt from the generator's beams as
          four-sided prisms that all sample one solid patch of the cable colour; lod1 with thicker cables
  truss   the truss portal over the carriageway (props/bridge_truss_arch, furniture: one draw call): chords, posts,
          bases and ties as geometry, the web of each plane drawn into a mipmap-safe cut-out picture (class
          baked_cutout), lamps with light anchors over the deck

The generators of these sets live in cesprites/props_cities.py (owned by the city packages): nothing there is
changed - the builders read the generator's meshes back (_boxes: every box beam with its axis and cross-section).
"""
import math
import time

import numpy as np

from . import bake as BK
from . import core, roles
from . import props3d as P
from .buildings3d import LOD0_M, weight_fn
from .export import Lod, Part


def boxes(ob):
    """The boxes (bm_beam / bm_box) of a mesh object: [dict(c, axis, a, b, length, w, h, ew, eh)] in root space - the
    end centres a, b along the longest principal axis, the cross-section w x h along ew / eh."""
    import bmesh
    mw = np.array(ob.matrix_world, dtype=np.float64)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    seen = set()
    out = []
    for v0 in bm.verts:
        if v0.index in seen:
            continue
        comp, stack = [], [v0]
        seen.add(v0.index)
        while stack:
            v = stack.pop()
            comp.append(v)
            for e in v.link_edges:
                o = e.other_vert(v)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        pts = np.array([mw[:3, :3] @ np.array(v.co) + mw[:3, 3] for v in comp])
        c = pts.mean(axis=0)
        cov = (pts - c).T @ (pts - c)
        _vals, vecs = np.linalg.eigh(cov)
        ext = []
        for k in range(3):
            pr = (pts - c) @ vecs[:, k]
            ext.append(float(pr.max() - pr.min()))
        order = np.argsort(ext)[::-1]
        ax = vecs[:, order[0]]
        if ax[np.argmax(np.abs(ax))] < 0:
            ax = -ax                     # a stable sign: the same beam gives the same end points in every run
        L = ext[order[0]]
        out.append(dict(c=c, axis=ax, a=c - ax * L / 2, b=c + ax * L / 2, length=L, w=ext[order[1]], h=ext[order[2]],
                        ew=vecs[:, order[1]], eh=vecs[:, order[2]]))
    bm.free()
    out.sort(key=lambda m: tuple(round(float(v), 3) for v in m["c"]))
    return out


def prism(add, a, b, w, h, ew, eh, caps=False):
    """A box beam from a to b (cross-section w along ew, h along eh): add(points, normal) per triangle."""
    a, b = np.asarray(a, dtype=np.float64), np.asarray(b, dtype=np.float64)
    hw, hh = np.asarray(ew) * w * 0.5, np.asarray(eh) * h * 0.5
    corners = [hw + hh, -hw + hh, -hw - hh, hw - hh]
    for i in range(4):
        p, q = corners[i], corners[(i + 1) % 4]
        n = p + q
        n = n / max(1e-9, np.linalg.norm(n))
        add([a + p, b + p, b + q], n)
        add([a + p, b + q, a + q], n)
    if caps:
        d = (b - a) / max(1e-9, np.linalg.norm(b - a))
        for (o, sgn) in ((a, -1.0), (b, 1.0)):
            q = [o + c for c in corners]
            add([q[0], q[1], q[2]], d * sgn)
            add([q[0], q[2], q[3]], d * sgn)


class Tris:
    """Triangles with their atlas coordinates for one class of a MeshBuilder."""

    def __init__(self):
        self.pos, self.nor, self.uv = [], [], []

    def add(self, pts, normal, uv):
        pts = [np.asarray(p, dtype=np.float64) for p in pts]
        n = np.asarray(normal, dtype=np.float64)
        uvs = [list(u) for u in uv] if isinstance(uv[0], (list, tuple, np.ndarray)) else [list(uv)] * 3
        if np.cross(pts[1] - pts[0], pts[2] - pts[0]) @ n < 0:
            pts = [pts[0], pts[2], pts[1]]
            uvs = [uvs[0], uvs[2], uvs[1]]
        self.pos.append(pts)
        self.nor.append([n, n, n])
        self.uv.append(uvs)

    def to(self, mb, cls):
        if self.pos:
            mb.add(cls, np.array(self.pos), np.array(self.nor), uv=np.array(self.uv, dtype=np.float64))


def _patch_object(rig, mat, name, at=(0.0, 0.0, -40.0), size=0.4):
    """A small square with a material, far below the model: its chart in the atlas is a solid patch of the material's
    colour (parts that are mapped onto it: the cables)."""
    import bmesh
    from cesprites import meshutil as MU
    bm = bmesh.new()
    x, y, z = at
    s = size / 2
    vs = [bm.verts.new(p) for p in ((x - s, y, z - s), (x + s, y, z - s), (x + s, y, z + s), (x - s, y, z + s))]
    bm.faces.new(vs)
    ob = MU.make(name, bm, mat, parent=rig.root)
    MU.tag(ob, node_name="body")
    return ob


def _uv_centre(ob):
    """Mean atlas coordinate of an object's loops (glTF / Godot convention: v down)."""
    lay = ob.data.uv_layers[BK.UV_NAME]
    uv = np.empty(len(ob.data.loops) * 2, dtype=np.float32)
    lay.data.foreach_get("uv", uv)
    c = uv.reshape(-1, 2).astype(np.float64).mean(axis=0)
    return [float(c[0]), float(1.0 - c[1])]


def _split_bands(objs, prefix, heights, tol=0.05):
    """Splits the edges of objects (name prefix) that lie at the given heights: the box unwrap then makes one chart per
    band - an 82 m wall in one chart limits the density of the whole atlas to 1024 px / 82 m = 12 px/m."""
    import bmesh
    n = 0
    for ob in objs:
        if not ob.name.startswith(prefix):
            continue
        mw = np.array(ob.matrix_world, dtype=np.float64)
        bm = bmesh.new()
        bm.from_mesh(ob.data)

        def wz(v, _mw=mw):
            return float((_mw[:3, :3] @ np.array(v.co) + _mw[:3, 3])[2])
        edges = [e for e in bm.edges if all(any(abs(wz(v) - h) < tol for h in heights) for v in e.verts)]
        if edges:
            bmesh.ops.split_edges(bm, edges=edges)
            n += len(edges)
        bm.to_mesh(ob.data)
        bm.free()
        ob.data.update()
    return n


def _band_objects(objs, prefix, heights):
    """Splits objects (name prefix) into one object per height band (faces by their centre height; the bands meet at
    edges that _split_bands has cut): the bake weight can then follow the height (_height_weight)."""
    import bpy
    import bmesh
    edges = [-1e9] + sorted(float(h) for h in heights) + [1e9]
    out = []
    for ob in objs:
        if not ob.name.startswith(prefix):
            out.append(ob)
            continue
        mw = np.array(ob.matrix_world, dtype=np.float64)
        for k in range(len(edges) - 1):
            nob = ob.copy()
            nob.data = ob.data.copy()
            nob.name = "%s_band%d" % (ob.name, k)
            for col in ob.users_collection:
                col.objects.link(nob)
            bm = bmesh.new()
            bm.from_mesh(nob.data)
            drop = []
            for f in bm.faces:
                z = float((mw[:3, :3] @ np.array(f.calc_center_median()) + mw[:3, 3])[2])
                if not edges[k] <= z < edges[k + 1]:
                    drop.append(f)
            bmesh.ops.delete(bm, geom=drop, context="FACES")
            bm.to_mesh(nob.data)
            bm.free()
            nob.data.update()
            if len(nob.data.polygons):
                out.append(nob)
            else:
                bpy.data.objects.remove(nob, do_unlink=True)
        bpy.data.objects.remove(ob, do_unlink=True)
    return out


def _height_weight(wf, heights, band_w):
    """Texel weight by height: wf times band_w[k] for the band k that holds the centre of the object's bounds - the
    foot next to the carriageway keeps the density, the head 60-88 m up (seen from 100 m and more) gets less."""
    hs = sorted(float(h) for h in heights)
    cache = {}

    def fn(n, ob):
        z = cache.get(ob.name)
        if z is None:
            zs = [float((ob.matrix_world @ v.co)[2]) for v in ob.data.vertices]
            z = (min(zs) + max(zs)) / 2.0 if zs else 0.0
            cache[ob.name] = z
        k = min(sum(1 for h in hs if z >= h), len(band_w) - 1)
        return wf(n, ob) * float(band_w[k])
    return fn


def build_pylon(model_id, spec3d):
    """The pylon of a cable-stayed bridge (see the module text). Options: cables (object prefix), beacon (object prefix
    of the aviation light), beacon_dir (Blender axes), cable_w (cable width per level), split (object prefix, heights:
    chart bands), band_w (texel weight per band, bottom up: every object by its height), atlas, ppm_max, view,
    roughness."""
    t0 = time.time()
    rig, info, sspec = P._build_source(spec3d)
    objs = P._objects(rig)
    core.realize(objs)
    if spec3d.get("split"):
        prefix, heights = spec3d["split"]
        _split_bands(objs, prefix, heights)
        if spec3d.get("band_w"):
            objs = _band_objects(objs, prefix, heights)
    cable_obs = [o for o in objs if o.name.startswith(spec3d.get("cables", "bpy_cables"))]
    cables = [bx for o in cable_obs for bx in boxes(o)]
    rest = [o for o in objs if o not in cable_obs]
    patch = _patch_object(rig, cable_obs[0].material_slots[0].material, "ce_patch_cable")
    bake_objs = rest + [patch]
    mats = {}
    for ob in bake_objs:
        for s in ob.material_slots:
            if s.material is not None:
                roles.tag(s.material)
                mats[s.material.name] = s.material
    size = tuple(spec3d.get("atlas", (1024, 1024)))
    wf = weight_fn(spec3d.get("view", "allround"), dict(spec3d.get("weights") or {}))
    if spec3d.get("split") and spec3d.get("band_w"):
        wf = _height_weight(wf, spec3d["split"][1], spec3d["band_w"])
    baked = BK.bake_atlas(rig, bake_objs, [mats[k] for k in sorted(mats)], size, weight_fn=wf,
                          ppm_max=spec3d.get("ppm_max", 64.0), ao=spec3d.get("ao"))
    cuv = _uv_centre(patch)
    lods = []
    widths = list(spec3d.get("cable_w", (0.24, 0.4)))
    pts0 = None
    for li, cw in enumerate(widths):
        mb = core.MeshBuilder()
        for soup in core.soups_of(rest, uv_layer=BK.UV_NAME):
            uv = soup.uv.copy()
            uv[:, :, 1] = 1.0 - uv[:, :, 1]
            mb.add("baked", soup.pos, soup.nor, uv=uv)
        tris = Tris()
        for c in cables:
            prism(lambda p, n: tris.add(p, n, cuv), c["a"], c["b"], cw, cw, c["ew"], c["eh"])
        tris.to(mb, "baked")
        if li == 0:
            pts0 = mb.points()
        name = "lod%d" % li
        lods.append(Lod(name, LOD0_M if li < len(widths) - 1 else 100000,
                        [Part("body", "%s_body" % name, mb.finish(min_height=1e-4), auto_lod=False)]))
    model = P._finish_model(model_id, spec3d, sspec, info, pts0)
    model.lods = lods
    model.auto_lod = False
    model.roughness = float(spec3d.get("roughness", 0.8))
    lights = []
    for ob in rest:
        if not ob.name.startswith(spec3d.get("beacon", "bpy_red")):
            continue
        pts = np.array([tuple(ob.matrix_world @ v.co) for v in ob.data.vertices])
        lo, hi = pts.min(axis=0), pts.max(axis=0)
        d = np.asarray(spec3d.get("beacon_dir", (-1.0, 0.0, 0.0)), dtype=np.float64)
        p = (lo + hi) / 2 + d * float(np.max(hi - lo)) * 0.5
        lights.append({"role": "lights", "pos": core.model_point(p),
                       "dir": [round(float(v), 3) + 0.0 for v in core.model_point(d)],
                       "size": round(float(np.max(hi - lo)), 3), "color": spec3d.get("beacon_color", "#ff2a1a")})
    model.lights = lights
    model.texture_files["albedo.png"] = BK.encode(baked["albedo"], None, "png")
    model.textures["albedo"] = "albedo.png"
    em = baked["emit"].get("lights")
    if em is not None and float(em.max()) > 0.05:
        model.texture_files["emit.png"] = BK.encode(BK.half(em), None, "png")
        model.textures["emit"] = "emit.png"
    model.stats = dict(build_s=round(time.time() - t0, 2), cables=len(cables), bake=baked["stats"],
                       emit_max=round(float(em.max()), 3) if em is not None else 0.0)
    return model


def build_lantern(model_id, spec3d):
    """Street furniture with glass lanterns (props/bridge_lamp; one vpbr surface): prop_vpbr of props3d, except for the
    lantern glass (objects named in "glass"): an unlit vpbr lamp shows half its lit colour - the frosted glass looked
    tan by day. Its sides are a flood-lit surface (lamp channel 14: their own pale colour by day, lit at night); only
    the faces looking down stay a lamp of channel 12 with a light anchor (dir down: the pools on the pavement and the
    far glow come from there). Options: glass (prefixes), hidden_tops, side_flood (weight), overrides."""
    t0 = time.time()
    rig, info, sspec = P._build_source(spec3d)
    objs = P._objects(rig)
    dropped = P._drop_hidden_tops(objs, spec3d.get("hidden_tops", ()))
    tr = roles.Translator(overrides=spec3d.get("overrides"), glass_class=False)
    mb = core.MeshBuilder()
    glass = tuple(spec3d.get("glass", ()))
    side = "-flood:%.2f" % float(spec3d.get("side_flood", 0.85))
    for soup in core.soups_of(objs):
        if not any(soup.name.startswith(g) for g in glass):
            left = tr.add_object(mb, soup)
            if left:
                raise roles.RoleError("%s: object '%s' has %s materials" % (model_id, soup.name, "/".join(sorted(left))))
            continue
        for mi in np.unique(soup.mi):
            sel = soup.mi == mi
            role, d = tr.describe(soup.material(int(mi)))
            lamp = roles.lamp_from_emit(d.get("emit"))
            lit = core.lin_to_hex(lamp[2]) if lamp else "#ffd890"
            pos, nor = soup.pos[sel], soup.nor[sel]
            down = nor.mean(axis=1)[:, 2] < -0.5
            if down.any():
                tr.add_role(mb, "flat", d, pos[down], nor[down], lamp_tag="lights:1:%s" % lit)
            if (~down).any():
                tr.add_role(mb, "flat", d, pos[~down], nor[~down], lamp_tag=side)
    pts = mb.points()
    model = P._finish_model(model_id, spec3d, sspec, info, pts)
    model.lods = [Lod("lod0", 100000, [Part("body", "lod0_body", mb.finish(), auto_lod=False)])]
    model.lights = tr.lights()
    model.stats = dict(build_s=round(time.time() - t0, 2), objects=len(objs), hidden_tops=dropped)
    return model


TRUSS_MIN_SOLID = 0.4     # members with a cross-section of at least this (m) stay geometry (chords, posts, bases)


def _visible_width(m):
    """Width of a member seen along y (the camera on the road): its cross-section perpendicular to the axis and y."""
    perp = np.cross(m["axis"], np.array([0.0, 1.0, 0.0]))
    ln = np.linalg.norm(perp)
    if ln < 1e-6:
        return max(m["w"], m["h"])
    perp /= ln
    return abs(float(perp @ m["ew"])) * m["w"] + abs(float(perp @ m["eh"])) * m["h"]


def build_truss(model_id, spec3d):
    """The truss portal (see the module text). Options: truss / plates / housing / lens (object prefixes), steel (hex),
    ppm (picture density), atlas, cell (m, the quads around the web), roughness."""
    from PIL import Image, ImageDraw
    from . import leafatlas
    t0 = time.time()
    rig, info, sspec = P._build_source(spec3d)
    objs = P._objects(rig)
    core.realize(objs)

    def of(pre):
        return [bx for o in objs if o.name.startswith(pre) for bx in boxes(o)]
    members = of(spec3d.get("truss", "bta_truss"))
    plates = of(spec3d.get("plates", "bta_plates"))
    housings = of(spec3d.get("housing", "bta_lh"))
    lenses = of(spec3d.get("lens", "bta_lamp"))
    solid, web = [], []
    for m in members:
        (solid if abs(m["axis"][1]) > 0.9 or m["w"] >= TRUSS_MIN_SOLID else web).append(m)
    planes = sorted({round(float(m["c"][1]), 1) for m in web})
    ppm = float(spec3d.get("ppm", 28.0))
    W, H = tuple(spec3d.get("atlas", (1024, 512)))
    pl0 = planes[0]
    web0 = [m for m in web if abs(float(m["c"][1]) - pl0) < 0.6]
    plates0 = [p for p in plates if abs(float(p["c"][1]) - pl0) < 0.6]
    xs = np.concatenate([[m["a"][0], m["b"][0]] for m in web0 + plates0])
    zs = np.concatenate([[m["a"][2], m["b"][2]] for m in web0 + plates0])
    x0, x1 = float(xs.min()) - 0.6, float(xs.max()) + 0.6
    z0, z1 = max(0.0, float(zs.min()) - 0.6), float(zs.max()) + 0.6
    pw, ph = int(math.ceil((x1 - x0) * ppm)), int(math.ceil((z1 - z0) * ppm))
    if pw + 48 > W or ph + 8 > H:
        raise RuntimeError("truss picture %d x %d px does not fit the atlas %d x %d" % (pw, ph, W, H))
    steel = spec3d.get("steel", "#56676a")
    col = tuple(int(c) for c in core.srgb8(core.hex_to_lin(steel)))
    dark = tuple(int(c * 0.7) for c in col)
    light = tuple(min(255, int(c * 1.1)) for c in col)
    ss = 4
    img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    ox, oy = 4, 4

    def tx(x, z):
        return np.array([(ox + (x - x0) * ppm) * ss, (oy + (z1 - z) * ppm) * ss])
    for m in web0:
        wpx = max(_visible_width(m) * ppm, P.LATTICE_MIN_PX) * ss
        pa, pb = tx(m["a"][0], m["a"][2]), tx(m["b"][0], m["b"][2])
        d = pb - pa
        ln = float(np.linalg.norm(d))
        if ln < 1e-6:
            continue
        nrm = np.array([-d[1], d[0]]) / ln * wpx * 0.5
        dr.polygon([tuple(pa + nrm), tuple(pb + nrm), tuple(pb - nrm), tuple(pa - nrm)], fill=dark + (255,))
        dr.polygon([tuple(pa + nrm * 0.5), tuple(pb + nrm * 0.5), tuple(pb - nrm * 0.5), tuple(pa - nrm * 0.5)],
                   fill=col + (255,))
    for p in plates0:
        corners = [p["c"] + p["axis"] * p["length"] / 2 * s1 + p["ew"] * p["w"] / 2 * s2
                   for (s1, s2) in ((1, 1), (-1, 1), (-1, -1), (1, -1))]
        dr.polygon([tuple(tx(float(q[0]), float(q[2]))) for q in corners], fill=light + (255,))
    # solid patches for the geometry: steel, lamp housing, lens - squares in the free column right of the picture
    patches = {}
    for i, (key, c) in enumerate((("steel", col), ("dark", (46, 52, 54)), ("lens", (255, 242, 214)))):
        x_p, y_p = ox + pw + 12, 8 + i * 28
        dr.rectangle([x_p * ss, y_p * ss, (x_p + 20) * ss, (y_p + 20) * ss], fill=c + (255,))
        patches[key] = [(x_p + 10) / W, (y_p + 10) / H]
    img = img.resize((W, H), Image.LANCZOS)
    a = np.array(img).astype(np.float64)
    a[:, :, 3] = np.where(a[:, :, 3] / 255.0 >= 0.5, 255.0, 0.0)
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    img = leafatlas.halo(img, alpha=P.LATTICE_HALO, px=P.LATTICE_HALO_PX, scissor=P.LATTICE_SCISSOR)
    img = leafatlas.bleed(img, scissor=P.LATTICE_SCISSOR)
    # quads around the web of a plane: occupied cells (members sampled every 25 cm), joined to runs per row
    cell = float(spec3d.get("cell", 1.0))
    nx, nz = int(math.ceil((x1 - x0) / cell)), int(math.ceil((z1 - z0) / cell))
    occ = np.zeros((nz, nx), dtype=bool)
    for m in web0 + plates0:
        for t in np.linspace(0.0, 1.0, max(2, int(m["length"] / 0.25) + 1)):
            q = m["a"] + (m["b"] - m["a"]) * t
            ix, iz = int((float(q[0]) - x0) / cell), int((z1 - float(q[2])) / cell)
            if 0 <= ix < nx and 0 <= iz < nz:
                occ[iz, ix] = True
    # a member of half a cell's width that touches a neighbouring cell: grow the occupancy by one cell
    grown = occ.copy()
    grown[1:, :] |= occ[:-1, :]
    grown[:-1, :] |= occ[1:, :]
    grown[:, 1:] |= occ[:, :-1]
    grown[:, :-1] |= occ[:, 1:]
    occ = grown
    runs = []
    for iz in range(nz):
        ix = 0
        while ix < nx:
            if occ[iz, ix]:
                j = ix
                while j < nx and occ[iz, j]:
                    j += 1
                runs.append((x0 + ix * cell, x0 + j * cell, z1 - (iz + 1) * cell, z1 - iz * cell))
                ix = j
            else:
                ix += 1
    tris = Tris()

    def uv_of(x, z):
        return [(ox + (x - x0) * ppm) / W, (oy + (z1 - z) * ppm) / H]
    for yp in planes:
        for (xa, xb, za, zb) in runs:
            q = [np.array([xa, yp, za]), np.array([xb, yp, za]), np.array([xb, yp, zb]), np.array([xa, yp, zb])]
            uvs = [uv_of(xa, za), uv_of(xb, za), uv_of(xb, zb), uv_of(xa, zb)]
            tris.add([q[0], q[1], q[2]], (0.0, -1.0, 0.0), [uvs[0], uvs[1], uvs[2]])
            tris.add([q[0], q[2], q[3]], (0.0, -1.0, 0.0), [uvs[0], uvs[2], uvs[3]])
    for m in solid:
        prism(lambda p, n: tris.add(p, n, patches["steel"]), m["a"], m["b"], m["w"], m["h"], m["ew"], m["eh"],
              caps=m["length"] < 3.0)
    for m in housings:
        prism(lambda p, n: tris.add(p, n, patches["dark"]), m["a"], m["b"], m["w"], m["h"], m["ew"], m["eh"], caps=True)
    for m in lenses:
        prism(lambda p, n: tris.add(p, n, patches["lens"]), m["a"], m["b"], m["w"], m["h"], m["ew"], m["eh"], caps=True)
    mb = core.MeshBuilder()
    tris.to(mb, "baked_cutout")
    pts0 = mb.points()
    model = P._finish_model(model_id, spec3d, sspec, info, pts0)
    model.lods = [Lod("lod0", 100000, [Part("body", "lod0_body", mb.finish(min_height=1e-4), auto_lod=False)])]
    model.auto_lod = False
    model.roughness = float(spec3d.get("roughness", 0.55))
    model.texture_files["albedo.png"] = leafatlas.png_bytes(img)
    model.textures["albedo"] = "albedo.png"
    # night: the lenses glow (emission atlas, half size) and light the deck (anchors looking down)
    emit = Image.new("RGB", (W // 2, H // 2), (0, 0, 0))
    de = ImageDraw.Draw(emit)
    x_l, y_l = (ox + pw + 12) // 2, (8 + 2 * 28) // 2
    de.rectangle([x_l, y_l, x_l + 10, y_l + 10], fill=(255, 216, 144))
    model.texture_files["emit.png"] = leafatlas.png_bytes(emit)
    model.textures["emit"] = "emit.png"
    lights = []
    for m in lenses:
        p = m["c"] - np.array([0.0, 0.0, min(m["w"], m["h"]) * 0.5])
        lights.append({"role": "lights", "pos": core.model_point(p), "dir": [0.0, -1.0, 0.0],
                       "size": round(float(max(m["length"], m["w"])), 3), "color": "#ffd890"})
    model.lights = sorted(lights, key=lambda e: (e["pos"][0], e["pos"][1], e["pos"][2]))
    model.stats = dict(build_s=round(time.time() - t0, 2), solid=len(solid), web=len(web), plates=len(plates),
                       planes=planes, picture=[pw, ph], runs=len(runs),
                       coverage=leafatlas.coverage(img, 6, scissor=P.LATTICE_SCISSOR))
    return model
