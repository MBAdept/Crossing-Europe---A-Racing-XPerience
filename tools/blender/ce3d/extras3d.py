"""Parts only the real-time player cars have (the sprites show the cars from behind, 250 px wide, with opaque
glass): third brake light behind the rear window, plate frame and plate lamps, roof antenna, front wipers.
Everything is derived from the design of the car (cesprites.player_cars) and from what the build has made - no
numbers per car except the optional overrides in EXTRAS.

Called by ce3d.vehicles3d after player_cars.build with the car back in build space (y = 0 at the rear bumper);
the parts are objects on the CENTER empty, tagged for the node "body".
"""
import math

import bmesh
import bpy

from cesprites import cardetail as CD
from cesprites import materials as M
from cesprites import meshutil as MU

from . import interior3d

# per design: chmsl = False if the design has its own third brake light; antenna_y = position on the roof
EXTRAS = {
    "limousine": dict(chmsl=True, antenna_y=None),
    "kompakt": dict(chmsl=False, antenna_y=0.86),
}


def _bounds(ob):
    pts = [ob.matrix_local @ v.co for v in ob.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return lo, hi


def _rear_plate(car):
    """Bounds (build space) of the rear number plate made by cardetail.plate, or None."""
    best = None
    for ob in car.center.children:
        if ob.type == "MESH" and ob.name.split(".")[0] == car.name + "_plate":
            lo, hi = _bounds(ob)
            if best is None or lo[1] < best[0][1]:
                best = (lo, hi)
    return best


def build_extras(car, fine=False):
    """Creates the extra parts of a built player car. Returns a dict of what was made."""
    d = car.d
    o = EXTRAS.get(car.name, {})
    made = {}
    dark = car.mat("x_dark", "#0b0b0c", rough=0.5)
    gloss = M.basic(car.name + "_x_gloss", "#060607", rough=0.08, coat=1.0)
    g = d["glass"]
    # --- third brake light: a bar under the roof behind the top of the rear window
    if o.get("chmsl", False):
        y = g["rw"]["top"] - 0.07
        z = interior3d.headroom(car, y, 0.0) + 0.028
        bm = MU.bm_box(0.36, 0.05, 0.03, (0.0, y + 0.012, z))
        MU.make(car.name + "_chmsl_house", bm, dark, parent=car.center)
        lamp = M.basic(car.name + "_chmsl", "#4a0806", rough=0.2, coat=0.6, emit={"brake": (CD.BRAKE_RED, 1.0)})
        bm = MU.bm_box(0.32, 0.006, 0.016, (0.0, y - 0.015, z))
        MU.tag(MU.make(car.name + "_chmsl_lamp", bm, lamp, parent=car.center), lamp="brake")
        made["chmsl"] = (round(y, 3), round(z, 3))
    # --- plate: frame around it and two lamps above it (lit with the tail lights, no light anchor)
    pl = _rear_plate(car)
    if pl is not None:
        lo, hi = pl
        yf = lo[1] - 0.002                      # the rear face of the plate is the smallest y
        t = 0.009
        bm = bmesh.new()
        MU.bm_box(hi[0] - lo[0] + 2 * t, 0.012, t, ((lo[0] + hi[0]) / 2, yf + 0.006, hi[2] + t / 2), bm=bm)
        MU.bm_box(hi[0] - lo[0] + 2 * t, 0.012, t, ((lo[0] + hi[0]) / 2, yf + 0.006, lo[2] - t / 2), bm=bm)
        MU.bm_box(t, 0.012, hi[2] - lo[2], (lo[0] - t / 2, yf + 0.006, (lo[2] + hi[2]) / 2), bm=bm)
        MU.bm_box(t, 0.012, hi[2] - lo[2], (hi[0] + t / 2, yf + 0.006, (lo[2] + hi[2]) / 2), bm=bm)
        MU.make(car.name + "_plateframe", bm, dark, parent=car.center)
        lampm = car.mat("x_platelamp", "#d8d2c2", rough=0.3)
        bm = bmesh.new()
        for sx in (-1, 1):
            MU.bm_box(0.07, 0.014, 0.011, (sx * 0.1, yf + 0.004, hi[2] + t + 0.012), bm=bm)
        MU.tag(MU.make(car.name + "_platelamp", bm, lampm, parent=car.center), lamp="-marker:1:#fff4dc")
        made["plate"] = True
    # --- roof antenna (shark fin) on the centre line
    g0, g1 = d["g_range"]
    ya = o.get("antenna_y") or (g["rw"]["top"] + 0.12)
    ya = min(max(ya, g0 + 0.2), g1 - 0.6)
    zr = car.roof(ya)
    ln, h, w = 0.17, 0.052, 0.038
    bm = bmesh.new()
    base = [(-w / 2, ya - ln * 0.45), (w / 2, ya - ln * 0.45), (w * 0.3, ya + ln * 0.55), (-w * 0.3, ya + ln * 0.55)]
    vb = [bm.verts.new((x, y, car.roof(y) - 0.004)) for (x, y) in base]
    vt = [bm.verts.new((-0.004, ya - ln * 0.4, zr + h)), bm.verts.new((0.004, ya - ln * 0.4, zr + h)),
          bm.verts.new((0.004, ya - ln * 0.12, zr + h * 0.92)), bm.verts.new((-0.004, ya - ln * 0.12, zr + h * 0.92))]
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((vb[i], vb[j], vt[j], vt[i]))
    bm.faces.new(vt)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = MU.make(car.name + "_antenna", bm, gloss, parent=car.center, smooth=True, sharp_deg=50)
    MU.bevel(ob, 0.004, 2)
    made["antenna"] = round(ya, 3)
    # --- front wipers at rest along the base of the windshield
    wb = g["ws"]["bottom"]
    n = 0
    for (x0, x1) in ((-0.56, -0.02), (0.06, 0.6)):
        p0 = car.cast("top", x0, wb - 0.03, target="green")
        p1 = car.cast("top", x1, wb - 0.105, target="green")
        if p0 and p1:
            CD.wiper(car, tuple(p0[0] + p0[1] * 0.014), tuple(p1[0] + p1[1] * 0.012))
            n += 1
    made["wipers"] = n
    return made


def uncover_pockets(car, soups, shift, cut_holes):
    """Seams and other flat details that run over a recessed lamp unit are cut away there (they would hang in
    front of the recess). soups: {name: Soup} in root space, shift(outline, proj) -> outline in root space,
    cut_holes = decalgeo.cut_holes. Returns the number of removed triangles."""
    removed = 0
    names = [n for n in soups if n.split(".")[0] in (car.name + "_seam", car.name + "_fuelflap")]
    for pk in car.lamp_pockets:
        proj = pk["proj"]
        ol = shift(pk["outline"], proj)
        variants = [(ol, 1)]
        if pk["sym"]:
            variants.append(([(-p[0], p[1]) for p in ol], 1) if proj != "side" else (ol, -1))
        for (outline, sgn) in variants:
            for n in names:
                s = soups[n]
                if s.n == 0:
                    continue
                pos, nor, mat, k = cut_holes(s.pos, s.nor, s.mi, proj, sgn, [outline], n_min=0.02)
                if k:
                    s.pos, s.nor, s.mi, s.n = pos, nor, mat, pos.shape[0]
                    removed += k
    return removed
