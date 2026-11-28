# K8: render a cached GLB (before/after) from four sides with Workbench (texture colour, flat light) - quick look only
import sys, math
import bpy
from mathutils import Vector
glb, out = sys.argv[-2], sys.argv[-1]
import os
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
d = os.path.dirname(glb)
alb = [f for f in os.listdir(d) if f.startswith("albedo")][0]
img = bpy.data.images.load(os.path.join(d, alb))
mat = bpy.data.materials.new("alb")
mat.use_nodes = True
nt = mat.node_tree
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = img
nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
nt.nodes.active = tex
for o in objs:
    if o.data.uv_layers:
        o.data.materials.clear()
        o.data.materials.append(mat)
# keep lod0 only (names carry the level)
for o in objs:
    if os.environ.get('MESH') and o.name != os.environ.get('MESH'):
        o.hide_render = True
vis = [o for o in objs if not o.hide_render]
mn = Vector((1e9, 1e9, 1e9)); mx = Vector((-1e9, -1e9, -1e9))
for o in vis:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
ctr = (mn + mx) / 2
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'FLAT'
sc.display.shading.color_type = 'TEXTURE'
sc.render.resolution_x, sc.render.resolution_y = 900, 700
sc.render.film_transparent = False
sc.world = bpy.data.worlds.new("w")
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 28
r = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z) * 1.6
print("bounds", tuple(mn), tuple(mx))
for name, ang in (("a", 45), ("b", 135), ("c", 225), ("d", 315)):
    a = math.radians(ang)
    cam.location = ctr + Vector((math.cos(a) * r, math.sin(a) * r, (mx.z - mn.z) * 0.15))
    d = ctr - cam.location
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = out + "_" + name + ".png"
    bpy.ops.render.render(write_still=True)
