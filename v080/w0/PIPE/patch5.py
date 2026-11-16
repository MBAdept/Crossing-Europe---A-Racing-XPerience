"""Hook patch 5: player cars (carbody, cardetail, player_cars) - detail levels, node / lamp tags, 3D lamp parts."""
from patchlib import patch

patch("tools/blender/cesprites/carbody.py", [
    ('''TAIL_RED = "#ff1a0e"
BRAKE_RED = "#ff2414"


def _prof(v):''', '''TAIL_RED = "#ff1a0e"
BRAKE_RED = "#ff2414"

# 3D pipeline hook (ce3d/lod.py): level of detail of a build. These defaults give the sprite model.
#   ring     scale of the points per cross-section segment (N_* above)
#   step     scale of the station spacing along the car (lofts)
#   res      scale of the grid of the conformal patches
#   off      scale of the height of the patches over the body, min_off = smallest height (m)
#   wheel    scale of the segment counts of lathed parts (wheels, liners, exhaust tips)
#   extras   lamp parts only the real-time models have (indicators, reverse light)
DETAIL = dict(ring=1.0, step=1.0, res=1.0, off=1.0, min_off=0.0, wheel=1.0, extras=False)


def _prof(v):'''),
    ('''    def __init__(self, rig, d, paint="#888888", metal=0.4, name="car", rough=0.3):
        self.rig = rig
        self.d = d
''', '''    def __init__(self, rig, d, paint="#888888", metal=0.4, name="car", rough=0.3, detail=None):
        self.rig = rig
        self.d = d
        self.detail = dict(DETAIL)
        self.detail.update(detail or {})
        self.N = {k: self.n_ring(v) for k, v in (
            ("under", N_UNDER), ("rb", N_RB), ("ls", N_LS), ("us", N_US), ("re", N_RE), ("deck", N_DECK),
            ("gb", N_GB), ("gs", N_GS), ("gr", N_GR), ("roof", N_ROOF))}
        self.glass_outlines = []        # (projection, symmetric, outline) of every pane (ce3d/vehicles3d.py)
'''),
    ('''    # ------------------------------------------------------------------ profiles / sections

    def arch_z(self, y):''', '''    # ------------------------------------------------------------------ detail level (3D pipeline hook)

    def n_ring(self, n):
        """Point count of a cross-section segment at the detail level (ring 1.0 = unchanged)."""
        k = self.detail["ring"]
        return n if k == 1.0 else max(2, int(round(n * k)))

    def n_wheel(self, n):
        """Segment count of a lathed part at the detail level (wheel 1.0 = unchanged)."""
        k = self.detail["wheel"]
        return n if k == 1.0 else max(8, int(round(n * k)))

    # ------------------------------------------------------------------ profiles / sections

    def arch_z(self, y):'''),
    ('''        for i in range(N_UNDER):
            pts.append((xu * i / N_UNDER, z0))
        # bottom rounding
        pts += C.arc(xu, z0 + f.r_b, f.r_b, -90, 0, N_RB, rx=x_low - xu)
        # lower side up to the shoulder
        zs = [z0 + f.r_b + (f.z_sh - z0 - f.r_b) * t for t in C.spacing(N_LS, "cos")[1:]]''',
     '''        N = self.N
        for i in range(N["under"]):
            pts.append((xu * i / N["under"], z0))
        # bottom rounding
        pts += C.arc(xu, z0 + f.r_b, f.r_b, -90, 0, N["rb"], rx=x_low - xu)
        # lower side up to the shoulder
        zs = [z0 + f.r_b + (f.z_sh - z0 - f.r_b) * t for t in C.spacing(N["ls"], "cos")[1:]]'''),
    ('''        for t in C.spacing(N_US, "lin")[1:]:''', '''        for t in C.spacing(N["us"], "lin")[1:]:'''),
    ('''                        N_RE, include_start=False)
        # deck
        for t in C.spacing(N_DECK, "lin")[1:]:''', '''                        N["re"], include_start=False)
        # deck
        for t in C.spacing(N["deck"], "lin")[1:]:'''),
    ('''        for i in range(N_GB):
            pts.append((xb * i / N_GB, zb))
        for t in C.spacing(N_GS, "lin"):''', '''        N = self.N
        for i in range(N["gb"]):
            pts.append((xb * i / N["gb"], zb))
        for t in C.spacing(N["gs"], "lin"):'''),
    ('''                        N_GR, include_start=False)
        for t in C.spacing(N_ROOF, "lin")[1:]:''', '''                        N["gr"], include_start=False)
        for t in C.spacing(N["roof"], "lin")[1:]:'''),
    # stations of the lower body
    ('''        dense = [(ya - self.Ra - 0.15, ya + self.Ra + 0.15, 0.012) for ya in (self.y_ra, self.y_fa)]
        rp = d.get("r_plan", (0.3, 0.4))
        rt = d.get("r_top", (0.1, 0.12))
        ys = C.stations(self.lb0, self.lb1, d.get("step", 0.022),
                        ends=((max(rp[0], rt[0]) + 0.02, 14), (max(rp[1], rt[1]) + 0.02, 14)),''',
     '''        ks = self.detail["step"]                    # 1.0 for the sprite model
        dense = [(ya - self.Ra - 0.15, ya + self.Ra + 0.15, 0.012 * ks) for ya in (self.y_ra, self.y_fa)]
        rp = d.get("r_plan", (0.3, 0.4))
        rt = d.get("r_top", (0.1, 0.12))
        ne = self.n_ring(14)
        ys = C.stations(self.lb0, self.lb1, d.get("step", 0.022) * ks,
                        ends=((max(rp[0], rt[0]) + 0.02, ne), (max(rp[1], rt[1]) + 0.02, ne)),'''),
    ('''            sl = abs(roof.deriv(y))
            y += max(0.004, d.get("g_step", 0.02) / (1.0 + 1.5 * sl))''',
     '''            sl = abs(roof.deriv(y))
            y += max(0.004 * self.detail["step"], d.get("g_step", 0.02) * self.detail["step"] / (1.0 + 1.5 * sl))'''),
    # bumper sections
    ('''            xbot = self.side_x(f, zb + rb) + o - pin
            xu = max(0.02, xbot - rb)
            for i in range(4):
                pts.append((xu * i / 4, zb))
            pts += C.arc(xu, zb + rb, rb, -90, 0, 5, rx=xbot - xu)
            n = 10
            for t in C.spacing(n, "lin")[1:]:
                z = zb + rb + (zt - rt - zb - rb) * t
                pts.append((self.side_x(f, z) + o - pin, z))
            xt = pts[-1][0]
            pts += C.arc(xt - rt, zt - rt, rt, 0, 90, 5, include_start=False)
            xin = xt - rt
            for t in C.spacing(6, "lin")[1:]:''',
     '''            xbot = self.side_x(f, zb + rb) + o - pin
            xu = max(0.02, xbot - rb)
            n4, n5, n6 = self.n_ring(4), self.n_ring(5), self.n_ring(6)
            for i in range(n4):
                pts.append((xu * i / n4, zb))
            pts += C.arc(xu, zb + rb, rb, -90, 0, n5, rx=xbot - xu)
            n = self.n_ring(10)
            for t in C.spacing(n, "lin")[1:]:
                z = zb + rb + (zt - rt - zb - rb) * t
                pts.append((self.side_x(f, z) + o - pin, z))
            xt = pts[-1][0]
            pts += C.arc(xt - rt, zt - rt, rt, 0, 90, n5, include_start=False)
            xin = xt - rt
            for t in C.spacing(n6, "lin")[1:]:'''),
    ('''            if which == "rear":
                y0, y1 = 0.0, self.y_ra - self.Ra - 0.004
                ends = ((b.get("r_plan", 0.3) + 0.05, 14), (0.0, 0))
            else:
                y0, y1 = self.y_fa + self.Ra + 0.004, self.L
                ends = ((0.0, 0), (b.get("r_plan", 0.4) + 0.05, 14))
            ys = C.stations(y0, y1, 0.02, ends=ends)''',
     '''            if which == "rear":
                y0, y1 = 0.0, self.y_ra - self.Ra - 0.004
                ends = ((b.get("r_plan", 0.3) + 0.05, self.n_ring(14)), (0.0, 0))
            else:
                y0, y1 = self.y_fa + self.Ra + 0.004, self.L
                ends = ((0.0, 0), (b.get("r_plan", 0.4) + 0.05, self.n_ring(14)))
            ys = C.stations(y0, y1, 0.02 * self.detail["step"], ends=ends)'''),
    ('''            segs = 36
''', '''            segs = self.n_wheel(36)
'''),
    # patches
    ('''        outline = C.ccw(outline)
        variants = [(outline, side)]
        if sym:
            if proj in ("rear", "front", "top"):''', '''        dt = self.detail
        if dt["res"] != 1.0 or dt["off"] != 1.0 or dt["min_off"] > 0.0:
            # 3D levels of detail: coarser grids, and patches high enough over the coarser body
            res = res * dt["res"]
            if walls > 0.0:
                walls = max(walls * dt["off"], dt["min_off"])
            offset = max(offset * dt["off"], dt["min_off"])
        outline = C.ccw(outline)
        variants = [(outline, side)]
        if sym:
            if proj in ("rear", "front", "top"):'''),
])

