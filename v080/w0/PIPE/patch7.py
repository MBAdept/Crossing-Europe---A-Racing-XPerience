"""Hook patch 7: player cars - drop patch triangles on surfaces that turn away from the projection (3D only)."""
from patchlib import patch

patch("tools/blender/cesprites/carbody.py", [
    ('''#   extras   lamp parts only the real-time models have (indicators, reverse light)
DETAIL = dict(ring=1.0, step=1.0, res=1.0, off=1.0, min_off=0.0, wheel=1.0, extras=False)''',
     '''#   extras   lamp parts only the real-time models have (indicators, reverse light)
#   graze    patches end where the body turns away from their projection: triangles on surface whose
#            normal is at less than this cosine to the projection axis are dropped. The sprites show such
#            stretched triangles edge-on (0 = keep them); seen from the side they are streaks on the flank
DETAIL = dict(ring=1.0, step=1.0, res=1.0, off=1.0, min_off=0.0, wheel=1.0, extras=False, graze=0.0)'''),
    ('''        vmap = {}
        for fi in faces:
            if any(hits[i] is None for i in fi):
                continue
            vs = []
            for i in fi:
                if i not in vmap:
                    loc, nor = hits[i]
                    vmap[i] = bm.verts.new(loc + nor * offset)
                vs.append(vmap[i])
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            f.material_index = 0
        bm.normal_update()''',
     '''        vmap = {}
        graze = self.detail["graze"]
        axis = {"rear": Vector((0.0, 1.0, 0.0)), "front": Vector((0.0, -1.0, 0.0)), "side": Vector((-sgn, 0.0, 0.0)),
                "top": Vector((0.0, 0.0, -1.0))}[proj]
        for fi in faces:
            if any(hits[i] is None for i in fi):
                continue
            if graze > 0.0 and min(abs(hits[i][1].dot(axis)) for i in fi) < graze:
                continue
            vs = []
            for i in fi:
                if i not in vmap:
                    loc, nor = hits[i]
                    vmap[i] = bm.verts.new(loc + nor * offset)
                vs.append(vmap[i])
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            f.material_index = 0
        bm.normal_update()'''),
])

patch("tools/blender/ce3d/lod.py", [
    ('''    "show": dict(ring=0.6, step=2.0, res=2.0, off=1.5, wheel=0.75, min_off=0.0),''',
     '''    "show": dict(ring=0.6, step=2.0, res=2.0, off=1.5, wheel=0.75, min_off=0.0, graze=0.22),'''),
    ('''    "lod0": dict(ring=0.4, step=3.5, res=3.5, off=2.5, wheel=0.5, min_off=0.0015),''',
     '''    "lod0": dict(ring=0.4, step=3.5, res=3.5, off=2.5, wheel=0.5, min_off=0.0015, graze=0.22),'''),
    ('''#   wheel  segments of the lathed wheel parts                       min_off  smallest patch height (m)''',
     '''#   wheel  segments of the lathed wheel parts                       min_off  smallest patch height (m)
#   graze  patches end where the body turns away from their projection (cosine; sprites: 0 = never)'''),
])
