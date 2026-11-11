"""Traffic cars as real-time models: the designs of cesprites.designs (dimensions, side profiles, windows,
lamps, plates, seams) on the smooth lofts of cesprites.carbody.SmoothCar.

The sprite generator cesprites.vehicles.Car lofts a ten-point control polygon - fine for a 256 px sprite, but as
a mesh its coarse levels crumple and its bumpers are second lofts that poke through the body (saw teeth at the
corners). The real-time build therefore takes from the design what makes the car - length, width, wheelbase, the
top line of the lower body, the silhouette of the greenhouse, tumblehome, bumper heights, wheels - and gives it
to SmoothCar (smooth_design): analytic cross-sections with a shoulder crease, flared wheel arches, bumpers with a
ledge that run flush into the arches, and levels of detail that are the same surface at another density.
What is drawn on the car stays the design's: windows, lamps, plates, seams and handles are the decal lists of
vehicles.Car (an unbuilt Car answers windows() / body_decals() ...), cut INTO the lofts by ce3d.decalgeo - one
layer at every level, ending along the same lines (the coarse levels take their normals from lod0).

  lod0    body (vpbr + glass) + 4 wheel nodes (cardetail wheels: tyre, spoked rim, brake disc; calipers in the body)
  lod1    one mesh: coarser lofts, drum wheels with a rim disc, plain mirrors
  lod2    one mesh: the body runs to the full length (no bumper lofts), 16-point sections
  shadow  the lofts of lod2 without decals
  colour variants = paint of the sets (instance uniform), one mesh for all
Model space: origin on the ground under the centre of the collision box, nose at -Z.
"""
import copy
import math
import time

import bmesh
import numpy as np

from . import core, decalgeo, roles
from . import lod as LOD
from .export import Lod, ModelData, Part, sprite_extent

# Lamp parts of the 3D builds, applied to a copy of the design (same decal conventions as cesprites.designs):
#   add      parts the sprites never needed (they show the cars from behind, lights as layers)
#   replace  {list: {part: entry}} - a part of the design that gets another outline in 3D
# Indicators are what the following driver reacts to (Rule 9): they lie INSIDE the face that looks at him - the
# flat part of the rear / front end, not the corner the lamp wraps around - and they are the last material group
# of the list, i.e. on top of the tail lamp in the stacking order. Seen from straight behind / ahead each one
# shows at least validate_models.LAMP_MIN_CM2 at every level of detail.
CAR_3D = {
    "sedan": dict(
        add=dict(
            tail_lamps=[
                # lower band of the lamp, outside the reverse light
                dict(part="indicator", poly=[(0.612, 0.808), (0.85, 0.801), (0.85, 0.846), (0.612, 0.846)],
                     outline=False),
            ],
            head_lamps=[
                # outer end of the headlight, inside its black outline
                dict(face="front", part="indicator", poly=[(0.70, 0.667), (0.868, 0.653), (0.868, 0.718), (0.708, 0.718)],
                     outline=False),
                dict(face="front", part="drl", poly=[(0.525, 0.653), (0.78, 0.645), (0.78, 0.663), (0.525, 0.671)],
                     outline=False),
            ],
        ),
        replace=dict(
            tail_lamps={
                # the design's reverse light starts in the corner of the lamp, on its black outline: 3D moves
                # it inside the lens
                "reverse": dict(part="reverse", poly=[(0.487, 0.812), (0.60, 0.809), (0.60, 0.846), (0.494, 0.846)],
                                outline=False),
            },
        ),
    ),
    "hatch": dict(
        add=dict(
            tail_lamps=[
                dict(part="indicator", poly=[(0.635, 0.752), (0.84, 0.74), (0.84, 0.79), (0.635, 0.795)], outline=False),
            ],
            head_lamps=[
                dict(face="front", part="indicator", poly=[(0.68, 0.627), (0.848, 0.613), (0.848, 0.688), (0.688, 0.688)],
                     outline=False),
                dict(face="front", part="drl", poly=[(0.505, 0.613), (0.76, 0.605), (0.76, 0.623), (0.505, 0.631)],
                     outline=False),
            ],
        ),
        replace=dict(
            tail_lamps={
                "reverse": dict(part="reverse", poly=[(0.517, 0.757), (0.62, 0.752), (0.62, 0.80), (0.524, 0.80)],
                                outline=False),
            },
        ),
    ),
    "wagon": dict(
        add=dict(
            tail_lamps=[
                # the reverse light first: its material is that of the headlights, and the indicators must be the
                # last material group (on top of everything)
                dict(part="reverse", poly=[(0.54, 0.777), (0.588, 0.774), (0.588, 0.812), (0.548, 0.812)], outline=False),
                dict(part="indicator", poly=[(0.60, 0.772), (0.84, 0.76), (0.84, 0.805), (0.60, 0.812)], outline=False),
            ],
            head_lamps=[
                dict(face="front", part="indicator", poly=[(0.71, 0.647), (0.878, 0.633), (0.878, 0.698), (0.718, 0.698)],
                     outline=False),
                dict(face="front", part="drl", poly=[(0.525, 0.633), (0.78, 0.625), (0.78, 0.643), (0.525, 0.651)],
                     outline=False),
            ],
        ),
    ),
}
PLATE_CHARS = [1, 1, 0, 1, 1, 0, 1, 1, 1]

