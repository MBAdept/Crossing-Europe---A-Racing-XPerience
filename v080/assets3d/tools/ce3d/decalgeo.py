"""Prototype: turn the object-space shader decals of vehicles.Car (windows, lamps, plates, seams, handles,
cladding, livery bands) into real geometry with flat materials - the way the player cars are built
(conformal patches ray-cast onto the body). No textures needed; every lamp becomes its own surface."""
import math

import bmesh
import bpy
from mathutils import Vector
from mathutils import geometry as mgeo
from mathutils.bvhtree import BVHTree

from cesprites import materials as M
from cesprites import meshutil as MU


def _ccw(poly):
    a = 0.0
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        a += x0 * y1 - x1 * y0
    return list(poly) if a >= 0 else list(reversed(poly))


def _inside(x, y, poly):
    c = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-12) + xi):
            c = not c
        j = i
    return c


def _inset(poly, d):
    poly = _ccw(poly)
    n = len(poly)
    out = []
    for i in range(n):
        p0, p1, p2 = poly[i - 1], poly[i], poly[(i + 1) % n]
        e1 = (p1[0] - p0[0], p1[1] - p0[1])
        e2 = (p2[0] - p1[0], p2[1] - p1[1])
        l1 = math.hypot(*e1) or 1e-9
        l2 = math.hypot(*e2) or 1e-9
        n1 = (-e1[1] / l1, e1[0] / l1)
        n2 = (-e2[1] / l2, e2[0] / l2)
        nx, ny = n1[0] + n2[0], n1[1] + n2[1]
        ln = math.hypot(nx, ny) or 1e-9
        nx, ny = nx / ln, ny / ln
        cosh = max(0.35, nx * n1[0] + ny * n1[1])
        out.append((p1[0] + nx * d / cosh, p1[1] + ny * d / cosh))
    return out


class Host:
    """Ray-cast targets (evaluated meshes) of a traffic car."""

    def __init__(self, car, parent):
        self.car = car
        self.parent = parent
        self._bvh = {}
        self.stats = dict(patches=0, tris=0, dropped=0)

    def bvh(self, ob):
        if ob.name not in self._bvh:
            deps = bpy.context.evaluated_depsgraph_get()
            deps.update()
            ev = ob.evaluated_get(deps)
            me = ev.to_mesh()
            mw = ob.matrix_world.copy()
            verts = [mw @ v.co for v in me.vertices]
            polys = [list(p.vertices) for p in me.polygons]
            ev.to_mesh_clear()
            self._bvh[ob.name] = BVHTree.FromPolygons(verts, polys, all_triangles=False)
        return self._bvh[ob.name]

    def cast(self, ob, proj, u, v, sign=1):
        L = self.car.L
        if proj == "rear":
            o, d = Vector((u, -3.0, v)), Vector((0.0, 1.0, 0.0))
        elif proj == "front":
            o, d = Vector((u, L + 3.0, v)), Vector((0.0, -1.0, 0.0))
        elif proj == "side":
            o, d = Vector((sign * 4.0, u, v)), Vector((-sign, 0.0, 0.0))
        else:
            o, d = Vector((u, v, 6.0)), Vector((0.0, 0.0, -1.0))
        loc, nor, idx, dist = self.bvh(ob).ray_cast(o, d, 50.0)
        if loc is None:
            return None
        if nor.dot(d) > 0:
            nor = -nor
        return loc, nor

    def patch(self, bm, ob, outline, proj, sign, offset, res, n_min, mat_index=0, y_range=None):
        """Triangulates the 2-D outline, ray-casts it onto ob and keeps the triangles whose surface normal
        passes the decal's face test (n_min = minimum |normal . projection axis|)."""
        outline = _ccw(outline)
        bnd = []
        n = len(outline)
        for i in range(n):
            a, b = outline[i], outline[(i + 1) % n]
            seg = math.hypot(b[0] - a[0], b[1] - a[1])
            k = max(1, int(math.ceil(seg / res)))
            for j in range(k):
                t = j / k
                bnd.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
        pts = list(bnd)
        xs = [p[0] for p in bnd]
        ys = [p[1] for p in bnd]
        nb = len(bnd)
        x = min(xs) + res * 0.5
        while x < max(xs):
            y = min(ys) + res * 0.5
            while y < max(ys):
                if _inside(x, y, outline):
                    pts.append((x, y))
                y += res
            x += res
        try:
            out = mgeo.delaunay_2d_cdt([Vector(p) for p in pts], [(i, (i + 1) % nb) for i in range(nb)],
                                       [list(range(nb))], 1, 1e-7)
        except Exception:
            return 0
        vco, faces = out[0], out[2]
        axis = {"rear": Vector((0, -1, 0)), "front": Vector((0, 1, 0)), "side": Vector((sign, 0, 0)),
                "top": Vector((0, 0, 1))}[proj]
        hits = []
        for p in vco:
            h = self.cast(ob, proj, p[0], p[1], sign)
            if h is not None and y_range is not None and not (y_range[0] <= h[0].y <= y_range[1]):
                h = None
            hits.append(h)
        vmap = {}
        made = 0
        for fi in faces:
            if any(hits[i] is None for i in fi):
                continue
            if min(hits[i][1].dot(axis) for i in fi) < n_min:
                self.stats["dropped"] += 1
                continue
            vs = []
            for i in fi:
                if i not in vmap:
                    loc, nor = hits[i]
                    vmap[i] = bm.verts.new(loc + nor * offset)
                vs.append(vmap[i])
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            f.material_index = mat_index
            f.smooth = True
            nrm = hits[fi[0]][1]
            f.normal_update()
            if f.normal.dot(nrm) < 0:
                f.normal_flip()
            made += 1
        self.stats["tris"] += made
        return made


