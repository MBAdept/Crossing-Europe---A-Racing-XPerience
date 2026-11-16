"""Buildings and roadside structures. Origin = centre of the front (near) face on the ground; the
building extends along +y (away from the road camera). Windows are procedural facade masks, lit
randomly in the 'lights' layer."""
import math
import random

import bmesh
from mathutils import Vector

from . import materials as M
from . import meshutil as MU

WARM = "#ffc46b"


# --- materials ----------------------------------------------------------------------------------

def facade(name, wall, grids, glass="#26313b", frame="#e9e6de", lit=0.45, warm=WARM, strength=1.5,
           brick=None, noise=0.06, decals=None, frame_w=0.07, shutters=None):
    """Wall with window grids. grids: [dict(face=front|back|side|any_side, u=(u0,u1), z=(z0,z1),
    pitch=(pu,pz), win=(wu,wz), lit=frac, color=hex, strength=s, arch=bool, glass=hex)]
    u = x on front/back faces, y on side faces."""
    m, nb = M.new_material(name)
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    if brick:
        bt = nb.node("ShaderNodeTexBrick")
        # brick texture is 2D: feed (u, z) with u = y on side faces, x elsewhere
        uu = nb.mixf(nb.gt(nb.absf(nx), nb.absf(ny)), x, y)
        bv = nb.node("ShaderNodeCombineXYZ")
        nb.feed(bv.inputs[0], uu)
        nb.feed(bv.inputs[1], z)
        nb.links.new(bv.outputs[0], bt.inputs["Vector"])
        bt.inputs["Color1"].default_value = M.srgb(brick[0])
        bt.inputs["Color2"].default_value = M.srgb(brick[1])
        bt.inputs["Mortar"].default_value = M.srgb(brick[2])
        bt.inputs["Scale"].default_value = brick[3] if len(brick) > 3 else 4.0
        bt.inputs["Mortar Size"].default_value = 0.018
        bt.inputs["Brick Width"].default_value = 0.5
        bt.inputs["Row Height"].default_value = 0.25
        col = bt.outputs["Color"]
    else:
        f = nb.ramp(nb.noise(0.9, detail=3.0), [(0.3, (0, 0, 0, 1)), (0.75, (1, 1, 1, 1))])
        c1 = M.srgb(wall)
        c2 = (c1[0] * (1 - noise * 2), c1[1] * (1 - noise * 2), c1[2] * (1 - noise * 2), 1.0)
        col = nb.mix(f, c1, c2)
    par = dict(col=col, rough=0.85, spec=0.3, metal=0.0)
    emit = None
    is_side = nb.gt(nb.absf(nx), 0.5)
    is_fb = nb.gt(nb.absf(ny), 0.5)
    vert = nb.lt(nb.absf(nz), 0.5)

    def apply(mask, color, rough, spec, metal=0.0):
        c = M.srgb(color) if isinstance(color, str) else color
        par["col"] = nb.mix(mask, par["col"], c)
        par["rough"] = nb.mixf(mask, par["rough"], rough)
        par["spec"] = nb.mixf(mask, par["spec"], spec)
        par["metal"] = nb.mixf(mask, par["metal"], metal)

    for gi, g in enumerate(grids):
        face = g.get("face", "front")
        if face == "front":
            ftest, u = nb.mul(vert, nb.lt(ny, -0.5)), x
        elif face == "back":
            ftest, u = nb.mul(vert, nb.gt(ny, 0.5)), x
        elif face == "side":
            ftest, u = nb.mul(vert, is_side), y
        elif face == "left":
            ftest, u = nb.mul(vert, nb.lt(nx, -0.5)), y
        elif face == "right":
            ftest, u = nb.mul(vert, nb.gt(nx, 0.5)), y
        else:  # front+back
            ftest, u = nb.mul(vert, is_fb), x
        u0, u1 = g["u"]
        z0, z1 = g["z"]
        pu, pz = g["pitch"]
        wu, wz = g["win"]
        rng = nb.AND(nb.band(u, u0, u1), nb.band(z, z0, z1), ftest)
        fu = nb.math("FLOORED_MODULO", nb.sub(u, u0), pu)
        fz = nb.math("FLOORED_MODULO", nb.sub(z, z0), pz)
        du = nb.absf(nb.sub(fu, pu / 2))
        dz = nb.sub(fz, pz / 2)
        adz = nb.absf(dz)
        win = nb.AND(nb.lt(du, wu / 2), nb.lt(adz, wz / 2))
        if g.get("arch"):
            # round top: inside a circle of radius wu/2 centred wu/2 below the top
            cz = nb.sub(dz, wz / 2 - wu / 2)
            circ = nb.lt(nb.add(nb.mul(du, du), nb.mul(cz, cz)), (wu / 2) ** 2)
            win = nb.mul(win, nb.OR(nb.lt(cz, 0.0), circ))
        fw = g.get("frame_w", frame_w)
        frm = nb.AND(nb.lt(du, wu / 2 + fw), nb.lt(adz, wz / 2 + fw))
        if g.get("arch"):
            cz2 = nb.sub(dz, wz / 2 - wu / 2)
            circ2 = nb.lt(nb.add(nb.mul(du, du), nb.mul(cz2, cz2)), (wu / 2 + fw) ** 2)
            frm = nb.mul(frm, nb.OR(nb.lt(cz2, 0.0), circ2))
        win = nb.mul(win, rng)
        frm = nb.mul(frm, rng)
        if shutters and g.get("shutters", True) and face != "shop":
            sh = nb.AND(nb.lt(du, wu / 2 + fw + wu * 0.5), nb.gt(du, wu / 2 + fw), nb.lt(adz, wz / 2), rng)
            apply(sh, shutters, 0.6, 0.3)
        apply(frm, g.get("frame", frame), 0.5, 0.35)
        apply(win, g.get("glass", glass), 0.08, 0.9, 0.2)
        # random lit windows (per window cell)
        iu = nb.math("FLOOR", nb.math("DIVIDE", nb.sub(u, u0), pu))
        iz = nb.math("FLOOR", nb.math("DIVIDE", nb.sub(z, z0), pz))
        cmb = nb.node("ShaderNodeCombineXYZ")
        nb.feed(cmb.inputs[0], iu)
        nb.feed(cmb.inputs[1], iz)
        nb.feed(cmb.inputs[2], nb.add(nb.mul(nx, 3.1), nb.add(nb.mul(ny, 7.3), gi * 1.7)))
        wn = nb.node("ShaderNodeTexWhiteNoise", noise_dimensions="3D")
        nb.links.new(cmb.outputs[0], wn.inputs["Vector"])
        lit_m = nb.mul(win, nb.lt(wn.outputs["Value"], g.get("lit", lit)))
        bright = nb.madd(wn.outputs["Value"], 0.8, 0.6)
        ecol = M.emit_col(g.get("color", warm), g.get("strength", strength))
        term = nb.color_scale(nb.color_scale(ecol, bright), lit_m)
        emit = term if emit is None else nb.vadd(emit, term)
    for d in decals or []:
        # buildings: 'front' = facing the camera (-y) -> car convention 'rear'
        d = dict(d, face={"front": "rear", "back": "front"}.get(d.get("face", "front"), d.get("face")))
        mask = M.decal_mask(nb, d)
        p = M._preset(d.get("mat", "black"))
        apply(mask, p["color"], p.get("rough", 0.5), p.get("spec", 0.4), p.get("metal", 0.0))
        for layer, (ec, s) in (d.get("emit") or {}).items():
            term = nb.color_scale(M.emit_col(ec, s), mask)
            emit = term if emit is None else nb.vadd(emit, term)
    out = M.principled(nb, par["col"], rough=par["rough"], spec=par["spec"], metal=par["metal"])
    return M.finish(m, nb, out, {"lights": emit} if emit is not None else None)


