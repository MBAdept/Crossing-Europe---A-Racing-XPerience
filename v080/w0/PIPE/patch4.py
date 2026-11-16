"""Hook patch 4: traffic cars (cesprites/vehicles.py) - detail levels, node tags, lamp tags of the decals."""
from patchlib import patch

patch("tools/blender/cesprites/vehicles.py", [
    # --- module: detail defaults + ring helpers
    ('''BUMPER_OUT = 0.035      # rear bumper protrudes behind the lower body (lower body starts here)
''', '''BUMPER_OUT = 0.035      # rear bumper protrudes behind the lower body (lower body starts here)

# 3D pipeline hook (ce3d/lod.py): level of detail of a build. These defaults give the sprite model.
#   subsurf  subdivision level of the body lofts            ring   cross-section: 1 = as designed, 2 = every
#   step     scale of the station spacing along the car             segment halved (spline), 0 = corners only
#   wheel    scale of the segment counts of tyres and rims  bevel  bevelled mirrors / wings
#   mirrors  door mirrors                                    small  mirror glass, exhaust tips, plate characters
DETAIL = dict(subsurf=1, ring=1, step=1.0, wheel=1.0, bevel=True, mirrors=True, small=True)
LOWER_COARSE = (0, 1, 3, 4, 6, 8, 9)          # points of lower_half kept at ring 0
CABIN_COARSE = (0, 1, 2, 3, 5, 7, 8, 9)       # points of cabin_half kept at ring 0


def refine_half(pts):
    """Halves every segment of a half cross-section [(x, z)] (bottom centre .. top centre) along a
    Catmull-Rom spline; the neighbours beyond the ends are the mirrored points of the other half."""
    n = len(pts)
    out = []
    for i in range(n - 1):
        p0 = pts[i - 1] if i > 0 else (-pts[1][0], pts[1][1])
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[i + 2] if i + 2 < n else (-pts[-2][0], pts[-2][1])
        out.append(p1)
        out.append(((-p0[0] + 9.0 * p1[0] + 9.0 * p2[0] - p3[0]) / 16.0,
                    (-p0[1] + 9.0 * p1[1] + 9.0 * p2[1] - p3[1]) / 16.0))
    out.append(pts[-1])
    return out
'''),
    # --- constructor
    ('''    def __init__(self, rig, d, paint="#888888", livery=None, metal=0.35, extras=None, name="car"):
        self.rig = rig
        self.d = dict(d)
''', '''    def __init__(self, rig, d, paint="#888888", livery=None, metal=0.35, extras=None, name="car", detail=None):
        self.rig = rig
        self.d = dict(d)
        self.detail = dict(DETAIL)
        self.detail.update(detail or {})
        self.bumper_obs = {}        # "rear" / "front" -> object (ce3d/decalgeo.py)
'''),
    # --- ring helper method (before build)
    ('''    # --- parts ----------------------------------------------------------------------------------

    def build(self):
''', '''    def _ring(self, half, coarse):
        """Half cross-section at the detail level of the build (ring 1 = unchanged)."""
        r = self.detail["ring"]
        if r == 1:
            return half
        if r >= 2:
            return refine_half(half)
        return [half[i] for i in coarse]

    def _segs(self, n):
        """Segment count of a lathed part at the detail level (wheel 1.0 = unchanged)."""
        k = self.detail["wheel"]
        return n if k == 1.0 else max(6, int(round(n * k)))

    # --- parts ----------------------------------------------------------------------------------

    def build(self):
'''),
    # --- lower body
    ('''        y0, y1 = BUMPER_OUT, self.L - 0.02
        dense = []
        for ya in (self.y_ra, self.y_fa):
            dense.append((ya - self.Ra, ya + self.Ra, 0.03))
        extra = _end_ys(y0, max(dd["plan_r"][0], dd["r_end"][0]) + 0.02)
        extra += [y1 - v + y0 for v in _end_ys(y0, max(dd["plan_r"][1], dd["r_end"][1]) + 0.02)]
        for ya in (self.y_ra, self.y_fa):
            extra += [ya - self.Ra - 0.003, ya - self.Ra + 0.003, ya + self.Ra - 0.003, ya + self.Ra + 0.003]
        extra += [p[0] for p in dd["lower"]]
        ys = _stations(y0, y1, 0.08, extra, dense)
        rings = []
        for y in ys:
            w, zb, zt = self.lower_frame(y)
            half = self.lower_half(w, zb, zt)
            rings.append([(x, y, z) for (x, z) in MU.mirror_ring(half)])
        bm = MU.loft(rings)
        ob = MU.make(self.name + "_lower", bm, mat, parent=self.rig.root, smooth=True, sharp_deg=48)
        _smooth_body(ob)
''', '''        y0, y1 = BUMPER_OUT, self.L - 0.02
        k = self.detail["step"]                     # 1.0 for the sprite model
        n_end = 7 if k == 1.0 else max(2, int(round(7 / k)))
        edge = 0.003 if k < 3.0 else 0.0
        dense = []
        for ya in (self.y_ra, self.y_fa):
            dense.append((ya - self.Ra, ya + self.Ra, 0.03 * k))
        extra = _end_ys(y0, max(dd["plan_r"][0], dd["r_end"][0]) + 0.02, n_end)
        extra += [y1 - v + y0 for v in _end_ys(y0, max(dd["plan_r"][1], dd["r_end"][1]) + 0.02, n_end)]
        for ya in (self.y_ra, self.y_fa):
            extra += [ya - self.Ra - edge, ya - self.Ra + edge, ya + self.Ra - edge, ya + self.Ra + edge]
        extra += [p[0] for p in dd["lower"]]
        ys = _stations(y0, y1, 0.08 * k, extra, dense)
        rings = []
        for y in ys:
            w, zb, zt = self.lower_frame(y)
            half = self._ring(self.lower_half(w, zb, zt), LOWER_COARSE)
            rings.append([(x, y, z) for (x, z) in MU.mirror_ring(half)])
        bm = MU.loft(rings)
        ob = MU.make(self.name + "_lower", bm, mat, parent=self.rig.root, smooth=True, sharp_deg=48)
        _smooth_body(ob, self.detail["subsurf"])
'''),
    # --- greenhouse
    ('''        ys = _stations(y0, y1, 0.05, [p[0] for p in cab] + [y0 + 0.01, y1 - 0.01])
        rings = []
        for y in ys:
            wb, zb, zt = self.cabin_frame(y)
            half = self.cabin_half(wb, zb, zt, dd["tumble"], rc=dd.get("roof_rc", 0.075))
            rings.append([(x, y, z) for (x, z) in MU.mirror_ring(half)])
        bm = MU.loft(rings)
        ob = MU.make(self.name + "_greenhouse", bm, mat, parent=self.rig.root, smooth=True, sharp_deg=32)
        _smooth_body(ob)
''', '''        ys = _stations(y0, y1, 0.05 * self.detail["step"], [p[0] for p in cab] + [y0 + 0.01, y1 - 0.01])
        rings = []
        for y in ys:
            wb, zb, zt = self.cabin_frame(y)
            half = self._ring(self.cabin_half(wb, zb, zt, dd["tumble"], rc=dd.get("roof_rc", 0.075)), CABIN_COARSE)
            rings.append([(x, y, z) for (x, z) in MU.mirror_ring(half)])
        bm = MU.loft(rings)
        ob = MU.make(self.name + "_greenhouse", bm, mat, parent=self.rig.root, smooth=True, sharp_deg=32)
        _smooth_body(ob, self.detail["subsurf"])
'''),
    # --- bumpers
    ('''            r_e = 0.05
            ys = sorted(set([ya + v for v in _end_ys(0, r_e + 0.12, 6)] + [yb - v for v in _end_ys(0, r_e + 0.12, 6)] +
                            [ya + (yb - ya) * i / 8 for i in range(9)]))
''', '''            r_e = 0.05
            ks = self.detail["step"]
            n_e = 6 if ks == 1.0 else max(2, int(round(6 / ks)))
            n_u = 8 if ks == 1.0 else max(1, int(round(8 / ks)))
            ys = sorted(set([ya + v for v in _end_ys(0, r_e + 0.12, n_e)] + [yb - v for v in _end_ys(0, r_e + 0.12, n_e)] +
                            [ya + (yb - ya) * i / n_u for i in range(n_u + 1)]))
'''),
    ('''                half = self.lower_half(ww, zb, zt, crown=0.0)
                rings.append([(x, y, z) for (x, z) in MU.mirror_ring(half)])
            bm = MU.loft(rings)
            ob = MU.make(self.name + ("_fbumper" if front else "_rbumper"), bm, mat, parent=self.rig.root,
                         smooth=True, sharp_deg=50)
            _smooth_body(ob)
            self.parts.append(ob)
''', '''                half = self._ring(self.lower_half(ww, zb, zt, crown=0.0), LOWER_COARSE)
                rings.append([(x, y, z) for (x, z) in MU.mirror_ring(half)])
            bm = MU.loft(rings)
            ob = MU.make(self.name + ("_fbumper" if front else "_rbumper"), bm, mat, parent=self.rig.root,
                         smooth=True, sharp_deg=50)
            _smooth_body(ob, self.detail["subsurf"])
            self.parts.append(ob)
            self.bumper_obs["front" if front else "rear"] = ob
'''),
    # --- wheels
    ('''        for ya in (self.y_ra, self.y_fa):
            tw = dd["tire_w"] if ya == self.y_fa else dd.get("tire_w_rear", dd["tire_w"])
            for side in (-1, 1):
                xo = side * (self.W2 - dd["wheel_inset"])
                xc = xo - side * tw / 2
                prof = [(R * 0.64, -tw / 2), (R * 0.9, -tw / 2), (R * 0.975, -tw / 2 + 0.022), (R, -tw / 2 + 0.05),
                        (R, tw / 2 - 0.05), (R * 0.975, tw / 2 - 0.022), (R * 0.9, tw / 2), (R * 0.64, tw / 2)]
                bm = MU.bm_lathe(prof, segs=28, axis="X", center=(xc, ya, R))
                ob = MU.make(self.name + "_tyre", bm, tire, parent=self.rig.root, smooth=True, sharp_deg=60)
                self.parts.append(ob)
                # rim: dark dish + bright lip + spokes
                rr = R * 0.66
                xf = xo - side * 0.03
                bm = MU.bm_cyl(rr, rr, 0.02, center=(xf - side * 0.02, ya, R), axis="X", segs=24)
                MU.make(self.name + "_dish", bm, rim_dark, parent=self.rig.root)
                lip = [(rr * 0.9, -0.012), (rr * 1.0, -0.012), (rr * 1.0, 0.012), (rr * 0.9, 0.012)]
                bm = MU.bm_lathe(lip, segs=28, axis="X", center=(xf, ya, R))
                spokes = dd.get("spokes", 5)
                for i in range(spokes):
                    a = 2 * math.pi * i / spokes + 0.3
                    p1 = (xf, ya + math.cos(a) * rr * 0.18, R + math.sin(a) * rr * 0.18)
                    p2 = (xf, ya + math.cos(a) * rr * 0.92, R + math.sin(a) * rr * 0.92)
                    MU.bm_beam(p1, p2, 0.016, rr * dd.get("spoke_w", 0.28), bm=bm, up=(1, 0, 0))
                MU.bm_cyl(rr * 0.22, rr * 0.18, 0.03, center=(xf, ya, R), axis="X", segs=12, bm=bm)
                MU.make(self.name + "_rim", bm, rim, parent=self.rig.root)
''', '''        simple = self.detail["wheel"] < 0.6        # far levels of the 3D models: tyre and dish only
        for ya in (self.y_ra, self.y_fa):
            tw = dd["tire_w"] if ya == self.y_fa else dd.get("tire_w_rear", dd["tire_w"])
            for side in (-1, 1):
                xo = side * (self.W2 - dd["wheel_inset"])
                xc = xo - side * tw / 2
                prof = [(R * 0.64, -tw / 2), (R * 0.9, -tw / 2), (R * 0.975, -tw / 2 + 0.022), (R, -tw / 2 + 0.05),
                        (R, tw / 2 - 0.05), (R * 0.975, tw / 2 - 0.022), (R * 0.9, tw / 2), (R * 0.64, tw / 2)]
                if simple:
                    prof = [prof[0], prof[3], prof[4], prof[7]]
                # 3D models: a wheel is its own node (pivot = wheel centre); no effect on sprite builds
                node = MU.node("wheel_%d%s" % (0 if ya == self.y_fa else 1, "l" if side < 0 else "r"),
                               pivot=(xc, ya, R))
                node.__enter__()
                bm = MU.bm_lathe(prof, segs=self._segs(28), axis="X", center=(xc, ya, R))
                ob = MU.make(self.name + "_tyre", bm, tire, parent=self.rig.root, smooth=True, sharp_deg=60)
                self.parts.append(ob)
                # rim: dark dish + bright lip + spokes
                rr = R * 0.66
                xf = xo - side * 0.03
                bm = MU.bm_cyl(rr, rr, 0.02, center=(xf - side * 0.02, ya, R), axis="X", segs=self._segs(24))
                MU.make(self.name + "_dish", bm, rim_dark if not simple else rim, parent=self.rig.root)
                if simple:
                    node.__exit__()
                    continue
                lip = [(rr * 0.9, -0.012), (rr * 1.0, -0.012), (rr * 1.0, 0.012), (rr * 0.9, 0.012)]
                bm = MU.bm_lathe(lip, segs=self._segs(28), axis="X", center=(xf, ya, R))
                spokes = dd.get("spokes", 5)
                for i in range(spokes):
                    a = 2 * math.pi * i / spokes + 0.3
                    p1 = (xf, ya + math.cos(a) * rr * 0.18, R + math.sin(a) * rr * 0.18)
                    p2 = (xf, ya + math.cos(a) * rr * 0.92, R + math.sin(a) * rr * 0.92)
                    MU.bm_beam(p1, p2, 0.016, rr * dd.get("spoke_w", 0.28), bm=bm, up=(1, 0, 0))
                MU.bm_cyl(rr * 0.22, rr * 0.18, 0.03, center=(xf, ya, R), axis="X", segs=self._segs(12), bm=bm)
                MU.make(self.name + "_rim", bm, rim, parent=self.rig.root)
                node.__exit__()
'''),
    # --- mirrors
    ('''        zm = zt + dd.get("mirror_dz", 0.1)
        for side in (-1, 1):
            xm = side * (self.W2 + 0.07)
            bm = MU.bm_box(0.17, 0.09, 0.11, (xm, ym, zm))
            MU.bm_beam((side * (self.W2 - 0.08), ym + 0.02, zm - 0.04), (xm, ym + 0.01, zm - 0.03), 0.03, 0.03, bm=bm)
            ob = MU.make(self.name + "_mirror", bm, body_mat, parent=self.rig.root)
            MU.bevel(ob, 0.02, 2)
            bm = MU.bm_box(0.14, 0.01, 0.085, (xm, ym - 0.05, zm))
            MU.make(self.name + "_mirrorglass", bm, glass, parent=self.rig.root)
''', '''        zm = zt + dd.get("mirror_dz", 0.1)
        if not self.detail["mirrors"]:
            return
        for side in (-1, 1):
            xm = side * (self.W2 + 0.07)
            bm = MU.bm_box(0.17, 0.09, 0.11, (xm, ym, zm))
            MU.bm_beam((side * (self.W2 - 0.08), ym + 0.02, zm - 0.04), (xm, ym + 0.01, zm - 0.03), 0.03, 0.03, bm=bm)
            ob = MU.make(self.name + "_mirror", bm, body_mat, parent=self.rig.root)
            if self.detail["bevel"]:
                MU.bevel(ob, 0.02, 2)
            if not self.detail["small"]:
                continue
            bm = MU.bm_box(0.14, 0.01, 0.085, (xm, ym - 0.05, zm))
            MU.make(self.name + "_mirrorglass", bm, glass, parent=self.rig.root)
'''),
    # --- extras: bevels, exhaust, plate text
    ('''            ob = MU.make(self.name + "_wing", bm, mat, parent=self.rig.root)
            MU.bevel(ob, 0.012, 2)
''', '''            ob = MU.make(self.name + "_wing", bm, mat, parent=self.rig.root)
            if self.detail["bevel"]:
                MU.bevel(ob, 0.012, 2)
'''),
    ('''            ob = MU.make(self.name + "_spoiler", bm, body_mat, parent=self.rig.root)
            MU.bevel(ob, 0.015, 2)
''', '''            ob = MU.make(self.name + "_spoiler", bm, body_mat, parent=self.rig.root)
            if self.detail["bevel"]:
                MU.bevel(ob, 0.015, 2)
'''),
    ('''        exhaust = ex.get("exhaust", [(0.5, 0.28)])
        chrome = M.basic(self.name + "_chrome", "#d6d8db", rough=0.12, metal=1.0)
''', '''        if not self.detail["small"]:
            return
        exhaust = ex.get("exhaust", [(0.5, 0.28)])
        chrome = M.basic(self.name + "_chrome", "#d6d8db", rough=0.12, metal=1.0)
'''),
    ('''            bm = MU.bm_cyl(r, r, 0.09, center=(xe, 0.03, ze), axis="Y", segs=16)
            MU.make(self.name + "_exh", bm, chrome, parent=self.rig.root)
            bm = MU.bm_cyl(r * 0.75, r * 0.75, 0.01, center=(xe, -0.018, ze), axis="Y", segs=16)
''', '''            bm = MU.bm_cyl(r, r, 0.09, center=(xe, 0.03, ze), axis="Y", segs=self._segs(16))
            MU.make(self.name + "_exh", bm, chrome, parent=self.rig.root)
            bm = MU.bm_cyl(r * 0.75, r * 0.75, 0.01, center=(xe, -0.018, ze), axis="Y", segs=self._segs(16))
'''),
    # --- lamp tags of the decals (key "lamp": channel for ce3d/roles.py; the sprite shader ignores it)
    ('''            dec.append(dict(face="rear", poly=[(0.0, z0), (hw, z0), (hw, z1), (0.0, z1)], mat="lamp_red_dark",
                            emit={"brake": (BRAKE_RED, 6.0)}, n=0.2))
''', '''            dec.append(dict(face="rear", poly=[(0.0, z0), (hw, z0), (hw, z1), (0.0, z1)], mat="lamp_red_dark",
                            emit={"brake": (BRAKE_RED, 6.0)}, n=0.2, lamp="brake"))
'''),
    ('''            dict(face="rear", poly=[(0.0, pz), (0.26, pz), (0.26, pz + 0.11), (0.0, pz + 0.11)], mat="plate", emit=emit),
''', '''            dict(face="rear", poly=[(0.0, pz), (0.26, pz), (0.26, pz + 0.11), (0.0, pz + 0.11)], mat="plate", emit=emit,
                 lamp="plate:0.6"),
'''),
    ('''            if part == "tail":
                d.update(mat=lp.get("mat", "lamp_red"), emit={"tail": (TAIL_RED, lp.get("tail", 1.6)),
                                                              "brake": (BRAKE_RED, lp.get("brake", 3.2))})
            elif part == "tail_only":
                d.update(mat=lp.get("mat", "lamp_red"), emit={"tail": (TAIL_RED, lp.get("tail", 2.2))})
            elif part == "brake_only":
                d.update(mat=lp.get("mat", "lamp_red"), emit={"brake": (BRAKE_RED, lp.get("brake", 4.0))})
            elif part == "indicator":
                d.update(mat="lamp_amber")
            elif part == "reverse":
                d.update(mat="lamp_clear")
            elif part == "head":
                d.update(mat=lp.get("mat", "lamp_clear"))
            elif part == "drl":
                d.update(mat="lamp_clear")
            elif part == "black":
                d.update(mat="gloss_black")
            elif part == "reflector":
                d.update(mat="reflector", emit={"tail": ("#ff2a10", 0.5)})
            else:
                d.update(mat=part)
            out.append(d)
''', '''            if part == "tail":
                d.update(mat=lp.get("mat", "lamp_red"), emit={"tail": (TAIL_RED, lp.get("tail", 1.6)),
                                                              "brake": (BRAKE_RED, lp.get("brake", 3.2))})
            elif part == "tail_only":
                d.update(mat=lp.get("mat", "lamp_red"), emit={"tail": (TAIL_RED, lp.get("tail", 2.2))})
            elif part == "brake_only":
                d.update(mat=lp.get("mat", "lamp_red"), emit={"brake": (BRAKE_RED, lp.get("brake", 4.0))})
            elif part == "indicator":
                d.update(mat="lamp_amber")
            elif part == "reverse":
                d.update(mat="lamp_clear")
            elif part == "head":
                d.update(mat=lp.get("mat", "lamp_clear"))
            elif part == "drl":
                d.update(mat="lamp_clear")
            elif part == "black":
                d.update(mat="gloss_black")
            elif part == "reflector":
                d.update(mat="reflector", emit={"tail": ("#ff2a10", 0.5)})
            else:
                d.update(mat=part)
            if part in LAMP_TAGS:
                d["lamp"] = LAMP_TAGS[part]
            out.append(d)
'''),
    ('''def _smooth_body(ob):
    """Softer traffic bodies (contract v2): sharp edges only at real creases, one subdivision level."""
    me = ob.data
    me.set_sharp_from_angle(angle=math.radians(70))
    m = ob.modifiers.new("subd", "SUBSURF")
    m.levels = 1
    m.render_levels = 1
    m.boundary_smooth = "PRESERVE_CORNERS"
''', '''# lamp channel of a lamp part in the 3D models (ce3d/roles.py); the sprite light layers know only tail / brake
LAMP_TAGS = {"tail": "tail_brake", "tail_only": "tail", "brake_only": "brake", "indicator": "ind",
             "reverse": "reverse", "head": "head", "drl": "drl", "reflector": "tail:0.3"}


def _smooth_body(ob, levels=1):
    """Softer traffic bodies (contract v2): sharp edges only at real creases, one subdivision level
    (levels 0: the 3D levels of detail build their own, finer or coarser cross-sections instead)."""
    me = ob.data
    me.set_sharp_from_angle(angle=math.radians(70))
    if levels <= 0:
        return
    m = ob.modifiers.new("subd", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    m.boundary_smooth = "PRESERVE_CORNERS"
'''),
])
