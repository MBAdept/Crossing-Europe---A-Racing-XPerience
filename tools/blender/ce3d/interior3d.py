"""Cabin of the player cars for the real-time models (contract 4.6.9: at most 6,000 triangles inside "body").

The sprites show opaque glass. The real-time models have transparent panes, so the car needs something behind
them: a dark tub (floor, door panels), parcel shelf, rear bench and front seats with headrests, dashboard with
an instrument hood, steering wheel on the left, centre console, mirror. Everything is derived from the design
of the car (cesprites.player_cars): axles, window positions, belt line, roof line - no numbers per car except
the optional overrides in INTERIOR.

Build space of cesprites.carbody: y = 0 at the rear bumper, +y forward, +x = right flank, z = 0 ground. The
parts are objects on the CENTER empty of the car like every other detail, tagged for the node "body".
All parts keep clear of the glass: seat backs and headrests are lowered until they stay under the roof line.
"""
import math

import bmesh
from mathutils import Matrix, Vector

from cesprites import cardetail as CD
from cesprites import meshutil as MU

# per design: overrides of the derived layout (m). hip_f / hip_r = y of the front / rear hip points,
# rear = False for a two-seater, recline_f / recline_r in degrees
INTERIOR = {
    "limousine": dict(),
    "kompakt": dict(),
}

COLORS = dict(tub="#17181a", carpet="#101112", seat="#2b2d31", seat_mid="#3a3d43", dash="#141516", dash_top="#0f1011",
              trim="#8e9297", wheel="#0b0b0c", shelf="#1b1c1f", liner="#26272a", screen="#05070a", mirror="#0c0c0d")


class _Parts:
    """Collects boxes into one bmesh per material (few objects, few modifiers)."""

    def __init__(self, car):
        self.car = car
        self.bms = {}

    def bm(self, key):
        if key not in self.bms:
            self.bms[key] = bmesh.new()
        return self.bms[key]

    def box(self, key, size, center, rot_x=0.0, pivot=None, taper=None):
        """Box (sx, sy, sz) at center, turned by rot_x degrees about the x axis through pivot (default: its
        centre); taper = (kx, ky): scale of the top face."""
        bm = self.bm(key)
        res = bmesh.ops.create_cube(bm, size=1.0)
        vs = res["verts"]
        if taper is not None:
            for v in vs:
                if v.co.z > 0.0:
                    v.co.x *= taper[0]
                    v.co.y *= taper[1]
        m = Matrix.Translation(Vector(center)) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
        bmesh.ops.transform(bm, matrix=m, verts=vs)
        if rot_x:
            pv = Vector(pivot if pivot is not None else center)
            r = Matrix.Translation(pv) @ Matrix.Rotation(math.radians(rot_x), 4, "X") @ Matrix.Translation(-pv)
            bmesh.ops.transform(bm, matrix=r, verts=vs)
        return vs

    def finish(self, bevels, segments):
        out = []
        for key in sorted(self.bms):
            bm = self.bms[key]
            if len(bm.faces) == 0:
                bm.free()
                continue
            mat = self.car.mat("int_" + key, COLORS[key], rough=0.82 if key not in ("trim", "screen") else 0.3,
                               metal=0.6 if key == "trim" else 0.0)
            ob = MU.make(self.car.name + "_int_" + key, bm, mat, parent=self.car.center, smooth=True, sharp_deg=50)
            w = bevels.get(key, 0.0)
            if w > 0.0:
                MU.bevel(ob, w, segments, angle_deg=40.0)
            out.append(ob)
        return out


