"""Heavy traffic: articulated truck (tractor + 13.6 m box/curtain trailer, 16.5 m) and a touring coach.
Vehicle space as for cars: y = 0 at the rear (anchor), +y forward, x = 0 centre, z = 0 ground."""
import math

import bmesh

from . import materials as M
from . import meshutil as MU
from .vehicles import BRAKE_RED, TAIL_RED, corner

AMBER = "#ffa21a"

TRUCK_VARIANTS = {
    "white": dict(box="#ecece8", cab="#ecece8", stripe="#1f4f9a", text="LOGISTIK", tarp=False),
    "red": dict(box="#a3231f", cab="#b02a24", stripe=None, text=None, tarp=True),
    "blue": dict(box="#21468f", cab="#21468f", stripe="#e9e9e5", text="TRANSPORT", tarp=False),
    "green": dict(box="#2e6b3a", cab="#e8e8e4", stripe=None, text=None, tarp=True),
}
BUS_VARIANTS = {
    "white": dict(body="#efefeb", s1="#1f4f9a", s2="#d6262b"),
    "red": dict(body="#b3242a", s1="#efefeb", s2="#1d1f22"),
    "blue": dict(body="#1f4f9a", s1="#efe0a0", s2="#efefeb"),
}


def build(rig, kind, p):
    if kind == "truck":
        return build_truck(rig, p)
    return build_bus(rig, p)


def _lamp(poly, part="tail", face="rear", tail=1.6, brake=3.2, **kw):
    d = dict(face=face, poly=poly, n=0.3, **kw)
    if part == "tail":
        d.update(mat="lamp_red", emit={"tail": (TAIL_RED, tail), "brake": (BRAKE_RED, brake)})
    elif part == "brake":
        d.update(mat="lamp_red", emit={"brake": (BRAKE_RED, brake)})
    elif part == "amber":
        d.update(mat="lamp_amber")
    elif part == "marker":
        d.update(mat="lamp_amber", emit={"tail": (AMBER, tail)})
    elif part == "reverse":
        d.update(mat="lamp_clear")
    elif part == "reflector":
        d.update(mat="reflector", emit={"tail": ("#ff2a10", tail)})
    return d


