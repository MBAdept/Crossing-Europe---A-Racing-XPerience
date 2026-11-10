import os, sys
REPO = "/home/user/crossing-europe---a-racing-xperience"
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from mathutils import geometry as mgeo
# semantics test: two overlapping squares
v = [Vector(p) for p in [(0,0),(2,0),(2,2),(0,2),(0.5,0.5),(1.5,0.5),(1.5,1.5),(0.5,1.5)]]
out = mgeo.delaunay_2d_cdt(v, [], [[0,1,2,3],[4,5,6,7]], 1, 1e-6)
print("faces", len(out[2]), "orig_faces", out[5])
from cesprites import rig as R, designs, vehicles, materials as M
from ce3d import decalgeo, core
rig = R.Rig(quick=True)
car = vehicles.Car(rig, designs.TRAFFIC_MODELS["sedan"], paint="#b52424", metal=0.3, name="sedan").build()
for d in car.body_decals():
    print({k: (v if k != "poly" else "poly%d" % len(v)) for k, v in d.items()})
st = decalgeo.convert(rig, car, res=0.03, body_dissolve_deg=2.0)
for o in rig.root.children:
    if "_dg_" in o.name:
        import collections
        c = collections.Counter(p.material_index for p in o.data.polygons)
        print(o.name, [(o.material_slots[i].material.name, n, [round(x,3) for x in core.mat_info(o.material_slots[i].material)["color"][:3]], core.mat_info(o.material_slots[i].material)["emit"]) for i, n in sorted(c.items())])
print("---- bumpers")
import collections
deps = bpy.context.evaluated_depsgraph_get(); deps.update()
for o in rig.root.children:
    if "bumper" in o.name and "_dg_" not in o.name or o.name.endswith("_lower"):
        c = collections.Counter(p.material_index for p in o.data.polygons)
        ev = o.evaluated_get(deps); me = ev.to_mesh()
        c2 = collections.Counter(p.material_index for p in me.polygons)
        zs = [v.co.z for v in o.data.vertices]
        print(o.name, "base", dict(c), "eval", dict(c2), [s.material.name for s in o.material_slots], "z", round(min(zs),3), round(max(zs),3), [m.type for m in o.modifiers], car.d["bumper"])
        ev.to_mesh_clear()