# Look of the real-time traffic cars where the sprite's look comes from Cycles, not from the design values
# (art review of AS1, findings B3 - B5):
#   rims   the sprite's silver rims (metal 1.0) mirror the dark wheel arch and road and read as anthracite; in
#          real time they had nothing to mirror and came out bright white-silver ("toy-like") - the 3D rim takes
#          the colour the sprite shows, at every level (lod1/lod2 used the bright colour as well)
#   plate  levels 1 and 2 drop the characters: the plate of those levels has the mean colour of the lod0 plate
#          with its characters and blue band (a white plate jumped brighter at 40 m and vanished at 120 m)
#   glass  lighter, glossier and a little metallic: the dark navy panes had no visible reflection and looked
#          painted (lod1/lod2 draw them as vpbr with the same values)
#   chmsl  the third brake light with a darker lit colour: unlit, a lamp shows half its lit colour, and the
#          bright red bar on the rear window looked switched on by day (lit, brake gain 2.2 still saturates it)
TRAFFIC_RIM = dict(color="#5a5d62", metal=0.6, rough=0.35)
FAR_PLATE = "#c4c4c1"
TRAFFIC_GLASS = dict(color="#2a343e", rough=0.02, metal=0.25)
CHMSL_LAMP = "brake:1:#b8160c"
EXHAUST = dict(color="#3c3d40", rough=0.4, metal=0.6, length=0.3)
MIRROR_GLASS = dict(color="#2c3238", rough=0.03, metal=0.9)


def traffic_design(name):
    """The design of cesprites.designs with the lamp parts of the 3D builds (CAR_3D) and the characters of the
    rear plate as decals (the sprite model sets small blocks in front of the plate)."""
    from cesprites import designs
    d = copy.deepcopy(designs.TRAFFIC_MODELS[name])
    d["chmsl_lamp"] = CHMSL_LAMP
    spec = CAR_3D.get(name, {})
    for k, parts in spec.get("replace", {}).items():
        lst = list(d.get(k, []))
        for part, entry in parts.items():
            hits = [i for i, e in enumerate(lst) if e.get("part", "tail") == part]
            if len(hits) != 1:
                raise KeyError("CAR_3D[%s].replace: %d parts '%s' in %s" % (name, len(hits), part, k))
            lst[hits[0]] = copy.deepcopy(entry)
        d[k] = lst
    for k, extra in spec.get("add", {}).items():
        d[k] = list(d.get(k, [])) + copy.deepcopy(extra)
    pz = d.get("plate_z")
    if pz is not None:
        key = "bumper_decals" if d.get("plate_on_bumper", False) else "body_decals"
        chars = []
        x = -0.205
        for c in d.get("plate_chars", PLATE_CHARS):
            if c:
                chars.append(dict(face="rear", sym=False, mat="plate_text", small=True,
                                  poly=[(x, pz + 0.019), (x + 0.035, pz + 0.019), (x + 0.035, pz + 0.091), (x, pz + 0.091)]))
                x += 0.047
            else:
                x += 0.03
        d[key + "_3d"] = chars
    return d


