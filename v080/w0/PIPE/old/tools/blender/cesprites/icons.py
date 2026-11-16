"""Small UI icons (weather and daytime) as stylised 3D shapes, front view, 96x96, dark outline."""
import math

import bmesh
from mathutils import Vector

from . import materials as M
from . import meshutil as MU

ICONS = ["weather_normal", "weather_rain", "weather_snow", "daytime_day", "daytime_night", "daytime_dawn",
         "daytime_dusk"]


def icon_sets():
    out = []
    for name in ICONS:
        out.append(dict(
            id="ui/" + name, builder="icon", params=dict(name=name), paint=[],
            camera=dict(mode="icon", cell=(96, 96), elevation=0.0, pad=0.07),
            layers=["base"], glow={}, tags=["ui", "icon"], shadow=0.0, fade_px=0.0,
            outline=dict(px=2, color=(0.07, 0.08, 0.1), strength=0.9)))
    return out


def _mat(name, color, rough=0.35, glow=0.0):
    mat = M.basic(name, color, rough=rough, spec=0.5, coat=0.3, sheen=0.2)
    if glow > 0:
        b = [n for n in mat.node_tree.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"][0]
        b.inputs["Emission Color"].default_value = M.srgb(color)
        b.inputs["Emission Strength"].default_value = glow
    return mat


def sun(rig, center, r, color="#ffc21a", ray_color="#ff9d0a", rays=8, ray_len=0.55, half=False, name="sun"):
    body = _mat(name + "_body", color, glow=0.45)
    rmat = _mat(name + "_ray", ray_color, glow=0.3)
    cx, cy, cz = center
    bm = MU.bm_sphere(r, center=center, subdiv=3, scale=(1.0, 0.5, 1.0))
    MU.make(name, bm, body, parent=rig.root, smooth=True)
    bm = bmesh.new()
    for k in range(rays):
        a = 2 * math.pi * k / rays + (math.pi / rays if half else 0.0)
        if half and math.sin(a) < -0.05:
            continue
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        base = Vector(center) + d * (r * 1.18)
        tip = Vector(center) + d * (r * (1.18 + ray_len))
        res = bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=r * 0.2, radius2=0.0,
                                    depth=(tip - base).length)
        rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
        from mathutils import Matrix
        bmesh.ops.transform(bm, matrix=Matrix.Translation((base + tip) / 2) @ rot @ Matrix.Diagonal((1, 0.5, 1, 1)),
                            verts=res["verts"])
    MU.make(name + "_rays", bm, rmat, parent=rig.root, smooth=True, sharp_deg=50)


def cloud(rig, center, scale, color="#f4f6f8", name="cloud"):
    mat = _mat(name, color, rough=0.5)
    cx, cy, cz = center
    bm = bmesh.new()
    for (dx, dz, r) in ((-0.55, 0.0, 0.42), (0.0, 0.22, 0.58), (0.55, 0.02, 0.45), (0.22, -0.12, 0.4), (-0.25, -0.14, 0.38)):
        MU.bm_sphere(r * scale, center=(cx + dx * scale, cy, cz + dz * scale), subdiv=3, scale=(1.0, 0.55, 1.0), bm=bm)
    MU.bm_sphere(0.5 * scale, center=(cx, cy, cz - 0.08 * scale), subdiv=3, scale=(1.7, 0.55, 0.55), bm=bm)
    ob = MU.make(name, bm, mat, parent=rig.root, smooth=True)
    MU.bevel(ob, 0.08 * scale, 3)
    return ob


def drop(rig, center, s, mat, name="drop"):
    prof = [(0.0, -1.0), (0.45, -0.85), (0.62, -0.5), (0.5, -0.05), (0.25, 0.45), (0.0, 0.9)]
    bm = MU.bm_lathe([(r * s, h * s) for r, h in prof], segs=16, center=center)
    for v in bm.verts:
        v.co.y = center[1] + (v.co.y - center[1]) * 0.6
    MU.make(name, bm, mat, parent=rig.root, smooth=True)


def flake(rig, center, s, mat, name="flake"):
    bm = bmesh.new()
    c = Vector(center)
    for k in range(6):
        a = math.pi / 6 + 2 * math.pi * k / 6
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        n = Vector((-d.z, 0.0, d.x))
        MU.bm_beam(c, c + d * s, s * 0.16, s * 0.12, bm=bm, up=(0, 1, 0))
        for t in (0.55,):
            p = c + d * s * t
            MU.bm_beam(p, p + (d + n) * s * 0.28, s * 0.12, s * 0.1, bm=bm, up=(0, 1, 0))
            MU.bm_beam(p, p + (d - n) * s * 0.28, s * 0.12, s * 0.1, bm=bm, up=(0, 1, 0))
    ob = MU.make(name, bm, mat, parent=rig.root)
    MU.bevel(ob, s * 0.03, 2)


