"""Shader decals of the traffic cars as real geometry (contract D19): windows, lamps, plates, seams,
handles and cladding of cesprites.vehicles.Car are object-space masks of one procedural material. For the
real-time models they are cut INTO the body mesh of each level of detail - a single layer, no patches
floating above the paint, nothing to z-fight:

  * every decal is a 2-D outline in a projection plane (rear / front: (x, z); side: (y, z); top: (x, y))
    with a face test on the surface normal - exactly what materials.decal_mask evaluates per pixel
  * the body triangles that pass the face test are projected into that plane and triangulated together
    with the outlines (constrained Delaunay, mathutils.geometry.delaunay_2d_cdt); every resulting triangle
    lies inside one body triangle (its 3-D position and normal come from there) and takes the material of
    the top-most outline that contains it - the stacking order of the shader
  * coarse levels (cut=False) only paint whole triangles by their centre

Stacking order of materials.surface: paint, cladding below a height, window seals, glass, then the decals
grouped per material in the order of first appearance.
"""
import math

import numpy as np
from mathutils import Vector
from mathutils import geometry as mgeo

from cesprites import materials as M

AXES = {"rear": np.array([0.0, -1.0, 0.0]), "front": np.array([0.0, 1.0, 0.0]), "top": np.array([0.0, 0.0, 1.0])}
END_DEPTH_M = 0.9          # rear / front decals reach this far into the body from its end
UV_AXES = {"rear": (0, 2), "front": (0, 2), "side": (1, 2), "top": (0, 1)}


# --- 2-D helpers ---------------------------------------------------------------------------------------

def _area2(poly):
    a = 0.0
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        a += x0 * y1 - x1 * y0
    return a


def _ccw(poly):
    return list(poly) if _area2(poly) >= 0 else list(reversed(poly))


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


def inset(poly, d):
    """Inward offset of a polygon (mitre joints; fine for the gently curved outlines of lamps and glass)."""
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


# --- triangle sets ------------------------------------------------------------------------------------------

