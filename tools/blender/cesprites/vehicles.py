"""Parametric passenger cars (hatch, sedan, wagon, suv, van, sports + player/police variants).

Vehicle space: y = 0 at the rear bumper (sprite anchor), +y forward, x = 0 centre line, z = 0 ground.
A car = lofted lower body (with wheel arches) + lofted greenhouse (glass by shader masks) + bumpers +
wheels + mirrors + extras. Lamps, plates, seams are shader decals on the body (crisp at any size); the
light layers come from the decals' emission colours.
"""
import math

from . import materials as M
from . import meshutil as MU

BUMPER_OUT = 0.035      # rear bumper protrudes behind the lower body (lower body starts here)

TAIL_RED = "#ff1a0e"
BRAKE_RED = "#ff2414"


def interp(profile, y):
    """Piecewise linear interpolation in a [(y, v)] profile (clamped)."""
    if y <= profile[0][0]:
        return profile[0][1]
    for (y0, v0), (y1, v1) in zip(profile[:-1], profile[1:]):
        if y0 <= y <= y1:
            t = 0.0 if y1 == y0 else (y - y0) / (y1 - y0)
            return v0 + (v1 - v0) * t
    return profile[-1][1]


def corner(d, r):
    """Inset of a rounded end of radius r at distance d from the end."""
    if r <= 0 or d >= r:
        return 0.0
    d = max(d, 0.0)
    return r - math.sqrt(max(0.0, r * r - (r - d) ** 2))


def _stations(y0, y1, step, extra=(), dense=()):
    ys = set()
    n = max(2, int(math.ceil((y1 - y0) / step)))
    for i in range(n + 1):
        ys.add(round(y0 + (y1 - y0) * i / n, 5))
    for e in extra:
        if y0 <= e <= y1:
            ys.add(round(e, 5))
    for (a, b, st) in dense:
        a, b = max(a, y0), min(b, y1)
        if b <= a:
            continue
        k = max(1, int(math.ceil((b - a) / st)))
        for i in range(k + 1):
            ys.add(round(a + (b - a) * i / k, 5))
    return sorted(ys)


def _end_ys(y0, r, n=7):
    """Stations clustered towards an end (y0) over distance r (cosine spacing)."""
    return [y0 + r * (1 - math.cos(math.pi / 2 * i / n)) for i in range(n + 1)]


