# Debug: triangles of the police words at several curve resolutions
import sys
sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3/tools/blender")
import bpy
from cesprites import catalog, textgeo
from cesprites import rig as RG

rig = RG.Rig(quick=True)
for word in sorted({p["word"] for p in catalog.POLICE.values()}):
    row = []
    for res in (1, 2, 3):
        cu = bpy.data.curves.new("t", "FONT")
        cu.body = word
        cu.font = textgeo.font()
        cu.size = 0.16
        cu.offset = 0.035 * 0.16
        cu.resolution_u = res
        ob = bpy.data.objects.new("t", cu)
        rig.col.objects.link(ob)
        deps = bpy.context.evaluated_depsgraph_get()
        deps.update()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(deps))
        me.calc_loop_triangles()
        row.append((res, len(me.loop_triangles), len(me.vertices), round(max(v.co.x for v in me.vertices) - min(v.co.x for v in me.vertices), 3)))
        bpy.data.objects.remove(ob)
    print(word, row)