class Tris:
    """Triangles of one body object: pos (T, 3, 3), nor (T, 3, 3) corner normals, mat (T) material index."""

    def __init__(self, pos, nor, mat=None):
        self.pos = np.asarray(pos, dtype=np.float64).reshape(-1, 3, 3)
        self.nor = np.asarray(nor, dtype=np.float64).reshape(-1, 3, 3)
        self.mat = np.zeros(self.pos.shape[0], dtype=np.int32) if mat is None else np.asarray(mat, dtype=np.int32)

    def face_normals(self):
        n = np.cross(self.pos[:, 1] - self.pos[:, 0], self.pos[:, 2] - self.pos[:, 0])
        return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)

    def split_z(self, z):
        """Splits every triangle that crosses the height z (cladding line)."""
        d = self.pos[:, :, 2] - z
        cross = (d.min(axis=1) < -1e-6) & (d.max(axis=1) > 1e-6)
        if not cross.any():
            return
        keep = ~cross
        new_p, new_n, new_m = [self.pos[keep]], [self.nor[keep]], [self.mat[keep]]
        for t in np.nonzero(cross)[0]:
            p, nn, dd = self.pos[t], self.nor[t], d[t]
            lo, hi = [], []
            for i in range(3):
                j = (i + 1) % 3
                (hi if dd[i] >= 0 else lo).append((p[i], nn[i]))
                if (dd[i] >= 0) != (dd[j] >= 0):
                    k = dd[i] / (dd[i] - dd[j])
                    q = (p[i] + (p[j] - p[i]) * k, nn[i] + (nn[j] - nn[i]) * k)
                    lo.append(q)
                    hi.append(q)
            for poly in (lo, hi):
                for i in range(1, len(poly) - 1):
                    new_p.append(np.array([[poly[0][0], poly[i][0], poly[i + 1][0]]]))
                    new_n.append(np.array([[poly[0][1], poly[i][1], poly[i + 1][1]]]))
                    new_m.append(np.array([self.mat[t]], dtype=np.int32))
        self.pos = np.concatenate(new_p)
        self.nor = np.concatenate(new_n)
        self.mat = np.concatenate(new_m)

    def paint_below(self, z, mat):
        self.split_z(z)
        self.mat[self.pos[:, :, 2].mean(axis=1) < z] = mat

    def apply(self, proj, sign, items, cut=True):
        """Applies the decals of one projection: items = [dict(poly, mat, n_min, y_range, nx_max)] bottom
        to top. cut=True cuts the body along the outlines; cut=False paints whole triangles."""
        if not items:
            return 0
        axis = np.array([float(sign), 0.0, 0.0]) if proj == "side" else AXES[proj]
        ua, va = UV_AXES[proj]
        fn = self.face_normals()
        dot = fn @ axis
        n_lo = min(it["n_min"] for it in items)
        polys = [_ccw([(float(p[0]), float(p[1])) for p in it["poly"]]) for it in items]
        allp = np.array([p for poly in polys for p in poly])
        lo2, hi2 = allp.min(axis=0), allp.max(axis=0)
        uv = self.pos[:, :, [ua, va]]
        cand = (dot >= n_lo) & (uv[:, :, 0].max(axis=1) >= lo2[0]) & (uv[:, :, 0].min(axis=1) <= hi2[0]) & \
            (uv[:, :, 1].max(axis=1) >= lo2[1]) & (uv[:, :, 1].min(axis=1) <= hi2[1])
        if proj in ("rear", "front") and cand.any():
            # only the end of the body that faces the viewer: the walls of the wheel arches face the same
            # way further inside and would lie behind it in this projection
            depth = self.pos.mean(axis=1) @ axis
            cand &= depth >= depth[cand].max() - END_DEPTH_M
        ids = np.nonzero(cand)[0]
        if ids.size == 0:
            return 0

        def top_item(t, cu, cv, cy):
            """Index of the top-most item that covers the point on body triangle t (or -1)."""
            best = -1
            for k, it in enumerate(items):
                if dot[t] < it["n_min"]:
                    continue
                if it.get("nx_max") is not None and abs(fn[t, 0]) >= it["nx_max"]:
                    continue
                yr = it.get("y_range")
                if yr is not None and not (yr[0] <= cy <= yr[1]):
                    continue
                if _inside(cu, cv, polys[k]):
                    best = k
            return best

        if not cut:
            n = 0
            for t in ids:
                c = self.pos[t].mean(axis=0)
                k = top_item(t, c[ua], c[va], c[1])
                if k >= 0:
                    self.mat[t] = items[k]["mat"]
                    n += 1
            return n
        # --- constrained triangulation of the candidate triangles together with the outlines
        index = {}
        verts = []

        def vid(u, v):
            key = (round(u * 1e6), round(v * 1e6))
            i = index.get(key)
            if i is None:
                i = len(verts)
                index[key] = i
                verts.append(Vector((u, v)))
            return i
        faces = []
        body_of = []
        for t in ids:
            tri = [vid(uv[t, i, 0], uv[t, i, 1]) for i in range(3)]
            if len(set(tri)) < 3:
                continue
            a = (verts[tri[1]] - verts[tri[0]]).cross(verts[tri[2]] - verts[tri[0]])
            if abs(a) < 1e-10:
                continue
            faces.append(tri if a > 0 else [tri[0], tri[2], tri[1]])
            body_of.append(int(t))
        nb = len(faces)
        if nb == 0:
            return 0
        for poly in polys:
            faces.append([vid(p[0], p[1]) for p in poly])
        out = mgeo.delaunay_2d_cdt(verts, [], faces, 1, 1e-7, True)
        vco, ofaces, orig = out[0], out[2], out[5]
        new_p, new_n, new_m = [], [], []
        replaced = set()
        # barycentric frames of the body triangles in the projection plane
        for fi, src in zip(ofaces, orig):
            bodies = [s for s in src if s < nb]
            if not bodies or len(fi) != 3:
                continue
            q = np.array([[vco[i][0], vco[i][1]] for i in fi])
            c2 = q.mean(axis=0)
            # several body triangles over each other in this projection: the one nearest to the viewer
            best_t, best_h = -1, -1e30
            pieces = []
            for s in bodies:
                t = body_of[s]
                a0, a1, a2 = uv[t, 0], uv[t, 1], uv[t, 2]
                det = (a1[0] - a0[0]) * (a2[1] - a0[1]) - (a2[0] - a0[0]) * (a1[1] - a0[1])
                if abs(det) < 1e-12:
                    continue
                w1 = ((q[:, 0] - a0[0]) * (a2[1] - a0[1]) - (a2[0] - a0[0]) * (q[:, 1] - a0[1])) / det
                w2 = ((a1[0] - a0[0]) * (q[:, 1] - a0[1]) - (q[:, 0] - a0[0]) * (a1[1] - a0[1])) / det
                w = np.stack([1.0 - w1 - w2, w1, w2], axis=1)
                h = float((w.mean(axis=0) @ self.pos[t]) @ axis)
                pieces.append((t, w))
                if h > best_h:
                    best_t, best_h = t, h
            if best_t < 0:
                continue
            for t, w in pieces:
                p3 = w @ self.pos[t]
                n3 = w @ self.nor[t]
                n3 = n3 / np.maximum(np.linalg.norm(n3, axis=1, keepdims=True), 1e-12)
                # keep the winding of the body triangle
                if np.cross(p3[1] - p3[0], p3[2] - p3[0]) @ fn[t] < 0:
                    p3, n3 = p3[::-1], n3[::-1]
                # only the surface nearest to the viewer takes the decal; what lies behind keeps its own
                k = top_item(t, c2[0], c2[1], float(p3[:, 1].mean())) if t == best_t else -1
                new_p.append(p3)
                new_n.append(n3)
                new_m.append(items[k]["mat"] if k >= 0 else self.mat[t])
                replaced.add(t)
        if not replaced:
            return 0
        keep = np.ones(self.pos.shape[0], dtype=bool)
        keep[list(replaced)] = False
        self.pos = np.concatenate([self.pos[keep], np.array(new_p)])
        self.nor = np.concatenate([self.nor[keep], np.array(new_n)])
        self.mat = np.concatenate([self.mat[keep], np.array(new_m, dtype=np.int32)])
        return len(new_p)


