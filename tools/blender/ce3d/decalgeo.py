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
  * the face test uses the SMOOTH normal, as the shader does: before the cut every triangle is split along
    the line where its interpolated normal crosses the threshold of a decal (Tris.split_level). A decal that
    wraps around a corner so ends along a clean line at every level of detail - with a test per triangle it
    ended along the edges of the mesh (saw teeth of 5 - 10 cm on the coarse levels)
  * cut=False only paints whole triangles by their centre (not used by the vehicles any more)

Stacking order of materials.surface: paint, cladding below a height, window seals, glass, then the decals
grouped per material in the order of first appearance. The order holds ACROSS the projections: every item
carries the rank of its material group, every triangle the rank of what it shows, and an item only replaces
what ranks at most as high. (The projections are applied one after the other - without the ranks the side
part of a tail lamp, applied last, painted over an indicator the rear projection had put on the corner.)
"""
import math
import os

import numpy as np
from mathutils import Vector
from mathutils import geometry as mgeo

from cesprites import materials as M

AXES = {"rear": np.array([0.0, -1.0, 0.0]), "front": np.array([0.0, 1.0, 0.0]), "top": np.array([0.0, 0.0, 1.0])}
# ranks of the stacking order: paint / cladding, window seals, glass, then the decal groups 0, 1, 2 ...
BASE_RANK, SEAL_RANK, GLASS_RANK = -3, -2, -1
END_DEPTH_M = 0.9          # rear / front decals reach this far into the body from its end
FACING_MIN = 0.08          # a face takes decals of a projection only if its own normal looks that way (cosine)
SLIVER_2D = 1.0e-4         # candidate triangles lower than this (m, in the projection plane) are left alone
UV_AXES = {"rear": (0, 2), "front": (0, 2), "side": (1, 2), "top": (0, 1)}


# --- 2-D helpers ---------------------------------------------------------------------------------------

def _area3(pos):
    """Total area of (T, 3, 3) triangles."""
    return float(0.5 * np.linalg.norm(np.cross(pos[:, 1] - pos[:, 0], pos[:, 2] - pos[:, 0]), axis=1).sum())


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
        # rank of what each triangle shows in the stacking order (BASE_RANK = paint, cladding)
        self.rank = np.full(self.pos.shape[0], BASE_RANK, dtype=np.int32)

    def face_normals(self):
        n = np.cross(self.pos[:, 1] - self.pos[:, 0], self.pos[:, 2] - self.pos[:, 0])
        return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)

    def split_z(self, z, where=None):
        """Splits every triangle that crosses the height z (cladding line). where: (T) bool - only these."""
        d = self.pos[:, :, 2] - z
        cross = (d.min(axis=1) < -1e-6) & (d.max(axis=1) > 1e-6)
        if where is not None:
            cross &= where
        if not cross.any():
            return
        keep = ~cross
        new_p, new_n, new_m, new_r = [self.pos[keep]], [self.nor[keep]], [self.mat[keep]], [self.rank[keep]]
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
                    new_r.append(np.array([self.rank[t]], dtype=np.int32))
        self.pos = np.concatenate(new_p)
        self.nor = np.concatenate(new_n)
        self.mat = np.concatenate(new_m)
        self.rank = np.concatenate(new_r)

    def split_level(self, axis, thr, where=None):
        """Splits every triangle that the level thr of (corner normal . axis) crosses. The field is linear
        inside a triangle (normals of new corners are interpolated, not normalised), so afterwards every
        triangle lies on one side of the line: a face test on the mean of the corner values is exact, and the
        line is continuous across the edges of smooth faces. where: (T) bool - only these triangles."""
        f = self.nor @ np.asarray(axis, dtype=np.float64)
        d = f - thr
        cross = (d.min(axis=1) < -1e-4) & (d.max(axis=1) > 1e-4)
        if where is not None:
            cross &= where
        if not cross.any():
            return 0
        keep = ~cross
        new_p, new_n, new_m, new_r = [self.pos[keep]], [self.nor[keep]], [self.mat[keep]], [self.rank[keep]]
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
                    new_r.append(np.array([self.rank[t]], dtype=np.int32))
        self.pos = np.concatenate(new_p)
        self.nor = np.concatenate(new_n)
        self.mat = np.concatenate(new_m)
        self.rank = np.concatenate(new_r)
        return int(cross.sum())

    def normalize(self):
        """Unit corner normals (the splits interpolate without normalising)."""
        self.nor = self.nor / np.maximum(np.linalg.norm(self.nor, axis=2, keepdims=True), 1e-12)

    def paint_below(self, z, mat):
        self.split_z(z)
        self.mat[self.pos[:, :, 2].mean(axis=1) < z] = mat

    def apply(self, proj, sign, items, cut=True):
        """Applies the decals of one projection: items = [dict(poly, mat, rank, n_min, y_range, nx_max)]
        bottom to top (ranks ascending). cut=True cuts the body along the outlines; cut=False paints whole
        triangles. An item never replaces what ranks higher (applied by an earlier projection)."""
        if not items:
            return 0
        axis = np.array([float(sign), 0.0, 0.0]) if proj == "side" else AXES[proj]
        ua, va = UV_AXES[proj]
        polys = [_ccw([(float(p[0]), float(p[1])) for p in it["poly"]]) for it in items]

        def facing():
            """Triangles that really look towards the viewer (not edge-on in this projection)."""
            return self.face_normals() @ axis > FACING_MIN

        def under(sel):
            """Triangles under the outline of one of the items sel (each item's own bounding box in the
            projection plane - the box around ALL of them would be the whole flank for a tail and a head lamp)."""
            u = self.pos[:, :, [ua, va]]
            u0, u1 = u[:, :, 0].min(axis=1), u[:, :, 0].max(axis=1)
            v0, v1 = u[:, :, 1].min(axis=1), u[:, :, 1].max(axis=1)
            hit = np.zeros(self.pos.shape[0], dtype=bool)
            for k in sel:
                pts = np.array(polys[k])
                lo, hi = pts.min(axis=0), pts.max(axis=0)
                hit |= (u1 >= lo[0]) & (u0 <= hi[0]) & (v1 >= lo[1]) & (v0 <= hi[1])
            return hit
        if cut:
            # every triangle under a decal on one side of its face test (see split_level)
            for thr in sorted({float(it["n_min"]) for it in items}):
                sel = [k for k, it in enumerate(items) if float(it["n_min"]) == thr]
                self.split_level(axis, thr, facing() & under(sel))
            for thr in sorted({float(it["nx_max"]) for it in items if it.get("nx_max") is not None}):
                sel = [k for k, it in enumerate(items) if it.get("nx_max") is not None and float(it["nx_max"]) == thr]
                for sg in (1.0, -1.0):
                    self.split_level((1.0, 0.0, 0.0), sg * thr, facing() & under(sel))
        fn = self.face_normals()
        # the face tests look at the smooth normal (mean of the corners); for flat faces that is the face normal
        # (not normalised: the mean of the corner values is the linear field the splits were made along)
        sn = self.nor.mean(axis=1)
        dot = sn @ axis
        n_lo = min(it["n_min"] for it in items)
        uv = self.pos[:, :, [ua, va]]
        cand = (dot >= n_lo) & (fn @ axis > FACING_MIN) & under(range(len(items)))
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
                if it.get("nx_max") is not None and abs(sn[t, 0]) >= it["nx_max"]:
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
                if k >= 0 and items[k]["rank"] >= self.rank[t]:
                    self.mat[t] = items[k]["mat"]
                    self.rank[t] = items[k]["rank"]
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
            longest = max((verts[tri[1]] - verts[tri[0]]).length, (verts[tri[2]] - verts[tri[1]]).length,
                          (verts[tri[0]] - verts[tri[2]]).length)
            if abs(a) < SLIVER_2D * longest:
                # slivers of earlier cuts keep what they show. (As input faces they also break the
                # triangulation's bookkeeping: a face that is a line in this plane was reported as a source of
                # EVERY output face, and the decal went to it instead of the real triangle - a comb of paint
                # triangles along the top of the side glass.)
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
        new_p, new_n, new_m, new_r, new_t = [], [], [], [], []
        covered = {}
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
                # the piece must lie inside this body triangle (do not trust the bookkeeping blindly)
                wc = w.mean(axis=0)
                if wc.min() < -0.02 or wc.max() > 1.02:
                    continue
                w = np.clip(w, 0.0, 1.0)
                w = w / np.maximum(w.sum(axis=1, keepdims=True), 1e-12)
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
                if k >= 0 and items[k]["rank"] < self.rank[t]:
                    k = -1                  # what is there ranks higher in the stacking order
                new_p.append(p3)
                new_n.append(n3)
                # an item without a material (mat None) only takes the place: what is there stays as it is
                new_m.append(items[k]["mat"] if k >= 0 and items[k]["mat"] is not None else self.mat[t])
                new_r.append(items[k]["rank"] if k >= 0 else self.rank[t])
                new_t.append(t)
                covered[t] = covered.get(t, 0.0) + abs(float((q[1, 0] - q[0, 0]) * (q[2, 1] - q[0, 1]) -
                                                              (q[2, 0] - q[0, 0]) * (q[1, 1] - q[0, 1])))
        if not new_t:
            return 0
        # a body triangle is only replaced by pieces that cover it: one that is nearly a line in this plane can
        # lose pieces to the tolerances (a hole in the body under a lamp) - it stays as it was
        whole = {}
        for t in covered:
            a0, a1, a2 = uv[t, 0], uv[t, 1], uv[t, 2]
            full = abs(float((a1[0] - a0[0]) * (a2[1] - a0[1]) - (a2[0] - a0[0]) * (a1[1] - a0[1])))
            whole[t] = covered[t] >= 0.985 * full
        ok = np.array([whole[t] for t in new_t], dtype=bool)
        replaced = [t for t in whole if whole[t]]
        if not replaced:
            return 0
        keep = np.ones(self.pos.shape[0], dtype=bool)
        keep[replaced] = False
        self.pos = np.concatenate([self.pos[keep], np.array(new_p)[ok]])
        self.nor = np.concatenate([self.nor[keep], np.array(new_n)[ok]])
        self.mat = np.concatenate([self.mat[keep], np.array(new_m, dtype=np.int32)[ok]])
        self.rank = np.concatenate([self.rank[keep], np.array(new_r, dtype=np.int32)[ok]])
        return int(ok.sum())


HOLE = -1                  # material index of what cut_holes removes


def cut_holes(pos, nor, mat, proj, sign, holes, keeps=(), n_min=0.05):
    """Openings in a triangle set (glazing of the player cars, the deck under the greenhouse): everything
    inside a hole outline and not inside a keep outline is removed, triangles are split along the outlines.
    pos, nor (T, 3, 3), mat (T) of the faces; outlines are 2-D polygons in the plane of the projection
    ("rear" / "front": (x, z); "side": (y, z), sign = which flank; "top": (x, y)). Only faces that look against
    the projection (normal . axis >= n_min) are cut - the far side of the object stays whole.
    Returns (pos, nor, mat, number of removed triangles)."""
    t = Tris(pos, nor, mat)
    items = [dict(poly=[(float(p[0]), float(p[1])) for p in h], mat=HOLE, rank=0, n_min=n_min) for h in holes]
    items += [dict(poly=[(float(p[0]), float(p[1])) for p in k], mat=None, rank=1, n_min=n_min) for k in keeps]
    t.apply(proj, sign, items, cut=True)
    t.normalize()
    keep = t.mat != HOLE
    return t.pos[keep], t.nor[keep], t.mat[keep], int((~keep).sum())


def pocket(pos, nor, mat, proj, sign, outline, depth, floor_mat, wall_mat, n_min=0.2):
    """A recess in a triangle set (lamp units of the player cars): the faces inside the outline that look
    against the projection are moved by depth along the projection axis into the body, walls close the step.
    pos, nor (T, 3, 3), mat (T). Returns (pos, nor, mat, stats) - stats: floor and wall triangles, the floor area
    (m2) and the mean depth of the floor along the viewing axis (which of several objects under one outline is in
    front)."""
    axis = np.array([float(sign), 0.0, 0.0]) if proj == "side" else AXES[proj]
    t = Tris(pos, nor, mat)
    mark = -7
    t.apply(proj, sign, [dict(poly=[(float(p[0]), float(p[1])) for p in outline], mat=mark, rank=0, n_min=n_min)],
            cut=True)
    sel = t.mat == mark
    nf = int(sel.sum())
    if nf == 0:
        return pos, nor, np.asarray(mat, dtype=np.int32), dict(floor=0, walls=0, front=-1e30, area=0.0)
    fp = t.pos[sel]
    front = float((fp.mean(axis=1) @ axis).mean())
    # boundary edges of the recessed region (in the winding of their triangle)
    key = np.round(fp * 2e5).astype(np.int64)
    count = {}
    for ti in range(nf):
        for i in range(3):
            a, b = tuple(key[ti, i]), tuple(key[ti, (i + 1) % 3])
            e = (a, b) if a < b else (b, a)
            count.setdefault(e, []).append((ti, i))
    shift = -axis * float(depth)
    wp, wn = [], []
    for e, uses in count.items():
        if len(uses) != 1:
            continue
        ti, i = uses[0]
        a, b = fp[ti, i], fp[ti, (i + 1) % 3]
        n = np.cross(axis, b - a)
        ln = np.linalg.norm(n)
        if ln < 1e-12:
            continue
        n = n / ln
        wp.append([a, b, b + shift])
        wp.append([a, b + shift, a + shift])
        wn += [[n, n, n], [n, n, n]]
    keep = ~sel
    out_p = [t.pos[keep], fp + shift]
    out_n = [t.nor[keep], t.nor[sel]]
    out_m = [t.mat[keep], np.full(nf, floor_mat, dtype=np.int32)]
    if wp:
        out_p.append(np.array(wp))
        out_n.append(np.array(wn))
        out_m.append(np.full(len(wp), wall_mat, dtype=np.int32))
    nn = np.concatenate(out_n)
    nn = nn / np.maximum(np.linalg.norm(nn, axis=2, keepdims=True), 1e-12)
    return np.concatenate(out_p), nn, np.concatenate(out_m), dict(floor=nf, walls=len(wp), front=front,
                                                                     area=_area3(fp))


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


def _decal_items(decals, pal, proj_filter=None, order_from=None):
    """{(proj, sign): [item]} of a decal list in the stacking order of materials.surface (grouped per
    material preset, groups in the order of first appearance; item["rank"] = index of the group).
    order_from: the full list the decals were selected from - the groups keep the order they have there (a far
    level that drops the rings of the tail lamps must not get the ring of the headlight on top of its lamp)."""
    order = {}
    for d in (order_from or []):
        order.setdefault(repr(sorted(M._preset(d.get("mat", "black")).items())), len(order))
    rows = []
    for d in decals:
        p = M._preset(d.get("mat", "black"))
        key = repr(sorted(p.items()))
        order.setdefault(key, len(order))
        # indicators are on top of whatever lamp they lie in, in every selection of the list (their group came
        # first when a level dropped the reverse light that shares its material with the headlights)
        top = 1000 if str(d.get("lamp", "")).split(":")[0] == "ind" else 0
        rows.append((order[key] + top, len(rows), d))
    rows.sort(key=lambda r: (r[0], r[1]))
    groups = {}
    for (rank, _i, d) in rows:
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
                    groups.setdefault(("side", 1), []).append(dict(poly=poly, mat=mat, n_min=thr, rank=rank))
                if only != "right":
                    groups.setdefault(("side", -1), []).append(dict(poly=poly, mat=mat, n_min=thr, rank=rank))
            else:
                groups.setdefault((proj, 1), []).append(dict(poly=poly, mat=mat, n_min=thr, rank=rank))
                if d.get("sym", True):
                    groups.setdefault((proj, 1), []).append(dict(poly=[(-p[0], p[1]) for p in poly], mat=mat,
                                                                 n_min=thr, rank=rank))
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
                                                                 n_min=nx_side, rank=SEAL_RANK))
    for poly in w.get("side", []):
        for sgn in (1, -1):
            groups.setdefault(("side", sgn), []).append(dict(
                poly=inset([tuple(p) for p in poly], fr) if seals else [tuple(p) for p in poly], mat=glass,
                n_min=nx_side, rank=GLASS_RANK))
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
            g.append(dict(poly=outer, mat=seal, n_min=0.05, y_range=(sp["y"][0], sp["y"][1]), nx_max=nx_side,
                          rank=SEAL_RANK))
            g.append(dict(poly=inner, mat=glass, n_min=0.05, y_range=(sp["y"][0] + fr, sp["y"][1] - fr),
                          nx_max=nx_side, rank=GLASS_RANK))
        else:
            g.append(dict(poly=outer, mat=glass, n_min=0.05, y_range=(sp["y"][0], sp["y"][1]), nx_max=nx_side,
                          rank=GLASS_RANK))
    return groups


def car_surfaces(car, soups, cut=True, level=0, paint_rough=0.28, seals=True, far_glass=False, far_plate=None,
                 glass_look=None, far_sill=False):
    """Cuts (or paints) the decals of a vehicles.Car into body lofts.
    car: the Car whose decal lists are used; car.body / car.cabin / car.bumper_obs name the lofts (those of the
    Car itself, or the SmoothCar lofts of ce3d.traffic3d). Without bumper objects (far levels whose body runs
    to the full length) the body takes the bumper's decals. d["<list>_3d"]: decals only the 3D builds have.
    soups: {object name: core.Soup} of the lower body, greenhouse and bumpers.
    level: 0 = every decal (lod0); 1 = no seams, handles and other small parts (lod1); 2 = only lamps,
    plates and the panes without their seals (lod2).
    seals=False: the panes fill their frames at every level (dark glass next to a dark seal is one more outline
    for nothing). far_glass: at level 2 the panes are not cut - every face of the greenhouse that is not roof
    becomes glass (a 16-point greenhouse has its edges where the panes end), and of the lamps only what is seen
    from straight behind / ahead is cut (no side wraps, no reverse and daytime lights).
    far_plate: colour (hex) of the number plates at levels 1 and 2 - the mean of the plate with its characters
    (which the coarse levels drop: a white plate jumped brighter at the swap), and the plate stays at level 2.
    None: the plates keep their colour and level 2 drops them.
    glass_look: dict(color, rough, metal) of the panes instead of the default dark glass.
    far_sill: at level 2 (far_glass) the rear end below the plastic line of the bumper is dark plastic, as the
    bumper of the nearer levels.
    Returns (Palette, {object name: Tris}, stats)."""
    d = car.d
    pal = Palette()
    black_bumper = bool(d.get("black_bumpers"))
    paint = pal.add("paint", "paint", dict(slot="paint", rough=paint_rough, metal=car.metal))
    plastic = pal.add("plastic", "flat", dict(color="#1a1b1d", rough=0.6, metal=0.0))
    bumper_base = pal.add("bumper", "flat", dict(color="#1b1c1e", rough=0.3, metal=0.0)) if black_bumper else paint
    seal = pal.add("seal", "flat", dict(color="#101112", rough=0.5, metal=0.0))
    glass = pal.add("glass", "glass", dict(glass_look or dict(color="#151c23", rough=0.03, metal=0.0)))
    out = {}
    stats = dict(cut_tris=0, painted=0)

    def small_filter(decals):
        if level == 0:
            return decals
        # farther levels: only what is still visible - lamps, plates, big dark areas (level 1)
        keep = []
        for dec in decals:
            polys = dec["poly"] if isinstance(dec["poly"][0][0], (list, tuple)) else [dec["poly"]]
            ext = (max(p[0] for p in polys[0]) - min(p[0] for p in polys[0]),
                   max(p[1] for p in polys[0]) - min(p[1] for p in polys[0]))
            size = max(ext)
            front1 = level == 1 and dec.get("face") == "front"     # headlights keep ring and size at the middle level
            if far_glass and not (dec.get("lamp") or dec.get("emit")) and dec.get("mat") == "gloss_black" and \
                    min(ext) > 0.05 and level >= 1 and not front1:
                continue                # the black ring around a lamp: the lamp fills it at the far levels
            if dec.get("lamp") or dec.get("emit") or (level == 1 and size > 0.2 and (min(ext) > 0.05 or not far_glass)):
                lamp = str(dec.get("lamp", "")).split(":")[0]
                if far_plate and lamp == "plate":
                    dec = dict(dec, mat=dict(color=far_plate, rough=0.45, spec=0.4))
                elif level == 2 and far_glass and (dec.get("face", "rear") == "side" or lamp in ("reverse", "drl", "plate")
                                                   or lamp.startswith("-")):
                    continue                # (a plate is 3 x 0.6 px at 120 m and costs 100 triangles on the end cap;
                    #                          "-": a lamp without a light anchor - the bumper reflectors of the SUV)
                if (level == 2 or (level == 1 and far_glass and not front1)) and dec.get("inset"):
                    dec = dict(dec)
                    dec.pop("inset")            # the lamp fills its (dropped) black outline
                keep.append(dec)
        return keep

    def run(tris, groups):
        for (proj, sgn) in sorted(groups, key=lambda g: (g[0], -g[1])):
            before = tris.pos.shape[0]
            area0 = _area3(tris.pos)
            n = tris.apply(proj, sgn, groups[(proj, sgn)], cut=cut)
            stats["cut_tris" if cut else "painted"] += n
            lost = area0 - _area3(tris.pos)
            if abs(lost) > 1.0e-4:
                # the cut must only re-divide the surface: a lost piece is a hole in the body
                raise RuntimeError("decal cut %s %+d changed the surface by %.1f cm2" % (proj, sgn, lost * 1e4))
            if os.environ.get("CE_STATS"):
                print("      decals %-5s %+d: %2d outlines, %5d -> %5d triangles" % (proj, sgn, len(groups[(proj, sgn)]),
                                                                                 before, tris.pos.shape[0]))

    # lower body: paint, cladding below a height, decals
    s = soups[car.body.name]
    t = Tris(s.pos, s.nor)
    t.mat[:] = paint
    if d.get("cladding") is not None and not (level == 2 and far_glass):
        t.paint_below(d["cladding"], plastic)       # (not at the far level: the cut along the sill costs 180 triangles)
    elif level == 2 and far_glass and far_sill and d.get("cladding") is not None:
        # the far level has no bumpers: the dark lower part of the rear bumper on its rear end only (what the
        # following driver sees; along the flanks the cut would cost 180 triangles) - the bottom row of the car
        # turned from dark plastic to paint at the 120 m swap
        z_pl = d["bumper"].get("plastic", 0.25)
        rear = t.face_normals()[:, 1] < -0.5
        t.split_z(z_pl, where=rear)
        rear = t.face_normals()[:, 1] < -0.5
        t.mat[rear & (t.pos[:, :, 2].mean(axis=1) < z_pl)] = plastic
    full = car.body_decals() + d.get("body_decals_3d", [])
    run(t, _decal_items(small_filter(full), pal, order_from=full))
    if not car.bumper_obs:
        full = car.bumper_decals() + d.get("bumper_decals_3d", [])
        run(t, _decal_items(small_filter(full), pal, order_from=full))
    out[car.body.name] = t
    # greenhouse: paint, window seals and glass, decals
    s = soups[car.cabin.name]
    t = Tris(s.pos, s.nor)
    t.mat[:] = paint
    if level == 2 and far_glass:
        fn = t.face_normals()
        belt = min(p[1] for poly in car.windows().get("side", []) for p in poly) if car.windows().get("side") else 0.0
        # d["far_pane_ny"]: how far a face must look along the car to be a front or rear pane. The fastback glass
        # of the traffic sports car lies at 17 degrees, on the default threshold: in each of its two quads one
        # triangle stayed paint - a diagonal half pane (43 % of the car's pixels changed at the 120 m swap)
        ny = float(d.get("far_pane_ny", 0.3))
        pane = ((np.abs(fn[:, 0]) > 0.6) | ((fn[:, 2] < 0.97) & (np.abs(fn[:, 1]) > ny))) & \
            (t.pos[:, :, 2].mean(axis=1) > belt + 0.02) & (fn[:, 2] > -0.3)
        t.mat[pane] = glass
        t.rank[pane] = GLASS_RANK
    else:
        run(t, _window_items(car.windows(), pal, seal, glass, seals=seals and level < 2))
    run(t, _decal_items(small_filter(car.cabin_decals()), pal, order_from=car.cabin_decals()))
    out[car.cabin.name] = t
    # bumpers: the rear one takes the rear and side decals, the front one the front and side decals
    for which, ob in sorted(car.bumper_obs.items()):
        s = soups[ob.name]
        t = Tris(s.pos, s.nor)
        t.mat[:] = bumper_base
        t.paint_below(d["bumper"].get("plastic", 0.25), plastic)
        skip = "front" if which == "rear" else "rear"
        full = car.bumper_decals() + d.get("bumper_decals_3d", [])
        run(t, _decal_items(small_filter(full), pal, proj_filter=lambda p, skip=skip: p != skip, order_from=full))
        out[ob.name] = t
    for t in out.values():
        t.normalize()
    return pal, out, stats
