"""Realise cesprites models (evaluated meshes, world space) and translate their materials.
Blender space of the generators: x right, y forward (along the road), z up, metres.
glTF / Godot space written here: X = x, Y = z (up), Z = -y  ->  vehicle nose at -Z (Godot node forward)."""
import math

import bpy
import numpy as np

LAYERS = ("tail", "brake", "beacon_a", "beacon_b", "lights")
PROC = {"ShaderNodeTexNoise", "ShaderNodeTexVoronoi", "ShaderNodeTexBrick", "ShaderNodeTexWhiteNoise",
        "ShaderNodeTexWave", "ShaderNodeTexMagic", "ShaderNodeTexChecker", "ShaderNodeTexGradient"}


def lin_to_srgb(c):
    c = np.clip(np.asarray(c, dtype=np.float64), 0.0, None)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.maximum(c, 1e-12), 1 / 2.4) - 0.055)


def mat_info(mat):
    """Class and constants of a cesprites material.
    cls: flat (constant Principled) | mask (object-space math masks) | proc (noise textures) | lens | none
    emit: {layer: [r, g, b] linear, already scaled by strength}; emit_proc: [layers with masked emission]"""
    if mat is None or mat.node_tree is None:
        return dict(cls="none", emit={}, emit_proc=[], color=(0.8, 0.8, 0.8, 1.0), rough=0.5, metal=0.0, coat=0.0, spec=0.5)
    key = "_ce_info"
    nt = mat.node_tree
    ts = {n.bl_idname for n in nt.nodes}
    emit, emit_proc = {}, []
    for n in nt.nodes:
        if n.bl_idname == "ShaderNodeVectorMath" and n.operation == "SCALE":
            s = n.inputs["Scale"]
            if s.is_linked:
                src = s.links[0].from_node
                if src.bl_idname == "ShaderNodeGroup" and src.node_tree and src.node_tree.name.startswith("CE_PASS"):
                    layer = s.links[0].from_socket.name
                    if n.inputs[0].is_linked:
                        emit_proc.append(layer)
                    else:
                        v = n.inputs[0].default_value
                        emit[layer] = [float(v[0]), float(v[1]), float(v[2])]
    bsdf = [n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"]
    info = dict(emit={k: v for k, v in emit.items() if max(v) > 1e-6}, emit_proc=sorted(set(emit_proc)))
    if not bsdf:
        tr = [n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfTransparent"]
        if tr:
            # materials.lens: first transparent BSDF carries the tint
            tint = None
            for n in tr:
                c = tuple(n.inputs["Color"].default_value)
                if c[:3] != (1.0, 1.0, 1.0):
                    tint = c
            df = [n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfDiffuse"]
            info.update(cls="lens", color=tint or (1, 1, 1, 1), rough=0.05, metal=0.0, coat=0.0, spec=0.5,
                        frost=bool(df))
            return info
        info.update(cls="none", color=(0.8, 0.8, 0.8, 1.0), rough=0.5, metal=0.0, coat=0.0, spec=0.5)
        return info
    b = bsdf[0]
    linked = [k for k in ("Base Color", "Roughness", "Metallic", "Normal", "Coat Weight", "Specular IOR Level")
              if b.inputs[k].is_linked]
    # cut-outs: a mask mixes a Transparent BSDF with the surface (railings, lattice openings)
    cutout = False
    for n in nt.nodes:
        if n.bl_idname == "ShaderNodeMixShader" and n.inputs[0].is_linked:
            srcs = [n.inputs[i].links[0].from_node.bl_idname if n.inputs[i].is_linked else "" for i in (1, 2)]
            fac_src = n.inputs[0].links[0].from_node
            is_pass = fac_src.bl_idname == "ShaderNodeMath" and any(
                l.from_node.bl_idname == "ShaderNodeGroup" for i in fac_src.inputs for l in i.links)
            if "ShaderNodeBsdfTransparent" in srcs and not is_pass:
                cutout = True
    if ts & PROC:
        cls = "proc"
    elif linked or cutout:
        cls = "mask"
    else:
        cls = "flat"
    info["cutout"] = cutout

    def val(k, d):
        return float(b.inputs[k].default_value) if not b.inputs[k].is_linked else d
    info.update(cls=cls, color=tuple(b.inputs["Base Color"].default_value), rough=val("Roughness", 0.5),
                metal=val("Metallic", 0.0), coat=val("Coat Weight", 0.0), spec=val("Specular IOR Level", 0.5),
                coat_rough=float(b.inputs["Coat Roughness"].default_value), linked=linked)
    return info


def to_gltf_axes(a):
    """(x, y, z) Blender -> (x, z, -y) glTF."""
    out = np.empty_like(a)
    out[:, 0] = a[:, 0]
    out[:, 1] = a[:, 2]
    out[:, 2] = -a[:, 1]
    return out


class Soup:
    """Triangle soup of one object in world (root) space: per-corner arrays."""

    def __init__(self, ob, deps, uv_layer=None):
        ev = ob.evaluated_get(deps)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        nt = len(me.loop_triangles)
        self.name = ob.name
        self.ob = ob
        self.mats = [s.material for s in ob.material_slots]
        self.n = nt
        if nt == 0:
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
        nm = np.linalg.inv(m3).T
        nor = cn[tl] @ nm.T
        ln = np.linalg.norm(nor, axis=1, keepdims=True)
        nor = nor / np.maximum(ln, 1e-12)
        self.pos = pos.reshape(nt, 3, 3)
        self.nor = nor.reshape(nt, 3, 3)
        if np.linalg.det(m3) < 0:
            self.pos = self.pos[:, ::-1, :].copy()
            self.nor = self.nor[:, ::-1, :].copy()
        self.mi = mi
        self.uv = None
        lay = None
        if uv_layer and uv_layer in me.uv_layers:
            lay = me.uv_layers[uv_layer]
        if lay is not None:
            uv = np.empty(nl * 2, dtype=np.float32)
            lay.data.foreach_get("uv", uv)
            uv = uv.reshape(-1, 2)[tl].reshape(nt, 3, 2)
            if np.linalg.det(m3) < 0:
                uv = uv[:, ::-1, :].copy()
            self.uv = uv
        ev.to_mesh_clear()


def weld(pos, nor, uv=None, col=None, uv2=None, tol=1e-5):
    """Per-corner arrays (M x 3 corners) -> indexed vertices. Returns dict(pos, nor, uv, col, idx)."""
    m = pos.shape[0] * 3
    cols = [np.round(pos.reshape(m, 3) / tol).astype(np.int64), np.round(nor.reshape(m, 3) * 2000).astype(np.int64)]
    if uv is not None:
        cols.append(np.round(uv.reshape(m, 2) * 65536).astype(np.int64))
    if uv2 is not None:
        cols.append(np.round(uv2.reshape(m, 2) * 65536).astype(np.int64))
    if col is not None:
        cols.append(col.reshape(m, 4).astype(np.int64))
    key = np.concatenate(cols, axis=1)
    _u, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    out = dict(pos=pos.reshape(m, 3)[first], nor=nor.reshape(m, 3)[first], idx=inv.reshape(-1).astype(np.uint32))
    out["uv"] = uv.reshape(m, 2)[first] if uv is not None else None
    out["uv2"] = uv2.reshape(m, 2)[first] if uv2 is not None else None
    out["col"] = col.reshape(m, 4)[first] if col is not None else None
    return out


def model_objects(rig):
    rig.root.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    return [o for o in rig.root.children_recursive if o.type == "MESH" and not o.hide_render and o not in rig.catchers]


def decimate_copy(ob, ratio, name=None):
    """Adds a collapse decimate modifier to a realised object (returns the modifier)."""
    m = ob.modifiers.new("lod", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = ratio
    m.use_collapse_triangulate = True
    return m
