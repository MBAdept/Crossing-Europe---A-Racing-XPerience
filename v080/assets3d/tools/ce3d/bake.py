"""Texture baking for materials that do not translate to glTF (object-space masks, noise ...):
box unwrap (6 axis charts per connected component, uniform texel density) + shelf packing into one atlas,
Cycles EMIT bakes of base colour, roughness/metallic and the emission layers (CE_PASS)."""
import math
import time

import bmesh
import bpy
import numpy as np

from cesprites import materials as M

from . import core

UV_NAME = "ce_bake"


def realize_in_place(objs):
    """Applies modifiers (evaluated mesh replaces the mesh data); object transforms stay untouched so that
    object-space shader coordinates remain valid."""
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


def _axis_class(n):
    ax = int(np.argmax(np.abs(n)))
    return ax * 2 + (1 if n[ax] < 0 else 0)


def box_unwrap(objs, is_bake_mat, weight_fn=None):
    """Creates the UV layer UV_NAME on every object and returns the charts
    [dict(ob, loops=[loop indices], uv=Nx2 metres (min at 0), w, h, weight)]."""
    charts = []
    for ob in objs:
        me = ob.data
        if UV_NAME not in me.uv_layers:
            me.uv_layers.new(name=UV_NAME)
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        mats = [s.material for s in ob.material_slots]
        flags = [is_bake_mat(mats[f.material_index] if f.material_index < len(mats) else None) for f in bm.faces]
        cls = [(_axis_class(np.array(f.normal)) if flags[f.index] else -1) for f in bm.faces]
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
            ax = c // 2
            ua, va = [(1, 2), (0, 2), (0, 1)][ax]
            loops, uv = [], []
            for f in comp:
                for l in f.loops:
                    loops.append(l.index)
                    co = l.vert.co
                    uv.append((co[ua], co[va]))
            uv = np.array(uv, dtype=np.float64)
            # world scale of the object (uniform scale assumed for texel density)
            sc = float(np.mean(np.abs(np.array(ob.matrix_world.to_scale()))))
            uv *= sc
            mn = uv.min(axis=0)
            uv -= mn
            w, h = float(uv[:, 0].max()), float(uv[:, 1].max())
            if h > w:           # long side horizontal: shelves pack much tighter
                uv = uv[:, ::-1].copy()
                w, h = h, w
            wt = weight_fn(ob, c, comp) if weight_fn else 1.0
            charts.append(dict(ob=ob, loops=np.array(loops, dtype=np.int64), uv=uv, w=w, h=h, weight=wt,
                               area=sum(f.calc_area() for f in comp) * sc * sc))
        bm.free()
    return charts


def pack(charts, size, gutter=3, ppm_max=512.0):
    """Shelf-packs the charts into size=(W, H) px at the highest uniform density (px/m) that fits.
    Returns ppm; writes chart['x'], chart['y'] (px) and chart['ppm']."""
    W, H = size
    order = sorted(range(len(charts)), key=lambda i: -charts[i]["h"] * charts[i]["weight"])

    def try_pack(ppm, write=False):
        x = y = gutter
        row_h = 0
        for i in order:
            c = charts[i]
            k = ppm * c["weight"]
            cw = int(math.ceil(c["w"] * k)) + 1
            ch = int(math.ceil(c["h"] * k)) + 1
            if cw + 2 * gutter > W:
                return False
            if x + cw + gutter > W:
                x = gutter
                y += row_h + gutter
                row_h = 0
            if y + ch + gutter > H:
                return False
            if write:
                c["x"], c["y"], c["ppm"] = x, y, k
            x += cw + gutter
            row_h = max(row_h, ch)
        return True
    lo, hi = 0.0, ppm_max
    if try_pack(hi):
        lo = hi
    else:
        for _ in range(28):
            mid = (lo + hi) / 2
            if try_pack(mid):
                lo = mid
            else:
                hi = mid
    try_pack(lo, write=True)
    return lo


def write_uvs(charts, size):
    W, H = size
    per_ob = {}
    for c in charts:
        per_ob.setdefault(c["ob"].name, []).append(c)
    for name, cs in per_ob.items():
        ob = cs[0]["ob"]
        me = ob.data
        lay = me.uv_layers[UV_NAME]
        n = len(me.loops)
        uv = np.zeros((n, 2), dtype=np.float32)
        for c in cs:
            u = (c["x"] + 0.5 + c["uv"][:, 0] * c["ppm"]) / W
            v = (c["y"] + 0.5 + c["uv"][:, 1] * c["ppm"]) / H
            uv[c["loops"], 0] = u
            uv[c["loops"], 1] = v
        lay.data.foreach_set("uv", uv.reshape(-1))
        me.uv_layers.active = lay
        lay.active_render = True
        me.update()


