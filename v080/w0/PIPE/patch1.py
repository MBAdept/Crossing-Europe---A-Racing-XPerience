"""Hook patch 1: shared core (materials tags, meshutil node tags, textgeo) + streetlight light cone."""
from patchlib import patch

patch("tools/blender/cesprites/materials.py", [
    ('''So procedural masks (e.g. lit windows) drive the base look and the night layer consistently.
"""
import math
''', '''So procedural masks (e.g. lit windows) drive the base look and the night layer consistently.

Hook of the 3D model pipeline (tools/blender/ce3d/roles.py): every material carries the custom properties
"ce_role" (flat | paint | glass | lens | surface | proc | fx) and "ce_data" (JSON with its constants). They
tell the exporter how the material is translated; they do not change the node tree or the renders.
"""
import json
import math
'''),
    ('''def scale_rgb(c, k):
    return (c[0] * k, c[1] * k, c[2] * k, 1.0)
''', '''def scale_rgb(c, k):
    return (c[0] * k, c[1] * k, c[2] * k, 1.0)


def tag(m, role, **data):
    """3D pipeline hook: role and constants of a material as custom properties (see module docstring).
    Colours are linear rgb; emit = {layer: rgb with the strength folded in}; sockets are left out."""
    clean = {}
    for k, v in data.items():
        if v is None:
            continue
        if k == "emit":
            v = {layer: [round(float(x), 6) for x in c[:3]] for layer, c in v.items() if isinstance(c, tuple)}
            if not v:
                continue
        elif isinstance(v, (tuple, list)):
            v = [round(float(x), 6) for x in v[:3]]
        elif isinstance(v, bool) or isinstance(v, str):
            pass
        elif isinstance(v, (int, float)):
            v = round(float(v), 6)
        else:
            continue
        clean[k] = v
    m["ce_role"] = role
    m["ce_data"] = json.dumps(clean, sort_keys=True)
    return m
'''),
    ('''    out = nb.node("ShaderNodeOutputMaterial")
    nb.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def principled(''', '''    out = nb.node("ShaderNodeOutputMaterial")
    nb.links.new(mix.outputs[0], out.inputs["Surface"])
    if m.get("ce_role") is None:
        m["ce_role"] = "proc"       # procedural unless the factory function below says otherwise
    return m


def principled('''),
    ('''    em = None
    if emit:
        em = {k: emit_col(v[0], v[1]) for k, v in emit.items()}
    return finish(m, nb, out, em)


def paint(''', '''    em = None
    if emit:
        em = {k: emit_col(v[0], v[1]) for k, v in emit.items()}
    return tag(finish(m, nb, out, em), "flat", color=c1, color2=None if color2 is None else c2,
               var=bool(var_scale), rough=rough, metal=metal, coat=coat, emit=em)


def paint('''),
    ('''    out = principled(nb, c, rough=rough, metal=metal, coat=coat, coat_rough=coat_rough, spec=0.5)
    em = {k: emit_col(v[0], v[1]) for k, v in emit.items()} if emit else None
    return finish(m, nb, out, em)
''', '''    out = principled(nb, c, rough=rough, metal=metal, coat=coat, coat_rough=coat_rough, spec=0.5)
    em = {k: emit_col(v[0], v[1]) for k, v in emit.items()} if emit else None
    return tag(finish(m, nb, out, em), "paint", color=c, rough=rough, metal=metal, coat=coat, emit=em)
'''),
    ('''    out = principled(nb, srgb(tint), rough=rough, metal=0.0, coat=0.6, coat_rough=0.008, spec=0.8)
    return finish(m, nb, out, None)
''', '''    out = principled(nb, srgb(tint), rough=rough, metal=0.0, coat=0.6, coat_rough=0.008, spec=0.8)
    return tag(finish(m, nb, out, None), "glass", color=srgb(tint), rough=rough)
'''),
    ('''    out = nb.node("ShaderNodeOutputMaterial")
    nb.links.new(sw.outputs[0], out.inputs["Surface"])
    return m


def emissive_only(''', '''    out = nb.node("ShaderNodeOutputMaterial")
    nb.links.new(sw.outputs[0], out.inputs["Surface"])
    return tag(m, "lens", tint=srgb(tint), frost=float(frost),
               emit={k: emit_col(v[0], v[1]) for k, v in emit.items()} if emit else None)


def emissive_only('''),
    ('''    out = principled(nb, srgb(tint), rough=rough, metal=0.0, spec=1.0, coat=0.0)
    em = {k: emit_col(v[0], v[1]) for k, v in emit.items()} if emit else None
    return finish(m, nb, out, em)
''', '''    out = principled(nb, srgb(tint), rough=rough, metal=0.0, spec=1.0, coat=0.0)
    em = {k: emit_col(v[0], v[1]) for k, v in emit.items()} if emit else None
    return tag(finish(m, nb, out, em), "glass", color=srgb(tint), rough=rough, emit=em)
'''),
    ('''    b = shader.node
    nb.feed(b.inputs["Coat Weight"], par["coat"])
    return finish(m, nb, shader, emit or None)
''', '''    b = shader.node
    nb.feed(b.inputs["Coat Weight"], par["coat"])
    return tag(finish(m, nb, shader, emit or None), "surface", color=base, rough=rough, metal=metal, coat=coat)
'''),
])