patch("tools/blender/cesprites/cardetail.py", [
    ('''def wheel_mesh(name, R, r_rim, tw, st, mats):
    """One wheel (tyre, rim, spokes, disc, caliper) in local space: axis X, outer face towards +X,
    centre at the origin. mats: dict tyre, rim, rim_dark, disc, caliper. Returns a list of objects."""
    objs = []
    # tyre
    bm = bmesh.new()
    _lathe_x(bm, _tyre_profile(R, r_rim, tw), 64)''', '''def wheel_mesh(name, R, r_rim, tw, st, mats, sg=None):
    """One wheel (tyre, rim, spokes, disc, caliper) in local space: axis X, outer face towards +X,
    centre at the origin. mats: dict tyre, rim, rim_dark, disc, caliper. Returns a list of objects.
    sg: segment count at the detail level of a 3D build (None = as designed, the sprite model)."""
    if sg is None:
        def sg(n):
            return n
    objs = []
    # tyre
    bm = bmesh.new()
    _lathe_x(bm, _tyre_profile(R, r_rim, tw), sg(64))'''),
    ('''    _lathe_x(bm, barrel, 48, mat_index=1)''', '''    _lathe_x(bm, barrel, sg(48), mat_index=1)'''),
    ('''    _lathe_x(bm, lip, 64, mat_index=0)''', '''    _lathe_x(bm, lip, sg(64), mat_index=0)'''),
    ('''    _lathe_x(bm, hub, 32, mat_index=0)''', '''    _lathe_x(bm, hub, sg(32), mat_index=0)'''),
    ('''    _lathe_x(bm, disc, 40, mat_index=0)''', '''    _lathe_x(bm, disc, sg(40), mat_index=0)'''),
    ('''    meshes = {}
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
    return out''', '''    # 3D models: the calipers do not spin - their faces belong to the node "body" (ce3d/roles.py)
    mats["caliper"]["ce_node"] = "body"
    meshes = {}
    for key, tw in (("f", d["tw"]), ("r", d.get("tw_r", d["tw"]))):
        meshes[key] = wheel_mesh(car.name + "_wheel_" + key, R, r_rim, tw, st, mats,
                                 sg=None if car.detail["wheel"] == 1.0 else car.n_wheel)
    inset = d.get("wheel_inset", 0.02)
    out = []
    for key, ya in (("r", car.y_ra), ("f", car.y_fa)):
        tw = d["tw"] if key == "f" else d.get("tw_r", d["tw"])
        f = car.frame(ya)
        x_out = car.W2 - inset
        for side in (1, -1):
            xc = side * (x_out - tw / 2)
            # 3D models: every wheel is its own node, pivot = the object origin (the wheel centre)
            with MU.node("wheel_%d%s" % (0 if key == "f" else 1, "r" if side > 0 else "l")):
                for me in meshes[key]:
                    ob = bpy.data.objects.new(me.name, me)
                    ob.location = (xc, ya, R)
                    ob.scale = (side, 1.0, 1.0)
                    if key == "f" and st.get("steer"):
                        ob.rotation_euler = (0.0, 0.0, math.radians(st["steer"]))
                    MU._link(ob, car.center)
                    out.append(ob)
    return out'''),
    # glass outlines for the 3D pipeline
    ('''    car.patch(poly, "side", seal, offset=0.0012, res=0.012, name="dlo_seal", target=target)
    inner = C.ccw(_inset_poly(poly, seal_w))
    car.patch(inner, "side", gm, offset=0.0022, res=0.012, name="dlo_glass", target=target)''',
     '''    car.patch(poly, "side", seal, offset=0.0012, res=0.012, name="dlo_seal", target=target)
    inner = C.ccw(_inset_poly(poly, seal_w))
    car.patch(inner, "side", gm, offset=0.0022, res=0.012, name="dlo_glass", target=target)
    car.glass_outlines.append(("side", True, inner))'''),
    ('''    car.patch(poly, "top", seal, offset=0.0012, res=0.014, sym=False, name="ws_seal", target=target)
    car.patch(C.ccw(_inset_poly(C.ccw(poly), seal_w)), "top", gm, offset=0.0022, res=0.014, sym=False,
              name="ws_glass", target=target)''',
     '''    car.patch(poly, "top", seal, offset=0.0012, res=0.014, sym=False, name="ws_seal", target=target)
    car.patch(C.ccw(_inset_poly(C.ccw(poly), seal_w)), "top", gm, offset=0.0022, res=0.014, sym=False,
              name="ws_glass", target=target)
    car.glass_outlines.append(("top", False, C.ccw(_inset_poly(C.ccw(poly), seal_w))))'''),
    ('''    car.patch(poly, proj, seal, offset=0.0012, res=0.012, sym=False, name="rw_seal", target=target)
    car.patch(C.ccw(_inset_poly(poly, seal_w)), proj, gm, offset=0.0022, res=0.012, sym=False, name="rw_glass",
              target=target)''',
     '''    car.patch(poly, proj, seal, offset=0.0012, res=0.012, sym=False, name="rw_seal", target=target)
    car.patch(C.ccw(_inset_poly(poly, seal_w)), proj, gm, offset=0.0022, res=0.012, sym=False, name="rw_glass",
              target=target)
    car.glass_outlines.append((proj, False, C.ccw(_inset_poly(poly, seal_w))))'''),
    # lamp channels of lamp parts (3D models)
    ('''_OFF = {"chrome": 0.0035, "dark": 0.003, "tail": 0.0045, "brake": 0.005, "guide": 0.0075, "reverse": 0.004,
        "indicator": 0.004, "reflector": 0.004, "white": 0.004}
''', '''_OFF = {"chrome": 0.0035, "dark": 0.003, "tail": 0.0045, "brake": 0.005, "guide": 0.0075, "reverse": 0.004,
        "indicator": 0.004, "reflector": 0.004, "white": 0.004}
# 3D models: lamp channel of a part whose sprite material has no light layer (ce3d/roles.py). Key: part kind,
# or (lamp tag, part kind) - the dark projector lenses of a headlight are its low beam. A part may name its
# channel itself with the key "lamp".
_LAMP3D = {"reverse": "reverse", "indicator": "ind", "white": "drl", ("head", "dark"): "head"}
'''),
    ('''        if "path" in part:
            pts = C.smooth_open(part["path"], 6) if part.get("smooth", True) and len(part["path"]) > 2 else part["path"]
            car.stripe(pts, part["width"], proj, mat, offset=off, res=min(res, part["width"] * 0.6), sym=sym,
                       name=nm, target=tgt, walls=part.get("walls", 0.0), wall_mat=mat if part.get("walls") else None)
        else:
            car.patch(part["outline"], proj, mat, offset=off, res=part.get("res", res), sym=sym, name=nm, target=tgt,
                      walls=part.get("walls", 0.0), wall_mat=mat if part.get("walls") else None)''',
     '''        if "path" in part:
            pts = C.smooth_open(part["path"], 6) if part.get("smooth", True) and len(part["path"]) > 2 else part["path"]
            pob = car.stripe(pts, part["width"], proj, mat, offset=off, res=min(res, part["width"] * 0.6), sym=sym,
                             name=nm, target=tgt, walls=part.get("walls", 0.0),
                             wall_mat=mat if part.get("walls") else None)
        else:
            pob = car.patch(part["outline"], proj, mat, offset=off, res=part.get("res", res), sym=sym, name=nm,
                            target=tgt, walls=part.get("walls", 0.0), wall_mat=mat if part.get("walls") else None)
        MU.tag(pob, lamp=part.get("lamp", _LAMP3D.get((tag, kind), _LAMP3D.get(kind))))'''),
    ('''    MU.make(car.name + "_plate", bm, pm, parent=car.center)
    bmat = car.mat("plate_band", band, rough=0.45)''',
     '''    pob = MU.make(car.name + "_plate", bm, pm, parent=car.center)
    MU.tag(pob, lamp="plate:0.6" if proj == "rear" else "none")     # 3D models: only the rear plate is lit
    bmat = car.mat("plate_band", band, rough=0.45)'''),
    ('''            _lathe_y(bm, prof, 40, (xx, z))''', '''            _lathe_y(bm, prof, car.n_wheel(40), (xx, z))'''),
    ('''            _lathe_y(bm, [(r * 0.87, y_tip + 0.012), (r * 0.87, y_tip + 0.08), (0.0, y_tip + 0.08)], 32, (xx, z))''',
     '''            _lathe_y(bm, [(r * 0.87, y_tip + 0.012), (r * 0.87, y_tip + 0.08), (0.0, y_tip + 0.08)], car.n_wheel(32),
                     (xx, z))'''),
    ('''            bm = MU.bm_box(sx * 0.42, 0.012, 0.016, (xc + side * sx * 0.22, y + sy * 0.38, z - sz * 0.22))
            MU.make(car.name + "_mirror_ind", bm, im, parent=car.center)''',
     '''            bm = MU.bm_box(sx * 0.42, 0.012, 0.016, (xc + side * sx * 0.22, y + sy * 0.38, z - sz * 0.22))
            MU.tag(MU.make(car.name + "_mirror_ind", bm, im, parent=car.center), lamp="ind")'''),
])

