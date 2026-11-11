"""Atlas bake of procedural materials (facades, roofs, landmarks ...; contract D19, 4.6.5).

  unwrap    box unwrap: connected faces with the same dominant world axis form a chart, projected onto
            the plane of the chart's mean normal (true lengths, "up" stays up); texel density per chart
            weighted by visibility (weight function of the model)
  pack      shelf packing into one atlas at the highest density (px/m) that fits
  bake      Cycles EMIT bakes at 2x resolution with 16 samples: base colour (through a temporary emission),
            the emission layers of CE_PASS ('lights'), optional opacity of cut-out materials
  finish    box downsample over covered texels, dilation into the gutters (no dark seams under mipmaps)
The UV layer "ce_bake" stays on the objects; the exporter reads it with the triangles.
"""
import io
import math

import bmesh
import bpy
import numpy as np

from cesprites import materials as M

from . import core

UV_NAME = "ce_bake"
SUPERSAMPLE = 2
SAMPLES = 16


# --- unwrap --------------------------------------------------------------------------------------------

def _axis_class(n):
    ax = int(np.argmax(np.abs(n)))
    return ax * 2 + (1 if n[ax] < 0 else 0)


def box_unwrap(objs, is_bake_mat, weight_fn=None):
    """Creates the UV layer UV_NAME on every object and returns the charts:
    [dict(ob, loops, uv (N x 2, metres, min at 0), w, h, weight, area, normal)]. Objects must be realised
    (no modifiers)."""
    charts = []
    for ob in objs:
        me = ob.data
        if UV_NAME not in me.uv_layers:
            me.uv_layers.new(name=UV_NAME)
        mw = np.array(ob.matrix_world, dtype=np.float64)
        m3 = mw[:3, :3]
        nm = np.linalg.inv(m3).T
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        mats = [s.material for s in ob.material_slots]
        wn = []
        cls = []
        for f in bm.faces:
            n = nm @ np.array(f.normal)
            ln = np.linalg.norm(n)
            n = n / ln if ln > 1e-12 else np.array([0.0, 0.0, 1.0])
            wn.append(n)
            ok = is_bake_mat(mats[f.material_index] if f.material_index < len(mats) else None)
            cls.append(_axis_class(n) if ok else -1)
        seen = [False] * len(bm.faces)
        for f0 in bm.faces:
            if seen[f0.index] or cls[f0.index] < 0:
                continue
            c = cls[f0.index]
            stack = [f0]
            seen[f0.index] = True
            comp = []
            while stack:
                f = stack.pop()
                comp.append(f)
                for e in f.edges:
                    for g in e.link_faces:
                        if not seen[g.index] and cls[g.index] == c:
                            seen[g.index] = True
                            stack.append(g)
            comp.sort(key=lambda f: f.index)
            areas = np.array([f.calc_area() for f in comp])
            nbar = (np.array([wn[f.index] for f in comp]) * areas[:, None]).sum(axis=0)
            ln = np.linalg.norm(nbar)
            nbar = nbar / ln if ln > 1e-9 else wn[comp[0].index]
            up = np.array([0.0, 0.0, 1.0]) if abs(nbar[2]) < 0.9 else np.array([0.0, 1.0, 0.0])
            u = np.cross(up, nbar)
            u /= np.linalg.norm(u)
            v = np.cross(nbar, u)
            loops, pts = [], []
            centres = []
            for f in comp:
                for l in f.loops:
                    loops.append(l.index)
                    pts.append(l.vert.co[:])
                # sample points of the face for the visibility test: its centre, and points near every
                # corner and edge (a wall is often covered only in part by another volume)
                fc = np.array(f.calc_center_median())
                vs = [np.array(v.co) for v in f.verts]
                samples = [fc] + [v * 0.85 + fc * 0.15 for v in vs]
                samples += [(vs[i] + vs[(i + 1) % len(vs)]) * 0.5 * 0.9 + fc * 0.1 for i in range(len(vs))]
                samples += [v * 0.5 + fc * 0.5 for v in vs]
                for sp in samples:
                    centres.append((sp @ m3.T + mw[:3, 3], wn[f.index]))
            wp = np.array(pts, dtype=np.float64) @ m3.T + mw[:3, 3]
            uv = np.stack([wp @ u, wp @ v], axis=1)
            uv -= uv.min(axis=0)
            w, h = float(uv[:, 0].max()), float(uv[:, 1].max())
            if h > w:               # long side horizontal: shelves pack tighter
                uv = np.stack([uv[:, 1], w - uv[:, 0]], axis=1)
                w, h = h, w
            sc = abs(np.linalg.det(m3)) ** (1.0 / 3.0)
            wt = float(weight_fn(nbar, ob)) if weight_fn else 1.0
            charts.append(dict(ob=ob, loops=np.array(loops, dtype=np.int64), uv=uv, w=w, h=h, weight=wt,
                               area=float(areas.sum()) * sc * sc, normal=nbar, centres=centres))
        bm.free()
    return charts


