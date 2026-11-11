"""Props, buildings and landmarks as real-time models.

  prop_vpbr    flat materials -> one vertex-PBR surface (road furniture, lamps as channel 12)
  prop_baked   procedural materials -> one atlas (albedo + night emission at half size), class baked
               (+ baked_cutout for materials with cut-out masks)
Model space: origin = the sprite anchor (ground, centre of the near face), the prop extends to -Z, +X is
to the right of the travel direction. A prop rendered for the right roadside (tag mirror_left) therefore
shows its -X side to the road and its +Z side to the approaching player.

Options of a catalog entry (ce3d.catalog3d):
  overrides  {material name: dict(role=..., color=hex, rough=, metal=, lamp=, skip=True)}  (prop_vpbr)
  atlas      (W, H) of the albedo atlas; ppm_max caps the texel density (px/m)
  view       'roadside' (road and approach faces 1.0, away faces 0.3, undersides 0.05) | 'allround'
             (all walls and roofs 1.0, undersides 0.05) - texel density weights (contract 4.6.5)
  params     extra generator parameters (e.g. allround=True: windows on every side of a landmark)
  roughness  the one roughness of the baked surfaces
"""
import math
import time

import numpy as np

from . import bake as BK
from . import core, roles
from .export import Lod, ModelData, Part, sprite_extent


def _sprite_spec(set_id):
    from cesprites import catalog
    for s in catalog.all_sets():
        if s["id"] == set_id:
            return s
    raise KeyError(set_id)


def _build_source(spec3d):
    """Builds the generator model of the source sprite set with node tagging on. Returns rig, info, spec."""
    import render_all as RA
    from cesprites import meshutil as MU
    from cesprites import rig as R
    sspec = dict(_sprite_spec(spec3d["source"]))
    if spec3d.get("params"):
        sspec["params"] = dict(sspec["params"], **spec3d["params"])
    rig = R.Rig(quick=True)
    MU.tagging(True)
    try:
        info = RA.build(rig, sspec)
    finally:
        MU.tagging(False)
    return rig, info, sspec


def _objects(rig):
    """Objects of the 3D model: everything tagged except node 'none' (sprite-only effects)."""
    out = []
    for ob in core.model_objects(rig):
        if roles.node_of(ob) != "none":
            out.append(ob)
    return out


def _object_size(info, pts):
    obj = info.get("object")
    if obj:
        return dict(obj)
    mn, mx = pts.min(axis=0), pts.max(axis=0)
    return {"width_m": round(float(mx[0] - mn[0]), 2), "length_m": round(float(mx[1] - mn[1]), 2),
            "height_m": round(float(mx[2]), 2)}


def _finish_model(model_id, spec3d, sspec, info, pts):
    model = ModelData(model_id, spec3d["kind"], _object_size(info, pts))
    model.extent_m = sprite_extent(pts, sspec["camera"].get("view_yaw", 0.0))
    model.tags = list(sspec.get("tags", []))
    model.auto_lod = bool(spec3d.get("auto_lod", False))
    for sid in (spec3d.get("sets") or [model_id]):
        model.sets[sid] = {"model": model_id}
    return model


# Rotors (AS1b): the vertices of a turning part (rotor of a wind turbine, sails of a windmill) carry the vpbr
# paint code ROTOR_CODE (COLOR.a 0.875 - today's vpbr.gdshader draws it as a fixed colour: a standing rotor) and
# UV2 = (-1, hub height / ROTOR_HUB_M): the shader turns them about the model's Z axis through (0, hub height)
# with ce_time (docs/modelle.md section 14; the turning itself is asked of the owner of vpbr.gdshader).
ROTOR_CODE = 223
ROTOR_HUB_M = 128.0


def build_vpbr(model_id, spec3d):
    t0 = time.time()
    rig, info, sspec = _build_source(spec3d)
    objs = _objects(rig)
    tr = roles.Translator(overrides=spec3d.get("overrides"), glass_class=False)
    mb = core.MeshBuilder()
    rotor = spec3d.get("rotor") or {}
    for soup in core.soups_of(objs):
        target = mb
        if any(soup.name.startswith(n) for n in rotor.get("objects", ())):
            target = core.MeshBuilder()
        left = tr.add_object(target, soup)
        if left:
            raise roles.RoleError("%s: object '%s' has %s materials - give a flat override or bake the model"
                                  % (model_id, soup.name, "/".join(sorted(left))))
        if target is not mb:
            _mark_rotor(target, rotor)
            mb.merge(target)
    pts = mb.points()
    model = _finish_model(model_id, spec3d, sspec, info, pts)
    model.lods = [Lod("lod0", 100000, [Part("body", "lod0_body", mb.finish(), auto_lod=model.auto_lod)])]
    model.lights = tr.lights()
    model.stats = dict(build_s=round(time.time() - t0, 2), objects=len(objs))
    return model


