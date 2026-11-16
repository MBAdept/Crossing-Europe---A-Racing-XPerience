"""bmesh helpers. All units are metres, Z is up, vehicles point to +Y (camera behind at -Y)."""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

_COLLECTION = None


def set_collection(col):
    global _COLLECTION
    _COLLECTION = col


def _link(ob, parent=None):
    col = _COLLECTION or bpy.context.scene.collection
    col.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return ob


def empty(name, parent=None, loc=(0, 0, 0)):
    ob = bpy.data.objects.new(name, None)
    ob.location = loc
    return _link(ob, parent)


def make(name, bm, mats, parent=None, smooth=False, sharp_deg=35.0, loc=None, rot=None):
    """Creates an object from a bmesh. mats: material or list (face.material_index selects)."""
    if not isinstance(mats, (list, tuple)):
        mats = [mats]
    me = bpy.data.meshes.new(name)
    if smooth:
        for f in bm.faces:
            f.smooth = True
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    if smooth:
        me.set_sharp_from_angle(angle=math.radians(sharp_deg))
    ob = bpy.data.objects.new(name, me)
    if loc is not None:
        ob.location = loc
    if rot is not None:
        ob.rotation_euler = rot
    return _link(ob, parent)


# --- primitives as bmesh ------------------------------------------------------------------------

def bm_box(sx, sy, sz, center=(0, 0, 0), bm=None, mat_index=0):
    """Axis-aligned box (full sizes) into bm (new bmesh if None)."""
    bm = bm or bmesh.new()
    res = bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(Vector(center)) @ Matrix.Diagonal((sx, sy, sz, 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=res["verts"])
    for v in res["verts"]:
        for f in v.link_faces:
            f.material_index = mat_index
    return bm


def bm_cyl(r1, r2, depth, center=(0, 0, 0), axis="Z", segs=16, bm=None, mat_index=0, caps=True):
    """Cylinder/cone along an axis, centred at center."""
    bm = bm or bmesh.new()
    res = bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=depth)
    rot = Matrix.Identity(4)
    if axis == "X":
        rot = Matrix.Rotation(math.pi / 2, 4, "Y")
    elif axis == "Y":
        rot = Matrix.Rotation(-math.pi / 2, 4, "X")
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(center)) @ rot, verts=res["verts"])
    for v in res["verts"]:
        for f in v.link_faces:
            f.material_index = mat_index
    return bm


def bm_sphere(r, center=(0, 0, 0), scale=(1, 1, 1), subdiv=2, bm=None, mat_index=0, uv=None):
    bm = bm or bmesh.new()
    if uv:
        res = bmesh.ops.create_uvsphere(bm, u_segments=uv[0], v_segments=uv[1], radius=r)
    else:
        res = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    m = Matrix.Translation(Vector(center)) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=res["verts"])
    for v in res["verts"]:
        for f in v.link_faces:
            f.material_index = mat_index
    return bm


def bm_beam(p1, p2, w, h=None, bm=None, mat_index=0, up=(0, 0, 1)):
    """Box beam between two points with cross-section w x h."""
    bm = bm or bmesh.new()
    h = w if h is None else h
    a, b = Vector(p1), Vector(p2)
    d = b - a
    length = d.length
    if length < 1e-6:
        return bm
    z = d.normalized()
    upv = Vector(up)
    if abs(z.dot(upv)) > 0.95:
        upv = Vector((1, 0, 0))
    x = upv.cross(z).normalized()
    y = z.cross(x)
    m = Matrix((
        (x.x, y.x, z.x, 0.0),
        (x.y, y.y, z.y, 0.0),
        (x.z, y.z, z.z, 0.0),
        (0.0, 0.0, 0.0, 1.0))).normalized()
    res = bmesh.ops.create_cube(bm, size=1.0)
    mm = Matrix.Translation((a + b) * 0.5) @ m.to_4x4() @ Matrix.Diagonal((w, h, length, 1.0))
    bmesh.ops.transform(bm, matrix=mm, verts=res["verts"])
    for v in res["verts"]:
        for f in v.link_faces:
            f.material_index = mat_index
    return bm


def bm_lathe(profile, segs=24, bm=None, mat_index=0, axis="Z", center=(0, 0, 0), close=True):
    """Revolves a profile [(r, h), ...] around an axis (default Z, h along the axis)."""
    bm = bm or bmesh.new()
    rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        ring = []
        for (r, h) in profile:
            ring.append(Vector((r * math.cos(a), r * math.sin(a), h)))
        rings.append(ring)
    verts = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(profile)
    for i in range(segs):
        a, b = verts[i], verts[(i + 1) % segs]
        for k in range(n - 1):
            try:
                f = bm.faces.new((a[k], b[k], b[k + 1], a[k + 1]))
                f.material_index = mat_index
            except ValueError:
                pass
    allv = [v for ring in verts for v in ring]
    bmesh.ops.remove_doubles(bm, verts=allv, dist=1e-6)
    allv = [v for v in allv if v.is_valid]
    rot = Matrix.Identity(4)
    if axis == "X":
        rot = Matrix.Rotation(math.pi / 2, 4, "Y")
    elif axis == "Y":
        rot = Matrix.Rotation(-math.pi / 2, 4, "X")
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(center)) @ rot, verts=allv)
    return bm