def hide_covered(charts, objs, weight=0.03, rays=14, samples=96):
    """Charts no ray can leave (wall tops under a roof, faces inside other volumes) get a tiny weight:
    from up to `samples` points spread over the faces of a chart, `rays` directions over the hemisphere of
    the face normal are cast against all objects. Returns the number of hidden charts."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    verts, polys = [], []
    for ob in objs:
        mw = ob.matrix_world
        base = len(verts)
        verts += [mw @ v.co for v in ob.data.vertices]
        polys += [[base + i for i in p.vertices] for p in ob.data.polygons]
    bvh = BVHTree.FromPolygons(verts, polys, all_triangles=False)
    # fixed directions: a ring at 25 degrees and one at 65 degrees off the normal, and the normal itself
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
                hit = bvh.ray_cast(o, Vector(w), 2000.0)
                if hit[0] is None:
                    free = True
                    break
            if free:
                break
        if not free:
            c["weight"] = min(c["weight"], weight)
            c["hidden"] = True
            hidden += 1
    return hidden


def _maxrects(rects, W, H):
    """MaxRects (best short side fit, rotation allowed) of [(w, h)] px rectangles into W x H.
    Returns [(x, y, rotated)] in input order or None if one does not fit. Deterministic."""
    free = [(0, 0, W, H)]
    out = [None] * len(rects)
    order = sorted(range(len(rects)), key=lambda i: (-max(rects[i]), -min(rects[i]), i))
    for i in order:
        w, h = rects[i]
        best = None
        for (fx, fy, fw, fh) in free:
            for rot, (rw, rh) in ((False, (w, h)), (True, (h, w))):
                if rw <= fw and rh <= fh:
                    key = (min(fw - rw, fh - rh), max(fw - rw, fh - rh), fy, fx, rot)
                    if best is None or key < best[0]:
                        best = (key, fx, fy, rw, rh, rot)
        if best is None:
            return None
        _k, x, y, rw, rh, rot = best
        out[i] = (x, y, rot)
        nxt = []
        for (fx, fy, fw, fh) in free:
            if x >= fx + fw or x + rw <= fx or y >= fy + fh or y + rh <= fy:
                nxt.append((fx, fy, fw, fh))
                continue
            if x > fx:
                nxt.append((fx, fy, x - fx, fh))
            if x + rw < fx + fw:
                nxt.append((x + rw, fy, fx + fw - (x + rw), fh))
            if y > fy:
                nxt.append((fx, fy, fw, y - fy))
            if y + rh < fy + fh:
                nxt.append((fx, y + rh, fw, fy + fh - (y + rh)))
        # drop free rectangles contained in another one
        nxt = sorted(set(nxt), key=lambda r: (-r[2] * r[3], r))
        keep = []
        for r in nxt:
            if not any(k[0] <= r[0] and k[1] <= r[1] and k[0] + k[2] >= r[0] + r[2] and k[1] + k[3] >= r[1] + r[3]
                       for k in keep):
                keep.append(r)
        free = keep
    return out


def _shelves(rects, W, H):
    """Shelf packing (fallback for very many charts): [(x, y, False)] or None."""
    order = sorted(range(len(rects)), key=lambda i: (-rects[i][1], i))
    out = [None] * len(rects)
    x = y = 0
    row_h = 0
    for i in order:
        w, h = rects[i]
        if w > W:
            return None
        if x + w > W:
            x = 0
            y += row_h
            row_h = 0
        if y + h > H:
            return None
        out[i] = (x, y, False)
        x += w
        row_h = max(row_h, h)
    return out


def pack(charts, size, gutter=2, ppm_max=512.0, maxrects_limit=1500):
    """Packs the charts into size = (W, H) px at the highest density that fits (MaxRects with rotation;
    shelves above maxrects_limit charts). Writes chart['x'], chart['y'] (px), chart['ppm'] (its own
    density = ppm * weight) and chart['rot'] (turned by 90 degrees). Returns ppm."""
    W, H = size
    fit = _maxrects if len(charts) <= maxrects_limit else _shelves

    def rects(ppm):
        return [(int(math.ceil(c["w"] * ppm * c["weight"])) + 1 + gutter,
                 int(math.ceil(c["h"] * ppm * c["weight"])) + 1 + gutter) for c in charts]

    def try_pack(ppm):
        return fit(rects(ppm), W - gutter, H - gutter)
    lo, hi = 0.0, ppm_max
    res = try_pack(hi)
    if res is not None:
        lo = hi
    else:
        res = None
        for _ in range(22):
            mid = (lo + hi) / 2
            r = try_pack(mid)
            if r is not None:
                lo, res = mid, r
            else:
                hi = mid
    if res is None or lo <= 0.0:
        raise RuntimeError("atlas %dx%d too small for %d charts" % (W, H, len(charts)))
    for c, (x, y, rot) in zip(charts, res):
        c["x"], c["y"], c["rot"], c["ppm"] = x + gutter, y + gutter, rot, lo * c["weight"]
    return lo


def write_uvs(charts, size):
    """UVs of the packed charts into the layer UV_NAME (Blender convention: v up)."""
    W, H = size
    per_ob = {}
    for c in charts:
        per_ob.setdefault(c["ob"].name, []).append(c)
    for name in sorted(per_ob):
        cs = per_ob[name]
        me = cs[0]["ob"].data
        lay = me.uv_layers[UV_NAME]
        uv = np.zeros((len(me.loops), 2), dtype=np.float32)
        for c in cs:
            cu, cv = c["uv"][:, 0], c["uv"][:, 1]
            if c.get("rot"):
                cu, cv = cv, c["w"] - cu
            uv[c["loops"], 0] = (c["x"] + 0.5 + cu * c["ppm"]) / W
            uv[c["loops"], 1] = (c["y"] + 0.5 + cv * c["ppm"]) / H
        lay.data.foreach_set("uv", uv.reshape(-1))
        me.uv_layers.active = lay
        lay.active_render = True
        me.update()


# --- bake ----------------------------------------------------------------------------------------------

class Baker:
    """Cycles EMIT bakes of a set of objects into one float image of size (W, H) * supersample."""

    def __init__(self, rig, objs, mats, size, supersample=SUPERSAMPLE, samples=SAMPLES):
        self.rig = rig
        self.objs = objs
        self.mats = mats
        self.size = size
        self.ss = supersample
        self.big = (size[0] * supersample, size[1] * supersample)
        sc = rig.scene
        sc.render.engine = "CYCLES"
        sc.cycles.samples = samples
        sc.cycles.use_denoising = False
        sc.cycles.use_adaptive_sampling = False
        sc.render.bake.margin = 2 * supersample
        sc.render.bake.margin_type = "EXTEND"
        sc.render.bake.use_clear = True
        self.img = bpy.data.images.new("ce_bake_img", self.big[0], self.big[1], alpha=True, float_buffer=True)
        for m in mats:
            nt = m.node_tree
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = self.img
            for x in nt.nodes:
                x.select = False
            n.select = True
            nt.nodes.active = n

    def _bake(self):
        for o in bpy.context.view_layer.objects:
            o.select_set(False)
        for o in self.objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.objs[0]
        bpy.ops.object.bake(type="EMIT", margin=2 * self.ss, use_clear=True)
        px = np.empty(self.big[0] * self.big[1] * 4, dtype=np.float32)
        self.img.pixels.foreach_get(px)
        return px.reshape(self.big[1], self.big[0], 4)[::-1].copy()        # top row first

    def layer(self, name):
        """Emission of a CE_PASS layer (linear) -> (H, W, 4) at bake resolution; alpha = covered."""
        M.set_pass(name)
        try:
            return self._bake()
        finally:
            M.set_pass("base")

    def base_color(self):
        """Principled base colour through a temporary emission (materials without a Principled BSDF bake
        mid grey)."""
        return self._rewired(lambda nt, em: _feed_base(nt, em))

    def ambient_occlusion(self, distance=1.5, samples=32, ground=True, occluders=()):
        """Cycles AO bake (1 = open sky, 0 = closed in), with a temporary ground plane at z = 0 so that walls
        darken a little towards their foot. occluders: further objects that shadow but are not baked (the
        vpbr parts of a model: window panes, gutters). Returns (H, W, 4) at bake resolution."""
        sc = self.rig.scene
        old_samples = sc.cycles.samples
        old_dist = sc.world.light_settings.distance
        sc.cycles.samples = samples
        sc.world.light_settings.distance = distance
        plane = None
        if ground:
            me = bpy.data.meshes.new("ce_ao_ground")
            s = 400.0
            me.from_pydata([(-s, -s, 0.0), (s, -s, 0.0), (s, s, 0.0), (-s, s, 0.0)], [], [(0, 1, 2, 3)])
            plane = bpy.data.objects.new("ce_ao_ground", me)
            self.rig.scene.collection.objects.link(plane)
        try:
            for o in bpy.context.view_layer.objects:
                o.select_set(False)
            for o in self.objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = self.objs[0]
            bpy.ops.object.bake(type="AO", margin=2 * self.ss, use_clear=True)
            px = np.empty(self.big[0] * self.big[1] * 4, dtype=np.float32)
            self.img.pixels.foreach_get(px)
            return px.reshape(self.big[1], self.big[0], 4)[::-1].copy()
        finally:
            sc.cycles.samples = old_samples
            sc.world.light_settings.distance = old_dist
            if plane is not None:
                bpy.data.objects.remove(plane, do_unlink=True)

    def opacity(self):
        """1 where a cut-out material is solid (a mask mixes a Transparent BSDF with the surface)."""
        return self._rewired(lambda nt, em: _feed_opacity(nt, em))

    def _rewired(self, feed):
        M.set_pass("base")
        undo = []
        for m in self.mats:
            nt = m.node_tree
            out = [n for n in nt.nodes if n.bl_idname == "ShaderNodeOutputMaterial"][0]
            old = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].is_linked else None
            em = nt.nodes.new("ShaderNodeEmission")
            em.inputs["Strength"].default_value = 1.0
            extra = feed(nt, em) or []
            nt.links.new(em.outputs[0], out.inputs["Surface"])
            undo.append((nt, out, old, [em] + extra))
        try:
            return self._bake()
        finally:
            for nt, out, old, nodes in undo:
                if old is not None:
                    nt.links.new(old, out.inputs["Surface"])
                for n in nodes:
                    nt.nodes.remove(n)


def _feed_base(nt, em):
    bs = [n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"]
    if not bs:
        em.inputs["Color"].default_value = (0.5, 0.5, 0.5, 1.0)
        return []
    inp = bs[0].inputs["Base Color"]
    if inp.is_linked:
        nt.links.new(inp.links[0].from_socket, em.inputs["Color"])
    else:
        em.inputs["Color"].default_value = tuple(inp.default_value)
    return []


def _feed_opacity(nt, em):
    em.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    for n in nt.nodes:
        if n.bl_idname != "ShaderNodeMixShader" or not n.inputs[0].is_linked:
            continue
        srcs = [n.inputs[i].links[0].from_node.bl_idname if n.inputs[i].is_linked else "" for i in (1, 2)]
        if "ShaderNodeBsdfTransparent" not in srcs:
            continue
        fac = n.inputs[0].links[0].from_socket
        if fac.node.bl_idname == "ShaderNodeMath" and any(
                l.from_node.bl_idname == "ShaderNodeGroup" for i in fac.node.inputs for l in i.links):
            continue                        # the CE_PASS switch of a lens, not a cut-out
        if srcs[0] == "ShaderNodeBsdfTransparent":       # fac = 1 -> surface
            nt.links.new(fac, em.inputs["Color"])
            return []
        inv = nt.nodes.new("ShaderNodeMath")              # fac = 1 -> transparent
        inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        nt.links.new(fac, inv.inputs[1])
        nt.links.new(inv.outputs[0], em.inputs["Color"])
        return [inv]
    return []


def has_cutout(mat):
    """True if the material mixes a Transparent BSDF in by a mask (railings, lattice openings)."""
    nt = mat.node_tree
    for n in nt.nodes:
        if n.bl_idname != "ShaderNodeMixShader" or not n.inputs[0].is_linked:
            continue
        srcs = [n.inputs[i].links[0].from_node.bl_idname if n.inputs[i].is_linked else "" for i in (1, 2)]
        fac = n.inputs[0].links[0].from_node
        is_pass = fac.bl_idname == "ShaderNodeMath" and any(
            l.from_node.bl_idname == "ShaderNodeGroup" for i in fac.inputs for l in i.links)
        if "ShaderNodeBsdfTransparent" in srcs and not is_pass:
            return True
    return False


# --- image finishing -------------------------------------------------------------------------------------

def downsample(img, ss):
    """Box filter over covered texels only. img: (H*ss, W*ss, 4) with alpha = coverage -> (H, W, 4)."""
    h, w = img.shape[0] // ss, img.shape[1] // ss
    a = img.reshape(h, ss, w, ss, 4).astype(np.float64)
    cov = (a[..., 3:4] > 0.5).astype(np.float64)
    n = cov.sum(axis=(1, 3))
    rgb = (a[..., :3] * cov).sum(axis=(1, 3)) / np.maximum(n, 1.0)
    return np.concatenate([rgb, (n > 0).astype(np.float64)], axis=2)


def dilate(img, steps=16):
    """Spreads covered texels into uncovered neighbours (alpha = coverage), `steps` texels far."""
    rgb = img[..., :3].copy()
    cov = img[..., 3] > 0.5
    for _ in range(steps):
        if cov.all():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros(cov.shape, dtype=np.float64)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            src = np.roll(rgb, (dy, dx), axis=(0, 1))
            sc = np.roll(cov, (dy, dx), axis=(0, 1))
            # no wrap-around at the borders
            if dy == 1:
                sc[0, :] = False
            elif dy == -1:
                sc[-1, :] = False
            if dx == 1:
                sc[:, 0] = False
            elif dx == -1:
                sc[:, -1] = False
            acc += src * sc[..., None]
            cnt += sc
        new = (~cov) & (cnt > 0)
        rgb[new] = acc[new] / cnt[new][:, None]
        cov = cov | new
    out = img.copy()
    out[..., :3] = rgb
    return out


def half(img):
    """2x2 box reduction of (H, W, C)."""
    h, w = img.shape[0] // 2, img.shape[1] // 2
    return img[:h * 2, :w * 2].reshape(h, 2, w, 2, img.shape[2]).mean(axis=(1, 3))


def encode(rgb_lin, alpha=None, fmt="png", srgb=True):
    """(H, W, 3) linear floats (+ optional alpha 0..1) -> PNG or WebP (quality 95) bytes."""
    from PIL import Image
    a = np.clip(rgb_lin, 0.0, 1.0)
    if srgb:
        a = core.lin_to_srgb(a)
    a8 = np.clip(np.round(a * 255.0), 0, 255).astype(np.uint8)
    if alpha is not None:
        al = np.clip(np.round(alpha * 255.0), 0, 255).astype(np.uint8)
        im = Image.fromarray(np.concatenate([a8, al[..., None]], axis=2), "RGBA")
    else:
        im = Image.fromarray(a8, "RGB")
    buf = io.BytesIO()
    if fmt == "webp":
        im.save(buf, "WEBP", quality=95, method=6, exact=True)
    else:
        im.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def _blur_covered(img, steps=1):
    """3x3 box blur of the rgb of covered texels (alpha = coverage) that only mixes covered texels: takes the
    sampling noise out of an AO bake without bleeding across chart borders."""
    rgb = img[..., :3].astype(np.float64)
    cov = (img[..., 3] > 0.5).astype(np.float64)
    for _ in range(steps):
        acc = rgb * cov[..., None]
        cnt = cov.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy == 0 and dx == 0:
                    continue
                acc += np.roll(rgb * cov[..., None], (dy, dx), axis=(0, 1))
                cnt += np.roll(cov, (dy, dx), axis=(0, 1))
        rgb = np.where(cov[..., None] > 0, acc / np.maximum(cnt, 1.0)[..., None], rgb)
    out = img.copy()
    out[..., :3] = rgb
    return out


def bake_atlas(rig, objs, mats, size, weight_fn=None, ppm_max=512.0, layers=("lights",), cutout=False,
               supersample=SUPERSAMPLE, samples=SAMPLES, ao=None):
    """Unwraps, packs and bakes. Returns dict(albedo (H, W, 3) linear, alpha (H, W) | None,
    emit {layer: (H, W, 3) linear at FULL size} (only layers with light), stats).
    ao: None (the colour only - wave 0) or dict(distance (m), floor (albedo factor in a closed corner),
    gamma, samples, occluders (objects that shadow but are not baked)): ambient occlusion is baked in - the
    albedo is multiplied by floor + (1 - floor) * ao^gamma. The real-time light has no occlusion of its own."""
    import time
    names = {m.name for m in mats}
    t0 = time.time()
    charts = box_unwrap(objs, lambda m: m is not None and m.name in names, weight_fn)
    hidden = hide_covered(charts, objs)
    ppm = pack(charts, size, gutter=2, ppm_max=ppm_max)
    write_uvs(charts, size)
    stats = dict(atlas=list(size), charts=len(charts), hidden=hidden, ppm=round(ppm, 2),
                 area_m2=round(sum(c["area"] for c in charts), 1), unwrap_s=round(time.time() - t0, 2))
    bk = Baker(rig, objs, mats, size, supersample, samples)
    t0 = time.time()
    base = downsample(bk.base_color(), supersample)
    stats["coverage"] = round(float(base[..., 3].mean()), 3)
    out = dict(albedo=None, alpha=None, emit={})
    if cutout:
        op = downsample(bk.opacity(), supersample)
        out["alpha"] = dilate(op)[..., 0]
    for layer in layers:
        em = downsample(bk.layer(layer), supersample)
        if float(em[..., :3].max()) > 0.004:
            out["emit"][layer] = dilate(em)[..., :3]
    if ao:
        # ambient occlusion is smooth: baked at the atlas size itself (a quarter of the texels of the colour bake).
        # Its own image node becomes the active one of every material - so it comes last.
        t_ao = time.time()
        occ = list(ao.get("occluders", ()))
        ao_bk = Baker(rig, objs, mats, size, 1, samples)
        a = ao_bk.ambient_occlusion(ao.get("distance", 1.5), ao.get("samples", 16), ao.get("ground", True), occ)
        a = downsample(_blur_covered(a, 1), 1)
        k = float(ao.get("floor", 0.45)) + (1.0 - float(ao.get("floor", 0.45))) * np.power(
            np.clip(a[..., 0], 0.0, 1.0), float(ao.get("gamma", 1.0)))
        base = base.copy()
        base[..., :3] *= k[..., None]
        stats["ao_s"] = round(time.time() - t_ao, 2)
        stats["ao_mean"] = round(float((k * base[..., 3]).sum() / max(1.0, base[..., 3].sum())), 3)
    out["albedo"] = dilate(base)[..., :3]
    stats["bake_s"] = round(time.time() - t0, 2)
    out["stats"] = stats
    return out
