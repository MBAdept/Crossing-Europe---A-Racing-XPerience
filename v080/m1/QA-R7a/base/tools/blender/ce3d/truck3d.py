"""The articulated truck as a real-time model (contract 4.6.2: tractor and trailer groups).

The sprite truck of cesprites.heavy is a set of textured boxes (render "box"): a bevelled cab box and a trailer
box whose doors, lamps and windows are shader decals. This builder makes the same vehicle - same footprint
(2.55 x 16.5 m, 4.0 m high), same axle positions, same lamp layout, the colours of heavy.TRUCK_VARIANTS - as a
model with real parts:

  tractor   cab-over cab (raked windshield, door windows, grille, sun visor, roof deflector, side fairings),
            bumper with headlights, steps, mudguards, frame, tanks, fifth wheel, mirrors, wipers
  trailer   box body with door frame, lock rods and hinges, reflective contour marking, chassis, landing gear,
            side guards, mudguards and flaps, lamp bar with two clusters, triangle reflectors, plate, underrun bar

Flat surfaces carry their markings as geometry cut into them (ce3d.decalgeo, one layer - nothing can flicker
at any distance); parts with depth are real meshes.

Liveries (cesprites.heavy.TRUCK_VARIANTS, AS2b): a box trailer carries the stripe and the word of its variant on both
flanks (white "LOGISTIK", blue "TRANSPORT": glyph outlines of the sprite's font, in the stripe colour paint3); a
curtain sider (red, green: "tarp") has corrugated curtains between the rails, pulled in at 22 straps with buckles.
One model per kind: traffic/truck (white), traffic/truck_transport (blue), traffic/truck_tarp (red, green).

Nodes      lod0: tractor/body, tractor/wheel_0l|r (front, steered), tractor/wheel_1l|r (drive, twin tyres),
                 trailer/body (mesh origin = the kingpin), trailer/wheel_0..2 l|r
           lod1, lod2: one merged mesh "body"; shadow: boxes
           "groups" of the manifest entry: {"tractor": {"pivot"}, "trailer": {"pivot": kingpin}} - a renderer
           that bends the truck turns every "trailer/..." part about the trailer pivot (model space).
Paint      paint = trailer body, paint2 = cab, paint3 = stripe and emblem (a livery without them: paint3 = paint)
Lamps      rear clusters: indicator (outside), tail + brake, reverse; contour tape and reflectors are lit
           surfaces (channel 15 "retro", RINT-B: their own colour by day; they light up in the player's low beam -
           the cone law of inc/headlight.gdshaderinc in vpbr.gdshader); amber side markers, the cab's roof markers
           (channel 9) and the plate lamp follow the tail lights without a light anchor; side repeaters on the cab
           (indicator channels)
Build space as in cesprites: y = 0 at the rear, +y forward, x = 0 centre (+x right), z = 0 ground.
"""
import math
import time

import bmesh
import numpy as np

from . import core, decalgeo, roles
from . import lod as LOD
from .export import Lod, ModelData, Part

# --- dimensions (m): the numbers of cesprites.heavy.build_truck -------------------------------------------
L = 16.5
W2 = 1.275
H = 4.0
TR_LEN = 13.6                       # trailer body: y 0 .. 13.6
BOX_Z0, BOX_Z1 = 1.22, 4.0
R = 0.53                            # all wheels
RADIUS = R
TR_AXLES = (3.0, 4.31, 5.62)
Y_DRIVE, Y_FRONT = 11.35, 15.25
TW_TRAILER, TW_DRIVE, TW_FRONT = 0.385, 0.30, 0.32
KINGPIN = (0.0, 11.95, 1.19)
CAB_Y0, CAB_Y1 = 14.05, 16.42
CAB_W2 = 1.24
CAB_Z0, CAB_Z1 = 1.25, 3.45
LOD_DIST = {"lod0": 60, "lod1": 180, "lod2": 100000}
SEGS = {0: 28, 1: 14, 2: 8, 3: 8}   # wheel segments per level (3 = shadow caster)

DARK = "#1c1d1f"
CHASSIS = "#26282b"
GREY = "#73777d"
ALU = "#c2c6cb"
RED_TAPE = "#d21c14"
YELLOW_TAPE = "#f0cc18"
LAMP_RED = "#ff1a0e"
AMBER = "#ffa21a"
# panes of the far levels (vpbr): the far colour of the traffic cars (traffic3d.TRAFFIC_GLASS_FAR, measured against
# the glass class of lod0 with the race look). AS2R: the bus rear window at the 60 m swap was (59, 77, 100) in lod1
# against (78, 97, 121) in lod0 - 43 % of its pixels changed by more than 24 levels
GLASS_FAR = "#3a4652"


def _rect(u0, v0, u1, v1):
    return [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]


def _quad(p0, p1, p2, p3):
    """Two triangles of a flat quad, counter-clockwise seen from outside: (pos (2, 3, 3), nor (2, 3, 3))."""
    pos = np.array([[p0, p1, p2], [p0, p2, p3]], dtype=np.float64)
    n = np.cross(pos[0, 1] - pos[0, 0], pos[0, 2] - pos[0, 0])
    n = n / max(np.linalg.norm(n), 1e-12)
    return pos, np.broadcast_to(n, (2, 3, 3)).copy()


