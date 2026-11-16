"""Hook patch 2: landmarks - material tag of Shade.finish, all-round windows of the Michel."""
from patchlib import patch

patch("tools/blender/cesprites/props_landmarks.py", [
    ('''        o = nb.node("ShaderNodeOutputMaterial")
        nb.links.new(res, o.inputs["Surface"])
        return self.m
''', '''        o = nb.node("ShaderNodeOutputMaterial")
        nb.links.new(res, o.inputs["Surface"])
        return M.tag(self.m, "proc")          # 3D pipeline: baked into the atlas (ce3d/roles.py)
'''),
    ('''    br.grid("left", (-44.0, 0.0), (11.5, 21.0), (6.4, 12.0), (2.8, 9.0), seed=2, **kw)
    br.grid("left", (-44.0, 0.0), (3.0, 7.6), (6.4, 6.0), (2.2, 4.2), seed=3, **kw)
''', '''    br.grid("left", (-44.0, 0.0), (11.5, 21.0), (6.4, 12.0), (2.8, 9.0), seed=2, **kw)
    br.grid("left", (-44.0, 0.0), (3.0, 7.6), (6.4, 6.0), (2.2, 4.2), seed=3, **kw)
    allround = bool(p.get("allround"))
    if allround:
        # 3D model (ce3d): the sides the sprite never shows get the same windows
        br.grid("back", (-31.0, 27.0), (11.5, 21.0), (6.4, 12.0), (2.8, 9.0), seed=4, **kw)
        br.grid("back", (-31.0, 27.0), (3.0, 7.6), (6.4, 6.0), (2.2, 4.2), seed=5, **kw)
        br.grid("right", (0.0, 44.0), (11.5, 21.0), (6.4, 12.0), (2.8, 9.0), seed=6, **kw)
        br.grid("right", (0.0, 44.0), (3.0, 7.6), (6.4, 6.0), (2.2, 4.2), seed=7, **kw)
'''),
    ('''    for i, face in enumerate(("front", "left", "back")):
        tb.grid(face, (-200.0, 200.0), (30.0, 52.0), (14.0, 11.0), (2.4, 8.0), lit=0.0, glass="#2a2f33",
                frame="#dccdaa", frame_w=0.4, arch=True, seed=i)
''', '''    for i, face in enumerate(("front", "left", "back") + (("right",) if allround else ())):
        tb.grid(face, (-200.0, 200.0), (30.0, 52.0), (14.0, 11.0), (2.4, 8.0), lit=0.0, glass="#2a2f33",
                frame="#dccdaa", frame_w=0.4, arch=True, seed=i)
'''),
])