def patch_multi(host, ob, proj, sign, items, offset, res, name, parent):
    """One constrained triangulation for all decals of a projection face: items = [(outline, material,
    n_min, y_range)], later items lie on top (shader order). Every output triangle takes the material of
    the top-most outline containing it -> a single layer without stacked, interpenetrating patches."""
    verts, faces = [], []
    for (outline, _m, _t, _y) in items:
        outline = _ccw(outline)
        xs = [p[0] for p in outline]
        ys = [p[1] for p in outline]
        size = min(max(xs) - min(xs), max(ys) - min(ys))
        r = max(0.004, min(res, size * 0.75))
        idx = []
        n = len(outline)
        for i in range(n):
            a, b = outline[i], outline[(i + 1) % n]
            seg = math.hypot(b[0] - a[0], b[1] - a[1])
            k = max(1, int(math.ceil(seg / r)))
            for j in range(k):
                t = j / k
                idx.append(len(verts))
                verts.append(Vector((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)))
        faces.append(idx)
    # interior grid points (inside any outline)
    allx = [v.x for v in verts]
    ally = [v.y for v in verts]
    outs = [_ccw(it[0]) for it in items]
    x = min(allx) + res * 0.5
    while x < max(allx):
        y = min(ally) + res * 0.5
        while y < max(ally):
            if any(_inside(x, y, o) for o in outs):
                verts.append(Vector((x, y)))
            y += res
        x += res
    try:
        out = mgeo.delaunay_2d_cdt(verts, [], faces, 1, 1e-6)
    except Exception as e:  # noqa
        print("cdt failed", name, e)
        return None
    vco, ofaces, orig_faces = out[0], out[2], out[5]
    axis = {"rear": Vector((0, -1, 0)), "front": Vector((0, 1, 0)), "side": Vector((sign, 0, 0)),
            "top": Vector((0, 0, 1))}[proj]
    hits = [host.cast(ob, proj, p[0], p[1], sign) for p in vco]
    bm = bmesh.new()
    mats = []
    vmap = {}
    for fi, src in zip(ofaces, orig_faces):
        if not src or any(hits[i] is None for i in fi):
            continue
        top = max(src)
        _o, mat, n_min, y_range = items[top]
        if min(hits[i][1].dot(axis) for i in fi) < n_min:
            host.stats["dropped"] += 1
            continue
        if y_range is not None and not all(y_range[0] <= hits[i][0].y <= y_range[1] for i in fi):
            continue
        if mat not in mats:
            mats.append(mat)
        vs = []
        for i in fi:
            if i not in vmap:
                loc, nor = hits[i]
                vmap[i] = bm.verts.new(loc + nor * offset)
            vs.append(vmap[i])
        try:
            f = bm.faces.new(vs)
        except ValueError:
            continue
        f.material_index = mats.index(mat)
        f.smooth = True
        f.normal_update()
        if f.normal.dot(hits[fi[0]][1]) < 0:
            f.normal_flip()
        host.stats["tris"] += len(fi) - 2
    if not len(bm.faces):
        bm.free()
        return None
    host.stats["patches"] += 1
    return MU.make(name, bm, mats, parent=parent, smooth=True, sharp_deg=60)


def _flat(name, preset, emit=None):
    p = M._preset(preset)
    kw = dict(rough=p.get("rough", 0.4), metal=p.get("metal", 0.0), coat=p.get("coat", 0.0), spec=p.get("spec", 0.5))
    return M.basic(name, p["color"], emit=emit, **kw)