def _box_faces(x0, x1, y0, y1, z0, z1, faces="rflRtb"):
    """Faces of a box as quads by letter: r rear (-y), f front (+y), l left (-x), R right (+x), t top, b bottom."""
    q = {
        "r": ((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)),
        "f": ((x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)),
        "R": ((x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)),
        "l": ((x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)),
        "t": ((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)),
        "b": ((x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (x0, y0, z0)),
    }
    return {k: _quad(*q[k]) for k in faces}


class _Build:
    """One level of the truck: Blender objects for the parts with depth, triangle panels for the flat ones."""

    def __init__(self, level, tarp=False, word=None):
        from cesprites import materials as M
        from cesprites import meshutil as MU
        from cesprites import rig as RG
        self.lv = level                       # 0, 1, 2 or 3 (shadow caster)
        self.M, self.MU = M, MU
        self.rig = RG.Rig(quick=True)
        self.root = self.rig.root
        self.pal = decalgeo.Palette()
        self.panels = {}                      # node -> [decalgeo.Tris]
        self.mats = {}
        self.split = level == 0               # tractor / trailer / wheel nodes; else everything is "body"
        self.tarp = tarp                      # curtain sider (red, green) instead of the box
        self.word = word                      # word on the flanks of the box ("LOGISTIK", "TRANSPORT") or None
        p = self.pal
        self.i_paint = p.add("paint", "paint", dict(slot="paint", rough=0.42, metal=0.1))
        self.i_cab = p.add("paint2", "paint", dict(slot="paint2", rough=0.3, metal=0.1))
        self.i_acc = p.add("paint3", "paint", dict(slot="paint3", rough=0.42, metal=0.1))
        self.i_dark = self.flat(DARK, 0.6)
        self.i_chassis = self.flat(CHASSIS, 0.7)
        self.i_alu = self.flat(ALU, 0.35, 0.55)
        self.i_grey = self.flat(GREY, 0.5, 0.2)
        self.i_seal = self.flat("#0c0d0e", 0.5)
        # the traffic cars' glass (traffic3d.TRAFFIC_GLASS): lighter, glossy, a little metallic - the black panes of the
        # cab read as painted (art review of AS1, C4). (AS2R) The far levels draw the panes as vpbr, which mirrors the
        # sky about half as strongly as the glass class: they take the far colour of the traffic cars (GLASS_FAR)
        self.i_glass = p.add("glass", "glass", dict(color="#2a343e" if level == 0 else GLASS_FAR, rough=0.02, metal=0.25))

    # --- materials ---------------------------------------------------------------------------------------

    def flat(self, color, rough=0.5, metal=0.0, lamp=None):
        return self.pal.add("flat|%s|%s|%s|%s" % (color, rough, metal, lamp), "flat",
                            dict(color=color, rough=rough, metal=metal), lamp)

    def mat(self, key, color, rough=0.5, metal=0.0):
        if key not in self.mats:
            self.mats[key] = self.M.basic("tk_" + key, color, rough=rough, metal=metal)
        return self.mats[key]

    def paint_mat(self, slot):
        key = "paint_" + slot
        if key not in self.mats:
            self.mats[key] = self.M.paint("tk_" + slot, "#808080", metal=0.1, rough=0.3 if slot == "paint2" else 0.42)
        return self.mats[key]

    # --- nodes -------------------------------------------------------------------------------------------

    def node(self, name, pivot=None):
        return self.MU.node(name if self.split else "body", pivot=pivot if self.split else None)

    def nname(self, name):
        return name if self.split else "body"

    # --- parts ---------------------------------------------------------------------------------------------

    def obj(self, name, bm, mat, smooth=False, sharp=40.0, bevel=0.0, segs=2, lamp=None):
        """Object from a bmesh in the current node; bevel only at the nearest level (hardened normals: the flat
        faces keep their normals, only the bevel is round)."""
        ob = self.MU.make("tk_" + name, bm, mat, parent=self.root, smooth=smooth or (bevel > 0.0 and self.lv == 0),
                          sharp_deg=sharp)
        if bevel > 0.0 and self.lv == 0:
            m = self.MU.bevel(ob, bevel, segs)
            m.harden_normals = True
        if lamp is not None:
            self.MU.tag(ob, lamp=lamp)
        return ob

    def box(self, name, x0, x1, y0, y1, z0, z1, mat, bevel=0.0, bm=None):
        b = self.MU.bm_box(x1 - x0, y1 - y0, z1 - z0, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), bm=bm)
        if bm is not None:
            return b
        return self.obj(name, b, mat, bevel=bevel)

    def panel(self, node, base, quads, groups=None):
        """Flat faces with markings cut into them. quads: [(pos, nor)], groups: {(proj, sign): [items]} with
        items dict(poly, mat) bottom to top."""
        pos = np.concatenate([q[0] for q in quads])
        nor = np.concatenate([q[1] for q in quads])
        t = decalgeo.Tris(pos, nor)
        t.mat[:] = base
        for key in sorted(groups or {}, key=lambda g: (g[0], -g[1])):
            items = []
            for rank, it in enumerate(groups[key]):
                items.append(dict(poly=it["poly"], mat=it["mat"], rank=rank, n_min=0.5))
            t.apply(key[0], key[1], items, cut=True)
        t.normalize()
        self.panels.setdefault(self.nname(node), []).append(t)
        return t


# --- wheels ------------------------------------------------------------------------------------------------

def _lathe_x(bm, prof, segs, mat_index=0):
    """Revolves (r, x) about the X axis. The faces look to the left of the profile's direction: (dr, dx) gives
    the normal (-dx, dr) in (r, x) - a tyre runs from the outer bead over the tread to the inner bead, a disc
    seen from outside (+x) from the centre outwards."""
    rings = []
    for i in range(segs):
        a = 2.0 * math.pi * i / segs - 0.5 * math.pi          # one vertex straight down: the tyre stands on it
        rings.append([bm.verts.new((x, r * math.cos(a), r * math.sin(a))) for (r, x) in prof])
    for i in range(segs):
        a_, b_ = rings[i], rings[(i + 1) % segs]
        for k in range(len(prof) - 1):
            f = bm.faces.new((a_[k], a_[k + 1], b_[k + 1], b_[k]))
            f.material_index = mat_index
            f.smooth = True


def _wheel(b, kind, loc, left=False, radius=None, tw=None):
    """One wheel (or twin wheel) of the right side at loc = (x of the outer tyre face, y, z); left = the same
    mesh turned by 180 degrees. Local space: axis X, outside +X, origin on the axle in the middle of the tyre
    (twin: of the pair). radius / tw: other wheels than the truck's (the bus: 0.5 m) - the rim scales with the
    radius."""
    lv = b.lv
    segs = SEGS[lv]
    R = RADIUS if radius is None else radius            # noqa: N806 (the module's R for the truck)
    if tw is None:
        tw = {"front": TW_FRONT, "drive": TW_DRIVE, "trailer": TW_TRAILER}[kind]
    twin = kind == "drive"
    gap = 0.035
    width = tw * 2 + gap if twin else tw
    r_rim = 0.292 * R / RADIUS
    tyre = b.mat("tyre", "#161718", rough=0.85)
    rim = b.mat("rim", "#c8ccd1", rough=0.35, metal=0.5)
    rim_dark = b.mat("rimdark", "#2a2c2f", rough=0.55, metal=0.2)
    centres = [width / 2 - tw / 2, -(width / 2 - tw / 2)] if twin else [0.0]
    bm = bmesh.new()
    for cx in centres:
        if lv == 0:
            prof = [(r_rim, -tw / 2 + 0.035), (r_rim + 0.03, -tw / 2 + 0.004), (R - 0.07, -tw / 2 - 0.006),
                    (R - 0.022, -tw / 2 + 0.006), (R - 0.004, -tw / 2 + 0.03), (R, -tw / 2 + 0.055),
                    (R, tw / 2 - 0.055), (R - 0.004, tw / 2 - 0.03), (R - 0.022, tw / 2 - 0.006),
                    (R - 0.07, tw / 2 + 0.006), (r_rim + 0.03, tw / 2 - 0.004), (r_rim, tw / 2 - 0.035)]
        elif lv == 1:
            prof = [(r_rim, -tw / 2 + 0.03), (R - 0.03, -tw / 2), (R, -tw / 2 + 0.045), (R, tw / 2 - 0.045),
                    (R - 0.03, tw / 2), (r_rim, tw / 2 - 0.03)]
        else:
            # (far: no inner sidewall - nobody looks under the vehicle from 180 m; the coach had 432 of its 1,500 lod2
            # triangles in the wheels)
            prof = [(R, -tw / 2), (R, tw / 2), (r_rim * 0.9, tw / 2)]
        _lathe_x(bm, [(r, x + cx) for (r, x) in reversed(prof)], segs)
    obs = [b.obj("tyre_" + kind, bm, tyre, smooth=True, sharp=50.0 if lv == 0 else 35.0)]
    # rim: lip, dish and hub of the outer wheel; a plain disc inside
    xo = width / 2 - 0.02                      # outer face of the rim lip
    bm = bmesh.new()
    if lv <= 1:
        if kind == "drive":
            dish = [(r_rim + 0.004, xo + 0.004), (r_rim - 0.012, xo + 0.006), (r_rim - 0.03, xo - 0.02),
                    (0.185, xo - 0.135), (0.17, xo - 0.14), (0.14, xo - 0.06), (0.105, xo - 0.035), (0.0, xo - 0.03)]
        elif kind == "front":
            dish = [(r_rim + 0.004, xo + 0.004), (r_rim - 0.012, xo + 0.006), (r_rim - 0.03, xo - 0.03),
                    (0.2, xo - 0.035), (0.17, xo + 0.02), (0.13, xo + 0.055), (0.07, xo + 0.07), (0.0, xo + 0.072)]
        else:
            dish = [(r_rim + 0.004, xo + 0.004), (r_rim - 0.012, xo + 0.006), (r_rim - 0.03, xo - 0.03),
                    (0.19, xo - 0.05), (0.16, xo - 0.03), (0.12, xo + 0.0), (0.085, xo + 0.03), (0.0, xo + 0.034)]
        if lv == 1:
            dish = [dish[0], dish[2], dish[3], dish[5], dish[7]]
        _lathe_x(bm, list(reversed(dish)), segs)
        if lv == 0:
            # wheel nuts and the dark hand holes of the disc
            r_n = 0.155 if kind != "front" else 0.15
            x_n = dish[4][1] if kind == "drive" else dish[3][1] + 0.01
            for i in range(10):
                a = 2.0 * math.pi * (i + 0.5) / 10
                b.MU.bm_cyl(0.014, 0.012, 0.03, center=(x_n + 0.012, r_n * math.cos(a), r_n * math.sin(a)), axis="X",
                            segs=6, bm=bm, mat_index=1)
    else:
        _lathe_x(bm, [(0.0, xo - 0.02), (r_rim * 0.9, xo - 0.02)], segs)
    obs.append(b.obj("rim_" + kind, bm, [rim, rim_dark], smooth=True, sharp=42.0))
    if lv == 0:
        # inside: a dark disc closes the wheel (seen from under the vehicle)
        bm = bmesh.new()
        _lathe_x(bm, [(r_rim, -width / 2 + 0.03), (0.0, -width / 2 + 0.05)], segs)
        obs.append(b.obj("rimback_" + kind, bm, rim_dark, smooth=True))
    x_out, y, z = loc
    xc = x_out - width / 2
    for ob in obs:
        ob.location = (-xc if left else xc, y, z)
        if left:
            ob.rotation_euler = (0.0, 0.0, math.pi)
    return (xc, y, z)