def smooth_design(car, full_length=False):
    """SmoothCar design of a traffic design (car: an unbuilt cesprites.vehicles.Car). full_length: the body runs
    from bumper to bumper (far levels without bumper lofts)."""
    from cesprites import vehicles as VEH
    d = car.d
    L, W2, R = car.L, car.W2, car.R
    cl = d["clearance"]
    bz1 = d["bumper"]["z"][1]
    fz1 = d.get("front_bumper_z", (0.0, bz1 - 0.02))[1]
    lower, cab = d["lower"], d["cabin"]
    flare = 0.006
    out_r, out_f = (0.0, 0.0) if full_length else (VEH.BUMPER_OUT, 0.02)
    y_ra, y_fa = car.y_ra, car.y_fa
    ym = 0.5 * (y_ra + y_fa)
    g0, g1 = cab[0][0], cab[-1][0]

    def low(y):
        return VEH.interp(lower, y)
    plan_r = d.get("plan_r", (0.20, 0.38))
    r_end = d.get("r_end", (0.09, 0.12))
    return dict(
        L=L, W=d["W"], wb=d["wb"], r_oh=y_ra, R=R, arch_gap=0.045, tw=d["tire_w"],
        **({"tw_r": d["tire_w_rear"]} if "tire_w_rear" in d else {}),
        arch_flare=(flare, 0.07),
        bump_rear=dict(out=out_r, z_top=bz1, z_bot=[(0.0, cl + 0.07), (0.3, cl + 0.02), (0.7, cl - 0.01)],
                       r_plan=plan_r[0] + 0.06, p_plan=2.4, r_end_bot=0.04),
        bump_front=dict(out=out_f, z_top=fz1, z_bot=[(L - 0.6, cl - 0.01), (L, cl + 0.03)], r_plan=plan_r[1] + 0.08,
                        r_end_bot=0.06),
        plan=[(0.0, W2 - 0.035), (y_ra, W2 - flare), (ym, W2 - flare - 0.004), (y_fa, W2 - flare), (L, W2 - 0.03)],
        r_plan=(plan_r[0], plan_r[1]), p_plan=(2.4, 2.0),
        deck=[(y, z + 0.025) for (y, z) in lower], crown=0.025, r_top=(r_end[0], r_end[1]), r_bot=(0.05, 0.08),
        under=[(0.0, cl + 0.07), (0.3, cl + 0.02), (0.8, cl), (L - 0.9, cl), (L - 0.35, cl + 0.02), (L, cl + 0.06)],
        shoulder=[(0.0, low(0.3) - 0.15), (ym, low(ym) - 0.14), (L, low(L - 0.45) - 0.14)],
        tuck=0.045, tumble_up=0.03, r_edge=0.06, r_bottom=0.045,
        g_range=(g0, g1), roof=[(y, z + 0.03) for (y, z) in cab],
        g_inset=0.005, tumble=d.get("tumble", 0.22), r_roof=d.get("roof_rc", 0.075), roof_crown=0.03,
        roof_taper=[(g0, 0.03), (g0 + 0.5, 0.0), (g1 - 0.9, 0.0), (g1, 0.02)],
        wheel_inset=0.036,
        rims=dict(color=d.get("rim_color", TRAFFIC_RIM["color"]), metal=TRAFFIC_RIM["metal"], rough=TRAFFIC_RIM["rough"], coat=0.4,
                  spokes=d.get("spokes", 5), kind="straight", spoke_w=(0.05, 0.036), dish=0.028, caliper="#3a3c3f"),
    )


def _drum_wheels(sc, d, segs, rim_color):
    """Wheels of the far levels in the node "body": a tyre with shoulders and a slightly dished rim disc."""
    from cesprites import materials as M
    from cesprites import meshutil as MU

    from .truck3d import _lathe_x
    R = sc.R
    r_rim = R - 0.095
    tyre = sc.mat("tyre", "#141415", rough=0.82, spec=0.35)
    rim = M.basic(sc.name + "_rimdisc", rim_color, rough=TRAFFIC_RIM["rough"], metal=TRAFFIC_RIM["metal"])
    inset = d.get("wheel_inset", 0.02)
    for ya, tw in ((sc.y_ra, d.get("tw_r", d["tw"])), (sc.y_fa, d["tw"])):
        for side in (1, -1):
            xc = sc.W2 - inset - tw / 2
            xo = tw / 2 - 0.02
            if segs >= 10:
                prof = [(r_rim, tw / 2 - 0.02), (R - 0.03, tw / 2), (R, tw / 2 - 0.04), (R, -tw / 2 + 0.04),
                        (R - 0.03, -tw / 2), (r_rim, -tw / 2 + 0.02)]
                disc = [(0.0, xo - 0.005), (r_rim * 0.3, xo - 0.005), (r_rim * 0.55, xo - 0.03), (r_rim * 1.02, xo)]
            else:
                # (no inner sidewall: beyond 120 m nobody looks under the car - room for the number plate in lod2)
                prof = [(r_rim * 0.95, tw / 2), (R, tw / 2), (R, -tw / 2)]
                disc = [(0.0, xo), (r_rim, xo)]
            bm = bmesh.new()
            _lathe_x(bm, prof, segs)
            ob_t = MU.make(sc.name + "_tyre_far", bm, tyre, parent=sc.center, smooth=True, sharp_deg=45)
            bm = bmesh.new()
            _lathe_x(bm, disc, segs)
            ob_r = MU.make(sc.name + "_rim_far", bm, rim, parent=sc.center, smooth=True, sharp_deg=45)
            for ob in (ob_t, ob_r):
                ob.location = (side * xc, ya, R)
                if side < 0:
                    ob.rotation_euler = (0.0, 0.0, math.pi)