# --- the decals of a Car ---------------------------------------------------------------------------------

class Palette:
    """Materials of the cut body: index -> (role, data, lamp tag) for roles.Translator.add_role."""

    def __init__(self):
        self.items = []
        self._index = {}

    def add(self, key, role, data, lamp=None):
        if key not in self._index:
            self._index[key] = len(self.items)
            self.items.append((role, data, lamp))
        return self._index[key]

    def preset(self, spec, emit=None, lamp=None):
        p = M._preset(spec)
        key = repr(sorted(p.items())) + "|" + repr(lamp) + "|" + repr(sorted((emit or {}).items()))
        data = dict(color=p["color"], rough=p.get("rough", 0.4), metal=p.get("metal", 0.0))
        if emit:
            data["emit"] = {layer: list(M.emit_col(c, s)[:3]) for layer, (c, s) in emit.items()}
        return self.add(key, "flat", data, lamp)


def _decal_items(decals, pal, proj_filter=None):
    """{(proj, sign): [item]} of a decal list in the stacking order of materials.surface (grouped per
    material preset, groups in the order of first appearance)."""
    order = {}
    rows = []
    for d in decals:
        p = M._preset(d.get("mat", "black"))
        key = repr(sorted(p.items()))
        order.setdefault(key, len(order))
        rows.append((order[key], len(rows), d))
    rows.sort(key=lambda r: (r[0], r[1]))
    groups = {}
    for (_g, _i, d) in rows:
        face = d.get("face", "rear")
        proj = face if face in ("rear", "front", "side", "top") else "rear"
        if proj_filter is not None and not proj_filter(proj):
            continue
        thr = d.get("n", 0.35 if proj in ("rear", "front") else (0.5 if proj == "side" else 0.6))
        mat = pal.preset(d.get("mat", "black"), d.get("emit"), d.get("lamp"))
        polys = d["poly"] if isinstance(d["poly"][0][0], (list, tuple)) else [d["poly"]]
        for poly in polys:
            poly = [(float(p[0]), float(p[1])) for p in poly]
            if d.get("inset"):
                poly = inset(poly, d["inset"])
            if proj == "side":
                only = d.get("only")
                if only != "left":
                    groups.setdefault(("side", 1), []).append(dict(poly=poly, mat=mat, n_min=thr))
                if only != "right":
                    groups.setdefault(("side", -1), []).append(dict(poly=poly, mat=mat, n_min=thr))
            else:
                groups.setdefault((proj, 1), []).append(dict(poly=poly, mat=mat, n_min=thr))
                if d.get("sym", True):
                    groups.setdefault((proj, 1), []).append(dict(poly=[(-p[0], p[1]) for p in poly], mat=mat,
                                                                 n_min=thr))
    return groups