def _arch_block(b, name, x0, x1, y_axle, y0, y1, z0, z1, mat, gap=0.07, n=12):
    """Mudguard: a block over a wheel (z0 above the axle) with the wheel circle cut out, on both sides of the
    vehicle. Profile in the (y, z) plane."""
    ra = R + gap
    k = min(1.0, (z0 - R) / ra)
    a_s, a_e = math.pi - math.asin(k), math.asin(k)
    arc = [(y_axle + ra * math.cos(a_s + (a_e - a_s) * i / n), R + ra * math.sin(a_s + (a_e - a_s) * i / n))
           for i in range(n + 1)]
    arc[0] = (arc[0][0], z0)
    arc[-1] = (arc[-1][0], z0)
    poly = [(y1, z0), (y1, z1), (y0, z1), (y0, z0)] + arc
    out = [poly[0]]
    for p in poly[1:]:
        if math.hypot(p[0] - out[-1][0], p[1] - out[-1][1]) > 1e-4 and math.hypot(p[0] - out[0][0], p[1] - out[0][1]) > 1e-4:
            out.append(p)
    obs = []
    for sgn in (1, -1):
        xa, xb = (x0, x1) if sgn > 0 else (-x1, -x0)
        obs.append(b.obj(name, b.MU.prism(out, xb - xa, plane="YZ", offset=xa), mat))
    return obs


# --- trailer -----------------------------------------------------------------------------------------------