def _mirrors(sc, ym, zm):
    """Door mirrors of the near level: a rounded housing on a foot, dark mirror glass facing backwards."""
    from cesprites import meshutil as MU
    glass = sc.mat("mirrorglass", MIRROR_GLASS["color"], rough=MIRROR_GLASS["rough"], metal=MIRROR_GLASS["metal"])
    for side in (-1, 1):
        xm = side * (sc.W2 + 0.0925)
        bm = MU.bm_box(0.125, 0.085, 0.105, (xm, ym + 0.005, zm + 0.006))
        MU.bm_beam((side * (sc.W2 - 0.03), ym + 0.02, zm - 0.045), (xm - side * 0.03, ym + 0.01, zm - 0.03), 0.045, 0.03, bm=bm)
        ob = MU.make(sc.name + "_mirror", bm, sc.paint, parent=sc.center, smooth=True, sharp_deg=50)
        m = MU.bevel(ob, 0.022, 2)
        m.harden_normals = True
        gl = MU.bm_box(0.1, 0.004, 0.078, (xm, ym - 0.039, zm + 0.006))
        MU.make(sc.name + "_mirrorglass", gl, glass, parent=sc.center)


def _level(spec3d, level, paint_hex, metal, fine=None):
    """One level of a traffic car. fine: {role: (pos, nor)} of the lofts of lod0 - the coarser levels take their
    normals from there (core.transfer_normals): they shade like lod0 and their decals end along the same lines."""
    from cesprites import carbody as CB
    from cesprites import cardetail as CD
    from cesprites import materials as M
    from cesprites import meshutil as MU
    from cesprites import rig as R
    from cesprites import vehicles

    from .vehicles3d import GREY, SHADOW_MARGIN_M, _add_soup, shadow_drums, shadow_stats
    rig = R.Rig(quick=True)
    name = spec3d["design"]
    far = level in ("lod2", "shadow")
    car = vehicles.Car(rig, traffic_design(name), paint=paint_hex, metal=metal, name=name)      # not built: decals
    sd = smooth_design(car, full_length=far)
    detail = dict(LOD.TRAFFIC_DETAIL[level])
    detail.update(spec3d.get("detail", {}).get(level, {}))
    MU.tagging(True)
    try:
        sc = CB.SmoothCar(rig, sd, paint=paint_hex, metal=metal, name=name, detail=detail)
        sc.build_lower()
        sc.build_greenhouse()
        if not far:
            sc.build_bumpers()
        if level != "shadow":
            sc.build_liners()
        dd = car.d
        ym = dd.get("mirror_y", dd["cabin"][-1][0] - 0.15)
        zm = car.lower_frame(ym)[2] + dd.get("mirror_dz", 0.1)
        ex = dd.get("extras", {})
        if level == "lod0":
            CD.wheels(sc, sd["rims"])
            _mirrors(sc, ym, zm)
            # exhaust: a dark pipe coming from under the car (a short chrome ring hung under the bumper)
            pipe = sc.mat("pipe", EXHAUST["color"], rough=EXHAUST["rough"], metal=EXHAUST["metal"])
            for (xe, ze, *rest) in ex.get("exhaust", [(0.5, 0.28)]):
                CD.exhaust(sc, xe, ze, "round", r=rest[0] if rest else 0.04, y_tip=-0.004, length=EXHAUST["length"],
                           sym=False, mat=pipe)
        elif level != "shadow":
            _drum_wheels(sc, sd, 12 if level == "lod1" else 6, sd["rims"]["color"])
            bm = bmesh.new()
            for side in (-1, 1):
                MU.bm_box(0.125, 0.085, 0.105, (side * (sc.W2 + 0.0925), ym + 0.005, zm + 0.006), bm=bm)
                if level == "lod1":
                    MU.bm_beam((side * (sc.W2 - 0.1), ym + 0.02, zm - 0.03), (side * (sc.W2 + 0.04), ym + 0.01, zm - 0.02),
                               0.045, 0.03, bm=bm)
            MU.make(name + "_mirror_far", bm, sc.paint, parent=sc.center)
            # the dark mirror glass looks backwards at every level (the far mirrors were paint all over and changed
            # colour at the 40 m swap)
            bm = bmesh.new()
            for side in (-1, 1):
                xm, yg, zg = side * (sc.W2 + 0.0925), ym + 0.005 - 0.0425 - 0.002, zm + 0.006
                vs = [bm.verts.new(p) for p in ((xm - 0.05, yg, zg - 0.039), (xm + 0.05, yg, zg - 0.039),
                                                (xm + 0.05, yg, zg + 0.039), (xm - 0.05, yg, zg + 0.039))]
                fc = bm.faces.new(vs)
                bm.normal_update()
                if fc.normal.y > 0.0:
                    fc.normal_flip()
            glass = sc.mat("mirrorglass", MIRROR_GLASS["color"], rough=MIRROR_GLASS["rough"], metal=MIRROR_GLASS["metal"])
            MU.make(name + "_mirrorglass_far", bm, glass, parent=sc.center)
        if "roof_rails" in ex and level != "shadow":
            y0, y1 = ex["roof_rails"]
            railm = M.basic(name + "_rail", ex.get("rail_color", "#9a9ea4"), rough=0.35, metal=0.6)
            bm = bmesh.new()
            n = 8 if level == "lod0" else (4 if level == "lod1" else 1)
            for side in (-1, 1):
                pts = []
                for i in range(n + 1):
                    y = y0 + (y1 - y0) * i / n
                    gh = sc.green_half(y)[1]
                    xx = gh["x_rc"] + gh["rr"] * 0.3 - 0.1
                    pts.append((side * xx, y, gh["zr"] - gh["rc"] * (xx / gh["x_rc"]) ** 2 + 0.045))
                for a, b in zip(pts[:-1], pts[1:]):
                    MU.bm_beam(a, b, 0.035, 0.03, bm=bm)
                if level != "lod2":
                    for p in (pts[0], pts[-1]):
                        MU.bm_box(0.04, 0.08, 0.05, (p[0], p[1] + (0.05 if p is pts[0] else -0.05), p[2] - 0.025), bm=bm)
            MU.make(name + "_rails", bm, railm, parent=sc.center)
    finally:
        MU.tagging(False)
    soups = core.soups_of(core.model_objects(rig))
    origin = np.array([0.0, car.L / 2.0, 0.0])
    nodes = {}
    tr = roles.Translator(overrides={"*_rim": dict(metal=TRAFFIC_RIM["metal"], rough=TRAFFIC_RIM["rough"])},
                          glass_class=(level == "lod0"), default_paint={"paint": paint_hex})
    if level == "shadow":
        # the hull is tucked inside the skin of lod0: where it stood out, the body lay in its own shadow
        mb = nodes.setdefault("body", core.MeshBuilder())
        tuck = []
        for s in soups:
            role = {sc.body.name: "body", sc.green.name: "cabin"}.get(s.name)
            if fine and role in fine:
                tuck.append(core.tuck_inside(s.pos, fine[role][0], SHADOW_MARGIN_M,      # each loft inside its own
                                             holes=[(ya, sc.R, sc.Ra + 0.03) for ya in (sc.y_ra, sc.y_fa)], nor=s.nor))
            mb.add("vpbr", s.pos, s.nor, GREY, (0.8, 0.0), roles.NO_LAMP)
        inset = sd.get("wheel_inset", 0.02)
        shadow_drums(mb, [(sc.W2 - inset, tw, ya, sc.R, sc.R)
                          for ya, tw in ((sc.y_ra, sd.get("tw_r", sd["tw"])), (sc.y_fa, sd["tw"]))], n=8)
        return car, sc, nodes, {}, origin, tr, shadow_stats(name, tuck) if tuck else {}, {}
    # the decal code asks the car for its lofts
    car.body, car.cabin = sc.body, sc.green
    car.bumper_obs = {} if far else {"rear": sc.bumper_rear, "front": sc.bumper_front}
    car.d.setdefault("cladding", car.d["bumper"].get("plastic", 0.25))           # dark sill between the wheels
    keys = {sc.body.name: "body", sc.green.name: "cabin"}
    for which, ob in car.bumper_obs.items():
        keys[ob.name] = "bumper_" + which
    lofts = {}
    for s in soups:
        role = keys.get(s.name)
        if role is None:
            continue
        if fine:
            src = fine.get(role) or (fine.get("body") if role.startswith("bumper") else None)
            if src is not None:
                s.nor = core.transfer_normals(s.pos, s.nor, src[0], src[1])
        if role != "cabin":
            core.flatten_ends(s.pos, s.nor)          # the flat end caps shade into the rounded ends
        lofts[role] = (s.pos.copy(), s.nor.copy())
    pal, tris, stats = decalgeo.car_surfaces(car, {s.name: s for s in soups}, cut=True,
                                             level={"lod0": 0, "lod1": 1, "lod2": 2}[level], paint_rough=0.24,
                                             seals=False, far_glass=True, far_plate=FAR_PLATE, glass_look=TRAFFIC_GLASS,
                                             far_sill=spec3d.get("far_sill", True))
    pivots = {}
    for s in soups:
        node = roles.node_of(s.ob)
        if node.startswith("wheel_"):
            mw = s.ob.matrix_world
            pivots[node] = np.array([mw[0][3], mw[1][3], mw[2][3]], dtype=np.float64)
        if level != "lod0":
            node = "body"
        if s.name in tris:
            t = tris[s.name]
            mb = nodes.setdefault(node, core.MeshBuilder())
            for mi in np.unique(t.mat):
                role, data, lamp = pal.items[int(mi)]
                sel = t.mat == mi
                tr.add_role(mb, role, dict(data), t.pos[sel], t.nor[sel], lamp)
        else:
            _add_soup(nodes, tr, s, node)
    return car, sc, nodes, pivots, origin, tr, stats, lofts