patch("tools/blender/cesprites/meshutil.py", [
    ('''_COLLECTION = None


def set_collection(col):
    global _COLLECTION
    _COLLECTION = col


def _link(ob, parent=None):
    col = _COLLECTION or bpy.context.scene.collection
    col.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return ob
''', '''_COLLECTION = None

# --- hooks of the 3D model pipeline (tools/blender/ce3d/roles.py) -----------------------------------------
# Objects are tagged with the node of the real-time model they belong to ("ce_node": body, wheel_0l, ...;
# "none" = sprite only). Sprite builds never switch tagging on: no property is written, nothing changes.
_TAGS = {"on": False, "node": "body", "pivot": None}


def tagging(on):
    """ce3d: tag every object created from now on (default node "body")."""
    _TAGS["on"] = bool(on)
    _TAGS["node"] = "body"
    _TAGS["pivot"] = None


class node:
    """with MU.node("wheel_0l", pivot=(x, y, z)): objects created inside belong to that node; pivot = its
    origin in build space (wheel centre). Does nothing while tagging is off."""

    def __init__(self, name, pivot=None):
        self.name = name
        self.pivot = pivot

    def __enter__(self):
        self.old = (_TAGS["node"], _TAGS["pivot"])
        _TAGS["node"] = self.name
        _TAGS["pivot"] = self.pivot
        return self

    def __exit__(self, *exc):
        _TAGS["node"], _TAGS["pivot"] = self.old
        return False


def tag(ob, lamp=None, node_name=None):
    """Writes the node tag of an object (and optionally its lamp channel, e.g. "ind", "head:0.8") while
    tagging is on. node_name overrides the current node ("none" = not part of the 3D model)."""
    if _TAGS["on"] and ob is not None:
        if node_name is not None:
            ob["ce_node"] = node_name
        elif ob.get("ce_node") is None:
            ob["ce_node"] = _TAGS["node"]
            if _TAGS["pivot"] is not None:
                ob["ce_pivot"] = [float(v) for v in _TAGS["pivot"]]
        if lamp is not None:
            ob["ce_lamp"] = lamp
    return ob


def set_collection(col):
    global _COLLECTION
    _COLLECTION = col


def _link(ob, parent=None):
    col = _COLLECTION or bpy.context.scene.collection
    col.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return tag(ob)
'''),
])

patch("tools/blender/cesprites/textgeo.py", [
    ('''    ob = bpy.data.objects.new(name, me)
    rig.col.objects.link(ob)
    ob.parent = rig.root
    return ob
''', '''    ob = bpy.data.objects.new(name, me)
    rig.col.objects.link(ob)
    ob.parent = rig.root
    return MU.tag(ob)
'''),
])

patch("tools/blender/cesprites/props_road.py", [
    ('''    mat = M.finish(m, nb, tr.outputs[0], {"lights": col})
    bm = MU.bm_cyl(radius, 0.12, height, center=(apex[0], apex[1], apex[2] - height / 2), segs=20, caps=False)
    ob = MU.make(name, bm, mat, parent=rig.root, smooth=True)
    ob.visible_shadow = False
    return ob
''', '''    mat = M.tag(M.finish(m, nb, tr.outputs[0], {"lights": col}), "fx")
    bm = MU.bm_cyl(radius, 0.12, height, center=(apex[0], apex[1], apex[2] - height / 2), segs=20, caps=False)
    ob = MU.make(name, bm, mat, parent=rig.root, smooth=True)
    ob.visible_shadow = False
    # 3D models: the light volume is a sprite effect - real light pools replace it (manifest "lights")
    MU.tag(ob, node_name="none")
    return ob
'''),
])