patch("tools/blender/cesprites/player_cars.py", [
    ('''def build(rig, p):
    d = DESIGNS[p["design"]]
    car = CB.SmoothCar(rig, d, paint=p["paint"], metal=p.get("metal", 0.3), name=p["design"])''',
     '''def build(rig, p):
    d = DESIGNS[p["design"]]
    car = CB.SmoothCar(rig, d, paint=p["paint"], metal=p.get("metal", 0.3), name=p["design"],
                       detail=p.get("detail"))        # detail: level of detail of a 3D build (ce3d/lod.py)'''),
    # limousine: lamp parts only the real-time model has
    ('''            dict(kind="guide", path=[(0.53, 0.958), (0.72, 0.962), (0.88, 0.966), (0.905, 0.94), (0.90, 0.875)],
                 width=0.011),
            dict(kind="guide", path=[(0.56, 0.902), (0.82, 0.866)], width=0.008),
        ]), tag="tail")''',
     '''            dict(kind="guide", path=[(0.53, 0.958), (0.72, 0.962), (0.88, 0.966), (0.905, 0.94), (0.90, 0.875)],
                 width=0.011),
            dict(kind="guide", path=[(0.56, 0.902), (0.82, 0.866)], width=0.008),
        ] + ([
            # real-time model only: indicator strip at the outer end, reverse light at the inner end
            dict(kind="indicator", path=[(0.884, 0.952), (0.888, 0.884)], width=0.013, smooth=False, offset=0.0062),
            dict(kind="reverse", outline=C.rounded_rect(0.585, 0.935, 0.07, 0.026, 0.009, 3), offset=0.0062),
        ] if car.detail["extras"] else [])), tag="tail")'''),
    ('''        dict(kind="white", path=[(0.49, 0.737), (0.82, 0.724), (0.88, 0.70)], width=0.01),
    ])
    car.patch([(-0.38, 0.52), (0.38, 0.52), (0.40, 0.71), (-0.40, 0.71)], "front", grille_mat(car, "slats", "#0a0a0b",''',
     '''        dict(kind="white", path=[(0.49, 0.737), (0.82, 0.724), (0.88, 0.70)], width=0.01),
    ] + ([
        # real-time model only: indicator at the outer end of the headlight
        dict(kind="indicator", path=[(0.835, 0.703), (0.878, 0.694)], width=0.013, smooth=False, offset=0.0052),
    ] if car.detail["extras"] else []))
    car.patch([(-0.38, 0.52), (0.38, 0.52), (0.40, 0.71), (-0.40, 0.71)], "front", grille_mat(car, "slats", "#0a0a0b",'''),
])
