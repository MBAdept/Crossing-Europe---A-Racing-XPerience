"""Detail builders for carbody.SmoothCar: wheels, glass, lamps, plates, exhausts, diffusers, spoilers,
wings, mirrors, roof rails, badges and seams. Units metres, vehicle space of carbody (y = 0 at the rear)."""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

from . import curves as C
from . import materials as M
from . import meshutil as MU
from . import textgeo

TAIL_RED = "#ff1a0e"
BRAKE_RED = "#ff2414"


# ---------------------------------------------------------------------------------------------- wheels

def _tyre_profile(R, r_rim, tw):
    """(r, x) lathe profile of a tyre, x across the tread (-tw/2 inner .. +tw/2 outer)."""
    h = R - r_rim
    p = [(r_rim + 0.006, -tw / 2 + 0.014), (r_rim + 0.02, -tw / 2 - 0.002), (r_rim + h * 0.45, -tw / 2 - 0.008),
         (R - h * 0.22, -tw / 2 - 0.004), (R - 0.012, -tw / 2 + 0.006), (R - 0.002, -tw / 2 + 0.022)]
    # tread with three circumferential grooves
    xs = [-tw / 2 + 0.036, -0.30 * tw, -0.30 * tw + 0.012, -0.05 * tw, -0.05 * tw + 0.012, 0.22 * tw,
          0.22 * tw + 0.012, tw / 2 - 0.036]
    tread = []
    for i, x in enumerate(xs):
        r = R if i in (0, 7) else R
        tread.append((r, x))
    # grooves: dips between pairs (1,2), (3,4), (5,6)
    out = list(p)
    out.append((R, xs[0]))
    for (a, b) in ((1, 2), (3, 4), (5, 6)):
        out += [(R, xs[a]), (R - 0.007, xs[a] + 0.002), (R - 0.007, xs[b] - 0.002), (R, xs[b])]
    out.append((R, xs[7]))
    out += [(R - 0.002, tw / 2 - 0.022), (R - 0.012, tw / 2 - 0.006), (R - h * 0.22, tw / 2 + 0.004),
            (r_rim + h * 0.45, tw / 2 + 0.008), (r_rim + 0.02, tw / 2 + 0.002), (r_rim + 0.006, tw / 2 - 0.014)]
    return out


def _lathe_x(bm, prof, segs, mat_index=0, a0=0.0, a1=360.0, closed=True):
    """Revolve (r, x) about the X axis into bm."""
    n = segs if closed else segs + 1
    rings = []
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * i / segs)
        rings.append([bm.verts.new((x, r * math.cos(a), r * math.sin(a))) for (r, x) in prof])
    m = len(prof)
    for i in range(segs if closed else segs):
        A, B = rings[i], rings[(i + 1) % n]
        for k in range(m - 1):
            try:
                f = bm.faces.new((A[k], A[k + 1], B[k + 1], B[k]))
                f.material_index = mat_index
                f.smooth = True
            except ValueError:
                pass
    return rings


