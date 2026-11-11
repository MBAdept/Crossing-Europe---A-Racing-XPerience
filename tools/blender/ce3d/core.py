"""Realised geometry of generator models: triangle soups in root space, welding, colour helpers.

Blender space of the generators: x right, y forward (along the road), z up, metres.
Model space of the exported meshes (glTF / Godot): X = x, Y = z (up), Z = -y  ->  the nose of a vehicle
and the far side of a prop point to -Z (to_model_axes is a pure rotation: windings stay as they are).
"""
import numpy as np

CLASS_ORDER = ("vpbr", "glass", "baked", "baked_cutout", "leaves")


# --- colours ---------------------------------------------------------------------------------------

def lin_to_srgb(c):
    c = np.clip(np.asarray(c, dtype=np.float64), 0.0, None)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.maximum(c, 1e-12), 1 / 2.4) - 0.055)


def srgb_to_lin(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, np.power((np.maximum(c, 0.0) + 0.055) / 1.055, 2.4))


def srgb8(lin_rgb):
    """Linear rgb (0..1) -> sRGB bytes."""
    return np.clip(np.round(lin_to_srgb(np.asarray(lin_rgb, dtype=np.float64)[:3]) * 255.0), 0, 255).astype(np.uint8)


def hex_to_lin(h):
    h = h.lstrip("#")
    return srgb_to_lin(np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]))


def lin_to_hex(lin_rgb):
    b = srgb8(lin_rgb)
    return "#%02x%02x%02x" % (int(b[0]), int(b[1]), int(b[2]))


# --- axes ------------------------------------------------------------------------------------------

def to_model_axes(a):
    """(x, y, z) Blender -> (x, z, -y) model space; works on (..., 3) arrays."""
    a = np.asarray(a)
    out = np.empty_like(a)
    out[..., 0] = a[..., 0]
    out[..., 1] = a[..., 2]
    out[..., 2] = -a[..., 1]
    return out


def model_point(p):
    """One Blender point -> rounded model-space list (manifest positions, 0.1 mm)."""
    return [round(float(p[0]), 4) + 0.0, round(float(p[2]), 4) + 0.0, round(-float(p[1]), 4) + 0.0]


# --- soups -----------------------------------------------------------------------------------------

class Soup:
    """Triangles of one evaluated object in root (world) space, per corner:
    pos (T, 3, 3), nor (T, 3, 3), mi (T) material index, uv (T, 3, 2) of a UV layer or None."""

    def __init__(self, ob, deps, uv_layer=None):
        ev = ob.evaluated_get(deps)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        nt = len(me.loop_triangles)
        self.ob = ob
        self.name = ob.name
        self.mats = [s.material for s in ob.material_slots]
        self.n = nt
        self.uv = None
        if nt == 0:
            self.pos = np.zeros((0, 3, 3))
            self.nor = np.zeros((0, 3, 3))
            self.mi = np.zeros(0, dtype=np.int32)
            ev.to_mesh_clear()
            return
        nv = len(me.vertices)
        nl = len(me.loops)
        co = np.empty(nv * 3, dtype=np.float32)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3).astype(np.float64)
        lv = np.empty(nl, dtype=np.int32)
        me.loops.foreach_get("vertex_index", lv)
        cn = np.empty(nl * 3, dtype=np.float32)
        me.corner_normals.foreach_get("vector", cn)
        cn = cn.reshape(-1, 3).astype(np.float64)
        tl = np.empty(nt * 3, dtype=np.int32)
        me.loop_triangles.foreach_get("loops", tl)
        mi = np.empty(nt, dtype=np.int32)
        me.loop_triangles.foreach_get("material_index", mi)
        mw = np.array(ob.matrix_world, dtype=np.float64)
        m3 = mw[:3, :3]
        pos = co[lv[tl]] @ m3.T + mw[:3, 3]
        nor = cn[tl] @ np.linalg.inv(m3)          # normals transform with the inverse transpose
        nor = nor / np.maximum(np.linalg.norm(nor, axis=1, keepdims=True), 1e-12)
        self.pos = pos.reshape(nt, 3, 3)
        self.nor = nor.reshape(nt, 3, 3)
        self.mi = mi
        flip = np.linalg.det(m3) < 0              # mirrored object (scale -1): restore the winding
        if uv_layer and uv_layer in me.uv_layers:
            uv = np.empty(nl * 2, dtype=np.float32)
            me.uv_layers[uv_layer].data.foreach_get("uv", uv)
            self.uv = uv.reshape(-1, 2)[tl].reshape(nt, 3, 2).astype(np.float64)
        if flip:
            self.pos = self.pos[:, ::-1, :].copy()
            self.nor = self.nor[:, ::-1, :].copy()
            if self.uv is not None:
                self.uv = self.uv[:, ::-1, :].copy()
        ev.to_mesh_clear()

    def material(self, index):
        return self.mats[index] if 0 <= index < len(self.mats) else None


def soups_of(objs, uv_layer=None):
    import bpy
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    out = [Soup(ob, deps, uv_layer) for ob in objs]
    return [s for s in out if s.n > 0]