def _window_items(w, pal, seal, glass, seals=True):
    """Window seals and glass of materials.window_masks as items {(proj, sign): [item]}.
    seals=False (far level): the panes fill their frames, no seal polygons."""
    groups = {}
    fr = w.get("frame", 0.016)
    nx_side = w.get("side_nx", 0.45)
    if seals:
        for poly in w.get("side_frames", w.get("side", [])):
            for sgn in (1, -1):
                groups.setdefault(("side", sgn), []).append(dict(poly=[tuple(p) for p in poly], mat=seal,
                                                                 n_min=nx_side))
    for poly in w.get("side", []):
        for sgn in (1, -1):
            groups.setdefault(("side", sgn), []).append(dict(
                poly=inset([tuple(p) for p in poly], fr) if seals else [tuple(p) for p in poly], mat=glass,
                n_min=nx_side))
    for key in ("front", "rear"):
        sp = w.get(key)
        if not sp:
            continue
        z0, z1 = sp["z"]

        def hw(z, extra=0.0, sp=sp):
            return sp["wb"] - sp["pillar"] - sp["tumble"] * (z - sp["zb"]) - extra
        n_z = 1                         # the sides of the pane are straight lines in this projection
        zs = [z0 + (z1 - z0) * i / n_z for i in range(n_z + 1)]
        outer = [(hw(z), z) for z in zs] + [(-hw(z), z) for z in reversed(zs)]
        zs2 = [z0 + fr + (z1 - z0 - 2 * fr) * i / n_z for i in range(n_z + 1)]
        inner = [(hw(z, fr), z) for z in zs2] + [(-hw(z, fr), z) for z in reversed(zs2)]
        g = groups.setdefault((key, 1), [])
        if seals:
            g.append(dict(poly=outer, mat=seal, n_min=0.05, y_range=(sp["y"][0], sp["y"][1]), nx_max=nx_side))
            g.append(dict(poly=inner, mat=glass, n_min=0.05, y_range=(sp["y"][0] + fr, sp["y"][1] - fr),
                          nx_max=nx_side))
        else:
            g.append(dict(poly=outer, mat=glass, n_min=0.05, y_range=(sp["y"][0], sp["y"][1]), nx_max=nx_side))
    return groups


def car_surfaces(car, soups, cut=True, level=0):
    """Cuts (or paints) the decals of a built vehicles.Car into its body lofts.
    soups: {object name: core.Soup} of the lower body, greenhouse and bumpers.
    level: 0 = every decal (lod0); 1 = no seams, handles and other small parts (lod1); 2 = only lamps,
    plates and the panes without their seals (lod2).
    Returns (Palette, {object name: Tris}, stats)."""
    d = car.d
    pal = Palette()
    black_bumper = bool(d.get("black_bumpers"))
    paint = pal.add("paint", "paint", dict(slot="paint", rough=0.28, metal=car.metal))
    plastic = pal.add("plastic", "flat", dict(color="#1a1b1d", rough=0.6, metal=0.0))
    bumper_base = pal.add("bumper", "flat", dict(color="#1b1c1e", rough=0.3, metal=0.0)) if black_bumper else paint
    seal = pal.add("seal", "flat", dict(color="#101112", rough=0.5, metal=0.0))
    glass = pal.add("glass", "glass", dict(color="#151c23", rough=0.03, metal=0.0))
    out = {}
    stats = dict(cut_tris=0, painted=0)

    def small_filter(decals):
        if level == 0:
            return decals
        # farther levels: only what is still visible - lamps, plates, big dark areas (level 1)
        keep = []
        for dec in decals:
            polys = dec["poly"] if isinstance(dec["poly"][0][0], (list, tuple)) else [dec["poly"]]
            size = max(max(p[0] for p in polys[0]) - min(p[0] for p in polys[0]),
                       max(p[1] for p in polys[0]) - min(p[1] for p in polys[0]))
            if dec.get("lamp") or dec.get("emit") or (level == 1 and size > 0.2):
                if level == 2 and dec.get("inset"):
                    dec = dict(dec)
                    dec.pop("inset")            # the lamp fills its (dropped) black outline
                keep.append(dec)
        return keep

    def run(tris, groups):
        for (proj, sgn) in sorted(groups, key=lambda g: (g[0], -g[1])):
            n = tris.apply(proj, sgn, groups[(proj, sgn)], cut=cut)
            stats["cut_tris" if cut else "painted"] += n

    # lower body: paint, cladding below a height, decals
    s = soups[car.body.name]
    t = Tris(s.pos, s.nor)
    t.mat[:] = paint
    if d.get("cladding") is not None:
        t.paint_below(d["cladding"], plastic)
    run(t, _decal_items(small_filter(car.body_decals()), pal))
    out[car.body.name] = t
    # greenhouse: paint, window seals and glass, decals
    s = soups[car.cabin.name]
    t = Tris(s.pos, s.nor)
    t.mat[:] = paint
    run(t, _window_items(car.windows(), pal, seal, glass, seals=level < 2))
    run(t, _decal_items(small_filter(car.cabin_decals()), pal))
    out[car.cabin.name] = t
    # bumpers: the rear one takes the rear and side decals, the front one the front and side decals
    for which, ob in sorted(car.bumper_obs.items()):
        s = soups[ob.name]
        t = Tris(s.pos, s.nor)
        t.mat[:] = bumper_base
        t.paint_below(d["bumper"].get("plastic", 0.25), plastic)
        skip = "front" if which == "rear" else "rear"
        run(t, _decal_items(small_filter(car.bumper_decals()), pal, proj_filter=lambda p, skip=skip: p != skip))
        out[ob.name] = t
    return pal, out, stats