def roof_mat(name, color, kind="tiles", rows=0.33):
    m, nb = M.new_material(name)
    x, y, z = nb.coords()
    f = nb.ramp(nb.noise(1.5, detail=3.0), [(0.3, (0, 0, 0, 1)), (0.75, (1, 1, 1, 1))])
    c1 = M.srgb(color)
    col = nb.mix(f, c1, (c1[0] * 0.75, c1[1] * 0.75, c1[2] * 0.75, 1))
    if kind == "tiles":
        line = nb.lt(nb.math("FLOORED_MODULO", z, rows * 0.55), 0.04)
        col = nb.mix(nb.mul(line, 0.6), col, (c1[0] * 0.35, c1[1] * 0.35, c1[2] * 0.35, 1))
        rough = 0.75
    elif kind == "metal":
        line = nb.lt(nb.math("FLOORED_MODULO", x, 0.5), 0.05)
        col = nb.mix(nb.mul(line, 0.5), col, (c1[0] * 0.6, c1[1] * 0.6, c1[2] * 0.6, 1))
        rough = 0.45
    else:
        rough = 0.9
    out = M.principled(nb, col, rough=rough, spec=0.35, metal=0.3 if kind == "metal" else 0.0)
    return M.finish(m, nb, out)


# --- geometry helpers ---------------------------------------------------------------------------

def walls(rig, name, w, d, h, mat, y0=0.0, x0=0.0, z0=0.0, bev=0.03):
    bm = MU.bm_box(w, d, h, (x0, y0 + d / 2, z0 + h / 2))
    ob = MU.make(name, bm, mat, parent=rig.root)
    if bev:
        MU.bevel(ob, bev, 1)
    return ob