class Baker:
    def __init__(self, rig, objs, mats, size):
        self.rig = rig
        self.objs = objs
        self.mats = mats
        self.size = size
        sc = rig.scene
        sc.render.engine = "CYCLES"
        sc.cycles.samples = 1
        sc.cycles.use_denoising = False
        sc.cycles.use_adaptive_sampling = False
        sc.render.bake.margin = 6
        sc.render.bake.use_clear = True
        self.img = bpy.data.images.new("ce_bake_img", size[0], size[1], alpha=True, float_buffer=True)
        self.nodes = {}
        for m in mats:
            nt = m.node_tree
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = self.img
            for x in nt.nodes:
                x.select = False
            n.select = True
            nt.nodes.active = n
            self.nodes[m.name] = n

    def _bake(self, colorspace="sRGB"):
        # float buffer: baked values are scene-linear whatever the label says
        for o in bpy.context.view_layer.objects:
            o.select_set(False)
        for o in self.objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.objs[0]
        bpy.ops.object.bake(type="EMIT", margin=6, use_clear=True)
        n = self.size[0] * self.size[1] * 4
        px = np.empty(n, dtype=np.float32)
        self.img.pixels.foreach_get(px)
        arr = px.reshape(self.size[1], self.size[0], 4)[::-1].copy()     # top row first
        return arr

    def bake_layer(self, layer):
        """Emission of a CE_PASS layer (linear values) -> float array HxWx4."""
        M.set_pass(layer)
        return self._bake("Non-Color")

    def bake_input(self, key, colorspace="sRGB", default=None):
        """Bakes a Principled input (Base Color / Roughness / Metallic ...) through a temporary emission."""
        M.set_pass("base")
        undo = []
        for m in self.mats:
            nt = m.node_tree
            out = [n for n in nt.nodes if n.bl_idname == "ShaderNodeOutputMaterial"][0]
            bs = [n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"]
            old = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].is_linked else None
            em = nt.nodes.new("ShaderNodeEmission")
            em.inputs["Strength"].default_value = 1.0
            if bs:
                inp = bs[0].inputs[key]
                if inp.is_linked:
                    nt.links.new(inp.links[0].from_socket, em.inputs["Color"])
                else:
                    v = inp.default_value
                    em.inputs["Color"].default_value = tuple(v) if hasattr(v, "__len__") else (v, v, v, 1.0)
            else:
                d = default if default is not None else 0.5
                em.inputs["Color"].default_value = (d, d, d, 1.0)
            nt.links.new(em.outputs[0], out.inputs["Surface"])
            undo.append((nt, out, old, em))
        try:
            arr = self._bake(colorspace)
        finally:
            for nt, out, old, em in undo:
                if old is not None:
                    nt.links.new(old, out.inputs["Surface"])
                nt.nodes.remove(em)
        return arr

    def bake_opacity(self):
        """Opacity of cut-out materials (a mask mixing a Transparent BSDF with the surface: railings,
        lattice work): the mix factor is baked through a temporary emission. Opaque materials -> 1."""
        M.set_pass("base")
        undo = []
        found = 0
        for m in self.mats:
            nt = m.node_tree
            out = [n for n in nt.nodes if n.bl_idname == "ShaderNodeOutputMaterial"][0]
            old = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].is_linked else None
            em = nt.nodes.new("ShaderNodeEmission")
            em.inputs["Strength"].default_value = 1.0
            em.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
            extra = []
            for n in nt.nodes:
                if n.bl_idname != "ShaderNodeMixShader" or not n.inputs[0].is_linked:
                    continue
                srcs = [n.inputs[i].links[0].from_node.bl_idname if n.inputs[i].is_linked else "" for i in (1, 2)]
                if "ShaderNodeBsdfTransparent" not in srcs:
                    continue
                fac = n.inputs[0].links[0].from_socket
                if srcs[0] == "ShaderNodeBsdfTransparent":      # fac = 1 -> surface
                    nt.links.new(fac, em.inputs["Color"])
                else:                                            # fac = 1 -> transparent
                    inv = nt.nodes.new("ShaderNodeMath")
                    inv.operation = "SUBTRACT"
                    inv.inputs[0].default_value = 1.0
                    nt.links.new(fac, inv.inputs[1])
                    nt.links.new(inv.outputs[0], em.inputs["Color"])
                    extra.append(inv)
                found += 1
                break
            nt.links.new(em.outputs[0], out.inputs["Surface"])
            undo.append((nt, out, old, [em] + extra))
        try:
            arr = self._bake("Non-Color") if found else None
        finally:
            for nt, out, old, nodes in undo:
                if old is not None:
                    nt.links.new(old, out.inputs["Surface"])
                for n in nodes:
                    nt.nodes.remove(n)
        return arr

    def coverage(self):
        """Alpha of the last bake = texels covered by charts (+margin)."""
        n = self.size[0] * self.size[1] * 4
        px = np.empty(n, dtype=np.float32)
        self.img.pixels.foreach_get(px)
        return px.reshape(self.size[1], self.size[0], 4)[::-1, :, 3].copy()


def to_png_bytes(arr, linear_to_srgb=False, mode="RGB"):
    import io

    from PIL import Image
    a = np.clip(arr, 0.0, 1.0)
    if linear_to_srgb:
        a = a.copy()
        a[:, :, :3] = core.lin_to_srgb(a[:, :, :3])
    a8 = (a * 255.0 + 0.5).astype(np.uint8)
    im = Image.fromarray(a8[:, :, :3] if mode == "RGB" else a8, mode)
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return buf.getvalue(), im