def moon(rig, center, r, name="moon"):
    mat = _mat(name, "#f3e7a8", glow=0.3)
    bm = MU.bm_sphere(r, center=center, subdiv=4, scale=(1.0, 0.5, 1.0))
    ob = MU.make(name, bm, mat, parent=rig.root, smooth=True)
    cut = MU.make(name + "_cut", MU.bm_sphere(r * 0.86, center=(center[0] + r * 0.5, center[1] - 0.1, center[2] + r * 0.28),
                                               subdiv=4, scale=(1.0, 2.0, 1.0)), mat, parent=rig.root, smooth=True)
    cut.hide_render = True
    m = ob.modifiers.new("cut", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.object = cut
    m.solver = "EXACT"


def star(rig, center, s, mat, name="star"):
    pts = []
    for k in range(10):
        a = math.pi / 2 + 2 * math.pi * k / 10
        rr = s if k % 2 == 0 else s * 0.45
        pts.append((center[0] + math.cos(a) * rr, center[2] + math.sin(a) * rr))
    bm = bmesh.new()
    front = [bm.verts.new((x, center[1] - s * 0.15, z)) for (x, z) in pts]
    back = [bm.verts.new((x, center[1] + s * 0.15, z)) for (x, z) in pts]
    cf = bm.verts.new((center[0], center[1] - s * 0.3, center[2]))
    cb = bm.verts.new((center[0], center[1] + s * 0.3, center[2]))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], cf))
        bm.faces.new((back[j], back[i], cb))
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    MU.make(name, bm, mat, parent=rig.root, smooth=True, sharp_deg=40)


def horizon(rig, z, color, name="horizon"):
    mat = _mat(name, color, rough=0.5)
    bm = MU.bm_box(2.9, 0.6, 0.22, (0.0, 0.0, z))
    ob = MU.make(name, bm, mat, parent=rig.root)
    MU.bevel(ob, 0.08, 3)


def chevron(rig, center, s, up, color, name="chev"):
    mat = _mat(name, color, rough=0.45)
    c = Vector(center)
    k = 1 if up else -1
    bm = bmesh.new()
    MU.bm_beam(c + Vector((-s, 0, -k * s * 0.5)), c + Vector((0, 0, k * s * 0.5)), s * 0.32, s * 0.3, bm=bm, up=(0, 1, 0))
    MU.bm_beam(c + Vector((s, 0, -k * s * 0.5)), c + Vector((0, 0, k * s * 0.5)), s * 0.32, s * 0.3, bm=bm, up=(0, 1, 0))
    ob = MU.make(name, bm, mat, parent=rig.root)
    MU.bevel(ob, s * 0.08, 2)


def half_sun(rig, z, r, color, ray):
    """Upper half of a sun sitting on the horizon (cut by a boolean box)."""
    sun(rig, (0.0, 0.0, z), r, color=color, ray_color=ray, half=True, name="hsun")
    import bpy
    ob = bpy.data.objects["hsun"]
    cutter = MU.make("hsun_cut", MU.bm_box(3.0, 3.0, 2.0, (0.0, 0.0, z - 1.0)), ob.data.materials[0], parent=rig.root)
    cutter.hide_render = True
    m = ob.modifiers.new("cut", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.object = cutter
    m.solver = "EXACT"


def build(rig, p):
    n = p["name"]
    if n == "daytime_day":
        sun(rig, (0.0, 0.0, 0.0), 0.62)
    elif n == "weather_normal":
        sun(rig, (0.35, 0.3, 0.35), 0.5, ray_len=0.45)
        cloud(rig, (-0.3, -0.25, -0.35), 0.82)
    elif n == "weather_rain":
        cloud(rig, (0.0, 0.0, 0.42), 1.0, color="#aeb8c4", name="rcloud")
        dm = _mat("raindrop", "#3f8ff0", rough=0.15)
        for (x, z) in ((-0.55, -0.55), (0.0, -0.75), (0.55, -0.55)):
            drop(rig, (x, -0.1, z), 0.24, dm, name="drop")
    elif n == "weather_snow":
        cloud(rig, (0.0, 0.0, 0.42), 1.0, color="#c9d1da", name="scloud")
        fm = _mat("snowflake", "#ffffff", rough=0.4)
        for (x, z, s) in ((-0.58, -0.6, 0.26), (0.05, -0.78, 0.3), (0.62, -0.55, 0.24)):
            flake(rig, (x, -0.2, z), s, fm, name="flake")
    elif n == "daytime_night":
        moon(rig, (-0.12, 0.0, 0.0), 0.72)
        sm = _mat("nstar", "#fff4c4", rough=0.3, glow=0.5)
        star(rig, (0.62, -0.1, 0.55), 0.2, sm, name="star1")
        star(rig, (0.55, -0.1, -0.35), 0.13, sm, name="star2")
    elif n == "daytime_dawn":
        half_sun(rig, -0.2, 0.62, "#ffab3a", "#ff7b1a")
        horizon(rig, -0.3, "#4a5f8f")
        chevron(rig, (0.0, -0.3, -0.75), 0.28, True, "#ffcf6a")
    elif n == "daytime_dusk":
        half_sun(rig, -0.2, 0.62, "#ff6a3a", "#d8434a")
        horizon(rig, -0.3, "#4b3a6e")
        chevron(rig, (0.0, -0.3, -0.75), 0.28, False, "#ffa070")
    return dict(object={"width_m": 1.0, "height_m": 1.0})