def gable_roof(rig, name, w, d, h_eave, h_ridge, mat, y0=0.0, x0=0.0, over=0.4, thick=0.18, hip=0.0, ridge_axis="y"):
    """Gable roof (ridge along y by default) with overhang; hip > 0 cuts the front/back gables (half-hip)."""
    bm = bmesh.new()
    if ridge_axis == "y":
        hw = w / 2 + over
        ya, yb = y0 - over, y0 + d + over
        rise = h_ridge - h_eave
        drop = rise * (over / (w / 2))
        e = h_eave - drop
        yr0, yr1 = ya + hip, yb - hip
        v = [bm.verts.new(p) for p in [
            (x0 - hw, ya, e), (x0 + hw, ya, e), (x0 + hw, yb, e), (x0 - hw, yb, e),
            (x0, yr0, h_ridge), (x0, yr1, h_ridge)]]
        if hip > 0:
            bm.faces.new((v[0], v[1], v[4]))       # front hip
            bm.faces.new((v[2], v[3], v[5]))       # back hip
        bm.faces.new((v[1], v[2], v[5], v[4]))     # right slope
        bm.faces.new((v[3], v[0], v[4], v[5]))     # left slope (open gable ends show the gable walls)
    else:
        hd = d / 2 + over
        yc = y0 + d / 2
        xa, xb = x0 - w / 2 - over, x0 + w / 2 + over
        rise = h_ridge - h_eave
        drop = rise * (over / (d / 2))
        e = h_eave - drop
        xr0, xr1 = xa + hip, xb - hip
        v = [bm.verts.new(p) for p in [
            (xa, yc - hd, e), (xb, yc - hd, e), (xb, yc + hd, e), (xa, yc + hd, e),
            (xr0, yc, h_ridge), (xr1, yc, h_ridge)]]
        bm.faces.new((v[0], v[1], v[5], v[4]))     # front slope
        bm.faces.new((v[2], v[3], v[4], v[5]))     # back slope
        if hip > 0:
            bm.faces.new((v[1], v[2], v[5]))
            bm.faces.new((v[3], v[0], v[4]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = MU.make(name, bm, mat, parent=rig.root)
    if thick:
        MU.solidify(ob, thick, offset=-1.0)
    return ob


def gable_wall(rig, name, w, h_eave, h_ridge, y, mat, x0=0.0, depth=0.3):
    """Triangular gable wall piece (front face at y)."""
    pts = [(x0 - w / 2, h_eave), (x0 + w / 2, h_eave), (x0, h_ridge)]
    bm = MU.prism(pts, depth, plane="XZ", offset=y)
    return MU.make(name, bm, mat, parent=rig.root)


def obj_size(w, h, d=None):
    o = {"width_m": round(w, 2), "height_m": round(h, 2)}
    if d is not None:
        o["length_m"] = round(d, 2)
    return o


def door(rig, name, x, w, h, y, mat, z0=0.0):
    bm = MU.bm_box(w, 0.12, h, (x, y - 0.03, z0 + h / 2))
    return MU.make(name, bm, mat, parent=rig.root)


# --- rural buildings ----------------------------------------------------------------------------

def farmhouse(rig, p):
    W, D, H = 11.0, 17.0, 3.6
    wall = facade("farm_wall", "#9a4a32", [
        dict(face="side", u=(1.2, 15.8), z=(0.9, 2.5), pitch=(2.4, 2.0), win=(0.9, 1.15), lit=0.4),
        dict(face="front", u=(-5.2, -2.4), z=(0.9, 2.5), pitch=(1.4, 2.0), win=(0.8, 1.1), lit=0.6),
        dict(face="front", u=(2.4, 5.2), z=(0.9, 2.5), pitch=(1.4, 2.0), win=(0.8, 1.1), lit=0.6),
        dict(face="front", u=(-1.4, 1.4), z=(4.3, 5.6), pitch=(1.4, 1.3), win=(0.7, 0.8), lit=0.3),
    ], brick=("#9b4a32", "#83402c", "#d8cfc2", 3.2), frame="#f0ede4",
        decals=[dict(face="front", sym=True, poly=[(0.0, 0.0), (1.55, 0.0), (1.55, 2.9), (0.0, 3.25)], mat="#5a3a22"),
                dict(face="front", sym=True, poly=[(0.0, 0.0), (0.06, 0.0), (0.06, 3.2), (0.0, 3.25)], mat="#2d1d10")])
    walls(rig, "farm_walls", W, D, H, wall)
    gable_wall(rig, "farm_gable", W, H, 8.4, 0.0, wall, depth=0.4)
    gable_wall(rig, "farm_gable_b", W, H, 8.4, D - 0.4, wall, depth=0.4)
    roof = roof_mat("farm_roof", "#8e3423", "tiles")
    gable_roof(rig, "farm_roof", W, D, H, 8.6, roof, over=0.45, hip=1.6)
    trim = M.basic("farm_trim", "#f2efe6", rough=0.6)
    bm = MU.bm_box(0.5, 0.5, 1.8, (2.2, D * 0.6, 8.0))
    MU.make("farm_chimney", bm, M.basic("farm_chim", "#7e3a28", rough=0.8), parent=rig.root)
    # yard lamp
    lamp = M.basic("farm_lamp", "#fff1c9", rough=0.3, emit={"lights": ("#ffd890", 7.0)})
    bm = MU.bm_box(0.25, 0.2, 0.3, (3.0, -0.12, 3.2))
    MU.make("farm_lamp", bm, lamp, parent=rig.root)
    return dict(object=obj_size(W + 0.9, 8.6, D))


def barn(rig, p):
    W, D, H = 10.0, 14.0, 4.2
    m, nb = M.new_material("barn_wood")
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    side = nb.gt(nb.absf(nx), 0.5)
    u = nb.mixf(side, x, y)
    plank = nb.lt(nb.math("FLOORED_MODULO", u, 0.32), 0.025)
    f = nb.ramp(nb.noise(2.0, detail=3.0), [(0.3, (0, 0, 0, 1)), (0.75, (1, 1, 1, 1))])
    col = nb.mix(f, M.srgb("#7a2a20"), M.srgb("#5e2018"))
    col = nb.mix(plank, col, M.srgb("#2a120d"))
    # white door frame + X brace on the front
    fr = nb.AND(nb.lt(ny, -0.5), nb.lt(nb.absf(x), 2.2), nb.lt(z, 3.6))
    inner = nb.AND(nb.lt(nb.absf(x), 2.0), nb.lt(z, 3.4))
    brace = nb.OR(nb.lt(nb.absf(nb.sub(nb.mul(nb.absf(x), 1.7), z)), 0.18),
                  nb.lt(nb.absf(nb.sub(z, 1.7)), 0.09), nb.lt(nb.absf(x), 0.06))
    col = nb.mix(nb.mul(fr, nb.OR(nb.NOT(inner), brace)), col, M.srgb("#efece4"))
    out = M.principled(nb, col, rough=0.8, spec=0.3)
    wood = M.finish(m, nb, out)
    walls(rig, "barn_walls", W, D, H, wood)
    gable_wall(rig, "barn_gable", W, H, 8.0, 0.0, wood, depth=0.3)
    gable_wall(rig, "barn_gable_b", W, H, 8.0, D - 0.3, wood, depth=0.3)
    roof = roof_mat("barn_roof", "#4d4f52", "metal")
    gable_roof(rig, "barn_roof", W, D, H, 8.1, roof, over=0.5)
    lamp = M.basic("barn_lamp", "#fff1c9", rough=0.3, emit={"lights": ("#ffd890", 7.0)})
    bm = MU.bm_box(0.25, 0.25, 0.25, (0.0, -0.13, 4.4))
    MU.make("barn_lamp", bm, lamp, parent=rig.root)
    return dict(object=obj_size(W + 1.0, 8.1, D))


def church(rig, p):
    W, D, H = 10.0, 22.0, 8.0
    TW = 6.0
    plaster = facade("church_wall", "#e8e1d0", [
        dict(face="side", u=(8.0, 21.0), z=(2.0, 6.8), pitch=(3.0, 4.8), win=(1.3, 3.8), lit=0.8, arch=True,
             color="#ffd27a", strength=1.6, frame="#cfc6b2"),
        dict(face="front", u=(-1.0, 1.0), z=(9.0, 12.5), pitch=(2.0, 3.5), win=(1.0, 2.2), lit=0.0, arch=True),
        dict(face="front", u=(-1.0, 1.0), z=(17.0, 19.5), pitch=(2.0, 2.5), win=(1.1, 1.8), lit=0.0, arch=True,
             glass="#1a1a1a"),
    ], frame="#cfc6b2",
        decals=[dict(face="front", sym=True, poly=[(0.0, 0.0), (0.95, 0.0), (0.95, 2.6), (0.0, 3.25)], mat="#4a2e1c"),
                dict(face="front", sym=True, poly=[(0.0, 14.2), (0.85, 14.2), (0.85, 15.9), (0.0, 15.9)],
                     mat="#e9e3cf", emit={"lights": ("#fff0c0", 1.4)}),
                dict(face="front", sym=True, poly=[(0.0, 14.95), (0.6, 14.95), (0.6, 15.05), (0.0, 15.05)], mat="#222222")])
    walls(rig, "church_nave", W, D, H, plaster, y0=TW - 1.0)
    gable_wall(rig, "church_gable", W, H, 14.0, TW - 1.0, plaster, depth=0.3)
    gable_wall(rig, "church_gable_b", W, H, 14.0, TW - 1.0 + D - 0.3, plaster, depth=0.3)
    slate = roof_mat("church_roof", "#3d4247", "tiles", rows=0.25)
    gable_roof(rig, "church_roof", W, D, H, 14.2, slate, y0=TW - 1.0, over=0.4)
    walls(rig, "church_tower", TW, TW, 21.0, plaster, y0=0.0)
    # spire
    bm = bmesh.new()
    base = [(-TW / 2 - 0.2, -0.2), (TW / 2 + 0.2, -0.2), (TW / 2 + 0.2, TW + 0.2), (-TW / 2 - 0.2, TW + 0.2)]
    vs = [bm.verts.new((bx, by, 21.0)) for (bx, by) in base]
    top = bm.verts.new((0.0, TW / 2, 34.0))
    for i in range(4):
        bm.faces.new((vs[i], vs[(i + 1) % 4], top))
    bm.faces.new(list(reversed(vs)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    MU.make("church_spire", bm, slate, parent=rig.root)
    gold = M.basic("church_gold", "#c9a43a", rough=0.3, metal=1.0)
    bm = MU.bm_box(0.08, 0.08, 1.6, (0.0, TW / 2, 34.6))
    MU.bm_box(0.7, 0.08, 0.08, (0.0, TW / 2, 34.9), bm=bm)
    MU.make("church_cross", bm, gold, parent=rig.root)
    return dict(object=obj_size(W + 0.8, 35.4, D + TW))


def windmill(rig, p):
    brick = facade("mill_brick", "#7a3b2b", [
        dict(face="any", u=(-1.2, 1.2), z=(1.0, 6.0), pitch=(2.4, 2.6), win=(0.8, 1.1), lit=0.5),
    ], brick=("#7d3b2a", "#6a3222", "#cbbfae", 3.0))
    thatch = M.basic("mill_thatch", "#5b4a33", rough=0.95, color2="#3e3223", var_scale=3.0, bump=(14.0, 0.5))
    wood = M.basic("mill_wood", "#e6e1d3", rough=0.7)
    dark = M.basic("mill_dark", "#2a2622", rough=0.8)
    # octagonal tapered tower: brick base (0-7 m) + thatched body (7-19 m)
    prof_b = [(0.0, 0.0), (4.4, 0.0), (4.1, 7.0), (0.0, 7.0)]
    bm = MU.bm_lathe(prof_b, segs=8, center=(0.0, 4.6, 0.0))
    MU.make("mill_base", bm, brick, parent=rig.root)
    prof_t = [(0.0, 7.0), (3.9, 7.0), (2.6, 19.0), (0.0, 19.0)]
    bm = MU.bm_lathe(prof_t, segs=8, center=(0.0, 4.6, 0.0))
    MU.make("mill_body", bm, thatch, parent=rig.root)
    # gallery (stelling)
    bm = MU.bm_lathe([(3.9, 6.9), (6.0, 6.9), (6.0, 7.2), (3.9, 7.2)], segs=16, center=(0.0, 4.6, 0.0))
    for i in range(16):
        a = 2 * math.pi * i / 16
        MU.bm_beam((math.cos(a) * 5.9, 4.6 + math.sin(a) * 5.9, 7.2), (math.cos(a) * 5.9, 4.6 + math.sin(a) * 5.9, 8.2), 0.08, bm=bm)
        MU.bm_beam((math.cos(a) * 5.9, 4.6 + math.sin(a) * 5.9, 6.9), (math.cos(a) * 4.2, 4.6 + math.sin(a) * 4.2, 4.0), 0.1, bm=bm)
    MU.make("mill_gallery", bm, dark, parent=rig.root)
    # cap
    bm = MU.bm_sphere(3.0, center=(0.0, 4.6, 19.6), scale=(1.0, 1.25, 0.75), subdiv=3)
    MU.make("mill_cap", bm, thatch, parent=rig.root, smooth=True)
    # sails: X shaped lattice in front of the cap (facing the camera)
    hub = Vector((0.0, 1.0, 19.8))
    bm = bmesh.new()
    MU.bm_cyl(0.45, 0.35, 1.6, center=(0.0, 1.6, 19.8), axis="Y", segs=12, bm=bm)
    for k in range(4):
        a = math.radians(30 + 90 * k)
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        n = Vector((-d.z, 0.0, d.x))
        tip = hub + d * 12.5
        MU.bm_beam(hub, tip, 0.3, 0.3, bm=bm, up=(0, 1, 0))
        for i in range(13):
            t = 2.5 + i * 0.8
            pa = hub + d * t
            MU.bm_beam(pa - n * 0.15, pa + n * 1.8, 0.07, 0.07, bm=bm, up=(0, 1, 0))
        MU.bm_beam(hub + d * 2.5 + n * 1.8, tip + n * 1.8, 0.08, 0.08, bm=bm, up=(0, 1, 0))
    MU.make("mill_sails", bm, wood, parent=rig.root)
    bm = MU.bm_box(1.2, 0.2, 2.1, (0.0, 0.25, 1.05))
    MU.make("mill_door", bm, M.basic("mill_door", "#2e4a2a", rough=0.6), parent=rig.root)
    return dict(object=obj_size(25.0, 32.3, 9.0))


def factory(rig, p):
    W, D, H = 34.0, 22.0, 9.0
    wall = facade("fac_wall", "#a9a49a", [
        dict(face="front", u=(-16.0, 16.0), z=(2.0, 7.4), pitch=(4.0, 5.4), win=(3.0, 3.8), lit=0.6,
             color="#d8e6ff", strength=1.8, frame="#5a5e63"),
        dict(face="side", u=(1.0, 21.0), z=(2.0, 7.4), pitch=(4.0, 5.4), win=(3.0, 3.8), lit=0.5,
             color="#d8e6ff", strength=1.8, frame="#5a5e63"),
    ], frame="#5a5e63", decals=[dict(face="front", sym=False, poly=[(6.0, 0.0), (11.0, 0.0), (11.0, 5.0), (6.0, 5.0)], mat="#5d6a74")])
    walls(rig, "fac_walls", W, D, H, wall)
    roof = roof_mat("fac_roof", "#6c7076", "metal")
    glass = M.basic("fac_skylight", "#5d7486", rough=0.1, metal=0.3, emit={"lights": ("#cfe0ff", 0.9)})
    for i in range(5):
        x0 = -W / 2 + i * (W / 5)
        bm = bmesh.new()
        v = [bm.verts.new(q) for q in [(x0, -0.2, H), (x0 + W / 5, -0.2, H), (x0 + W / 5, D + 0.2, H), (x0, D + 0.2, H),
                                         (x0 + W / 5, -0.2, H + 3.2), (x0 + W / 5, D + 0.2, H + 3.2)]]
        bm.faces.new((v[0], v[1], v[4]))
        bm.faces.new((v[3], v[5], v[2]))
        bm.faces.new((v[0], v[4], v[5], v[3]))
        bm.faces.new((v[0], v[3], v[2], v[1]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        MU.make("fac_saw", bm, roof, parent=rig.root)
        bm = MU.bm_box(0.15, D, 2.8, (x0 + W / 5 - 0.1, D / 2, H + 1.5))
        MU.make("fac_glass", bm, glass, parent=rig.root)
    chim = facade("fac_chim", "#8a4430", [], brick=("#8a4430", "#743a28", "#c2b6a4", 2.5))
    bm = MU.bm_lathe([(0.0, 0.0), (1.6, 0.0), (1.0, 34.0), (0.0, 34.0)], segs=16, center=(W / 2 - 4.0, D + 3.0, 0.0))
    MU.make("fac_chimney", bm, chim, parent=rig.root, smooth=True)
    red = M.basic("fac_red", "#a01010", rough=0.3, emit={"lights": ("#ff2010", 8.0)})
    bm = MU.bm_cyl(0.3, 0.3, 0.3, center=(W / 2 - 4.0, D + 3.0, 34.2), segs=10)
    MU.make("fac_redlight", bm, red, parent=rig.root)
    tank = M.basic("fac_tank", "#c5c8cc", rough=0.35, metal=0.7)
    bm = MU.bm_cyl(3.2, 3.2, 14.0, center=(-W / 2 + 4.0, D + 4.0, 7.0), segs=24)
    MU.bm_cyl(3.2, 0.5, 1.5, center=(-W / 2 + 4.0, D + 4.0, 14.7), segs=24, bm=bm)
    MU.make("fac_tank", bm, tank, parent=rig.root, smooth=True, sharp_deg=40)
    return dict(object=obj_size(W, 34.5, D + 7.0))


def house_med(rig, p):
    W, D, H = 10.0, 8.0, 6.6
    wall = facade("med_wall", "#e2c896", [
        dict(face="front", u=(-4.5, 4.5), z=(0.7, 6.2), pitch=(3.0, 3.1), win=(1.0, 1.55), lit=0.45),
        dict(face="side", u=(0.5, 7.5), z=(0.7, 6.2), pitch=(3.5, 3.1), win=(0.9, 1.4), lit=0.35),
    ], frame="#f3efe6", shutters="#3f6f4a", noise=0.1)
    walls(rig, "med_walls", W, D, H, wall)
    roof = roof_mat("med_roof", "#b45a32", "tiles", rows=0.28)
    bm = bmesh.new()
    o = 0.5
    v = [bm.verts.new(q) for q in [(-W / 2 - o, -o, H), (W / 2 + o, -o, H), (W / 2 + o, D + o, H), (-W / 2 - o, D + o, H),
                                     (-W / 2 + 3.0, D / 2, H + 2.4), (W / 2 - 3.0, D / 2, H + 2.4)]]
    bm.faces.new((v[0], v[1], v[5], v[4]))
    bm.faces.new((v[2], v[3], v[4], v[5]))
    bm.faces.new((v[1], v[2], v[5]))
    bm.faces.new((v[3], v[0], v[4]))
    bm.faces.new((v[0], v[3], v[2], v[1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = MU.make("med_roof", bm, roof, parent=rig.root)
    MU.solidify(ob, 0.18, offset=-1.0)
    rail = M.basic("med_rail", "#2a2a2a", rough=0.5, metal=0.6)
    bm = MU.bm_box(3.2, 1.0, 0.15, (0.0, -0.5, 3.3))
    for i in range(12):
        MU.bm_box(0.03, 0.03, 0.9, (-1.55 + i * 0.28, -0.98, 3.8), bm=bm)
    MU.bm_box(3.2, 0.05, 0.05, (0.0, -0.98, 4.25), bm=bm)
    MU.make("med_balcony", bm, rail, parent=rig.root)
    return dict(object=obj_size(W + 1.0, 9.0, D))


# --- city buildings -----------------------------------------------------------------------------

def building_block_a(rig, p):
    W, D, H = 18.0, 12.0, 19.0
    wall = facade("blka_wall", "#d9c59a", [
        dict(face="front", u=(-8.4, 8.4), z=(0.6, 18.4), pitch=(2.8, 3.0), win=(1.4, 1.6), lit=0.5),
        dict(face="side", u=(0.6, 11.4), z=(0.6, 18.4), pitch=(2.7, 3.0), win=(1.3, 1.6), lit=0.4),
    ], frame="#f1ece2", noise=0.07)
    walls(rig, "blka_walls", W, D, H, wall)
    slab = M.basic("blka_slab", "#cfccc4", rough=0.7)
    rail = M.basic("blka_rail", "#3a3d40", rough=0.5, metal=0.5)
    bm = bmesh.new()
    bm2 = bmesh.new()
    for f in range(1, 6):
        z = 0.6 + f * 3.0 - 0.55
        for x in (-5.6, 5.6):
            MU.bm_box(4.2, 1.2, 0.18, (x, -0.6, z), bm=bm)
            MU.bm_box(4.2, 0.05, 0.9, (x, -1.18, z + 0.5), bm=bm2)
    MU.make("blka_balc", bm, slab, parent=rig.root)
    MU.make("blka_rail", bm2, rail, parent=rig.root)
    bm = MU.bm_box(W + 0.3, D + 0.3, 0.5, (0.0, D / 2, H + 0.25))
    MU.make("blka_parapet", bm, slab, parent=rig.root)
    return dict(object=obj_size(W + 0.3, H + 0.5, D))


def building_block_b(rig, p):
    W, D, H = 20.0, 13.0, 21.5
    wall = facade("blkb_wall", "#8c4a36", [
        dict(face="front", u=(-9.6, 9.6), z=(4.2, 21.0), pitch=(2.4, 3.2), win=(1.2, 1.9), lit=0.5),
        dict(face="side", u=(0.6, 12.4), z=(4.2, 21.0), pitch=(2.4, 3.2), win=(1.2, 1.9), lit=0.4),
        dict(face="front", u=(-9.6, 9.6), z=(0.2, 3.6), pitch=(4.8, 3.4), win=(3.8, 2.8), lit=0.85,
             color="#ffe6bf", strength=1.5, frame="#2a2c2e", glass="#3a4a55"),
    ], brick=("#8c4a36", "#7a3e2d", "#c4b8a6", 3.0), frame="#ece6da")
    walls(rig, "blkb_walls", W, D, H, wall)
    trim = M.basic("blkb_trim", "#d8d2c4", rough=0.7)
    bm = MU.bm_box(W + 0.4, D + 0.4, 0.6, (0.0, D / 2, H + 0.3))
    MU.bm_box(W + 0.2, 0.3, 0.35, (0.0, -0.15, 3.85), bm=bm)
    MU.make("blkb_trim", bm, trim, parent=rig.root)
    return dict(object=obj_size(W + 0.4, H + 0.6, D))


def building_tall(rig, p):
    W, D, H = 22.0, 22.0, 56.0
    m, nb = M.new_material("tower_glass")
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    side = nb.gt(nb.absf(nx), 0.5)
    u = nb.mixf(side, x, y)
    floor_z = nb.math("FLOORED_MODULO", z, 3.5)
    band = nb.lt(floor_z, 0.9)
    mull = nb.lt(nb.math("FLOORED_MODULO", u, 1.6), 0.12)
    sky = nb.ramp(nb.math("DIVIDE", z, H), [(0.0, M.srgb("#2c4256")), (1.0, M.srgb("#6f8ea8"))])
    col = nb.mix(nb.OR(band, mull), sky, M.srgb("#c9cdd1"))
    rough = nb.mixf(nb.OR(band, mull), 0.06, 0.6)
    metal = nb.mixf(nb.OR(band, mull), 0.6, 0.0)
    out = M.principled(nb, col, rough=rough, metal=metal, spec=0.8)
    iu = nb.math("FLOOR", nb.math("DIVIDE", u, 3.2))
    iz = nb.math("FLOOR", nb.math("DIVIDE", z, 3.5))
    cmb = nb.node("ShaderNodeCombineXYZ")
    nb.feed(cmb.inputs[0], iu)
    nb.feed(cmb.inputs[1], iz)
    nb.feed(cmb.inputs[2], nb.add(nb.mul(nx, 3.0), nb.mul(ny, 5.0)))
    wn = nb.node("ShaderNodeTexWhiteNoise", noise_dimensions="3D")
    nb.links.new(cmb.outputs[0], wn.inputs["Vector"])
    vert = nb.lt(nb.absf(nz), 0.5)
    lit = nb.AND(nb.NOT(nb.OR(band, mull)), nb.lt(wn.outputs["Value"], 0.34), vert, nb.gt(z, 4.0))
    em = nb.color_scale(nb.color_scale(M.emit_col("#ffe4b8", 0.75), nb.madd(wn.outputs["Value"], 1.2, 0.55)), lit)
    mat = M.finish(m, nb, out, {"lights": em})
    walls(rig, "tower", W, D, H, mat, bev=0.05)
    lobby = M.basic("tower_lobby", "#2e3a44", rough=0.1, metal=0.4, emit={"lights": ("#fff2d6", 2.2)})
    bm = MU.bm_box(W - 2.0, 0.3, 3.4, (0.0, 0.0, 1.8))
    MU.make("tower_lobby", bm, lobby, parent=rig.root)
    top = M.basic("tower_top", "#8d9196", rough=0.6, metal=0.3)
    bm = MU.bm_box(W * 0.5, D * 0.5, 3.0, (0.0, D / 2, H + 1.5))
    MU.bm_box(W + 0.3, D + 0.3, 0.8, (0.0, D / 2, H + 0.4), bm=bm)
    MU.bm_cyl(0.15, 0.08, 7.0, center=(3.0, D / 2, H + 6.0), segs=8, bm=bm)
    MU.make("tower_top", bm, top, parent=rig.root)
    red = M.basic("tower_red", "#a01010", rough=0.3, emit={"lights": ("#ff2010", 8.0)})
    bm = MU.bm_sphere(0.3, center=(3.0, D / 2, H + 9.6), subdiv=1)
    MU.make("tower_redlight", bm, red, parent=rig.root)
    return dict(object=obj_size(W + 0.3, H + 9.9, D))


def building_oldtown(rig, p):
    W, D, H = 8.0, 12.0, 13.0
    wall = facade("old_wall", "#d79a7a", [
        dict(face="front", u=(-3.6, 3.6), z=(4.0, 12.6), pitch=(2.4, 2.9), win=(1.0, 1.6), lit=0.5),
        dict(face="front", u=(-3.6, 3.6), z=(13.5, 16.0), pitch=(2.4, 2.5), win=(0.9, 1.3), lit=0.4),
        dict(face="side", u=(0.6, 11.4), z=(4.0, 12.6), pitch=(2.6, 2.9), win=(1.0, 1.5), lit=0.4),
        dict(face="front", u=(-3.6, 3.6), z=(0.3, 3.4), pitch=(3.6, 3.4), win=(2.4, 2.6), lit=0.9, arch=True,
             color="#ffe2b8", strength=1.5, frame="#5a3a2a", glass="#30383e"),
    ], frame="#f6f2ea", noise=0.08)
    walls(rig, "old_walls", W, D, H, wall)
    # stepped gable (front)
    bm = bmesh.new()
    steps = 5
    for i in range(steps):
        w = W * (1 - i / steps)
        MU.bm_box(w, 0.5, 1.4, (0.0, 0.25, H + 0.7 + i * 1.4), bm=bm)
    MU.make("old_gable", bm, wall, parent=rig.root)
    roof = roof_mat("old_roof", "#7d3226", "tiles", rows=0.25)
    gable_roof(rig, "old_roof", W, D - 0.6, H, H + 6.6, roof, y0=0.5, over=0.2)
    cap = M.basic("old_cap", "#efe9df", rough=0.7)
    bm = bmesh.new()
    for i in range(steps):
        w = W * (1 - i / steps)
        MU.bm_box(w + 0.15, 0.6, 0.12, (0.0, 0.25, H + 1.4 + i * 1.4), bm=bm)
    MU.make("old_caps", bm, cap, parent=rig.root)
    return dict(object=obj_size(W + 0.4, H + 7.0, D))


def building_shop(rig, p):
    W, D, H = 14.0, 10.0, 8.2
    wall = facade("shop_wall", "#ece7dc", [
        dict(face="front", u=(-6.4, 6.4), z=(0.3, 3.5), pitch=(4.25, 3.2), win=(3.6, 2.8), lit=1.0,
             color="#ffe9c8", strength=1.6, frame="#2c2e30", glass="#3b4b56"),
        dict(face="front", u=(-6.4, 6.4), z=(4.7, 7.6), pitch=(2.13, 2.9), win=(1.1, 1.5), lit=0.45),
        dict(face="side", u=(0.6, 9.4), z=(4.7, 7.6), pitch=(2.3, 2.9), win=(1.1, 1.5), lit=0.35),
    ], frame="#f6f4ee", noise=0.05)
    walls(rig, "shop_walls", W, D, H, wall)
    sign = M.basic("shop_sign", "#1f6e8c", rough=0.4, emit={"lights": ("#9fe0ff", 1.6)})
    bm = MU.bm_box(9.0, 0.25, 0.9, (0.0, -0.12, 4.15))
    MU.make("shop_sign", bm, sign, parent=rig.root)
    m, nb = M.new_material("shop_awning")
    x, y, z = nb.coords()
    stripe = nb.lt(nb.math("FLOORED_MODULO", x, 0.8), 0.4)
    col = nb.mix(stripe, M.srgb("#b8322a"), M.srgb("#f1ece2"))
    aw = M.finish(m, nb, M.principled(nb, col, rough=0.8, spec=0.3, sheen=0.3))
    bm = bmesh.new()
    v = [bm.verts.new(q) for q in [(-6.5, 0.0, 3.6), (6.5, 0.0, 3.6), (6.5, -1.6, 2.8), (-6.5, -1.6, 2.8)]]
    bm.faces.new(v)
    ob = MU.make("shop_awning", bm, aw, parent=rig.root)
    MU.solidify(ob, 0.05)
    trim = M.basic("shop_trim", "#8b8f94", rough=0.5)
    bm = MU.bm_box(W + 0.3, D + 0.3, 0.45, (0.0, D / 2, H + 0.22))
    MU.make("shop_parapet", bm, trim, parent=rig.root)
    return dict(object=obj_size(W + 0.3, H + 0.45, D))