def layout(car):
    """Derived positions of the cabin (build space)."""
    d = car.d
    g = d["glass"]
    o = dict(INTERIOR.get(car.name, {}))
    g0, g1 = d["g_range"]
    ws_b, ws_t = g["ws"]["bottom"], g["ws"]["top"]
    rw_b, rw_t = g["rw"]["bottom"], g["rw"]["top"]
    ym = 0.5 * (car.y_ra + car.y_fa)
    z_floor = car.under(ym) + 0.115
    y_dash1 = min(g1 - 0.05, ws_b + 0.09)
    y_dash0 = ws_b - 0.40
    hip_f = o.get("hip_f", min(car.y_fa - 1.36, y_dash0 - 0.40))
    hip_r = o.get("hip_r", hip_f - 0.80)
    y_cabin0 = g0 + 0.05
    rear = o.get("rear", hip_r - 0.45 > y_cabin0 + 0.12)
    return dict(g0=g0, g1=g1, ws_b=ws_b, ws_t=ws_t, rw_b=rw_b, rw_t=rw_t, z_floor=z_floor, y_dash0=y_dash0,
                y_dash1=y_dash1, hip_f=hip_f, hip_r=hip_r, rear=rear, y_cabin0=y_cabin0, y_cabin1=g1 - 0.05,
                recline_f=o.get("recline_f", 21.0), recline_r=o.get("recline_r", 26.0))


def cabin_half_width(car, y, margin=0.02):
    """Half width of the cabin at the belt (inside of the greenhouse base)."""
    return car.green_half(y)[1]["xb"] - margin


def headroom(car, y, x):
    """Height the cabin offers at (y, x): inside of the roof / glass, with clearance."""
    g0, g1 = car.d["g_range"]
    y = min(max(y, g0 + 0.02), g1 - 0.02)
    gh = car.green_half(y)[1]
    x_rc = max(0.05, gh["x_rc"])
    return gh["zr"] - gh["rc"] * min(1.0, abs(x) / x_rc) ** 2 - 0.055


def _seat(parts, car, lay, x, hip, width, recline, z_c, back_len, head=True, key="seat"):
    """Seat at hip point y = hip: cushion, reclined backrest, headrest on two posts. The backrest is shortened
    and the headrest lowered until both stay under the roof."""
    a = math.radians(recline)
    cush_len = 0.50
    # cushion: slightly raised at the front
    parts.box(key, (width, cush_len, 0.13), (x, hip + 0.16, z_c - 0.065), rot_x=4.0, pivot=(x, hip - 0.09, z_c))
    parts.box("seat_mid", (width * 0.62, cush_len * 0.8, 0.02), (x, hip + 0.17, z_c + 0.006), rot_x=4.0, pivot=(x, hip - 0.09, z_c))
    # backrest from the pivot at the rear of the cushion
    py, pz = hip - 0.10, z_c - 0.03
    th = 0.105

    def top_of(length, extra):
        yy = py - (length + extra) * math.sin(a)
        zz = pz + (length + extra) * math.cos(a)
        return yy, zz
    for _ in range(12):
        yt, zt = top_of(back_len, 0.20 if head else 0.02)
        if zt <= headroom(car, yt, abs(x) + width * 0.3):
            break
        back_len -= 0.03
    cy, cz = py - 0.5 * back_len * math.sin(a), pz + 0.5 * back_len * math.cos(a)
    parts.box(key, (width * 0.96, th, back_len), (x, cy, cz), rot_x=recline, taper=(0.86, 1.0))
    parts.box("seat_mid", (width * 0.56, 0.02, back_len * 0.72), (x, cy + (th * 0.5 + 0.004) * math.cos(a), cz + (th * 0.5 + 0.004) * math.sin(a)), rot_x=recline)
    if head:
        hy, hz = top_of(back_len, 0.105)
        parts.box(key, (width * 0.5, 0.085, 0.16), (x, hy, hz), rot_x=recline * 0.6)
        for sx in (-0.06, 0.06):
            py2, pz2 = top_of(back_len, 0.02)
            parts.box("trim", (0.012, 0.012, 0.07), (x + sx, py2, pz2), rot_x=recline)
    return top_of(back_len, 0.0)