def _mark_rotor(mb, rotor):
    """Rotor code on every vpbr corner of a MeshBuilder (see ROTOR_CODE): COLOR.a and UV2.y = hub height."""
    hub = float(rotor["hub_z"]) / ROTOR_HUB_M
    if not 0.0 < hub <= 1.0:
        raise ValueError("rotor hub at %.1f m: outside 0 .. %.0f m" % (float(rotor["hub_z"]), ROTOR_HUB_M))
    new = []
    for (pos, nor, col, uv, uv2) in mb.chunks.get("vpbr", []):
        col = np.array(col, copy=True)
        if np.any(uv2[..., 0] >= 0.0):
            raise ValueError("a rotor part is a lamp: rotors carry no lamp channel")
        col[..., 3] = ROTOR_CODE
        uv2 = np.array(uv2, copy=True)
        uv2[..., 1] = hub
        new.append((pos, nor, col, uv, uv2))
    mb.chunks["vpbr"] = new


def weight_roadside(n, _ob):
    """Texel density by visibility for a prop on the right roadside (Blender axes: -x = road, -y = the
    approaching player, +z = roofs)."""
    if n[2] < -0.5:
        return 0.05
    if n[2] > 0.3:
        return 1.0                   # roofs are seen from the road and from afar
    if n[0] < -0.5 or n[1] < -0.5:
        return 1.0
    return 0.3


def weight_allround(n, _ob):
    return 0.05 if n[2] < -0.5 else 1.0


def build_baked(model_id, spec3d):
    t0 = time.time()
    rig, info, sspec = _build_source(spec3d)
    objs = _objects(rig)
    core.realize(objs)
    mats = {}
    for ob in objs:
        for s in ob.material_slots:
            if s.material is not None:
                roles.tag(s.material)                 # every material must be tagged
                mats[s.material.name] = s.material
    mat_list = [mats[k] for k in sorted(mats)]
    cut_names = {m.name for m in mat_list if BK.has_cutout(m)}
    size = tuple(spec3d.get("atlas", (1024, 1024)))
    wf = weight_allround if spec3d.get("view") == "allround" else weight_roadside
    baked = BK.bake_atlas(rig, objs, mat_list, size, weight_fn=wf, ppm_max=spec3d.get("ppm_max", 128.0),
                          cutout=bool(cut_names))
    tr = roles.Translator()
    mb = core.MeshBuilder()
    for soup in core.soups_of(objs, uv_layer=BK.UV_NAME):
        uv = soup.uv.copy()
        uv[:, :, 1] = 1.0 - uv[:, :, 1]             # glTF / Godot: v down
        for mi in np.unique(soup.mi):
            mat = soup.material(int(mi))
            sel = soup.mi == mi
            mb.add("baked_cutout" if mat.name in cut_names else "baked", soup.pos[sel], soup.nor[sel], uv=uv[sel])
            # lamps of flat materials (yard lamps ...) become anchors; their glow is in the emission atlas
            role, d = roles.tag(mat)
            lamp = roles.lamp_from_emit(d.get("emit")) if role == "flat" else None
            if lamp is not None and lamp[0] == "lights" and lamp[1] >= 0.25:
                tr.anchors.append((lamp[0], soup.pos[sel].mean(axis=1), core.tri_areas(soup.pos[sel]), lamp[2]))
    pts = mb.points()
    model = _finish_model(model_id, spec3d, sspec, info, pts)
    model.lods = [Lod("lod0", 100000, [Part("body", "lod0_body", mb.finish(), auto_lod=model.auto_lod)])]
    model.lights = tr.lights()
    model.roughness = float(spec3d.get("roughness", 0.9))
    big = max(size) > 1024
    alb_name = "albedo.webp" if big else "albedo.png"
    model.texture_files[alb_name] = BK.encode(baked["albedo"], baked["alpha"], "webp" if big else "png")
    model.textures["albedo"] = alb_name
    if "lights" in baked["emit"]:
        model.texture_files["emit.png"] = BK.encode(BK.half(baked["emit"]["lights"]), None, "png")
        model.textures["emit"] = "emit.png"
    model.stats = dict(build_s=round(time.time() - t0, 2), objects=len(objs), bake=baked["stats"])
    return model