class Car:
    """Builds one car model from a design dict (see DESIGNS) into the rig root."""

    def __init__(self, rig, d, paint="#888888", livery=None, metal=0.35, extras=None, name="car"):
        self.rig = rig
        self.d = dict(d)
        self.paint = paint
        self.livery = livery or {}
        self.metal = metal
        self.name = name
        self.parts = []
        dd = self.d
        dd.setdefault("clearance", 0.15)
        dd.setdefault("tumble", 0.22)
        dd.setdefault("shoulder_in", 0.07)
        dd.setdefault("r_end", (0.09, 0.12))
        dd.setdefault("plan_r", (0.20, 0.38))
        dd.setdefault("bumper", dict(z=(0.0, 0.56), out=0.012))
        dd.setdefault("wheel_inset", 0.05)
        self.L = dd["L"]
        self.W2 = dd["W"] / 2.0
        self.y_ra = BUMPER_OUT + dd["r_oh"]
        self.y_fa = self.y_ra + dd["wb"]
        self.R = dd["wheel_r"]
        self.Ra = self.R + 0.045

    def object_size(self):
        h = max(p[1] for p in self.d["cabin"]) + 0.03
        return {"width_m": round(self.d["W"], 3), "length_m": round(self.L, 3), "height_m": round(h, 3)}

    # --- geometry functions ---------------------------------------------------------------------

    def bottom_at(self, y):
        zb = self.d["clearance"]
        for ya in (self.y_ra, self.y_fa):
            dy = abs(y - ya)
            if dy < self.Ra:
                zb = max(zb, self.R + math.sqrt(self.Ra * self.Ra - dy * dy))
        return zb

    def lower_frame(self, y):
        """(half width, bottom z, top z) of the lower body at station y, including end rounding."""
        dd = self.d
        y0, y1 = BUMPER_OUT, self.L - 0.02
        dr, df = y - y0, y1 - y
        re, fe = dd["r_end"]
        e = corner(dr, re) + corner(df, fe)
        pc = corner(dr, dd["plan_r"][0]) + corner(df, dd["plan_r"][1])
        w = self.W2 - pc - e * 0.5
        zt = interp(dd["lower"], y) - e * 0.85
        zb = self.bottom_at(y) + e * 0.5
        return w, zb, zt

    @staticmethod
    def lower_half(w, zb, zt, crown=0.025):
        h = max(zt - zb, 0.02)
        rb = min(0.05, h * 0.2)
        rt = min(0.10, h * 0.3)
        return [
            (0.0, zb),
            (w - rb * 1.6, zb),
            (w - rb * 0.45, zb + rb * 0.35),
            (w, zb + rb * 1.4),
            (w, zb + h * 0.45),
            (w - 0.01, zt - rt * 1.5),
            (w - rt * 0.42, zt - rt * 0.42),
            (w - rt * 1.4, zt),
            (w * 0.5, zt + crown * 0.8),
            (0.0, zt + crown),
        ]

    def cabin_frame(self, y):
        dd = self.d
        w, zb_l, zt_l = self.lower_frame(y)
        zt = interp(dd["cabin"], y)
        zb = zt_l - 0.035
        wb = w - dd["shoulder_in"]
        return wb, zb, max(zt, zb + 0.012)

    @staticmethod
    def cabin_half(wb, zb, zt, tumble, rc=0.075, crown=0.03):
        h = zt - zb
        rc = min(rc, h * 0.35)
        wt = wb - tumble * h
        cx, cz = wt - rc, zt - rc
        pts = [(0.0, zb), (wb, zb), (wb - tumble * h * 0.5, zb + h * 0.5)]
        for i in range(5):
            a = math.radians(i * 22.5)
            pts.append((cx + rc * math.cos(a), cz + rc * math.sin(a)))
        pts.append((cx * 0.5, zt + crown * 0.8))
        pts.append((0.0, zt + crown))
        return pts

    # --- parts ----------------------------------------------------------------------------------

    def build(self):
        dd = self.d
        root = self.rig.root
        lv = self.livery
        body_mat = M.surface(self.name + "_body", self.paint, metal=self.metal, rough=0.28, coat=0.8,
                             livery=lv.get("bands"), decals=self.body_decals(), plastic_below=dd.get("cladding"),
                             roof_color=lv.get("roof_color"), roof_z=lv.get("roof_z"))
        cab_mat = M.surface(self.name + "_cabin", self.paint, metal=self.metal, rough=0.28, coat=0.8,
                            livery=lv.get("bands"), windows=self.windows(), decals=self.cabin_decals(),
                            roof_color=lv.get("roof_color"), roof_z=lv.get("roof_z"))
        bump_mat = M.surface(self.name + "_bumper", self.paint if not dd.get("black_bumpers") else "#1b1c1e",
                             metal=self.metal if not dd.get("black_bumpers") else 0.0, rough=0.3, coat=0.7,
                             livery=lv.get("bands"), decals=self.bumper_decals(),
                             plastic_below=dd["bumper"].get("plastic", 0.25))
        self.dark = M.basic(self.name + "_dark", "#121314", rough=0.7)
        self.body = self.lower_body(body_mat)
        self.cabin = self.greenhouse(cab_mat)
        self.bumpers(bump_mat)
        self.wells()
        self.wheels()
        self.mirrors(body_mat)
        self.extras(body_mat)
        return self

    def lower_body(self, mat):
        dd = self.d
        y0, y1 = BUMPER_OUT, self.L - 0.02
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
        self.parts.append(ob)
        return ob

    def greenhouse(self, mat):
        dd = self.d
        cab = dd["cabin"]
        y0, y1 = cab[0][0], cab[-1][0]
        ys = _stations(y0, y1, 0.05, [p[0] for p in cab] + [y0 + 0.01, y1 - 0.01])
        rings = []
        for y in ys:
            wb, zb, zt = self.cabin_frame(y)
            half = self.cabin_half(wb, zb, zt, dd["tumble"], rc=dd.get("roof_rc", 0.075))
            rings.append([(x, y, z) for (x, z) in MU.mirror_ring(half)])
        bm = MU.loft(rings)
        ob = MU.make(self.name + "_greenhouse", bm, mat, parent=self.rig.root, smooth=True, sharp_deg=32)
        _smooth_body(ob)
        self.parts.append(ob)
        return ob

    def bumpers(self, mat):
        dd = self.d
        bz0, bz1 = dd["bumper"]["z"]
        out = dd["bumper"].get("out", 0.012)
        # rear bumper: y from 0 to the rear arch
        for front in (False, True):
            if front:
                fz = dd.get("front_bumper_z", (bz0, bz1 - 0.02))
                ya, yb = self.y_fa + self.Ra + 0.01, self.L
                z0, z1 = fz
            else:
                ya, yb = 0.0, self.y_ra - self.Ra - 0.01
                z0, z1 = bz0, bz1
            if yb - ya < 0.05:
                continue
            r_e = 0.05
            ys = sorted(set([ya + v for v in _end_ys(0, r_e + 0.12, 6)] + [yb - v for v in _end_ys(0, r_e + 0.12, 6)] +
                            [ya + (yb - ya) * i / 8 for i in range(9)]))
            ys = [y for y in ys if ya <= y <= yb]
            rings = []
            for y in ys:
                d_end = (y - ya) if not front else (yb - y)
                e = corner(d_end, r_e)
                ref_y = max(y, BUMPER_OUT + 0.001) if not front else min(y, self.L - 0.021)
                w, zb_body, zt_body = self.lower_frame(ref_y)
                pc_extra = corner(d_end, dd["plan_r"][1 if front else 0] * 0.7)
                ww = min(w + out, self.W2 + out) - e * 0.6 - pc_extra * 0.3
                zb = max(dd["clearance"] - 0.02, z0 if z0 > 0 else dd["clearance"] - 0.02) + e * 0.5
                zt = z1 - e * 0.6
                half = self.lower_half(ww, zb, zt, crown=0.0)
                rings.append([(x, y, z) for (x, z) in MU.mirror_ring(half)])
            bm = MU.loft(rings)
            ob = MU.make(self.name + ("_fbumper" if front else "_rbumper"), bm, mat, parent=self.rig.root,
                         smooth=True, sharp_deg=50)
            _smooth_body(ob)
            self.parts.append(ob)

    def wells(self):
        dd = self.d
        xi = self.W2 - dd["wheel_inset"] - dd["tire_w"] * 0.75
        import bmesh
        bm = bmesh.new()
        for ya in (self.y_ra, self.y_fa):
            # fill the arch behind the tyre, but stay below the body surface (no poking through the hood)
            zt_min = min(self.lower_frame(ya + self.Ra * (k / 4.0 - 1.0))[2] for k in range(9))
            top = min(self.R + self.Ra + 0.025, zt_min - 0.07)
            z0 = dd["clearance"] - 0.02
            MU.bm_box(2 * xi, 2 * self.Ra + 0.02, top - z0, (0.0, ya, (top + z0) * 0.5), bm=bm)
        ob = MU.make(self.name + "_wells", bm, self.dark, parent=self.rig.root)
        self.parts.append(ob)

    def wheels(self):
        import bmesh
        dd = self.d
        R = self.R
        tire = M.basic(self.name + "_tyre", "#17181a", rough=0.85, spec=0.3)
        rim_col = dd.get("rim_color", "#b8bcc2")
        rim = M.basic(self.name + "_rim", rim_col, rough=0.25, metal=1.0)
        rim_dark = M.basic(self.name + "_rimdark", "#1e1f22", rough=0.5, metal=0.2)
        for ya in (self.y_ra, self.y_fa):
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

    def mirrors(self, body_mat):
        dd = self.d
        import bmesh
        glass = M.basic(self.name + "_mglass", "#3a4148", rough=0.05, metal=0.9)
        ym = dd.get("mirror_y", dd["cabin"][-1][0] - 0.15)
        wl, zb, zt = self.lower_frame(ym)
        zm = zt + dd.get("mirror_dz", 0.1)
        for side in (-1, 1):
            xm = side * (self.W2 + 0.07)
            bm = MU.bm_box(0.17, 0.09, 0.11, (xm, ym, zm))
            MU.bm_beam((side * (self.W2 - 0.08), ym + 0.02, zm - 0.04), (xm, ym + 0.01, zm - 0.03), 0.03, 0.03, bm=bm)
            ob = MU.make(self.name + "_mirror", bm, body_mat, parent=self.rig.root)
            MU.bevel(ob, 0.02, 2)
            bm = MU.bm_box(0.14, 0.01, 0.085, (xm, ym - 0.05, zm))
            MU.make(self.name + "_mirrorglass", bm, glass, parent=self.rig.root)

    def extras(self, body_mat):
        dd = self.d
        import bmesh
        ex = dd.get("extras", {})
        if "roof_rails" in ex:
            y0, y1 = ex["roof_rails"]
            rail = M.basic(self.name + "_rail", ex.get("rail_color", "#9a9ea4"), rough=0.35, metal=0.8)
            bm = bmesh.new()
            for side in (-1, 1):
                pts = []
                for i in range(9):
                    y = y0 + (y1 - y0) * i / 8
                    wb, zb, zt = self.cabin_frame(y)
                    xx = wb - dd["tumble"] * (zt - zb) - 0.1
                    pts.append((side * xx, y, zt + 0.045))
                for a, b in zip(pts[:-1], pts[1:]):
                    MU.bm_beam(a, b, 0.035, 0.03, bm=bm)
                for y in (y0 + 0.05, y1 - 0.05):
                    wb, zb, zt = self.cabin_frame(y)
                    xx = wb - dd["tumble"] * (zt - zb) - 0.1
                    MU.bm_box(0.04, 0.08, 0.05, (side * xx, y, zt + 0.02), bm=bm)
            MU.make(self.name + "_rails", bm, rail, parent=self.rig.root)
        if "wing" in ex:
            w = ex["wing"]
            mat = body_mat if not w.get("black") else M.basic(self.name + "_wing", "#151617", rough=0.3, coat=0.5)
            bm = MU.bm_box(w["width"], w["chord"], 0.035, (0.0, w["y"], w["z"]))
            for side in (-1, 1):
                MU.bm_box(0.04, w["chord"] * 0.5, w["z"] - w["base_z"], (side * w["width"] * 0.3, w["y"], (w["z"] + w["base_z"]) / 2), bm=bm)
            ob = MU.make(self.name + "_wing", bm, mat, parent=self.rig.root)
            MU.bevel(ob, 0.012, 2)
        if "roof_spoiler" in ex:
            s = ex["roof_spoiler"]
            y = dd["cabin"][0][0] + s.get("dy", 0.18)
            wb, zb, zt = self.cabin_frame(y)
            wt = wb - dd["tumble"] * (zt - zb)
            bm = MU.bm_box(2 * wt - 0.04, 0.22, 0.04, (0.0, y - 0.04, zt + 0.0))
            ob = MU.make(self.name + "_spoiler", bm, body_mat, parent=self.rig.root)
            MU.bevel(ob, 0.015, 2)
        exhaust = ex.get("exhaust", [(0.5, 0.28)])
        chrome = M.basic(self.name + "_chrome", "#d6d8db", rough=0.12, metal=1.0)
        inner = M.basic(self.name + "_pipe", "#0a0a0a", rough=0.8)
        for (xe, ze, *rest) in exhaust:
            r = rest[0] if rest else 0.04
            bm = MU.bm_cyl(r, r, 0.09, center=(xe, 0.03, ze), axis="Y", segs=16)
            MU.make(self.name + "_exh", bm, chrome, parent=self.rig.root)
            bm = MU.bm_cyl(r * 0.75, r * 0.75, 0.01, center=(xe, -0.018, ze), axis="Y", segs=16)
            MU.make(self.name + "_exhi", bm, inner, parent=self.rig.root)
        self.plate_text()

    def plate_text(self):
        """Pseudo characters on the rear plate (tiny dark blocks)."""
        dd = self.d
        pz = dd.get("plate_z")
        if pz is None:
            return
        import bmesh
        y = self.plate_surface_y()
        bm = bmesh.new()
        chars = dd.get("plate_chars", [1, 1, 0, 1, 1, 0, 1, 1, 1])
        x = -0.205
        for c in chars:
            if c:
                MU.bm_box(0.035, 0.004, 0.072, (x + 0.0175, y - 0.003, pz + 0.055), bm=bm)
                x += 0.047
            else:
                x += 0.03
        mat = M.basic(self.name + "_platetext", "#181818", rough=0.6)
        MU.make(self.name + "_platetext", bm, mat, parent=self.rig.root)

    def plate_surface_y(self):
        dd = self.d
        on_bumper = dd.get("plate_on_bumper", False)
        if on_bumper:
            return 0.0
        return BUMPER_OUT

    # --- shader decals --------------------------------------------------------------------------

    def body_decals(self):
        dd = self.d
        dec = []
        for s in dd.get("seams", []):
            dec.append(dict(face="side", poly=[(s - 0.004, dd["clearance"] + 0.05), (s + 0.004, dd["clearance"] + 0.05),
                                               (s + 0.004, 2.5), (s - 0.004, 2.5)], mat="seal", n=0.6))
        for (yh, zh) in dd.get("handles", []):
            dec.append(dict(face="side", poly=MU.rounded_rect(0.13, 0.025, 0.012, 2, yh, zh), mat="dark", n=0.6))
        dec += self.lamp_decals(dd.get("tail_lamps", []), "tail")
        dec += self.lamp_decals(dd.get("head_lamps", []), "head")
        dec += dd.get("body_decals", [])
        pz = dd.get("plate_z")
        if pz is not None and not dd.get("plate_on_bumper", False):
            dec += self.plate_decals(pz)
        if pz is not None and dd.get("front_plate_z") is not None:
            fz = dd["front_plate_z"]
            dec.append(dict(face="front", poly=[(0.0, fz), (0.26, fz), (0.26, fz + 0.11), (0.0, fz + 0.11)], mat="plate"))
        dec += self.livery.get("decals", [])
        return dec

    def bumper_decals(self):
        dd = self.d
        dec = []
        pz = dd.get("plate_z")
        if pz is not None and dd.get("plate_on_bumper", False):
            dec += self.plate_decals(pz)
        dec += dd.get("bumper_decals", [])
        fz = dd.get("front_plate_z")
        if fz is not None:
            dec.append(dict(face="front", poly=[(0.0, fz), (0.26, fz), (0.26, fz + 0.11), (0.0, fz + 0.11)], mat="plate"))
        return dec

    def cabin_decals(self):
        dd = self.d
        dec = []
        dec += self.lamp_decals(dd.get("cabin_lamps", []), "tail")
        ch = dd.get("chmsl")
        if ch:
            z0, z1, hw = ch
            dec.append(dict(face="rear", poly=[(0.0, z0), (hw, z0), (hw, z1), (0.0, z1)], mat="lamp_red_dark",
                            emit={"brake": (BRAKE_RED, 6.0)}, n=0.2))
        dec += dd.get("cabin_decals", [])
        return dec

    def plate_decals(self, pz):
        emit = {"tail": ("#fff4dc", 0.12)}
        return [
            dict(face="rear", poly=[(0.0, pz), (0.26, pz), (0.26, pz + 0.11), (0.0, pz + 0.11)], mat="plate", emit=emit),
            dict(face="rear", sym=False, poly=[(-0.26, pz), (-0.225, pz), (-0.225, pz + 0.11), (-0.26, pz + 0.11)],
                 mat="plate_blue"),
        ]

    def lamp_decals(self, lamps, kind):
        """Lamp list entries: dict(face, poly, part) where part in tail|brake_only|indicator|reverse|head|drl."""
        out = []
        for lp in lamps:
            part = lp.get("part", "tail")
            d = dict(face=lp.get("face", "rear" if kind == "tail" else "front"), poly=lp["poly"], n=lp.get("n", 0.3))
            if "only" in lp:
                d["only"] = lp["only"]
            if lp.get("outline", part in ("tail", "tail_only", "brake_only", "head")):
                o = dict(d)
                o["mat"] = "gloss_black"
                out.append(o)
                d["inset"] = lp.get("outline_w", 0.012)
            if part == "tail":
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
        return out

    # --- windows --------------------------------------------------------------------------------

    def windows(self):
        dd = self.d
        win = dd.get("win", {})
        cab = dd["cabin"]
        belt = max(self.lower_frame(y)[2] for y in (cab[0][0] + 0.3, cab[-1][0] - 0.3))
        bot = belt + win.get("belt_margin", 0.02)
        # half-planes (a, b, c): a*y + b*z + c >= 0 inside
        hp = [(0.0, 1.0, -bot)]
        for (p, q) in zip(cab[:-1], cab[1:]):
            # top edge of the silhouette, traversed front->rear for a CCW polygon
            ex, ez = p[0] - q[0], p[1] - q[1]
            ln = math.hypot(ex, ez)
            a, b = -ez / ln, ex / ln
            steep = abs(q[1] - p[1]) / max(1e-6, abs(q[0] - p[0])) > 0.45
            if steep:
                m = win.get("a_pillar", 0.075) if q[0] > (cab[0][0] + cab[-1][0]) / 2 else win.get("c_pillar", 0.12)
            else:
                m = win.get("roof_margin", 0.055)
            c = -(a * q[0] + b * q[1]) - m
            hp.append((a, b, c))
        for (p, q) in win.get("clip", []):
            ex, ez = q[0] - p[0], q[1] - p[1]
            ln = math.hypot(ex, ez)
            a, b = -ez / ln, ex / ln
            hp.append((a, b, -(a * p[0] + b * p[1])))
        ybox = (cab[0][0] - 1, cab[-1][0] + 1)
        poly = [(ybox[0], bot - 1), (ybox[1], bot - 1), (ybox[1], 4.0), (ybox[0], 4.0)]
        for h in hp:
            poly = clip_poly(poly, h)
        sides = []
        frames = []
        if len(poly) >= 3:
            frames.append(poly)
            pieces = [poly]
            for (yp, wp) in win.get("pillars", []):
                nxt = []
                for pc in pieces:
                    left = clip_poly(pc, (-1.0, 0.0, yp - wp / 2))
                    right = clip_poly(pc, (1.0, 0.0, -(yp + wp / 2)))
                    nxt += [g for g in (left, right) if len(g) >= 3]
                pieces = nxt
            sides = pieces
        zr = max(p[1] for p in cab)
        # roof span: points within 0.06 of the max height
        flat = [p for p in cab if p[1] > zr - win.get("roof_band", 0.07)]
        y_r0, y_r1 = flat[0][0], flat[-1][0]
        res = {"frame": win.get("frame", 0.016), "side": sides, "side_frames": frames}
        wsb = self.cabin_frame(cab[-1][0] - 0.05)
        res["front"] = dict(y=(y_r1, cab[-1][0]), z=(interp(cab, cab[-1][0]) + win.get("ws_bottom", 0.03),
                                                    zr - win.get("ws_top", 0.05)),
                            wb=wsb[0], zb=wsb[1], tumble=dd["tumble"], pillar=win.get("ws_pillar", 0.075))
        rwb = self.cabin_frame(cab[0][0] + 0.05)
        rz0 = win.get("rw_z0", interp(cab, cab[0][0]) + win.get("rw_bottom", 0.035))
        res["rear"] = dict(y=(cab[0][0], y_r0), z=(rz0, zr - win.get("rw_top", 0.05)),
                           wb=rwb[0], zb=rwb[1], tumble=dd["tumble"], pillar=win.get("rw_pillar", 0.1))
        if win.get("no_rear_window"):
            res.pop("rear")
        return res


def _smooth_body(ob):
    """Softer traffic bodies (contract v2): sharp edges only at real creases, one subdivision level."""
    me = ob.data
    me.set_sharp_from_angle(angle=math.radians(70))
    m = ob.modifiers.new("subd", "SUBSURF")
    m.levels = 1
    m.render_levels = 1
    m.boundary_smooth = "PRESERVE_CORNERS"


def clip_poly(poly, h):
    """Sutherland-Hodgman clip of a polygon [(y,z)] by half-plane a*y+b*z+c >= 0."""
    a, b, c = h
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        fp = a * p[0] + b * p[1] + c
        fq = a * q[0] + b * q[1] + c
        if fp >= 0:
            out.append(p)
        if (fp >= 0) != (fq >= 0):
            t = fp / (fp - fq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out