def build_interior(car, fine=False):
    """Creates the cabin objects of a built player car (after player_cars.build). Returns the layout."""
    lay = layout(car)
    d = car.d
    parts = _Parts(car)
    zf = lay["z_floor"]
    y0, y1 = lay["y_cabin0"], lay["y_cabin1"]
    # --- tub: floor and door panels as a loft of U sections (normals inwards), closed at both ends -------------
    bm = parts.bm("tub")
    n = 14
    rings = []
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        w = cabin_half_width(car, y)
        zt = CD._belt(car, y) + 0.004
        rings.append([Vector((-w, y, zt)), Vector((-w, y, zf)), Vector((w, y, zf)), Vector((w, y, zt))])
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    for a_, b_ in zip(vr[:-1], vr[1:]):
        for k in range(3):
            bm.faces.new((a_[k], a_[k + 1], b_[k + 1], b_[k]))      # seen from inside
    bm.faces.new((vr[0][3], vr[0][2], vr[0][1], vr[0][0]))          # rear wall
    bm.faces.new((vr[-1][0], vr[-1][1], vr[-1][2], vr[-1][3]))      # front wall (behind the dashboard)
    # --- parcel shelf / luggage cover behind the rear seats, dashboard top under the windshield ------------------
    w_mid = cabin_half_width(car, 0.5 * (y0 + y1))
    seat_w = min(0.52, w_mid - 0.14)
    z_c = zf + 0.27
    x_seat = min(0.37, w_mid - seat_w * 0.5 - 0.03)
    top_f = _seat(parts, car, lay, -x_seat, lay["hip_f"], seat_w, lay["recline_f"], z_c, 0.60)
    _seat(parts, car, lay, x_seat, lay["hip_f"], seat_w, lay["recline_f"], z_c, 0.60)
    shelf_y1 = y0 + 0.25
    if lay["rear"]:
        # rear bench: one cushion, one backrest, two headrests
        hr = lay["hip_r"]
        bw = 2.0 * cabin_half_width(car, hr) - 0.10
        a = math.radians(lay["recline_r"])
        parts.box("seat", (bw, 0.50, 0.14), (0.0, hr + 0.15, z_c - 0.09), rot_x=5.0, pivot=(0.0, hr - 0.1, z_c - 0.02))
        back_len = 0.56
        py, pz = hr - 0.10, z_c - 0.05
        for _ in range(12):
            yt, zt = py - (back_len + 0.17) * math.sin(a), pz + (back_len + 0.17) * math.cos(a)
            if zt <= headroom(car, yt, 0.42) and yt > y0 + 0.08:
                break
            back_len -= 0.03
        cy, cz = py - 0.5 * back_len * math.sin(a), pz + 0.5 * back_len * math.cos(a)
        parts.box("seat", (bw, 0.11, back_len), (0.0, cy, cz), rot_x=lay["recline_r"], taper=(0.94, 1.0))
        for sx in (-1, 1):
            parts.box("seat_mid", (bw * 0.3, 0.02, back_len * 0.7), (sx * bw * 0.24, cy + 0.06 * math.cos(a), cz + 0.06 * math.sin(a)),
                      rot_x=lay["recline_r"])
            hy, hz = py - (back_len + 0.085) * math.sin(a), pz + (back_len + 0.085) * math.cos(a)
            parts.box("seat", (0.24, 0.08, 0.13), (sx * bw * 0.27, hy, hz), rot_x=lay["recline_r"] * 0.6)
        shelf_y1 = py - back_len * math.sin(a) + 0.03
        shelf_z = min(pz + back_len * math.cos(a) - 0.02, CD._belt(car, shelf_y1) - 0.012)
    else:
        shelf_y1 = top_f[0] - 0.05
        shelf_z = CD._belt(car, shelf_y1) - 0.03
    if shelf_y1 > y0 + 0.06:
        ws_ = cabin_half_width(car, 0.5 * (y0 + shelf_y1)) - 0.004
        parts.box("shelf", (2.0 * ws_, shelf_y1 - y0 + 0.02, 0.02), (0.0, 0.5 * (y0 + shelf_y1), shelf_z))
    # --- dashboard: body under the windshield base, soft top, instrument hood, centre screen, console -----------
    yd0, yd1 = lay["y_dash0"], lay["y_dash1"]
    wd = cabin_half_width(car, yd0) - 0.006
    z_cowl = CD._belt(car, min(yd1, lay["ws_b"])) - 0.012
    parts.box("dash", (2.0 * wd, yd1 - yd0, 0.30), (0.0, 0.5 * (yd0 + yd1), z_cowl - 0.15), taper=(1.0, 0.82))
    parts.box("dash_top", (2.0 * wd - 0.02, (yd1 - yd0) * 0.9, 0.022), (0.0, 0.5 * (yd0 + yd1) + 0.02, z_cowl + 0.004))
    parts.box("dash_top", (0.34, 0.16, 0.075), (-x_seat, yd0 + 0.10, z_cowl + 0.03), taper=(0.9, 0.7))     # hood
    parts.box("screen", (0.26, 0.012, 0.12), (0.0, yd0 - 0.004, z_cowl - 0.07), rot_x=-12.0)
    parts.box("tub", (0.20, 0.67, 0.20), (0.0, lay["hip_f"] + 0.085, zf + 0.11))          # centre console
    parts.box("dash", (0.22, 0.30, 0.06), (0.0, yd0 - 0.13, zf + 0.26), rot_x=-10.0)
    # steering wheel on the left: rim, hub, three spokes, column
    tilt = math.radians(24.0)
    wy, wz = yd0 - 0.10, z_cowl - 0.085
    bmw = parts.bm("wheel")
    rr, rt = 0.185, 0.016
    segs, tube = (28, 8) if fine else (16, 6)
    prof = [(rr + rt * math.cos(2 * math.pi * k / tube), rt * math.sin(2 * math.pi * k / tube)) for k in range(tube + 1)]
    before = set(bmw.verts)
    MU.bm_lathe(prof, segs=segs, bm=bmw)
    for ang in (90.0, 210.0, 330.0):
        ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
        MU.bm_beam((ca * 0.03, sa * 0.03, 0.0), (ca * rr, sa * rr, 0.0), 0.03, 0.012, bm=bmw)
    MU.bm_cyl(0.05, 0.045, 0.03, center=(0.0, 0.0, -0.004), segs=10, bm=bmw)
    MU.bm_cyl(0.028, 0.028, 0.26, center=(0.0, 0.0, -0.14), segs=8, bm=bmw)
    new = [v for v in bmw.verts if v not in before]
    # the lathe axis (z) becomes the column: pointing forward-down, the rim faces the driver
    m = Matrix.Translation(Vector((-x_seat, wy, wz))) @ Matrix.Rotation(math.pi / 2 - tilt, 4, "X")
    bmesh.ops.transform(bmw, matrix=m, verts=new)
    bmesh.ops.recalc_face_normals(bmw, faces=bmw.faces)
    # inside mirror at the windshield header
    zr = headroom(car, lay["ws_t"] + 0.06, 0.0)
    parts.box("mirror", (0.22, 0.02, 0.06), (0.0, lay["ws_t"] + 0.10, zr - 0.02), rot_x=8.0)
    # bevel widths stay well under half the thinnest box of their group (wider ones fold faces over)
    bev = dict(seat=0.028, seat_mid=0.0, dash=0.02, dash_top=0.007, shelf=0.0, tub=0.0, trim=0.0, wheel=0.0,
               screen=0.0, mirror=0.008)
    obs = parts.finish(bev, 3 if fine else 2)
    for ob in obs:
        if ob.name.endswith("_int_tub"):
            ob.data.set_sharp_from_angle(angle=math.radians(40.0))
    return lay


def deck_opening(car, lay, margin=0.022):
    """Outline (x, y), top projection, of the opening in the deck of the lower body under the greenhouse: the
    cabin is open below the belt line."""
    y0, y1 = lay["y_cabin0"] + 0.01, lay["y_cabin1"] - 0.01
    n = 24
    right = []
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        right.append((cabin_half_width(car, y, margin), y))
    return right + [(-x, y) for (x, y) in reversed(right)]