def _trailer(b):
    lv = b.lv
    e = 0.001                           # markings stay this far off the panel edges (no T-junctions)
    node = "trailer/body"
    lamp_marker = "-marker:1:" + AMBER
    # retroreflective contour tape: a lit surface (channel 15 "retro", RINT-B: its own colour by day; it lights up in
    # the player's low beam – vpbr.gdshader, the cone law of inc/headlight.gdshaderinc – instead of with the night as
    # a flood-lit surface, channel 14, did). As a number-plate surface (channel 8: tail light x plate_energy 0.45) the
    # contour stayed nearly dark at night, and it is the truck's main night cue
    i_tape_r = b.flat(RED_TAPE, 0.35, 0.0, "retro:%.2f" % TAPE_NIGHT)
    i_tape_y = b.flat(YELLOW_TAPE, 0.35, 0.0, "retro:%.2f" % TAPE_NIGHT)
    i_marker = b.flat("#c86a12", 0.2, 0.0, lamp_marker)
    i_marker_red = b.flat("#8a0c0a", 0.2, 0.0, "marker:1:" + LAMP_RED)
    f = _box_faces(-W2, W2, 0.0, TR_LEN, BOX_Z0, BOX_Z1)
    # --- rear: door frame, door gap, stripe, contour tape, end-outline lamps
    rear = [] if b.tarp else [dict(poly=_rect(-1.10, 1.55, 1.10, 1.75), mat=b.i_acc)]
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 1.165, sx * (W2 - e)))
        rear.append(dict(poly=_rect(x0, BOX_Z0 + e, x1, BOX_Z1 - e), mat=b.i_alu))
    rear += [dict(poly=_rect(-W2 + e, 3.885, W2 - e, BOX_Z1 - e), mat=b.i_alu),
             dict(poly=_rect(-W2 + e, BOX_Z0 + e, W2 - e, 1.335), mat=b.i_alu)]
    if lv <= 1:
        rear.append(dict(poly=_rect(-0.007, 1.335, 0.007, 3.885), mat=b.i_seal))
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 1.095, sx * 1.15))
        rear.append(dict(poly=_rect(x0, 1.385, x1, 3.835), mat=i_tape_r))
        x0, x1 = sorted((sx * 1.04, sx * 1.24))
        rear.append(dict(poly=_rect(x0, 3.915, x1, 3.975), mat=i_marker_red))
    rear += [dict(poly=_rect(-1.15, 3.78, 1.15, 3.835), mat=i_tape_r), dict(poly=_rect(-1.15, 1.385, 1.15, 1.44), mat=i_tape_r)]
    b.panel(node, b.i_paint, [f["r"]], {("rear", 1): rear})
    # --- sides: rails, posts, stripe and word (box) or curtain with straps (tarp), reflective line, marker lamps
    for sgn, key in ((1, "R"), (-1, "l")):
        frame = [dict(poly=_rect(e, BOX_Z0 + e, TR_LEN - e, 1.32), mat=b.i_alu),
                 dict(poly=_rect(e, 3.90, TR_LEN - e, BOX_Z1 - e), mat=b.i_alu),
                 dict(poly=_rect(e, 1.32, 0.1, 3.90), mat=b.i_alu),
                 dict(poly=_rect(TR_LEN - 0.1, 1.32, TR_LEN - e, 3.90), mat=b.i_alu)]
        lamps = []
        if lv <= 1:
            for i in range(5):
                y = 0.6 + i * 3.0
                lamps.append(dict(poly=_rect(y, BOX_Z0 + 0.03, y + 0.10, BOX_Z0 + 0.085), mat=i_marker))
        tape = dict(poly=_rect(0.16, 1.34, TR_LEN - 0.16, 1.39), mat=i_tape_y)
        if b.tarp:
            _curtain(b, node, sgn, key, frame + lamps, tape)
            continue
        side = [dict(poly=_rect(0.1, 1.55, TR_LEN - 0.1, 1.75), mat=b.i_acc)]
        if lv <= 1 and b.word:
            side += _word_items(b, sgn)
        side += frame + [tape] + lamps
        b.panel(node, b.i_paint, [f[key]], {("side", sgn): side})
    b.panel(node, b.i_paint, [f["f"], f["t"]])
    b.panel(node, b.i_chassis, [f["b"]])
    MU = b.MU
    alu = b.mat("alu", ALU, 0.35, 0.55)
    dark = b.mat("dark", DARK, 0.6)
    chassis = b.mat("chassis", CHASSIS, 0.7)
    grey = b.mat("grey", GREY, 0.5, 0.2)
    with b.node(node):
        # --- door hardware
        if lv == 0:
            bm = bmesh.new()
            for x in (-0.95, -0.33, 0.33, 0.95):
                MU.bm_cyl(0.017, 0.017, BOX_Z1 - BOX_Z0 - 0.16, center=(x, -0.024, (BOX_Z0 + BOX_Z1) / 2), segs=8, bm=bm)
                for z in (1.42, 2.6, 3.78):
                    MU.bm_box(0.07, 0.03, 0.05, (x, -0.016, z), bm=bm)
                MU.bm_box(0.26, 0.022, 0.035, (x + (0.11 if x < 0 else -0.11), -0.03, 2.05), bm=bm)
            for sx in (-1, 1):
                for z in (1.5, 2.2, 2.9, 3.6):
                    MU.bm_box(0.11, 0.028, 0.13, (sx * 1.2, -0.012, z), bm=bm)
            b.obj("doorhw", bm, alu, smooth=True, sharp=40.0)
        elif lv in (1, 2):
            # the four lock rods as bars (lod2 too: they are the light lines of the rear at 60 - 180 m; without them
            # the rear turned into a plain face at the switch at 180 m)
            bm = bmesh.new()
            for x in (-0.95, -0.33, 0.33, 0.95):
                MU.bm_box(0.03, 0.03, BOX_Z1 - BOX_Z0 - 0.16, (x, -0.02, (BOX_Z0 + BOX_Z1) / 2), bm=bm)
            b.obj("doorhw", bm, alu)
        # --- chassis, landing gear, side guards, axles
        bm = bmesh.new()
        if lv == 0:
            for sx in (-1, 1):
                MU.bm_box(0.1, 12.2, 0.3, (sx * 0.47, 6.35, 1.07), bm=bm)
            for y in (0.4, 2.2, 6.6, 8.2, 9.8, 11.2, 12.3):
                MU.bm_box(1.9, 0.08, 0.12, (0.0, y, 1.15), bm=bm)
            for y in TR_AXLES:
                MU.bm_cyl(0.065, 0.065, 2.0, center=(0.0, y, R), axis="X", segs=8, bm=bm)
                for sx in (-1, 1):
                    MU.bm_box(0.09, 0.9, 0.09, (sx * 0.47, y + 0.25, R + 0.12), bm=bm)       # trailing arm / spring
            for sx in (-1, 1):
                MU.bm_box(0.1, 0.1, 0.95, (sx * 0.78, 9.6, 0.72), bm=bm)
                MU.bm_box(0.24, 0.24, 0.04, (sx * 0.78, 9.6, 0.23), bm=bm)
            MU.bm_box(1.6, 0.06, 0.06, (0.0, 9.6, 0.9), bm=bm)
        elif lv == 1:
            MU.bm_box(1.04, 12.2, 0.3, (0.0, 6.35, 1.07), bm=bm)
            for y in TR_AXLES:
                MU.bm_box(2.0, 0.12, 0.12, (0.0, y, R), bm=bm)
            for sx in (-1, 1):
                MU.bm_box(0.1, 0.1, 0.99, (sx * 0.78, 9.6, 0.72), bm=bm)
        else:
            MU.bm_box(1.04, 12.2, 0.3, (0.0, 6.35, 1.07), bm=bm)
        b.obj("tchassis", bm, chassis)
        if lv <= 1:
            bm = bmesh.new()
            for sx in (-1, 1):
                for zz in (0.57, 0.85):
                    MU.bm_box(0.04, 2.95, 0.1, (sx * (W2 - 0.03), 7.8, zz), bm=bm)
                for y in (6.5, 7.8, 9.1):
                    MU.bm_box(0.035, 0.06, 0.72 if lv == 0 else 0.7, (sx * (W2 - 0.07), y, 0.86), bm=bm)
            b.obj("guards", bm, grey)
        # --- mudguards over the trailer wheels, flaps behind the last axle
        if lv == 0:
            bm = bmesh.new()
            for y in TR_AXLES:
                for sx in (-1, 1):
                    ra = R + 0.075
                    x_in, x_out = sx * (W2 - TW_TRAILER - 0.06), sx * (W2 - 0.005)
                    ring = []
                    for i in range(9):
                        a = math.radians(18.0 + 144.0 * i / 8)
                        ring.append((y + ra * math.cos(a), R + ra * math.sin(a)))
                    va = [bm.verts.new((x_in, p[0], p[1])) for p in ring]
                    vb = [bm.verts.new((x_out, p[0], p[1])) for p in ring]
                    vc = [bm.verts.new((x_out, y + (ra - 0.05) * math.cos(math.radians(18.0 + 144.0 * i / 8)),
                                        R + (ra - 0.05) * math.sin(math.radians(18.0 + 144.0 * i / 8)))) for i in range(9)]
                    for i in range(8):
                        top = (va[i], va[i + 1], vb[i + 1], vb[i])                  # top of the guard
                        lip = (vb[i], vb[i + 1], vc[i + 1], vc[i])                  # outer lip
                        bm.faces.new(top if sx > 0 else top[::-1])
                        bm.faces.new(lip if sx > 0 else lip[::-1])
            b.obj("tguards", bm, dark, smooth=True, sharp=50.0)
        if lv <= 1:
            bm = bmesh.new()
            for sx in (-1, 1):
                MU.bm_box(0.44, 0.018, 0.56, (sx * (W2 - 0.24), TR_AXLES[0] - R - 0.11, 0.5), bm=bm)
            if lv == 1:
                MU.bm_box(2 * W2 - 0.08, 3.9, 0.04, (0.0, TR_AXLES[1], R + R + 0.1), bm=bm)
            b.obj("tflaps", bm, dark)
        # --- underrun bar with its brackets
        bm = MU.bm_box(2 * W2 - 0.14, 0.1, 0.12, (0.0, 0.085, 0.46))
        if lv <= 1:
            for x in (-0.62, 0.62):
                MU.bm_box(0.08, 0.08, 0.5, (x, 0.13, 0.75), bm=bm)
        b.obj("underrun", bm, alu, bevel=0.012)
    # --- lamp bar: dark panel with two lamp clusters, triangle reflectors and the plate
    yb = 0.03
    bar = _box_faces(-W2 + 0.02, W2 - 0.02, yb, yb + 0.12, 0.6, 1.0)
    i_bar = b.flat("#202124", 0.5, 0.2)
    i_tri = b.flat("#c01712", 0.25, 0.0, "retro:%.2f" % TAPE_NIGHT)     # triangle reflectors: retroreflective as well
    i_plate = b.flat("#eeeeea", 0.45, 0.0, "plate:0.6")
    i_blue = b.flat("#1d3c9c", 0.45)
    i_text = b.flat("#151515", 0.5)
    i_platelamp = b.flat("#d9d2c0", 0.3, 0.0, "-marker:1:#fff4dc")
    items = []
    for sx in (-1, 1):
        cx = sx * 0.36
        items.append(dict(poly=[(cx - 0.085, 0.725), (cx + 0.085, 0.725), (cx, 0.872)], mat=i_tri))
    items += [dict(poly=_rect(-0.268, 0.722, 0.268, 0.846), mat=b.i_seal), dict(poly=_rect(-0.26, 0.73, 0.26, 0.838), mat=i_plate),
              dict(poly=_rect(-0.26, 0.73, -0.222, 0.838), mat=i_blue), dict(poly=_rect(-0.2, 0.868, 0.2, 0.888), mat=i_platelamp)]
    if lv <= 1:
        x = -0.2
        for c in (1, 1, 0, 1, 1, 0, 1, 1, 1):
            if c:
                items.append(dict(poly=_rect(x, 0.752, x + 0.034, 0.818), mat=i_text))
                x += 0.047
            else:
                x += 0.03
    b.panel(node, i_bar, [bar["r"]], {("rear", 1): items})
    b.panel(node, i_bar, [bar[k] for k in "lRtb"])
    i_ind = b.flat("#c86a12", 0.15, 0.0, "ind")
    i_tail = b.flat("#8a0c0a", 0.15, 0.0, "tail_brake")
    i_rev = b.flat("#b9bec4", 0.15, 0.3, "reverse")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.515, sx * 1.215))
        blk = _box_faces(x0, x1, yb - 0.03, yb, 0.705, 0.935)
        cl = []
        for (a, c, mat) in ((0.975, 1.2, i_ind), (0.745, 0.96, i_tail), (0.53, 0.73, i_rev)):
            u0, u1 = sorted((sx * a, sx * c))
            cl.append(dict(poly=_rect(u0, 0.72, u1, 0.92), mat=mat))
        b.panel(node, b.i_seal, [blk["r"]], {("rear", 1): cl})
        b.panel(node, b.i_seal, [blk[k] for k in "lRtb"])