def wheel_mesh(name, R, r_rim, tw, st, mats):
    """One wheel (tyre, rim, spokes, disc, caliper) in local space: axis X, outer face towards +X,
    centre at the origin. mats: dict tyre, rim, rim_dark, disc, caliper. Returns a list of objects."""
    objs = []
    # tyre
    bm = bmesh.new()
    _lathe_x(bm, _tyre_profile(R, r_rim, tw), 64)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name + "_tyre")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mats["tyre"])
    me.set_sharp_from_angle(angle=math.radians(50))
    objs.append(me)
    # rim: barrel (dark) + polished lip + spokes + hub
    xo = tw / 2 - 0.012              # outer face of the lip
    bm = bmesh.new()
    barrel = [(r_rim - 0.012, xo - 0.03), (r_rim - 0.012, -tw / 2 + 0.03), (r_rim * 0.5, -tw / 2 + 0.03)]
    _lathe_x(bm, barrel, 48, mat_index=1)
    lip = [(r_rim + 0.012, xo - 0.016), (r_rim + 0.014, xo - 0.004), (r_rim + 0.006, xo + 0.002),
           (r_rim - 0.012, xo + 0.001), (r_rim - 0.02, xo - 0.006), (r_rim - 0.018, xo - 0.03)]
    _lathe_x(bm, lip, 64, mat_index=0)
    dish = st.get("dish", 0.03)
    r0, r1 = st.get("hub_r", 0.07), r_rim - 0.016
    n = st.get("spokes", 5)
    kind = st.get("kind", "straight")
    w0, w1 = st.get("spoke_w", (0.045, 0.03))
    depth = st.get("spoke_depth", 0.03)

    def face_x(r):
        t = (r - r0) / max(1e-6, (r1 - r0))
        return xo - 0.004 - dish * (1.0 - t) ** 1.4

    def spoke(angle_deg, wa, wb, ra=r0, rb=r1, bend=0.0, twist=0.0):
        k = 7
        rings = []
        for i in range(k + 1):
            t = i / k
            r = ra + (rb - ra) * t
            w = wa + (wb - wa) * t
            ang = math.radians(angle_deg + bend * t * t)
            ca, sa = math.cos(ang), math.sin(ang)
            xf = face_x(r)
            ring = []
            for (tt, dx) in ((-w / 2, 0.0), (w / 2, 0.0), (w / 2 * 0.8, -depth), (-w / 2 * 0.8, -depth)):
                # radial r along (ca, sa) in the (y, z) plane, tangential tt along (-sa, ca)
                yy = r * ca - tt * sa
                zz = r * sa + tt * ca
                ring.append(bm.verts.new((xf + dx, yy, zz)))
            rings.append(ring)
        for a, b in zip(rings[:-1], rings[1:]):
            for j in range(4):
                jj = (j + 1) % 4
                f = bm.faces.new((a[j], a[jj], b[jj], b[j]))
                f.material_index = 0
                f.smooth = True
        bm.faces.new(list(reversed(rings[0]))).material_index = 0
        bm.faces.new(rings[-1]).material_index = 0

    for i in range(n):
        a = 360.0 * i / n + st.get("phase", 90.0)
        if kind == "straight":
            spoke(a, w0, w1)
        elif kind == "twin":
            gap = st.get("twin_gap", 7.0)
            spoke(a - gap / 2, w0 * 0.55, w1 * 0.55)
            spoke(a + gap / 2, w0 * 0.55, w1 * 0.55)
        elif kind == "y":
            rm = r0 + (r1 - r0) * 0.45
            spoke(a, w0, w0 * 0.8, r0, rm)
            spoke(a - 6.0, w1 * 0.6, w1 * 0.55, rm - 0.01, r1, bend=-6.0)
            spoke(a + 6.0, w1 * 0.6, w1 * 0.55, rm - 0.01, r1, bend=6.0)
        elif kind == "turbine":
            spoke(a, w0, w1, bend=st.get("bend", 18.0))
    # hub + centre cap
    hub = [(0.0, face_x(r0) + 0.004), (r0 * 0.55, face_x(r0) + 0.003), (r0 * 0.9, face_x(r0) - 0.004),
           (r0 * 1.05, face_x(r0) - depth)]
    _lathe_x(bm, hub, 32, mat_index=0)
    # wheel nuts
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3
        MU.bm_cyl(0.011, 0.009, 0.012, center=(face_x(r0) - 0.002, math.cos(a) * r0 * 0.62, math.sin(a) * r0 * 0.62),
                  axis="X", segs=8, bm=bm, mat_index=1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name + "_rim")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mats["rim"])
    me.materials.append(mats["rim_dark"])
    me.set_sharp_from_angle(angle=math.radians(40))
    objs.append(me)
    # brake disc + caliper
    bm = bmesh.new()
    xd = face_x(r0) - depth - 0.03
    disc = [(0.06, xd), (r_rim - 0.04, xd), (r_rim - 0.04, xd - 0.026), (0.06, xd - 0.026)]
    _lathe_x(bm, disc, 40, mat_index=0)
    rc0, rc1 = r_rim - 0.105, r_rim - 0.03
    cal = [(rc0, xd + 0.022), (rc1, xd + 0.022), (rc1, xd - 0.05), (rc0, xd - 0.05)]
    ca0 = st.get("caliper_angle", 125.0)
    rings = _lathe_x(bm, cal, 8, mat_index=1, a0=ca0 - 26, a1=ca0 + 26, closed=False)
    bm.faces.new(list(reversed(rings[0]))).material_index = 1
    bm.faces.new(rings[-1]).material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name + "_brake")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mats["disc"])
    me.materials.append(mats["caliper"])
    objs.append(me)
    return objs