# --- buildings with depth (AS1b, docs/modelle.md section 14) -----------------------------------------------------
#
#   building   like prop_baked, plus what a real-time model needs and a sprite paints:
#     openings   the window grids and door decals of every facade material (props_buildings.WINDOW_LOG) are cut
#                into the walls (constrained Delaunay): reveals (baked, with ambient occlusion), frames, sills and
#                panes (vpbr; lit panes are lamp channel 12 - they light up with ce_night, a share given by the
#                grid's "lit", as the sprite's light layer does)
#     gutters    half-round gutters under the longest eaves of every roof, downpipes down the wall to the ground
#     caps       a cover slab on chimneys
#     ao         ambient occlusion baked into the atlas (bake.bake_atlas ao=...)
#   Two surfaces: baked (walls, roofs, reveals) and vpbr (panes, frames, sills, gutters, lamps) - rural building
#   budget: 2,000 triangles, 2 draw calls. Options of the catalog entry: "openings" (dict: reveal_m, door_m,
#   reveal_color, sill_color, door_color, pane_lit (weight range), skip_faces), "gutters" (dict or False),
#   "ao" (bake.bake_atlas).

REVEAL_M = 0.12
FRAME_W = 0.06
SILL_M = 0.05
GUTTER_R = 0.065


def _vpbr_mat(name, color, rough=0.5, metal=0.0, lamp=None):
    """A flat material that goes to the vpbr surface of a building (custom property ce_vpbr)."""
    import json
    from cesprites import materials as M
    m = M.basic(name, color, rough=rough, metal=metal)
    if lamp:
        d = json.loads(m["ce_data"])
        d["lamp"] = lamp
        m["ce_data"] = json.dumps(d, sort_keys=True)
    m["ce_vpbr"] = 1
    return m


def _baked_flat(name, color):
    """A plain colour that is baked into the atlas (reveals): role flat, no ce_vpbr."""
    from cesprites import materials as M
    return M.basic(name, color, rough=0.85)


def _face_class(n):
    if abs(n[2]) > 0.5:
        return None
    if abs(n[1]) >= abs(n[0]):
        return "front" if n[1] < 0 else "back"
    return "left" if n[0] < 0 else "right"


# faces a grid of props_buildings.facade() paints (its "face" key; anything else = front and back)
GRID_FACES = {"front": ("front",), "back": ("back",), "side": ("left", "right"), "left": ("left",),
              "right": ("right",)}


def _grid_windows(g):
    """Window rectangles (u0, u1, z0, z1) of a facade grid, clipped to its band - as the shader paints them."""
    u0, u1 = g["u"]
    z0, z1 = g["z"]
    pu, pz = g["pitch"]
    wu, wz = g["win"]
    out = []
    k = 0
    while u0 + pu / 2 + k * pu - wu / 2 < u1:
        uc = u0 + pu / 2 + k * pu
        j = 0
        while z0 + pz / 2 + j * pz - wz / 2 < z1:
            zc = z0 + pz / 2 + j * pz
            a, b = max(uc - wu / 2, u0), min(uc + wu / 2, u1)
            c, d = max(zc - wz / 2, z0), min(zc + wz / 2, z1)
            if b - a > 0.25 and d - c > 0.25:
                out.append((a, b, c, d))
            j += 1
        k += 1
    return out


def _inside_poly(pt, poly):
    """Point in polygon (2D, even-odd)."""
    x, y = pt
    inside = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1 + 1e-12):
            inside = not inside
    return inside


def _cdt_with_holes(poly, holes):
    """Triangles [(p, q, r) 2D] of a polygon minus holes (constrained Delaunay)."""
    from mathutils import Vector
    from mathutils.geometry import delaunay_2d_cdt

    def ccw(p):
        # the triangulation only fills polygons given counter-clockwise (measured: a clockwise wall face came
        # back without a single triangle)
        area = sum(p[i][0] * p[(i + 1) % len(p)][1] - p[(i + 1) % len(p)][0] * p[i][1] for i in range(len(p)))
        return list(p) if area > 0 else list(reversed(p))
    poly = ccw(poly)
    holes = [ccw(h) for h in holes]
    verts = [Vector((float(x), float(y))) for (x, y) in poly]
    faces = [list(range(len(poly)))]
    edges = [(i, (i + 1) % len(poly)) for i in range(len(poly))]
    for h in holes:
        base = len(verts)
        verts += [Vector((float(x), float(y))) for (x, y) in h]
        faces.append(list(range(base, base + len(h))))
        edges += [(base + i, base + (i + 1) % len(h)) for i in range(len(h))]
    vco, _e, ofaces, _ov, _oe, orig_f = delaunay_2d_cdt(verts, edges, faces, 1, 1e-7)
    tris = []
    for f, of in zip(ofaces, orig_f):
        if 0 not in of or any(i > 0 for i in of):
            continue
        pts = [(vco[i][0], vco[i][1]) for i in f]
        for i in range(1, len(pts) - 1):
            tris.append((pts[0], pts[i], pts[i + 1]))
    return tris