CURTAIN_AMP = 0.014                 # the curtain is pulled in this far at a strap (m)
STRAP_Y0, STRAP_DY, STRAP_N = 0.3, 0.6, 22
STRAP = "#26282b"
WORD_Y, WORD_Z, WORD_SIZE = 6.825, 2.85, 0.62    # cesprites.heavy.build_truck: centre of the side text, its size


def _word_items(b, sgn):
    """The word of the livery on one flank as cut outlines (cesprites.heavy._side_text: the sprite's font and size,
    centred on the trailer, reading from the rear to the front on the right flank). Holes keep what is under them."""
    from .police3d import glyph_outlines
    loops = glyph_outlines(b.rig, b.word, WORD_SIZE, res=2 if b.lv == 0 else 1)
    out = []
    for lp, hole in loops:
        out.append(dict(poly=[(WORD_Y + sgn * x, WORD_Z + y) for (x, y) in lp], mat=None if hole else b.i_acc))
    return sorted(out, key=lambda it: it["mat"] is None)


def _curtain(b, node, sgn, key, frame, tape):
    """Curtain side of one flank: the rails and posts flat (strips of the box face), between them the curtain -
    corrugated at lod0 (pulled in at the straps, out to the rails between them), flat further away - with the
    straps and the reflective line cut in; buckles at the foot of each strap (lod0)."""
    lv = b.lv
    x_face = sgn * W2
    i_strap = b.flat(STRAP, 0.6, 0.0)
    # frame: four strips of the box face
    f = _box_faces(-W2, W2, 0.0, TR_LEN, BOX_Z0, 1.32)[key]
    b.panel(node, b.i_paint, [f], {("side", sgn): [it for it in frame if max(p[1] for p in it["poly"]) <= 1.32 + 1e-6]})
    b.panel(node, b.i_alu, [_box_faces(-W2, W2, 0.0, TR_LEN, 3.90, BOX_Z1)[key]])
    b.panel(node, b.i_alu, [_box_faces(-W2, W2, 0.0, 0.1, 1.32, 3.90)[key],
                            _box_faces(-W2, W2, TR_LEN - 0.1, TR_LEN, 1.32, 3.90)[key]])
    # the curtain
    y0, y1 = 0.1, TR_LEN - 0.1
    if lv == 0:
        ys = sorted(set([y0, y1] + [round(y0 + (y1 - y0) * i / 132, 5) for i in range(133)] +
                        [round(STRAP_Y0 + STRAP_DY * i + d, 5) for i in range(STRAP_N) for d in (-0.0175, 0.0175)]))
        zs = (1.32, 1.36, 1.39, 2.6, 3.86, 3.90)    # the first and last row meet the rails (no slit to look into)
    else:
        ys, zs = [y0, y1], (1.32, 3.90)

    def x_at(y, z=2.0):
        if lv > 0 or z <= 1.32 + 1e-6 or z >= 3.90 - 1e-6:
            return x_face
        u = math.pi * (y - STRAP_Y0) / STRAP_DY
        return sgn * (W2 - 0.002 - CURTAIN_AMP * math.cos(u) ** 2)

    def n_at(y):
        if lv > 0:
            return np.array([float(sgn), 0.0, 0.0])
        u = math.pi * (y - STRAP_Y0) / STRAP_DY
        d = CURTAIN_AMP * math.sin(2.0 * u) * math.pi / STRAP_DY      # d(W2 - amp cos^2)/dy
        n = np.array([float(sgn), -sgn * d, 0.0])
        return n / np.linalg.norm(n)
    pos, nor = [], []
    for ya, yb in zip(ys[:-1], ys[1:]):
        for za, zb in zip(zs[:-1], zs[1:]):
            q = [(x_at(ya, za), ya, za), (x_at(yb, za), yb, za), (x_at(yb, zb), yb, zb), (x_at(ya, zb), ya, zb)]
            nq = [n_at(ya), n_at(yb), n_at(yb), n_at(ya)]
            for tri in ((0, 1, 2), (0, 2, 3)):
                pp = np.array([q[i] for i in tri], dtype=np.float64)
                nn = np.array([nq[i] for i in tri], dtype=np.float64)
                if np.cross(pp[1] - pp[0], pp[2] - pp[0]) @ nn.sum(axis=0) < 0.0:
                    pp, nn = pp[::-1], nn[::-1]
                pos.append(pp)
                nor.append(nn)
    t = decalgeo.Tris(np.array(pos), np.array(nor))
    t.mat[:] = b.i_paint
    items = [dict(poly=_rect(STRAP_Y0 + STRAP_DY * i - 0.0175, 1.32, STRAP_Y0 + STRAP_DY * i + 0.0175, 3.90), mat=i_strap)
             for i in range(STRAP_N)] if lv <= 1 else []      # (far: 3.5 cm straps are a sixth of a pixel at 180 m)
    items.append(tape)
    t.apply("side", sgn, [dict(poly=it["poly"], mat=it["mat"], rank=r, n_min=0.5) for r, it in enumerate(items)],
            cut=True)
    t.normalize()
    b.panels.setdefault(b.nname(node), []).append(t)
    if lv == 0:
        bm = bmesh.new()
        for i in range(STRAP_N):
            y = STRAP_Y0 + STRAP_DY * i
            xo = sgn * (W2 - CURTAIN_AMP + 0.004)
            b.MU.bm_box(0.022, 0.05, 0.085, (xo, y, 1.42), bm=bm)
        with b.node(node):
            b.obj("buckles", bm, b.mat("buckle", "#3a3c40", 0.4, 0.5))


# --- tractor -----------------------------------------------------------------------------------------------

CAB_PROFILE = [(CAB_Y0, CAB_Z0), (CAB_Y1, CAB_Z0), (CAB_Y1, 2.12), (CAB_Y1 - 0.15, 3.03), (CAB_Y1 - 0.32, 3.37),
               (CAB_Y1 - 0.62, CAB_Z1), (CAB_Y0 + 0.14, CAB_Z1), (CAB_Y0, CAB_Z1 - 0.07)]