def _rect(x0, z0, x1, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


def _wheel(rig, name, x_outer, y, R, tw, side, tire, rim, dual=False):
    xc = x_outer - side * tw / 2
    prof = [(R * 0.6, -tw / 2), (R * 0.92, -tw / 2), (R * 0.98, -tw / 2 + 0.03), (R, -tw / 2 + 0.06),
            (R, tw / 2 - 0.06), (R * 0.98, tw / 2 - 0.03), (R * 0.92, tw / 2), (R * 0.6, tw / 2)]
    bm = MU.bm_lathe(prof, segs=28, axis="X", center=(xc, y, R))
    if dual:
        MU.bm_lathe(prof, segs=28, axis="X", center=(xc - side * (tw + 0.03), y, R), bm=bm)
    MU.make(name + "_tyre", bm, tire, parent=rig.root, smooth=True, sharp_deg=60)
    xf = x_outer - side * 0.04
    bm = MU.bm_cyl(R * 0.6, R * 0.6, 0.03, center=(xf, y, R), axis="X", segs=24)
    MU.bm_cyl(R * 0.22, R * 0.18, 0.06, center=(xf + side * 0.02, y, R), axis="X", segs=12, bm=bm)
    for i in range(10):
        a = 2 * math.pi * i / 10
        MU.bm_cyl(0.018, 0.018, 0.04, center=(xf + side * 0.02, y + math.cos(a) * R * 0.33, R + math.sin(a) * R * 0.33),
                  axis="X", segs=6, bm=bm)
    MU.make(name + "_rim", bm, rim, parent=rig.root)


def build_truck(rig, p):
    v = TRUCK_VARIANTS[p.get("variant", "white")]
    box_col = p.get("paint", v["box"])
    W2 = 1.275
    L_tr = 13.6
    box_z0, box_z1 = 1.22, 4.0
    root = rig.root
    tire = M.basic("tr_tyre", "#17181a", rough=0.85, spec=0.3)
    rim = M.basic("tr_rim", "#b9bdc2", rough=0.3, metal=0.9)
    dark = M.basic("tr_dark", "#1c1d1f", rough=0.6)
    grey = M.basic("tr_grey", "#6d7177", rough=0.5, metal=0.3)
    alu = M.basic("tr_alu", "#b8bcc1", rough=0.25, metal=1.0)

    # --- trailer box ------------------------------------------------------------------------
    side_dec = []
    rear_dec = [
        dict(face="rear", poly=_rect(0.0, box_z0, 0.006, box_z1), mat="seal", n=0.5),          # door split
        dict(face="rear", poly=[(1.18, box_z0), (1.3, box_z0), (1.3, box_z1), (1.18, box_z1)], mat="alu", n=0.5),
        dict(face="rear", poly=_rect(0.0, box_z1 - 0.12, 1.3, box_z1 + 0.1), mat="alu", n=0.5),
        dict(face="rear", poly=_rect(0.0, box_z0 - 0.1, 1.3, box_z0 + 0.1), mat="alu", n=0.5),
    ]
    for zh in (1.6, 2.6, 3.6):     # hinges
        rear_dec.append(dict(face="rear", poly=_rect(1.06, zh, 1.18, zh + 0.12), mat="dark", n=0.5))
    # contour marking (reflective tape: faint glow in the tail layer = caught by headlights)
    tape = dict(face="rear", poly=[_rect(1.1, box_z0 + 0.12, 1.16, box_z1 - 0.14), _rect(0.0, box_z1 - 0.2, 1.16, box_z1 - 0.14)],
                mat="#c21a14", emit={"tail": ("#ff3018", 0.45)}, n=0.5)
    rear_dec.append(tape)
    if v["tarp"]:
        for i in range(22):
            y = 0.3 + i * 0.6
            side_dec.append(dict(face="side", poly=_rect(y, box_z0 + 0.05, y + 0.035, box_z1 - 0.12), mat="dark", n=0.6))
        side_dec.append(dict(face="side", poly=_rect(0.0, box_z1 - 0.12, L_tr, box_z1 + 0.1), mat="alu", n=0.6))
    if v["stripe"]:
        side_dec.append(dict(face="side", poly=_rect(0.0, 1.55, L_tr, 1.75), mat=v["stripe"], n=0.6))
        rear_dec.append(dict(face="rear", poly=_rect(0.0, 1.55, 1.1, 1.75), mat=v["stripe"], n=0.5))
    # side marker lamps (amber, lit with the lights)
    for i in range(5):
        y = 0.6 + i * 3.0
        side_dec.append(_lamp(_rect(y, box_z0 + 0.03, y + 0.09, box_z0 + 0.09), part="marker", face="side", tail=2.0))
    box_mat = M.surface("tr_box", box_col, metal=0.15, rough=0.45 if v["tarp"] else 0.35, coat=0.0 if v["tarp"] else 0.3,
                        decals=rear_dec + side_dec)
    bm = MU.bm_box(2 * W2, L_tr, box_z1 - box_z0, (0.0, 0.05 + L_tr / 2, (box_z0 + box_z1) / 2))
    ob = MU.make("tr_box", bm, box_mat, parent=root)
    MU.bevel(ob, 0.035, 2)
    # lock rods
    bm = bmesh.new()
    for x in (-0.95, -0.35, 0.35, 0.95):
        MU.bm_cyl(0.022, 0.022, box_z1 - box_z0 - 0.3, center=(x, 0.03, (box_z0 + box_z1) / 2), segs=8, bm=bm)
        MU.bm_box(0.08, 0.05, 0.1, (x, 0.04, 2.1), bm=bm)
    MU.make("tr_rods", bm, alu, parent=root)
    if v["text"]:
        _side_text(rig, v["text"], y0=0.05, y1=L_tr, z=2.85, size=0.62, x=W2 + 0.004, color=v["stripe"] or "#222222")
    # chassis under the trailer, landing gear, side guards
    bm = MU.bm_box(1.0, L_tr - 0.4, 0.28, (0.0, 0.25 + (L_tr - 0.4) / 2, box_z0 - 0.14))
    for side in (-1, 1):
        MU.bm_box(0.09, 0.09, 0.95, (side * 0.95, 11.2, 0.55), bm=bm)
        MU.bm_box(0.25, 0.25, 0.05, (side * 0.95, 11.2, 0.04), bm=bm)
    MU.make("tr_chassis", bm, dark, parent=root)
    bm = bmesh.new()
    for side in (-1, 1):
        for zz in (0.6, 0.86):
            MU.bm_box(0.05, 4.6, 0.09, (side * (W2 - 0.06), 8.55, zz), bm=bm)
        for y in (6.4, 8.5, 10.6):
            MU.bm_box(0.04, 0.06, 0.45, (side * (W2 - 0.12), y, 0.95), bm=bm)
    MU.make("tr_guards", bm, grey, parent=root)
    # trailer axles (3, single wide tyres) + mud flaps
    R = 0.53
    for y in (3.0, 4.31, 5.62):
        for side in (-1, 1):
            _wheel(rig, "tr_w", side * (W2 - 0.03), y, R, 0.385, side, tire, rim)
    bm = bmesh.new()
    for side in (-1, 1):
        MU.bm_box(0.42, 0.02, 0.5, (side * (W2 - 0.25), 2.32, 0.5), bm=bm)
        MU.bm_box(2 * W2 - 0.1, 2.0, 0.05, (0.0, 4.31, 1.18), bm=bm)  # wheel cover strip
    MU.make("tr_flaps", bm, dark, parent=root)

    # --- rear light bar, underride guard, plate --------------------------------------------
    rdec = []
    for side in (-1, 1):
        xo = 1.18
        segs = [(0.98, 1.06, "amber"), (0.76, 0.98, "tail"), (0.62, 0.76, "reverse"), (0.50, 0.62, "brake")]
        for (x0, x1, part) in segs:
            rdec.append(_lamp(_rect(x0 * side if side > 0 else -x1, 0.80, x1 * side if side > 0 else -x0, 0.93),
                              part=part, sym=False))
        # reflective triangles
        cx = side * 0.82
        rdec.append(_lamp([(cx - 0.09, 0.66), (cx + 0.09, 0.66), (cx, 0.78)], part="reflector", sym=False, tail=0.7))
    rdec.append(dict(face="rear", sym=False, poly=_rect(-0.3, 0.66, 0.22, 0.77), mat="plate",
                     emit={"tail": ("#fff4dc", 0.12)}))
    rdec.append(dict(face="rear", sym=False, poly=_rect(-0.3, 0.66, -0.265, 0.77), mat="plate_blue"))
    lb_mat = M.surface("tr_lightbar", "#202124", metal=0.2, rough=0.5, coat=0.0, decals=rdec)
    bm = MU.bm_box(2 * W2 - 0.04, 0.16, 0.36, (0.0, 0.10, 0.80))
    MU.make("tr_lightbar", bm, lb_mat, parent=root)
    bm = MU.bm_box(2 * W2 - 0.2, 0.12, 0.12, (0.0, 0.08, 0.5))
    for x in (-0.6, 0.6):
        MU.bm_box(0.08, 0.08, 0.6, (x, 0.12, 0.8), bm=bm)
    MU.make("tr_underride", bm, grey, parent=root)

    # --- tractor -----------------------------------------------------------------------------
    cab_col = v["cab"] if p.get("variant") else box_col
    y_cab0, y_cab1 = 14.2, 16.48
    cab_dec = [
        dict(face="front", poly=_rect(0.0, 2.35, 1.06, 3.42), mat="glass", n=0.5),
        dict(face="front", poly=_rect(0.0, 1.55, 0.92, 2.15), mat="dark", n=0.5),               # grille
        dict(face="front", poly=_rect(0.0, 0.62, 1.25, 1.0), mat="#3a3d42", n=0.5),              # bumper
        dict(face="front", poly=_rect(0.82, 0.72, 1.18, 0.9), mat="lamp_clear", n=0.5),          # headlights
        dict(face="side", poly=_rect(15.35, 2.4, 16.32, 3.32), mat="glass", n=0.6),
        dict(face="side", poly=_rect(14.3, 2.4, 15.25, 3.32), mat="glass", n=0.6),
        dict(face="side", poly=_rect(15.3, 0.9, 15.32, 3.4), mat="seal", n=0.6),
        dict(face="rear", poly=_rect(0.0, 1.3, 1.3, 3.9), mat="#2b2d30", n=0.5),
    ]
    cab_mat = M.surface("tr_cab", cab_col, metal=0.2, rough=0.3, coat=0.6, decals=cab_dec)
    bm = MU.bm_box(2.48, y_cab1 - y_cab0, 2.65, (0.0, (y_cab0 + y_cab1) / 2, 1.25 + 2.65 / 2))
    ob = MU.make("tr_cabbox", bm, cab_mat, parent=root)
    MU.bevel(ob, 0.12, 3)
    # roof deflector (wedge up to trailer height)
    bm = bmesh.new()
    pts = [(-1.18, y_cab0 + 0.05), (1.18, y_cab0 + 0.05)]
    verts = [bm.verts.new(v_) for v_ in [
        (-1.18, y_cab0 + 0.1, 3.9), (1.18, y_cab0 + 0.1, 3.9), (1.18, y_cab1 - 0.5, 3.9), (-1.18, y_cab1 - 0.5, 3.9),
        (-1.12, y_cab0 + 0.1, 4.02), (1.12, y_cab0 + 0.1, 4.02)]]
    bm.faces.new((verts[0], verts[1], verts[2], verts[3]))
    bm.faces.new((verts[3], verts[2], verts[5], verts[4]))
    bm.faces.new((verts[0], verts[4], verts[5], verts[1]))
    bm.faces.new((verts[0], verts[3], verts[4]))
    bm.faces.new((verts[1], verts[5], verts[2]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    MU.make("tr_deflector", bm, cab_mat, parent=root)
    # tractor chassis, tanks, wheels
    bm = MU.bm_box(1.0, 5.2, 0.3, (0.0, 13.75, 1.0))
    MU.make("tr_tchassis", bm, dark, parent=root)
    bm = bmesh.new()
    for side in (-1, 1):
        MU.bm_cyl(0.32, 0.32, 1.1, center=(side * 1.0, 13.0, 0.82), axis="Y", segs=20, bm=bm)
    MU.make("tr_tanks", bm, alu, parent=root)
    for side in (-1, 1):
        _wheel(rig, "tr_tw", side * (W2 - 0.04), 11.35, R, 0.3, side, tire, rim, dual=True)
        _wheel(rig, "tr_fw", side * (W2 - 0.03), 15.05, R, 0.32, side, tire, rim)
    # mirrors
    bm = bmesh.new()
    for side in (-1, 1):
        MU.bm_box(0.12, 0.08, 0.45, (side * 1.42, 16.25, 2.85), bm=bm)
        MU.bm_beam((side * 1.2, 16.3, 3.1), (side * 1.42, 16.27, 3.05), 0.04, bm=bm)
    MU.make("tr_mirrors", bm, dark, parent=root)
    return dict(object={"width_m": 2.55, "length_m": 16.5, "height_m": 4.0})


def _side_text(rig, text, y0, y1, z, size, x, color):
    from . import textgeo
    mat = M.basic("txt_" + text, color, rough=0.4, coat=0.3)
    for side in (-1, 1):
        ob = textgeo.text_mesh(rig, text, size, mat)
        textgeo.place_side(ob, side, (y0 + y1) / 2, z, side * x)


def build_bus(rig, p):
    v = BUS_VARIANTS[p.get("variant", "white")]
    col = p.get("paint", v["body"])
    L, W2, H = 12.8, 1.275, 3.65
    root = rig.root
    zb_body = 0.38
    y_ra, y_fa = 3.15, 10.0
    R = 0.5
    Ra = R + 0.06
    tire = M.basic("bus_tyre", "#17181a", rough=0.85, spec=0.3)
    rim = M.basic("bus_rim", "#b9bdc2", rough=0.3, metal=0.9)
    dark = M.basic("bus_dark", "#141516", rough=0.7)
    dec = [
        # side window band with thin pillars
        dict(face="side", poly=_rect(0.9, 1.72, 11.25, 3.28), mat="seal", n=0.55),
        dict(face="side", poly=[_rect(0.95 + i * 1.47, 1.76, 0.95 + i * 1.47 + 1.4, 3.24) for i in range(7)], mat="glass", n=0.55),
        dict(face="side", poly=_rect(11.32, 0.5, 12.2, 3.24), mat="glass", n=0.55, only="right"),          # door
        dict(face="side", poly=_rect(11.32, 1.76, 12.5, 3.24), mat="glass", n=0.55, only="left"),
        # livery stripes
        dict(face="side", poly=[(0.0, 0.95), (L, 0.95), (L, 1.12), (0.0, 1.32)], mat=v["s1"], n=0.55),
        dict(face="side", poly=[(0.0, 1.38), (L, 1.18), (L, 1.26), (0.0, 1.46)], mat=v["s2"], n=0.55),
        dict(face="rear", poly=_rect(0.0, 0.95, 1.4, 1.12), mat=v["s1"], n=0.5),
        # rear: window, engine grille louvres, lamps, plate
        dict(face="rear", poly=_rect(0.0, 2.62, 1.0, 3.32), mat="seal", n=0.5),
        dict(face="rear", poly=_rect(0.0, 2.66, 0.96, 3.28), mat="glass", n=0.5),
        dict(face="rear", poly=_rect(0.0, 0.62, 1.12, 0.66), mat="dark", n=0.5),
    ]
    for i in range(6):
        z = 1.35 + i * 0.12
        dec.append(dict(face="rear", poly=_rect(0.0, z, 0.8, z + 0.035), mat="dark", n=0.5))
    dec += [
        _lamp(_rect(1.04, 0.72, 1.22, 1.95), part="tail"),
        _lamp(_rect(1.04, 1.98, 1.22, 2.12), part="amber"),
        _lamp(_rect(1.04, 2.15, 1.22, 2.3), part="reverse"),
        _lamp(_rect(0.0, 3.40, 0.35, 3.46), part="brake", brake=4.0),
        dict(face="rear", sym=False, poly=_rect(-0.26, 0.48, 0.26, 0.59), mat="plate", emit={"tail": ("#fff4dc", 0.12)}),
        dict(face="rear", sym=False, poly=_rect(-0.26, 0.48, -0.225, 0.59), mat="plate_blue"),
        # front
        dict(face="front", poly=_rect(0.0, 1.25, 1.16, 3.4), mat="glass", n=0.5),
        dict(face="front", poly=_rect(0.62, 0.58, 1.1, 0.78), mat="lamp_clear", n=0.5),
        dict(face="front", poly=_rect(0.0, 0.5, 0.5, 0.9), mat="dark", n=0.5),
    ]
    for i in range(4):
        y = 1.2 + i * 2.6
        dec.append(_lamp(_rect(y, 0.45, y + 0.08, 0.5), part="marker", face="side", tail=2.0))
    mat = M.surface("bus_body", col, metal=0.25, rough=0.3, coat=0.6, decals=dec, plastic_below=0.42)

    def bottom(y):
        zb = zb_body
        for ya in (y_ra, y_fa):
            dy = abs(y - ya)
            if dy < Ra:
                zb = max(zb, R + math.sqrt(Ra * Ra - dy * dy))
        return zb

    ys = set([0.0, L])
    for i in range(0, 61):
        ys.add(L * i / 60)
    for e in range(12):
        ys.add(0.25 * (1 - math.cos(math.pi / 2 * e / 11)))
        ys.add(L - 0.45 * (1 - math.cos(math.pi / 2 * e / 11)))
    for ya in (y_ra, y_fa):
        for k in range(-12, 13):
            ys.add(ya + Ra * k / 12.0)
        ys.add(ya - Ra - 0.003)
        ys.add(ya + Ra + 0.003)
    rings = []
    for y in sorted(ys):
        if y < 0 or y > L:
            continue
        e = corner(y, 0.18) + corner(L - y, 0.4)
        w = W2 - e * 0.6
        zb = bottom(y) + e * 0.4
        zt = H - e * 0.5 - (0.12 * max(0.0, (y - (L - 1.2)) / 1.2) ** 2)
        rt = 0.28
        half = [(0.0, zb), (w - 0.06, zb), (w, zb + 0.06), (w, zt - rt * 1.2), (w - 0.03, zt - rt * 0.5),
                (w - rt * 0.55, zt - 0.06), (w - rt * 1.3, zt), (w * 0.4, zt + 0.02), (0.0, zt + 0.025)]
        rings.append([(x, y, z) for (x, z) in MU.mirror_ring(half)])
    ob = MU.make("bus_body", MU.loft(rings), mat, parent=root, smooth=True, sharp_deg=40)
    # wells, wheels, bumpers, mirrors
    bm = bmesh.new()
    for ya in (y_ra, y_fa):
        MU.bm_box(2 * W2 - 0.6, 2 * Ra, R + Ra - 0.2, (0.0, ya, (0.2 + R + Ra) / 2), bm=bm)
    MU.make("bus_wells", bm, dark, parent=root)
    for side in (-1, 1):
        _wheel(rig, "bus_rw", side * (W2 - 0.05), y_ra, R, 0.28, side, tire, rim, dual=True)
        _wheel(rig, "bus_fw", side * (W2 - 0.05), y_fa, R, 0.3, side, tire, rim)
    bm = MU.bm_box(2 * W2 - 0.04, 0.1, 0.22, (0.0, 0.02, 0.48))
    MU.bm_box(2 * W2 - 0.04, 0.1, 0.25, (0.0, L - 0.02, 0.5), bm=bm)
    ob = MU.make("bus_bumpers", bm, dark, parent=root)
    MU.bevel(ob, 0.03, 2)
    bm = bmesh.new()
    for side in (-1, 1):
        MU.bm_beam((side * 1.1, L - 0.2, 3.2), (side * 1.45, L + 0.35, 3.0), 0.05, bm=bm)
        MU.bm_beam((side * 1.45, L + 0.35, 3.0), (side * 1.45, L + 0.4, 2.55), 0.05, bm=bm)
        MU.bm_box(0.1, 0.06, 0.38, (side * 1.45, L + 0.4, 2.35), bm=bm)
    MU.make("bus_mirrors", bm, dark, parent=root)
    return dict(object={"width_m": 2.55, "length_m": L, "height_m": H})