class _Geo:
    """Triangles per material, collected in root space and turned into one object per material."""

    def __init__(self):
        self.tris = {}

    def tri(self, mat, a, b, c, normal):
        a, b, c = (np.asarray(v, dtype=np.float64) for v in (a, b, c))
        if np.cross(b - a, c - a) @ np.asarray(normal, dtype=np.float64) < 0:
            b, c = c, b
        self.tris.setdefault(mat.name, (mat, []))[1].append((a, b, c))

    def quad(self, mat, a, b, c, d, normal):
        self.tri(mat, a, b, c, normal)
        self.tri(mat, a, c, d, normal)

    def box(self, mat, lo, hi, skip_bottom=True):
        x0, y0, z0 = (float(v) for v in lo)
        x1, y1, z1 = (float(v) for v in hi)
        self.quad(mat, (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), (0, 0, 1))
        if not skip_bottom:
            self.quad(mat, (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (0, 0, -1))
        self.quad(mat, (x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1), (0, -1, 0))
        self.quad(mat, (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1), (0, 1, 0))
        self.quad(mat, (x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1), (-1, 0, 0))
        self.quad(mat, (x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1), (1, 0, 0))

    def objects(self, rig, prefix):
        import bmesh
        from cesprites import meshutil as MU
        out = []
        for name in sorted(self.tris):
            mat, tris = self.tris[name]
            bm = bmesh.new()
            for (a, b, c) in tris:
                vs = [bm.verts.new(tuple(float(x) for x in p)) for p in (a, b, c)]
                try:
                    bm.faces.new(vs)
                except ValueError:
                    pass
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
            ob = MU.make("%s_%s" % (prefix, name), bm, mat, parent=rig.root)
            MU.tag(ob, node_name="body")
            out.append(ob)
        return out


def _openings(rig, objs, log, opt, geo):
    """Cuts the windows and doors of the facade materials into their walls; reveals, frames, sills and panes go
    to geo. Returns the number of openings."""
    import bmesh
    import zlib
    by_mat = {e["material"]: e for e in log}
    reveal_m = float(opt.get("reveal_m", REVEAL_M))
    reveal_mat = _baked_flat("ce_reveal", opt.get("reveal_color", "#d9d2c6"))
    frame_mats = {}
    pane_dark = {}
    pane_lit = {}
    sill_mat = _vpbr_mat("ce_sill", opt.get("sill_color", "#bdb8ae"), rough=0.8)
    door_mat = _vpbr_mat("ce_door", opt.get("door_color", "#5a3a22"), rough=0.75)
    gap_mat = _vpbr_mat("ce_door_gap", "#2a1b10", rough=0.8)
    # lit panes: a vpbr lamp shows HALF its lit colour by day - so the lit colour is a dark warm tone (a window
    # with a lit room behind it reads as dark glass with warm curtains by day) and the weight is high
    lit_w = opt.get("pane_lit", (0.55, 0.9))
    lit_col = opt.get("pane_lit_color", "#7a5e3a")
    # the box of every facade object: a wall whose outside lies inside it is an inner face (the back of a gable
    # under the roof) and gets no openings
    fac = [o for o in objs if any(s.material is not None and s.material.name in by_mat for s in o.material_slots)]
    if fac:
        fp = np.concatenate([np.array([tuple(o.matrix_world @ v.co) for v in o.data.vertices]) for o in fac])
        box_lo, box_hi = fp.min(axis=0) + 0.05, fp.max(axis=0) - 0.05
    count = 0
    for ob in objs:
        mats = [s.material for s in ob.material_slots]
        if not any(m is not None and m.name in by_mat for m in mats):
            continue
        if any(abs(float(v)) > 1e-9 for v in ob.location) or any(abs(float(v)) > 1e-9 for v in ob.rotation_euler):
            continue        # facade coordinates are object space: only objects built in root space are cut
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.faces.ensure_lookup_table()
        new_faces = []
        drop = []
        for f in list(bm.faces):
            mat = mats[f.material_index] if f.material_index < len(mats) else None
            if mat is None or mat.name not in by_mat:
                continue
            e = by_mat[mat.name]
            n = np.array(f.normal, dtype=np.float64)
            cls = _face_class(n)
            if cls is None or cls in opt.get("skip_faces", ()):
                continue
            u_ax = np.array([1.0, 0.0, 0.0]) if cls in ("front", "back") else np.array([0.0, 1.0, 0.0])
            vs = [np.array(v.co, dtype=np.float64) for v in f.verts]
            w = float(np.mean([v @ n for v in vs]))
            probe = np.mean(vs, axis=0) + n * 0.3
            if np.all(probe >= box_lo) and np.all(probe <= box_hi):
                continue
            poly = [(float(v @ u_ax), float(v[2])) for v in vs]
            holes = []          # (polygon, kind, grid / decal, grid index)
            for gi, g in enumerate(e["grids"]):
                if cls not in GRID_FACES.get(g.get("face", "front"), ("front", "back")):
                    continue
                for (a, b, c, d) in _grid_windows(g):
                    rect = [(a, c), (b, c), (b, d), (a, d)]
                    if all(_inside_poly((x + (0.04 if x < (a + b) / 2 else -0.04),
                                         y + (0.04 if y < (c + d) / 2 else -0.04)), poly) for (x, y) in rect) and \
                            all(_inside_poly((x, y), poly) for (x, y) in
                                [(a - 0.03, c - 0.03), (b + 0.03, c - 0.03), (b + 0.03, d + 0.03), (a - 0.03, d + 0.03)]):
                        holes.append(([(a, c), (b, c), (b, d), (a, d)], "window", g, gi))
            for d in e["decals"]:
                if not d.get("door") or d.get("face") != cls:
                    continue
                pts = [(float(x), float(y)) for (x, y) in d["poly"]]
                if d.get("sym", True):
                    # a half outline over x >= 0: joined with its mirror image into one outline
                    pts = pts + [(-x, y) for (x, y) in reversed(pts) if x > 1e-6]
                    pts = [p for i, p in enumerate(pts) if i == 0 or abs(p[0] - pts[i - 1][0]) + abs(p[1] - pts[i - 1][1]) > 1e-6]
                if cls in ("back", "left"):
                    pts = [(-x, y) for (x, y) in pts]
                # a door stands on the ground: its foot may reach below the face (the bevel at the foot of the
                # wall stays as a threshold); the cut keeps only what lies inside the face
                zmin = min(p[1] for p in poly)
                pts = [(x, y - 0.02 if y <= zmin + 0.04 else y) for (x, y) in pts]
                cx = float(np.mean([p[0] for p in pts]))
                cz = float(np.mean([p[1] for p in pts]))
                if _inside_poly((cx, cz), poly):
                    holes.append((pts, "door", d, -1))
            if not holes:
                continue
            tris = _cdt_with_holes(poly, [h[0] for h in holes])
            if not tris:
                continue

            def p3(u, z, depth=0.0, _u=u_ax, _n=n, _w=w):
                base = _u * u + np.array([0.0, 0.0, z])
                return base - _n * (base @ _n) + _n * (_w - depth)
            for (a2, b2, c2) in tris:
                new_faces.append((p3(*a2), p3(*b2), p3(*c2), n, f.material_index))
            drop.append(f)
            for (pts, kind, src, gi) in holes:
                count += 1
                depth = reveal_m if kind == "window" else float(opt.get("door_m", 0.1))
                m2 = len(pts)
                cu = float(np.mean([p[0] for p in pts]))
                cz = float(np.mean([p[1] for p in pts]))
                # reveal: from the wall plane inwards, normals into the opening
                for i in range(m2):
                    (ua, za), (ub, zb) = pts[i], pts[(i + 1) % m2]
                    inward = np.array([cu - (ua + ub) / 2, cz - (za + zb) / 2])
                    nn = u_ax * inward[0] + np.array([0.0, 0.0, inward[1]])
                    nn = nn - n * (nn @ n)
                    nn /= max(1e-9, np.linalg.norm(nn))
                    geo.quad(reveal_mat, p3(ua, za), p3(ub, zb), p3(ub, zb, depth), p3(ua, za, depth), nn)
                xs = [p[0] for p in pts]
                zs = [p[1] for p in pts]
                a, b, c, d = min(xs), max(xs), min(zs), max(zs)
                if kind == "door":
                    pts3 = [p3(x, z, depth) for (x, z) in pts]
                    for i in range(1, m2 - 1):
                        geo.tri(door_mat, pts3[0], pts3[i], pts3[i + 1], n)
                    # the gap between the two wings
                    geo.quad(gap_mat, p3(cu - 0.03, c, depth - 0.005), p3(cu + 0.03, c, depth - 0.005),
                             p3(cu + 0.03, d - 0.4, depth - 0.005), p3(cu - 0.03, d - 0.4, depth - 0.005), n)
                    continue
                fcol = src.get("frame", e.get("frame", "#e9e6de"))
                if fcol not in frame_mats:
                    frame_mats[fcol] = _vpbr_mat("ce_frame_%s" % fcol.lstrip("#"), fcol, rough=0.55)
                fm = frame_mats[fcol]
                gcol = src.get("glass", e.get("glass", "#26313b"))
                h = zlib.crc32(("%s|%d|%.2f|%.2f|%.2f" % (ob.name, gi, a, c, w)).encode()) / 2.0 ** 32
                if h < float(src.get("lit", e.get("lit", 0.45))):
                    wgt = lit_w[0] + (lit_w[1] - lit_w[0]) * ((h * 7.31) % 1.0)
                    key = (gcol, round(wgt, 2))
                    if key not in pane_lit:
                        lamp = "-lights:%.2f:%s" % (wgt, lit_col)
                        pane_lit[key] = _vpbr_mat("ce_pane_lit_%s_%02d" % (gcol.lstrip("#"), int(wgt * 100)), lit_col,
                                                  rough=0.12, metal=0.1, lamp=lamp)
                    pm = pane_lit[key]
                else:
                    if gcol not in pane_dark:
                        pane_dark[gcol] = _vpbr_mat("ce_pane_%s" % gcol.lstrip("#"), gcol, rough=0.08, metal=0.25)
                    pm = pane_dark[gcol]
                geo.quad(pm, p3(a, c, depth), p3(b, c, depth), p3(b, d, depth), p3(a, d, depth), n)
                # frame: a border inside the opening and a cross, just in front of the pane
                fd = depth - 0.015
                fw = FRAME_W
                geo.quad(fm, p3(a, c, fd), p3(b, c, fd), p3(b, c + fw, fd), p3(a, c + fw, fd), n)
                geo.quad(fm, p3(a, d - fw, fd), p3(b, d - fw, fd), p3(b, d, fd), p3(a, d, fd), n)
                geo.quad(fm, p3(a, c + fw, fd), p3(a + fw, c + fw, fd), p3(a + fw, d - fw, fd), p3(a, d - fw, fd), n)
                geo.quad(fm, p3(b - fw, c + fw, fd), p3(b, c + fw, fd), p3(b, d - fw, fd), p3(b - fw, d - fw, fd), n)
                um = (a + b) / 2
                if b - a > 0.55:
                    geo.quad(fm, p3(um - fw * 0.4, c + fw, fd), p3(um + fw * 0.4, c + fw, fd),
                             p3(um + fw * 0.4, d - fw, fd), p3(um - fw * 0.4, d - fw, fd), n)
                if d - c > 0.9:
                    zt = c + (d - c) * 0.62
                    geo.quad(fm, p3(a + fw, zt - fw * 0.4, fd), p3(b - fw, zt - fw * 0.4, fd),
                             p3(b - fw, zt + fw * 0.4, fd), p3(a + fw, zt + fw * 0.4, fd), n)
                if c < 0.3:
                    continue        # a shop window down to the ground has no sill
                # sill: a slab under the opening, standing out of the wall
                s0, s1 = a - 0.05, b + 0.05
                top, bot = c, c - 0.06
                geo.quad(sill_mat, p3(s0, top, -SILL_M), p3(s1, top, -SILL_M), p3(s1, top, depth * 0.5),
                         p3(s0, top, depth * 0.5), np.array([0.0, 0.0, 1.0]))
                geo.quad(sill_mat, p3(s0, bot, -SILL_M), p3(s1, bot, -SILL_M), p3(s1, top, -SILL_M),
                         p3(s0, top, -SILL_M), n)
                geo.quad(sill_mat, p3(s0, bot, -SILL_M), p3(s0, bot, 0.0), p3(s0, top, 0.0), p3(s0, top, -SILL_M), -u_ax)
                geo.quad(sill_mat, p3(s1, bot, -SILL_M), p3(s1, bot, 0.0), p3(s1, top, 0.0), p3(s1, top, -SILL_M), u_ax)
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
    return count


def _gutters(rig, objs, opt, geo):
    """Half-round gutters under the longest eaves of every roof object, downpipes at their ends down the wall to
    the ground."""
    gutter = _vpbr_mat("ce_gutter", opt.get("color", "#7d8287"), rough=0.4, metal=0.6)
    walls = [o for o in objs if "wall" in o.name and "roof" not in o.name]
    if walls:
        wp = np.concatenate([np.array([tuple(o.matrix_world @ v.co) for v in o.data.vertices]) for o in walls])
        wlo, whi = wp.min(axis=0), wp.max(axis=0)
    else:
        wlo = whi = None
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
        for (ln, a, b) in eaves:
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
            c0 = a + out * (GUTTER_R * 0.9) - np.array([0.0, 0.0, GUTTER_R * 0.6])
            c1 = b + out * (GUTTER_R * 0.9) - np.array([0.0, 0.0, GUTTER_R * 0.6])
            segs = 5
            prev = None
            for k in range(segs + 1):
                ang = math.pi * k / segs          # 0 .. pi: the lower half of a circle about the gutter axis
                off = out * math.cos(ang) * GUTTER_R - np.array([0.0, 0.0, math.sin(ang) * GUTTER_R])
                cur = (c0 + off, c1 + off)
                if prev is not None:
                    am = ang - math.pi / segs / 2
                    nn = out * math.cos(am) - np.array([0.0, 0.0, math.sin(am)])
                    geo.quad(gutter, prev[0], prev[1], cur[1], cur[0], nn)
                prev = cur
            if wlo is None:
                continue
            # downpipes near both ends: a goose-neck back to the wall, then down to the ground
            for end in (a + d * 0.3, b - d * 0.3):
                top = end + out * (GUTTER_R * 0.9) - np.array([0.0, 0.0, GUTTER_R * 1.6])
                wall_pt = np.array([np.clip(top[0], wlo[0], whi[0]), np.clip(top[1], wlo[1], whi[1]), top[2]])
                wall_pt += out * 0.07
                knee = np.array([wall_pt[0], wall_pt[1], top[2] - 0.35])
                foot = np.array([wall_pt[0], wall_pt[1], 0.05])
                _pipe(geo, gutter, [top, knee, foot], 0.045, 6)
                n_pipes += 1
    return n_pipes


def _pipe(geo, mat, path, r, segs):
    for i in range(len(path) - 1):
        a, b = np.asarray(path[i], dtype=np.float64), np.asarray(path[i + 1], dtype=np.float64)
        d = b - a
        ln = np.linalg.norm(d)
        if ln < 1e-6:
            continue
        d /= ln
        up = np.array([0.0, 0.0, 1.0]) if abs(d[2]) < 0.95 else np.array([1.0, 0.0, 0.0])
        u = np.cross(d, up)
        u /= np.linalg.norm(u)
        v = np.cross(d, u)
        for k in range(segs):
            a0 = 2 * math.pi * k / segs
            a1 = 2 * math.pi * (k + 1) / segs
            n0 = u * math.cos(a0) + v * math.sin(a0)
            n1 = u * math.cos(a1) + v * math.sin(a1)
            geo.quad(mat, a + n0 * r, a + n1 * r, b + n1 * r, b + n0 * r, (n0 + n1) / 2)


def _caps(rig, objs, geo):
    """A cover slab on every chimney (objects named *chim*)."""
    cap = _vpbr_mat("ce_cap", "#6d6862", rough=0.85)
    n = 0
    for ob in objs:
        if "chim" not in ob.name:
            continue
        pts = np.array([tuple(ob.matrix_world @ v.co) for v in ob.data.vertices])
        lo, hi = pts.min(axis=0), pts.max(axis=0)
        geo.box(cap, (lo[0] - 0.06, lo[1] - 0.06, hi[2]), (hi[0] + 0.06, hi[1] + 0.06, hi[2] + 0.08))
        n += 1
    return n


class _SubSoup:
    """A view of a soup restricted to some triangles (one material) for roles.Translator.add_object."""

    def __init__(self, soup, sel):
        self.ob = soup.ob
        self.name = soup.name
        self.mats = soup.mats
        self.pos = soup.pos[sel]
        self.nor = soup.nor[sel]
        self.mi = soup.mi[sel]
        self.n = int(sel.sum())

    def material(self, index):
        return self.mats[index] if 0 <= index < len(self.mats) else None


def build_building(model_id, spec3d):
    """Buildings with real depth (see the section header): baked walls and roofs with ambient occlusion, vpbr
    panes, frames, sills, gutters and lamps."""
    from cesprites import props_buildings as B
    t0 = time.time()
    B.WINDOW_LOG = []
    try:
        rig, info, sspec = _build_source(spec3d)
        log = list(B.WINDOW_LOG)
    finally:
        B.WINDOW_LOG = None
    for e in log:
        for d in e["decals"]:
            # a large decal with a door colour standing on the ground of the front is a door (recessed wings)
            pts = d.get("poly") or []
            if pts and not isinstance(pts[0][0], (list, tuple)) and str(d.get("mat", "")).startswith("#"):
                xs = [p[0] for p in pts]
                ys = [p[1] for p in pts]
                if (max(xs) - min(xs)) * (max(ys) - min(ys)) > 1.5 and min(ys) < 0.05:
                    d["door"] = True
                    d["face"] = d.get("face", "front")
    objs = _objects(rig)
    core.realize(objs)
    geo = _Geo()
    stats = {}
    if spec3d.get("openings", True) is not False:
        stats["openings"] = _openings(rig, objs, log, dict(spec3d.get("openings") or {}), geo)
    if spec3d.get("gutters", True) is not False:
        stats["pipes"] = _gutters(rig, objs, dict(spec3d.get("gutters") or {}), geo)
    stats["caps"] = _caps(rig, objs, geo)
    objs = objs + geo.objects(rig, model_id.split("/")[-1])
    mats = {}
    for ob in objs:
        for s in ob.material_slots:
            if s.material is not None:
                roles.tag(s.material)
                mats[s.material.name] = s.material
    vpbr_names = set()
    for name, m in mats.items():
        role, d = roles.tag(m)
        if m.get("ce_vpbr") or (role == "flat" and roles.lamp_from_emit(d.get("emit")) is not None):
            vpbr_names.add(name)
    bake_objs = [o for o in objs if any(s.material is not None and s.material.name not in vpbr_names
                                        for s in o.material_slots)]
    bake_mats = [mats[k] for k in sorted(mats) if k not in vpbr_names]
    cut_names = {m.name for m in bake_mats if BK.has_cutout(m)}
    size = tuple(spec3d.get("atlas", (1024, 1024)))
    wf = weight_allround if spec3d.get("view") == "allround" else weight_roadside
    baked = BK.bake_atlas(rig, bake_objs, bake_mats, size, weight_fn=wf, ppm_max=spec3d.get("ppm_max", 128.0),
                          cutout=bool(cut_names), ao=spec3d.get("ao"))
    tr = roles.Translator(glass_class=False)
    mb = core.MeshBuilder()
    for soup in core.soups_of(objs, uv_layer=BK.UV_NAME):
        for mi in np.unique(soup.mi):
            mat = soup.material(int(mi))
            sel = soup.mi == mi
            if mat.name in vpbr_names:
                tr.add_object(mb, _SubSoup(soup, sel))
                continue
            uv = soup.uv[sel].copy()
            uv[:, :, 1] = 1.0 - uv[:, :, 1]
            mb.add("baked_cutout" if mat.name in cut_names else "baked", soup.pos[sel], soup.nor[sel], uv=uv)
    pts = mb.points()
    model = _finish_model(model_id, spec3d, sspec, info, pts)
    model.auto_lod = False          # the vpbr surface carries lamp channels (contract A-4)
    model.lods = [Lod("lod0", 100000, [Part("body", "lod0_body", mb.finish(), auto_lod=False)])]
    model.lights = tr.lights(split_x=0.0)
    model.roughness = float(spec3d.get("roughness", 0.9))
    big = max(size) > 1024
    alb_name = "albedo.webp" if big else "albedo.png"
    model.texture_files[alb_name] = BK.encode(baked["albedo"], baked["alpha"], "webp" if big else "png")
    model.textures["albedo"] = alb_name
    # the night light of the walls: what the sprite's window masks emitted is cut out now (the panes are vpbr
    # lamps) - an atlas with only crumbs of light left (under 5 % at its brightest texel) is not shipped
    em = baked["emit"].get("lights")
    if em is not None and float(em.max()) > 0.05:
        model.texture_files["emit.png"] = BK.encode(BK.half(em), None, "png")
        model.textures["emit"] = "emit.png"
    model.stats = dict(build_s=round(time.time() - t0, 2), objects=len(objs), bake=baked["stats"], **stats)
    return model