def build_car(model_id, spec3d):
    from cesprites import catalog

    from .vehicles3d import SLIVER_M, _sprite_spec, _wheel_parts
    t0 = time.time()
    design = spec3d["design"]
    colours = dict(catalog.TRAFFIC_COLORS[design])
    set_ids = list(spec3d.get("sets") or [])
    first = set_ids[0].split("_", 1)[1]
    paint_hex = colours[first]
    metal = catalog.METALLIC.get(first, 0.35)
    sspec = _sprite_spec(spec3d["source"])
    lods = []
    stats = {}
    model = None
    fine = None
    for level in ("lod0", "lod1", "lod2"):
        car, sc, nodes, pivots, origin, tr, st, lofts = _level(spec3d, level, paint_hex, metal, fine)
        stats[level] = st
        if level == "lod0":
            fine = lofts
            model = ModelData(model_id, spec3d["kind"], car.object_size())
            pts = np.concatenate([mb.points() for mb in nodes.values()])
            model.extent_m = sprite_extent(pts - origin, 0.0)
            model.lights = tr.lights(origin=origin)
            same = "tw_r" not in sc.d
            parts = [Part("body", "lod0_body", nodes["body"].finish(origin=origin, min_height=SLIVER_M))]
            parts += _wheel_parts(nodes, pivots, origin, sc.R, "wheel", same)
            lods.append(Lod("lod0", LOD.VEHICLE_LOD_DIST["lod0"], parts))
        else:
            lods.append(Lod(level, LOD.VEHICLE_LOD_DIST[level], [Part("body", level + "_body",
                                                                       nodes["body"].finish(origin=origin, min_height=SLIVER_M))]))
    car, sc, nodes, _p, origin, _tr, stats["shadow"], _l = _level(spec3d, "shadow", paint_hex, metal, fine)
    model.shadow = Part("body", "shadow", nodes["body"].finish(origin=origin, min_height=SLIVER_M))
    model.lods = lods
    model.paint = {"paint": paint_hex, "metal": metal}
    model.tags = list(sspec.get("tags", []))
    for sid in set_ids:
        cname = sid.split("_", 1)[1]
        model.sets[sid] = {"model": model_id, "paint": {"paint": colours[cname], "metal": catalog.METALLIC.get(cname, 0.35)}}
    model.stats = dict(build_s=round(time.time() - t0, 2), decals=stats)
    return model
