"""scratch: per-object topology sub-hashes of one sprite build. usage: python geo_dbg.py <base dir with cesprites> <set id>"""
import hashlib
import sys

base, sid = sys.argv[1], sys.argv[2]
sys.path.insert(0, base)
import bpy  # noqa
import numpy as np  # noqa
import render_all as RA  # noqa
from cesprites import catalog  # noqa
from cesprites import rig as R  # noqa

sets = {s["id"]: s for s in catalog.all_sets()}
rig = R.Rig(quick=True)
info = RA.build(rig, sets[sid])
rig.root.rotation_euler = (0.0, 0.0, 0.0)
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()
deps.update()
obs = [o for o in rig.root.children_recursive if o.type in ("MESH", "CURVE", "FONT", "SURFACE")]
obs.sort(key=lambda o: o.name)


def h(a):
    return hashlib.sha1(a).hexdigest()[:8]


for ob in obs:
    ev = ob.evaluated_get(deps)
    me = ev.to_mesh()
    nl = len(me.loops)
    lv = np.empty(nl, dtype=np.int32)
    me.loops.foreach_get("vertex_index", lv)
    npo = len(me.polygons)
    ls = np.empty(npo, dtype=np.int32)
    me.polygons.foreach_get("loop_start", ls)
    mi = np.empty(npo, dtype=np.int32)
    me.polygons.foreach_get("material_index", mi)
    sm = np.empty(npo, dtype=bool)
    me.polygons.foreach_get("use_smooth", sm)
    cn = np.empty(nl * 3, dtype=np.float32)
    me.corner_normals.foreach_get("vector", cn)
    flags = "%s|%s|%d|%d|%d|%s" % (ob.name, ob.type, int(ob.hide_render), int(ob.visible_shadow),
                                   int(ob.is_shadow_catcher), ob.parent.name if ob.parent else "")
    slots = ",".join(s.material.name if s.material else "-" for s in ob.material_slots)
    cnr = np.round(cn.astype(np.float64) * 1e4).astype(np.int32)
    print("OBJ %-40s v%-6d lv %s ls %s mi %s sm %s cn %s slots %s  mods %s" % (
        flags, len(me.vertices), h(lv.tobytes()), h(ls.tobytes()), h(mi.tobytes()), h(sm.astype(np.int8).tobytes()),
        h(cnr.tobytes()), slots, ",".join(m.type for m in ob.modifiers)))
    # canonical: every polygon as (vertex indices from its smallest index on, material, smooth, corner normals
    # in that order); polygons sorted
    lt = np.empty(npo, dtype=np.int32)
    me.polygons.foreach_get("loop_total", lt)
    rows = []
    cn3 = cnr.reshape(-1, 3)
    for i in range(npo):
        a, k = int(ls[i]), int(lt[i])
        vs = lv[a:a + k]
        r = int(np.argmin(vs))
        # ties cannot happen: a polygon never uses a vertex twice
        order = [(r + j) % k for j in range(k)]
        rows.append((tuple(int(vs[j]) for j in order), int(mi[i]), int(sm[i]),
                     tuple(tuple(int(x) for x in cn3[a + j]) for j in order)))
    rows.sort()
    print("   canonical %s  faces %d  first %s" % (hashlib.sha1(repr(rows).encode()).hexdigest()[:12], npo, rows[0][0]))
    if len(sys.argv) > 3 and sys.argv[3] == ob.name:
        np.save(sys.argv[4], cn.reshape(-1, 3))
    ev.to_mesh_clear()