def wheels(car, st):
    """Four wheels from the style dict (rim colour/metal, spokes, kind, caliper colour ...)."""
    d = car.d
    R = car.R
    r_rim = st.get("r_rim", R - 0.095)
    mats = dict(
        tyre=car.mat("tyre", "#141415", rough=0.82, spec=0.35),
        rim=M.basic(car.name + "_rim", st.get("color", "#b9bdc3"), rough=st.get("rough", 0.22),
                    metal=st.get("metal", 1.0), coat=st.get("coat", 0.3)),
        rim_dark=car.mat("rimdark", "#1b1c1e", rough=0.5, metal=0.4),
        disc=car.mat("disc", "#77797c", rough=0.42, metal=0.85),
        caliper=M.basic(car.name + "_caliper", st.get("caliper", "#2a2b2d"), rough=0.3, coat=0.6),
    )
    meshes = {}
    for key, tw in (("f", d["tw"]), ("r", d.get("tw_r", d["tw"]))):
        meshes[key] = wheel_mesh(car.name + "_wheel_" + key, R, r_rim, tw, st, mats)
    inset = d.get("wheel_inset", 0.02)
    out = []
    for key, ya in (("r", car.y_ra), ("f", car.y_fa)):
        tw = d["tw"] if key == "f" else d.get("tw_r", d["tw"])
        f = car.frame(ya)
        x_out = car.W2 - inset
        for side in (1, -1):
            xc = side * (x_out - tw / 2)
            for me in meshes[key]:
                ob = bpy.data.objects.new(me.name, me)
                ob.location = (xc, ya, R)
                ob.scale = (side, 1.0, 1.0)
                if key == "f" and st.get("steer"):
                    ob.rotation_euler = (0.0, 0.0, math.radians(st["steer"]))
                MU._link(ob, car.center)
                out.append(ob)
    return out


# ---------------------------------------------------------------------------------------------- glass

def _belt(car, y):
    g = car.green_half(y)[1]
    return g["zb"] + car.d.get("g_sink", 0.04)


def glass(car, g):
    """Side windows, windshield and rear window as conformal patches on the greenhouse, with black seals.
    g: dlo=dict(y_rear, y_rear_top, y_front, top=margin below the roof edge, bottom=margin above the belt,
                pillars=[(y_bottom, y_top, width)] black dividers, quarter=..),
       ws=dict(top, bottom, pillar), rw=dict(top, bottom, pillar, proj), seal=width, tint, frame_mat."""
    seal_w = g.get("seal", 0.014)
    tint = g.get("tint", "#0d1115")
    gm = M.glass_mat(car.name + "_glass", tint) if hasattr(M, "glass_mat") else M.basic(
        car.name + "_glass", tint, rough=0.015, spec=1.0, coat=0.6)
    seal = car.mat("seal", "#09090a", rough=0.45, spec=0.4, coat=0.2)
    trim = g.get("trim")
    target = "green"
    # --- side DLO (right flank; the patch is mirrored to the left)
    s = g["dlo"]
    yr, yrt, yf = s["y_rear"], s["y_rear_top"], s["y_front"]
    top_m, bot_m = s.get("top", 0.022), s.get("bottom", 0.012)
    ys = [yr + (yf - yr) * i / 60 for i in range(61)]
    bottom = [(y, _belt(car, y) + bot_m) for y in ys]
    tops = []
    for y in ys:
        gh = car.green_half(y)[1]
        tops.append((y, gh["zs"] - top_m))
    # C-pillar: line from (yr, belt) to (yrt, top)
    poly = []
    for (y, z) in bottom:
        poly.append((y, z))
    for (y, z) in reversed(tops):
        poly.append((y, z))
    # clip by the C-pillar line and the front cut (polygon must stay simple)
    poly = _clip(poly, (yr, 0.0), (yrt, 3.0), keep_right=True)
    if s.get("front_cut"):
        a, b = s["front_cut"]
        poly = _clip(poly, a, b, keep_right=False)
    poly = [p for i, p in enumerate(poly) if i == 0 or math.hypot(p[0] - poly[i - 1][0], p[1] - poly[i - 1][1]) > 1e-4]
    car.patch(poly, "side", seal, offset=0.0012, res=0.012, name="dlo_seal", target=target)
    inner = C.ccw(_inset_poly(poly, seal_w))
    car.patch(inner, "side", gm, offset=0.0022, res=0.012, name="dlo_glass", target=target)
    for (yb, yt, w) in s.get("pillars", []):
        zb = _belt(car, yb) - 0.01
        zt = car.green_half(yt)[1]["zs"] + 0.01
        pp = [(yb - w / 2, zb), (yb + w / 2, zb), (yt + w / 2, zt), (yt - w / 2, zt)]
        car.patch(pp, "side", seal if not trim else trim, offset=0.0032, res=0.01, name="bpillar", target=target)
    if trim and s.get("chrome_line"):
        # bright trim along the belt and the roof edge of the DLO
        car.stripe([(p[0], p[1] - 0.002) for p in bottom[::3]], 0.012, "side", trim, offset=0.0028, res=0.006,
                   name="belt_trim", target="all")
    # --- windshield (top projection)
    w = g["ws"]
    y0, y1 = w["bottom"], w["top"]
    left, right = [], []
    for i in range(41):
        y = y0 + (y1 - y0) * i / 40
        gh = car.green_half(y)[1]
        xw = gh["x_rc"] + gh["rr"] * 0.35 - w.get("pillar", 0.05)
        right.append((xw, y))
        left.append((-xw, y))
    poly = right + list(reversed(left))
    car.patch(poly, "top", seal, offset=0.0012, res=0.014, sym=False, name="ws_seal", target=target)
    car.patch(C.ccw(_inset_poly(C.ccw(poly), seal_w)), "top", gm, offset=0.0022, res=0.014, sym=False,
              name="ws_glass", target=target)
    # --- rear window
    r = g["rw"]
    proj = r.get("proj", "rear")
    y0, y1 = r["bottom"], r["top"]
    right = []
    for i in range(41):
        y = y0 + (y1 - y0) * i / 40
        gh = car.green_half(y)[1]
        xw = gh["x_rc"] + gh["rr"] * 0.35 - r.get("pillar", 0.06)
        zc = gh["zr"] - gh["rc"] * (xw / max(0.05, gh["x_rc"])) ** 2
        right.append((xw, zc if proj == "rear" else y))
    left = [(-p[0], p[1]) for p in right]
    poly = C.ccw(right + list(reversed(left)))
    car.patch(poly, proj, seal, offset=0.0012, res=0.012, sym=False, name="rw_seal", target=target)
    car.patch(C.ccw(_inset_poly(poly, seal_w)), proj, gm, offset=0.0022, res=0.012, sym=False, name="rw_glass",
              target=target)
    return gm