def _tractor(b):
    lv = b.lv
    MU = b.MU
    node = "tractor/body"
    dark = b.mat("dark", DARK, 0.6)
    chassis = b.mat("chassis", CHASSIS, 0.7)
    alu = b.mat("alu", ALU, 0.35, 0.55)
    grey = b.mat("grey", GREY, 0.5, 0.2)
    cab = b.paint_mat("paint2")
    # --- cab shell: the side profile extruded over the width, edges rounded at the near levels
    with b.node("none"):
        bm = MU.prism(CAB_PROFILE, 2 * CAB_W2, plane="YZ", offset=-CAB_W2)
        shell = b.MU.make("tk_cabshell", bm, cab, parent=b.root, smooth=lv <= 1, sharp_deg=35.0)
        if lv <= 1:
            m = MU.bevel(shell, 0.075, 3 if lv == 0 else 1)
            m.harden_normals = True
    s = core.soups_of([shell])[0]
    front = [dict(poly=_rect(-1.13, 2.13, 1.13, 3.05), mat=b.i_seal),
             dict(poly=decalgeo.inset(_rect(-1.13, 2.13, 1.13, 3.05), 0.045), mat=b.i_glass),
             dict(poly=_rect(-0.99, 1.33, 0.99, 2.03), mat=b.flat("#131415", 0.5, 0.2))]
    if lv == 1:
        for z in (1.45, 1.6, 1.75, 1.9):
            front.append(dict(poly=_rect(-0.93, z, 0.93, z + 0.045), mat=b.i_grey))
    if lv <= 1:
        front.append(dict(poly=_rect(-0.11, 1.945, 0.11, 2.005), mat=b.i_alu))
    win = [(15.28, 2.2), (16.2, 2.2), (16.12, 3.0), (15.28, 3.0)]
    sides = {}
    for sgn in (1, -1):
        it = [dict(poly=_rect(CAB_Y0 + 0.08, CAB_Z0 + 0.002, CAB_Y1 - 0.08, 1.37), mat=b.i_dark),
              dict(poly=win, mat=b.i_seal), dict(poly=decalgeo.inset(win, 0.04), mat=b.i_glass)]
        if lv <= 1:
            it += [dict(poly=_rect(15.2, 1.37, 15.214, 3.08), mat=b.i_seal),
                   dict(poly=_rect(15.2, 3.066, 16.26, 3.08), mat=b.i_seal),
                   dict(poly=_rect(15.3, 1.98, 15.47, 2.03), mat=b.i_dark)]
        sides[("side", sgn)] = it
    t = decalgeo.Tris(s.pos, s.nor)
    t.mat[:] = b.i_cab
    groups = dict(sides)
    groups[("front", 1)] = front
    for key in sorted(groups, key=lambda g: (g[0], -g[1])):
        t.apply(key[0], key[1], [dict(poly=it["poly"], mat=it["mat"], rank=r, n_min=0.5) for r, it in enumerate(groups[key])],
                cut=True)
    t.normalize()
    b.panels.setdefault(b.nname(node), []).append(t)
    import bpy
    bpy.data.objects.remove(shell)
    with b.node(node):
        # --- grille bars, sun visor, roof deflector, side fairings
        if lv == 0:
            bm = bmesh.new()
            for z in (1.45, 1.6, 1.75, 1.9):
                MU.bm_box(1.86, 0.03, 0.045, (0.0, CAB_Y1 + 0.006, z + 0.022), bm=bm)
            b.obj("grillebars", bm, grey, bevel=0.006, segs=1)
        if lv <= 1:
            # sun visor: a thin plate sloping forward over the windshield
            y_v = CAB_Y1 - 0.13
            bm = MU.prism([(y_v, 3.045), (y_v + 0.2, 2.985), (y_v + 0.2, 3.03), (y_v, 3.1)], 2.3, plane="YZ", offset=-1.15)
            b.obj("visor", bm, dark)
        if lv == 0:
            # five amber marker lamps on the front edge of the visor (lit with the tail lights, no anchors)
            bm = bmesh.new()
            for x in (-0.8, -0.4, 0.0, 0.4, 0.8):
                MU.bm_box(0.09, 0.03, 0.035, (x, CAB_Y1 + 0.075, 3.0), bm=bm)
            b.obj("roofmarkers", bm, b.mat("roofmarker", "#c86a12", 0.2), lamp="-marker:1:" + AMBER)
            # indicator repeaters on the cab sides, behind the doors
            bm = bmesh.new()
            for sx in (-1, 1):
                MU.bm_box(0.012, 0.09, 0.045, (sx * (CAB_W2 + 0.004), CAB_Y0 + 0.32, 1.47), bm=bm)
            b.obj("repeaters", bm, b.mat("repeater", "#c86a12", 0.15), lamp="ind")
        # deflector: wedge from the roof front up to the height of the trailer
        zt = 3.88
        bm = bmesh.new()
        y0, y1 = CAB_Y0 + 0.06, CAB_Y1 - 0.7
        v = [bm.verts.new(p) for p in [(-1.15, y0, CAB_Z1 - 0.01), (1.15, y0, CAB_Z1 - 0.01), (1.12, y1, CAB_Z1 - 0.01),
                                        (-1.12, y1, CAB_Z1 - 0.01), (-1.15, y0, zt), (1.15, y0, zt),
                                        (-1.14, y0 + 0.5, zt - 0.03), (1.14, y0 + 0.5, zt - 0.03)]]
        for fc in ((0, 3, 2, 1), (3, 6, 7, 2), (6, 4, 5, 7), (0, 1, 5, 4), (0, 4, 6, 3), (1, 2, 7, 5)):
            bm.faces.new([v[i] for i in fc])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        b.obj("deflector", bm, cab, bevel=0.04, segs=2)
        if lv <= 1:
            bm = bmesh.new()
            for sx in (-1, 1):
                MU.bm_box(0.045, 0.36, 1.95, (sx * (CAB_W2 - 0.025), CAB_Y0 - 0.16, 2.45), bm=bm)
            b.obj("fairings", bm, cab, bevel=0.012, segs=1)
        # --- bumper
        bmp = _box_faces(-1.262, 1.262, CAB_Y1 - 0.22, L, 0.5, 1.23)
        items = [dict(poly=_rect(-0.62, 0.56, 0.62, 0.74), mat=b.i_seal),
                 dict(poly=_rect(-0.26, 0.86, 0.26, 0.968), mat=b.flat("#eeeeea", 0.45))]
        i_head = b.flat("#dfe6ec", 0.1, 0.3, "head")
        i_ind = b.flat("#c86a12", 0.15, 0.0, "ind")
        i_drl = b.flat("#e8ebee", 0.15, 0.2, "drl")
        for sx in (-1, 1):
            u0, u1 = sorted((sx * 0.73, sx * 1.2))
            items.append(dict(poly=_rect(u0, 0.79, u1, 1.08), mat=b.i_seal))
            u0, u1 = sorted((sx * 0.75, sx * 1.0))
            items.append(dict(poly=_rect(u0, 0.86, u1, 1.06), mat=i_head))
            u0, u1 = sorted((sx * 1.02, sx * 1.18))
            items.append(dict(poly=_rect(u0, 0.86, u1, 1.06), mat=i_ind))
            u0, u1 = sorted((sx * 0.75, sx * 1.18))
            items.append(dict(poly=_rect(u0, 0.805, u1, 0.842), mat=i_drl))
        if lv <= 1:
            items.append(dict(poly=_rect(0.222, 0.86, 0.26, 0.968), mat=b.flat("#1d3c9c", 0.45)))    # left as seen from ahead
    b.panel(node, b.flat("#3a3d42", 0.45, 0.1), [bmp["f"]], {("front", 1): items})
    b.panel(node, b.flat("#3a3d42", 0.45, 0.1), [bmp[k] for k in "lRtb"])
    with b.node(node):
        # --- steps, mudguards, frame, tanks, boxes, fifth wheel
        if lv <= 1:
            bm = bmesh.new()
            for sx in (-1, 1):
                MU.bm_box(0.3, 0.34, 0.7, (sx * 1.09, 16.03, 0.87), bm=bm)
            b.obj("stepbox", bm, dark)
            if lv == 0:
                bm = bmesh.new()
                for sx in (-1, 1):
                    for z in (0.66, 0.98):
                        MU.bm_box(0.06, 0.3, 0.035, (sx * 1.262, 16.03, z), bm=bm)
                b.obj("steps", bm, alu)
        _arch_block(b, "fender_f", 0.93, 1.262, Y_FRONT, Y_FRONT - 0.66, Y_FRONT + 0.6, 0.78, CAB_Z0 + 0.004, dark,
                    n=12 if lv == 0 else (6 if lv == 1 else 2))
        _arch_block(b, "fender_r", 0.6, 1.262, Y_DRIVE, Y_DRIVE - 0.66, Y_DRIVE + 0.66, 0.86, 1.17, dark,
                    n=12 if lv == 0 else (6 if lv == 1 else 2))
        bm = bmesh.new()
        if lv == 0:
            for sx in (-1, 1):
                MU.bm_box(0.09, 5.65, 0.24, (sx * 0.42, 13.15, 0.97), bm=bm)
            for y in (10.5, 12.2, 13.9):
                MU.bm_box(0.84, 0.1, 0.16, (0.0, y, 0.97), bm=bm)
            MU.bm_cyl(0.075, 0.075, 1.9, center=(0.0, Y_DRIVE, R), axis="X", segs=8, bm=bm)
            MU.bm_cyl(0.19, 0.19, 0.36, center=(0.0, Y_DRIVE, R), axis="X", segs=10, bm=bm)     # differential
            MU.bm_cyl(0.06, 0.06, 2.0, center=(0.0, Y_FRONT, R), axis="X", segs=8, bm=bm)
            MU.bm_box(0.9, 0.9, 0.09, (0.0, 11.9, 1.135), bm=bm)                               # fifth wheel
        else:
            MU.bm_box(0.93, 5.65, 0.24, (0.0, 13.15, 0.97), bm=bm)
            if lv == 1:
                MU.bm_box(1.9, 0.14, 0.14, (0.0, Y_DRIVE, R), bm=bm)
                MU.bm_box(0.9, 0.9, 0.09, (0.0, 11.9, 1.135), bm=bm)
        b.obj("frame", bm, chassis)
        if lv <= 1:
            bm = bmesh.new()
            for sx in (-1, 1):
                MU.bm_cyl(0.33, 0.33, 1.25, center=(sx * 0.94, 13.05, 0.8), axis="Y", segs=16 if lv == 0 else 8, bm=bm)
            b.obj("tanks", bm, alu, smooth=True, sharp=50.0)
        else:
            # far level: the mirrors as plain blocks (they are part of the bounding box of every level)
            bm = bmesh.new()
            for sx in (-1, 1):
                MU.bm_box(0.13, 0.1, 0.76, (sx * 1.47, 16.2, 2.6), bm=bm)
            b.obj("mirrors", bm, dark)
        if lv <= 1:
            bm = bmesh.new()
            for sx in (-1, 1):
                MU.bm_box(0.5, 0.62, 0.62, (sx * 0.99, 14.2, 0.84), bm=bm)                    # battery / air box
                MU.bm_box(0.46, 0.018, 0.62, (sx * 1.02, Y_DRIVE - R - 0.12, 0.55), bm=bm)    # mud flaps
                if lv == 0:
                    for y in (12.7, 13.4):
                        MU.bm_box(0.04, 0.05, 0.7, (sx * 1.262, y, 0.8), bm=bm)              # tank straps
            b.obj("boxes", bm, dark)
        # --- mirrors and wipers
        if lv <= 1:
            bm = bmesh.new()
            for sx in (-1, 1):
                MU.bm_box(0.13, 0.1, 0.5, (sx * 1.47, 16.2, 2.74), bm=bm)
                MU.bm_box(0.13, 0.1, 0.2, (sx * 1.47, 16.2, 2.34), bm=bm)
                MU.bm_beam((sx * 1.22, 16.22, 3.0), (sx * 1.47, 16.22, 2.96), 0.035, bm=bm)
                MU.bm_beam((sx * 1.22, 16.22, 2.28), (sx * 1.47, 16.22, 2.3), 0.035, bm=bm)
            b.obj("mirrors", bm, dark, bevel=0.015, segs=2)
            if lv == 0:
                bm = bmesh.new()
                for sx in (-1, 1):
                    MU.bm_box(0.1, 0.006, 0.44, (sx * 1.47, 16.147, 2.74), bm=bm)
                    MU.bm_box(0.1, 0.006, 0.16, (sx * 1.47, 16.147, 2.34), bm=bm)
                b.obj("mirrorglass", bm, b.mat("mglass", "#3a4148", 0.05, 0.9))
                bm = bmesh.new()
                for x in (-0.5, 0.45):
                    MU.bm_beam((x, CAB_Y1 + 0.012, 2.17), (x + 0.5, CAB_Y1 - 0.045, 2.55), 0.02, 0.012, bm=bm)
                b.obj("wipers", bm, dark)


def _wheels(b):
    """Wheel nodes (lod0: right wheels only, the left ones are the turned mesh) or all wheels in the body."""
    pivots = {}
    spec = [("tractor/wheel_0", "front", W2 - 0.03, Y_FRONT), ("tractor/wheel_1", "drive", W2 - 0.04, Y_DRIVE)]
    spec += [("trailer/wheel_%d" % i, "trailer", W2 - 0.03, y) for i, y in enumerate(reversed(TR_AXLES))]
    for (name, kind, x_out, y) in spec:
        if b.split:
            if name in ("trailer/wheel_1", "trailer/wheel_2"):
                continue                      # same mesh as trailer/wheel_0
            with b.node(name + "r"):
                pivots[name] = _wheel(b, kind, (x_out, y, R))
        else:
            with b.node("body"):
                _wheel(b, kind, (x_out, y, R))
                _wheel(b, kind, (x_out, y, R), left=True)
    return pivots, spec


def _level(level, paints, tarp=False, word=None):
    from cesprites import meshutil as MU
    b = _Build(level, tarp=tarp, word=word)
    MU.tagging(True)
    try:
        if level <= 2:
            _trailer(b)
            _tractor(b)
            pivots, wspec = _wheels(b)
        else:
            pivots, wspec = _shadow(b), []
    finally:
        MU.tagging(False)
    soups = core.soups_of(core.model_objects(b.rig))
    tr = roles.Translator(overrides={"tk_paint2": dict(slot="paint2")}, glass_class=(level == 0), glass_opacity=0.9,
                          default_paint=paints)
    nodes = {}
    for s in soups:
        node = roles.node_of(s.ob)
        if node == "none":
            continue
        from .vehicles3d import _add_soup
        _add_soup(nodes, tr, s, node)
    for node, lst in b.panels.items():
        mb = nodes.setdefault(node, core.MeshBuilder())
        for t in lst:
            for mi in np.unique(t.mat):
                role, data, lamp = b.pal.items[int(mi)]
                sel = t.mat == mi
                tr.add_role(mb, role, dict(data), t.pos[sel], t.nor[sel], lamp)
    return b, nodes, pivots, wspec, tr


SHADOW_IN = 0.03                    # the shadow caster lies this far inside the faces of the bodies
TAPE_NIGHT = 0.8                    # glow of the retroreflective tape and reflectors in the low beam (weight of channel 15)
WHITE_MAX = 216                     # near-white liveries: largest sRGB channel (see _tone)


def _tone(hex_col):
    """Real-time colour of a livery: a near-white paint (all channels above 85 %) is brought down to WHITE_MAX.
    White paint reflects about 80 % of the light; the sprite colours (#ececea) came out as pure 255 white without any
    form on the box and the cab in real time (art review of AS1, C2)."""
    h = hex_col.lstrip("#")
    rgb = [int(h[i:i + 2], 16) for i in (0, 2, 4)]
    if min(rgb) < 217:
        return hex_col
    k = WHITE_MAX / float(max(rgb))
    return "#%02x%02x%02x" % tuple(int(round(c * k)) for c in rgb)


def _shadow(b):
    """Shadow caster: the trailer as a box, the cab as its profile, the wheels as drums, and under the cab and the
    trailer only the parts that are really there (bumper, fenders, step and battery boxes, tanks, the frame
    rails) - everything SHADOW_IN inside the visible faces (a caster in the plane of a face, or in front of a
    dished rim, throws its shadow on the very part it stands for). (A box over the whole width under the cab
    and a slab under the whole trailer stood out of the hull - 446 to 1,838 px per view in the art review - and
    shaded fenders, wheels and the rear lamp bar.)"""
    MU = b.MU
    grey = b.mat("grey", GREY)
    e = SHADOW_IN

    def inset_box(x0, x1, y0, y1, z0, z1, bm):
        if x1 - x0 > 2 * e and y1 - y0 > 2 * e and z1 - z0 > 2 * e:
            MU.bm_box(x1 - x0 - 2 * e, y1 - y0 - 2 * e, z1 - z0 - 2 * e, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), bm=bm)

    with b.node("body"):
        bm = MU.bm_box(2 * (W2 - e), TR_LEN - 2 * e, BOX_Z1 - BOX_Z0 - 2 * e, (0.0, TR_LEN / 2, (BOX_Z0 + BOX_Z1) / 2))
        # bumper, under the cab
        inset_box(-1.262, 1.262, CAB_Y1 - 0.22, L, 0.5, 1.23, bm)
        for sx in (-1, 1):
            # front fender blocks (above the wheel), step boxes, battery / air boxes, tanks (as boxes inside the
            # cylinders), frame rails of tractor and trailer
            xa, xb = sorted((sx * 0.93, sx * 1.262))
            inset_box(xa, xb, Y_FRONT - 0.66, Y_FRONT + 0.6, R + R + 0.06, CAB_Z0, bm)
            xa, xb = sorted((sx * 0.94, sx * 1.24))
            inset_box(xa, xb, 15.86, 16.2, 0.52, 1.22, bm)
            xa, xb = sorted((sx * 0.74, sx * 1.24))
            inset_box(xa, xb, 13.89, 14.51, 0.53, 1.15, bm)
            xa, xb = sorted((sx * (0.94 - 0.23), sx * (0.94 + 0.23)))
            inset_box(xa, xb, 12.43, 13.67, 0.57, 1.03, bm)
            xa, xb = sorted((sx * 0.37, sx * 0.47))
            inset_box(xa, xb, 10.33, 15.97, 0.85, 1.09, bm)
            xa, xb = sorted((sx * 0.42, sx * 0.52))
            inset_box(xa, xb, 0.25, 12.45, 0.92, 1.22, bm)
        b.obj("shadow", bm, grey)
        prof = decalgeo.inset([tuple(p) for p in CAB_PROFILE], e)
        b.obj("shadow_cab", MU.prism(prof, 2 * (CAB_W2 - e), plane="YZ", offset=-(CAB_W2 - e)), grey)
        # wheels: the inner part of the tyres (the outer part would shade the dish of the rims)
        bm = bmesh.new()
        r = R * 0.97
        for y in TR_AXLES + (Y_DRIVE, Y_FRONT):
            x_out = W2 - (0.04 if y == Y_DRIVE else 0.03)
            if y == Y_DRIVE:
                x0, x1 = x_out - (2 * TW_DRIVE + 0.035), x_out - 0.2
            else:
                x0, x1 = x_out - (TW_FRONT if y == Y_FRONT else TW_TRAILER), x_out - 0.11
            for sx in (-1, 1):
                MU.bm_cyl(r, r, x1 - x0, center=(sx * (x0 + x1) / 2, y, R), axis="X", segs=8, bm=bm)
        b.obj("shadow_wheels", bm, grey)
    return {}


def build_truck(model_id, spec3d):
    from cesprites import catalog, heavy

    from .vehicles3d import SLIVER_M, _sprite_spec
    t0 = time.time()
    colours = dict(catalog.TRAFFIC_COLORS["truck"])
    set_ids = list(spec3d.get("sets") or [])
    first = set_ids[0].split("_", 1)[1]

    def livery(cname):
        v = heavy.TRUCK_VARIANTS[cname]
        return {"paint": _tone(colours[cname]), "paint2": _tone(v["cab"]), "paint3": _tone(v["stripe"] or colours[cname]),
                "metal": 0.1}
    paints = {k: v for k, v in livery(first).items() if k != "metal"}
    # the kind of the trailer: all sets of one model must agree (a word or a curtain is geometry, not paint)
    kinds = {(bool(heavy.TRUCK_VARIANTS[sid.split("_", 1)[1]]["tarp"]), heavy.TRUCK_VARIANTS[sid.split("_", 1)[1]]["text"])
             for sid in set_ids}
    if len(kinds) != 1:
        raise ValueError("%s: the sets %s are different trailers %s" % (model_id, set_ids, sorted(kinds, key=str)))
    tarp, word = kinds.pop()
    sspec = _sprite_spec(spec3d["source"])
    origin = np.array([0.0, L / 2.0, 0.0])
    model = ModelData(model_id, spec3d["kind"], {"width_m": 2 * W2, "length_m": L, "height_m": H})
    lods = []
    for level in (0, 1, 2):
        b, nodes, pivots, wspec, tr = _level(level, paints, tarp, word)
        name = "lod%d" % level
        if level == 0:
            model.lights = tr.lights(origin=origin)
            kp = np.array(KINGPIN)
            parts = [Part("tractor/body", "lod0_tractor", nodes["tractor/body"].finish(origin=origin, min_height=SLIVER_M))]
            wheel_parts = []
            meshes = {}
            for (wname, kind, x_out, y) in wspec:
                src = wname if wname in pivots else "trailer/wheel_0"
                key = "wheel_" + kind
                if key not in meshes:
                    meshes[key] = nodes[src + "r"].finish(origin=np.array(pivots[src]), min_height=SLIVER_M)
                xc = pivots[src][0]
                for side in ("l", "r"):
                    p = np.array([xc if side == "r" else -xc, y, R]) - origin
                    wheel_parts.append(Part(wname + side, key, meshes[key], pos=core.model_point(p),
                                            yaw_deg=180.0 if side == "l" else 0.0,
                                            wheel={"radius": R, "steer": wname == "tractor/wheel_0"}, auto_lod=False))
            parts += [p for p in wheel_parts if p.node.startswith("tractor/")]
            parts.append(Part("trailer/body", "lod0_trailer", nodes["trailer/body"].finish(origin=kp, min_height=SLIVER_M),
                              pos=core.model_point(kp - origin)))
            parts += [p for p in wheel_parts if p.node.startswith("trailer/")]
            lods.append(Lod(name, LOD_DIST[name], parts))
            model.extra["groups"] = {"tractor": {"pivot": core.model_point(np.array([0.0, Y_DRIVE, 0.0]) - origin)},
                                     "trailer": {"pivot": core.model_point(kp - origin)}}
        else:
            lods.append(Lod(name, LOD_DIST[name], [Part("body", name + "_body",
                                                        nodes["body"].finish(origin=origin, min_height=SLIVER_M))]))
    b, nodes, _p, _w, _tr = _level(3, paints, tarp, word)
    model.shadow = Part("body", "shadow", nodes["body"].finish(origin=origin))
    model.lods = lods
    model.paint = livery(first)
    model.tags = list(sspec.get("tags", []))
    for sid in set_ids:
        model.sets[sid] = {"model": model_id, "paint": livery(sid.split("_", 1)[1])}
    model.stats = dict(build_s=round(time.time() - t0, 2), tarp=tarp, word=word)
    return model