def model_objects(rig):
    """Mesh objects of the model on the rig root (straight, no shadow catchers), sorted by name."""
    import bpy
    rig.root.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    obs = [o for o in rig.root.children_recursive if o.type == "MESH" and o not in rig.catchers]
    return sorted(obs, key=lambda o: o.name)


def realize(objs):
    """Applies the modifiers of the objects in place (the evaluated mesh replaces the mesh data). Object
    transforms stay, so object-space shader coordinates remain valid for the bakes."""
    import bpy
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    new = []
    for ob in objs:
        if ob.modifiers:
            me = bpy.data.meshes.new_from_object(ob.evaluated_get(deps), preserve_all_data_layers=True, depsgraph=deps)
            new.append((ob, me))
    for ob, me in new:
        ob.modifiers.clear()
        ob.data = me
    bpy.context.view_layer.update()


# --- mesh building -----------------------------------------------------------------------------------

class MeshBuilder:
    """Collects per-corner triangle data per material class (Blender space) and welds it into indexed
    surfaces in model space."""

    def __init__(self):
        self.chunks = {}

    def add(self, cls, pos, nor, col=None, uv=None, uv2=None):
        """pos, nor: (T, 3, 3); col: (T, 3, 4) uint8 or a single (4,) value; uv, uv2: (T, 3, 2) or a
        single (2,) value for all corners."""
        pos = np.asarray(pos, dtype=np.float64).reshape(-1, 3, 3)
        t = pos.shape[0]
        if t == 0:
            return
        nor = np.asarray(nor, dtype=np.float64).reshape(-1, 3, 3)

        def full(v, k, dtype):
            if v is None:
                return None
            a = np.asarray(v, dtype=dtype)
            if a.ndim == 1:
                a = np.broadcast_to(a, (t, 3, k)).copy()
            return a.reshape(t, 3, k)
        self.chunks.setdefault(cls, []).append((pos, nor, full(col, 4, np.uint8), full(uv, 2, np.float64),
                                                full(uv2, 2, np.float64)))

    def empty(self):
        return not self.chunks

    def triangles(self, cls=None):
        return int(sum(c[0].shape[0] for k, cs in self.chunks.items() if cls in (None, k) for c in cs))

    def points(self):
        """All corner positions (Blender space), (N, 3)."""
        ps = [c[0].reshape(-1, 3) for cs in self.chunks.values() for c in cs]
        return np.concatenate(ps) if ps else np.zeros((0, 3))

    def merge(self, other, offset=None):
        for cls, cs in other.chunks.items():
            for (pos, nor, col, uv, uv2) in cs:
                self.chunks.setdefault(cls, []).append((pos + (0.0 if offset is None else np.asarray(offset)),
                                                        nor, col, uv, uv2))

    def finish(self, origin=None, min_height=0.0):
        """[(class, dict(pos, nor, idx, col, uv, uv2))] in CLASS_ORDER; positions relative to origin
        (Blender space) and converted to model space. Degenerate triangles are dropped.
        min_height (m): also drops slivers - triangles whose smallest height is below it. The cuts of decals and
        openings leave triangles a few hundredths of a millimetre high; the baked meshes store positions in
        16 bits (0.07 mm for a car), so such a triangle can come out wound the other way (the validator counted
        them as inside-out faces). What they leave open is narrower than they were."""
        out = []
        for cls in CLASS_ORDER:
            cs = self.chunks.get(cls)
            if not cs:
                continue
            if min_height > 0.0:
                kept = []
                for c in cs:
                    p = c[0]
                    e = np.stack([np.linalg.norm(p[:, 1] - p[:, 0], axis=1), np.linalg.norm(p[:, 2] - p[:, 1], axis=1),
                                  np.linalg.norm(p[:, 0] - p[:, 2], axis=1)], axis=1)
                    area2 = np.linalg.norm(np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0]), axis=1)
                    ok = area2 >= min_height * e.max(axis=1)
                    if ok.all():
                        kept.append(c)
                    elif ok.any():
                        kept.append(tuple(None if a is None else a[ok] for a in c))
                cs = kept
                if not cs:
                    continue
            pos = np.concatenate([c[0] for c in cs])
            nor = np.concatenate([c[1] for c in cs])

            def cat(i, k, dtype, default):
                if all(c[i] is None for c in cs):
                    return None
                return np.concatenate([c[i] if c[i] is not None else
                                       np.broadcast_to(np.asarray(default, dtype=dtype), (c[0].shape[0], 3, k))
                                       for c in cs])
            col = cat(2, 4, np.uint8, (255, 255, 255, 255))
            uv = cat(3, 2, np.float64, (0.0, 0.0))
            uv2 = cat(4, 2, np.float64, (-1.0, 0.0))
            if origin is not None:
                pos = pos - np.asarray(origin, dtype=np.float64)
            w = weld(to_model_axes(pos), to_model_axes(nor), col, uv, uv2)
            if w is not None:
                out.append((cls, w))
        return out


