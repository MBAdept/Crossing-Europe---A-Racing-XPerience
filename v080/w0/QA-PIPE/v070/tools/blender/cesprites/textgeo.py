"""Text as mesh (Inter font shipped with Blender: Latin incl. accents + Cyrillic)."""
import math
import os

import bpy

from . import meshutil as MU


def font():
    path = os.path.join(bpy.utils.system_resource("DATAFILES"), "fonts", "Inter.woff2")
    return bpy.data.fonts.load(path, check_existing=True)


def text_mesh(rig, text, size, mat, bold=0.035, extrude=0.0012, name="txt", spacing=1.0):
    """Mesh object of the text (centred), local axes: reading +X, up +Y, facing +Z."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = text
    cu.font = font()
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.offset = bold * size
    cu.extrude = extrude
    cu.resolution_u = 3
    cu.space_character = spacing
    tmp = bpy.data.objects.new(name + "_curve", cu)
    rig.col.objects.link(tmp)
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(deps))
    bpy.data.objects.remove(tmp)
    me.materials.clear()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    rig.col.objects.link(ob)
    ob.parent = rig.root
    return ob


def width_of(ob):
    xs = [v.co.x for v in ob.data.vertices]
    return (max(xs) - min(xs)) if xs else 0.0


def fit(ob, max_w):
    w = width_of(ob)
    if w > max_w > 0:
        k = max_w / w
        ob.scale = (k, k, 1.0)


def place_side(ob, side, y, z, x, wrap=None, offset=0.004):
    """side=+1: right flank (reads rear->front), -1: left flank (reads front->rear)."""
    ob.location = (x, y, z)
    ob.rotation_euler = (math.pi / 2, 0.0, math.pi / 2 if side > 0 else -math.pi / 2)
    if wrap is not None:
        _wrap(ob, wrap, offset)


def place_rear(ob, x, z, y, wrap=None, offset=0.004):
    ob.location = (x, y, z)
    ob.rotation_euler = (math.pi / 2, 0.0, 0.0)
    if wrap is not None:
        _wrap(ob, wrap, offset)


def place_front(ob, x, z, y, wrap=None, offset=0.004):
    ob.location = (x, y, z)
    ob.rotation_euler = (math.pi / 2, 0.0, math.pi)
    if wrap is not None:
        _wrap(ob, wrap, offset)


def _wrap(ob, target, offset):
    m = ob.modifiers.new("wrap", "SHRINKWRAP")
    m.target = target
    m.wrap_method = "PROJECT"
    m.use_project_x = False
    m.use_project_y = False
    m.use_project_z = True
    m.use_negative_direction = True
    m.use_positive_direction = True
    m.offset = offset