def loft(rings, bm=None, cap0=True, cap1=True, mat_index=0):
    """Connects closed rings (lists of 3D points, equal length) with quads; optional n-gon caps."""
    bm = bm or bmesh.new()
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    faces = []
    for a, b in zip(vr[:-1], vr[1:]):
        for i in range(n):
            j = (i + 1) % n
            try:
                faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
            except ValueError:
                pass
    if cap0:
        faces.append(bm.faces.new(list(reversed(vr[0]))))
    if cap1:
        faces.append(bm.faces.new(vr[-1]))
    for f in faces:
        f.material_index = mat_index
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return bm


def mirror_ring(half):
    """half: [(x, z)] from bottom centre (x=0) over +x to top centre (x=0). Returns full closed ring."""
    ring = list(half)
    for (x, z) in reversed(half[1:-1]):
        ring.append((-x, z))
    return ring


def prism(points2d, depth, bm=None, mat_index=0, plane="XZ", offset=0.0):
    """Extrudes a 2D polygon (counter-clockwise) along the plane normal.
    plane XZ: points (x, z), extruded along +Y from offset to offset+depth.
    plane YZ: points (y, z), extruded along +X. plane XY: points (x, y), extruded along +Z."""
    bm = bm or bmesh.new()

    def to3(p, d):
        if plane == "XZ":
            return Vector((p[0], d, p[1]))
        if plane == "YZ":
            return Vector((d, p[0], p[1]))
        return Vector((p[0], p[1], d))

    a = [bm.verts.new(to3(p, offset)) for p in points2d]
    b = [bm.verts.new(to3(p, offset + depth)) for p in points2d]
    faces = [bm.faces.new(a), bm.faces.new(list(reversed(b)))]
    n = len(points2d)
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((a[i], b[i], b[j], a[j])))
    for f in faces:
        f.material_index = mat_index
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return bm


def flat_polygon(points3d, bm=None, mat_index=0, subdiv=0):
    bm = bm or bmesh.new()
    vs = [bm.verts.new(p) for p in points3d]
    f = bm.faces.new(vs)
    f.material_index = mat_index
    if subdiv > 0:
        res = bmesh.ops.triangulate(bm, faces=[f])
        edges = list({e for ff in res["faces"] for e in ff.edges})
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=subdiv, use_grid_fill=True)
    return bm


def rounded_rect(w, h, r, n=4, cx=0.0, cy=0.0):
    """2D rounded rectangle points (counter-clockwise), full width w, height h, corner radius r."""
    r = min(r, w * 0.5 - 1e-4, h * 0.5 - 1e-4)
    pts = []
    corners = [(w / 2 - r, -h / 2 + r, -90), (w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180)]
    for (x, y, a0) in corners:
        for i in range(n + 1):
            a = math.radians(a0 + 90.0 * i / n)
            pts.append((cx + x + r * math.cos(a), cy + y + r * math.sin(a)))
    return pts


def ellipse_pts(rx, ry, n=24, cx=0.0, cy=0.0):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]


# --- modifiers ----------------------------------------------------------------------------------

def bevel(ob, width, segments=2, angle_deg=30.0):
    m = ob.modifiers.new("bevel", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(angle_deg)
    m.harden_normals = False
    return m


def shrinkwrap_onto(ob, target, axis="Y", positive=True, negative=True, offset=0.004):
    m = ob.modifiers.new("wrap", "SHRINKWRAP")
    m.target = target
    m.wrap_method = "PROJECT"
    m.use_project_x = axis == "X"
    m.use_project_y = axis == "Y"
    m.use_project_z = axis == "Z"
    m.use_negative_direction = negative
    m.use_positive_direction = positive
    m.offset = offset
    return m


def solidify(ob, thickness, offset=1.0):
    m = ob.modifiers.new("solid", "SOLIDIFY")
    m.thickness = thickness
    m.offset = offset
    return m


def displace(ob, strength, size=0.5, kind="CLOUDS", depth=2, seed=0, mid=0.5, direction="NORMAL"):
    tex = bpy.data.textures.new(ob.name + "_tx", kind)
    if kind == "CLOUDS":
        tex.noise_scale = size
        tex.noise_depth = depth
        tex.noise_basis = "ORIGINAL_PERLIN" if seed % 2 == 0 else "IMPROVED_PERLIN"
    elif kind == "VORONOI":
        tex.noise_scale = size
    m = ob.modifiers.new("disp", "DISPLACE")
    m.texture = tex
    m.strength = strength
    m.mid_level = mid
    m.direction = direction
    m.texture_coords = "GLOBAL" if seed == 0 else "OBJECT"
    return m


def subsurf(ob, levels=1):
    m = ob.modifiers.new("subd", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    return m


def smooth_obj(ob, deg=35.0):
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.data.set_sharp_from_angle(angle=math.radians(deg))