def weld(pos, nor, col=None, uv=None, uv2=None):
    """Per-corner arrays (T x 3 corners) -> indexed vertices: dict(pos, nor, idx, col, uv, uv2).
    Corners are merged when position (0.01 mm), normal (1e-3), colour, UV and UV2 are equal - so a vertex
    is never shared between two paint codes or lamp channels."""
    m = pos.shape[0] * 3
    keys = [np.round(pos.reshape(m, 3) * 1e5).astype(np.int64), np.round(nor.reshape(m, 3) * 1e3).astype(np.int64)]
    if col is not None:
        keys.append(col.reshape(m, 4).astype(np.int64))
    if uv is not None:
        keys.append(np.round(uv.reshape(m, 2) * 65536.0).astype(np.int64))
    if uv2 is not None:
        keys.append(np.round(uv2.reshape(m, 2) * 4096.0).astype(np.int64))
    key = np.concatenate(keys, axis=1)
    _u, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    idx = inv.reshape(-1, 3)
    ok = (idx[:, 0] != idx[:, 1]) & (idx[:, 1] != idx[:, 2]) & (idx[:, 0] != idx[:, 2])
    idx = idx[ok]
    if idx.shape[0] == 0:
        return None
    # drop vertices that only degenerate triangles used, keep the order of first use stable
    used = np.zeros(first.shape[0], dtype=bool)
    used[idx.reshape(-1)] = True
    remap = np.cumsum(used) - 1
    sel = first[used]
    out = dict(pos=pos.reshape(m, 3)[sel], nor=nor.reshape(m, 3)[sel], idx=remap[idx].reshape(-1).astype(np.uint32))
    out["col"] = col.reshape(m, 4)[sel] if col is not None else None
    out["uv"] = uv.reshape(m, 2)[sel] if uv is not None else None
    out["uv2"] = uv2.reshape(m, 2)[sel] if uv2 is not None else None
    return out


def transfer_normals(pos, nor, fpos, fnor, pull=0.15, max_dist=0.12, agree=0.2):
    """Corner normals for a coarse build from a finer build of the same surface (levels of detail).
    pos, nor: (T, 3, 3) of the coarse triangles; fpos, fnor: the fine ones. Every corner takes the smooth normal
    of the nearest point of the fine surface - the coarse level then shades like the fine one (flat facets with
    the normals of the curved surface they stand for) and face tests on the smooth normal (decals) cut along
    the same lines at every level. A corner whose fine normal looks away from its own face (cosine below
    `agree`: a sharp edge of the fine build, the nearest point lies on the other side) asks again from a point
    pulled towards the middle of its triangle; if that fails too it keeps its normal."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    fpos = np.asarray(fpos, dtype=np.float64).reshape(-1, 3, 3)
    fnor = np.asarray(fnor, dtype=np.float64).reshape(-1, 3, 3)
    pos = np.asarray(pos, dtype=np.float64).reshape(-1, 3, 3)
    out = np.array(nor, dtype=np.float64).reshape(-1, 3, 3).copy()
    if fpos.shape[0] == 0 or pos.shape[0] == 0:
        return out
    bvh = BVHTree.FromPolygons([Vector(p) for p in fpos.reshape(-1, 3)],
                               [(3 * i, 3 * i + 1, 3 * i + 2) for i in range(fpos.shape[0])], all_triangles=True)
    cfn = np.cross(pos[:, 1] - pos[:, 0], pos[:, 2] - pos[:, 0])
    cfn = cfn / np.maximum(np.linalg.norm(cfn, axis=1, keepdims=True), 1e-12)
    cache = {}

    def lookup(p):
        loc, _n, idx, dist = bvh.find_nearest(Vector(p))
        if loc is None or dist > max_dist:
            return None
        a, b, c = fpos[idx]
        v0, v1, v2 = b - a, c - a, np.array(loc) - a
        d00, d01, d11, d20, d21 = v0 @ v0, v0 @ v1, v1 @ v1, v2 @ v0, v2 @ v1
        den = d00 * d11 - d01 * d01
        if abs(den) < 1e-18:
            n = fnor[idx].mean(axis=0)
        else:
            w1 = (d11 * d20 - d01 * d21) / den
            w2 = (d00 * d21 - d01 * d20) / den
            w = np.clip(np.array([1.0 - w1 - w2, w1, w2]), 0.0, 1.0)
            n = w @ fnor[idx]
        ln = np.linalg.norm(n)
        return n / ln if ln > 1e-9 else None
    for t in range(pos.shape[0]):
        cen = pos[t].mean(axis=0)
        for i in range(3):
            p = pos[t, i]
            key = (int(round(p[0] * 1e5)), int(round(p[1] * 1e5)), int(round(p[2] * 1e5)))
            if key not in cache:
                cache[key] = lookup(p)
            n = cache[key]
            if n is None or n @ cfn[t] < agree:
                n = lookup(p + pull * (cen - p))
            if n is not None and n @ cfn[t] >= agree:
                out[t, i] = n
    return out


def tri_count(surfaces):
    return int(sum(len(s["idx"]) // 3 for _c, s in surfaces))


def tri_areas(pos):
    """Areas of (T, 3, 3) triangles."""
    return 0.5 * np.linalg.norm(np.cross(pos[:, 1] - pos[:, 0], pos[:, 2] - pos[:, 0]), axis=1)