def convert(rig, car, offset_scale=1.0, res=0.02, body_dissolve_deg=0.0):
    """Replaces the surface() materials of a built vehicles.Car by plain paint and adds geometry decals.
    body_dissolve_deg > 0: the body lofts are simplified FIRST (planar dissolve), the decals are then cast
    onto the simplified surface, so they can never dip below it. Returns statistics."""
    root = rig.root
    host = Host(car, root)
    d = car.d
    parts = {o.name: o for o in car.parts}
    lower = car.body
    cabin = car.cabin
    bumpers = [o for o in car.parts if "bumper" in o.name]
    if body_dissolve_deg > 0:
        for ob in [lower, cabin] + bumpers:
            m = ob.modifiers.new("planar", "DECIMATE")
            m.decimate_type = "DISSOLVE"
            m.angle_limit = math.radians(body_dissolve_deg)
            m.delimit = {"MATERIAL", "SHARP"}
    targets = [(lower, car.body_decals(), "body"), (cabin, car.cabin_decals(), "cab")]
    for b in bumpers:
        targets.append((b, car.bumper_decals(), b.name.split("_")[-1]))
    mats = {}
    layer_off = [0]

    def mat_for(dec):
        p = M._preset(dec.get("mat", "black"))
        em = dec.get("emit") or None
        key = repr(sorted(p.items())) + repr(sorted((em or {}).items()))
        if key not in mats:
            mats[key] = _flat("%s_dg_%d" % (car.name, len(mats)), p, emit=em)
        return mats[key]

    groups = {}

    def add(ob, proj, sgn, poly, mat, thr, y_range=None):
        groups.setdefault((ob.name, proj, sgn), dict(ob=ob, items=[]))["items"].append((poly, mat, thr, y_range))

    # windows first (the shader applies them before the decals)
    w = car.windows()
    fr = w.get("frame", 0.016)
    seal = _flat(car.name + "_dg_seal", dict(color="#101112", rough=0.5, spec=0.3))
    glass = M.glass_mat(car.name + "_glass", "#151c23")
    nx_min = w.get("side_nx", 0.45)
    for poly in w.get("side_frames", []):
        for sgn in (1, -1):
            add(cabin, "side", sgn, [tuple(p) for p in poly], seal, nx_min)
    for poly in w.get("side", []):
        for sgn in (1, -1):
            add(cabin, "side", sgn, _inset([tuple(p) for p in poly], fr), glass, nx_min)
    for key, proj in (("front", "front"), ("rear", "rear")):
        sp = w.get(key)
        if not sp:
            continue
        z0, z1 = sp["z"]

        def hw(z, extra=0.0, sp=sp):
            return sp["wb"] - sp["pillar"] - sp["tumble"] * (z - sp["zb"]) - extra
        n_z = 8
        zs = [z0 + (z1 - z0) * i / n_z for i in range(n_z + 1)]
        outer = [(hw(z), z) for z in zs] + [(-hw(z), z) for z in reversed(zs)]
        zs2 = [z0 + fr + (z1 - z0 - 2 * fr) * i / n_z for i in range(n_z + 1)]
        inner = [(hw(z, fr), z) for z in zs2] + [(-hw(z, fr), z) for z in reversed(zs2)]
        add(cabin, proj, 1, outer, seal, 0.05, (sp["y"][0], sp["y"][1]))
        add(cabin, proj, 1, inner, glass, 0.05, (sp["y"][0] + fr, sp["y"][1] - fr))
    for ob, decals, tag in targets:
        for di, dec in enumerate(decals):
            face = dec.get("face", "rear")
            proj = face if face in ("rear", "front", "side", "top") else "rear"
            if (proj == "rear" and "fbumper" in ob.name) or (proj == "front" and "rbumper" in ob.name):
                continue
            thr = dec.get("n", 0.35 if proj in ("rear", "front") else (0.5 if proj == "side" else 0.6))
            polys = dec["poly"] if isinstance(dec["poly"][0][0], (list, tuple)) else [dec["poly"]]
            sym = dec.get("sym", True)
            mat = mat_for(dec)
            for poly in polys:
                poly = [tuple(p) for p in poly]
                if dec.get("inset"):
                    poly = _inset(poly, dec["inset"])
                if proj == "side":
                    only = dec.get("only")
                    if only != "left":
                        add(ob, proj, 1, poly, mat, thr)
                    if only != "right":
                        add(ob, proj, -1, poly, mat, thr)
                else:
                    add(ob, proj, 1, poly, mat, thr)
                    if sym:
                        add(ob, proj, 1, [(-p[0], p[1]) for p in poly], mat, thr)
    for (oname, proj, sgn), g in groups.items():
        patch_multi(host, g["ob"], proj, sgn, g["items"], 0.002 * offset_scale, res,
                    "%s_dg_%s_%s%s" % (car.name, oname.split("_")[-1], proj, "r" if sgn > 0 else "l"), root)
    # --- body materials: plain paint; cladding / bumper plastic by a horizontal cut
    paint = M.paint(car.name + "_paint", car.paint, metal=car.metal, rough=0.28, coat=0.8)
    plastic = _flat(car.name + "_dg_plastic", dict(color="#1a1b1d", rough=0.6, spec=0.3))

    def cut(ob, z_cut):
        me = ob.data
        me.materials.clear()            # (clearing resets the face indices -> do it before assigning them)
        me.materials.append(paint)
        me.materials.append(plastic)
        bm = bmesh.new()
        bm.from_mesh(me)
        if z_cut is not None:
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z_cut), plane_no=(0, 0, 1))
            for f in bm.faces:
                f.material_index = 1 if f.calc_center_median().z < z_cut else 0
        else:
            for f in bm.faces:
                f.material_index = 0
        bm.to_mesh(me)
        bm.free()

    cut(lower, d.get("cladding"))
    cut(cabin, None)
    for b in bumpers:
        cut(b, d["bumper"].get("plastic", 0.25))
    # mirrors / spoilers used the body material
    for o in root.children:
        for s in o.material_slots:
            if s.material and s.material.name.endswith(("_body", "_cabin", "_bumper")):
                s.material = paint
    return host.stats