def _clip(poly, a, b, keep_right=True):
    """Clips a polygon by the line a->b; keeps the side right of the direction (or left)."""
    ex, ez = b[0] - a[0], b[1] - a[1]

    def side(p):
        v = ex * (p[1] - a[1]) - ez * (p[0] - a[0])
        return -v if keep_right else v
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        sp, sq = side(p), side(q)
        if sp >= 0:
            out.append(p)
        if (sp >= 0) != (sq >= 0):
            t = sp / (sp - sq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def _inset_poly(poly, d):
    """Inward offset of a counter-clockwise polygon (mitre joints, fine for gently curved outlines)."""
    poly = C.ccw(poly)
    n = len(poly)
    out = []
    for i in range(n):
        p0, p1, p2 = poly[i - 1], poly[i], poly[(i + 1) % n]
        e1 = (p1[0] - p0[0], p1[1] - p0[1])
        e2 = (p2[0] - p1[0], p2[1] - p1[1])
        l1 = math.hypot(*e1) or 1e-9
        l2 = math.hypot(*e2) or 1e-9
        n1 = (-e1[1] / l1, e1[0] / l1)
        n2 = (-e2[1] / l2, e2[0] / l2)
        nx, ny = n1[0] + n2[0], n1[1] + n2[1]
        ln = math.hypot(nx, ny) or 1e-9
        nx, ny = nx / ln, ny / ln
        cosh = max(0.35, nx * n1[0] + ny * n1[1])
        out.append((p1[0] + nx * d / cosh, p1[1] + ny * d / cosh))
    return out


# ---------------------------------------------------------------------------------------------- lamps

def part_mat(car, kind, part):
    """Materials of lamp internals. Emission values stay <= 1 (no clipping); brightness = post gain."""
    t = part.get("tail", None)
    b = part.get("brake", None)
    if kind == "guide":           # LED light guide: position light, also lit when braking
        return M.basic(car.name + "_guide_%s_%s" % (t, b), part.get("color", "#e8b0a8"), rough=0.35, coat=0.3,
                       emit={"tail": (TAIL_RED, 1.0 if t is None else t), "brake": (BRAKE_RED, 0.55 if b is None else b)})
    if kind == "tail":            # softly glowing lamp body (position light only)
        return M.basic(car.name + "_tailfill_%s" % t, part.get("color", "#b0261a"), rough=0.3, coat=0.4,
                       emit={"tail": (TAIL_RED, 0.32 if t is None else t)})
    if kind == "brake":           # brake segment
        return M.basic(car.name + "_brakefill_%s_%s" % (t, b), part.get("color", "#8a1810"), rough=0.25, coat=0.5,
                       emit={"brake": (BRAKE_RED, 1.0 if b is None else b), "tail": (TAIL_RED, 0.0 if t is None else t)})
    if kind == "chrome":
        return car.mat("lampchrome", "#d2d5d9", rough=0.3, metal=0.9)
    if kind == "dark":
        return car.mat("lampdark", "#120808", rough=0.3, metal=0.2, coat=0.6)
    if kind == "reverse":
        return car.mat("reverse", "#d9dde2", rough=0.15, metal=0.3, coat=0.6)
    if kind == "indicator":
        return car.mat("indicator", "#c86414", rough=0.2, coat=0.6)
    if kind == "reflector":
        return M.basic(car.name + "_reflector", "#7c100c", rough=0.25, coat=0.6, emit={"tail": ("#ff2a10", 0.3)})
    if kind == "white":
        return car.mat("lampwhite", "#e8ebee", rough=0.25, coat=0.4)
    raise ValueError(kind)


_OFF = {"chrome": 0.0035, "dark": 0.003, "tail": 0.0045, "brake": 0.005, "guide": 0.0075, "reverse": 0.004,
        "indicator": 0.004, "reflector": 0.004, "white": 0.004}


def lamp(car, spec, tag="tail"):
    """Lamp assembly on the body: dark housing, internals (chrome bowls, glowing fills, LED light guides,
    brake segments ...), and a raised tinted lens with side walls (transparent in the light passes).
    spec: outline (CCW, right side; mirrored when sym), proj, depth, tint, housing, parts=[{kind, outline |
    path+width, tail, brake, color, offset}], lenses=[{outline, tint}] (default: one lens = outline)."""
    proj = spec.get("proj", "rear")
    sym = spec.get("sym", True)
    tgt = spec.get("target", "all")
    depth = spec.get("depth", 0.012)
    res = spec.get("res", 0.007)
    hm = M.basic(car.name + "_housing_" + tag, spec.get("housing", "#b9b3b2"), rough=0.45, metal=0.0, coat=0.2)
    car.patch(spec["outline"], proj, hm, offset=0.0015, res=res, sym=sym, name=tag + "_housing", target=tgt)
    for i, part in enumerate(spec.get("parts", [])):
        kind = part["kind"]
        mat = part_mat(car, kind, part)
        off = part.get("offset", _OFF[kind])
        nm = "%s_%s%d" % (tag, kind, i)
        if "path" in part:
            pts = C.smooth_open(part["path"], 6) if part.get("smooth", True) and len(part["path"]) > 2 else part["path"]
            car.stripe(pts, part["width"], proj, mat, offset=off, res=min(res, part["width"] * 0.6), sym=sym,
                       name=nm, target=tgt, walls=part.get("walls", 0.0), wall_mat=mat if part.get("walls") else None)
        else:
            car.patch(part["outline"], proj, mat, offset=off, res=part.get("res", res), sym=sym, name=nm, target=tgt,
                      walls=part.get("walls", 0.0), wall_mat=mat if part.get("walls") else None)
    lenses = spec.get("lenses") or [dict(outline=spec["outline"], tint=spec.get("tint", "#c41a0f"))]
    for i, ln in enumerate(lenses):
        lm = M.lens(car.name + "_lens_%s%d" % (tag, i), tint=ln.get("tint", "#c41a0f"), refl=ln.get("refl", 0.06),
                    frost=ln.get("frost", spec.get("frost", 0.3)))
        car.patch(ln["outline"], proj, lm, offset=ln.get("depth", depth), res=res, sym=sym, walls=ln.get("depth", depth),
                  wall_mat=lm, name="%s_lens%d" % (tag, i), target=tgt)


def light_box(car, center, size, mat, bevel=0.004, name="lightbox"):
    """Small box element (third brake light etc.) in build space."""
    bm = MU.bm_box(size[0], size[1], size[2], center)
    ob = MU.make(car.name + "_" + name, bm, mat, parent=car.center)
    if bevel:
        MU.bevel(ob, bevel, 2)
    return ob


# ---------------------------------------------------------------------------------------------- plate, text

def text_patch(car, text, height, center, proj, mat, offset=0.002, sym=False, target="all", bold=0.03,
               spacing=1.0, max_w=None, side=1):
    """Text as a conformal mesh: letters laid out in the projection plane around center (u, v) and ray-cast
    onto the surface (readable from outside)."""
    ob = textgeo.text_mesh(car.rig, text, height, mat, bold=bold, extrude=0.0, name="tmp_txt", spacing=spacing)
    me = ob.data
    xs = [v.co.x for v in me.vertices]
    w = (max(xs) - min(xs)) if xs else 0.0
    k = 1.0
    if max_w and w > max_w:
        k = max_w / w
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.objects.remove(ob)
    out = bmesh.new()
    variants = [(1, side)]
    if sym:
        variants.append((-1, -side))
    for (mx, sgn) in variants:
        vmap = {}
        ok = True
        for v in bm.verts:
            lx, ly = v.co.x * k, v.co.y * k
            if proj == "rear":
                u, vv = center[0] * mx + lx, center[1] + ly
            elif proj == "front":
                u, vv = center[0] * mx - lx, center[1] + ly
            elif proj == "side":
                # right flank reads rear->front (+y), left flank front->rear
                u, vv = center[0] + lx * (1 if sgn > 0 else -1), center[1] + ly
            else:  # top: reads along +x, up = +y (towards the front)
                u, vv = center[0] + lx, center[1] + ly
            h = car.cast(proj, u, vv, sgn, target)
            if h is None:
                ok = False
                break
            loc, nor = h
            vmap[v] = out.verts.new(loc + nor * offset)
        if not ok:
            continue
        for f in bm.faces:
            try:
                out.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
    bm.free()
    out.normal_update()
    for f in out.faces:
        c = f.calc_center_median()
        want = {"rear": Vector((0, -1, 0)), "front": Vector((0, 1, 0)), "top": Vector((0, 0, 1))}.get(proj)
        if want is None:
            want = Vector((1 if c.x > 0 else -1, 0, 0))
        if f.normal.dot(want) < 0:
            f.normal_flip()
    return MU.make(car.name + "_txt", out, mat, parent=car.center)


def plate(car, center, proj="rear", size=(0.52, 0.112), text="CE 2026", target="all", recess=0.022,
          band="#1f3f9c"):
    """Flat number plate (white, blue band, black characters) at center (u, v), standing just proud of the
    surface and facing straight backwards/forwards, with a dark recess around it."""
    cu, cv = center
    h = car.cast(proj, cu, cv, 1, target)
    if h is None:
        return None
    w, hh = size
    out_y = -1.0 if proj == "rear" else 1.0
    rec = car.mat("plate_recess", "#0c0c0d", rough=0.55)
    if recess:
        car.patch(C.rounded_rect(cu, cv, w + recess * 2, hh + recess * 2, 0.02, 4), proj, rec, offset=0.0012,
                  res=0.01, sym=False, name="plate_recess", target=target)
    # outermost surface point behind the plate -> plate stands just in front of it
    ys = []
    for du in (-w / 2, 0.0, w / 2):
        for dv in (-hh / 2, 0.0, hh / 2):
            h2 = car.cast(proj, cu + du, cv + dv, 1, target)
            if h2:
                ys.append(h2[0].y)
    y_pl = (min(ys) if proj == "rear" else max(ys)) + out_y * 0.006
    pm = M.basic(car.name + "_plate", "#eeeeea", rough=0.4, spec=0.4, emit={"tail": ("#fff4dc", 0.1)})
    bm = bmesh.new()
    th = 0.004
    pts = C.rounded_rect(0.0, 0.0, w, hh, 0.012, 3)
    sgn = 1 if proj == "rear" else -1
    vf = [bm.verts.new((cu + px * sgn, y_pl, cv + pz)) for (px, pz) in pts]
    vb = [bm.verts.new((cu + px * sgn, y_pl - out_y * th, cv + pz)) for (px, pz) in pts]
    bm.faces.new(vf)
    bm.faces.new(list(reversed(vb)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((vf[i], vb[i], vb[j], vf[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    MU.make(car.name + "_plate", bm, pm, parent=car.center)
    bmat = car.mat("plate_band", band, rough=0.45)
    bw = 0.045
    xl = cu - (w / 2 - bw / 2 - 0.004) * sgn
    bm = MU.bm_box(bw, 0.001, hh - 0.008, (xl, y_pl + out_y * 0.0006, cv))
    MU.make(car.name + "_plateband", bm, bmat, parent=car.center)
    tm = car.mat("plate_text", "#111111", rough=0.5)
    ob = textgeo.text_mesh(car.rig, text, hh * 0.62, tm, bold=0.06, extrude=0.0, name=car.name + "_platetext")
    textgeo.fit(ob, w - bw - 0.05)
    ob.parent = car.center
    ob.location = (cu + (bw / 2 + 0.006) * sgn, y_pl + out_y * 0.0008, cv - hh * 0.02)
    ob.rotation_euler = (math.pi / 2, 0.0, 0.0 if proj == "rear" else math.pi)
    ob2 = textgeo.text_mesh(car.rig, "CE", 0.022, car.mat("plate_bandtext", "#f2f2f2", rough=0.5), bold=0.02,
                            extrude=0.0, name=car.name + "_plateband_t")
    ob2.parent = car.center
    ob2.location = (xl, y_pl + out_y * 0.0012, cv - hh * 0.25)
    ob2.rotation_euler = (math.pi / 2, 0.0, 0.0 if proj == "rear" else math.pi)
    return y_pl


# ---------------------------------------------------------------------------------------------- exhausts, diffuser

def exhaust(car, x, z, kind="round", r=0.045, w=0.12, h=0.06, y_tip=-0.006, length=0.18, sym=True, mat=None,
            corner=0.018):
    """Exhaust tips pointing backwards (tip face at y = y_tip): polished lip, dark inner pipe."""
    chrome = mat or car.mat("chrome", "#e0e2e5", rough=0.08, metal=1.0)
    inner = car.mat("pipe_inner", "#050505", rough=0.9)
    xs = [x, -x] if sym and abs(x) > 1e-4 else [x]
    for xx in xs:
        bm = bmesh.new()
        if kind == "round":
            prof = [(r * 0.86, y_tip + 0.012), (r * 0.93, y_tip + 0.002), (r, y_tip + 0.004), (r * 1.02, y_tip + 0.03),
                    (r * 1.0, y_tip + length)]
            _lathe_y(bm, prof, 40, (xx, z))
            MU.make(car.name + "_exh", bm, chrome, parent=car.center, smooth=True, sharp_deg=70)
            bm = bmesh.new()
            _lathe_y(bm, [(r * 0.87, y_tip + 0.012), (r * 0.87, y_tip + 0.08), (0.0, y_tip + 0.08)], 32, (xx, z))
            MU.make(car.name + "_exh_in", bm, inner, parent=car.center, smooth=True)
        else:
            if kind == "oval":
                outline = C.ellipse(0.0, 0.0, w / 2, h / 2, 40)
            else:
                outline = C.rounded_rect(0.0, 0.0, w, h, corner, 5)
                if kind == "trapezoid":
                    outline = [(px * (1.0 - 0.12 * (0.5 - pz / h)), pz) for (px, pz) in outline]
            _ring_tube(bm, outline, xx, z, y_tip, length, lip=0.007)
            MU.make(car.name + "_exh", bm, chrome, parent=car.center, smooth=True, sharp_deg=50)
            bm = bmesh.new()
            inner_o = [(px * 0.86, pz * 0.8) for (px, pz) in outline]
            verts = [bm.verts.new((xx + px, y_tip + 0.03, z + pz)) for (px, pz) in inner_o]
            bm.faces.new(verts)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            MU.make(car.name + "_exh_in", bm, inner, parent=car.center)


def _lathe_y(bm, prof, segs, center):
    """Revolve (r, y) about an axis parallel to Y through center (x, z)."""
    cx, cz = center
    rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        rings.append([bm.verts.new((cx + r * math.cos(a), y, cz + r * math.sin(a))) for (r, y) in prof])
    m = len(prof)
    for i in range(segs):
        A, B = rings[i], rings[(i + 1) % segs]
        for k in range(m - 1):
            try:
                f = bm.faces.new((A[k], A[k + 1], B[k + 1], B[k]))
                f.smooth = True
            except ValueError:
                pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def _ring_tube(bm, outline, cx, cz, y_tip, length, lip=0.006):
    """Tube with a rolled lip from a 2-D outline (x, z) running from y_tip forward by length."""
    n = len(outline)
    cen = (sum(p[0] for p in outline) / n, sum(p[1] for p in outline) / n)

    def scaled(k):
        return [(cen[0] + (p[0] - cen[0]) * k, cen[1] + (p[1] - cen[1]) * k) for p in outline]
    size = max(max(p[0] for p in outline) - min(p[0] for p in outline), 0.01)
    k_in = 1.0 - 2 * lip / size
    layers = [(scaled(k_in), y_tip + 0.012), (scaled((1 + k_in) / 2), y_tip), (scaled(1.0), y_tip + 0.006),
              (scaled(1.0), y_tip + length)]
    rings = [[bm.verts.new((cx + p[0], y, cz + p[1])) for p in ring] for ring, y in layers]
    for A, B in zip(rings[:-1], rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((A[i], A[j], B[j], B[i]))
            f.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def fins(car, xs, z0, z1, y0, y1, thick=0.008, mat=None, sym=False):
    """Vertical diffuser fins (boxes with rounded edges)."""
    m = mat or car.mat("diffuser", "#111214", rough=0.5, coat=0.2)
    bm = bmesh.new()
    allx = list(xs) + ([-x for x in xs] if sym else [])
    for x in allx:
        MU.bm_box(thick, y1 - y0, z1 - z0, (x, (y0 + y1) / 2, (z0 + z1) / 2), bm=bm)
    ob = MU.make(car.name + "_fins", bm, m, parent=car.center)
    MU.bevel(ob, min(0.003, thick * 0.4), 2)
    return ob


# ---------------------------------------------------------------------------------------------- spoilers, mirrors

def loft_x(car, sections, mat, name, smooth=True, sharp=40):
    """Lofts closed (y, z) sections placed at x positions: sections = [(x, [(y, z), ...]), ...]."""
    rings = [[(x, y, z) for (y, z) in sec] for (x, sec) in sections]
    bm = MU.loft(rings)
    return MU.make(car.name + "_" + name, bm, mat, parent=car.center, smooth=smooth, sharp_deg=sharp)


def airfoil(y_le, y_te, z_le, z_te, thick, camber=0.0, n=10):
    """Closed (y, z) section of a wing/spoiler from the leading edge (front) to the trailing edge (rear)."""
    top, bot = [], []
    for i in range(n + 1):
        t = i / n
        y = y_le + (y_te - y_le) * t
        zc = z_le + (z_te - z_le) * t + camber * 4 * t * (1 - t)
        th = thick * min(1.0, 2.2 * math.sqrt(max(t, 1e-6)) * (1 - t) ** 1.1 + 0.1)
        top.append((y, zc + th * 0.5))
        bot.append((y, zc - th * 0.5))
    return top + list(reversed(bot[1:-1]))


def mirrors(car, y, z, mat, glass_mat=None, size=(0.19, 0.088, 0.108), indicator=True):
    """Door mirrors: rounded housing on a short arm, dark mirror glass facing backwards, amber
    indicator strip on the outer front edge."""
    sx, sy, sz = size
    gm = glass_mat or car.mat("mirrorglass", "#2c3238", rough=0.03, metal=0.95)
    xb = car.W2 - 0.03
    out = []
    for side in (1, -1):
        xc = side * (car.W2 + sx * 0.5 + 0.03)
        secs = []
        for i in range(9):
            t = i / 8
            xx = xc - side * sx / 2 + side * sx * t
            k = 0.82 + 0.18 * math.sin(math.pi * min(1.0, t * 1.25))
            hy, hz = sy * k / 2, sz * k / 2
            ring = []
            for j in range(20):
                a = 2 * math.pi * j / 20
                ca, sa = math.cos(a), math.sin(a)
                yy = math.copysign(abs(ca) ** 0.55, ca) * hy
                zz = math.copysign(abs(sa) ** 0.6, sa) * hz
                ring.append((xx, y + yy + 0.01 * t, z + zz + 0.012 * t))
            secs.append(ring)
        if side < 0:
            secs = list(reversed(secs))
        bmm = MU.loft(secs)
        ob = MU.make(car.name + "_mirror", bmm, mat, parent=car.center, smooth=True, sharp_deg=70)
        out.append(ob)
        bm = MU.bm_beam((side * xb, y + 0.025, z - 0.055), (xc - side * sx * 0.3, y + 0.01, z - 0.03), 0.05, 0.03)
        ob = MU.make(car.name + "_mirrorarm", bm, mat, parent=car.center)
        MU.bevel(ob, 0.008, 2)
        gl = MU.bm_box(sx * 0.82, 0.004, sz * 0.72, (xc + side * 0.006, y - sy / 2 + 0.006, z + 0.006))
        ob = MU.make(car.name + "_mirrorglass", gl, gm, parent=car.center)
        MU.bevel(ob, 0.0015, 1)
        if indicator:
            im = car.mat("mirror_ind", "#d07a22", rough=0.15, coat=0.6)
            bm = MU.bm_box(sx * 0.42, 0.012, 0.016, (xc + side * sx * 0.22, y + sy * 0.38, z - sz * 0.22))
            MU.make(car.name + "_mirror_ind", bm, im, parent=car.center)
    return out


def wiper(car, pivot, tip, mat=None):
    m = mat or car.mat("wiper", "#0d0d0e", rough=0.5)
    bm = MU.bm_beam(pivot, tip, 0.016, 0.012)
    MU.bm_cyl(0.02, 0.018, 0.02, center=pivot, axis="Y", segs=12, bm=bm)
    ob = MU.make(car.name + "_wiper", bm, m, parent=car.center)
    MU.bevel(ob, 0.003, 1)
    return ob


def roof_rails(car, y0, y1, x_in, mat, h=0.055, w=0.035):
    """Roof rails following the roof line at |x| = x_rc - x_in, with feet at both ends."""
    out = []
    for side in (1, -1):
        pts = []
        for i in range(25):
            y = y0 + (y1 - y0) * i / 24
            gh = car.green_half(y)[1]
            xx = gh["x_rc"] + gh["rr"] * 0.3 - x_in
            zr = gh["zr"] - gh["rc"] * (xx / gh["x_rc"]) ** 2
            lift = h * min(1.0, min(i, 24 - i) / 3.0) ** 0.7
            pts.append((side * xx, y, zr + 0.012 + lift))
        prof = C.rounded_rect(0.0, 0.0, w, 0.024, 0.01, 3)
        bm = sweep(pts, prof)
        out.append(MU.make(car.name + "_rail", bm, mat, parent=car.center, smooth=True, sharp_deg=60))
    return out


def sweep(path, prof, up=(0, 0, 1)):
    """Sweeps a closed 2-D profile (u = sideways, v = up) along a 3-D polyline; capped ends."""
    bm = bmesh.new()
    rings = []
    n = len(path)
    upv = Vector(up)
    for i in range(n):
        p = Vector(path[i])
        a = Vector(path[max(0, i - 1)])
        b = Vector(path[min(n - 1, i + 1)])
        t = (b - a).normalized()
        side = t.cross(upv).normalized()
        u2 = side.cross(t).normalized()
        rings.append([bm.verts.new(p + side * pu + u2 * pv) for (pu, pv) in prof])
    m = len(prof)
    for A, B in zip(rings[:-1], rings[1:]):
        for j in range(m):
            k = (j + 1) % m
            f = bm.faces.new((A[j], A[k], B[k], B[j]))
            f.smooth = True
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm
