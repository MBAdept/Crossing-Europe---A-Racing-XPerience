"""Regional city buildings and bridge parts (docs/staedte.md sections 2 and 4).

Conventions as in props_buildings: origin = centre of the near (front) face on the ground, the building
extends along +y (away from the road camera); 3/4 view for the RIGHT roadside (the -x side faces the road,
tag mirror_left). Facade details are object-space shader masks (windows with frames, mullions, shutters,
blinds; brick, ashlar, rustication, half-timbering, clapboard, panel joints) - lit windows feed the
'lights' layer - plus real geometry where relief matters (cornices, sills, pediments, balconies, gables,
roofs, dormers, chimneys, fences, garden plants).

Sets: props/city_<style>_<name> (style = hanse, german, german_old, dutch, belgian, paris, french, spanish,
italian, vienna, swiss, central, eastern, balkan, baltic) and props/bridge_truss_arch, props/bridge_pylon,
props/bridge_lamp, props/houseboat. The table CITY_PROPS at the end lists them (merged into props.PROPS).
"""
import math
import random

import bmesh
from mathutils import Matrix, Vector

from . import materials as M
from . import meshutil as MU
from .props_buildings import obj_size
from .props_nature import bark, crown, leaves, trunk

WARM = "#ffc46b"
LIT = ("#ffc46b", "#ffd690", "#ffe6bf")


def _lin(c):
    return M.srgb(c) if isinstance(c, str) else c


def shade(c, k):
    """sRGB hex colour scaled by k (k < 1 darker) -> hex."""
    h = c.lstrip("#")
    v = [min(255, max(0, int(int(h[i:i + 2], 16) * k))) for i in (0, 2, 4)]
    return "#%02x%02x%02x" % tuple(v)


# --- wall material ------------------------------------------------------------------------------

def _noise_col(nb, color, noise, scale=0.9):
    f = nb.ramp(nb.noise(scale, detail=3.0), [(0.3, (0, 0, 0, 1)), (0.75, (1, 1, 1, 1))])
    c1 = _lin(color)
    k = 1 - noise * 2
    return nb.mix(f, c1, (c1[0] * k, c1[1] * k, c1[2] * k, 1.0))


def _mod(nb, a, m):
    return nb.math("FLOORED_MODULO", a, m)


def _surface(nb, spec, u, z):
    """Colour socket of a wall surface. spec: hex colour or dict(color, kind, ...):
    kind plain | brick (color2, mortar, scale) | ashlar (joint, h, w) | rustic (joint, h) |
    clap (line, pitch) | vboard (line, pitch) | panel (joint, pu, pz, u0, z0) | timber (see _timber)."""
    if isinstance(spec, str):
        spec = dict(color=spec)
    kind = spec.get("kind", "plain")
    col = spec["color"]
    if kind == "brick":
        bt = nb.node("ShaderNodeTexBrick")
        bv = nb.node("ShaderNodeCombineXYZ")
        nb.feed(bv.inputs[0], u)
        nb.feed(bv.inputs[1], z)
        nb.links.new(bv.outputs[0], bt.inputs["Vector"])
        bt.inputs["Color1"].default_value = M.srgb(col)
        bt.inputs["Color2"].default_value = M.srgb(spec.get("color2", shade(col, 0.86)))
        bt.inputs["Mortar"].default_value = M.srgb(spec.get("mortar", shade(col, 1.35)))
        bt.inputs["Scale"].default_value = spec.get("scale", 2.6)
        bt.inputs["Mortar Size"].default_value = spec.get("mortar_size", 0.012)
        bt.inputs["Brick Width"].default_value = 0.5
        bt.inputs["Row Height"].default_value = 0.25
        bt.inputs["Bias"].default_value = spec.get("bias", 0.0)
        out = bt.outputs["Color"]
        if spec.get("noise", 0.05):
            f = nb.ramp(nb.noise(0.7, detail=2.0), [(0.3, (0, 0, 0, 1)), (0.8, (1, 1, 1, 1))])
            out = nb.mix(nb.mul(f, spec.get("noise", 0.05) * 3.0), out, M.srgb(shade(col, 0.7)))
        return out
    base = _noise_col(nb, col, spec.get("noise", 0.06))
    if kind == "plain":
        return base
    jc = _lin(spec.get("joint", shade(col, 0.72)))
    if kind == "ashlar":
        h, w, jw = spec.get("h", 0.55), spec.get("w", 1.15), spec.get("jw", 0.03)
        row = nb.math("FLOOR", nb.math("DIVIDE", z, h))
        off = nb.mul(_mod(nb, row, 2.0), w * 0.5)
        joint = nb.OR(nb.lt(_mod(nb, z, h), jw), nb.lt(_mod(nb, nb.add(u, off), w), jw))
        return nb.mix(nb.mul(joint, spec.get("strength", 0.7)), base, jc)
    if kind == "rustic":
        h, jw = spec.get("h", 0.6), spec.get("jw", 0.07)
        fz = _mod(nb, z, h)
        # bevelled groove: dark joint + slightly lit upper chamfer
        joint = nb.lt(fz, jw)
        lip = nb.AND(nb.gt(fz, jw), nb.lt(fz, jw * 2.0))
        c = nb.mix(nb.mul(joint, 0.85), base, jc)
        if spec.get("vertical", True):
            row = nb.math("FLOOR", nb.math("DIVIDE", z, h))
            off = nb.mul(_mod(nb, row, 2.0), spec.get("w", 1.6) * 0.5)
            vj = nb.lt(_mod(nb, nb.add(u, off), spec.get("w", 1.6)), jw * 0.7)
            c = nb.mix(nb.mul(vj, 0.7), c, jc)
        return nb.mix(nb.mul(lip, 0.35), c, M.srgb(shade(col, 1.12)))
    if kind == "clap":
        p = spec.get("pitch", 0.2)
        fz = nb.math("DIVIDE", _mod(nb, z, p), p)
        c = nb.mix(nb.mul(nb.sub(1.0, fz), 0.45), base, jc)
        return nb.mix(nb.lt(fz, 0.12), c, M.srgb(shade(col, 0.55)))
    if kind == "vboard":
        p = spec.get("pitch", 0.22)
        return nb.mix(nb.mul(nb.lt(_mod(nb, u, p), 0.03), 0.8), base, jc)
    if kind == "panel":
        pu, pz, jw = spec.get("pu", 3.6), spec.get("pz", 2.8), spec.get("jw", 0.04)
        j = nb.OR(nb.lt(_mod(nb, nb.sub(u, spec.get("u0", 0.0)), pu), jw), nb.lt(_mod(nb, nb.sub(z, spec.get("z0", 0.0)), pz), jw))
        return nb.mix(nb.mul(j, 0.8), base, jc)
    if kind == "timber":
        return _timber(nb, base, spec, u, z)
    if kind == "concrete":
        # weathered concrete: vertical run-off streaks below every floor slab
        mp = nb.node("ShaderNodeMapping")
        nb.links.new(nb.texco(), mp.inputs["Vector"])
        mp.inputs["Scale"].default_value = (6.0, 6.0, 0.35)
        st = nb.ramp(nb.noise(1.0, detail=2.0, vec=mp.outputs[0]), [(0.45, (0, 0, 0, 1)), (0.75, (1, 1, 1, 1))])
        fz = nb.math("DIVIDE", _mod(nb, z, spec.get("pz", 2.9)), spec.get("pz", 2.9))
        return nb.mix(nb.mul(st, nb.mul(nb.sub(1.0, fz), spec.get("streaks", 0.45))), base, jc)
    raise ValueError(kind)


def _timber(nb, base, s, u, z):
    """Half-timbering: posts every `pitch` from u0, beams at the floor lines and sill/lintel heights,
    diagonal braces in every second bay (bays given by `brace` parity), restricted to u_range."""
    tc = _lin(s.get("timber", "#3d2a1d"))
    u0, p, w = s["u0"], s["pitch"], s.get("w", 0.2)
    fu = _mod(nb, nb.sub(u, u0), p)
    post = nb.OR(nb.lt(fu, w * 0.5), nb.gt(fu, p - w * 0.5))
    bay = nb.math("FLOOR", nb.math("DIVIDE", nb.sub(u, u0), p))
    beams = None
    braces = None
    for fi, (z0, z1) in enumerate(s["floors"]):
        inside = nb.band(z, z0 - 0.001, z1 + 0.001)
        bl = nb.OR(nb.lt(nb.absf(nb.sub(z, z0 + w * 0.5)), w * 0.5), nb.lt(nb.absf(nb.sub(z, z1 - w * 0.5)), w * 0.5))
        for zz in (s.get("sill"), s.get("lintel")):
            if zz is not None and z0 + zz < z1 - w:
                bl = nb.OR(bl, nb.lt(nb.absf(nb.sub(z, z0 + zz)), w * 0.35))
        bl = nb.mul(bl, inside)
        beams = bl if beams is None else nb.OR(beams, bl)
        if s.get("brace", True):
            t = nb.math("DIVIDE", fu, p)
            sz = nb.math("DIVIDE", nb.sub(z, z0), z1 - z0)
            par = _mod(nb, nb.add(bay, fi), 2.0)
            # "/" in even bays, "\" in odd bays -> the braces form chevrons (Mann figures) around posts
            d1 = nb.absf(nb.sub(t, sz))
            d2 = nb.absf(nb.sub(nb.sub(1.0, t), sz))
            d = nb.mixf(par, d1, d2)
            sel = nb.lt(_mod(nb, nb.add(bay, s.get("brace_phase", 0)), s.get("brace_every", 2)), 0.5)
            br = nb.AND(nb.lt(d, w * 0.55 / max(p, z1 - z0)), inside, sel)
            braces = br if braces is None else nb.OR(braces, br)
    m = nb.OR(post, beams) if beams is not None else post
    if braces is not None:
        m = nb.OR(m, braces)
    ua, ub = s.get("u_range", (-1e4, 1e4))
    za, zb = s.get("z_range", (-1e4, 1e4))
    m = nb.AND(m, nb.band(u, ua, ub), nb.band(z, za, zb))
    return nb.mix(m, base, tc)


def _face(nb, face):
    """(test mask, u coordinate) for a face selector; u = x on front/back, y on sides."""
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    vert = nb.lt(nb.absf(nz), 0.5)
    # thresholds 0.8: 45 degree chamfer faces belong to none of the axis faces
    if face == "front":
        return nb.mul(vert, nb.lt(ny, -0.8)), x
    if face == "back":
        return nb.mul(vert, nb.gt(ny, 0.8)), x
    if face == "left":
        return nb.mul(vert, nb.lt(nx, -0.8)), y
    if face == "right":
        return nb.mul(vert, nb.gt(nx, 0.8)), y
    if face == "side":
        return nb.mul(vert, nb.gt(nb.absf(nx), 0.8)), y
    if face == "chamfer":
        # 45 degree front-left corner face; u = distance along it (x - y) / sqrt 2
        return nb.AND(vert, nb.lt(nx, -0.4), nb.lt(ny, -0.4)), nb.mul(nb.sub(x, y), 0.70711)
    raise ValueError(face)


def grid(face, u0, nu, pu, z0, nz, pz, win, **kw):
    """Window grid: nu x nz windows of size win=(w, h) in cells of pu x pz starting at (u0, z0);
    the window bottom sits `sill` above the cell bottom (default centred)."""
    g = dict(face=face, u0=u0, nu=nu, pu=pu, z0=z0, nz=nz, pz=pz, win=win)
    g.update(kw)
    return g


def centres(g):
    """Window centres (u, z, i, j) of a grid (skipped cells left out)."""
    wu, wz = g["win"]
    sill = g.get("sill", (g["pz"] - wz) * 0.5)
    skip = set(tuple(s) for s in g.get("skip", ()))
    out = []
    for j in range(g["nz"]):
        for i in range(g["nu"]):
            if (i, j) in skip:
                continue
            out.append((g["u0"] + (i + 0.5) * g["pu"], g["z0"] + j * g["pz"] + sill + wz * 0.5, i, j))
    return out


def wallmat(name, color, grids=(), zones=(), frame="#ece8df", glass="#26313b", lit=0.45, strength=1.5,
            frame_w=0.07, rough=0.85, decals=None, curtains=0.35, seed=0.0):
    """Wall with windows. color: surface spec (see _surface); zones: [dict(box=((x0,x1),(y0,y1),(z0,z1)),
    surface=spec)] painted over it in order. grids: see grid(); per grid options: top (round|seg|pointed),
    mull dict(v=n, h=n or [fractions], w), shutters colour, blind colour (+blind_max), frame, glass, lit,
    color (light), strength, frame_w, skip [(i, j)], kind (win|door|shop)."""
    m, nb = M.new_material(name)
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    side = nb.gt(nb.absf(nx), nb.absf(ny))
    uu = nb.mixf(side, x, y)
    col = _surface(nb, color, uu, z)
    for zn in zones:
        (xa, xb), (ya, yb), (za, zb) = zn["box"]
        mask = nb.AND(nb.band(x, xa, xb), nb.band(y, ya, yb), nb.band(z, za, zb))
        col = nb.mix(mask, col, _surface(nb, zn["surface"], uu, z))
    par = dict(col=col, rough=rough, spec=0.3, metal=0.0)
    emit = None

    def apply(mask, color_, rough_, spec_, metal_=0.0):
        c = _lin(color_) if isinstance(color_, (str, tuple)) else color_
        par["col"] = nb.mix(mask, par["col"], c)
        par["rough"] = nb.mixf(mask, par["rough"], rough_)
        par["spec"] = nb.mixf(mask, par["spec"], spec_)
        par["metal"] = nb.mixf(mask, par["metal"], metal_)

    for gi, g in enumerate(grids):
        kind = g.get("kind", "win")
        ftest, u = _face(nb, g.get("face", "front"))
        u0, pu, z0, pz = g["u0"], g["pu"], g["z0"], g["pz"]
        u1, z1 = u0 + g["nu"] * pu, z0 + g["nz"] * pz
        wu, wz = g["win"]
        sill = g.get("sill", (pz - wz) * 0.5)
        rng = nb.AND(nb.band(u, u0, u1), nb.band(z, z0, z1), ftest)
        fu = _mod(nb, nb.sub(u, u0), pu)
        fz = _mod(nb, nb.sub(z, z0), pz)
        du = nb.absf(nb.sub(fu, pu * 0.5))
        dz = nb.sub(fz, sill + wz * 0.5)
        adz = nb.absf(dz)
        fw = g.get("frame_w", frame_w)
        top = g.get("top")

        def shape(grow):
            a = wu * 0.5 + grow
            rect = nb.AND(nb.lt(du, a), nb.lt(adz, wz * 0.5 + grow))
            if not top:
                return rect
            if top == "round":
                rise = wu * 0.5
                R = wu * 0.5 + grow
                cz = nb.sub(dz, wz * 0.5 - rise)
                circ = nb.lt(nb.add(nb.mul(du, du), nb.mul(cz, cz)), R * R)
                return nb.mul(rect, nb.OR(nb.lt(cz, 0.0), circ))
            if top == "seg":
                s = wu * g.get("rise", 0.16)
                R0 = ((wu * 0.5) ** 2 + s * s) / (2 * s)
                cz = nb.sub(dz, wz * 0.5 - R0)
                circ = nb.lt(nb.add(nb.mul(du, du), nb.mul(cz, cz)), (R0 + grow) ** 2)
                return nb.mul(rect, nb.OR(nb.lt(dz, wz * 0.5 - s), circ))
            if top == "pointed":
                spring = wz * 0.5 - 0.866 * wu
                dzs = nb.sub(dz, spring)
                dd = nb.add(du, wu * 0.5)
                circ = nb.lt(nb.add(nb.mul(dd, dd), nb.mul(dzs, dzs)), (wu + grow) ** 2)
                return nb.mul(rect, nb.OR(nb.lt(dzs, 0.0), circ))
            raise ValueError(top)

        win = shape(0.0)
        frm = shape(fw)
        iu = nb.math("FLOOR", nb.math("DIVIDE", nb.sub(u, u0), pu))
        iz = nb.math("FLOOR", nb.math("DIVIDE", nb.sub(z, z0), pz))
        for (si, sj) in g.get("skip", ()):
            keep = nb.NOT(nb.AND(nb.lt(nb.absf(nb.sub(iu, si)), 0.5), nb.lt(nb.absf(nb.sub(iz, sj)), 0.5)))
            win = nb.mul(win, keep)
            frm = nb.mul(frm, keep)
        win = nb.mul(win, rng)
        frm = nb.mul(frm, rng)
        # per-window random numbers
        cmb = nb.node("ShaderNodeCombineXYZ")
        nb.feed(cmb.inputs[0], iu)
        nb.feed(cmb.inputs[1], iz)
        nb.feed(cmb.inputs[2], nb.add(nb.mul(nx, 3.1), nb.add(nb.mul(ny, 7.3), gi * 1.7 + seed)))
        wn = nb.node("ShaderNodeTexWhiteNoise", noise_dimensions="3D")
        nb.links.new(cmb.outputs[0], wn.inputs["Vector"])
        sep = nb.node("ShaderNodeSeparateColor")
        nb.links.new(wn.outputs["Color"], sep.inputs[0])
        r1, r2, r3 = wn.outputs["Value"], sep.outputs[0], sep.outputs[1]
        if g.get("shutters"):
            sw = wu * g.get("shutter_w", 0.5)
            sh = nb.AND(nb.gt(du, wu * 0.5 + fw), nb.lt(du, wu * 0.5 + fw + sw), nb.lt(adz, wz * 0.5), rng)
            if g.get("skip"):
                for (si, sj) in g["skip"]:
                    sh = nb.mul(sh, nb.NOT(nb.AND(nb.lt(nb.absf(nb.sub(iu, si)), 0.5), nb.lt(nb.absf(nb.sub(iz, sj)), 0.5))))
            slat = nb.lt(_mod(nb, z, 0.11), 0.03)
            sc = _lin(g["shutters"])
            apply(sh, nb.mix(nb.mul(slat, 0.5), sc, (sc[0] * 0.55, sc[1] * 0.55, sc[2] * 0.55, 1.0)), 0.6, 0.3)
        apply(frm, g.get("frame", frame), 0.5, 0.35)
        gl = _lin(g.get("glass", glass))
        if kind == "win" and curtains > 0:
            cur = (0.42, 0.42, 0.4, 1.0)
            glc = nb.mix(nb.mul(nb.lt(r3, curtains), 0.22), gl, cur)
        else:
            glc = gl
        apply(win, glc, 0.08 if kind != "door" else 0.5, 0.9 if kind != "door" else 0.3, 0.2 if kind != "door" else 0.0)
        bars = None
        mull = g.get("mull")
        if mull and kind != "door":
            mw = mull.get("w", 0.06)
            nv = mull.get("v", 1)
            for k in range(1, nv + 1):
                pos = abs(-wu * 0.5 + wu * k / (nv + 1))
                b = nb.lt(nb.absf(nb.sub(du, pos)), mw * 0.5)
                bars = b if bars is None else nb.OR(bars, b)
            hs = mull.get("h", 1)
            fr = hs if isinstance(hs, (list, tuple)) else [(k + 1) / (hs + 1) for k in range(hs)]
            zb = nb.add(dz, wz * 0.5)
            for f in fr:
                b = nb.lt(nb.absf(nb.sub(zb, f * wz)), mw * 0.5)
                bars = b if bars is None else nb.OR(bars, b)
            bars = nb.mul(bars, win)
            apply(bars, g.get("mull_color", g.get("frame", frame)), 0.5, 0.35)
        blind = None
        if g.get("blind"):
            cover = nb.mul(nb.mul(r2, r2), g.get("blind_max", 0.8))
            blind = nb.mul(win, nb.gt(dz, nb.sub(wz * 0.5, nb.mul(cover, wz))))
            bc = _lin(g["blind"])
            slat = nb.lt(_mod(nb, z, 0.06), 0.012)
            apply(blind, nb.mix(nb.mul(slat, 0.4), bc, (bc[0] * 0.6, bc[1] * 0.6, bc[2] * 0.6, 1.0)), 0.6, 0.3)
        lit_frac = g.get("lit", lit if kind == "win" else (0.95 if kind == "shop" else 0.0))
        if lit_frac > 0:
            lm = nb.mul(win, nb.lt(r1, lit_frac))
            if bars is not None:
                lm = nb.mul(lm, nb.NOT(bars))
            if blind is not None:
                lm = nb.mul(lm, nb.NOT(blind))
            bright = nb.madd(r1, 0.8, 0.6) if kind == "win" else 1.0
            cols = g.get("color")
            if cols is None:
                cols = LIT if kind == "win" else ("#ffcf8a", "#ffdcaa")
            if isinstance(cols, str):
                cols = (cols,)
            st = g.get("strength", strength if kind == "win" else 1.05)
            ecol = M.emit_col(cols[0], st)
            if len(cols) > 1:
                e2 = M.emit_col(cols[1], st)
                ecol = nb.mix(nb.gt(r2, 0.55), ecol, e2)
            if len(cols) > 2:
                e3 = M.emit_col(cols[2], st)
                ecol = nb.mix(nb.gt(r3, 0.8), ecol, e3)
            term = nb.color_scale(nb.color_scale(ecol, bright), lm)
            emit = term if emit is None else nb.vadd(emit, term)
    for d in decals or []:
        d = dict(d, face={"front": "rear", "back": "front"}.get(d.get("face", "front"), d.get("face")))
        mask = M.decal_mask(nb, d)
        p = M._preset(d.get("mat", "black"))
        apply(mask, p["color"], p.get("rough", 0.5), p.get("spec", 0.4), p.get("metal", 0.0))
        for layer, (ec, s) in (d.get("emit") or {}).items():
            term = nb.color_scale(M.emit_col(ec, s), mask)
            emit = term if emit is None else nb.vadd(emit, term)
    out = M.principled(nb, par["col"], rough=par["rough"], spec=par["spec"], metal=par["metal"])
    return M.finish(m, nb, out, {"lights": emit} if emit is not None else None)


def roofmat(name, color, kind="tiles", rows=0.3, var=0.25, color2=None):
    """Roof covering. kind: tiles (horizontal courses), canal (round Mediterranean tiles: courses +
    ribs down the slope), slate (fine courses, cool), zinc / copper / metal (standing seams down the
    slope), diamond (two-colour diamond pattern, color2), flat (gravel), thatch."""
    m, nb = M.new_material(name)
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    side = nb.gt(nb.absf(nx), nb.absf(ny))
    u = nb.mixf(side, x, y)
    f = nb.ramp(nb.noise(1.3, detail=3.0), [(0.3, (0, 0, 0, 1)), (0.75, (1, 1, 1, 1))])
    c1 = _lin(color)
    col = nb.mix(f, c1, (c1[0] * (1 - var), c1[1] * (1 - var), c1[2] * (1 - var), 1))
    rough, metal = 0.75, 0.0
    if kind in ("tiles", "slate", "canal"):
        r = rows * (0.55 if kind == "slate" else 1.0)
        fz = nb.math("DIVIDE", _mod(nb, z, r), r)
        col = nb.mix(nb.mul(nb.lt(fz, 0.16), 0.55), col, (c1[0] * 0.35, c1[1] * 0.35, c1[2] * 0.35, 1))
        if kind == "canal":
            fu = nb.math("DIVIDE", _mod(nb, u, 0.24), 0.24)
            rib = nb.math("SINE", nb.mul(fu, math.pi))
            col = nb.mix(nb.mul(nb.sub(1.0, rib), 0.55), col, (c1[0] * 0.45, c1[1] * 0.45, c1[2] * 0.45, 1))
        if kind == "slate":
            rough = 0.55
    elif kind in ("zinc", "copper", "metal"):
        seam = nb.lt(_mod(nb, u, 0.55 if kind != "metal" else 0.5), 0.05)
        col = nb.mix(nb.mul(seam, 0.55), col, (c1[0] * 0.6, c1[1] * 0.6, c1[2] * 0.6, 1))
        rough, metal = (0.45, 0.35) if kind == "zinc" else ((0.5, 0.15) if kind == "copper" else (0.45, 0.3))
    elif kind == "diamond":
        k = 0.7
        a = nb.math("FLOOR", nb.math("DIVIDE", nb.add(u, z), k))
        b = nb.math("FLOOR", nb.math("DIVIDE", nb.sub(u, z), k))
        par = _mod(nb, nb.add(a, b), 2.0)
        col = nb.mix(par, col, _lin(color2 or "#d8b43a"))
        fz = nb.math("DIVIDE", _mod(nb, z, 0.22), 0.22)
        col = nb.mix(nb.mul(nb.lt(fz, 0.15), 0.4), col, (0.05, 0.05, 0.05, 1))
        rough = 0.4
    elif kind == "flat":
        g = nb.ramp(nb.noise(18.0, detail=2.0), [(0.3, (0, 0, 0, 1)), (0.7, (1, 1, 1, 1))])
        col = nb.mix(nb.mul(g, 0.5), col, (c1[0] * 0.7, c1[1] * 0.7, c1[2] * 0.7, 1))
        rough = 0.95
    elif kind == "thatch":
        rough = 0.95
    out = M.principled(nb, col, rough=rough, spec=0.35, metal=metal)
    return M.finish(m, nb, out)


def lace_mat(name, color="#1d1f1f", kind="bars", pitch=0.13, bar=0.035, z0=0.0, h=1.0, metal=0.5, pz=None):
    """Wrought-iron railing panel material: opaque where the pattern is, transparent elsewhere (also in
    the light passes, so lit windows glow through). kind: bars | haussmann (bars + band of rings) |
    balusters (round-bellied stone balusters, opaque light colour) | lattice (diagonal mesh)."""
    m, nb = M.new_material(name)
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    side = nb.gt(nb.absf(nx), nb.absf(ny))
    u = nb.mixf(side, x, y)
    zr = nb.sub(z, z0) if pz is None else _mod(nb, nb.sub(z, z0), pz)
    rails = nb.OR(nb.lt(zr, bar * 1.6), nb.gt(zr, h - bar * 1.8))
    fu = _mod(nb, u, pitch)
    if kind == "bars":
        pat = nb.OR(rails, nb.lt(fu, bar))
    elif kind == "haussmann":
        mid = nb.band(zr, h * 0.62, h * 0.86)
        cu = nb.sub(fu, pitch * 0.5)
        cz = nb.sub(zr, h * 0.74)
        rr = nb.math("SQRT", nb.add(nb.mul(cu, cu), nb.mul(cz, cz)))
        ring = nb.mul(nb.lt(nb.absf(nb.sub(rr, pitch * 0.36)), bar * 0.45), mid)
        band = nb.OR(nb.lt(nb.absf(nb.sub(zr, h * 0.6)), bar * 0.5), nb.lt(nb.absf(nb.sub(zr, h * 0.88)), bar * 0.5))
        pat = nb.OR(rails, nb.mul(nb.lt(fu, bar), nb.lt(zr, h * 0.6)), ring, band)
    elif kind == "balusters":
        t = nb.math("DIVIDE", zr, h)
        bell = nb.add(0.18, nb.mul(nb.math("SINE", nb.mul(nb.add(nb.mul(t, 0.8), 0.15), math.pi)), 0.2))
        pat = nb.OR(nb.lt(zr, h * 0.12), nb.gt(zr, h * 0.86),
                    nb.lt(nb.absf(nb.sub(fu, pitch * 0.5)), nb.mul(bell, pitch)))
    elif kind == "lattice":
        a = _mod(nb, nb.add(u, zr), pitch)
        b = _mod(nb, nb.sub(u, zr), pitch)
        pat = nb.OR(rails, nb.lt(a, bar), nb.lt(b, bar))
    else:
        raise ValueError(kind)
    c = _lin(color)
    solid = M.principled(nb, c, rough=0.45 if kind != "balusters" else 0.8, metal=metal if kind != "balusters" else 0.0,
                         spec=0.4)
    tr = nb.node("ShaderNodeBsdfTransparent")
    tr.inputs["Color"].default_value = (1, 1, 1, 1)
    base_mix = nb.node("ShaderNodeMixShader")
    nb.feed(base_mix.inputs[0], pat)
    nb.links.new(tr.outputs[0], base_mix.inputs[1])
    nb.links.new(solid, base_mix.inputs[2])
    grp = nb.node("ShaderNodeGroup")
    grp.node_tree = M.pass_group()
    em = nb.node("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0, 0, 0, 1)
    tr2 = nb.node("ShaderNodeBsdfTransparent")
    tr2.inputs["Color"].default_value = (1, 1, 1, 1)
    light_mix = nb.node("ShaderNodeMixShader")
    nb.feed(light_mix.inputs[0], pat)
    nb.links.new(tr2.outputs[0], light_mix.inputs[1])
    nb.links.new(em.outputs[0], light_mix.inputs[2])
    sw = nb.node("ShaderNodeMixShader")
    nb.feed(sw.inputs[0], nb.NOT(grp.outputs["base"]))
    nb.links.new(base_mix.outputs[0], sw.inputs[1])
    nb.links.new(light_mix.outputs[0], sw.inputs[2])
    out = nb.node("ShaderNodeOutputMaterial")
    nb.links.new(sw.outputs[0], out.inputs["Surface"])
    return m


def lamp_mat(name, color="#fff1c9", strength=8.0, light="#ffd890"):
    return M.basic(name, color, rough=0.3, emit={"lights": (light, strength)})


def basic(name, color, rough=0.6, metal=0.0, **kw):
    return M.basic(name, color, rough=rough, metal=metal, **kw)


# --- geometry helpers ---------------------------------------------------------------------------

def bx(bm, x0, x1, y0, y1, z0, z1, mi=0):
    """Axis-aligned box by bounds into bm."""
    return MU.bm_box(abs(x1 - x0), abs(y1 - y0), abs(z1 - z0), ((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5),
                     bm=bm, mat_index=mi)


def mk(rig, name, bm, mats, bevel=None, smooth=False, shadow=True):
    ob = MU.make(name, bm, mats, parent=rig.root, smooth=smooth)
    if bevel:
        MU.bevel(ob, bevel, 1)
    if not shadow:
        ob.visible_shadow = False
    return ob


def fbox(bm, face, plane, u0, u1, z0, z1, out0, out1, mi=0):
    """Box on a facade: u range, z range, from out0 to out1 metres in front of the face plane."""
    if face in ("front", "chamfer"):
        return bx(bm, u0, u1, plane - out1, plane - out0, z0, z1, mi)
    if face == "left":
        return bx(bm, plane - out1, plane - out0, u0, u1, z0, z1, mi)
    if face == "right":
        return bx(bm, plane + out0, plane + out1, u0, u1, z0, z1, mi)
    if face == "back":
        return bx(bm, u0, u1, plane + out0, plane + out1, z0, z1, mi)
    raise ValueError(face)


def fprism(bm, face, plane, pts, out0, out1, mi=0):
    """2D outline [(u, z)] extruded out of a facade between out0 and out1."""
    if face in ("front", "back"):
        sgn = -1 if face == "front" else 1
        a, b = plane + sgn * out0, plane + sgn * out1
        return MU.prism(pts, abs(b - a), bm=bm, mat_index=mi, plane="XZ", offset=min(a, b))
    sgn = -1 if face == "left" else 1
    a, b = plane + sgn * out0, plane + sgn * out1
    return MU.prism(pts, abs(b - a), bm=bm, mat_index=mi, plane="YZ", offset=min(a, b))


def rows_of(g, rows):
    return [c for c in centres(g) if rows is None or c[3] in rows]


def sills(bm, g, plane, rows=None, h=0.1, out=0.13, ext=0.1, mi=0):
    wu, wz = g["win"]
    for (u, zc, i, j) in rows_of(g, rows):
        fbox(bm, g["face"], plane, u - wu / 2 - ext, u + wu / 2 + ext, zc - wz / 2 - h, zc - wz / 2, 0.0, out, mi)


def lintels(bm, g, plane, rows=None, h=0.2, out=0.1, ext=0.12, gap=0.05, mi=0):
    wu, wz = g["win"]
    for (u, zc, i, j) in rows_of(g, rows):
        z0 = zc + wz / 2 + gap
        fbox(bm, g["face"], plane, u - wu / 2 - ext, u + wu / 2 + ext, z0, z0 + h, 0.0, out, mi)


def surrounds(bm, g, plane, rows=None, w=0.14, out=0.06, mi=0):
    wu, wz = g["win"]
    for (u, zc, i, j) in rows_of(g, rows):
        a, b = zc - wz / 2 - 0.02, zc + wz / 2 + w
        fbox(bm, g["face"], plane, u - wu / 2 - w, u - wu / 2, a, b, 0.0, out, mi)
        fbox(bm, g["face"], plane, u + wu / 2, u + wu / 2 + w, a, b, 0.0, out, mi)
        fbox(bm, g["face"], plane, u - wu / 2 - w, u + wu / 2 + w, zc + wz / 2, b, 0.0, out, mi)


def pediments(bm, g, plane, rows=None, kind="tri", h=0.45, out=0.16, ext=0.18, gap=0.08, t=0.16, alt=False, mi=0):
    """Pediments above windows: tri (triangular), seg (segmental arc), flat (cornice); alt=True
    alternates tri/seg along the row."""
    wu, wz = g["win"]
    for (u, zc, i, j) in rows_of(g, rows):
        k = kind
        if alt:
            k = "tri" if i % 2 == 0 else "seg"
        zb = zc + wz / 2 + gap
        a = wu / 2 + ext
        fbox(bm, g["face"], plane, u - a, u + a, zb, zb + t, 0.0, out + 0.03, mi)
        if k == "tri":
            pts = [(u - a, zb + t), (u + a, zb + t), (u, zb + t + h)]
            fprism(bm, g["face"], plane, pts, 0.0, out, mi)
        elif k == "seg":
            n = 9
            R = (a * a + h * h) / (2 * h)
            cz = zb + t + h - R
            upper = []
            for q in range(n + 1):
                xx = -a + 2 * a * q / n
                upper.append((u + xx, cz + math.sqrt(max(0.0, R * R - xx * xx))))
            lower = [(p[0], max(zb + t, p[1] - t * 1.1)) for p in reversed(upper)]
            fprism(bm, g["face"], plane, upper + lower, 0.0, out, mi)


class Rails:
    """Railing panels with a lace material; one material per railing bottom height so the pattern's
    rails line up with every panel (lace_mat patterns are anchored at z0)."""

    def __init__(self, name, color="#1d2020", kind="bars", pitch=0.13, bar=0.035, h=1.0):
        self.name, self.color, self.kind, self.pitch, self.bar, self.h = name, color, kind, pitch, bar, h
        self.bands = {}

    def add(self, face, plane, u0, u1, zf, out0, out1, h=None):
        key = (round(zf, 3), round(h or self.h, 3))
        bm = self.bands.setdefault(key, bmesh.new())
        fbox(bm, face, plane, u0, u1, zf, zf + (h or self.h), out0, out1)

    def add_box(self, x0, x1, y0, y1, zf, h=None):
        key = (round(zf, 3), round(h or self.h, 3))
        bm = self.bands.setdefault(key, bmesh.new())
        bx(bm, x0, x1, y0, y1, zf, zf + (h or self.h))

    def add_rot(self, cx, cy, length, depth, rot, zf, h=None):
        key = (round(zf, 3), round(h or self.h, 3))
        bm = self.bands.setdefault(key, bmesh.new())
        hh = h or self.h
        obox(bm, (cx, cy, zf + hh / 2), (length, depth, hh), rot)

    def build(self, rig):
        for k, ((z, h), bm) in enumerate(sorted(self.bands.items())):
            mat = lace_mat("%s_%d" % (self.name, k), self.color, self.kind, self.pitch, self.bar, z0=z, h=h)
            mk(rig, "%s_%d" % (self.name, k), bm, mat)


def balconies(bm_slab, rails, g, plane, rows, depth=0.75, ext=0.3, rail_h=1.0, slab=0.16, span=None, mi=0):
    """Balcony slabs (bm_slab) and railing panels (Rails) under windows of the given rows;
    span=(u0, u1) instead of per window = one continuous balcony along the row."""
    wu, wz = g["win"]
    face = g["face"]
    done = set()
    for (u, zc, i, j) in rows_of(g, rows):
        zf = zc - wz / 2 - 0.02
        if span is not None:
            if j in done:
                continue
            done.add(j)
            a, b = span
        else:
            a, b = u - wu / 2 - ext, u + wu / 2 + ext
        fbox(bm_slab, face, plane, a, b, zf - slab, zf, 0.0, depth, mi)
        # railing: front + two ends (thin panels)
        rails.add(face, plane, a, b, zf, depth - 0.04, depth, rail_h)
        rails.add(face, plane, a, a + 0.03, zf, 0.0, depth, rail_h)
        rails.add(face, plane, b - 0.03, b, zf, 0.0, depth, rail_h)


def cornice(bm, x0, x1, y0, y1, z, layers, mi=0):
    """Moulded cornice around a footprint: layers [(height, outset)] stacked upwards from z."""
    for (h, o) in layers:
        bx(bm, x0 - o, x1 + o, y0 - o, y1 + o, z, z + h, mi)
        z += h
    return z


CORNICE = [(0.12, 0.08), (0.1, 0.2), (0.22, 0.38), (0.1, 0.5)]
CORNICE_S = [(0.1, 0.06), (0.12, 0.16), (0.08, 0.24)]
BAND = [(0.18, 0.08)]


def pilasters(bm, face, plane, us, z0, z1, w=0.5, out=0.12, cap=True, mi=0):
    for u in us:
        fbox(bm, face, plane, u - w / 2, u + w / 2, z0, z1, 0.0, out, mi)
        if cap:
            fbox(bm, face, plane, u - w / 2 - 0.06, u + w / 2 + 0.06, z1 - 0.25, z1, 0.0, out + 0.06, mi)
            fbox(bm, face, plane, u - w / 2 - 0.05, u + w / 2 + 0.05, z0, z0 + 0.3, 0.0, out + 0.05, mi)


def smooth_pts(pts, n=5):
    """Catmull-Rom polyline through 2D control points (end points kept)."""
    if len(pts) < 3:
        return list(pts)
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[c]) + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2 +
                                    (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3) for c in (0, 1)))
    out.append(pts[-1])
    return out


def mirror_outline(half, xc, z0):
    """Right half [(dx, dz)] from the right foot (w/2, 0) up to the apex (0, h) -> closed outline
    (counter-clockwise in x/z) in absolute coordinates."""
    right = [(xc + dx, z0 + dz) for (dx, dz) in half]
    left = [(xc - dx, z0 + dz) for (dx, dz) in reversed(half)]
    clean = []
    for p in right + left:
        if not clean or abs(p[0] - clean[-1][0]) > 1e-5 or abs(p[1] - clean[-1][1]) > 1e-5:
            clean.append(p)
    if abs(clean[0][0] - clean[-1][0]) < 1e-5 and abs(clean[0][1] - clean[-1][1]) < 1e-5:
        clean.pop()
    return clean


def gable_half(kind, w, h):
    """Right half outline of a front gable of width w and height h (above the eave line)."""
    a = w / 2
    if kind == "tri":
        return [(a, 0.0), (0.0, h)]
    if kind == "step":
        n = 5
        pts = [(a, 0.0)]
        for k in range(n):
            x = a - a * k / (n + 0.8)
            z = h * (k + 1) / (n + 1)
            pts += [(x, z), (a - a * (k + 1) / (n + 0.8), z)]
        pts += [(a - a * n / (n + 0.8), h), (0.0, h)]
        return pts
    if kind == "bell":
        c = smooth_pts([(a, 0.0), (a, 0.35 * 1), (a * 0.82, h * 0.22), (a * 0.6, h * 0.36), (a * 0.62, h * 0.55),
                        (a * 0.55, h * 0.75), (a * 0.32, h * 0.92), (0.0, h)], 4)
        return c
    if kind == "neck":
        sh = h * 0.32
        claw = smooth_pts([(a, 0.0), (a * 0.98, sh * 0.35), (a * 0.75, sh * 0.82), (a * 0.42, sh)], 4)
        return claw + [(a * 0.42, h * 0.78), (a * 0.5, h * 0.78), (a * 0.5, h * 0.82), (0.0, h)]
    if kind == "spout":
        return [(a, 0.0), (a, 0.3), (a * 0.36, h * 0.8), (a * 0.36, h * 0.93), (0.0, h)]
    if kind == "volute":
        return smooth_pts([(a, 0.0), (a * 0.95, h * 0.12), (a * 0.62, h * 0.3), (a * 0.5, h * 0.48),
                           (a * 0.44, h * 0.66), (a * 0.36, h * 0.82), (a * 0.16, h * 0.96), (0.0, h)], 4)
    if kind == "round":
        n = 10
        return [(a * math.cos(math.pi * 0.5 * k / n), h * math.sin(math.pi * 0.5 * k / n)) for k in range(n + 1)]
    if kind == "cornice":
        return [(a, 0.0), (a, h), (0.0, h)]
    raise ValueError(kind)


def front_gable(rig, name, kind, xc, w, z0, h, mat, y0=0.0, depth=0.45, cap_mat=None, back=None, face="front"):
    """Gable wall from an outline (kind, see gable_half) extruded from the plane y0 backwards (face
    'front': outline in x/z centred at xc) or from the plane x = y0 inwards (face 'left': outline in
    y/z centred at y = xc). cap_mat: coping on the outline steps/edges."""
    pl = "XZ" if face == "front" else "YZ"
    pts = mirror_outline(gable_half(kind, w, h), xc, z0)
    bm = MU.prism(pts, depth, plane=pl, offset=y0)
    ob = mk(rig, name, bm, mat)
    if back is not None:
        bm = MU.prism(mirror_outline(gable_half("tri", w, back[1]), xc, z0), depth, plane=pl, offset=back[0])
        mk(rig, name + "_b", bm, mat)

    def box_(bm_, ua, ub, za, zb):
        if face == "front":
            bx(bm_, ua, ub, y0 - 0.06, y0 + depth + 0.06, za, zb)
        else:
            bx(bm_, y0 - 0.06, y0 + depth + 0.06, ua, ub, za, zb)

    if cap_mat is not None:
        bm = bmesh.new()
        half = gable_half(kind, w, h)
        if kind == "step":
            for k in range(1, len(half) - 1, 2):
                (xa, za), (xb, zb) = half[k], half[k + 1]
                for s in (-1, 1):
                    xs = sorted((xc + s * xa, xc + s * xb))
                    box_(bm, xs[0] - 0.06, xs[1] + 0.06, z0 + za, z0 + za + 0.12)
        else:
            # thin coping strip following the outline (outward normal of the right half, mirrored)
            for s in (-1, 1):
                for (p, q) in zip(half[:-1], half[1:]):
                    dx, dz = q[0] - p[0], q[1] - p[1]
                    ln = math.hypot(dx, dz)
                    if ln < 1e-4:
                        continue
                    nx_, nz_ = dz / ln, -dx / ln
                    ua, ub = xc + s * (p[0] + nx_ * 0.05), xc + s * (q[0] + nx_ * 0.05)
                    za, zb = z0 + p[1] + nz_ * 0.05, z0 + q[1] + nz_ * 0.05
                    if face == "front":
                        a, b = Vector((ua, y0 + depth * 0.5, za)), Vector((ub, y0 + depth * 0.5, zb))
                        MU.bm_beam(a, b, 0.12, depth + 0.1, bm=bm, up=(0, 1, 0))
                    else:
                        a, b = Vector((y0 + depth * 0.5, ua, za)), Vector((y0 + depth * 0.5, ub, zb))
                        MU.bm_beam(a, b, depth + 0.1, 0.12, bm=bm, up=(1, 0, 0))
        mk(rig, name + "_cap", bm, cap_mat)
    return ob


def gable_ends(rig, name, x0, x1, y0, y1, z_eave, z_ridge, mat, axis="x", depth=0.3):
    """Triangular gable walls closing a saddle roof (axis x: at x0 and x1; axis y: at y0 and y1)."""
    if axis == "x":
        yc, w = (y0 + y1) / 2, y1 - y0
        front_gable(rig, name + "_l", "tri", yc, w, z_eave, z_ridge - z_eave, mat, y0=x0, depth=depth, face="left")
        front_gable(rig, name + "_r", "tri", yc, w, z_eave, z_ridge - z_eave, mat, y0=x1 - depth, depth=depth,
                    face="left")
    else:
        xc, w = (x0 + x1) / 2, x1 - x0
        front_gable(rig, name + "_f", "tri", xc, w, z_eave, z_ridge - z_eave, mat, y0=y0, depth=depth)
        front_gable(rig, name + "_b", "tri", xc, w, z_eave, z_ridge - z_eave, mat, y0=y1 - depth, depth=depth)


def offset_poly(pts, d):
    """Convex polygon [(x, y)] (counter-clockwise) offset outwards by d."""
    n = len(pts)
    lines = []
    for i in range(n):
        a, b = Vector(pts[i]), Vector(pts[(i + 1) % n])
        t = (b - a).normalized()
        nrm = Vector((t.y, -t.x))
        lines.append((a + nrm * d, t))
    out = []
    for i in range(n):
        (p1, t1), (p2, t2) = lines[i - 1], lines[i]
        den = t1.x * t2.y - t1.y * t2.x
        if abs(den) < 1e-9:
            out.append((p2.x, p2.y))
            continue
        s = ((p2.x - p1.x) * t2.y - (p2.y - p1.y) * t2.x) / den
        q = p1 + t1 * s
        out.append((q.x, q.y))
    return out


def cornice_poly(bm, pts, z, layers, mi=0):
    for (h, o) in layers:
        poly_prism_z(bm, offset_poly(pts, o), z, z + h, mi)
        z += h
    return z


def chamfer_fp(x0, x1, y0, y1, c):
    """Footprint with the front-left corner cut at 45 degrees (counter-clockwise from above)."""
    return [(x0 + c, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0 + c)]


def ring_obj(rig, name, pts, z0, z1, mat, bevel=None):
    bm = bmesh.new()
    poly_prism_z(bm, pts, z0, z1)
    return mk(rig, name, bm, mat, bevel=bevel)


def turret(rig, name, cx, cy, r, z0, z1, wall, roof, kind="cone", roof_h=5.0, segs=8, corbel=1.2, win=None,
           seed=1, finial="#c9a43a", lit=0.5):
    """Corner turret: octagonal shaft on a corbel, roof cone | helm (steep) | dome | onion, finial;
    win = (w, h, [z centres]) small windows on the shaft faces."""
    bm = MU.bm_lathe([(0.0, z0 - corbel), (r * 0.25, z0 - corbel), (r, z0), (r, z1), (0.0, z1)], segs=segs,
                     center=(cx, cy, 0.0))
    mk(rig, name + "_shaft", bm, wall)
    rb = r + 0.25
    if kind in ("cone", "helm"):
        prof = [(0.0, z1), (rb, z1), (0.0, z1 + roof_h)]
    elif kind == "dome":
        prof = [(0.0, z1)] + dome_prof(rb, roof_h, base=z1) + [(0.0, z1 + roof_h)]
    else:
        prof = [(0.0, z1)] + [(rr, z1 + zz) for (rr, zz) in onion(roof_h, rb * 1.1)]
    bm = MU.bm_lathe(prof, segs=segs if kind in ("cone", "helm") else 20, center=(cx, cy, 0.0))
    mk(rig, name + "_roof", bm, roof, smooth=kind not in ("cone", "helm"))
    bm = bmesh.new()
    zt = z1 + roof_h + (0.25 if kind == "onion" else 0.0)
    MU.bm_cyl(0.05, 0.05, 1.6, center=(cx, cy, zt + 0.6), segs=6, bm=bm)
    MU.bm_sphere(0.16, center=(cx, cy, zt + 0.35), subdiv=1, bm=bm)
    mk(rig, name + "_fin", bm, basic(name + "_finm", finial, rough=0.3, metal=0.9))
    if win:
        ww, wh, zs = win
        rng = random.Random(seed)
        bg, bl = bmesh.new(), bmesh.new()
        for k in range(segs):
            a = 2 * math.pi * (k + 0.5) / segs
            if math.sin(a) > 0.35:      # faces pointing away (+y) are never seen
                continue
            for zc in zs:
                c = (cx + math.cos(a) * (r * math.cos(math.pi / segs) + 0.02), cy + math.sin(a) * (r * math.cos(math.pi / segs) + 0.02), zc)
                obox(bl if rng.random() < lit else bg, c, (ww, 0.08, wh), math.degrees(a) + 90.0)
        for b_, mn, em in ((bg, "_g", None), (bl, "_l", {"lights": (WARM, 1.4)})):
            if len(b_.verts):
                mk(rig, name + mn, b_, M.basic(name + mn + "m", "#2a343d", rough=0.08, spec=0.9, emit=em))
            else:
                b_.free()


def statue(bm, x, y, z, h=1.8):
    """Simple stone figure on a pedestal (attic statues)."""
    bx(bm, x - 0.35, x + 0.35, y - 0.35, y + 0.35, z, z + 0.7)
    MU.bm_cyl(0.26, 0.2, h * 0.62, center=(x, y, z + 0.7 + h * 0.31), segs=8, bm=bm)
    MU.bm_sphere(0.15, center=(x, y, z + 0.7 + h * 0.62 + 0.15), subdiv=1, bm=bm)
    MU.bm_beam((x + 0.15, y, z + 0.7 + h * 0.5), (x + 0.42, y - 0.1, z + 0.7 + h * 0.75), 0.09, bm=bm)


def cross(bm, x, y, z, h=1.6):
    MU.bm_beam((x, y, z), (x, y, z + h), 0.09, bm=bm)
    MU.bm_beam((x - h * 0.28, y, z + h * 0.68), (x + h * 0.28, y, z + h * 0.68), 0.08, bm=bm)


def quoins(bm, face, plane, u, z0, z1, h=0.5, w0=0.9, w1=0.55, out=0.05, mi=0):
    """Alternating corner stones up a building edge at u (extending into +u)."""
    z = z0
    k = 0
    while z + h <= z1 + 1e-6:
        w = w0 if k % 2 == 0 else w1
        fbox(bm, face, plane, u, u + w, z + 0.03, z + h - 0.03, 0.0, out, mi)
        z += h
        k += 1


def saddle(rig, name, x0, x1, y0, y1, z_eave, z_ridge, mat, axis="y", over_side=0.35, over_end=0.0, thick=0.16,
           over_end0=None):
    """Saddle roof over the box x0..x1 / y0..y1: ridge along `axis`; eaves overhang over_side, gable ends
    over_end (over_end0 for the y0 / x0 end if different)."""
    oe0 = over_end if over_end0 is None else over_end0
    bm = bmesh.new()
    if axis == "y":
        hw = (x1 - x0) / 2
        xc = (x0 + x1) / 2
        drop = (z_ridge - z_eave) * over_side / hw
        e = z_eave - drop
        ya, yb = y0 - oe0, y1 + over_end
        v = [bm.verts.new(p) for p in [(x0 - over_side, ya, e), (x1 + over_side, ya, e), (x1 + over_side, yb, e),
                                         (x0 - over_side, yb, e), (xc, ya, z_ridge), (xc, yb, z_ridge)]]
        bm.faces.new((v[1], v[2], v[5], v[4]))
        bm.faces.new((v[3], v[0], v[4], v[5]))
    else:
        hd = (y1 - y0) / 2
        yc = (y0 + y1) / 2
        drop = (z_ridge - z_eave) * over_side / hd
        e = z_eave - drop
        xa, xb = x0 - oe0, x1 + over_end
        v = [bm.verts.new(p) for p in [(xa, y0 - over_side, e), (xb, y0 - over_side, e), (xb, y1 + over_side, e),
                                         (xa, y1 + over_side, e), (xa, yc, z_ridge), (xb, yc, z_ridge)]]
        bm.faces.new((v[0], v[1], v[5], v[4]))
        bm.faces.new((v[2], v[3], v[4], v[5]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    ob = mk(rig, name, bm, mat)
    if thick:
        MU.solidify(ob, thick, offset=-1.0)
    return ob


def hip(rig, name, x0, x1, y0, y1, z_eave, z_ridge, mat, over=0.4, ridge=None, thick=0.16):
    """Hip roof (all four sides sloped); ridge length from the pitch of the shorter side unless given
    (0 = pyramid)."""
    xa, xb, ya, yb = x0 - over, x1 + over, y0 - over, y1 + over
    w, d = xb - xa, yb - ya
    h = z_ridge - z_eave
    drop = h * over / (min(x1 - x0, y1 - y0) / 2)
    e = z_eave - drop
    hh = z_ridge - e
    bm = bmesh.new()
    xc, yc = (xa + xb) / 2, (ya + yb) / 2
    if w >= d:
        r = (w - d) / 2 if ridge is None else ridge / 2
        top = [(xc - r, yc), (xc + r, yc)]
    else:
        r = (d - w) / 2 if ridge is None else ridge / 2
        top = [(xc, yc - r), (xc, yc + r)]
    v = [bm.verts.new(p) for p in [(xa, ya, e), (xb, ya, e), (xb, yb, e), (xa, yb, e)]]
    if r < 1e-3:
        t = bm.verts.new((xc, yc, e + hh))
        for i in range(4):
            bm.faces.new((v[i], v[(i + 1) % 4], t))
    else:
        t0 = bm.verts.new((top[0][0], top[0][1], e + hh))
        t1 = bm.verts.new((top[1][0], top[1][1], e + hh))
        if w >= d:
            bm.faces.new((v[0], v[1], t1, t0))
            bm.faces.new((v[1], v[2], t1))
            bm.faces.new((v[2], v[3], t0, t1))
            bm.faces.new((v[3], v[0], t0))
        else:
            bm.faces.new((v[0], v[1], t0))
            bm.faces.new((v[1], v[2], t1, t0))
            bm.faces.new((v[2], v[3], t1))
            bm.faces.new((v[3], v[0], t0, t1))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    ob = mk(rig, name, bm, mat)
    if thick:
        MU.solidify(ob, thick, offset=-1.0)
    return ob


def mansard(rig, name, x0, x1, y0, y1, z, h1, in1, h2, mat1, mat2=None, over=0.25, flat_top=False):
    """Mansard roof: steep lower part (rise h1, inset in1) + low hip on top (rise h2)."""
    xa, xb, ya, yb = x0 - over, x1 + over, y0 - over, y1 + over
    r0 = [(xa, ya, z), (xb, ya, z), (xb, yb, z), (xa, yb, z)]
    r1 = [(xa + in1, ya + in1, z + h1), (xb - in1, ya + in1, z + h1), (xb - in1, yb - in1, z + h1), (xa + in1, yb - in1, z + h1)]
    bm = MU.loft([r0, r1], cap0=False, cap1=flat_top)
    for f in bm.faces:
        if f.normal.z < -0.01:
            f.normal_flip()
    mk(rig, name + "_low", bm, mat1)
    if not flat_top:
        hip(rig, name + "_top", xa + in1, xb - in1, ya + in1, yb - in1, z + h1, z + h1 + h2, mat2 or mat1,
            over=0.05, thick=0.0)
    return z + h1


def mansard_poly(rig, name, pts, z, h1, in1, h2, mat1, mat2, over=0.2):
    """Mansard over a convex footprint polygon: steep part (rise h1, inset in1), then a low slope (rise
    h2) to a flat top inset 3 m further."""
    r0 = [(q[0], q[1], z) for q in offset_poly(pts, over)]
    r1 = [(q[0], q[1], z + h1) for q in offset_poly(pts, over - in1)]
    r2 = [(q[0], q[1], z + h1 + h2) for q in offset_poly(pts, over - in1 - 3.0)]
    for (ra, rb, cap, mat, nm) in ((r0, r1, False, mat1, "_low"), (r1, r2, True, mat2, "_top")):
        bm = MU.loft([ra, rb], cap0=False, cap1=cap)
        for f in bm.faces:
            if f.normal.z < -0.01:
                f.normal_flip()
        mk(rig, name + nm, bm, mat)
    return z + h1


def dormers(rig, name, xs, y_eave, z_eave, pitch_deg, w, h, wall, roof, kind="gable", z_up=0.5, glass_seed=1,
            lit=0.5, face="front", frame="#efece4"):
    """Dormers on a roof slope that rises from the eave line (y_eave, z_eave) backwards with pitch_deg
    (face 'front'); xs = dormer centres. face 'left': the slope rises from the eave line x = y_eave
    towards +x and xs are y positions. kind: gable | flat | seg | hip."""
    tp = math.tan(math.radians(pitch_deg))
    zb = z_eave + z_up
    yf = y_eave + z_up / tp + 0.12
    depth = (h + 0.8) / tp + 0.6
    rng = random.Random(glass_seed)
    bw, br, bg, bl, bf = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for xc in xs:
        bx(bw, xc - w / 2, xc + w / 2, yf, yf + depth, zb - 0.6, zb + h)
        gw, gh = w * 0.62, h * 0.66
        target = bl if rng.random() < lit else bg
        bx(target, xc - gw / 2, xc + gw / 2, yf - 0.03, yf + 0.05, zb + h * 0.12, zb + h * 0.12 + gh)
        bx(bf, xc - gw / 2 - 0.08, xc + gw / 2 + 0.08, yf - 0.02, yf + 0.04, zb + h * 0.12 - 0.08, zb + h * 0.12 + gh + 0.08)
        if kind == "gable":
            rh = w * 0.42
            pts = [(xc - w / 2 - 0.12, zb + h), (xc + w / 2 + 0.12, zb + h), (xc, zb + h + rh)]
            MU.prism(pts, depth + 0.15, bm=br, plane="XZ", offset=yf - 0.15)
        elif kind == "seg":
            pts = [(xc - w / 2 - 0.12, zb + h)]
            for q in range(9):
                t = q / 8.0
                pts.append((xc + (t - 0.5) * (w + 0.24), zb + h + math.sin(math.pi * t) * w * 0.25))
            pts.append((xc + w / 2 + 0.12, zb + h))
            pts = pts[1:]
            MU.prism(pts, depth + 0.15, bm=br, plane="XZ", offset=yf - 0.15)
        elif kind == "hip":
            bx(br, xc - w / 2 - 0.1, xc + w / 2 + 0.1, yf - 0.12, yf + depth, zb + h, zb + h + 0.15)
            MU.prism([(xc - w / 2 - 0.1, zb + h + 0.15), (xc + w / 2 + 0.1, zb + h + 0.15), (xc, zb + h + w * 0.35)],
                     depth + 0.12, bm=br, plane="XZ", offset=yf - 0.12)
        else:
            bx(br, xc - w / 2 - 0.12, xc + w / 2 + 0.12, yf - 0.18, yf + depth, zb + h, zb + h + 0.16)
    if face == "left":
        for b_ in (bw, br, bg, bl, bf):
            for v in b_.verts:
                v.co.x, v.co.y = v.co.y, v.co.x
            bmesh.ops.reverse_faces(b_, faces=list(b_.faces))
    mk(rig, name + "_w", bw, wall)
    mk(rig, name + "_r", br, roof)
    mk(rig, name + "_f", bf, M.basic(name + "_fm", frame, rough=0.5))
    gm = M.basic(name + "_glass", "#2a343d", rough=0.08, spec=0.9)
    lm = M.basic(name + "_lit", "#2a343d", rough=0.08, spec=0.9, emit={"lights": (WARM, 1.4)})
    if len(bg.verts):
        mk(rig, name + "_g", bg, gm)
    else:
        bg.free()
    if len(bl.verts):
        mk(rig, name + "_l", bl, lm)
    else:
        bl.free()


def chimneys(rig, name, pts, z0, z1, mat, w=0.6, d=0.6, pots=None, cap=True):
    bm = bmesh.new()
    bp = bmesh.new()
    for (x, y) in pts:
        bx(bm, x - w / 2, x + w / 2, y - d / 2, y + d / 2, z0, z1)
        if cap:
            bx(bm, x - w / 2 - 0.06, x + w / 2 + 0.06, y - d / 2 - 0.06, y + d / 2 + 0.06, z1, z1 + 0.12)
        if pots:
            n = max(1, int(w / 0.3))
            for k in range(n):
                px = x - w / 2 + (k + 0.5) * w / n
                MU.bm_cyl(0.09, 0.07, 0.5, center=(px, y, z1 + 0.37), segs=8, bm=bp)
    mk(rig, name, bm, mat)
    if pots:
        mk(rig, name + "_pots", bp, M.basic(name + "_pm", pots, rough=0.7))
    else:
        bp.free()


def obox(bm, center, size, rot_z, mi=0):
    """Box rotated about Z (degrees)."""
    res = bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(Vector(center)) @ Matrix.Rotation(math.radians(rot_z), 4, "Z") @ Matrix.Diagonal(
        (size[0], size[1], size[2], 1.0))
    bmesh.ops.transform(bm, matrix=m, verts=res["verts"])
    for v in res["verts"]:
        for f in v.link_faces:
            f.material_index = mi
    return bm


def poly_prism_z(bm, pts, z0, z1, mi=0):
    """Vertical prism from a footprint polygon [(x, y)] (counter-clockwise seen from above)."""
    a = [bm.verts.new((p[0], p[1], z0)) for p in pts]
    b = [bm.verts.new((p[0], p[1], z1)) for p in pts]
    fs = [bm.faces.new(list(reversed(a))), bm.faces.new(b)]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        fs.append(bm.faces.new((a[i], a[j], b[j], b[i])))
    for f in fs:
        f.material_index = mi
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    return bm


def lathe(rig, name, prof, center, mat, segs=24, smooth=True):
    bm = MU.bm_lathe(prof, segs=segs, center=center)
    return mk(rig, name, bm, mat, smooth=smooth)


def onion(h, r, neck=0.35, tip=0.25, n=14):
    """Profile [(r, z)] of an onion dome of height h and max radius r (z from 0)."""
    pts = []
    for k in range(n + 1):
        t = k / n
        z = t * h
        if t < 0.45:
            rr = r * (neck + (1 - neck) * math.sin(math.pi * 0.5 * t / 0.45) ** 0.8)
        else:
            q = (t - 0.45) / 0.55
            rr = r * (1 - q) ** 1.4 * (1 + 0.25 * math.sin(math.pi * q))
        pts.append((max(rr, 0.0), z))
    pts[-1] = (0.0, h + tip)
    return [(r * neck, 0.0)] + pts[1:]


def dome_prof(r, h, n=12, base=0.0):
    return [(r * math.cos(math.pi * 0.5 * k / n), base + h * math.sin(math.pi * 0.5 * k / n)) for k in range(n + 1)]


# --- garden, plants, fences ---------------------------------------------------------------------

def tree(rig, name, x, y, h, r, seed, kind="round", c1="#3f6b28", c2="#62903a", bark_c=("#5a4632", "#3a2c20")):
    """Garden tree: round (fruit / linden), birch, thuja (narrow conifer), conifer."""
    b = bark(name + "_bark", bark_c[0], bark_c[1])
    if kind == "thuja":
        lv = leaves(name + "_lv", "#24451f", "#355a2a", scale=2.4, bump=0.5)
        crown(rig, name + "_c", (x, y, h * 0.5), r * 0.8, r * 0.8, h * 0.47, int(18 + h * 6), r * 0.32, r * 0.45, lv,
              seed, disp=0.08, shell=0.2)
        return
    lv = leaves(name + "_lv", c1, c2)
    th = h * (0.42 if kind == "round" else 0.55)
    trunk(rig, name + "_t", [(x, y, 0.0), (x + 0.05, y, th * 0.6), (x, y + 0.04, th + r * 0.4)],
          [0.09 + h * 0.012, 0.07 + h * 0.008, 0.04], b)
    if kind == "birch":
        crown(rig, name + "_c", (x, y, h - r * 1.3), r * 0.8, r * 0.8, r * 1.35, 20, r * 0.25, r * 0.45, lv, seed,
              disp=0.18, shell=0.7)
    else:
        crown(rig, name + "_c", (x, y, h - r), r, r * 0.95, r * 0.9, int(14 + r * 6), r * 0.3, r * 0.55, lv, seed,
              disp=0.22, shell=0.6, flat_bottom=-r * 0.6)


def hedge(rig, name, x0, x1, y0, y1, h, seed, c1="#3a6125", c2="#557f31"):
    lv = leaves(name + "_lv", c1, c2, scale=2.5)
    a, b = max(0.3, abs(x1 - x0) / 2), max(0.3, abs(y1 - y0) / 2)
    n = int(6 + (a + b) * 4)
    crown(rig, name, ((x0 + x1) / 2, (y0 + y1) / 2, h * 0.5), a, b, h * 0.5, n, min(h, 0.9) * 0.45, min(h, 0.9) * 0.62,
          lv, seed, disp=0.12, shell=0.3, flat_bottom=-h * 0.45)


def flowers(rig, name, pts, colors=("#d6262b", "#e2477a", "#f2f2f0"), r=0.16, seed=3):
    """Small flower blobs (window boxes, beds)."""
    rng = random.Random(seed)
    bms = [bmesh.new() for _ in colors]
    for (x, y, z) in pts:
        k = rng.randrange(len(colors))
        MU.bm_sphere(r * rng.uniform(0.8, 1.2), center=(x, y, z), subdiv=1, bm=bms[k])
    for k, c in enumerate(colors):
        mk(rig, "%s_%d" % (name, k), bms[k], M.basic("%s_m%d" % (name, k), c, rough=0.7))


def fence(rig, name, segs, h=1.2, kind="picket", color="#f1efe8", post_color=None, post_w=0.3, pitch=0.13):
    """Fence along line segments [((x0, y0), (x1, y1))]: picket (wooden slats, at least 20 cm pitch so
    the gaps stay visible), boards (horizontal), metal (thin bars, dark), panel (brick/plaster posts +
    metal bars), wall (low plastered wall)."""
    if kind == "picket":
        pitch = max(pitch, 0.2)
    bm = bmesh.new()
    bp = bmesh.new()
    for (a, b) in segs:
        a, b = Vector((a[0], a[1], 0)), Vector((b[0], b[1], 0))
        d = b - a
        L = d.length
        if L < 1e-3:
            continue
        t = d.normalized()
        rot = math.degrees(math.atan2(t.y, t.x))
        if kind == "wall":
            c = (a + b) * 0.5
            obox(bm, (c.x, c.y, h / 2), (L, 0.25, h), rot)
            obox(bp, (c.x, c.y, h + 0.04), (L + 0.06, 0.32, 0.08), rot)
            continue
        npost = max(2, int(L / 2.4) + 1)
        for k in range(npost):
            p = a + d * (k / (npost - 1))
            pw = post_w if kind in ("panel", "boards") else 0.1
            obox(bp, (p.x, p.y, (h + 0.12) / 2), (pw, pw, h + 0.12), rot)
        if kind == "panel":
            obox(bp, ((a.x + b.x) / 2, (a.y + b.y) / 2, 0.15), (L, 0.22, 0.3), rot)
        if kind in ("picket", "metal", "panel"):
            n = int(L / pitch)
            for k in range(n):
                p = a + d * ((k + 0.5) / n)
                bw = 0.08 if kind == "picket" else 0.03
                z0 = 0.3 if kind == "panel" else 0.06
                obox(bm, (p.x, p.y, (z0 + h) / 2), (bw, 0.025, h - z0 - (0.0 if kind != "picket" else 0.04)), rot)
            for zz in ((0.3, h * 0.82) if kind == "picket" else (0.35 if kind == "panel" else 0.1, h - 0.06)):
                c = (a + b) * 0.5
                obox(bm, (c.x, c.y, zz), (L, 0.04, 0.06), rot)
        elif kind == "boards":
            nb_ = int(h / 0.18)
            c = (a + b) * 0.5
            for k in range(nb_):
                obox(bm, (c.x, c.y, 0.12 + k * 0.18), (L, 0.04, 0.14), rot)
    mk(rig, name, bm, M.basic(name + "_m", color, rough=0.55 if kind in ("metal", "panel") else 0.7,
                               metal=0.4 if kind in ("metal", "panel") else 0.0))
    mk(rig, name + "_p", bp, M.basic(name + "_pm", post_color or color, rough=0.75))


def flat_parapet(rig, name, x0, x1, y0, y1, z, mat, h=0.6, roof_color="#6f6d68", inset=0.25):
    bm = bmesh.new()
    t = inset
    bx(bm, x0, x1, y0, y0 + t, z, z + h)
    bx(bm, x0, x1, y1 - t, y1, z, z + h)
    bx(bm, x0, x0 + t, y0, y1, z, z + h)
    bx(bm, x1 - t, x1, y0, y1, z, z + h)
    mk(rig, name, bm, mat)
    bm = bmesh.new()
    bx(bm, x0 + t, x1 - t, y0 + t, y1 - t, z, z + 0.08)
    mk(rig, name + "_roof", bm, roofmat(name + "_rm", roof_color, "flat"))


def glass_boxes(rig, name, boxes, lit=0.5, seed=1, color=WARM, strength=1.4, glass="#2a343d"):
    """Small glazed boxes (dormer windows, oriels...) randomly lit."""
    rng = random.Random(seed)
    bg, bl = bmesh.new(), bmesh.new()
    for b in boxes:
        bx(bl if rng.random() < lit else bg, *b)
    if len(bg.verts):
        mk(rig, name + "_g", bg, M.basic(name + "_gm", glass, rough=0.08, spec=0.9))
    else:
        bg.free()
    if len(bl.verts):
        mk(rig, name + "_l", bl, M.basic(name + "_lm", glass, rough=0.08, spec=0.9, emit={"lights": (color, strength)}))
    else:
        bl.free()


def wall_lamp(rig, name, pts, strength=6.0):
    bm = bmesh.new()
    for (x, y, z) in pts:
        bx(bm, x - 0.12, x + 0.12, y - 0.3, y, z - 0.16, z + 0.16)
    mk(rig, name, bm, lamp_mat(name + "_m", strength=strength))


def awning(rig, name, x0, x1, y, z, depth, drop, c1, c2="#f1ece2", stripe=0.5):
    """Striped awning (c2=None: plain) sloping from the wall at height z out by depth, with a valance."""
    m, nb = M.new_material(name)
    x = nb.coords()[0]
    s = nb.lt(_mod(nb, x, stripe * 2), stripe)
    col = nb.mix(s, _lin(c1), _lin(c2)) if c2 else _lin(c1)
    mat = M.finish(m, nb, M.principled(nb, col, rough=0.8, spec=0.3, sheen=0.3))
    bm = bmesh.new()
    v = [bm.verts.new(q) for q in [(x0, y, z), (x1, y, z), (x1, y - depth, z - drop), (x0, y - depth, z - drop)]]
    bm.faces.new(v)
    # valance
    v2 = [bm.verts.new(q) for q in [(x0, y - depth, z - drop), (x1, y - depth, z - drop), (x1, y - depth - 0.01, z - drop - 0.3),
                                      (x0, y - depth - 0.01, z - drop - 0.3)]]
    bm.faces.new(v2)
    ob = mk(rig, name, bm, mat)
    MU.solidify(ob, 0.04)
    return ob


def info(w, h, d):
    return dict(object=obj_size(w, h, d))


# =================================================================================================
# shared: narrow town house with a front gable
# =================================================================================================

def gable_house(rig, name, xc, w, d, zt, gable, gh, surf, grids, trim="#efece4", roof_c="#7d3226", roof_kind="tiles",
                pitch=52.0, cap=True, y0=0.0, seed=0, frame="#efece4", zones=(), lit=0.45, gdepth=0.5, decals=None):
    """Town house with its gable to the street: body x0..x1 / y0..d up to the eave zt, front gable of
    kind `gable` and height gh (coping in `trim`), saddle roof along y below the gable top."""
    x0, x1 = xc - w / 2, xc + w / 2
    wall = wallmat(name + "_wall", surf, grids, zones=zones, frame=frame, seed=seed, lit=lit, decals=decals)
    bm = bmesh.new()
    bx(bm, x0, x1, y0, d, 0.0, zt)
    mk(rig, name + "_body", bm, wall)
    capm = basic(name + "_capm", trim, rough=0.6) if cap else None
    front_gable(rig, name + "_gable", gable, xc, w, zt, gh, wall, y0=y0, depth=gdepth, cap_mat=capm)
    zr = zt + min(gh - 0.3, (w / 2) * math.tan(math.radians(pitch)))
    saddle(rig, name + "_roof", x0 + 0.02, x1 - 0.02, y0 + gdepth, d, zt, zr,
           roofmat(name + "_rm", roof_c, roof_kind, rows=0.28), axis="y", over_side=0.0, over_end=0.0)
    front_gable(rig, name + "_bg", "tri", xc, w, zt, zr - zt, wall, y0=d - 0.3, depth=0.3)
    return wall, capm, zr


# =================================================================================================
# hanse: brick gable houses, Kontorhaus, Speicher (warehouse), harbour crane
# =================================================================================================

def hanse_gabled(rig, p):
    """Three Hanseatic merchant houses: Gothic step gable with blind niches (dark red brick), baroque
    volute gable (plastered pale yellow), pointed gable with lancet windows (orange-red brick)."""
    D = 16.0
    fr = dict(frame="#efe9de", mull=dict(v=1, h=[0.55], w=0.06))
    # A: step gable
    brA = "#7a3324"
    xa, wa, ta = -8.0, 8.0, 10.6
    gA = [grid("front", xa - 3.6, 3, 2.4, 4.0, 2, 3.3, (1.1, 1.9), sill=0.7, top="seg", **fr),
          grid("front", xa - 3.6, 3, 2.4, 0.0, 1, 4.0, (1.1, 1.9), sill=1.2, top="seg", skip=[(1, 0)], **fr),
          grid("front", xa - 1.2, 1, 2.4, 0.0, 1, 3.7, (1.9, 3.2), sill=0.0, top="round", kind="door", glass="#3b2a20",
               frame="#e9e2d4"),
          grid("front", xa - 0.5, 1, 1.0, ta + 0.5, 1, 1.9, (0.85, 1.5), sill=0.2, top="seg", **fr),
          grid("front", xa - 0.5, 1, 1.0, ta + 2.7, 1, 2.0, (0.8, 1.7), sill=0.1, kind="door", glass="#2f4a3a",
               frame="#e9e2d4"),
          grid("front", xa - 2.4, 2, 2.4, ta + 0.3, 1, 3.4, (0.55, 3.0), sill=0.2, top="pointed", kind="door",
               glass=shade(brA, 0.55), frame=shade(brA, 0.8)),
          grid("front", xa - 4.8, 2, 4.8, ta + 0.3, 1, 2.3, (0.55, 1.5), sill=0.2, top="pointed", kind="door",
               glass=shade(brA, 0.55), frame=shade(brA, 0.8))]
    gable_house(rig, "hga", xa, wa, D, ta, "step", 6.5, dict(color=brA, kind="brick", scale=2.4), gA,
                trim="#ece6da", roof_c="#7e3a2a", seed=1)
    # B: volute gable, plastered
    xb, wb, tb = -0.25, 7.5, 13.1
    gB = [grid("front", xb - 3.3, 3, 2.2, 3.8, 3, 3.1, (1.1, 1.85), sill=0.7, **fr),
          grid("front", xb - 3.3, 3, 2.2, 0.0, 1, 3.8, (1.15, 1.9), sill=1.1, skip=[(1, 0)], **fr),
          grid("front", xb - 1.1, 1, 2.2, 0.0, 1, 3.4, (1.3, 2.9), sill=0.0, top="round", kind="door", glass="#2b3f5c",
               frame="#f4f0e6"),
          grid("front", xb - 1.1, 1, 2.2, tb + 0.6, 1, 2.0, (1.0, 1.6), sill=0.1, top="round", **fr),
          grid("front", xb - 0.6, 1, 1.2, tb + 3.0, 1, 1.4, (0.7, 0.9), sill=0.1, top="round", **fr)]
    _, capB, _ = gable_house(rig, "hgb", xb, wb, D, tb, "volute", 6.0, dict(color="#eadba6", noise=0.05), gB,
                              trim="#f4f0e6", roof_c="#6f3427", seed=2)
    bm = bmesh.new()
    pilasters(bm, "front", 0.0, [xb - wb / 2 + 0.3, xb + wb / 2 - 0.3], 0.0, tb, w=0.5, out=0.1)
    cornice(bm, xb - wb / 2, xb + wb / 2, 0.0, 0.05, tb - 0.25, [(0.12, 0.08), (0.18, 0.2)])
    mk(rig, "hgb_orn", bm, capB)
    # C: pointed gable with lancet windows
    brC = "#a5482e"
    xc, wc, tc = 7.75, 8.5, 10.2
    gC = [grid("front", xc - 3.75, 3, 2.5, 3.8, 2, 3.2, (1.15, 2.1), sill=0.6, top="pointed", **fr),
          grid("front", xc - 3.75, 3, 2.5, 0.0, 1, 3.8, (1.15, 2.0), sill=1.0, top="pointed", skip=[(0, 0)], **fr),
          grid("front", xc - 3.75, 1, 2.5, 0.0, 1, 3.4, (1.5, 2.9), sill=0.0, top="pointed", kind="door",
               glass="#4a2e22", frame="#e9e2d4"),
          grid("front", xc - 2.5, 2, 2.5, tc + 0.6, 1, 2.6, (1.0, 2.0), sill=0.1, top="pointed", **fr),
          grid("front", xc - 0.6, 1, 1.2, tc + 3.6, 1, 1.6, (0.7, 1.2), sill=0.1, top="pointed", **fr)]
    gable_house(rig, "hgc", xc, wc, D, tc, "tri", 7.0, dict(color=brC, kind="brick", scale=2.4), gC,
                zones=[dict(box=((xc - 5, xc + 5), (-1, 1), (z, z + 0.22)), surface="#e8e1d1") for z in (3.7, 7.0, tc - 0.1)],
                trim="#ece6da", roof_c="#7e3a2a", seed=3)
    flowers(rig, "hg_pots", [(xb - 2.0, -0.6, 0.4), (xb + 1.6, -0.6, 0.4), (xa + 2.3, -0.6, 0.4)],
            colors=("#3f6b28",), r=0.35, seed=2)
    return info(24.0, 17.2, D)


def hanse_kontor(rig, p):
    """Kontorhaus (1920s Hamburg brick expressionism): dark clinker, slender piers over eight storeys,
    two set-back top storeys, shop windows in the ground floor."""
    W, D = 28.0, 20.0
    x0, x1 = -W / 2, W / 2
    zg, pz, n = 4.6, 3.3, 7
    ze = zg + pz * n
    clinker = dict(color="#5c2b22", kind="brick", color2="#4a231c", mortar="#3a2a24", scale=2.6, noise=0.07)
    fr = dict(frame="#e9e4d8", mull=dict(v=1, h=[0.62], w=0.06), lit=0.5, glass="#26303a")
    pu = 1.6
    nf, ns = int(W / pu), int(D / pu)
    u0f, u0s = x0 + (W - nf * pu) / 2, (D - ns * pu) / 2
    gf = grid("front", u0f, nf, pu, zg, n, pz, (1.0, 1.85), sill=0.75, **fr)
    gs = grid("left", u0s, ns, pu, zg, n, pz, (1.0, 1.85), sill=0.75, **fr)
    shopf = grid("front", x0 + 0.5, 5, (W - 1.0) / 5, 0.0, 1, zg, ((W - 1.0) / 5 - 1.0, 3.2), sill=0.5, kind="shop",
                 frame="#1e2a28", glass="#2a3a3c")
    shops = grid("left", 0.5, 4, (D - 1.0) / 4, 0.0, 1, zg, ((D - 1.0) / 4 - 1.0, 3.2), sill=0.5, kind="shop",
                 frame="#1e2a28", glass="#2a3a3c")
    wall = wallmat("hk_wall", clinker, [gf, gs, shopf, shops], seed=4)
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze + 0.8)
    mk(rig, "hk_body", bm, wall)
    pier = basic("hk_pier", "#542620", rough=0.8, color2="#47201a", var_scale=3.0)
    bm = bmesh.new()
    for k in range(nf + 1):
        u = u0f + k * pu
        fbox(bm, "front", 0.0, u - 0.24, u + 0.24, zg - 0.3, ze + 1.4, 0.0, 0.32)
        fprism(bm, "front", 0.0, [(u - 0.24, ze + 1.4), (u + 0.24, ze + 1.4), (u, ze + 2.1)], 0.0, 0.32)
    for k in range(ns + 1):
        u = u0s + k * pu
        fbox(bm, "left", x0, u - 0.24, u + 0.24, zg - 0.3, ze + 1.4, 0.0, 0.32)
        fprism(bm, "left", x0, [(u - 0.24, ze + 1.4), (u + 0.24, ze + 1.4), (u, ze + 2.1)], 0.0, 0.32)
    cornice(bm, x0, x1, 0.0, D, zg - 0.45, [(0.25, 0.12), (0.2, 0.3)])
    mk(rig, "hk_piers", bm, pier)
    # set-back storeys with brick parapets
    top = [(1.8, ze + 0.8, ze + 4.0), (3.6, ze + 4.0, ze + 7.0)]
    for i, (st, za, zb) in enumerate(top):
        g1 = grid("front", x0 + st + 0.4, int((W - 2 * st - 0.8) / 2.0), 2.0, za, 1, zb - za, (1.4, 1.8), sill=0.6, **fr)
        g2 = grid("left", st + 0.4, int((D - 2 * st - 0.8) / 2.0), 2.0, za, 1, zb - za, (1.4, 1.8), sill=0.6, **fr)
        wt = wallmat("hk_top%d" % i, clinker, [g1, g2], seed=7 + i)
        bm = bmesh.new()
        bx(bm, x0 + st, x1 - st, st, D - st, za, zb)
        mk(rig, "hk_top%d" % i, bm, wt)
    flat_parapet(rig, "hk_par0", x0, x1, 0.0, D, ze + 0.8, pier, h=1.0, inset=0.3)
    flat_parapet(rig, "hk_par1", x0 + 1.8, x1 - 1.8, 1.8, D - 1.8, ze + 4.0, pier, h=0.9, inset=0.3)
    flat_parapet(rig, "hk_par2", x0 + 3.6, x1 - 3.6, 3.6, D - 3.6, ze + 7.0, pier, h=0.6, inset=0.3)
    return info(W + 0.7, ze + 7.6, D)


def hanse_speicher(rig, p):
    """Speicherstadt warehouse: red brick neo-Gothic with glazed bands, granite plinth, stepped side gable,
    two cross gables over the loading bays (doors on every floor, winch housings), corner turret,
    green copper roof."""
    W, D = 26.0, 20.0
    x0, x1 = -W / 2, W / 2
    zb, pz, n = 1.8, 3.3, 6
    ze = zb + pz * n
    br = "#9b3f2a"
    fr = dict(frame="#e6dfd2", mull=dict(v=1, h=[0.6], w=0.06), lit=0.35, glass="#28323a")
    bays = (-7.0, 7.0)
    grids = []
    for xb_ in bays:
        grids.append(grid("front", xb_ - 1.1, 1, 2.2, zb, n, pz, (1.5, 2.4), sill=0.3, kind="door", glass="#2d4a3a",
                          frame="#e6dfd2"))
    grids += [grid("front", -12.9, 3, 1.6, zb, n, pz, (0.9, 1.6), sill=0.8, top="seg", **fr),
              grid("front", -5.7, 6, 1.9, zb, n, pz, (0.9, 1.6), sill=0.8, top="seg", **fr),
              grid("front", 8.1, 3, 1.6, zb, n, pz, (0.9, 1.6), sill=0.8, top="seg", **fr),
              grid("left", 0.8, 10, 1.84, zb, n, pz, (0.9, 1.6), sill=0.8, top="seg", **fr)]
    zones = [dict(box=((-99, 99), (-99, 99), (-1, zb)), surface=dict(color="#8f8c86", kind="ashlar", h=0.6, w=1.4,
                                                                      strength=0.6))]
    for k in range(n):
        z = zb + k * pz + 0.55
        zones.append(dict(box=((-99, 99), (-99, 99), (z, z + 0.24)), surface=dict(color="#2f3b33", noise=0.04)))
    wall = wallmat("hs_wall", dict(color=br, kind="brick", scale=2.5), grids, zones=zones, seed=5)
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "hs_body", bm, wall)
    copper = roofmat("hs_cu", "#5c9a83", "copper", var=0.2)
    zr = ze + (D / 2) * math.tan(math.radians(40))
    saddle(rig, "hs_roof", x0, x1, 0.0, D, ze, zr, copper, axis="x", over_side=0.3, over_end=0.0)
    trim = basic("hs_trim", "#d9d2c3", rough=0.7)
    front_gable(rig, "hs_lg", "step", D / 2, D + 0.6, ze, zr - ze + 2.0, wall, y0=x0, depth=0.6, face="left", cap_mat=trim)
    front_gable(rig, "hs_rg", "tri", D / 2, D, ze, zr - ze, wall, y0=x1 - 0.3, depth=0.3, face="left")
    gwin = []
    for xb_ in bays:
        front_gable(rig, "hs_cg%d" % (xb_ > 0), "step", xb_, 6.0, ze, 5.4, wall, y0=0.0, depth=0.5, cap_mat=trim)
        saddle(rig, "hs_cgr%d" % (xb_ > 0), xb_ - 3.0, xb_ + 3.0, 0.5, D / 2, ze, ze + 3.6, copper, axis="y",
               over_side=0.0)
        gwin.append(grid("front", xb_ - 0.9, 1, 1.8, ze + 0.4, 1, 2.6, (1.3, 2.2), sill=0.2, kind="door",
                         glass="#2d4a3a", frame="#e6dfd2"))
    wg = wallmat("hs_gwall", dict(color=br, kind="brick", scale=2.5), gwin, seed=6)
    for i, xb_ in enumerate(bays):
        # cross-gable fronts carry the top loading doors (separate material: the windows grid of the gable)
        bm = MU.prism(mirror_outline(gable_half("step", 6.0, 5.4), xb_, ze), 0.06, plane="XZ", offset=-0.06)
        mk(rig, "hs_gfront%d" % i, bm, wg)
    # winch housings + plinth band + door hoods
    bm = bmesh.new()
    for xb_ in bays:
        bx(bm, xb_ - 0.8, xb_ + 0.8, -1.3, 0.3, ze + 3.0, ze + 4.3)
        MU.prism([(xb_ - 0.95, ze + 4.3), (xb_ + 0.95, ze + 4.3), (xb_, ze + 5.0)], 1.7, bm=bm, plane="XZ", offset=-1.4)
        for k in range(n):
            bx(bm, xb_ - 1.0, xb_ + 1.0, -0.15, 0.0, zb + k * pz + 2.75, zb + k * pz + 2.95)
    mk(rig, "hs_winch", bm, basic("hs_wm", "#3f5a4a", rough=0.6))
    bm = bmesh.new()
    cornice(bm, x0, x1, 0.0, D, ze - 0.4, [(0.15, 0.1), (0.25, 0.22)])
    cornice(bm, x0, x1, 0.0, D, zb - 0.1, [(0.18, 0.1)])
    mk(rig, "hs_cornice", bm, trim)
    turret(rig, "hs_tur", x0 + 0.2, 0.2, 1.25, ze - 5.0, ze + 1.8, wall, copper, kind="helm", roof_h=6.0, corbel=1.4,
           win=(0.45, 1.0, [ze - 3.0, ze - 0.4]), seed=3)
    return info(W + 0.9, zr + 2.2, D)


def hanse_crane(rig, p):
    """Harbour portal crane: four-legged portal on rails, slewing machinery house with cabin, luffing
    lattice jib, hook; red lattice steel, red light on the jib head, lit cabin."""
    red = basic("hc_red", "#9a3424", rough=0.5, metal=0.35, color2="#7d2a1e", var_scale=2.0)
    dark = basic("hc_dark", "#2a2d30", rough=0.5, metal=0.5)
    bm = bmesh.new()
    hx, y0, y1 = 4.2, 0.0, 6.4
    H = 9.6
    for x in (-hx, hx):
        for y in (y0, y1):
            MU.bm_beam((x, y, 0.4), (x * 0.82, y + (0.6 if y == y0 else -0.6), H), 0.7, 0.7, bm=bm)
        MU.bm_beam((x, y0, 0.6), (x * 0.9, y1 - 0.3, H * 0.55), 0.25, bm=bm)
        MU.bm_beam((x, y1, 0.6), (x * 0.9, y0 + 0.3, H * 0.55), 0.25, bm=bm)
        bx(bm, x - 0.6, x + 0.6, y0 - 0.9, y1 + 0.9, 0.0, 0.7)
    for y in (y0 + 0.5, y1 - 0.5):
        MU.bm_beam((-hx * 0.85, y, H - 0.4), (hx * 0.85, y, H - 0.4), 0.8, 0.9, bm=bm)
        MU.bm_beam((-hx, y, 1.2), (0.0, y, H - 1.0), 0.25, bm=bm)
        MU.bm_beam((hx, y, 1.2), (0.0, y, H - 1.0), 0.25, bm=bm)
    MU.bm_cyl(2.6, 2.6, 0.9, center=(0.0, 3.2, H + 0.2), segs=20, bm=bm)
    mk(rig, "hc_portal", bm, red)
    # rails
    bm = bmesh.new()
    for x in (-hx, hx):
        bx(bm, x - 0.08, x + 0.08, -6.0, 12.0, 0.0, 0.15)
    mk(rig, "hc_rails", bm, dark)
    # machinery house + cabin + counterweight
    zh = H + 0.65
    bm = bmesh.new()
    bx(bm, -2.0, 2.0, 1.0, 7.6, zh, zh + 3.6)
    mk(rig, "hc_house", bm, wallmat("hc_house", dict(color="#c9c9c3", kind="vboard", pitch=0.5, noise=0.04), [
        grid("left", 1.5, 4, 1.4, zh + 1.3, 1, 1.8, (0.8, 0.9), sill=0.5, lit=0.5, frame="#3a3d40"),
        grid("front", -1.6, 2, 1.6, zh + 1.2, 1, 2.0, (1.0, 1.0), sill=0.5, lit=0.6, frame="#3a3d40")]), bevel=0.05)
    saddle(rig, "hc_hroof", -2.0, 2.0, 1.0, 7.6, zh + 3.6, zh + 4.4, red, axis="y", over_side=0.15, over_end=0.15)
    bm = bmesh.new()
    bx(bm, -1.0, 1.0, -0.3, 1.0, zh + 0.3, zh + 2.6)
    mk(rig, "hc_cabin", bm, wallmat("hc_cab", "#c9c9c3", [
        grid("front", -0.9, 1, 1.8, zh + 0.3, 1, 2.3, (1.6, 1.3), sill=0.8, lit=0.9, frame="#3a3d40", glass="#2a3540"),
        grid("left", -0.25, 1, 1.2, zh + 0.3, 1, 2.3, (1.0, 1.3), sill=0.8, lit=0.9, frame="#3a3d40", glass="#2a3540")]))
    bm = bmesh.new()
    bx(bm, -1.8, 1.8, 7.6, 9.4, zh - 0.4, zh + 2.4)
    mk(rig, "hc_weight", bm, dark)
    # luffing lattice jib from the house front, pointing away from the road (right) and up
    piv = Vector((0.6, 1.4, zh + 1.2))
    ang = math.radians(52.0)
    L = 25.0
    dvec = Vector((math.cos(ang) * 0.94, -math.cos(ang) * 0.34, math.sin(ang))).normalized()
    side = Vector((0.34, 0.94, 0.0)).normalized()
    upv = side.cross(dvec).normalized()
    bm = bmesh.new()
    corners = []
    for (a, b) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        corners.append((side * a * 0.75 + upv * b * 0.6, side * a * 0.18 + upv * b * 0.18))
    for (c0, c1) in corners:
        MU.bm_beam(piv + c0, piv + dvec * L + c1, 0.22, bm=bm)
    nseg = 14
    for k in range(nseg):
        t0, t1 = k / nseg, (k + 1) / nseg
        for i in range(4):
            c0a, c1a = corners[i]
            c0b, c1b = corners[(i + 1) % 4]
            pa = piv + dvec * (L * t0) + c0a.lerp(c1a, t0)
            pb = piv + dvec * (L * t1) + c0b.lerp(c1b, t1)
            MU.bm_beam(pa, pb, 0.1, bm=bm)
    tip = piv + dvec * L
    MU.bm_beam(tip, tip + Vector((0.0, 0.0, -0.8)) + dvec * 1.2, 0.35, bm=bm)
    # A-frame and luffing ties
    apex = Vector((0.0, 6.0, zh + 9.0))
    for s in (-1, 1):
        MU.bm_beam(Vector((s * 1.6, 6.8, zh + 3.6)), apex, 0.3, bm=bm)
    MU.bm_beam(apex, piv + dvec * (L * 0.62), 0.12, bm=bm)
    MU.bm_beam(apex, Vector((0.0, 8.8, zh + 2.4)), 0.12, bm=bm)
    mk(rig, "hc_jib", bm, red)
    bm = bmesh.new()
    hook = tip + dvec * 1.0
    MU.bm_beam(hook, Vector((hook.x, hook.y, 6.0)), 0.05, bm=bm)
    bx(bm, hook.x - 0.3, hook.x + 0.3, hook.y - 0.3, hook.y + 0.3, 5.2, 6.0)
    mk(rig, "hc_hook", bm, dark)
    bm = MU.bm_sphere(0.35, center=(tip.x, tip.y, tip.z + 0.5), subdiv=1)
    mk(rig, "hc_red_light", bm, M.basic("hc_redl", "#a01010", rough=0.3, emit={"lights": ("#ff2010", 9.0)}))
    wall_lamp(rig, "hc_flood", [(-2.05, 3.0, zh + 3.3), (0.0, -0.31, zh + 2.75)], strength=7.0)
    return info(2 * hx + tip.x, tip.z + 1.0, 12.0)


# =================================================================================================
# german: single-family house, 1950s Mietshaus, Gruenderzeit block, office tower
# =================================================================================================

def german_house(rig, p):
    """Einfamilienhaus: 1.5 storeys, 45 degree saddle roof (eaves to the street) with a dormer, cream
    render, roller shutters, attached garage, hedge and a small ornamental tree."""
    W, D = 10.0, 9.0
    x0, x1 = -W / 2, W / 2
    ze = 4.0
    zr = ze + (D / 2) * math.tan(math.radians(42))
    fr = dict(frame="#f7f7f4", mull=dict(v=1, h=0, w=0.07), blind="#8a8d90", blind_max=0.9, lit=0.45)
    gf = grid("front", x0 + 0.6, 3, 2.95, 0.5, 1, 3.0, (1.25, 1.4), sill=0.75, skip=[(1, 0)], **fr)
    door = grid("front", -0.6, 1, 1.2, 0.5, 1, 2.6, (1.05, 2.2), sill=0.0, kind="door", glass="#5a4434", frame="#e8e6e0")
    gl = grid("left", 1.5, 2, 3.0, 0.5, 1, 3.0, (1.2, 1.4), sill=0.75, **fr)
    gg = grid("left", D / 2 - 0.6, 1, 1.2, ze + 0.7, 1, 1.8, (0.9, 1.1), sill=0.3, **fr)
    wall = wallmat("gh_wall", dict(color="#efe9dc", noise=0.05), [gf, door, gl, gg],
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, 0.5)), surface=dict(color="#8d8b86", noise=0.08))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "gh_body", bm, wall)
    roof = roofmat("gh_roof", "#3f4247", "tiles", rows=0.33)
    saddle(rig, "gh_roof", x0, x1, 0.0, D, ze, zr, roof, axis="x", over_side=0.5, over_end=0.4)
    gable_ends(rig, "gh_gab", x0, x1, 0.0, D, ze, zr, wall, axis="x")
    dormers(rig, "gh_dorm", [1.2], -0.0, ze, 42.0, 2.6, 1.4, basic("gh_dw", "#e9e5da"), roof, kind="flat", z_up=1.0,
            glass_seed=2, lit=0.6)
    trim = basic("gh_trim", "#d0cec8", rough=0.6)
    bm = bmesh.new()
    sills(bm, gf, 0.0, h=0.05, out=0.1, ext=0.05)
    sills(bm, gl, x0, h=0.05, out=0.1, ext=0.05)
    bx(bm, -1.2, 1.2, -1.2, 0.0, 2.75, 2.85)
    mk(rig, "gh_trim", bm, trim)
    chimneys(rig, "gh_chim", [(2.6, D * 0.62)], zr - 2.0, zr + 0.9, basic("gh_chm", "#5d5f63", rough=0.6), w=0.5, d=0.5)
    # garage (flat roof) on the road side
    gar = wallmat("gh_gar", dict(color="#e9e4d8", noise=0.05), [
        grid("front", x0 - 3.3, 1, 3.0, 0.0, 1, 2.6, (2.5, 2.15), sill=0.0, kind="door", glass="#c9cbcc", frame="#9a9d9f")],
        decals=[dict(face="front", sym=False, poly=[(x0 - 3.05, z), (x0 - 0.55, z), (x0 - 0.55, z + 0.03), (x0 - 3.05, z + 0.03)],
                     mat="#8f9294") for z in (0.5, 1.0, 1.5)])
    bm = bmesh.new()
    bx(bm, x0 - 3.6, x0, 0.8, 7.4, 0.0, 2.7)
    mk(rig, "gh_garage", bm, gar)
    bm = bmesh.new()
    bx(bm, x0 - 3.75, x0 + 0.05, 0.65, 7.55, 2.7, 2.95)
    mk(rig, "gh_garroof", bm, trim)
    hedge(rig, "gh_hedge", x0 + 0.2, x1 + 1.0, -4.3, -3.6, 1.1, 8)
    hedge(rig, "gh_hedge2", x1 + 0.6, x1 + 1.2, -4.0, 6.0, 1.1, 9)
    tree(rig, "gh_tree", x1 - 1.2, -2.2, 3.6, 1.2, 12, c1="#8a3a2a", c2="#b5523a")
    bm = bmesh.new()
    bx(bm, -2.2, -1.95, -4.0, -3.75, 0.0, 1.1)
    bx(bm, -2.35, -1.8, -4.1, -3.65, 1.1, 1.45)
    mk(rig, "gh_mailbox", bm, basic("gh_mb", "#3d4a5a", rough=0.4, metal=0.3))
    wall_lamp(rig, "gh_lamp", [(1.4, 0.0, 2.3)], strength=5.0)
    return info(W + 4.8, zr + 0.9, D)


def german_mietshaus(rig, p):
    """1950s Mietshaus: four storeys, plain pastel render, small balconies with coloured panels, glass-brick
    stairwell, saddle roof with dormers, chimneys and TV aerials."""
    W, D = 20.0, 11.0
    x0, x1 = -W / 2, W / 2
    zb, pz, n = 0.7, 3.0, 4
    ze = zb + pz * n
    zr = ze + (D / 2) * math.tan(math.radians(36))
    fr = dict(frame="#eeeeea", mull=dict(v=1, h=[0.7], w=0.06), lit=0.5)
    axes = [-8.1, -5.4, -2.7, 2.7, 5.4, 8.1]
    grids = [grid("front", u - 0.75, 1, 1.5, zb, n, pz, (1.25, 1.4), sill=0.85, **fr) for u in axes]
    grids.append(grid("front", -0.5, 1, 1.0, zb + 1.5, n, pz, (0.7, 1.6), sill=0.5, lit=0.8, color="#fff1d0",
                      mull=dict(v=2, h=4, w=0.05), frame="#d8d8d2", glass="#8fa3ad"))
    grids.append(grid("front", -0.7, 1, 1.4, 0.0, 1, 2.6, (1.2, 2.2), sill=0.1, kind="door", glass="#7a5b3a",
                      frame="#d8d8d2"))
    grids.append(grid("left", 1.0, 3, 3.0, zb, n, pz, (1.1, 1.3), sill=0.85, **fr))
    wall = wallmat("gm_wall", dict(color="#dccb9c", noise=0.06), grids,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zb)), surface=dict(color="#9a978e", noise=0.08))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "gm_body", bm, wall)
    roof = roofmat("gm_roof", "#8a4632", "tiles", rows=0.3)
    saddle(rig, "gm_roof", x0, x1, 0.0, D, ze, zr, roof, axis="x", over_side=0.45, over_end=0.3)
    gable_ends(rig, "gm_gab", x0, x1, 0.0, D, ze, zr, wall, axis="x")
    dormers(rig, "gm_dorm", [-5.4, 5.4], 0.0, ze, 36.0, 1.6, 1.2, basic("gm_dw", "#dccb9c"), roof, kind="gable",
            z_up=0.9, glass_seed=4)
    # balconies with coloured sheet panels
    slab = basic("gm_slab", "#cfcac0", rough=0.8)
    panel = basic("gm_panel", "#4f7f8f", rough=0.5)
    bs, bp = bmesh.new(), bmesh.new()
    rails = Rails("gm_rail", "#2d3033", "bars", pitch=0.14, bar=0.03)
    for xc in (-4.05, 4.05):
        for k in range(1, n):
            z = zb + k * pz
            bx(bs, xc - 1.3, xc + 1.3, -1.1, 0.0, z - 0.15, z)
            bx(bp, xc - 1.3, xc + 1.3, -1.12, -1.06, z, z + 0.55)
            rails.add_box(xc - 1.3, xc + 1.3, -1.1, -1.07, z + 0.55, 0.45)
    mk(rig, "gm_slab", bs, slab)
    mk(rig, "gm_panel", bp, panel)
    rails.build(rig)
    grids2 = [grid("front", xc - 0.5, 1, 1.0, zb + pz, n - 1, pz, (0.85, 2.1), sill=0.05, kind="door",
                   glass="#3b4650", frame="#eeeeea") for xc in (-4.05, 4.05)]
    bd = bmesh.new()
    for g in grids2:
        for (u, zc, i, j) in centres(g):
            bx(bd, u - 0.45, u + 0.45, -0.03, 0.0, zc - 1.05, zc + 1.05)
    mk(rig, "gm_bdoors", bd, M.basic("gm_bdm", "#3b4650", rough=0.1, spec=0.9))
    bm = bmesh.new()
    bx(bm, -1.4, 1.4, -1.3, 0.0, 2.6, 2.75)
    sills(bm, grids[0], 0.0, h=0.05, out=0.08)
    mk(rig, "gm_trim", bm, slab)
    chimneys(rig, "gm_chim", [(-7.0, D * 0.5), (0.0, D * 0.5), (7.0, D * 0.5)], zr - 1.5, zr + 1.2,
             basic("gm_chm", "#8a5a48", rough=0.8), w=0.6, d=0.5)
    bm = bmesh.new()
    for (xa, ya) in ((-6.0, D * 0.5), (3.0, D * 0.5)):
        MU.bm_beam((xa, ya, zr - 0.5), (xa, ya, zr + 2.6), 0.05, bm=bm)
        for k in range(4):
            MU.bm_beam((xa - 0.9 + k * 0.1, ya, zr + 1.7 + k * 0.25), (xa + 0.9 - k * 0.1, ya, zr + 1.7 + k * 0.25), 0.03, bm=bm)
    mk(rig, "gm_aerials", bm, basic("gm_aer", "#8d9196", rough=0.4, metal=0.7))
    return info(W + 0.9, zr + 2.6, D)


def german_gruenderzeit(rig, p):
    """Gruenderzeit corner block: rusticated shop floor, four upper storeys with window pediments, a central
    bay window (Erker) with balcony, corner quoins, main cornice, mansard roof with dormers."""
    W, D = 18.0, 14.0
    x0, x1 = -W / 2, W / 2
    zg = 4.2
    floors = [(4.2, 3.6, 2.2), (7.8, 3.4, 2.1), (11.2, 3.3, 2.0), (14.5, 3.2, 1.9)]
    ze = 17.7
    fr = dict(frame="#f1ece2", mull=dict(v=1, h=[0.68], w=0.06), lit=0.45)
    pu = 2.8
    grids, gfl = [], []
    for (face, u0, nn, plane) in (("front", -8.4, 6, 0.0), ("left", 1.4, 4, x0)):
        sk = [(2, 0), (3, 0)] if face == "front" else []
        fl = [grid(face, u0, nn, pu, z, 1, h, (1.25, wh), sill=0.7, skip=sk, **fr) for (z, h, wh) in floors]
        shop = grid(face, u0, nn, pu, 0.0, 1, zg, (2.1, 3.0), sill=0.4, kind="shop", frame="#2b2420", glass="#31403f")
        grids += fl + [shop]
        gfl.append((face, plane, fl))
    # Erker windows (front + sides of the bay)
    xe0, xe1, ye = -2.6, 2.6, -1.0
    erker = [grid("front", xe0 + 0.3, 3, (xe1 - xe0 - 0.6) / 3, z, 1, h, (1.05, wh), sill=0.7, **fr)
             for (z, h, wh) in floors[:3]]
    erker += [grid("left", ye + 0.2, 1, 0.6, z, 1, h, (0.45, wh), sill=0.7, **fr) for (z, h, wh) in floors[:3]]
    surf = dict(color="#e2d4b2", noise=0.05)
    wall = wallmat("gg_wall", surf, grids, seed=8,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zg)), surface=dict(color="#cdbf9f", kind="rustic", h=0.55))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "gg_body", bm, wall)
    ew = wallmat("gg_erker", surf, erker, seed=9)
    bm = bmesh.new()
    bx(bm, xe0, xe1, ye, 0.05, zg + 0.2, floors[2][0] + floors[2][1])
    mk(rig, "gg_erker", bm, ew)
    orn = basic("gg_orn", "#f2ead6", rough=0.75)
    bm = bmesh.new()
    cornice(bm, x0, x1, 0.0, D, zg - 0.3, [(0.15, 0.1), (0.18, 0.18)])
    for (z, h, wh) in floors[1:]:
        cornice(bm, x0, x1, 0.0, D, z - 0.1, [(0.14, 0.06)])
    cornice(bm, x0, x1, 0.0, D, ze - 0.3, [(0.15, 0.1), (0.15, 0.25), (0.3, 0.5), (0.1, 0.58)])
    for (face, plane, fl) in gfl:
        pediments(bm, fl[0], plane, kind="tri", h=0.45, out=0.15)
        pediments(bm, fl[1], plane, kind="seg", h=0.35, out=0.14)
        lintels(bm, fl[2], plane, h=0.22, out=0.1)
        surrounds(bm, fl[3], plane, w=0.1, out=0.05)
        for k in range(4):
            sills(bm, fl[k], plane, h=0.1, out=0.12)
    quoins(bm, "front", 0.0, x0, zg, ze - 0.3)
    quoins(bm, "left", x0, 0.0, zg, ze - 0.3)
    # Erker: cornices and corbel
    cornice(bm, xe0, xe1, ye, 0.0, zg - 0.2, [(0.25, 0.0), (0.2, 0.12)])
    for (z, h, wh) in floors[1:3]:
        cornice(bm, xe0, xe1, ye, 0.0, z - 0.1, [(0.15, 0.06)])
    zt_e = floors[2][0] + floors[2][1]
    bx(bm, xe0 - 0.1, xe1 + 0.1, ye - 0.1, 0.0, zt_e, zt_e + 0.2)
    mk(rig, "gg_orn", bm, orn)
    rails = Rails("gg_rail", "#22262a", "haussmann", pitch=0.2, bar=0.03)
    rails.add_box(xe0, xe1, ye - 0.06, ye, zt_e + 0.2, 1.0)
    rails.add_box(xe0, xe0 + 0.04, ye, 0.0, zt_e + 0.2, 1.0)
    rails.build(rig)
    mansard(rig, "gg_mans", x0, x1, 0.0, D, ze + 0.32, 3.4, 1.3, 1.6, roofmat("gg_slate", "#4d5157", "slate"),
            roofmat("gg_tar", "#5a5d60", "metal"), over=0.15)
    dormers(rig, "gg_dorm", [-6.0, -2.0, 2.0, 6.0], -0.15, ze + 0.32, 69.0, 1.2, 1.6, orn, roofmat("gg_dr", "#4d5157", "metal"),
            kind="seg", z_up=0.4, glass_seed=5)
    chimneys(rig, "gg_chim", [(-5.0, D * 0.55), (4.0, D * 0.5)], ze + 3.0, ze + 6.0, basic("gg_chm", "#8a5a48", rough=0.8),
             w=0.9, d=0.6)
    return info(W + 1.2, ze + 6.0, D)


def german_office(rig, p):
    """Office tower (Frankfurt): stone podium with glass lobby, blue-green curtain wall with fins and
    spandrel bands, chamfered corners, set-back glass crown lit at night, aerial with red lights."""
    W = 28.0
    x0, x1 = -W / 2, W / 2
    c = 3.0
    zp, zt = 12.0, 104.0
    m, nb = M.new_material("go_glass")
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    side = nb.gt(nb.absf(nx), nb.absf(ny))
    u = nb.mixf(side, x, y)
    fz = _mod(nb, z, 3.8)
    band = nb.lt(fz, 1.0)
    fin = nb.lt(_mod(nb, u, 1.5), 0.14)
    sky = nb.ramp(nb.math("DIVIDE", z, zt), [(0.0, M.srgb("#2b4a55")), (0.6, M.srgb("#4f7a88")), (1.0, M.srgb("#86a9b8"))])
    frame = nb.OR(band, fin)
    col = nb.mix(frame, sky, M.srgb("#b9c0c4"))
    col = nb.mix(nb.mul(band, nb.lt(fz, 0.12)), col, M.srgb("#7d8589"))
    out = M.principled(nb, col, rough=nb.mixf(frame, 0.05, 0.45), metal=nb.mixf(frame, 0.55, 0.2), spec=0.9)
    iu = nb.math("FLOOR", nb.math("DIVIDE", u, 3.0))
    iz = nb.math("FLOOR", nb.math("DIVIDE", z, 3.8))
    cmb = nb.node("ShaderNodeCombineXYZ")
    nb.feed(cmb.inputs[0], iu)
    nb.feed(cmb.inputs[1], iz)
    nb.feed(cmb.inputs[2], nb.add(nb.mul(nx, 3.0), nb.mul(ny, 5.0)))
    wn = nb.node("ShaderNodeTexWhiteNoise", noise_dimensions="3D")
    nb.links.new(cmb.outputs[0], wn.inputs["Vector"])
    vert = nb.lt(nb.absf(nz), 0.5)
    litm = nb.AND(nb.NOT(frame), nb.lt(wn.outputs["Value"], 0.32), vert, nb.gt(z, zp))
    em = nb.color_scale(nb.color_scale(M.emit_col("#fff0d6", 0.8), nb.madd(wn.outputs["Value"], 1.2, 0.5)), litm)
    glass = M.finish(m, nb, out, {"lights": em})
    fp = [(x0 + c, 0.0), (x1 - c, 0.0), (x1, c), (x1, W - c), (x1 - c, W), (x0 + c, W), (x0, W - c), (x0, c)]
    ring_obj(rig, "go_tower", fp, zp, zt, glass)
    stone = wallmat("go_stone", dict(color="#cfcbc2", kind="ashlar", h=1.2, w=2.4, strength=0.4), [
        grid("front", x0 + 2.0, 6, (W - 4.0) / 6, 0.0, 1, zp, ((W - 4.0) / 6 - 0.8, 9.5), sill=0.5, kind="shop",
             frame="#3a3f44", glass="#2c3c46", color="#fff2dc", strength=1.2),
        grid("left", 2.0, 6, (W - 4.0) / 6, 0.0, 1, zp, ((W - 4.0) / 6 - 0.8, 9.5), sill=0.5, kind="shop",
             frame="#3a3f44", glass="#2c3c46", color="#fff2dc", strength=1.2)])
    ring_obj(rig, "go_podium", offset_poly(fp, 1.5), 0.0, zp, stone)
    trim = basic("go_trim", "#c5c9cc", rough=0.4, metal=0.6)
    bm = bmesh.new()
    poly_prism_z(bm, offset_poly(fp, 1.8), zp, zp + 0.6)
    poly_prism_z(bm, offset_poly(fp, 0.3), zt, zt + 1.2)
    mk(rig, "go_trim", bm, trim)
    # crown: set-back glass pyramid with a lit lattice
    cm, cb = M.new_material("go_crown")
    cx_, cy_, cz_ = cb.coords()
    lat = cb.OR(cb.lt(_mod(cb, cb.add(cx_, cz_), 2.0), 0.12), cb.lt(_mod(cb, cb.sub(cx_, cz_), 2.0), 0.12),
                cb.lt(_mod(cb, cb.add(cy_, cz_), 2.0), 0.12), cb.lt(_mod(cb, cb.sub(cy_, cz_), 2.0), 0.12))
    ccol = cb.mix(lat, M.srgb("#5d7f8f"), M.srgb("#d9dde0"))
    cout = M.principled(cb, ccol, rough=cb.mixf(lat, 0.05, 0.4), metal=0.4, spec=0.9)
    crown_m = M.finish(cm, cb, cout, {"lights": cb.color_scale(M.emit_col("#dbe8ff", 2.2), lat)})
    inner = offset_poly(fp, -3.0)
    r1 = [(q[0], q[1], zt + 1.2) for q in inner]
    r2 = [(q[0] * 0.25, W / 2 + (q[1] - W / 2) * 0.25, zt + 13.0) for q in inner]
    bm = MU.loft([r1, r2], cap0=False, cap1=True)
    mk(rig, "go_crown", bm, crown_m)
    bm = bmesh.new()
    MU.bm_cyl(0.35, 0.12, 12.0, center=(0.0, W / 2, zt + 19.0), segs=8, bm=bm)
    mk(rig, "go_mast", bm, trim)
    red = M.basic("go_red", "#a01010", rough=0.3, emit={"lights": ("#ff2010", 8.0)})
    bm = bmesh.new()
    MU.bm_sphere(0.35, center=(0.0, W / 2, zt + 25.2), subdiv=1, bm=bm)
    for (xx, yy) in ((x0 + 0.5, 0.5), (x1 - 0.5, 0.5)):
        MU.bm_sphere(0.3, center=(xx, yy, zt + 1.5), subdiv=1, bm=bm)
    mk(rig, "go_red", bm, red)
    return info(W + 3.6, zt + 25.5, W + 3.0)


# =================================================================================================
# german_old: half-timbered houses, baroque town houses
# =================================================================================================

TIMBER_WIN = dict(frame="#efe9dc", mull=dict(v=1, h=[0.5], w=0.06), lit=0.5)


def timber_house(rig, name, x0, x1, d, storeys, infill, timber, pitch=1.1, jetty=0.35, left_jetty=False,
                 gable=None, gh=0.0, eaves_roof=None, roof_c="#7d3a2a", base=None, wins=None, extra_grids=(),
                 seed=0, shutters=None, door=None):
    """Jettied half-timbered house. storeys: [(z0, z1)] (the first one is stone `base` if given, else
    timber); each upper storey projects `jetty` further to the front (and to the left if left_jetty).
    wins: per storey a list of bay indices with windows; gable: kind of the front gable (ridge along y)
    or eaves_roof = (ridge height) for a roof with its eaves to the street."""
    u0 = x0 + 0.1
    floors = [(z0, z1) for k, (z0, z1) in enumerate(storeys) if not (k == 0 and base)]
    zt = storeys[-1][1]
    nfront = len(storeys) - 1
    yf = -nfront * jetty
    if gable:
        floors += [(zt, zt + gh * 0.45), (zt + gh * 0.45, zt + gh)]
    elif eaves_roof:
        hz = eaves_roof - zt
        floors += [(zt, zt + hz * 0.4), (zt + hz * 0.4, zt + hz * 0.75)]
    grids = list(extra_grids)
    nb_ = int((x1 - x0 - 0.2) / pitch)
    for k, (z0, z1) in enumerate(storeys):
        if k == 0 and base:
            continue
        bays = (wins or {}).get(k, [j for j in range(1, nb_ - 1, 2)])
        for j in bays:
            grids.append(grid("front", u0 + (j - 0.5) * pitch, 1, 2 * pitch, z0, 1, z1 - z0, (pitch - 0.24, 1.3),
                              sill=0.85, shutters=shutters, **TIMBER_WIN))
        if left_jetty:
            j0 = int(math.ceil((1.0 - u0) / pitch))
            j0 += 1 - j0 % 2
            for j in range(j0, int((d - 1.5 - u0) / pitch), 4):
                grids.append(grid("left", u0 + (j - 0.5) * pitch, 1, 2 * pitch, z0, 1, z1 - z0, (pitch - 0.24, 1.3),
                                  sill=0.85, **TIMBER_WIN))
    if door:
        grids.append(door)
    surf = dict(color=infill, kind="timber", timber=timber, u0=u0, pitch=pitch, w=0.2, floors=floors, sill=0.85,
                lintel=2.25, brace_every=2, brace_phase=0, noise=0.05)
    zones = [dict(box=((-99, 99), (-99, 99), (-1, storeys[0][1])), surface=base)] if base else []
    wall = wallmat(name + "_wall", surf, grids, zones=zones, seed=seed)
    heads = bmesh.new()
    for k, (z0, z1) in enumerate(storeys):
        yk = -k * jetty
        xk = x0 - (k * jetty if left_jetty else 0.0)
        bm = bmesh.new()
        bx(bm, xk, x1, yk, d, z0, z1)
        mk(rig, "%s_s%d" % (name, k), bm, wall)
        if k > 0:
            n = int((x1 - xk) / 0.6)
            for i in range(n):
                xx = xk + 0.3 + i * 0.6
                bx(heads, xx - 0.09, xx + 0.09, yk - 0.02, yk + jetty, z0 - 0.22, z0)
    mk(rig, name + "_heads", heads, basic(name + "_hm", timber, rough=0.7))
    xl = x0 - (nfront * jetty if left_jetty else 0.0)
    roof = roofmat(name + "_rm", roof_c, "tiles", rows=0.26)
    if gable:
        front_gable(rig, name + "_gable", gable, (xl + x1) / 2, x1 - xl, zt, gh, wall, y0=yf, depth=0.4)
        zr = zt + gh + 0.15
        saddle(rig, name + "_roof", xl, x1, yf, d, zt, zr, roof, axis="y", over_side=0.25, over_end=0.25,
               over_end0=0.35)
    else:
        zr = eaves_roof
        saddle(rig, name + "_roof", xl, x1, yf, d, zt, zr, roof, axis="x", over_side=0.4, over_end=0.0)
        gable_ends(rig, name + "_ge", xl, x1, yf, d, zt, zr, wall, axis="x")
    return wall, roof, zr, yf


def german_old_fachwerk(rig, p):
    """Three jettied half-timbered houses: dark timber on white with a sandstone ground floor (gable to
    the street), ox-blood timber on ochre (eaves to the street, dormers), dark timber on cream above a
    plastered green ground floor."""
    D = 13.0
    st3 = [(0.0, 3.2), (3.2, 6.0), (6.0, 8.8)]
    sand = dict(color="#c8a27c", kind="ashlar", h=0.5, w=1.0, strength=0.5)
    timber_house(rig, "gfa", -11.25, -4.25, D, st3, "#efe8da", "#3e2a1d", left_jetty=True, gable="tri", gh=6.6,
                 base=sand, seed=1, wins={1: [1, 3, 5], 2: [1, 3, 5]},
                 door=grid("front", -9.85, 1, 2.0, 0.0, 1, 3.0, (1.5, 2.6), sill=0.0, top="round", kind="door",
                           glass="#4a3222", frame="#b48d68"),
                 extra_grids=[grid("front", -7.4, 1, 1.8, 0.0, 1, 3.0, (1.1, 1.3), sill=1.0, **TIMBER_WIN),
                              grid("front", -8.6, 1, 1.0, 9.3, 1, 1.8, (0.75, 1.1), sill=0.2, **TIMBER_WIN),
                              grid("front", -8.6, 1, 1.0, 11.6, 1, 1.4, (0.6, 0.8), sill=0.2, **TIMBER_WIN)])
    _, roofB, zrB, yfB = timber_house(rig, "gfb", -4.25, 4.75, D, [(0.0, 3.0), (3.0, 5.8), (5.8, 8.6)], "#e6c47e",
                                      "#7a2b1f", eaves_roof=15.8, roof_c="#8a3b2a", seed=2,
                                      wins={0: [1, 5], 1: [1, 3, 5, 7], 2: [1, 3, 5, 7]},
                                      door=grid("front", -0.85, 1, 1.4, 0.0, 1, 2.6, (1.1, 2.3), sill=0.0, kind="door",
                                                glass="#5a3a26", frame="#7a2b1f"))
    pB = math.degrees(math.atan((zrB - 8.6) / ((D - yfB) / 2)))
    dormers(rig, "gfb_dorm", [-1.9, 2.4], yfB, 8.6, pB, 1.5, 1.3, basic("gfb_dw", "#e6c47e"), roofB, kind="gable",
            z_up=0.8, glass_seed=7)
    green = dict(color="#b5c79c", noise=0.05)
    timber_house(rig, "gfc", 4.75, 11.25, D, [(0.0, 3.1), (3.1, 5.9), (5.9, 8.7)], "#ece2c6", "#3b2a1e", gable="tri",
                 gh=6.2, base=green, seed=3, roof_c="#743628", wins={1: [1, 3], 2: [1, 3]},
                 door=grid("front", 5.35, 1, 1.4, 0.0, 1, 2.7, (1.05, 2.3), sill=0.0, kind="door", glass="#3c4b35",
                           frame="#efe9dc"),
                 extra_grids=[grid("front", 7.6, 1, 2.0, 0.0, 1, 3.1, (1.4, 1.4), sill=0.9, **TIMBER_WIN),
                              grid("front", 7.55, 1, 0.9, 9.2, 1, 1.8, (0.7, 1.1), sill=0.2, **TIMBER_WIN)])
    pts = []
    for (x, z) in ((-10.2, 4.05), (-6.9, 4.05), (-2.5, 3.85), (2.9, 3.85), (6.3, 4.0)):
        pts += [(x + 0.15 * k, -0.62 if x < -4 else -0.32, z) for k in range(5)]
    flowers(rig, "gf_fl", pts, colors=("#d6262b", "#e85a8a", "#3f6b28"), r=0.13, seed=5)
    return info(23.0, 15.8, D)


def german_old_fachwerk_b(rig, p):
    """Large half-timbered guild house: red sandstone ground floor with a round-arched gateway, two jettied
    timber storeys, a very steep roof with two rows of dormers, polygonal corner oriel with a helm roof."""
    D = 13.0
    x0, x1 = -7.0, 7.0
    sand = dict(color="#b5735c", kind="ashlar", h=0.55, w=1.1, strength=0.5)
    wall, roof, zr, yf = timber_house(
        rig, "gfx", x0, x1, D, [(0.0, 3.6), (3.6, 6.6), (6.6, 9.6)], "#f0e9da", "#3a2619", eaves_roof=21.0,
        roof_c="#6f3326", base=sand, seed=4, pitch=1.15, wins={1: [3, 5, 7, 9], 2: [3, 5, 7, 9]},
        door=grid("front", -1.6, 1, 3.2, 0.0, 1, 3.5, (2.8, 3.2), sill=0.0, top="round", kind="door", glass="#3f2a1c",
                  frame="#9c6250"),
        extra_grids=[grid("front", 2.0, 2, 2.2, 0.0, 1, 3.6, (1.1, 1.5), sill=1.1, top="seg", **TIMBER_WIN)])
    px = math.degrees(math.atan((zr - 9.6) / ((D - yf) / 2)))
    dormers(rig, "gfx_d1", [-4.0, -1.3, 1.4, 4.1], yf, 9.6, px, 1.3, 1.3, basic("gfx_dw", "#f0e9da"), roof,
            kind="gable", z_up=1.0, glass_seed=8)
    dormers(rig, "gfx_d2", [-1.3, 1.4], yf, 9.6, px, 1.0, 1.0, basic("gfx_dw2", "#f0e9da"), roof, kind="gable",
            z_up=6.2, glass_seed=9)
    turret(rig, "gfx_erker", x0 - 0.75, yf - 0.1, 1.55, 4.4, 11.2, wall, roofmat("gfx_slate", "#3f4247", "slate"),
           kind="helm", roof_h=6.5, corbel=1.0, win=(0.55, 1.1, [5.9, 8.9]), seed=4)
    return info(17.0, 22.0, D)


def german_old_barock(rig, p):
    """Two baroque town houses: pink with white stucco, giant pilasters, a central volute cross gable with
    an oculus and a mansard roof; pale yellow with an oriel and a saddle roof."""
    D = 14.0
    fr = dict(frame="#f4efe6", mull=dict(v=1, h=[0.66], w=0.06), lit=0.45)
    fl = [(4.0, 3.5, 2.2), (7.5, 3.3, 2.0), (10.8, 3.1, 1.9)]
    ze = 13.9
    # A
    xa0, xa1 = -10.0, 0.5
    ga = [grid("front", xa0 + 0.85, 4, 2.2, z, 1, h, (1.2, wh), sill=0.75, **fr) for (z, h, wh) in fl]
    ga += [grid("front", xa0 + 0.85, 4, 2.2, 0.0, 1, 4.0, (1.4, 2.6), sill=0.5, top="seg", skip=[(1, 0)], **fr),
           grid("front", xa0 + 3.05, 1, 2.2, 0.0, 1, 4.0, (1.6, 3.2), sill=0.0, top="round", kind="door",
                glass="#4b3424", frame="#f4efe6"),
           grid("left", 1.2, 5, 2.4, 4.0, 3, 3.3, (1.1, 1.9), sill=0.8, **fr)]
    gz = [grid("front", -5.3, 1, 1.0, ze + 0.3, 1, 1.9, (0.8, 1.4), sill=0.2, top="seg", **fr),
          grid("front", -5.2, 1, 0.8, ze + 2.4, 1, 1.0, (0.55, 0.55), sill=0.2, top="round", **fr)]
    wa = wallmat("gba_wall", dict(color="#e7b19c", noise=0.05), ga + gz, seed=2,
                 zones=[dict(box=((-99, 99), (-99, 99), (-1, 4.0)), surface=dict(color="#dfa894", kind="rustic", h=0.6))])
    bm = bmesh.new()
    bx(bm, xa0, xa1, 0.0, D, 0.0, ze)
    mk(rig, "gba_body", bm, wa)
    st = basic("gba_st", "#f6f1e7", rough=0.75)
    bm = bmesh.new()
    pilasters(bm, "front", 0.0, [xa0 + 0.35, xa1 - 0.35], 4.0, ze - 0.4, w=0.6, out=0.14)
    pilasters(bm, "left", xa0, [0.4, D - 0.4], 4.0, ze - 0.4, w=0.6, out=0.14)
    cornice(bm, xa0, xa1, 0.0, D, 3.75, [(0.12, 0.08), (0.15, 0.16)])
    cornice(bm, xa0, xa1, 0.0, D, ze - 0.4, [(0.15, 0.1), (0.15, 0.22), (0.25, 0.42), (0.1, 0.5)])
    pediments(bm, ga[0], 0.0, kind="seg", h=0.4, out=0.14)
    surrounds(bm, ga[1], 0.0, w=0.12, out=0.06)
    surrounds(bm, ga[2], 0.0, w=0.1, out=0.05)
    for g in ga[:3]:
        sills(bm, g, 0.0, h=0.1, out=0.12)
    lintels(bm, ga[5], xa0, h=0.2, out=0.1)
    mk(rig, "gba_stucco", bm, st)
    mansard(rig, "gba_mans", xa0, xa1, 0.0, D, ze + 0.25, 3.4, 1.4, 1.3, roofmat("gba_roof", "#9a4430", "tiles"),
            over=0.15)
    front_gable(rig, "gba_zw", "volute", -4.75, 5.0, ze + 0.25, 4.6, wa, y0=0.0, depth=0.5, cap_mat=st)
    saddle(rig, "gba_zwr", -7.2, -2.3, 0.5, 4.0, ze + 0.25, ze + 3.7, roofmat("gba_zr", "#9a4430", "tiles"), axis="y",
           over_side=0.0)
    # B
    xb0, xb1 = 0.5, 10.0
    gb = [grid("front", xb0 + 0.55, 4, 2.1, z, 1, h, (1.15, wh), sill=0.75, skip=[(1, 0), (2, 0)] if z < 10 else [], **fr)
          for (z, h, wh) in fl]
    gb += [grid("front", xb0 + 0.55, 4, 2.1, 0.0, 1, 4.0, (1.5, 2.6), sill=0.5, kind="shop", skip=[(2, 0)]),
           grid("front", xb0 + 4.75, 1, 2.1, 0.0, 1, 4.0, (1.2, 2.7), sill=0.0, kind="door", glass="#40362a",
                frame="#f4efe6")]
    oe = [grid("front", 3.55, 2, 1.7, z, 1, h, (1.1, wh), sill=0.75, **fr) for (z, h, wh) in fl[:2]]
    oe += [grid("left", -0.8, 1, 0.6, z, 1, h, (0.4, wh), sill=0.75, **fr) for (z, h, wh) in fl[:2]]
    wb = wallmat("gbb_wall", dict(color="#ecd592", noise=0.05), gb, seed=3)
    bm = bmesh.new()
    bx(bm, xb0, xb1, 0.0, D, 0.0, ze)
    mk(rig, "gbb_body", bm, wb)
    wo = wallmat("gbb_oriel", dict(color="#ecd592", noise=0.05), oe, seed=4)
    bm = bmesh.new()
    bx(bm, 3.45, 7.05, -0.9, 0.05, 4.2, 10.8)
    mk(rig, "gbb_oriel", bm, wo)
    bm = bmesh.new()
    cornice(bm, xb0, xb1, 0.0, D, 3.75, [(0.12, 0.08), (0.15, 0.16)])
    cornice(bm, xb0, xb1, 0.0, D, ze - 0.4, [(0.15, 0.1), (0.15, 0.22), (0.2, 0.36)])
    cornice(bm, 3.45, 7.05, -0.9, 0.0, 3.7, [(0.25, 0.0), (0.25, 0.12)])
    cornice(bm, 3.45, 7.05, -0.9, 0.0, 10.8, [(0.15, 0.1), (0.15, 0.2)])
    for g in gb[:3]:
        surrounds(bm, g, 0.0, w=0.12, out=0.06)
    mk(rig, "gbb_stucco", bm, st)
    bm = MU.bm_lathe([(0.0, 11.1), (1.5, 11.1), (1.2, 11.9), (0.6, 12.5), (0.0, 12.7)], segs=4, center=(5.25, -0.42, 0.0))
    for v in bm.verts:
        v.co.x = 5.25 + (v.co.x - 5.25) * 1.25
        v.co.y = -0.42 + (v.co.y + 0.42) * 0.62
    mk(rig, "gbb_cap", bm, roofmat("gbb_cu", "#5f9a84", "copper"))
    rb = roofmat("gbb_roof", "#9a4430", "tiles")
    zrb = ze + 6.0
    saddle(rig, "gbb_roof", xb0, xb1, 0.0, D, ze, zrb, rb, axis="x", over_side=0.4, over_end=0.0)
    gable_ends(rig, "gbb_ge", xb0, xb1, 0.0, D, ze, zrb, wb, axis="x")
    dormers(rig, "gbb_dorm", [2.6, 7.9], 0.0, ze, 40.6, 1.3, 1.3, basic("gbb_dw", "#ecd592"), rb, kind="seg", z_up=0.9,
            glass_seed=6)
    chimneys(rig, "gb_chim", [(-6.0, D * 0.6), (7.5, D * 0.55)], ze + 3.0, ze + 6.6, basic("gb_chm", "#c9b49a", rough=0.8))
    return info(20.5, zrb + 0.6, D)


# =================================================================================================
# dutch: canal houses (step / bell / neck gables)
# =================================================================================================

SASH = dict(frame="#f4f2ec", mull=dict(v=1, h=[0.5], w=0.07), lit=0.5)


def _canal_house(rig, name, xc, w, d, floors, gable, gh, brick, trim="#f2efe6", door_c="#1f3a2a", painted=None,
                 gwin=None, seed=0, ground=3.6, upper=3.2):
    """One canal house: brick front with tall sash windows, raised entrance (stoop), front gable of
    kind `gable` (step | bell | neck | spout | cornice), saddle roof along y, hoist beam."""
    x0, x1 = xc - w / 2, xc + w / 2
    zt = ground + upper * (floors - 1)
    n = 2 if w < 6.2 else 3
    pu = (w - 0.9) / n
    ww = min(1.25, pu * 0.62)
    grids = [grid("front", x0 + 0.45, n, pu, ground, floors - 1, upper, (ww, 2.0), sill=0.6, **SASH),
             grid("front", x0 + 0.45, n, pu, 0.0, 1, ground, (ww, 1.9), sill=1.2, skip=[(0, 0)], **SASH),
             grid("front", x0 + 0.45, 1, pu, 0.9, 1, 2.7, (1.05, 2.45), sill=0.0, kind="door", glass=door_c,
                  frame=trim)]
    for gi in gwin or []:
        grids.append(grid("front", xc - gi[0] / 2, 1, gi[0], zt + gi[1], 1, gi[2], (gi[3], gi[2] - 0.3),
                          sill=0.1, **SASH))
    surf = dict(color=brick, kind="brick", mortar=shade(brick, 1.5), scale=2.4) if not painted else dict(color=painted)
    wall = wallmat(name + "_wall", surf, grids, frame=trim, seed=seed)
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, d, 0.0, zt)
    mk(rig, name + "_body", bm, wall)
    capm = basic(name + "_capm", trim, rough=0.6)
    front_gable(rig, name + "_gable", gable, xc, w, zt, gh, wall, y0=0.0, depth=0.5, cap_mat=capm)
    rp = 52.0
    zr = zt + min(gh - 0.4, (w / 2) * math.tan(math.radians(rp)))
    roof = roofmat(name + "_roof", "#5a4a42" if seed % 2 else "#463f3c", "tiles", rows=0.28)
    saddle(rig, name + "_roof", x0 + 0.02, x1 - 0.02, 0.5, d, zt, zr, roof, axis="y", over_side=0.0, over_end=0.0)
    bm = bmesh.new()
    bx(bm, x0 + 0.45 + pu / 2 - 0.9, x0 + 0.45 + pu / 2 + 0.9, -1.4, 0.0, 0.0, 0.9)
    bx(bm, x0 + 0.45 + pu / 2 - 0.9, x0 + 0.45 + pu / 2 + 0.9, -1.9, -1.4, 0.0, 0.45)
    mk(rig, name + "_stoop", bm, basic(name + "_st", "#8f8b84", rough=0.85))
    bm = bmesh.new()
    # string course, hoist beam
    bx(bm, x0 + 0.1, x1 - 0.1, -0.08, 0.0, ground - 0.15, ground)
    bx(bm, xc - 0.12, xc + 0.12, -1.1, 0.4, zt + gh - 1.05, zt + gh - 0.8)
    mk(rig, name + "_trim", bm, capm)
    return zt + gh


def dutch_canal(rig, p):
    """Three Amsterdam canal houses: step gable (red-brown brick), bell gable (dark painted brick with
    white sandstone), neck gable (orange-red brick)."""
    D = 14.0
    tops = [
        _canal_house(rig, "dca", -6.25, 6.5, D, 3, "step", 5.0, "#6e3123", seed=1,
                     gwin=[(2.0, 0.6, 2.0, 0.95), (2.0, 2.7, 1.8, 0.85)]),
        _canal_house(rig, "dcb", -0.25, 5.5, D, 4, "bell", 4.4, "#3a2c27", painted="#2f2a27", seed=2,
                     gwin=[(2.0, 0.7, 2.2, 1.0)]),
        _canal_house(rig, "dcc", 6.25, 7.0, D, 3, "neck", 6.0, "#a3462c", seed=3,
                     gwin=[(2.2, 0.4, 2.0, 1.0), (2.2, 2.6, 1.9, 0.9)]),
    ]
    flowers(rig, "dc_pots", [(-6.25 - 1.0 + 0.5 * k, -1.2, 1.05) for k in range(3)] +
            [(6.25 + 0.5 * k, -1.25, 1.05) for k in range(3)], colors=("#3f6b28", "#c43a3a"), r=0.22, seed=7)
    return info(19.0, max(tops), D)


# =================================================================================================
# dutch (continued): canal houses with cornice / spout / Renaissance gables, terraced houses, houseboat
# =================================================================================================

def dutch_canal_b(rig, p):
    """Three more canal houses: plastered cornice house with a crest, a narrow warehouse with a spout gable
    and red-green shutters, an Amsterdam Renaissance step gable (red brick with white sandstone bands)."""
    D = 14.0
    # A: cornice house
    xa, wa = -5.75, 8.0
    ga = [grid("front", xa - 3.6, 3, 2.4, 3.6, 3, 3.2, (1.25, 2.0), sill=0.6, **SASH),
          grid("front", xa - 3.6, 3, 2.4, 0.0, 1, 3.6, (1.25, 1.9), sill=1.2, skip=[(1, 0)], **SASH),
          grid("front", xa - 1.2, 1, 2.4, 0.9, 1, 2.7, (1.1, 2.45), sill=0.0, kind="door", glass="#1f2a3a", frame="#f2efe6"),
          grid("front", xa - 0.6, 1, 1.2, 13.25, 1, 1.4, (0.8, 0.8), sill=0.25, top="round", **SASH)]
    wall, capm, _ = gable_house(rig, "dba", xa, wa, D, 13.2, "cornice", 1.6, dict(color="#d8d4cb", noise=0.04), ga,
                                trim="#f4f2ec", roof_c="#4a4440", seed=11, pitch=40.0)
    front_gable(rig, "dba_crest", "volute", xa, 3.4, 14.8, 1.5, wall, y0=0.0, depth=0.4, cap_mat=capm)
    bm = bmesh.new()
    cornice(bm, xa - wa / 2, xa + wa / 2, 0.0, 0.1, 13.0, [(0.12, 0.1), (0.2, 0.3), (0.12, 0.4)])
    mk(rig, "dba_orn", bm, capm)
    bm = bmesh.new()
    bx(bm, xa - 0.9, xa + 0.9, -1.4, 0.0, 0.0, 0.9)
    mk(rig, "dba_stoop", bm, basic("dba_st", "#8f8b84", rough=0.85))
    # B: spout gable warehouse with shutters and loading doors
    xb, wb = 0.75, 5.0
    gb = [grid("front", xb - 2.2, 2, 2.2, 3.4, 3, 3.0, (0.95, 1.7), sill=0.6, shutters="#7a1f1a", shutter_w=0.5, **SASH),
          grid("front", xb - 1.1, 1, 2.2, 0.0, 1, 3.4, (1.6, 2.7), sill=0.0, kind="door", glass="#2d4a35", frame="#f2efe6"),
          grid("front", xb - 0.6, 1, 1.2, 12.4, 1, 2.0, (0.9, 1.6), sill=0.1, kind="door", glass="#2d4a35",
               frame="#f2efe6")]
    gable_house(rig, "dbb", xb, wb, D, 12.4, "spout", 4.8, dict(color="#5c2a1f", kind="brick", scale=2.4), gb,
                trim="#f2efe6", roof_c="#3f3a37", seed=12, pitch=58.0)
    bm = bmesh.new()
    bx(bm, xb - 0.12, xb + 0.12, -1.1, 0.4, 16.0, 16.25)
    mk(rig, "dbb_hoist", bm, basic("dbb_hm", "#3a2a20"))
    # C: Amsterdam Renaissance
    xc, wc = 6.75, 7.0
    brc = "#9b3d2a"
    gc = [grid("front", xc - 3.15, 3, 2.1, 3.6, 2, 3.2, (1.1, 2.0), sill=0.6, **SASH),
          grid("front", xc - 3.15, 3, 2.1, 0.0, 1, 3.6, (1.1, 1.9), sill=1.2, skip=[(0, 0)], **SASH),
          grid("front", xc - 3.15, 1, 2.1, 0.9, 1, 2.7, (1.05, 2.45), sill=0.0, kind="door", glass="#3a1f1a",
               frame="#f2efe6"),
          grid("front", xc - 2.1, 2, 2.1, 10.4, 1, 2.2, (0.95, 1.6), sill=0.2, **SASH),
          grid("front", xc - 0.5, 1, 1.0, 12.6, 1, 1.9, (0.7, 1.2), sill=0.2, kind="door", glass="#7a1f1a",
               frame="#f2efe6")]
    zones = []
    for zb_ in (1.0, 2.4, 3.45, 4.4, 6.0, 6.6, 7.6, 9.2, 9.75, 11.6, 13.2):
        zones.append(dict(box=((xc - 4, xc + 4), (-1, 1), (zb_, zb_ + 0.2)), surface="#ece5d6"))
    gable_house(rig, "dbc", xc, wc, D, 10.0, "step", 5.6, dict(color=brc, kind="brick", scale=2.4), gc, zones=zones,
                trim="#f1ece0", roof_c="#4a4440", seed=13)
    bm = bmesh.new()
    lintels(bm, gc[0], 0.0, h=0.22, out=0.06, ext=0.08)
    bx(bm, xc - 0.12, xc + 0.12, -1.1, 0.4, 14.4, 14.65)
    mk(rig, "dbc_orn", bm, basic("dbc_om", "#efe9dc", rough=0.6))
    return info(20.0, 16.6, D)


def _bike(rig, name, x, y):
    """Dutch bicycle leaning upright (wheels facing the camera)."""
    bmw = bmesh.new()
    prof = [(0.33 + 0.03 * math.cos(2 * math.pi * k / 6), 0.03 * math.sin(2 * math.pi * k / 6)) for k in range(6)]
    for dx in (-0.55, 0.55):
        MU.bm_lathe(prof, segs=20, bm=bmw, axis="Y", center=(x + dx, y, 0.36))
    mk(rig, name + "_w", bmw, basic(name + "_wm", "#1c1c1c", rough=0.5))
    bm = bmesh.new()
    for (a, b) in (((x - 0.55, y, 0.36), (x - 0.05, y, 0.36)), ((x - 0.05, y, 0.36), (x + 0.45, y, 0.85)),
                   ((x - 0.55, y, 0.36), (x - 0.25, y, 0.85)), ((x - 0.25, y, 0.85), (x + 0.45, y, 0.85)),
                   ((x - 0.05, y, 0.36), (x - 0.3, y, 0.95)), ((x + 0.55, y, 0.36), (x + 0.42, y, 1.05)),
                   ((x + 0.42, y, 1.05), (x + 0.3, y, 1.08))):
        MU.bm_beam(a, b, 0.04, bm=bm)
    bx(bm, x - 0.42, x - 0.18, y - 0.06, y + 0.06, 0.95, 1.0)
    mk(rig, name + "_f", bm, basic(name + "_fm", "#2f4f6f", rough=0.4, metal=0.4))


def dutch_terrace(rig, p):
    """Dutch terraced houses (rijtjeshuizen): four brick units with big windows, wide dormers, orange
    roof tiles, low hedges and bicycles."""
    n, wu, D = 4, 5.4, 9.0
    W = n * wu
    x0, x1 = -W / 2, W / 2
    ze = 5.6
    zr = ze + (D / 2) * math.tan(math.radians(48))
    fr = dict(frame="#f7f6f2", mull=dict(v=1, h=0, w=0.07), lit=0.55)
    grids = []
    for k in range(n):
        xs = x0 + k * wu
        grids += [grid("front", xs + 0.4, 1, 3.0, 0.3, 1, 2.8, (2.4, 1.8), sill=0.55, **fr),
                  grid("front", xs + 3.5, 1, 1.5, 0.3, 1, 2.8, (1.0, 2.25), sill=0.0, kind="door",
                       glass=("#2f4a6a", "#6a2f2a", "#2f5a3a", "#3a3a3a")[k], frame="#f7f6f2"),
                  grid("front", xs + 0.5, 2, 2.2, 3.1, 1, 2.6, (1.4, 1.4), sill=0.7, **fr)]
    grids.append(grid("left", 1.2, 2, 3.3, 3.1, 1, 2.6, (1.0, 1.3), sill=0.7, **fr))
    wall = wallmat("dt_wall", dict(color="#8c4a35", kind="brick", scale=2.6), grids, seed=21,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, 0.3)), surface=dict(color="#5d5a55"))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "dt_body", bm, wall)
    roof = roofmat("dt_roof", "#b65a33", "tiles", rows=0.3)
    saddle(rig, "dt_roof", x0, x1, 0.0, D, ze, zr, roof, axis="x", over_side=0.35, over_end=0.25)
    gable_ends(rig, "dt_ge", x0, x1, 0.0, D, ze, zr, wall, axis="x")
    dormers(rig, "dt_dorm", [x0 + (k + 0.5) * wu for k in range(n)], 0.0, ze, 48.0, 3.4, 1.4,
            basic("dt_dw", "#e9e6df"), roofmat("dt_dr", "#3d3f42", "flat"), kind="flat", z_up=1.0, glass_seed=22, lit=0.55)
    trim = basic("dt_trim", "#ede9e1", rough=0.6)
    bm = bmesh.new()
    for k in range(1, n):
        bx(bm, x0 + k * wu - 0.08, x0 + k * wu + 0.08, -0.06, 0.0, 0.3, ze)
    for k in range(n):
        xs = x0 + k * wu
        bx(bm, xs + 3.35, xs + 4.85, -0.9, 0.0, 2.75, 2.85)
    mk(rig, "dt_trim", bm, trim)
    for k in range(n):
        xs = x0 + k * wu
        hedge(rig, "dt_hedge%d" % k, xs + 0.3, xs + 3.0, -2.6, -2.1, 0.9, 30 + k)
    _bike(rig, "dt_bike1", x0 + 2.2, -1.2)
    _bike(rig, "dt_bike2", x0 + 13.0, -1.0)
    return info(W + 0.7, zr + 0.3, D)


def houseboat(rig, p):
    """Amsterdam houseboat (woonboot): black steel hull, dark green wooden cabin with big windows, roof
    garden, deck with plants; anchor = waterline under the middle of the near side."""
    L, B = 16.0, 4.6
    x0, x1 = -L / 2, L / 2
    m, nb = M.new_material("hb_hull")
    x, y, z = nb.coords()
    col = nb.mix(nb.band(z, 0.62, 0.72), M.srgb("#141618"), M.srgb("#b52a22"))
    col = nb.mix(nb.lt(z, 0.12), col, M.srgb("#3d3a33"))
    hull = M.finish(m, nb, M.principled(nb, col, rough=0.45, metal=0.4, spec=0.5))
    bm = bmesh.new()
    pts = [(x0 + 0.6, 0.0), (x1 - 0.6, 0.0), (x1, 0.6), (x1, B - 0.6), (x1 - 0.6, B), (x0 + 0.6, B), (x0, B - 0.6), (x0, 0.6)]
    poly_prism_z(bm, pts, 0.0, 0.95)
    mk(rig, "hb_hull", bm, hull, bevel=0.05)
    cab = wallmat("hb_cabin", dict(color="#2f4a3c", kind="vboard", pitch=0.18, noise=0.06), [
        grid("front", x0 + 1.6, 5, 2.3, 0.95, 1, 2.5, (1.7, 1.5), sill=0.55, frame="#efece4", lit=0.75,
             mull=dict(v=1, h=0, w=0.06)),
        grid("left", 0.9, 1, 2.8, 0.95, 1, 2.5, (1.8, 1.5), sill=0.55, frame="#efece4", lit=0.75),
        grid("front", x0 + 1.6 + 5 * 2.3 - 0.1, 1, 1.1, 0.95, 1, 2.5, (0.85, 2.0), sill=0.05, kind="door",
             glass="#6a4a2a", frame="#efece4")], seed=31)
    bm = bmesh.new()
    bx(bm, x0 + 1.2, x1 - 1.6, 0.35, B - 0.35, 0.95, 3.5)
    mk(rig, "hb_cabin", bm, cab)
    trim = basic("hb_trim", "#ece8de", rough=0.6)
    bm = bmesh.new()
    bx(bm, x0 + 1.0, x1 - 1.4, 0.15, B - 0.15, 3.5, 3.68)
    bx(bm, x0 + 0.1, x1 - 0.1, -0.04, B + 0.04, 0.92, 1.0)
    mk(rig, "hb_trim", bm, trim)
    rails = Rails("hb_rail", "#1f2321", "bars", pitch=0.18, bar=0.03, h=0.8)
    rails.add_box(x0 + 1.0, x1 - 1.4, 0.15, 0.19, 3.68)
    rails.add_box(x0 + 1.0, x0 + 1.04, 0.15, B - 0.15, 3.68)
    rails.build(rig)
    for i, (px, py, r_) in enumerate([(-4.5, 1.2, 0.55), (-2.0, 2.6, 0.45), (1.5, 1.4, 0.6), (4.0, 2.2, 0.5)]):
        crown(rig, "hb_plant%d" % i, (px, py, 3.68 + r_ * 0.9), r_, r_, r_ * 0.9, 7, r_ * 0.35, r_ * 0.55,
              leaves("hb_pl%d" % i, "#3f6b28", "#6a9a3a", scale=3.0), 40 + i, disp=0.1)
    flowers(rig, "hb_fl", [(x1 - 0.8, 0.6 + 0.4 * k, 1.25) for k in range(8)] + [(x0 + 0.6, 0.8 + 0.5 * k, 1.2) for k in range(6)],
            colors=("#d6262b", "#f2c81b", "#e85a8a", "#3f6b28"), r=0.2, seed=6)
    wall_lamp(rig, "hb_lamp", [(x1 - 1.62, 0.6, 2.7)], strength=5.0)
    return info(L, 4.5, B)


# =================================================================================================
# belgian: brick terrace (Liege), Mosan Renaissance house
# =================================================================================================

def belgian_terrace(rig, p):
    """Four Liege terraced houses in different bricks (red, brown, painted white, ochre) with bluestone
    lintels and plinths, slate roof with dormers, a cafe with a dark green front."""
    n, wu, D = 4, 5.5, 10.0
    W = n * wu
    x0, x1 = -W / 2, W / 2
    ze = 9.8
    zr = ze + (D / 2) * math.tan(math.radians(45))
    fr = dict(frame="#f2f0ea", mull=dict(v=1, h=[0.7], w=0.06), lit=0.5)
    bricks = [dict(color="#9a4733", kind="brick", scale=2.6), dict(color="#6f4a35", kind="brick", scale=2.6),
              dict(color="#ebe8e0", noise=0.04), dict(color="#b38a5c", kind="brick", scale=2.6)]
    grids, zones = [], []
    for k in range(n):
        xs = x0 + k * wu
        grids += [grid("front", xs + 0.55, 2, 2.2, 3.6, 2, 3.1, (1.1, 2.0), sill=0.6, **fr)]
        if k < 3:
            grids += [grid("front", xs + 0.55, 2, 2.2, 0.0, 1, 3.6, (1.1, 2.0), sill=1.0, skip=[(0, 0)], **fr),
                      grid("front", xs + 0.55, 1, 2.2, 0.3, 1, 3.3, (1.1, 2.7), sill=0.0, kind="door",
                           glass=("#3a2a20", "#2f3f55", "#5a2a24")[k], frame="#e9e6de")]
        else:
            grids += [grid("front", xs + 0.4, 1, 3.4, 0.0, 1, 3.4, (2.9, 2.6), sill=0.4, kind="shop", frame="#1f3d2c",
                           glass="#2a3a34", color=("#ffc77a",), strength=1.0),
                      grid("front", xs + 3.8, 1, 1.4, 0.0, 1, 3.4, (1.0, 2.6), sill=0.0, kind="door", glass="#1f3d2c",
                           frame="#1f3d2c")]
        zones.append(dict(box=((xs - (1.0 if k == 0 else 0.0), xs + wu + (1.0 if k == n - 1 else 0.0)), (-99, 99),
                               (0.6, 99)), surface=bricks[k]))
    grids.append(grid("left", 1.0, 3, 2.6, 3.6, 2, 3.1, (1.0, 1.8), sill=0.6, **fr))
    wall = wallmat("bt_wall", dict(color="#5f646b", noise=0.05), grids, zones=zones, seed=41)
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "bt_body", bm, wall)
    blue = basic("bt_blue", "#61666d", rough=0.7)
    bm = bmesh.new()
    for g in grids:
        if g.get("kind", "win") == "win" and g["face"] == "front":
            lintels(bm, g, 0.0, h=0.2, out=0.05, ext=0.08, gap=0.0)
            sills(bm, g, 0.0, h=0.08, out=0.1, ext=0.06)
    bx(bm, x0 + 3 * wu + 0.2, x1 - 0.2, -0.2, 0.0, 3.35, 3.75)
    mk(rig, "bt_blue", bm, blue)
    sign = M.basic("bt_sign", "#1f3d2c", rough=0.4, emit={"lights": ("#ffd27a", 1.2)})
    bm = bmesh.new()
    bx(bm, x0 + 3 * wu + 0.6, x1 - 0.6, -0.24, -0.2, 3.4, 3.7)
    mk(rig, "bt_sign", bm, sign)
    cols = ["#f2f0ea", "#2f4a3c", "#7a2a22", "#f2f0ea"]
    for k in range(n):
        xs = x0 + k * wu
        bm = bmesh.new()
        cornice(bm, xs + 0.02, xs + wu - 0.02, 0.0, 0.3, ze - 0.45, [(0.15, 0.1), (0.2, 0.25), (0.1, 0.32)])
        for c in range(3):
            fbox(bm, "front", 0.0, xs + 0.4 + c * 2.25, xs + 0.6 + c * 2.25, ze - 0.95, ze - 0.45, 0.0, 0.22)
        mk(rig, "bt_cor%d" % k, bm, basic("bt_corm%d" % k, cols[k], rough=0.55))
    roof = roofmat("bt_roof", "#3b4046", "slate")
    saddle(rig, "bt_roof", x0, x1, 0.0, D, ze, zr, roof, axis="x", over_side=0.3, over_end=0.2)
    gable_ends(rig, "bt_ge", x0, x1, 0.0, D, ze, zr, wall, axis="x")
    dormers(rig, "bt_dorm", [x0 + (k + 0.5) * wu for k in range(n)], 0.0, ze, 45.0, 1.4, 1.5, basic("bt_dw", "#e6e3db"),
            roof, kind="gable", z_up=0.8, glass_seed=42)
    chimneys(rig, "bt_chim", [(x0 + k * wu, D * 0.55) for k in range(1, n)], zr - 1.6, zr + 0.8,
             basic("bt_chm", "#8b4a35", rough=0.8), w=0.6, d=0.6)
    return info(W + 0.6, zr + 0.8, D)


def belgian_stone(rig, p):
    """Mosan Renaissance house (Liege): red brick with limestone bands, stone cross windows, bluestone
    ground floor with an arched door, steep stepped gable and slate roof."""
    W, D = 10.0, 13.0
    x0 = -W / 2
    fr = dict(frame="#cfcabe", frame_w=0.13, mull=dict(v=1, h=[0.62], w=0.14), mull_color="#cfcabe", lit=0.5)
    zt = 10.4
    g = [grid("front", x0 + 0.6, 3, 2.93, 3.8, 2, 3.3, (1.35, 2.3), sill=0.5, **fr),
         grid("front", x0 + 0.6, 3, 2.93, 0.0, 1, 3.8, (1.35, 2.3), sill=0.9, skip=[(1, 0)], **fr),
         grid("front", -1.0, 1, 2.0, 0.0, 1, 3.6, (1.7, 3.0), sill=0.0, top="round", kind="door", glass="#3b2e24",
              frame="#cfcabe"),
         grid("front", -2.4, 2, 2.4, zt + 0.5, 1, 2.5, (1.0, 1.8), sill=0.2, **fr),
         grid("front", -0.6, 1, 1.2, zt + 3.3, 1, 1.8, (0.75, 1.2), sill=0.2, **fr),
         grid("left", 1.2, 4, 2.8, 3.8, 2, 3.3, (1.2, 2.0), sill=0.6, **fr)]
    zones = [dict(box=((-99, 99), (-99, 99), (-1, 3.6)), surface=dict(color="#7f8287", kind="ashlar", h=0.5, w=0.9,
                                                                       strength=0.5))]
    z = 4.3
    while z < zt + 6.0:
        zones.append(dict(box=((-99, 99), (-99, 99), (z, z + 0.24)), surface="#d6d1c4"))
        z += 0.95
    gable_house(rig, "bs", 0.0, W, D, zt, "step", 7.0, dict(color="#a44a34", kind="brick", scale=2.6), g, zones=zones,
                trim="#d6d1c4", roof_c="#3a3f45", roof_kind="slate", seed=51, frame="#cfcabe")
    return info(W, zt + 7.1, D)


# =================================================================================================
# paris: Haussmann blocks
# =================================================================================================

STONE = "#e4d9c2"


def _haussmann(rig, name, W, D, bays, pu, shop_kind="arch", cafe=None, seed=0, chamfer=0.0):
    """Haussmann block: rusticated shop floor + entresol, four storeys of pale limestone (pediments on the
    etage noble, continuous wrought-iron balconies on the 2nd and 5th floor, window railings between),
    main cornice, zinc mansard with dormers, chimney stacks with terracotta pots. chamfer > 0: the
    front-left corner is cut at 45 degrees (pan coupe) with its own window bay and balconies."""
    x0, x1 = -W / 2, W / 2
    c = chamfer
    zg, ze = 4.2, 6.6
    floors = [(6.6, 3.6, 2.65), (10.2, 3.2, 2.45), (13.4, 3.0, 2.3), (16.4, 2.8, 2.05)]
    zc = 19.2
    u0f = x0 + c + (W - c - bays * pu) / 2
    nside = int((D - c - 1.0) // pu)
    u0s = c + (D - c - nside * pu) / 2
    fr = dict(frame="#efe9dc", mull=dict(v=1, h=[0.36, 0.7], w=0.06), lit=0.45, glass="#2a333b")
    faces = [("front", u0f, bays, 0.0), ("left", u0s, nside, x0)]
    if c:
        faces.append(("chamfer", x0 * 0.70711 - pu / 2, 1, None))
    grids = []
    gfl = []
    for (face, u0, n, plane) in faces:
        shop = grid(face, u0, n, pu, 0.0, 1, zg, (pu * 0.74, 3.55), sill=0.15, kind="shop", frame="#20302a",
                    glass="#2e3c40", top="seg" if shop_kind == "arch" else None, rise=0.12)
        ent = grid(face, u0, n, pu, zg, 1, ze - zg, (1.3, 1.5), sill=0.45, frame="#efe9dc", lit=0.3,
                   mull=dict(v=1, h=0, w=0.06))
        fl = [grid(face, u0, n, pu, z, 1, h, (1.3, wh), sill=0.25, **fr) for (z, h, wh) in floors]
        grids += [shop, ent] + fl
        gfl.append((face, plane, fl))
    wall = wallmat(name + "_wall", dict(color=STONE, kind="ashlar", h=0.5, w=1.25, jw=0.02, strength=0.35, noise=0.05),
                   grids, zones=[dict(box=((-99, 99), (-99, 99), (-1, ze)),
                                      surface=dict(color=shade(STONE, 0.97), kind="rustic", h=0.6, w=2.4, jw=0.06))],
                   seed=seed)
    fp = chamfer_fp(x0, x1, 0.0, D, c) if c else [(x0, 0.0), (x1, 0.0), (x1, D), (x0, D)]
    ring_obj(rig, name + "_body", fp, 0.0, zc, wall)
    stone = basic(name + "_stone", shade(STONE, 1.02), rough=0.8)
    bm = bmesh.new()
    cornice_poly(bm, fp, ze - 0.35, [(0.12, 0.06), (0.15, 0.14), (0.08, 0.2)])
    for (z, h, wh) in floors[1:]:
        cornice_poly(bm, fp, z - 0.12, [(0.14, 0.07)])
    cornice_poly(bm, fp, zc - 0.2, [(0.2, 0.1), (0.15, 0.25), (0.3, 0.55), (0.12, 0.62)])
    for (face, plane, fl) in gfl:
        if plane is None:
            continue
        sills(bm, fl[1], plane, h=0.12, out=0.12)
        sills(bm, fl[2], plane, h=0.12, out=0.12)
        pediments(bm, fl[0], plane, alt=True, h=0.42, out=0.16, ext=0.2)
        lintels(bm, fl[1], plane, h=0.24, out=0.12, ext=0.16)
        surrounds(bm, fl[2], plane, w=0.12, out=0.05)
        surrounds(bm, fl[3], plane, w=0.1, out=0.05)
        # consoles under the continuous balcony of the second floor
        for (u, zc_, i, j) in centres(fl[0]):
            for sg in (-1, 1):
                fbox(bm, face, plane, u + sg * 0.95 - 0.12, u + sg * 0.95 + 0.12, 6.0, 6.55, 0.0, 0.85)
    mk(rig, name + "_stone", bm, stone)
    slab = basic(name + "_slab", shade(STONE, 0.98), rough=0.8)
    rails = Rails(name + "_rail", "#1d2020", "haussmann", pitch=0.2, bar=0.03)
    bs = bmesh.new()
    for (face, plane, fl) in gfl:
        if plane is None:
            # chamfer: rotated slabs and railings along the cut corner
            L = c * math.sqrt(2.0)
            for k in (0, 3):
                g = fl[k]
                zf = g["z0"] + g["sill"] - 0.02
                mx, my = x0 + c / 2 - 0.47 * 0.7071, c / 2 - 0.47 * 0.7071
                obox(bs, (mx, my, zf - 0.09), (L + 0.9, 0.95, 0.18), -45.0)
                rails.add_rot(x0 + c / 2 - 0.93 * 0.7071, c / 2 - 0.93 * 0.7071, L + 0.75, 0.04, -45.0, zf)
            for k in (1, 2):
                g = fl[k]
                zf = g["z0"] + g["sill"] - 0.02
                rails.add_rot(x0 + c / 2 - 0.14 * 0.7071, c / 2 - 0.14 * 0.7071, 1.5, 0.04, -45.0, zf, h=0.9)
            continue
        span = (x0 + c - 0.1, x1 + 0.1) if face == "front" else (c - 0.1, D - 0.2)
        for k in (0, 3):
            g = fl[k]
            zf = g["z0"] + g["sill"] - 0.02
            fbox(bs, face, plane, span[0], span[1], zf - 0.18, zf, 0.0, 0.95)
            rails.add(face, plane, span[0], span[1], zf, 0.91, 0.95)
        for k in (1, 2):
            g = fl[k]
            for (u, zc_, i, j) in centres(g):
                zf = g["z0"] + g["sill"] - 0.02
                rails.add(face, plane, u - 0.75, u + 0.75, zf, 0.12, 0.16, h=0.9)
    mk(rig, name + "_slab", bs, slab)
    rails.build(rig)
    zinc = roofmat(name + "_zinc", "#7d8b97", "zinc")
    if c:
        zt = mansard_poly(rig, name + "_mans", fp, zc + 0.47, 3.1, 1.25, 1.4, zinc,
                          roofmat(name + "_zinc2", "#6f7d89", "zinc"), over=0.1)
    else:
        zt = mansard(rig, name + "_mans", x0, x1, 0.0, D, zc + 0.47, 3.1, 1.25, 1.4, zinc,
                     roofmat(name + "_zinc2", "#6f7d89", "zinc"), over=0.1)
    dw = basic(name + "_dorm", "#e9e2d2", rough=0.7)
    drm = roofmat(name + "_dr", "#6f7d89", "zinc")
    dormers(rig, name + "_dorm", [q[0] for q in centres(gfl[0][2][0])], -0.1, zc + 0.47, 68.0, 1.15, 1.75, dw, drm,
            kind="seg", z_up=0.35, glass_seed=seed + 3, lit=0.45)
    dormers(rig, name + "_dorl", [q[0] for q in centres(gfl[1][2][0])], x0 - 0.1, zc + 0.47, 68.0, 1.15, 1.75, dw, drm,
            kind="seg", z_up=0.35, glass_seed=seed + 4, lit=0.45, face="left")
    chim = basic(name + "_chim", "#d9cdb5", rough=0.85)
    chimneys(rig, name + "_chim", [(x0 + 2.5 + c * 0.6, D * 0.5), (x1 - 3.0, D * 0.45), (0.0, D * 0.62)], zt, zt + 3.2,
             chim, w=1.6, d=0.7, pots="#c56a3c")
    if cafe:
        awning(rig, name + "_awn", u0f + 0.1, u0f + pu * 2 - 0.1, 0.0, 3.95, 1.7, 0.7, cafe, None)
        tb = bmesh.new()
        for k in range(4):
            xx = u0f + 0.6 + k * 1.6
            MU.bm_cyl(0.35, 0.35, 0.05, center=(xx, -2.2, 0.75), segs=12, bm=tb)
            MU.bm_cyl(0.04, 0.04, 0.72, center=(xx, -2.2, 0.37), segs=6, bm=tb)
        mk(rig, name + "_tables", tb, basic(name + "_tbm", "#2b2b2b", rough=0.4, metal=0.6))
    return info(W + 1.3, zt + 3.5, D)


def paris_haussmann(rig, p):
    return _haussmann(rig, "phm", 22.4, 15.0, 6, 3.6, cafe="#8a1f24", seed=1)


def paris_haussmann_corner(rig, p):
    """Haussmann corner block with a cut corner (pan coupe) facing the road."""
    return _haussmann(rig, "phc", 21.0, 18.0, 4, 3.6, seed=5, chamfer=4.2)


# =================================================================================================
# french: Loire stone house with shutters, southern house with canal tiles, Lyon town house
# =================================================================================================

def french_maison(rig, p):
    """Loire house: pale tuffeau stone with quoins, tall windows with blue-grey shutters, steep slate roof,
    stone dormers with pediments, tall chimneys at the gable ends, garden wall with hydrangeas."""
    W, D = 12.0, 9.0
    x0, x1 = -W / 2, W / 2
    ze = 6.4
    zr = ze + (D / 2) * math.tan(math.radians(50))
    fr = dict(frame="#f2efe8", mull=dict(v=1, h=[0.36, 0.7], w=0.05), shutters="#8ea3ad", lit=0.45)
    tuf = dict(color="#ebe3cc", kind="ashlar", h=0.45, w=0.9, strength=0.25, noise=0.05)
    g = [grid("front", -5.4, 3, 3.6, 0.0, 1, 3.3, (1.2, 2.0), sill=0.75, skip=[(1, 0)], **fr),
         grid("front", -5.4, 3, 3.6, 3.3, 1, 3.1, (1.2, 1.75), sill=0.65, **fr),
         grid("front", -0.7, 1, 1.4, 0.0, 1, 3.3, (1.15, 2.4), sill=0.15, kind="door", glass="#5b6f7a", frame="#f2efe8"),
         grid("left", 2.0, 2, 2.5, 0.0, 2, 3.25, (1.1, 1.7), sill=0.8, **fr)]
    wall = wallmat("fm_wall", tuf, g, seed=61)
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "fm_body", bm, wall)
    slate = roofmat("fm_slate", "#454b52", "slate")
    saddle(rig, "fm_roof", x0, x1, 0.0, D, ze, zr, slate, axis="x", over_side=0.35, over_end=0.15)
    gable_ends(rig, "fm_ge", x0, x1, 0.0, D, ze, zr, wall, axis="x")
    st = basic("fm_stone", "#efe8d5", rough=0.8)
    dormers(rig, "fm_dorm", [-3.6, 3.6], 0.0, ze, 50.0, 1.25, 1.6, st, slate, kind="gable", z_up=0.15, glass_seed=62)
    bm = bmesh.new()
    quoins(bm, "front", 0.0, x0, 0.0, ze, h=0.45, w0=0.7, w1=0.4)
    quoins(bm, "left", x0, 0.0, 0.0, ze, h=0.45, w0=0.7, w1=0.4)
    cornice(bm, x0, x1, 0.0, D, ze - 0.25, [(0.12, 0.08), (0.13, 0.18)])
    sills(bm, g[0], 0.0, h=0.08, out=0.1)
    sills(bm, g[1], 0.0, h=0.08, out=0.1)
    mk(rig, "fm_orn", bm, st)
    chimneys(rig, "fm_chim", [(x0 + 0.6, D / 2), (x1 - 0.6, D / 2)], zr - 1.0, zr + 1.6, st, w=1.0, d=0.6)
    fence(rig, "fm_wall2", [((x0 - 1.0, -4.5), (-1.3, -4.5)), ((1.3, -4.5), (x1 + 1.0, -4.5)), ((x0 - 1.0, -4.5), (x0 - 1.0, D))],
          h=1.1, kind="wall", color="#e3dac2", post_color="#d6ccb3")
    fence(rig, "fm_gate", [((-1.3, -4.5), (1.3, -4.5))], h=1.25, kind="metal", color="#2b3530", pitch=0.13)
    for i, (hx, hy) in enumerate([(-4.2, -0.9), (-2.6, -1.0), (2.6, -1.0), (4.2, -0.9)]):
        crown(rig, "fm_hyd%d" % i, (hx, hy, 0.55), 0.7, 0.55, 0.55, 9, 0.3, 0.45, leaves("fm_hl%d" % i, "#3f6526", "#557f31"),
              60 + i, disp=0.08, flat_bottom=-0.45)
        flowers(rig, "fm_hf%d" % i, [(hx + 0.5 * math.cos(a), hy - 0.35 + 0.25 * math.sin(a), 0.75 + 0.25 * math.sin(2 * a))
                                     for a in [k * 0.9 for k in range(7)]], colors=("#7f8fd6", "#c47ab5"), r=0.2, seed=i)
    tree(rig, "fm_tree", x0 - 3.0, 2.0, 6.5, 2.2, 63)
    return info(W + 4.6, zr + 1.7, D)


def french_sud(rig, p):
    """Southern French house: ochre-pink render, lavender-blue shutters, low roof with canal tiles and a
    genoise eave, wrought-iron balcony, garden wall, plane tree and oleanders."""
    W, D = 12.0, 10.0
    x0, x1 = -W / 2, W / 2
    ze = 6.1
    zr = ze + (D / 2) * math.tan(math.radians(17))
    fr = dict(frame="#f4f0e6", mull=dict(v=1, h=[0.5], w=0.05), shutters="#7f95b8", lit=0.45)
    g = [grid("front", -5.4, 3, 3.6, 0.0, 1, 3.1, (1.15, 1.9), sill=0.8, skip=[(1, 0)], **fr),
         grid("front", -5.4, 3, 3.6, 3.1, 1, 3.0, (1.15, 1.8), sill=0.55, **fr),
         grid("front", -0.65, 1, 1.3, 0.0, 1, 3.1, (1.1, 2.3), sill=0.1, kind="door", glass="#6e4a2e", frame="#f4f0e6"),
         grid("left", 1.8, 2, 3.2, 0.0, 2, 3.05, (1.05, 1.6), sill=0.8, **fr)]
    wall = wallmat("fs_wall", dict(color="#e8b98c", noise=0.09), g, seed=71,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, 0.45)), surface=dict(color="#c9946a", noise=0.1))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "fs_body", bm, wall)
    tiles = roofmat("fs_tiles", "#b9653d", "canal", rows=0.38)
    saddle(rig, "fs_roof", x0, x1, 0.0, D, ze, zr, tiles, axis="x", over_side=0.55, over_end=0.35)
    gable_ends(rig, "fs_ge", x0, x1, 0.0, D, ze, zr, wall, axis="x")
    # genoise: rows of tile ends under the eave (front + left)
    gm = basic("fs_gen", "#c06a40", rough=0.8)
    bm = bmesh.new()
    for r_, (zz, out) in enumerate(((ze - 0.12, 0.28), (ze - 0.28, 0.16))):
        n = int(W / 0.24)
        for k in range(n):
            xx = x0 + (k + 0.5) * W / n + (0.12 if r_ else 0.0)
            if xx < x1:
                MU.bm_cyl(0.09, 0.09, out, center=(xx, -out / 2, zz), axis="Y", segs=8, bm=bm)
    mk(rig, "fs_genoise", bm, gm)
    bm = bmesh.new()
    bx(bm, x0 - 0.05, x1 + 0.05, -0.06, D, ze - 0.42, ze - 0.36)
    mk(rig, "fs_genb", bm, basic("fs_genw", "#efe3cf", rough=0.8))
    slab = basic("fs_slab", "#e1d7c4", rough=0.8)
    bm = bmesh.new()
    bx(bm, -1.7, 1.7, -0.75, 0.0, 3.5, 3.65)
    mk(rig, "fs_balc", bm, slab)
    rails = Rails("fs_rail", "#1f2321", "haussmann", pitch=0.2, bar=0.03)
    rails.add_box(-1.7, 1.7, -0.75, -0.71, 3.65, 0.95)
    rails.add_box(-1.7, -1.66, -0.75, 0.0, 3.65, 0.95)
    rails.add_box(1.66, 1.7, -0.75, 0.0, 3.65, 0.95)
    rails.build(rig)
    fence(rig, "fs_wall2", [((x0 - 1.5, -5.0), (-1.4, -5.0)), ((1.4, -5.0), (x1 + 1.0, -5.0)),
                            ((x0 - 1.5, -5.0), (x0 - 1.5, D))], h=1.6, kind="wall", color="#e3b48a", post_color="#efe3cf")
    fence(rig, "fs_gate", [((-1.4, -5.0), (1.4, -5.0))], h=1.5, kind="metal", color="#3d5a8a", pitch=0.12)
    tree(rig, "fs_plane", x0 - 3.2, -1.0, 8.5, 3.0, 72, c1="#5d7f2e", c2="#86a84a", bark_c=("#a39a80", "#7d7460"))
    for i, (ox, oy) in enumerate([(-4.3, -1.2), (4.4, -1.2)]):
        crown(rig, "fs_ol%d" % i, (ox, oy, 0.9), 0.75, 0.6, 0.9, 12, 0.3, 0.45, leaves("fs_oll%d" % i, "#3f6526", "#5d7f35"),
              70 + i, disp=0.08, flat_bottom=-0.8)
        flowers(rig, "fs_olf%d" % i, [(ox + 0.6 * math.cos(a), oy - 0.45 + 0.3 * math.sin(a), 1.2 + 0.5 * math.sin(2 * a))
                                      for a in [k * 0.8 for k in range(8)]], colors=("#e75a9a", "#f2f0f0"), r=0.15, seed=i)
    bp = bmesh.new()
    for xx in (-2.8, 2.8):
        MU.bm_cyl(0.32, 0.22, 0.6, center=(xx, -0.5, 0.3), segs=12, bm=bp)
    mk(rig, "fs_pots", bp, basic("fs_potm", "#b8603a", rough=0.8))
    return info(W + 7.0, 8.5, D)


def french_immeuble(rig, p):
    """Lyon town house: ochre render, tall windows with grey-green shutters and iron railings, a balcony on
    the first floor, slate mansard with dormers, a bakery with a blue front and awning."""
    W, D = 16.0, 12.0
    x0, x1 = -W / 2, W / 2
    fl = [(4.0, 3.4, 2.4), (7.4, 3.2, 2.25), (10.6, 3.1, 2.15)]
    ze = 13.7
    fr = dict(frame="#f1ece2", mull=dict(v=1, h=[0.4, 0.72], w=0.05), shutters="#7d8f86", shutter_w=0.48, lit=0.45)
    g = [grid("front", -7.2, 5, 2.88, z, 1, h, (1.15, wh), sill=0.35, **fr) for (z, h, wh) in fl]
    g += [grid("left", 1.2, 3, 3.2, z, 1, h, (1.1, wh), sill=0.35, **fr) for (z, h, wh) in fl]
    g += [grid("front", -7.2, 2, 2.88, 0.0, 1, 4.0, (2.4, 3.0), sill=0.3, kind="shop", frame="#264a73",
               glass="#2c3f4f"),
          grid("front", -1.44, 1, 2.88, 0.0, 1, 4.0, (1.3, 3.0), sill=0.0, kind="door", glass="#3a2c24", frame="#e5dccb"),
          grid("front", 1.44, 2, 2.88, 0.0, 1, 4.0, (2.0, 2.8), sill=0.5, kind="shop", frame="#6a4a34", glass="#2c3f4f")]
    wall = wallmat("fi_wall", dict(color="#e3b06e", noise=0.08), g, seed=81,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, 4.0)), surface=dict(color="#d9c8a6", kind="ashlar", h=0.55,
                                                                                    w=1.2, strength=0.4))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "fi_body", bm, wall)
    st = basic("fi_stone", "#ece4d2", rough=0.8)
    bm = bmesh.new()
    cornice(bm, x0, x1, 0.0, D, 3.85, [(0.15, 0.08)])
    cornice(bm, x0, x1, 0.0, D, ze - 0.3, [(0.12, 0.08), (0.12, 0.2), (0.2, 0.36)])
    for gg in g[:6]:
        plane = 0.0 if gg["face"] == "front" else x0
        surrounds(bm, gg, plane, w=0.12, out=0.05)
        sills(bm, gg, plane, h=0.1, out=0.1)
    quoins(bm, "front", 0.0, x0, 4.0, ze - 0.3, h=0.5, w0=0.6, w1=0.35)
    quoins(bm, "left", x0, 0.0, 4.0, ze - 0.3, h=0.5, w0=0.6, w1=0.35)
    mk(rig, "fi_orn", bm, st)
    rails = Rails("fi_rail", "#1e2221", "bars", pitch=0.11, bar=0.025)
    bs = bmesh.new()
    zf = fl[0][0] + 0.35 - 0.02
    bx(bs, -4.6, 4.6, -0.85, 0.0, zf - 0.16, zf)
    rails.add_box(-4.6, 4.6, -0.85, -0.81, zf, 1.0)
    for sx in (-4.6, 4.56):
        rails.add_box(sx, sx + 0.04, -0.85, 0.0, zf, 1.0)
    for gg in g[1:6]:
        if gg is g[3]:
            continue
        plane = 0.0 if gg["face"] == "front" else x0
        for (u, zc, i, j) in centres(gg):
            zb = zc - gg["win"][1] / 2
            rails.add(gg["face"], plane, u - 0.7, u + 0.7, zb, 0.1, 0.14, h=0.85)
    mk(rig, "fi_balc", bs, st)
    rails.build(rig)
    zt = mansard(rig, "fi_mans", x0, x1, 0.0, D, ze + 0.14, 3.0, 1.2, 1.2, roofmat("fi_slate", "#4b5157", "slate"),
                 roofmat("fi_zinc", "#6f7a84", "zinc"), over=0.12)
    dormers(rig, "fi_dorm", [q[0] for q in centres(g[0])], -0.12, ze + 0.14, 68.0, 1.1, 1.6, st,
            roofmat("fi_dr", "#4b5157", "zinc"), kind="gable", z_up=0.35, glass_seed=82)
    awning(rig, "fi_awn", -7.0, -1.6, 0.0, 3.85, 1.4, 0.6, "#2c5f9a", "#f1ece2", stripe=0.35)
    sign = M.basic("fi_sign", "#264a73", rough=0.4, emit={"lights": ("#ffe2a8", 1.1)})
    bm = bmesh.new()
    bx(bm, -7.0, -1.6, -0.12, 0.0, 3.35, 3.75)
    mk(rig, "fi_sign", bm, sign)
    chimneys(rig, "fi_chim", [(-5.0, D * 0.5), (5.0, D * 0.55)], zt, zt + 2.6, st, w=1.2, d=0.6, pots="#c56a3c")
    return info(W + 0.8, zt + 3.2, D)


# =================================================================================================
# spanish: residential block with balconies and blinds, white house, Madrid brick building
# =================================================================================================

def spanish_block(rig, p):
    """Madrid / Barcelona residential block: cream render, a balcony with an iron railing at every window,
    green roller blinds, air conditioners and plants, shops below, set-back penthouse with tiles."""
    W, D = 20.0, 16.0
    x0, x1 = -W / 2, W / 2
    zg, pz, n = 4.2, 3.0, 6
    ze = zg + pz * n
    fr = dict(frame="#f1ede4", mull=dict(v=1, h=[0.72], w=0.05), blind="#3b6450", blind_max=0.85, lit=0.45)
    gf = grid("front", -9.6, 7, 2.74, zg, n, pz, (1.15, 2.25), sill=0.1, **fr)
    gs = grid("left", 1.0, 5, 2.8, zg, n, pz, (1.1, 2.25), sill=0.1, **fr)
    shops = [grid("front", -9.6, 4, 4.8, 0.0, 1, zg, (3.6, 3.1), sill=0.4, kind="shop", frame="#2a2d30", glass="#2f3c44"),
             grid("left", 1.0, 3, 4.6, 0.0, 1, zg, (3.4, 3.1), sill=0.4, kind="shop", frame="#2a2d30", glass="#2f3c44")]
    wall = wallmat("sb_wall", dict(color="#ead6b2", noise=0.07), [gf, gs] + shops, seed=91,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zg)), surface=dict(color="#c3ab88", kind="ashlar", h=0.6,
                                                                                  w=1.4, strength=0.45))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze + 0.9)
    mk(rig, "sb_body", bm, wall)
    slab = basic("sb_slab", "#ddd2bf", rough=0.8)
    rails = Rails("sb_rail", "#1d2020", "bars", pitch=0.12, bar=0.028)
    bs = bmesh.new()
    balconies(bs, rails, gf, 0.0, None, depth=0.65, ext=0.25, rail_h=1.0)
    balconies(bs, rails, gs, x0, None, depth=0.65, ext=0.25, rail_h=1.0)
    cornice(bs, x0, x1, 0.0, D, zg - 0.35, [(0.2, 0.12), (0.15, 0.25)])
    cornice(bs, x0, x1, 0.0, D, ze - 0.1, [(0.15, 0.1), (0.2, 0.3)])
    mk(rig, "sb_slab", bs, slab)
    rails.build(rig)
    # air conditioners and plants on some balconies
    rng = random.Random(9)
    ba, bpl = bmesh.new(), []
    for (u, zc, i, j) in centres(gf):
        r = rng.random()
        zf = zc - 2.25 / 2
        if r < 0.25:
            bx(ba, u + 0.25, u + 1.0, -0.55, -0.25, zf, zf + 0.55)
        elif r < 0.5:
            bpl.append((u - 0.55, -0.45, zf + 0.25))
    mk(rig, "sb_ac", ba, basic("sb_acm", "#d9dad6", rough=0.4))
    flowers(rig, "sb_plants", bpl, colors=("#3f6b28", "#d6262b"), r=0.25, seed=4)
    # set-back penthouse (atico)
    pt = wallmat("sb_atico", dict(color="#efe2c8", noise=0.05), [
        grid("front", -7.5, 5, 3.0, ze + 0.9, 1, 3.0, (1.6, 2.2), sill=0.1, **fr),
        grid("left", 3.0, 3, 3.3, ze + 0.9, 1, 3.0, (1.4, 2.2), sill=0.1, **fr)], seed=92)
    bm = bmesh.new()
    bx(bm, x0 + 2.5, x1 - 2.5, 2.5, D - 2.0, ze + 0.9, ze + 3.9)
    mk(rig, "sb_atico", bm, pt)
    hip(rig, "sb_atr", x0 + 2.5, x1 - 2.5, 2.5, D - 2.0, ze + 3.9, ze + 5.6, roofmat("sb_tiles", "#b5603a", "canal"),
        over=0.4)
    rails2 = Rails("sb_rail2", "#1d2020", "bars", pitch=0.12, bar=0.028)
    rails2.add_box(x0 + 0.1, x1 - 0.1, 0.1, 0.14, ze + 0.9)
    rails2.add_box(x0 + 0.1, x0 + 0.14, 0.1, D - 0.1, ze + 0.9)
    rails2.build(rig)
    return info(W + 0.6, ze + 5.6, D)


def spanish_casa(rig, p):
    """White Spanish house: whitewashed walls with ochre trim, low canal-tile roof, iron window grilles
    (rejas), balcony, arched wooden door, white garden wall with geraniums and an orange tree."""
    W, D = 12.0, 10.0
    x0, x1 = -W / 2, W / 2
    ze = 6.0
    zr = ze + (D / 2) * math.tan(math.radians(19))
    fr = dict(frame="#5d3a24", mull=dict(v=1, h=0, w=0.06), lit=0.45, blind="#7a5a3a", blind_max=0.5)
    g = [grid("front", -5.4, 3, 3.6, 0.0, 1, 3.0, (1.1, 1.5), sill=0.95, skip=[(1, 0)], **fr),
         grid("front", -5.4, 3, 3.6, 3.0, 1, 3.0, (1.1, 1.9), sill=0.35, **fr),
         grid("front", -0.8, 1, 1.6, 0.0, 1, 3.0, (1.3, 2.5), sill=0.0, top="round", kind="door", glass="#6b4423",
              frame="#d9a85e"),
         grid("left", 2.0, 2, 3.0, 0.0, 2, 3.0, (1.0, 1.4), sill=0.95, **fr)]
    zones = [dict(box=((-99, 99), (-99, 99), (-1, 0.55)), surface=dict(color="#d3a15c", noise=0.08)),
             dict(box=((-99, 99), (-99, 99), (5.75, 6.1)), surface="#d3a15c")]
    wall = wallmat("sc_wall", dict(color="#f5f2ea", noise=0.04), g, zones=zones, seed=101)
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "sc_body", bm, wall)
    tiles = roofmat("sc_tiles", "#b8613b", "canal", rows=0.36)
    saddle(rig, "sc_roof", x0, x1, 0.0, D, ze, zr, tiles, axis="x", over_side=0.45, over_end=0.3)
    gable_ends(rig, "sc_ge", x0, x1, 0.0, D, ze, zr, wall, axis="x")
    ochre = basic("sc_ochre", "#d3a15c", rough=0.8)
    bm = bmesh.new()
    for gg, plane in ((g[0], 0.0), (g[1], 0.0), (g[3], x0)):
        surrounds(bm, gg, plane, w=0.16, out=0.03)
    mk(rig, "sc_trim", bm, ochre)
    rails = Rails("sc_reja", "#1b1c1c", "bars", pitch=0.12, bar=0.03)
    for (u, zc, i, j) in centres(g[0]):
        rails.add("front", 0.0, u - 0.7, u + 0.7, zc - 0.85, 0.12, 0.16, h=1.7)
    for (u, zc, i, j) in centres(g[3]):
        if zc < 3.0:
            rails.add("left", x0, u - 0.62, u + 0.62, zc - 0.8, 0.12, 0.16, h=1.6)
    rails.build(rig)
    bs = bmesh.new()
    bx(bs, -1.5, 1.5, -0.7, 0.0, 3.2, 3.35)
    mk(rig, "sc_balc", bs, ochre)
    r2 = Rails("sc_rail", "#1b1c1c", "bars", pitch=0.12, bar=0.03)
    r2.add_box(-1.5, 1.5, -0.7, -0.66, 3.35, 0.95)
    r2.add_box(-1.5, -1.46, -0.7, 0.0, 3.35, 0.95)
    r2.add_box(1.46, 1.5, -0.7, 0.0, 3.35, 0.95)
    r2.build(rig)
    fence(rig, "sc_wall2", [((x0 - 1.0, -4.5), (-1.5, -4.5)), ((1.5, -4.5), (x1 + 1.0, -4.5)),
                            ((x0 - 1.0, -4.5), (x0 - 1.0, D))], h=1.5, kind="wall", color="#f3f0e8", post_color="#d3a15c")
    fence(rig, "sc_gate", [((-1.5, -4.5), (1.5, -4.5))], h=1.6, kind="metal", color="#1b1c1c", pitch=0.12)
    flowers(rig, "sc_ger", [(x0 - 0.5 + 0.6 * k, -4.5, 1.65) for k in range(8)] + [(2.0 + 0.6 * k, -4.5, 1.65) for k in range(6)],
            colors=("#d6262b", "#e2477a", "#3f6b28"), r=0.2, seed=8)
    tree(rig, "sc_orange", x0 - 3.2, -1.5, 4.2, 1.6, 103, c1="#2f5a1f", c2="#4c7a2a")
    flowers(rig, "sc_oranges", [(x0 - 3.2 + 1.1 * math.cos(a), -1.5 + 1.0 * math.sin(a), 3.0 + 0.5 * math.sin(3 * a))
                                for a in [0.35 * k for k in range(18)]], colors=("#f08a1c",), r=0.1, seed=5)
    return info(W + 6.0, zr + 0.2, D)


def spanish_ladrillo(rig, p):
    """Madrid brick building (neo-Mudejar): red brick with cream stone surrounds, quoins and bands, iron
    balconies at every window, slate mansard with dormers and a slate spire on the corner."""
    W, D = 18.0, 14.0
    x0, x1 = -W / 2, W / 2
    zg, pz, n = 4.0, 3.3, 4
    ze = zg + pz * n
    fr = dict(frame="#f0ebe0", mull=dict(v=1, h=[0.7], w=0.05), lit=0.45, blind="#5b3f2a", blind_max=0.6)
    gf = grid("front", -8.1, 6, 2.7, zg, n, pz, (1.15, 2.35), sill=0.12, **fr)
    gs = grid("left", 1.6, 4, 2.9, zg, n, pz, (1.1, 2.35), sill=0.12, **fr)
    shops = [grid("front", -8.1, 6, 2.7, 0.0, 1, zg, (2.0, 3.0), sill=0.35, kind="shop", frame="#3a2a20",
                  glass="#2f3c44", skip=[(2, 0)]),
             grid("front", -2.7, 1, 2.7, 0.0, 1, zg, (1.5, 3.2), sill=0.0, top="round", kind="door", glass="#4a3020",
                  frame="#e5dcc6")]
    wall = wallmat("sl_wall", dict(color="#b2553b", kind="brick", scale=2.6), [gf, gs] + shops, seed=111,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zg)), surface=dict(color="#d9ceb8", kind="rustic", h=0.55))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "sl_body", bm, wall)
    st = basic("sl_stone", "#e8dfca", rough=0.8)
    bm = bmesh.new()
    surrounds(bm, gf, 0.0, w=0.18, out=0.05)
    surrounds(bm, gs, x0, w=0.18, out=0.05)
    pediments(bm, gf, 0.0, rows=[0], kind="tri", h=0.4, out=0.14)
    quoins(bm, "front", 0.0, x1 - 0.7, zg, ze, h=0.5, w0=0.7, w1=0.45)
    quoins(bm, "left", x0, 0.0, zg, ze, h=0.5, w0=0.7, w1=0.45)
    cornice(bm, x0, x1, 0.0, D, zg - 0.3, [(0.18, 0.1), (0.15, 0.22)])
    cornice(bm, x0, x1, 0.0, D, ze - 0.3, [(0.15, 0.1), (0.15, 0.25), (0.25, 0.5)])
    mk(rig, "sl_orn", bm, st)
    rails = Rails("sl_rail", "#1d1f1f", "bars", pitch=0.12, bar=0.028)
    bs = bmesh.new()
    balconies(bs, rails, gf, 0.0, None, depth=0.55, ext=0.22, rail_h=1.0, slab=0.14)
    balconies(bs, rails, gs, x0, None, depth=0.55, ext=0.22, rail_h=1.0, slab=0.14)
    mk(rig, "sl_slab", bs, st)
    rails.build(rig)
    slate = roofmat("sl_slate", "#40464d", "slate")
    mansard(rig, "sl_mans", x0, x1, 0.0, D, ze + 0.15, 3.2, 1.2, 1.4, slate, roofmat("sl_zinc", "#5d656d", "zinc"),
            over=0.4)
    dormers(rig, "sl_dorm", [q[0] for q in centres(gf)][1:], -0.4, ze + 0.15, 69.0, 1.1, 1.5, st, slate, kind="gable",
            z_up=0.4, glass_seed=112)
    turret(rig, "sl_spire", x0 + 0.4, 0.4, 2.0, ze + 0.15, ze + 4.6, wall, slate, kind="helm", roof_h=7.5, corbel=0.2,
           win=(0.7, 1.3, [ze + 2.3]), seed=11, finial="#2b2d2f")
    return info(W + 1.0, ze + 13.0, D)


# =================================================================================================
# italian: Renaissance palazzo, residential block with persiane, Venetian houses
# =================================================================================================

def _funnel_chimney(bm, x, y, z0, h=2.6):
    """Venetian chimney: shaft with an inverted-cone (funnel) top."""
    prof = [(0.0, z0), (0.32, z0), (0.32, z0 + h * 0.55), (0.78, z0 + h * 0.92), (0.82, z0 + h), (0.0, z0 + h)]
    MU.bm_lathe(prof, segs=12, bm=bm, center=(x, y, 0.0))


def italian_palazzo(rig, p):
    """Renaissance palazzo: rusticated ground floor with a round-arched portal, piano nobile with alternating
    pediments and a balustraded balcony, second floor with green shutters, attic windows, deep cornicione
    on modillions, low hip roof with canal tiles, rusticated quoins."""
    W, D = 24.0, 18.0
    x0, x1 = -W / 2, W / 2
    zg, zn, z2, za = 6.0, 11.5, 16.0, 18.2
    fr = dict(frame="#efe6d2", mull=dict(v=1, h=[0.62], w=0.06), lit=0.45)
    u0, pu, n = -11.2, 3.2, 7
    g = [grid("front", u0, n, pu, 0.0, 1, zg, (1.0, 1.4), sill=2.6, skip=[(3, 0)], frame="#cbbd9f",
              mull=dict(v=2, h=1, w=0.05), lit=0.35),
         grid("front", -1.6, 1, 3.2, 0.0, 1, zg, (2.6, 4.6), sill=0.0, top="round", kind="door", glass="#4a3020",
              frame="#cbbd9f"),
         grid("front", u0, n, pu, zg, 1, zn - zg, (1.5, 3.0), sill=1.0, **fr),
         grid("front", u0, n, pu, zn, 1, z2 - zn, (1.3, 2.4), sill=0.8, shutters="#3f6b47", **fr),
         grid("front", u0, n, pu, z2, 1, za - z2, (0.9, 0.9), sill=0.6, **fr),
         grid("left", 1.0, 5, pu, 0.0, 1, zg, (1.0, 1.4), sill=2.6, frame="#cbbd9f", mull=dict(v=2, h=1, w=0.05), lit=0.35),
         grid("left", 1.0, 5, pu, zg, 1, zn - zg, (1.5, 3.0), sill=1.0, **fr),
         grid("left", 1.0, 5, pu, zn, 1, z2 - zn, (1.3, 2.4), sill=0.8, shutters="#3f6b47", **fr),
         grid("left", 1.0, 5, pu, z2, 1, za - z2, (0.9, 0.9), sill=0.6, **fr)]
    wall = wallmat("ip_wall", dict(color="#d9a568", noise=0.08), g, seed=121,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zg)), surface=dict(color="#c9b99a", kind="rustic", h=0.75,
                                                                                  w=1.6, jw=0.08))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, za)
    mk(rig, "ip_body", bm, wall)
    st = basic("ip_stone", "#d3c5a6", rough=0.8)
    bm = bmesh.new()
    cornice(bm, x0, x1, 0.0, D, zg - 0.2, [(0.25, 0.12), (0.15, 0.22)])
    cornice(bm, x0, x1, 0.0, D, zn + 0.1, [(0.2, 0.1)])
    for (gg, plane) in ((g[2], 0.0), (g[6], x0)):
        pediments(bm, gg, plane, alt=True, h=0.5, out=0.18, ext=0.22)
        surrounds(bm, gg, plane, w=0.16, out=0.07)
        sills(bm, gg, plane, h=0.14, out=0.16)
    for (gg, plane) in ((g[3], 0.0), (g[7], x0), (g[4], 0.0), (g[8], x0)):
        surrounds(bm, gg, plane, w=0.13, out=0.05)
    quoins(bm, "front", 0.0, x0, zg, za, h=0.6, w0=1.1, w1=0.7, out=0.08)
    quoins(bm, "left", x0, 0.0, zg, za, h=0.6, w0=1.1, w1=0.7, out=0.08)
    quoins(bm, "front", 0.0, x1 - 1.1, zg, za, h=0.6, w0=1.1, w1=1.1, out=0.08)
    zc = cornice(bm, x0, x1, 0.0, D, za, [(0.25, 0.12), (0.2, 0.3), (0.35, 0.75), (0.3, 1.25), (0.15, 1.35)])
    for k in range(int(W / 0.8)):
        xx = x0 + 0.4 + k * 0.8
        bx(bm, xx - 0.12, xx + 0.12, -0.95, 0.0, za + 0.45, za + 0.8)
    for k in range(int(D / 0.8)):
        yy = 0.4 + k * 0.8
        bx(bm, x0 - 0.95, x0, yy - 0.12, yy + 0.12, za + 0.45, za + 0.8)
    # balcony over the portal
    bx(bm, -2.4, 2.4, -1.1, 0.0, zg + 0.75, zg + 0.95)
    for xx in (-2.0, 2.0):
        bx(bm, xx - 0.2, xx + 0.2, -1.0, 0.0, zg - 0.5, zg + 0.75)
    mk(rig, "ip_stone", bm, st)
    bal = Rails("ip_bal", "#ddd0b3", "balusters", pitch=0.3, h=0.95)
    bal.add_box(-2.4, 2.4, -1.1, -0.9, zg + 0.95)
    bal.add_box(-2.4, -2.2, -1.1, 0.0, zg + 0.95)
    bal.add_box(2.2, 2.4, -1.1, 0.0, zg + 0.95)
    bal.build(rig)
    hip(rig, "ip_roof", x0, x1, 0.0, D, zc - 0.1, zc + 3.2, roofmat("ip_tiles", "#b4613f", "canal", rows=0.4), over=1.2)
    chimneys(rig, "ip_chim", [(-6.0, D * 0.55), (6.0, D * 0.5)], zc + 1.0, zc + 3.8, basic("ip_chm", "#c79a6a", rough=0.8),
             w=0.8, d=0.8)
    return info(W + 2.7, zc + 3.8, D)


def italian_block(rig, p):
    """Milan / Italian residential block: terracotta render, french windows with green persiane, iron balconies,
    flower boxes, shops with awnings, low canal-tile roof with rafters under a deep overhang."""
    W, D = 18.0, 13.0
    x0, x1 = -W / 2, W / 2
    zg, pz, n = 4.0, 3.1, 5
    ze = zg + pz * n
    fr = dict(frame="#efe8dc", mull=dict(v=1, h=[0.7], w=0.05), shutters="#3e6b45", shutter_w=0.5, lit=0.45)
    gf = grid("front", -8.7, 6, 2.9, zg, n, pz, (1.15, 2.25), sill=0.15, **fr)
    gs = grid("left", 1.2, 4, 2.7, zg, n, pz, (1.05, 2.2), sill=0.15, **fr)
    shops = [grid("front", -8.7, 3, 5.8, 0.0, 1, zg, (4.2, 3.0), sill=0.35, kind="shop", frame="#2c2a26", glass="#2e3b42")]
    wall = wallmat("ib_wall", dict(color="#d98f5a", noise=0.09), [gf, gs] + shops, seed=131,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zg)), surface=dict(color="#cdb79a", kind="ashlar", h=0.5,
                                                                                  w=1.0, strength=0.4))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "ib_body", bm, wall)
    st = basic("ib_st", "#e4d6bd", rough=0.8)
    rails = Rails("ib_rail", "#1e2120", "bars", pitch=0.12, bar=0.028)
    bs = bmesh.new()
    balconies(bs, rails, gf, 0.0, [0, 2, 4], depth=0.6, ext=0.2, rail_h=1.0, slab=0.14)
    balconies(bs, rails, gs, x0, [0, 2, 4], depth=0.6, ext=0.2, rail_h=1.0, slab=0.14)
    sills(bs, gf, 0.0, rows=[1, 3], h=0.12, out=0.35)
    cornice(bs, x0, x1, 0.0, D, zg - 0.3, [(0.2, 0.1), (0.12, 0.2)])
    for k in range(1, n):
        cornice(bs, x0, x1, 0.0, D, zg + k * pz - 0.1, [(0.12, 0.06)])
    mk(rig, "ib_slab", bs, st)
    rails.build(rig)
    pts = []
    for (u, zc, i, j) in centres(gf):
        if j in (1, 3):
            pts += [(u - 0.4 + 0.27 * k, -0.25, zc - 2.25 / 2 + 0.05) for k in range(4)]
    flowers(rig, "ib_fl", pts, colors=("#d6262b", "#e2477a", "#3f6b28"), r=0.14, seed=13)
    hip(rig, "ib_roof", x0, x1, 0.0, D, ze, ze + 2.4, roofmat("ib_tiles", "#b3603d", "canal", rows=0.38), over=1.0)
    bm = bmesh.new()
    for k in range(int(W / 0.7)):
        xx = x0 + 0.35 + k * 0.7
        bx(bm, xx - 0.07, xx + 0.07, -0.95, 0.0, ze - 0.38, ze - 0.2)
    for k in range(int(D / 0.7)):
        yy = 0.35 + k * 0.7
        bx(bm, x0 - 0.95, x0, yy - 0.07, yy + 0.07, ze - 0.38, ze - 0.2)
    mk(rig, "ib_rafters", bm, basic("ib_wood", "#5a3c26", rough=0.7))
    for k in range(3):
        xa = -8.7 + k * 5.8 + 0.4
        awning(rig, "ib_awn%d" % k, xa, xa + 5.0, 0.0, 3.6, 1.3, 0.55, ("#2f6b45", "#8a1f24", "#2f6b45")[k], "#f1ece2",
               stripe=0.4)
    return info(W + 2.0, ze + 2.4, D)


def italian_venezia(rig, p):
    """Two Venetian houses: Venetian red with Gothic pointed windows in white Istrian stone, a polifora with a
    balustraded balcony and a water gate; ochre with green shutters; funnel-shaped chimneys."""
    D = 14.0
    fr = dict(frame="#f1ece2", frame_w=0.11, mull=dict(v=1, h=[0.55], w=0.05), lit=0.45)
    # A
    xa0, xa1 = -9.0, 0.0
    ga = [grid("front", -6.9, 4, 1.2, 3.6, 1, 3.8, (0.85, 2.6), sill=0.6, top="pointed", **fr),
          grid("front", -8.6, 1, 1.2, 3.6, 1, 3.8, (0.85, 2.4), sill=0.7, top="pointed", **fr),
          grid("front", -1.6, 1, 1.2, 3.6, 1, 3.8, (0.85, 2.4), sill=0.7, top="pointed", **fr),
          grid("front", -8.5, 4, 2.0, 7.4, 2, 3.1, (0.9, 2.0), sill=0.6, top="pointed", **fr),
          grid("front", -6.0, 1, 3.0, 0.0, 1, 3.6, (2.2, 2.9), sill=0.0, top="round", kind="door", glass="#2f4a3a",
               frame="#f1ece2"),
          grid("front", -8.6, 1, 1.2, 0.0, 1, 3.6, (0.7, 1.0), sill=1.8, mull=dict(v=2, h=1, w=0.05), frame="#f1ece2"),
          grid("front", -1.6, 1, 1.2, 0.0, 1, 3.6, (0.7, 1.0), sill=1.8, mull=dict(v=2, h=1, w=0.05), frame="#f1ece2"),
          grid("left", 1.5, 4, 3.0, 3.6, 3, 3.3, (0.9, 2.0), sill=0.6, top="pointed", **fr)]
    wa = wallmat("iva_wall", dict(color="#b44a3a", noise=0.1), ga, seed=141,
                 zones=[dict(box=((-99, 99), (-99, 99), (-1, 0.9)), surface=dict(color="#e8e1d2", kind="ashlar", h=0.45,
                                                                                 w=0.9, strength=0.4))])
    bm = bmesh.new()
    bx(bm, xa0, xa1, 0.0, D, 0.0, 13.6)
    mk(rig, "iva_body", bm, wa)
    ist = basic("iv_istria", "#f1ece2", rough=0.7)
    bm = bmesh.new()
    cornice(bm, xa0, xa1, 0.0, D, 3.5, [(0.15, 0.08)])
    cornice(bm, xa0, xa1, 0.0, D, 13.35, [(0.12, 0.1), (0.15, 0.25)])
    bx(bm, -7.1, -1.9, -0.8, 0.0, 4.05, 4.2)
    sills(bm, ga[3], 0.0, h=0.1, out=0.12)
    mk(rig, "iva_stone", bm, ist)
    bal = Rails("iva_bal", "#f1ece2", "balusters", pitch=0.26, h=0.85)
    bal.add_box(-7.1, -1.9, -0.8, -0.62, 4.2)
    bal.add_box(-7.1, -6.92, -0.8, 0.0, 4.2)
    bal.add_box(-2.08, -1.9, -0.8, 0.0, 4.2)
    bal.build(rig)
    hip(rig, "iva_roof", xa0, xa1, 0.0, D, 13.6, 15.6, roofmat("iva_tiles", "#b05d3c", "canal", rows=0.38), over=0.5)
    # B
    xb0, xb1 = 0.0, 8.0
    frb = dict(frame="#f1ece2", mull=dict(v=1, h=[0.6], w=0.05), shutters="#3e6b45", shutter_w=0.5, lit=0.45)
    gb = [grid("front", 0.4, 3, 2.4, 3.4, 3, 3.0, (1.0, 1.9), sill=0.6, **frb),
          grid("front", 0.4, 3, 2.4, 0.0, 1, 3.4, (1.0, 1.7), sill=1.0, skip=[(1, 0)], **frb),
          grid("front", 2.8, 1, 2.4, 0.0, 1, 3.4, (1.3, 2.6), sill=0.0, top="round", kind="door", glass="#3f2a1e",
               frame="#f1ece2")]
    wb = wallmat("ivb_wall", dict(color="#dba55e", noise=0.1), gb, seed=142)
    bm = bmesh.new()
    bx(bm, xb0, xb1, 0.0, D, 0.0, 12.4)
    mk(rig, "ivb_body", bm, wb)
    bm = bmesh.new()
    cornice(bm, xb0, xb1, 0.0, D, 12.15, [(0.12, 0.1), (0.15, 0.22)])
    for gg in gb[:1]:
        surrounds(bm, gg, 0.0, w=0.1, out=0.04)
    mk(rig, "ivb_stone", bm, ist)
    rails = Rails("ivb_rail", "#1e2120", "bars", pitch=0.12, bar=0.028)
    bs = bmesh.new()
    balconies(bs, rails, gb[0], 0.0, [0], depth=0.5, ext=0.15, rail_h=0.95, slab=0.12)
    mk(rig, "ivb_slab", bs, ist)
    rails.build(rig)
    hip(rig, "ivb_roof", xb0, xb1, 0.0, D, 12.4, 14.2, roofmat("ivb_tiles", "#b8653f", "canal", rows=0.38), over=0.5)
    bm = bmesh.new()
    for (x, y, z) in ((-7.5, 5.0, 14.4), (-3.0, 9.0, 14.8), (2.0, 6.5, 13.2), (6.0, 4.0, 13.0)):
        _funnel_chimney(bm, x, y, z - 0.6)
    mk(rig, "iv_chim", bm, basic("iv_chm", "#c98a6a", rough=0.8), smooth=True)
    return info(17.3, 17.4, D)


# =================================================================================================
# vienna: Ringstrasse palais, baroque dome church, Gruenderzeit tenement with a corner dome
# =================================================================================================

def vienna_palais(rig, p):
    """Viennese palais (Renaissance revival, Schoenbrunn yellow with white stucco): rusticated ground floor with
    arched windows and portal, central risalit with giant pilasters and a pediment, alternating window
    pediments, main cornice, balustraded attic with statues, copper roof."""
    W, D = 28.0, 20.0
    x0, x1 = -W / 2, W / 2
    zg, z1, z2, ze = 5.0, 10.0, 14.4, 18.2
    fr = dict(frame="#f6f1e6", mull=dict(v=1, h=[0.66], w=0.06), lit=0.45)
    u0, pu, n = -13.5, 3.0, 9
    g = [grid("front", u0, n, pu, 0.0, 1, zg, (1.4, 2.6), sill=1.2, top="round", skip=[(4, 0)], **fr),
         grid("front", -1.5, 1, 3.0, 0.0, 1, zg, (2.6, 4.2), sill=0.0, top="round", kind="door", glass="#2f4a3a",
              frame="#f6f1e6"),
         grid("front", u0, n, pu, zg, 1, z1 - zg, (1.5, 3.0), sill=0.9, **fr),
         grid("front", u0, n, pu, z1, 1, z2 - z1, (1.4, 2.6), sill=0.8, **fr),
         grid("front", u0, n, pu, z2, 1, ze - z2, (1.3, 2.2), sill=0.7, **fr),
         grid("left", 1.0, 6, pu, 0.0, 1, zg, (1.4, 2.6), sill=1.2, top="round", **fr),
         grid("left", 1.0, 6, pu, zg, 1, z1 - zg, (1.5, 3.0), sill=0.9, **fr),
         grid("left", 1.0, 6, pu, z1, 1, z2 - z1, (1.4, 2.6), sill=0.8, **fr),
         grid("left", 1.0, 6, pu, z2, 1, ze - z2, (1.3, 2.2), sill=0.7, **fr)]
    wall = wallmat("vp_wall", dict(color="#e9c46c", noise=0.05), g, seed=151,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zg)), surface=dict(color="#efd389", kind="rustic", h=0.5,
                                                                                  w=1.8, jw=0.07))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    bx(bm, -4.6, 4.6, -0.6, 0.05, 0.0, ze)
    mk(rig, "vp_body", bm, wall)
    wh = basic("vp_white", "#f6f1e6", rough=0.75)
    bm = bmesh.new()
    for (y0_, xa, xb) in ((0.0, x0, x1), (-0.6, -4.6, 4.6)):
        cornice(bm, xa, xb, y0_, D, zg - 0.3, [(0.18, 0.1), (0.15, 0.2)])
        cornice(bm, xa, xb, y0_, D, z2 - 0.12, [(0.14, 0.08)])
        cornice(bm, xa, xb, y0_, D, ze - 0.3, [(0.15, 0.1), (0.15, 0.25), (0.3, 0.55), (0.15, 0.62)])
    for (gg, plane) in ((g[2], 0.0), (g[6], x0)):
        pediments(bm, gg, plane, alt=True, h=0.48, out=0.17, ext=0.22)
        surrounds(bm, gg, plane, w=0.14, out=0.06)
    for (gg, plane) in ((g[3], 0.0), (g[7], x0)):
        lintels(bm, gg, plane, h=0.26, out=0.13, ext=0.18)
        surrounds(bm, gg, plane, w=0.12, out=0.05)
    for (gg, plane) in ((g[4], 0.0), (g[8], x0)):
        surrounds(bm, gg, plane, w=0.11, out=0.05)
    for gg, plane in ((g[2], 0.0), (g[3], 0.0), (g[4], 0.0), (g[6], x0), (g[7], x0), (g[8], x0)):
        sills(bm, gg, plane, h=0.12, out=0.14)
    pilasters(bm, "front", -0.6, [-4.5, -1.5, 1.5, 4.5], zg, z2 - 0.15, w=0.62, out=0.22)
    pilasters(bm, "front", 0.0, [x0 + 0.4, x1 - 0.4], zg, ze - 0.3, w=0.7, out=0.15)
    pilasters(bm, "left", x0, [0.4, D - 0.4], zg, ze - 0.3, w=0.7, out=0.15)
    mk(rig, "vp_white", bm, wh)
    front_gable(rig, "vp_ped", "tri", 0.0, 9.8, ze + 0.45, 2.6, wh, y0=-1.25, depth=0.7)
    bm = MU.bm_sphere(1.0, center=(0.0, -1.35, ze + 1.35), scale=(0.75, 0.2, 0.9), subdiv=2)
    mk(rig, "vp_arms", bm, basic("vp_gold", "#c9a43a", rough=0.35, metal=0.8), smooth=True)
    zb = ze + 0.45
    bal = Rails("vp_bal", "#f6f1e6", "balusters", pitch=0.3, h=1.1)
    bal.add_box(x0 + 0.2, -4.9, -0.05, 0.25, zb)
    bal.add_box(4.9, x1 - 0.2, -0.05, 0.25, zb)
    bal.add_box(x0 - 0.05, x0 + 0.25, 0.2, D - 0.2, zb)
    bal.build(rig)
    bm = bmesh.new()
    for xx in [x0 + 0.4, -10.5, -7.5, 7.5, 10.5, x1 - 0.4]:
        bx(bm, xx - 0.35, xx + 0.35, -0.1, 0.4, zb, zb + 1.3)
    for yy in (4.0, 8.0, 12.0, 16.0):
        bx(bm, x0 - 0.1, x0 + 0.4, yy - 0.35, yy + 0.35, zb, zb + 1.3)
    for xx in (-10.5, -7.5, 7.5, 10.5):
        statue(bm, xx, 0.15, zb + 1.3, h=1.9)
    for xx in (-4.6, 4.6):
        statue(bm, xx, -0.85, zb + 0.2, h=2.1)
    mk(rig, "vp_attic", bm, wh)
    hip(rig, "vp_roof", x0 + 0.6, x1 - 0.6, 0.6, D - 0.6, zb, zb + 4.2, roofmat("vp_cu", "#5f9a83", "copper"), over=0.0)
    return info(W + 1.3, zb + 4.2, D)


def vienna_kirche(rig, p):
    """Viennese baroque dome church: twin towers with copper bell caps flanking a columned portico with a
    pediment, curved gable, drum with windows, green copper dome with lantern and gilded crosses."""
    wallc = "#efe6d2"
    fr = dict(frame="#f8f3e8", mull=dict(v=1, h=[0.5], w=0.06), lit=0.7, color=("#ffcf7a", "#ffd890"), strength=1.3)
    g = [grid("front", -12.0, 2, 2.5, 3.0, 1, 6.0, (1.3, 3.2), sill=1.0, top="round", **fr),
         grid("front", 7.0, 2, 2.5, 3.0, 1, 6.0, (1.3, 3.2), sill=1.0, top="round", **fr),
         grid("front", -12.0, 2, 2.5, 12.0, 1, 5.0, (1.1, 2.4), sill=1.0, top="round", **fr),
         grid("front", 7.0, 2, 2.5, 12.0, 1, 5.0, (1.1, 2.4), sill=1.0, top="round", **fr),
         grid("front", -11.5, 1, 4.0, 21.0, 1, 5.0, (1.5, 3.4), sill=0.8, top="round", kind="door", glass="#2b2d2f",
              frame="#f8f3e8"),
         grid("front", 7.5, 1, 4.0, 21.0, 1, 5.0, (1.5, 3.4), sill=0.8, top="round", kind="door", glass="#2b2d2f",
              frame="#f8f3e8"),
         grid("front", -1.8, 1, 3.6, 14.2, 1, 5.0, (3.0, 3.8), sill=0.3, top="round", **fr),
         grid("front", -1.5, 1, 3.0, 0.0, 1, 7.0, (2.6, 5.4), sill=0.0, top="round", kind="door", glass="#3f2a1c",
              frame="#f8f3e8"),
         grid("left", 1.0, 1, 3.0, 3.0, 2, 9.0, (1.3, 3.2), sill=1.0, top="round", **fr),
         grid("left", 8.0, 3, 4.5, 3.0, 1, 12.0, (1.8, 5.5), sill=2.0, top="round", **fr)]
    wall = wallmat("vk_wall", dict(color=wallc, noise=0.04), g, seed=161)
    wh = basic("vk_white", "#faf6ec", rough=0.75)
    cu = roofmat("vk_cu", "#5f9c86", "copper", var=0.18)
    gold = basic("vk_gold", "#d4ad42", rough=0.3, metal=0.9)
    bm = bmesh.new()
    for s in (-1, 1):
        bx(bm, s * 7.0, s * 12.0, 0.0, 5.0, 0.0, 27.0)
    bx(bm, -7.0, 7.0, 0.0, 4.0, 0.0, 19.5)
    bx(bm, -12.0, 12.0, 4.0, 26.0, 0.0, 17.0)
    mk(rig, "vk_body", bm, wall)
    # nave back part: octagonal drum base
    bm = bmesh.new()
    cornice(bm, -12.0, 12.0, 0.0, 26.0, 16.7, [(0.15, 0.1), (0.2, 0.3)])
    for s in (-1, 1):
        xa, xb = (7.0, 12.0) if s > 0 else (-12.0, -7.0)
        cornice(bm, xa, xb, 0.0, 5.0, 9.2, [(0.2, 0.12), (0.15, 0.22)])
        cornice(bm, xa, xb, 0.0, 5.0, 19.6, [(0.2, 0.12), (0.25, 0.3)])
        cornice(bm, xa, xb, 0.0, 5.0, 26.7, [(0.15, 0.1), (0.25, 0.3)])
        pilasters(bm, "front", 0.0, [xa + 0.4, xb - 0.4], 0.5, 26.5, w=0.6, out=0.15)
    cornice(bm, -7.0, 7.0, 0.0, 4.0, 19.2, [(0.15, 0.1), (0.2, 0.25)])
    # portico: four columns, entablature, pediment
    for xx in (-4.6, -1.6, 1.6, 4.6):
        MU.bm_cyl(0.42, 0.36, 9.4, center=(xx, -1.6, 0.7 + 4.7), segs=14, bm=bm)
        bx(bm, xx - 0.55, xx + 0.55, -2.15, -1.05, 0.0, 0.7)
        bx(bm, xx - 0.55, xx + 0.55, -2.15, -1.05, 10.1, 10.4)
    bx(bm, -5.4, 5.4, -2.3, 0.0, 10.4, 11.4)
    mk(rig, "vk_white", bm, wh)
    front_gable(rig, "vk_ped", "tri", 0.0, 11.2, 11.4, 2.6, wh, y0=-2.3, depth=2.3)
    front_gable(rig, "vk_top", "volute", 0.0, 9.0, 19.5, 3.8, wall, y0=0.0, depth=0.6, cap_mat=wh)
    saddle(rig, "vk_portr", -5.4, 5.4, -2.3, 0.0, 11.4, 13.9, cu, axis="y", over_side=0.0, over_end=0.0)
    # tower caps: copper bell caps + lanterns
    for xc in (-9.5, 9.5):
        prof = [(0.0, 27.3), (2.9, 27.3), (2.9, 27.8), (2.2, 29.0), (2.5, 30.2), (1.4, 31.6), (0.7, 32.2), (0.75, 33.6),
                (0.95, 34.2), (0.3, 35.6), (0.0, 36.2)]
        lathe(rig, "vk_cap%d" % (xc > 0), prof, (xc, 2.5, 0.0), cu, segs=8, smooth=False)
        bm = bmesh.new()
        cross(bm, xc, 2.5, 36.1, h=1.8)
        mk(rig, "vk_cr%d" % (xc > 0), bm, gold)
    # drum, dome, lantern
    cy = 15.0
    drum = wallmat("vk_drum", dict(color=wallc, noise=0.04), [], seed=162)
    lathe(rig, "vk_drum", [(0.0, 17.0), (7.2, 17.0), (7.2, 23.5), (0.0, 23.5)], (0.0, cy, 0.0), drum, segs=16, smooth=False)
    glass_boxes(rig, "vk_dw", [(math.cos(a) * 7.25 - 0.6, math.cos(a) * 7.25 + 0.6, cy + math.sin(a) * 7.25 - 0.6,
                                cy + math.sin(a) * 7.25 + 0.6, 18.6, 21.8) for a in
                               [math.radians(200 + 23 * k) for k in range(7)]], lit=0.8, seed=5, color="#ffcf7a")
    bm = bmesh.new()
    MU.bm_cyl(7.7, 7.7, 0.5, center=(0.0, cy, 23.6), segs=24, bm=bm)
    MU.bm_cyl(7.6, 7.6, 0.4, center=(0.0, cy, 16.9), segs=24, bm=bm)
    MU.bm_cyl(1.9, 1.9, 0.35, center=(0.0, cy, 31.9), segs=12, bm=bm)
    mk(rig, "vk_rings", bm, wh)
    lathe(rig, "vk_dome", [(0.0, 23.8)] + dome_prof(7.4, 8.0, base=23.8) + [(0.0, 31.8)], (0.0, cy, 0.0), cu, segs=32)
    lath = wallmat("vk_lant", dict(color=wallc, noise=0.04), [], seed=163)
    lathe(rig, "vk_lant", [(0.0, 31.8), (1.6, 31.8), (1.6, 34.6), (0.0, 34.6)], (0.0, cy, 0.0), lath, segs=8, smooth=False)
    glass_boxes(rig, "vk_lw", [(-0.5, 0.5, cy - 1.68, cy - 1.58, 32.4, 34.0), (-1.68, -1.58, cy - 0.5, cy + 0.5, 32.4, 34.0)],
                lit=1.0, color="#ffd27a")
    lathe(rig, "vk_lcap", [(0.0, 34.6)] + [(r * 1.0, 34.6 + z) for (r, z) in onion(2.4, 1.6)], (0.0, cy, 0.0), cu, segs=16)
    bm = bmesh.new()
    cross(bm, 0.0, cy, 37.2, h=2.0)
    mk(rig, "vk_crd", bm, gold)
    return info(24.0, 39.2, 26.0)


def vienna_zinshaus(rig, p):
    """Viennese Gruenderzeit tenement: rusticated ground floor with dark wood shop portals, stucco window
    aediculae, a corner bay crowned by a copper dome, red-brown saddle roof with dormers."""
    W, D = 20.0, 14.0
    x0, x1 = -W / 2, W / 2
    zg = 4.5
    fl = [(4.5, 3.6, 2.3), (8.1, 3.4, 2.2), (11.5, 3.3, 2.1), (14.8, 3.2, 1.9)]
    ze = 18.0
    fr = dict(frame="#f4f0e6", mull=dict(v=1, h=[0.68], w=0.06), lit=0.45)
    gfl = []
    g = []
    for (face, u0, nn, plane) in (("front", -7.2, 6, 0.0), ("left", 2.6, 4, x0)):
        fls = [grid(face, u0, nn, 2.8, z, 1, h, (1.2, wh), sill=0.7, **fr) for (z, h, wh) in fl]
        g += fls
        g.append(grid(face, u0, nn, 2.8, 0.0, 1, zg, (2.0, 3.2), sill=0.5, kind="shop", frame="#3c2a20", glass="#2e3a3e"))
        gfl.append((face, plane, fls))
    wall = wallmat("vz_wall", dict(color="#ddd4c2", noise=0.05), g, seed=171,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zg)), surface=dict(color="#d2c8b4", kind="rustic", h=0.5))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "vz_body", bm, wall)
    wh = basic("vz_white", "#f3efe6", rough=0.75)
    bm = bmesh.new()
    cornice(bm, x0, x1, 0.0, D, zg - 0.3, [(0.2, 0.1), (0.15, 0.2)])
    for (z, h, wh_) in fl[1:]:
        cornice(bm, x0, x1, 0.0, D, z - 0.1, [(0.14, 0.07)])
    cornice(bm, x0, x1, 0.0, D, ze - 0.35, [(0.15, 0.1), (0.15, 0.25), (0.3, 0.5), (0.1, 0.58)])
    for (face, plane, fls) in gfl:
        pediments(bm, fls[0], plane, kind="tri", h=0.45, out=0.16)
        surrounds(bm, fls[0], plane, w=0.14, out=0.06)
        pediments(bm, fls[1], plane, kind="seg", h=0.35, out=0.14)
        lintels(bm, fls[2], plane, h=0.24, out=0.12)
        surrounds(bm, fls[3], plane, w=0.1, out=0.05)
        for f_ in fls:
            sills(bm, f_, plane, h=0.1, out=0.12)
        # consoles under the first-floor windows
        for (u, zc, i, j) in centres(fls[0]):
            for sg in (-1, 1):
                fbox(bm, face, plane, u + sg * 0.55 - 0.1, u + sg * 0.55 + 0.1, zc - 1.6, zc - 1.15, 0.0, 0.2)
    mk(rig, "vz_white", bm, wh)
    roof = roofmat("vz_roof", "#8a4a38", "tiles", rows=0.3)
    zr = ze + (D / 2) * math.tan(math.radians(42))
    saddle(rig, "vz_roof", x0, x1, 0.0, D, ze, zr, roof, axis="x", over_side=0.35, over_end=0.1)
    gable_ends(rig, "vz_ge", x0, x1, 0.0, D, ze, zr, wall, axis="x")
    dormers(rig, "vz_dorm", [-4.4, -1.6, 1.2, 4.0, 6.8], 0.0, ze, 42.0, 1.2, 1.5, wh, roof, kind="seg", z_up=0.8,
            glass_seed=172)
    turret(rig, "vz_dome", x0 + 0.3, 0.3, 2.3, zg + 0.4, ze + 1.4, wall, roofmat("vz_cu", "#5f9c86", "copper"),
           kind="dome", roof_h=3.6, corbel=1.2, win=(0.8, 1.6, [6.3, 9.8, 13.1, 16.3]), seed=17, segs=8)
    lathe(rig, "vz_ring", [(0.0, ze + 1.4), (2.75, ze + 1.4), (2.75, ze + 1.75), (0.0, ze + 1.75)], (x0 + 0.3, 0.3, 0.0),
          wh, segs=8, smooth=False)
    awning(rig, "vz_awn", -7.0, -1.7, 0.0, 4.1, 1.4, 0.6, "#7a1f24", None)
    chimneys(rig, "vz_chim", [(-3.0, D * 0.55), (5.0, D * 0.5)], zr - 2.0, zr + 1.0, basic("vz_chm", "#a07a64", rough=0.8))
    return info(W + 2.0, ze + 6.0, D)


# =================================================================================================
# swiss: chalet, Bern arcade houses
# =================================================================================================

def swiss_chalet(rig, p):
    """Bernese chalet: white rendered ground floor, dark log upper storeys, wide gable roof with a deep
    overhang towards the street, balconies with cut-out balustrades, red geraniums, green shutters,
    firewood stack."""
    W, D = 12.0, 11.0
    x0, x1 = -W / 2, W / 2
    zw, zt = 2.8, 5.6
    gh = (W / 2) * math.tan(math.radians(24))
    fr = dict(frame="#f4f2ec", mull=dict(v=1, h=[0.5], w=0.06), shutters="#3f6a3e", shutter_w=0.45, lit=0.5)
    g = [grid("front", -5.1, 4, 2.55, zw, 1, 2.8, (0.95, 1.3), sill=0.8, **fr),
         grid("front", -1.5, 2, 1.5, zt, 1, 2.4, (0.8, 1.1), sill=0.5, **fr),
         grid("front", -5.1, 4, 2.55, 0.0, 1, 2.8, (0.9, 1.1), sill=0.9, skip=[(1, 0)], **fr),
         grid("front", -2.55, 1, 2.55, 0.0, 1, 2.8, (1.0, 2.1), sill=0.0, kind="door", glass="#5a3a22", frame="#efe9de"),
         grid("left", 1.0, 3, 3.0, zw, 1, 2.8, (0.9, 1.25), sill=0.8, **fr),
         grid("left", 1.0, 3, 3.0, 0.0, 1, 2.8, (0.9, 1.1), sill=0.9, **fr)]
    wood = dict(color="#7b4a28", kind="clap", pitch=0.22, joint="#3a2010", noise=0.08)
    wall = wallmat("sch_wall", wood, g, seed=181,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zw)), surface=dict(color="#efebe2", noise=0.05))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, zt)
    mk(rig, "sch_body", bm, wall)
    front_gable(rig, "sch_gable", "tri", 0.0, W, zt, gh, wall, y0=0.0, depth=0.3)
    front_gable(rig, "sch_gback", "tri", 0.0, W, zt, gh, wall, y0=D - 0.3, depth=0.3)
    roof = roofmat("sch_roof", "#5d4838", "tiles", rows=0.25)
    saddle(rig, "sch_roof", x0, x1, 0.0, D, zt, zt + gh + 0.05, roof, axis="y", over_side=1.3, over_end=0.8,
           over_end0=1.7, thick=0.32)
    woodm = basic("sch_wood", "#6e4224", rough=0.7)
    bm = bmesh.new()
    bx(bm, x0 - 0.2, x1 + 0.2, -1.3, 0.0, zw - 0.2, zw)
    bx(bm, -3.3, 3.3, -0.9, 0.0, zt - 0.15, zt)
    for xx in (x0 - 0.1, x1 + 0.1):
        MU.bm_beam((xx, -1.25, zw - 0.2), (xx, -0.1, zw - 1.2), 0.15, bm=bm)
    # carved bargeboards along the front roof edges
    for sg in (-1, 1):
        a = Vector((sg * (W / 2 + 1.3), -1.75, zt - 1.3 * gh / (W / 2) - 0.05))
        b = Vector((0.0, -1.75, zt + gh + 0.05))
        MU.bm_beam(a, b, 0.45, 0.1, bm=bm, up=(0, 1, 0))
    mk(rig, "sch_woodm", bm, woodm)
    bal = Rails("sch_bal", "#6a3f22", "balusters", pitch=0.22, h=1.0)
    bal.add_box(x0 - 0.2, x1 + 0.2, -1.3, -1.22, zw)
    bal.add_box(x0 - 0.2, x0 - 0.12, -1.3, 0.0, zw)
    bal.add_box(-3.3, 3.3, -0.9, -0.82, zt)
    bal.build(rig)
    pts = [(x0 + 0.2 + 0.35 * k, -1.42, zw + 1.05) for k in range(int((W - 0.4) / 0.35))]
    pts += [(-3.0 + 0.35 * k, -1.02, zt + 1.05) for k in range(18)]
    pts += [(u - 0.4 + 0.3 * k, -0.2, zc - 0.65) for (u, zc, i, j) in centres(g[2]) for k in range(3)]
    flowers(rig, "sch_ger", pts, colors=("#d81f26", "#e8343a", "#3f6b28"), r=0.17, seed=18)
    bm = bmesh.new()
    for k in range(5):
        for j in range(6):
            MU.bm_cyl(0.16, 0.16, 1.0, center=(x0 - 0.55, 2.2 + j * 0.34 + (0.17 if k % 2 else 0.0), 0.18 + k * 0.3),
                      axis="X", segs=8, bm=bm)
    mk(rig, "sch_logs", bm, basic("sch_logm", "#a3784f", rough=0.85, color2="#7d5636", var_scale=6.0))
    return info(W + 2.7, zt + gh + 0.4, D)


def swiss_laube(rig, p):
    """Bern old-town houses with arcades (Lauben): greenish sandstone, round arches on heavy piers, shop
    fronts in the arcade, flower boxes, steep brown roof with a deep eave and small dormers."""
    D = 15.0
    xs = [-10.25, -3.25, 3.25, 10.25]
    x0, x1 = xs[0], xs[-1]
    za = 4.2
    zs = [za, 7.4, 10.6, 13.8]
    ze = zs[-1]
    fr = dict(frame="#f2efe6", mull=dict(v=1, h=[0.6], w=0.06), lit=0.5)
    cols = ["#b2ad93", "#d9b46c", "#a9a58d"]
    grids, zones = [], []
    for k in range(3):
        xa, xb = xs[k], xs[k + 1]
        n = 3 if xb - xa > 6.8 else 2
        pu = (xb - xa - 0.8) / n
        grids.append(grid("front", xa + 0.4, n, pu, za, 3, 3.2, (1.1, 1.9), sill=0.75, **fr))
        grids.append(grid("front", xa + 0.6, 2, (xb - xa - 1.2) / 2, 0.0, 1, za, ((xb - xa - 1.2) / 2 - 0.9, 2.6),
                          sill=0.3, kind="shop", frame="#4a3a2a", glass="#2f3b3f"))
        zones.append(dict(box=((xa - (1 if k == 0 else 0), xb + (1 if k == 2 else 0)), (-99, 99), (-1, 99)),
                          surface=dict(color=cols[k], kind="ashlar" if k != 1 else "plain", h=0.5, w=1.1, strength=0.35,
                                       noise=0.06)))
    grids.append(grid("left", 4.0, 3, 3.3, za, 3, 3.2, (1.0, 1.8), sill=0.75, **fr))
    wall = wallmat("sl2_wall", "#b2ad93", grids, zones=zones, seed=191)
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, za, ze)
    bx(bm, x0, x1, 3.0, D, 0.0, za)
    bx(bm, x0, x0 + 0.5, 0.9, 3.0, 0.0, za)
    mk(rig, "sl2_body", bm, wall)
    stone = basic("sl2_stone", "#aba68c", rough=0.85, color2="#99947c", var_scale=2.0)
    bm = bmesh.new()
    piers = [x0 + 0.45, -6.75, xs[1], 0.0, xs[2], 6.75, x1 - 0.45]
    for xp in piers:
        bx(bm, xp - 0.45, xp + 0.45, 0.0, 0.95, 0.0, za)
    for (pa, pb) in zip(piers[:-1], piers[1:]):
        a, b = pa + 0.45, pb - 0.45
        r = (b - a) / 2
        zsp = za - 0.35 - r
        pts = [(a, zsp)] + [((a + b) / 2 - r * math.cos(math.pi * t / 10), zsp + r * math.sin(math.pi * t / 10))
                            for t in range(1, 10)] + [(b, zsp), (b, za), (a, za)]
        MU.prism(pts, 0.95, bm=bm, plane="XZ", offset=0.0)
    bx(bm, x0, x1, 0.0, 3.0, za - 0.25, za)
    cornice(bm, x0, x1, 0.0, D, za - 0.1, [(0.12, 0.08)])
    mk(rig, "sl2_arcade", bm, stone)
    pts = []
    bf = bmesh.new()
    for gg in grids:
        if gg["face"] == "front" and gg.get("kind", "win") == "win":
            for (u, zc, i, j) in centres(gg):
                bx(bf, u - 0.62, u + 0.62, -0.32, 0.0, zc - 0.95 - 0.25, zc - 0.95)
                pts += [(u - 0.45 + 0.3 * q, -0.17, zc - 0.95 + 0.05) for q in range(4)]
    mk(rig, "sl2_boxes", bf, basic("sl2_bx", "#6a4a2c", rough=0.7))
    flowers(rig, "sl2_ger", pts, colors=("#d81f26", "#e8343a", "#3f6b28"), r=0.15, seed=19)
    roof = roofmat("sl2_roof", "#8d4c36", "tiles", rows=0.3)
    zr = ze + (D / 2) * math.tan(math.radians(48))
    saddle(rig, "sl2_roof", x0, x1, 0.0, D, ze, zr, roof, axis="x", over_side=1.2, over_end=0.2, thick=0.25)
    gable_ends(rig, "sl2_ge", x0, x1, 0.0, D, ze, zr, wall, axis="x")
    bm = bmesh.new()
    bx(bm, x0 - 0.2, x1 + 0.2, -1.2, 0.0, ze - 1.15, ze - 1.05)
    mk(rig, "sl2_soffit", bm, basic("sl2_sof", "#5a3c26", rough=0.7))
    dormers(rig, "sl2_dorm", [-6.75, 0.0, 6.75], 0.0, ze, 48.0, 1.2, 1.2, basic("sl2_dw", "#efe9dc"), roof, kind="gable",
            z_up=1.2, glass_seed=192)
    return info(21.0, zr + 0.3, D)


# =================================================================================================
# central (Prague, Budapest, Ljubljana): baroque town houses, Jugendstil, eclectic corner with turret
# =================================================================================================

def central_barock(rig, p):
    """Two Prague baroque town houses: pale yellow with a volute gable and white pilasters, salmon pink with
    a small volute dormer gable; red tile roofs, house sign above the door."""
    D = 14.0
    fr = dict(frame="#f4efe6", mull=dict(v=1, h=[0.66], w=0.06), lit=0.45)
    fl = [(4.0, 3.3, 2.0), (7.3, 3.2, 1.95), (10.5, 3.1, 1.85)]
    # A: gable to the street
    xa, wa, zta = -5.25, 9.5, 13.6
    ga = [grid("front", xa - 4.2, 3, 2.8, z, 1, h, (1.15, wh), sill=0.7, **fr) for (z, h, wh) in fl]
    ga += [grid("front", xa - 4.2, 3, 2.8, 0.0, 1, 4.0, (1.2, 2.2), sill=0.9, skip=[(1, 0)], top="seg", **fr),
           grid("front", xa - 0.8, 1, 1.6, 0.0, 1, 4.0, (1.4, 2.9), sill=0.0, top="round", kind="door", glass="#4a3222",
                frame="#f4efe6"),
           grid("front", xa - 1.4, 2, 1.4, zta + 0.5, 1, 2.0, (0.9, 1.5), sill=0.2, **fr),
           grid("front", xa - 0.5, 1, 1.0, zta + 2.8, 1, 1.3, (0.6, 0.8), sill=0.2, top="round", **fr)]
    gable_house(rig, "cba", xa, wa, D, zta, "volute", 5.4, dict(color="#efd88f", noise=0.05), ga,
                              trim="#f6f1e7", roof_c="#a8462e", seed=201)
    st = basic("cb_st", "#f6f1e7", rough=0.75)
    bm = bmesh.new()
    pilasters(bm, "front", 0.0, [xa - wa / 2 + 0.35, xa + wa / 2 - 0.35], 4.0, zta, w=0.55, out=0.12)
    cornice(bm, xa - wa / 2, xa + wa / 2, 0.0, 0.05, 3.8, [(0.12, 0.08), (0.12, 0.16)])
    cornice(bm, xa - wa / 2, xa + wa / 2, 0.0, 0.05, zta - 0.3, [(0.12, 0.1), (0.15, 0.22)])
    pediments(bm, ga[0], 0.0, kind="seg", h=0.35, out=0.14)
    surrounds(bm, ga[1], 0.0, w=0.12, out=0.05)
    surrounds(bm, ga[2], 0.0, w=0.1, out=0.05)
    mk(rig, "cba_st", bm, st)
    bm = MU.bm_sphere(0.45, center=(xa, -0.08, 3.55), scale=(1.0, 0.2, 1.0), subdiv=2)
    mk(rig, "cba_sign", bm, basic("cba_gold", "#c9a43a", rough=0.35, metal=0.8), smooth=True)
    # B: eaves to the street with a volute dormer gable
    xb0, xb1 = -0.5, 10.0
    gb = [grid("front", xb0 + 0.5, 4, 2.375, z, 1, h, (1.1, wh), sill=0.7, **fr) for (z, h, wh) in fl]
    gb += [grid("front", xb0 + 0.5, 4, 2.375, 0.0, 1, 4.0, (1.2, 2.2), sill=0.9, top="seg", skip=[(1, 0)], **fr),
           grid("front", xb0 + 2.875, 1, 2.375, 0.0, 1, 4.0, (1.3, 2.8), sill=0.0, top="round", kind="door",
                glass="#3d4b33", frame="#f4efe6"),
           grid("front", 3.9, 1, 1.4, 13.9, 1, 1.9, (0.9, 1.3), sill=0.2, top="round", **fr)]
    wB = wallmat("cbb_wall", dict(color="#e8a690", noise=0.05), gb, seed=202)
    bm = bmesh.new()
    bx(bm, xb0, xb1, 0.0, D, 0.0, 13.6)
    mk(rig, "cbb_body", bm, wB)
    bm = bmesh.new()
    cornice(bm, xb0, xb1, 0.0, D, 3.8, [(0.12, 0.08), (0.12, 0.16)])
    cornice(bm, xb0, xb1, 0.0, D, 13.3, [(0.12, 0.1), (0.15, 0.22), (0.15, 0.3)])
    for gg in gb[:3]:
        surrounds(bm, gg, 0.0, w=0.12, out=0.05)
        sills(bm, gg, 0.0, h=0.08, out=0.1)
    pediments(bm, gb[0], 0.0, kind="tri", h=0.35, out=0.14)
    mk(rig, "cbb_st", bm, st)
    roof = roofmat("cbb_roof", "#a8462e", "tiles")
    zr = 13.6 + (D / 2) * math.tan(math.radians(45))
    saddle(rig, "cbb_roof", xb0, xb1, 0.0, D, 13.6, zr, roof, axis="x", over_side=0.35, over_end=0.0)
    gable_ends(rig, "cbb_ge", xb0, xb1, 0.0, D, 13.6, zr, wB, axis="x")
    front_gable(rig, "cbb_zw", "volute", 4.6, 3.6, 13.6, 3.2, wB, y0=0.0, depth=0.45, cap_mat=st)
    saddle(rig, "cbb_zwr", 2.85, 6.35, 0.45, 3.5, 13.6, 16.3, roof, axis="y", over_side=0.0)
    chimneys(rig, "cb_chim", [(-3.0, D * 0.6), (7.0, D * 0.55)], 17.0, 21.5, basic("cb_chm", "#d6c3a8", rough=0.8))
    return info(20.0, zr, D)


def central_jugendstil(rig, p):
    """Jugendstil house (Prague / Budapest / Ljubljana): cream facade with teal and gold tile bands, rounded
    windows, semicircular balconies, masks, a big round decorative gable with a gold mosaic and an
    oculus, copper mansard."""
    W, D = 14.0, 14.0
    x0, x1 = -W / 2, W / 2
    zg, pz, n = 4.2, 3.4, 4
    ze = zg + pz * n
    fr = dict(frame="#f6f1e6", mull=dict(v=1, h=[0.72], w=0.05), lit=0.45)
    gf = grid("front", -6.3, 5, 2.52, zg, n, pz, (1.25, 2.2), sill=0.7, top="seg", rise=0.3, **fr)
    gs = grid("left", 1.2, 4, 2.9, zg, n, pz, (1.15, 2.1), sill=0.7, top="seg", rise=0.3, **fr)
    shops = [grid("front", -6.3, 5, 2.52, 0.0, 1, zg, (2.0, 3.0), sill=0.4, kind="shop", top="seg", rise=0.25,
                  frame="#3a5a52", glass="#2e3c40", skip=[(2, 0)]),
             grid("front", -1.26, 1, 2.52, 0.0, 1, zg, (1.5, 3.3), sill=0.0, top="round", kind="door", glass="#3a5a52",
                  frame="#f6f1e6"),
             grid("front", -1.6, 1, 3.2, ze + 0.6, 1, 2.6, (1.8, 1.8), sill=0.3, top="round", **fr)]
    zones = []
    for k in range(n):
        z = zg + k * pz + 0.45
        zones.append(dict(box=((-99, 99), (-99, 99), (z, z + 0.16)), surface="#3f8a7a"))
    zones.append(dict(box=((-99, 99), (-99, 99), (ze - 0.9, ze - 0.45)), surface=dict(color="#c9a43a", kind="vboard",
                                                                                      pitch=0.3, joint="#3f8a7a")))
    wall = wallmat("cj_wall", dict(color="#f1e7cd", noise=0.05), [gf, gs] + shops, zones=zones, seed=211,
                   decals=[dict(face="front", sym=True, poly=[(0.0, ze + 3.3), (2.6, ze + 3.3), (2.2, ze + 4.4), (0.0, ze + 4.7)],
                                mat="#c9a43a")])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "cj_body", bm, wall)
    front_gable(rig, "cj_gable", "round", 0.0, 8.4, ze, 5.0, wall, y0=0.0, depth=0.5,
                cap_mat=basic("cj_cap", "#f6f1e6", rough=0.7))
    st = basic("cj_st", "#f6f1e6", rough=0.75)
    bm = bmesh.new()
    cornice(bm, x0, x1, 0.0, D, zg - 0.3, [(0.15, 0.1), (0.12, 0.2)])
    cornice(bm, x0, x1, 0.0, D, ze - 0.3, [(0.12, 0.12), (0.18, 0.3)])
    for (u, zc, i, j) in centres(gf):
        if j == n - 1:
            MU.bm_sphere(0.22, center=(u, -0.12, zc + 1.35), scale=(1.0, 0.6, 1.2), subdiv=2, bm=bm)
    pilasters(bm, "front", 0.0, [-6.75, 6.75], zg, ze - 0.3, w=0.5, out=0.12)
    mk(rig, "cj_st", bm, st)
    # semicircular balconies
    slab = basic("cj_slab", "#e9dfc6", rough=0.8)
    rails = Rails("cj_rail", "#1f2a26", "lattice", pitch=0.22, bar=0.03)
    bs = bmesh.new()
    for xc in (-3.78, 3.78):
        for k in (1, 3):
            zf = zg + k * pz + 0.68
            MU.bm_cyl(1.35, 1.35, 0.16, center=(xc, 0.0, zf - 0.08), segs=20, bm=bs)
            for q in range(6):
                a0, a1 = math.pi + math.pi * q / 6, math.pi + math.pi * (q + 1) / 6
                cx = xc + 1.33 * (math.cos(a0) + math.cos(a1)) / 2
                cy = 1.33 * (math.sin(a0) + math.sin(a1)) / 2
                ln = 2 * 1.33 * math.sin(math.pi / 12)
                rails.add_rot(cx, cy, ln + 0.04, 0.04, math.degrees((a0 + a1) / 2) + 90.0, zf, 1.0)
    mk(rig, "cj_balc", bs, slab)
    rails.build(rig)
    mansard(rig, "cj_mans", x0, x1, 0.0, D, ze + 0.12, 3.0, 1.1, 1.4, roofmat("cj_cu", "#5f9c86", "copper"),
            roofmat("cj_cu2", "#4f8a74", "copper"), over=0.2)
    return info(W + 0.6, ze + 5.2, D)


def central_eckturm(rig, p):
    """Budapest eclectic corner house: beige stucco with white ornaments, steep roof with colourful glazed
    Zsolnay tiles in a diamond pattern, corner turret with a tiled helm and gilded finial."""
    W, D = 18.0, 16.0
    x0, x1 = -W / 2, W / 2
    zg, pz, n = 4.4, 3.4, 4
    ze = zg + pz * n
    fr = dict(frame="#f2ede2", mull=dict(v=1, h=[0.68], w=0.06), lit=0.45)
    gf = grid("front", -5.6, 5, 2.8, zg, n, pz, (1.2, 2.1), sill=0.75, **fr)
    gs = grid("left", 3.0, 4, 3.0, zg, n, pz, (1.15, 2.1), sill=0.75, **fr)
    gga = grid("left", D / 2 - 2.6, 2, 2.6, ze + 0.6, 1, 2.6, (1.0, 1.6), sill=0.3, **fr)
    ggb = grid("left", D / 2 - 0.6, 1, 1.2, ze + 3.6, 1, 1.8, (0.7, 1.1), sill=0.3, top="round", **fr)
    shops = [gga, ggb,
             grid("front", -5.6, 5, 2.8, 0.0, 1, zg, (2.1, 3.0), sill=0.45, kind="shop", frame="#3a2e26", glass="#2e3a3e"),
             grid("left", 3.0, 4, 3.0, 0.0, 1, zg, (2.1, 3.0), sill=0.45, kind="shop", frame="#3a2e26", glass="#2e3a3e")]
    wall = wallmat("ce_wall", dict(color="#e0cfa9", noise=0.05), [gf, gs] + shops, seed=221,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zg)), surface=dict(color="#cdbb96", kind="rustic", h=0.55))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "ce_body", bm, wall)
    st = basic("ce_st", "#f2ede2", rough=0.75)
    bm = bmesh.new()
    cornice(bm, x0, x1, 0.0, D, zg - 0.3, [(0.15, 0.1), (0.15, 0.2)])
    for k in range(1, n):
        cornice(bm, x0, x1, 0.0, D, zg + k * pz - 0.1, [(0.13, 0.06)])
    cornice(bm, x0, x1, 0.0, D, ze - 0.3, [(0.15, 0.1), (0.15, 0.25), (0.25, 0.48)])
    for (gg, plane) in ((gf, 0.0), (gs, x0)):
        pediments(bm, gg, plane, rows=[0], kind="tri", h=0.42, out=0.15)
        surrounds(bm, gg, plane, rows=[1, 2, 3], w=0.12, out=0.05)
        sills(bm, gg, plane, h=0.1, out=0.12)
    mk(rig, "ce_st", bm, st)
    tiles = roofmat("ce_zsolnay", "#3c7d5c", "diamond", color2="#d8b13a")
    zr = ze + (D / 2) * math.tan(math.radians(50))
    saddle(rig, "ce_roof", x0, x1, 0.0, D, ze, zr, tiles, axis="x", over_side=0.3, over_end=0.0)
    gable_ends(rig, "ce_ge", x0, x1, 0.0, D, ze, zr, wall, axis="x")
    dormers(rig, "ce_dorm", [-2.8, 2.8, 5.6], 0.0, ze, 50.0, 1.2, 1.5, st, tiles, kind="gable", z_up=0.8, glass_seed=222)
    turret(rig, "ce_tur", x0 + 0.4, 0.4, 2.1, zg + 0.6, ze + 3.0, wall, tiles, kind="helm", roof_h=9.0, corbel=1.6,
           win=(0.75, 1.6, [zg + 2.4, zg + 5.8, zg + 9.2, zg + 12.6, ze + 1.6]), seed=22, finial="#d4ad42")
    return info(W + 1.6, ze + 12.6, D)


# =================================================================================================
# eastern (Poland): small single-family houses with fences and gardens
# =================================================================================================

def _kostka_porch(rig, name, xc, w, y, z_slab, wall, rail_c="#3b3f42"):
    """Balcony over the entrance on two posts (typical 1970s cube house)."""
    bm = bmesh.new()
    bx(bm, xc - w / 2, xc + w / 2, y - 1.6, y, z_slab - 0.18, z_slab)
    for s in (-1, 1):
        bx(bm, xc + s * (w / 2 - 0.15) - 0.1, xc + s * (w / 2 - 0.15) + 0.1, y - 1.55, y - 1.35, 0.0, z_slab - 0.18)
    bx(bm, xc - 0.9, xc + 0.9, y - 1.4, y, 0.0, 0.2)
    bx(bm, xc - 0.9, xc + 0.9, y - 0.9, y, 0.2, 0.4)
    mk(rig, name, bm, wall)
    r = Rails(name + "_rail", rail_c, "bars", pitch=0.16, bar=0.03)
    r.add_box(xc - w / 2, xc + w / 2, y - 1.6, y - 1.56, z_slab)
    r.add_box(xc - w / 2, xc - w / 2 + 0.04, y - 1.6, y, z_slab)
    r.add_box(xc + w / 2 - 0.04, xc + w / 2, y - 1.6, y, z_slab)
    r.build(rig)


def eastern_house_a(rig, p):
    """Kostka: two-storey cube house with a low hip roof, ochre render, balcony over the porch,
    panel fence with plastered posts, apple tree and shed."""
    W, D = 9.4, 9.4
    x0, x1 = -W / 2, W / 2
    Z = 6.6
    win = dict(frame="#f4f4f1", mull=dict(v=1, h=[0.68], w=0.07), lit=0.45)
    gf = grid("front", x0 + 0.5, 3, 2.8, 0.7, 2, 3.0, (1.3, 1.4), sill=0.85, skip=[(1, 0)], **win)
    gs = grid("left", 0.6, 3, 2.75, 0.7, 2, 3.0, (1.2, 1.4), sill=0.85, skip=[(1, 0)], **win)
    door = grid("front", -0.75, 1, 1.5, 0.4, 1, 2.4, (1.05, 2.15), sill=0.0, kind="door", glass="#6a4a32", frame="#4a3424")
    wall = wallmat("eha_wall", dict(color="#d8bd84", noise=0.08), [gf, gs, door],
                   zones=[dict(box=((-20, 20), (-20, 20), (-1, 0.7)), surface=dict(color="#8e887c", noise=0.1)),
                          dict(box=((-20, 20), (-20, 20), (3.55, 3.75)), surface="#b6956a")])
    bm = bmesh.new()
    bx(bm, x0, x1, 0, D, 0, Z)
    mk(rig, "eha_body", bm, wall, bevel=0.03)
    trim = basic("eha_trim", "#e9e6dc", rough=0.7)
    bm = bmesh.new()
    sills(bm, gf, 0.0, h=0.06, out=0.1, ext=0.05)
    sills(bm, gs, x0, h=0.06, out=0.1, ext=0.05)
    bx(bm, x0 - 0.12, x1 + 0.12, -0.12, D + 0.12, Z - 0.2, Z)
    mk(rig, "eha_trim", bm, trim)
    roof = roofmat("eha_roof", "#7a3527", "tiles", rows=0.33)
    hip(rig, "eha_roof", x0, x1, 0, D, Z, Z + 2.1, roof, over=0.55, ridge=0.0)
    chimneys(rig, "eha_chim", [(1.6, D * 0.55)], Z + 1.0, Z + 3.1, basic("eha_chm", "#8b4a35", rough=0.85), w=0.55, d=0.55)
    _kostka_porch(rig, "eha_porch", 0.0, 2.6, 0.0, 3.6, basic("eha_conc", "#d6cfbf", rough=0.85))
    # satellite dish on the road-side wall
    bm = MU.bm_sphere(0.42, center=(x0 - 0.35, 2.2, 5.0), scale=(0.35, 1.0, 1.0), subdiv=2)
    MU.bm_beam((x0, 2.2, 4.8), (x0 - 0.35, 2.2, 4.9), 0.05, bm=bm)
    mk(rig, "eha_dish", bm, basic("eha_dishm", "#d9dad6", rough=0.4), smooth=True)
    # garden: fence with plastered posts and dark bars, apple tree, bushes, shed
    fy = -5.5
    fx = x0 - 4.8
    fence(rig, "eha_fence", [((fx, fy), (-1.8, fy)), ((1.8, fy), (x1 + 1.5, fy)), ((fx, fy), (fx, D + 2.0))],
          h=1.35, kind="panel", color="#2f3a33", post_color="#c9b48d", post_w=0.36, pitch=0.12)
    fence(rig, "eha_gate", [((-1.8, fy), (1.8, fy))], h=1.3, kind="metal", color="#2f3a33", pitch=0.14)
    tree(rig, "eha_apple", fx + 2.3, -2.6, 4.6, 1.7, 5, c1="#47702a", c2="#6f9a3a")
    flowers(rig, "eha_apples", [(fx + 2.3 + 1.2 * math.cos(a), -2.6 + 1.2 * math.sin(a), 3.4 + 0.5 * math.sin(3 * a))
                               for a in [0.3 * k for k in range(18)]], colors=("#c2321f", "#d9a12a"), r=0.08, seed=4)
    for i, (bxp, byp) in enumerate([(-3.6, -0.7), (-2.2, -0.8), (2.4, -0.8), (3.7, -0.7)]):
        crown(rig, "eha_bush%d" % i, (bxp, byp, 0.45), 0.6, 0.45, 0.45, 8, 0.3, 0.42,
              leaves("eha_bl%d" % i, "#3d6526", "#5d8a33", scale=2.5), 30 + i, disp=0.1, flat_bottom=-0.35)
    shed = wallmat("eha_shed", dict(color="#7d5a3c", kind="vboard", pitch=0.2, noise=0.1),
                   [grid("front", fx + 1.1, 1, 1.2, 0.0, 1, 2.2, (0.9, 1.9), sill=0.0, kind="door", glass="#5b3f28")])
    bm = bmesh.new()
    bx(bm, fx + 0.7, fx + 3.1, 6.0, 8.2, 0, 2.3)
    mk(rig, "eha_shed", bm, shed)
    saddle(rig, "eha_shedr", fx + 0.7, fx + 3.1, 6.0, 8.2, 2.3, 2.9, roofmat("eha_shedrm", "#4e5154", "metal"),
           axis="y", over_side=0.2, over_end=0.2)
    return info(W + 11.0, Z + 3.1, D)


# =================================================================================================
# eastern (continued): single-storey house with a steep roof, newer house with thuja hedge, Plattenbau
# =================================================================================================

def eastern_house_b(rig, p):
    """Village-style single-storey house: pale green render, steep gable to the street with attic windows,
    dark red sheet-metal roof, side porch, green picket fence, birch, bench and a small roofed well."""
    W, D = 8.0, 11.0
    x0, x1 = -W / 2, W / 2
    zt = 3.5
    gh = (W / 2) * math.tan(math.radians(45))
    fr = dict(frame="#f4f4f1", mull=dict(v=1, h=[0.66], w=0.07), lit=0.5)
    g = [grid("front", -3.6, 2, 3.6, 0.5, 1, 3.0, (1.2, 1.35), sill=0.75, **fr),
         grid("front", -1.6, 2, 1.6, zt + 0.4, 1, 1.6, (0.75, 0.95), sill=0.3, **fr),
         grid("left", 1.0, 1, 2.0, 0.5, 1, 3.0, (1.1, 1.35), sill=0.75, **fr),
         grid("left", 6.0, 2, 2.4, 0.5, 1, 3.0, (1.1, 1.35), sill=0.75, **fr),
         grid("left", 3.5, 1, 1.4, 0.5, 1, 2.6, (1.0, 2.1), sill=0.0, kind="door", glass="#6a4a2e", frame="#e9e6dc")]
    wall = wallmat("ehb_wall", dict(color="#c0d4ae", noise=0.07), g, seed=231,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, 0.5)), surface=dict(color="#8f8c84", noise=0.1))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, zt)
    mk(rig, "ehb_body", bm, wall)
    front_gable(rig, "ehb_gable", "tri", 0.0, W, zt, gh, wall, y0=0.0, depth=0.3)
    front_gable(rig, "ehb_gb", "tri", 0.0, W, zt, gh, wall, y0=D - 0.3, depth=0.3)
    roof = roofmat("ehb_roof", "#6b2f26", "metal")
    saddle(rig, "ehb_roof", x0, x1, 0.0, D, zt, zt + gh + 0.05, roof, axis="y", over_side=0.45, over_end=0.35)
    chimneys(rig, "ehb_chim", [(1.4, D * 0.6)], zt + 2.0, zt + gh + 1.0, basic("ehb_chm", "#9a5a44", rough=0.85),
             w=0.5, d=0.5)
    # side porch with a small gable canopy
    bm = bmesh.new()
    bx(bm, x0 - 1.5, x0, 2.6, 4.4, 0.0, 0.5)
    bx(bm, x0 - 1.5, x0 - 0.5, 2.6, 4.4, 0.0, 0.25)
    for yy in (2.7, 4.3):
        bx(bm, x0 - 1.45, x0 - 1.3, yy - 0.07, yy + 0.07, 0.5, 2.8)
    mk(rig, "ehb_porch", bm, basic("ehb_wood", "#7a5a3a", rough=0.7))
    saddle(rig, "ehb_canopy", x0 - 1.6, x0, 2.5, 4.5, 2.8, 3.4, roof, axis="x", over_side=0.1, over_end=0.0)
    trim = basic("ehb_trim", "#f2efe6", rough=0.6)
    bm = bmesh.new()
    sills(bm, g[0], 0.0, h=0.06, out=0.1)
    bx(bm, x0 - 0.05, x1 + 0.05, -0.08, D + 0.08, zt - 0.15, zt)
    mk(rig, "ehb_trim", bm, trim)
    fy, fx = -4.5, x0 - 5.0
    fence(rig, "ehb_fence", [((fx, fy), (-1.0, fy)), ((1.0, fy), (x1 + 1.5, fy)), ((fx, fy), (fx, D + 1.0))], h=1.15,
          kind="picket", color="#4f7a45", pitch=0.14)
    fence(rig, "ehb_gate", [((-1.0, fy), (1.0, fy))], h=1.1, kind="picket", color="#4f7a45", pitch=0.14)
    tree(rig, "ehb_birch", fx + 1.6, -2.0, 7.0, 1.6, 23, kind="birch", c1="#6f9a32", c2="#93b84a",
         bark_c=("#e8e6df", "#2a2622"))
    flowers(rig, "ehb_bed", [(x0 + 0.5 + 0.3 * k, -0.6 - 0.15 * (k % 2), 0.25) for k in range(10)] +
            [(1.0 + 0.3 * k, -0.6 - 0.15 * (k % 2), 0.25) for k in range(10)],
            colors=("#e2477a", "#f2c81b", "#d6262b", "#8a5ad6"), r=0.16, seed=23)
    bm = bmesh.new()
    bx(bm, fx + 2.6, fx + 4.0, -3.2, -2.8, 0.42, 0.5)
    for xx in (fx + 2.7, fx + 3.9):
        bx(bm, xx - 0.05, xx + 0.05, -3.15, -2.85, 0.0, 0.42)
    bx(bm, fx + 2.6, fx + 4.0, -2.85, -2.8, 0.5, 0.95)
    mk(rig, "ehb_bench", bm, basic("ehb_bm", "#7a5a3a", rough=0.7))
    # small roofed well
    wb = bmesh.new()
    MU.bm_cyl(0.55, 0.55, 0.8, center=(fx + 1.4, 3.2, 0.4), segs=12, bm=wb)
    mk(rig, "ehb_well", wb, basic("ehb_wm", "#8d877c", rough=0.9))
    wb = bmesh.new()
    for xx in (fx + 0.9, fx + 1.9):
        bx(wb, xx - 0.05, xx + 0.05, 3.15, 3.25, 0.4, 2.0)
    MU.bm_beam((fx + 0.85, 3.2, 1.55), (fx + 1.95, 3.2, 1.55), 0.1, bm=wb)
    mk(rig, "ehb_wpost", wb, basic("ehb_wpm", "#6a4a2e", rough=0.7))
    saddle(rig, "ehb_wroof", fx + 0.7, fx + 2.1, 2.7, 3.7, 2.0, 2.55, roof, axis="x", over_side=0.15, over_end=0.1)
    return info(W + 7.0, zt + gh + 1.0, D)


def eastern_house_c(rig, p):
    """Newer two-storey house: salmon render, anthracite windows with roller shutters, low hip roof, garage
    with a roof terrace, horizontal board fence between plastered posts, a row of thujas."""
    W, D = 10.0, 9.5
    x0, x1 = -W / 2, W / 2
    ze = 6.0
    fr = dict(frame="#3a3d40", mull=dict(v=1, h=0, w=0.07), blind="#5b5f63", blind_max=0.7, lit=0.5)
    g = [grid("front", -4.4, 3, 2.9, 0.3, 1, 2.85, (1.5, 1.4), sill=0.75, skip=[(1, 0)], **fr),
         grid("front", -4.4, 3, 2.9, 3.15, 1, 2.85, (1.5, 1.4), sill=0.7, **fr),
         grid("front", -0.65, 1, 1.3, 0.3, 1, 2.85, (1.1, 2.3), sill=0.0, kind="door", glass="#4a4d50", frame="#3a3d40"),
         grid("left", 2.8, 2, 3.2, 0.3, 1, 2.85, (1.3, 1.4), sill=0.75, **fr),
         grid("left", 1.2, 1, 1.6, 3.15, 1, 2.85, (1.1, 2.3), sill=0.05, kind="door", glass="#31383e", frame="#3a3d40"),
         grid("left", 4.4, 2, 3.0, 3.15, 1, 2.85, (1.3, 1.4), sill=0.7, **fr)]
    wall = wallmat("ehc_wall", dict(color="#e7b39d", noise=0.05), g, seed=241,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, 0.3)), surface=dict(color="#6f6d69", noise=0.08)),
                          dict(box=((-99, -1.0), (-99, 0.5), (3.0, 6.1)), surface=dict(color="#efe9e0", noise=0.04))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "ehc_body", bm, wall)
    hip(rig, "ehc_roof", x0, x1, 0.0, D, ze, ze + 2.7, roofmat("ehc_roof", "#3c3f43", "tiles", rows=0.33), over=0.6)
    gar = wallmat("ehc_gar", dict(color="#efe9e0", noise=0.04), [
        grid("front", x0 - 3.4, 1, 3.2, 0.0, 1, 2.7, (2.6, 2.2), sill=0.0, kind="door", glass="#c9cbcc", frame="#8f9294")],
        decals=[dict(face="front", sym=False, poly=[(x0 - 3.1, z), (x0 - 0.5, z), (x0 - 0.5, z + 0.03), (x0 - 3.1, z + 0.03)],
                     mat="#8f9294") for z in (0.55, 1.1, 1.65)])
    bm = bmesh.new()
    bx(bm, x0 - 3.6, x0, 0.4, 6.8, 0.0, 2.9)
    mk(rig, "ehc_garage", bm, gar)
    rails = Rails("ehc_rail", "#2b2e31", "bars", pitch=0.12, bar=0.03)
    rails.add_box(x0 - 3.6, x0, 0.4, 0.44, 3.0)
    rails.add_box(x0 - 3.6, x0 - 3.56, 0.4, 6.8, 3.0)
    rails.build(rig)
    bm = bmesh.new()
    bx(bm, x0 - 3.7, x0 + 0.05, 0.3, 6.9, 2.9, 3.0)
    mk(rig, "ehc_terr", bm, basic("ehc_tm", "#9b9893", rough=0.8))
    fy, fx = -5.0, x0 - 6.0
    fence(rig, "ehc_fence", [((fx, fy), (x0 - 3.8, fy)), ((-1.0, fy), (x1 + 1.5, fy)), ((fx, fy), (fx, D + 1.0))], h=1.5,
          kind="boards", color="#7d6b58", post_color="#efe9e0", post_w=0.4)
    fence(rig, "ehc_gate", [((x0 - 3.8, fy), (-1.0, fy))], h=1.45, kind="metal", color="#3a3d40", pitch=0.1)
    for k in range(7):
        tree(rig, "ehc_thuja%d" % k, fx + 0.7, fy + 1.0 + k * 1.3, 3.0, 0.55, 240 + k, kind="thuja")
    tree(rig, "ehc_tree", x1 + 0.6, -2.4, 4.0, 1.3, 249, c1="#4b7a2c", c2="#6f9a3a")
    return info(W + 9.0, ze + 2.7, D)


def eastern_plattenbau(rig, p):
    """Polish prefab block (wielka plyta): eleven storeys of panels with visible joints, thermo-renovated in
    pastel colour fields, two columns of loggias with coloured parapets, stairwell window strip, entrance
    canopy, flat roof with machine room and aerials, satellite dishes."""
    W, D = 28.8, 12.0
    x0, x1 = -W / 2, W / 2
    zg, pz, n = 3.0, 2.8, 10
    ze = zg + pz * n
    fr = dict(frame="#f2f2ef", mull=dict(v=1, h=0, w=0.07), lit=0.45)
    gf = grid("front", x0, 8, 3.6, zg, n, pz, (1.5, 1.4), sill=0.85, skip=[(3, j) for j in range(n)] + [(4, j) for j in range(n)], **fr)
    g0 = grid("front", x0, 8, 3.6, 0.0, 1, zg, (1.5, 1.3), sill=1.0, skip=[(3, 0), (4, 0)], **fr)
    gst = grid("front", -0.5, 1, 1.0, zg + 1.4, n, pz, (0.8, 1.6), sill=0.3, lit=0.75, color=("#fff2d6",), frame="#d8d8d2",
               glass="#8a9aa3")
    gdoor = grid("front", -1.0, 1, 2.0, 0.0, 1, 2.8, (1.6, 2.3), sill=0.0, kind="door", glass="#4b5560", frame="#8f9294")
    gl = grid("left", 1.0, 3, 3.6, zg, n, pz, (0.9, 1.2), sill=0.95, **fr)
    zones = [dict(box=((-99, 99), (-99, 99), (-1, zg)), surface=dict(color="#8d8a84", kind="panel", pu=3.6, pz=1.5, jw=0.03)),
             dict(box=((x0 - 1, -10.8), (-99, 99), (zg, ze)), surface=dict(color="#e9c45e", kind="panel", pu=3.6, pz=pz,
                                                                          u0=x0, z0=zg, joint="#bf9c45")),
             dict(box=((10.8, x1 + 1), (-99, 99), (zg, ze)), surface=dict(color="#a7c977", kind="panel", pu=3.6, pz=pz,
                                                                        u0=x0, z0=zg, joint="#83a35b")),
             dict(box=((-1.8, 1.8), (-99, 99), (zg, ze + 1)), surface=dict(color="#e39a5a", kind="panel", pu=3.6, pz=pz,
                                                                          u0=x0, z0=zg, joint="#b97a44"))]
    wall = wallmat("epb_wall", dict(color="#ece6d8", kind="panel", pu=3.6, pz=pz, u0=x0, z0=zg, joint="#b9b3a6"),
                   [gf, g0, gst, gdoor, gl], zones=zones, seed=251)
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze + 0.8)
    mk(rig, "epb_body", bm, wall)
    # loggias: two columns, slabs + coloured parapets
    slab = basic("epb_slab", "#cfcac0", rough=0.85)
    par_a = basic("epb_para", "#5b8fb0", rough=0.6)
    par_b = basic("epb_parb", "#d77a4f", rough=0.6)
    bs, ba, bb = bmesh.new(), bmesh.new(), bmesh.new()
    rng = random.Random(25)
    dishes = []
    for xc in (-7.2, 7.2):
        for k in range(n):
            z = zg + k * pz
            bx(bs, xc - 1.75, xc + 1.75, -1.2, 0.0, z - 0.15, z)
            bx(ba if (k + (xc > 0)) % 2 else bb, xc - 1.75, xc + 1.75, -1.25, -1.15, z, z + 1.05)
            for s in (-1, 1):
                bx(bs, xc + s * 1.75 - 0.08, xc + s * 1.75 + 0.08, -1.2, 0.0, z, z + 1.05)
            if rng.random() < 0.35:
                dishes.append((xc + rng.uniform(-1.2, 1.2), -1.3, z + 1.35))
    mk(rig, "epb_slab", bs, slab)
    mk(rig, "epb_para", ba, par_a)
    mk(rig, "epb_parb", bb, par_b)
    bl = bmesh.new()
    for xc in (-7.2, 7.2):
        for k in range(n):
            z = zg + k * pz
            bx(bl, xc - 1.4, xc + 1.4, -0.03, 0.0, z + 0.1, z + 2.35)
    mk(rig, "epb_logg", bl, M.basic("epb_lgm", "#33404a", rough=0.1, spec=0.9, emit={"lights": ("#ffd59a", 0.5)}))
    bm = bmesh.new()
    for (dx, dy, dz) in dishes:
        MU.bm_sphere(0.38, center=(dx, dy, dz), scale=(1.0, 0.35, 1.0), subdiv=2, bm=bm)
    for (dx, dy, dz) in ((x0 + 0.5 + 3.6 * k + 1.0, -0.3, zg + pz * (k % n) + 1.0) for k in (1, 5, 7)):
        MU.bm_sphere(0.38, center=(dx, dy, dz), scale=(1.0, 0.35, 1.0), subdiv=2, bm=bm)
    mk(rig, "epb_dishes", bm, basic("epb_dm", "#dcdcd8", rough=0.4), smooth=True)
    bm = bmesh.new()
    bx(bm, -2.4, 2.4, -1.6, 0.0, 2.7, 2.9)
    bx(bm, -6.0, 0.0, 3.0, 7.5, ze + 0.8, ze + 3.2)
    for (ax_, ay_) in ((-11.0, 6.0), (4.0, 5.0), (11.0, 7.0)):
        MU.bm_beam((ax_, ay_, ze + 0.8), (ax_, ay_, ze + 4.0), 0.06, bm=bm)
        for q in range(3):
            MU.bm_beam((ax_ - 0.7, ay_, ze + 3.0 + q * 0.3), (ax_ + 0.7, ay_, ze + 3.0 + q * 0.3), 0.04, bm=bm)
    mk(rig, "epb_roofstuff", bm, basic("epb_rs", "#a9a59c", rough=0.7))
    flat_parapet(rig, "epb_par", x0, x1, 0.0, D, ze + 0.8, basic("epb_pm", "#d7d1c3"), h=0.6, inset=0.25)
    return info(W, ze + 4.0, D)


# =================================================================================================
# balkan: unfinished brick house, finished house with balustrade, Serbo-Byzantine church, brutalist block
# =================================================================================================

def balkan_house(rig, p):
    """Typical unfinished Balkan family house: plastered ground floor, raw red hollow-brick upper floor in a
    grey concrete frame, flat slab with rebar sticking out for the next storey, cantilevered balcony
    slab without railing, concrete wall with a red metal gate, vine pergola."""
    W, D = 10.0, 9.0
    x0, x1 = -W / 2, W / 2
    fr = dict(frame="#f4f4f1", mull=dict(v=1, h=0, w=0.07), lit=0.5)
    g = [grid("front", -4.5, 3, 3.0, 0.0, 1, 2.9, (1.3, 1.3), sill=0.9, skip=[(1, 0)], **fr),
         grid("front", -0.6, 1, 1.2, 0.0, 1, 2.9, (1.0, 2.2), sill=0.05, kind="door", glass="#6a4a2e", frame="#e9e6dc"),
         grid("front", -4.5, 3, 3.0, 3.1, 1, 2.9, (1.2, 1.3), sill=0.8, skip=[(2, 0)], **fr),
         grid("front", 1.5, 1, 3.0, 3.1, 1, 2.9, (1.2, 1.4), sill=0.75, kind="door", glass="#121314", frame="#7a7670"),
         grid("left", 1.5, 2, 3.0, 0.0, 1, 2.9, (1.2, 1.3), sill=0.9, **fr),
         grid("left", 3.0, 1, 3.0, 3.1, 1, 2.9, (1.1, 1.3), sill=0.8, **fr)]
    zones = [dict(box=((-99, 99), (-99, 99), (3.1, 5.8)), surface=dict(color="#b85c38", kind="brick", scale=1.25,
                                                                         mortar="#9d8f7e", mortar_size=0.02)),
             dict(box=((-99, 99), (-99, 99), (2.82, 3.1)), surface=dict(color="#a8a59d", noise=0.1)),
             dict(box=((-99, 99), (-99, 99), (5.8, 6.2)), surface=dict(color="#a8a59d", noise=0.1))]
    wall = wallmat("bh_wall", dict(color="#eeeae0", noise=0.06), g, zones=zones, seed=261)
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, 6.2)
    mk(rig, "bh_body", bm, wall)
    conc = basic("bh_conc", "#a8a59d", rough=0.9, color2="#8f8c85", var_scale=3.0)
    bm = bmesh.new()
    for xx in (x0, 0.0, x1):
        bx(bm, xx - 0.17, xx + 0.17, -0.03, 0.3, 2.82, 6.2)
    for yy in (0.0, D / 2, D):
        bx(bm, x0 - 0.03, x0 + 0.3, yy - 0.17 if yy > 0 else 0.0, yy + 0.17 if yy < D else D, 2.82, 6.2)
    bx(bm, x0 - 0.15, x1 + 0.15, -0.15, D + 0.15, 6.2, 6.45)
    bx(bm, -2.6, 1.0, -1.4, 0.0, 2.9, 3.12)
    mk(rig, "bh_frame", bm, conc)
    rust = basic("bh_rebar", "#6a3a22", rough=0.6, metal=0.3)
    bm = bmesh.new()
    for xx in (x0, 0.0, x1):
        for yy in (0.0, D / 2, D):
            for (dx, dy) in ((-0.1, -0.1), (0.1, -0.1), (-0.1, 0.1), (0.1, 0.1)):
                MU.bm_beam((xx + dx, yy + dy, 6.45), (xx + dx * 1.4, yy + dy * 1.4, 7.6), 0.035, bm=bm)
    mk(rig, "bh_rebar", bm, rust)
    fy, fx = -4.5, x0 - 4.5
    fence(rig, "bh_wall2", [((fx, fy), (-1.6, fy)), ((1.6, fy), (x1 + 1.2, fy)), ((fx, fy), (fx, D))], h=1.4, kind="wall",
          color="#bab6ad", post_color="#a9a59c")
    fence(rig, "bh_gate", [((-1.6, fy), (1.6, fy))], h=1.5, kind="metal", color="#8a2a22", pitch=0.11)
    # vine pergola on the road side
    wood = basic("bh_wood", "#6a4a2e", rough=0.75)
    bm = bmesh.new()
    for (px, py) in ((x0 - 3.6, 0.5), (x0 - 3.6, 5.5), (x0 - 0.4, 0.5), (x0 - 0.4, 5.5)):
        bx(bm, px - 0.07, px + 0.07, py - 0.07, py + 0.07, 0.0, 2.5)
    for py in (0.5, 3.0, 5.5):
        bx(bm, x0 - 3.8, x0 - 0.2, py - 0.05, py + 0.05, 2.45, 2.55)
    mk(rig, "bh_perg", bm, wood)
    crown(rig, "bh_vine", (x0 - 2.0, 3.0, 2.75), 2.0, 2.8, 0.35, 26, 0.35, 0.6, leaves("bh_vl", "#4a7a2a", "#6f9a3a"), 27,
          disp=0.12, shell=0.2)
    bm = MU.bm_sphere(0.42, center=(x1 + 0.3, 3.0, 5.0), scale=(0.35, 1.0, 1.0), subdiv=2)
    mk(rig, "bh_dish", bm, basic("bh_dm", "#dcdcd8", rough=0.4), smooth=True)
    return info(W + 5.7, 7.6, D)


def balkan_house_b(rig, p):
    """Finished Balkan house: peach render, white balustrade balcony across the front, red tile hip roof,
    the road-side wall still unplastered brick, wrought-iron fence on white posts, fig tree and roses."""
    W, D = 10.0, 10.0
    x0, x1 = -W / 2, W / 2
    ze = 6.2
    fr = dict(frame="#f4f4f1", mull=dict(v=1, h=[0.66], w=0.07), blind="#cfc8bb", blind_max=0.6, lit=0.5)
    g = [grid("front", -4.5, 3, 3.0, 0.2, 1, 2.9, (1.3, 1.4), sill=0.85, skip=[(1, 0)], **fr),
         grid("front", -0.6, 1, 1.2, 0.2, 1, 2.9, (1.05, 2.25), sill=0.0, kind="door", glass="#5a3a26", frame="#efece4"),
         grid("front", -4.5, 3, 3.0, 3.1, 1, 3.1, (1.25, 2.2), sill=0.15, **fr),
         grid("left", 2.0, 2, 3.5, 0.2, 2, 2.95, (1.2, 1.35), sill=0.85, **fr)]
    zones = [dict(box=((-99, x0 + 0.02), (-99, 99), (-1, 99)), surface=dict(color="#b5603c", kind="brick", scale=1.3,
                                                                            mortar="#a09380", mortar_size=0.02)),
             dict(box=((-99, 99), (-99, 99), (-1, 0.2)), surface=dict(color="#9b968c", noise=0.08))]
    wall = wallmat("bhb_wall", dict(color="#eab38e", noise=0.06), g, zones=zones, seed=271)
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "bhb_body", bm, wall)
    hip(rig, "bhb_roof", x0, x1, 0.0, D, ze, ze + 2.8, roofmat("bhb_roof", "#a84c33", "tiles", rows=0.32), over=0.65)
    white = basic("bhb_white", "#f2efe8", rough=0.7)
    bm = bmesh.new()
    bx(bm, x0 - 0.2, x1 + 0.2, -1.4, 0.0, 2.95, 3.15)
    for xx in (x0 + 0.2, x1 - 0.2):
        bx(bm, xx - 0.15, xx + 0.15, -1.3, -1.0, 0.0, 2.95)
    bx(bm, x0 - 0.06, x1 + 0.06, -0.06, D + 0.06, ze - 0.25, ze)
    mk(rig, "bhb_white", bm, white)
    bal = Rails("bhb_bal", "#f2efe8", "balusters", pitch=0.24, h=0.95)
    bal.add_box(x0 - 0.2, x1 + 0.2, -1.4, -1.25, 3.15)
    bal.add_box(x0 - 0.2, x0 - 0.05, -1.4, 0.0, 3.15)
    bal.build(rig)
    fy, fx = -4.8, x0 - 4.5
    fence(rig, "bhb_fence", [((fx, fy), (-1.5, fy)), ((1.5, fy), (x1 + 1.2, fy)), ((fx, fy), (fx, D))], h=1.6,
          kind="panel", color="#1f2020", post_color="#efece4", post_w=0.4, pitch=0.13)
    fence(rig, "bhb_gate", [((-1.5, fy), (1.5, fy))], h=1.7, kind="metal", color="#1f2020", pitch=0.12)
    bm = bmesh.new()
    for xx in [fx + 2.4 * k for k in range(4)] + [-1.5, 1.5]:
        MU.bm_sphere(0.12, center=(xx, fy, 1.86), subdiv=1, bm=bm)
    mk(rig, "bhb_knobs", bm, basic("bhb_gold", "#c9a43a", rough=0.35, metal=0.8))
    tree(rig, "bhb_fig", fx + 2.0, -1.8, 4.2, 1.8, 28, c1="#3f6b28", c2="#5d8a33")
    for i in range(3):
        crown(rig, "bhb_rose%d" % i, (-3.5 + 3.4 * i, -2.2, 0.5), 0.5, 0.4, 0.5, 6, 0.25, 0.35,
              leaves("bhb_rl%d" % i, "#3d6526", "#557f31"), 280 + i, disp=0.06, flat_bottom=-0.4)
    flowers(rig, "bhb_roses", [(-3.5 + 3.4 * i + 0.35 * math.cos(a), -2.5 + 0.2 * math.sin(a), 0.75)
                               for i in range(3) for a in (0.0, 1.6, 3.1, 4.7)], colors=("#c41e3a", "#f2f0f0"), r=0.12,
            seed=29)
    return info(W + 5.7, ze + 2.8, D)


def balkan_church(rig, p):
    """Serbo-Byzantine church: walls in alternating courses of red brick and pale stone, arched windows,
    cross-shaped roof, octagonal drum with a lead-grey dome, four corner domes, front bell tower with an
    onion dome, gilded crosses."""
    stone = "#e6dcc3"
    zones = []
    z = 0.55
    while z < 30:
        zones.append(dict(box=((-99, 99), (-99, 99), (z, z + 0.24)), surface=dict(color=stone, noise=0.05)))
        z += 0.78
    fr = dict(frame=stone, frame_w=0.16, mull=dict(v=1, h=0, w=0.06), lit=0.6, color=("#ffcf7a", "#ffd890"), strength=1.3)
    g = [grid("left", 4.0, 2, 3.0, 2.0, 1, 5.0, (1.0, 2.8), sill=0.8, top="round", **fr),
         grid("left", 15.0, 2, 3.0, 2.0, 1, 5.0, (1.0, 2.8), sill=0.8, top="round", **fr),
         grid("left", 10.0, 2, 2.0, 2.0, 2, 4.0, (0.9, 2.4), sill=0.6, top="round", **fr),
         grid("front", -0.9, 1, 1.8, 0.0, 1, 4.2, (1.6, 3.2), sill=0.0, top="round", kind="door", glass="#3f2a1c",
              frame=stone),
         grid("front", -0.6, 1, 1.2, 7.0, 1, 3.0, (0.8, 2.0), sill=0.5, top="round", **fr),
         grid("front", -0.7, 1, 1.4, 14.0, 1, 3.6, (1.0, 2.6), sill=0.5, top="round", kind="door", glass="#1d1e1f",
              frame=stone),
         grid("front", -6.5, 2, 2.2, 2.0, 1, 5.0, (0.9, 2.6), sill=0.8, top="round", **fr),
         grid("front", 2.1, 2, 2.2, 2.0, 1, 5.0, (0.9, 2.6), sill=0.8, top="round", **fr),
         grid("front", -7.6, 1, 2.0, 2.5, 1, 5.0, (1.0, 2.6), sill=0.6, top="round", **fr)]
    wall = wallmat("bc_wall", dict(color="#b0563c", kind="brick", scale=2.4, mortar="#d6c9b0"), g, zones=zones,
                   seed=281)
    bm = bmesh.new()
    bx(bm, -6.0, 6.0, 3.0, 21.0, 0.0, 9.0)
    bx(bm, -8.5, 8.5, 9.0, 15.0, 0.0, 9.0)
    bx(bm, -2.4, 2.4, -2.0, 3.0, 0.0, 18.0)
    mk(rig, "bc_body", bm, wall)
    lead = roofmat("bc_lead", "#61676c", "metal", var=0.15)
    saddle(rig, "bc_r1", -6.0, 6.0, 3.0, 21.0, 9.0, 12.6, lead, axis="y", over_side=0.3, over_end=0.2)
    saddle(rig, "bc_r2", -8.5, 8.5, 9.0, 15.0, 9.0, 12.6, lead, axis="x", over_side=0.3, over_end=0.2)
    gable_ends(rig, "bc_ge1", -6.0, 6.0, 3.0, 21.0, 9.0, 12.6, wall, axis="y")
    gable_ends(rig, "bc_ge2", -8.5, 8.5, 9.0, 15.0, 9.0, 12.6, wall, axis="x")
    gold = basic("bc_gold", "#d4ad42", rough=0.3, metal=0.9)
    bcr = bmesh.new()
    lathe(rig, "bc_drum", [(0.0, 11.0), (3.1, 11.0), (3.1, 16.6), (0.0, 16.6)], (0.0, 12.0, 0.0), wall, segs=8, smooth=False)
    glass_boxes(rig, "bc_dw", [(math.cos(a) * 3.0 - 0.35, math.cos(a) * 3.0 + 0.35, 12.0 + math.sin(a) * 3.0 - 0.35,
                                12.0 + math.sin(a) * 3.0 + 0.35, 12.8, 15.2) for a in [math.radians(225 + 45 * k) for k in range(3)]],
                lit=0.8, color="#ffcf7a")
    lathe(rig, "bc_dome", [(0.0, 16.6)] + dome_prof(3.4, 2.9, base=16.6) + [(0.0, 19.5)], (0.0, 12.0, 0.0), lead, segs=24)
    cross(bcr, 0.0, 12.0, 19.4, h=2.0)
    for (cx, cy) in ((-4.3, 5.5), (4.3, 5.5), (-4.3, 18.5), (4.3, 18.5)):
        lathe(rig, "bc_sd%d%d" % (cx > 0, cy > 10), [(0.0, 9.6), (1.3, 9.6), (1.3, 12.0), (0.0, 12.0)], (cx, cy, 0.0), wall,
              segs=8, smooth=False)
        lathe(rig, "bc_sdd%d%d" % (cx > 0, cy > 10), [(0.0, 12.0)] + dome_prof(1.45, 1.3, base=12.0) + [(0.0, 13.3)],
              (cx, cy, 0.0), lead, segs=16)
        cross(bcr, cx, cy, 13.25, h=1.2)
    lathe(rig, "bc_onion", [(0.0, 18.0)] + [(r, 18.0 + z_) for (r, z_) in onion(4.2, 2.3)], (0.0, 0.5, 0.0), lead, segs=20)
    cross(bcr, 0.0, 0.5, 22.4, h=1.8)
    mk(rig, "bc_crosses", bcr, gold)
    bm = bmesh.new()
    cornice(bm, -2.4, 2.4, -2.0, 3.0, 17.8, [(0.2, 0.15)])
    cornice(bm, -6.0, 6.0, 3.0, 21.0, 8.8, [(0.2, 0.12)])
    cornice(bm, -8.5, 8.5, 9.0, 15.0, 8.8, [(0.2, 0.12)])
    mk(rig, "bc_cor", bm, basic("bc_st", stone, rough=0.8))
    return info(17.6, 24.2, 23.0)


def balkan_plattenbau(rig, p):
    """Socialist high-rise (Novi Beograd style): raw weathered concrete, continuous balcony bands with solid
    parapets on every floor, randomly glazed loggias, air conditioners and satellite dishes, shops below."""
    W, D = 28.0, 14.0
    x0, x1 = -W / 2, W / 2
    zg, pz, n = 3.6, 2.9, 12
    ze = zg + pz * n
    fr = dict(frame="#c9ccce", mull=dict(v=1, h=0, w=0.07), lit=0.45)
    gf = grid("front", x0 + 0.5, 8, 3.375, zg, n, pz, (2.2, 2.2), sill=0.15, **fr)
    gl = grid("left", 1.5, 3, 3.6, zg, n, pz, (0.9, 1.2), sill=0.9, **fr)
    shops = grid("front", x0 + 0.5, 6, 4.5, 0.0, 1, zg, (3.6, 2.8), sill=0.4, kind="shop", frame="#3a3d40",
                 glass="#2e3a40", color=("#ffcf8a", "#bfe0ff"))
    wall = wallmat("bp_wall", dict(color="#a8a59e", kind="concrete", joint="#7d7a73", pz=pz, noise=0.1),
                   [gf, gl, shops], seed=291)
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze + 1.0)
    mk(rig, "bp_body", bm, wall)
    conc = wallmat("bp_conc", dict(color="#b1aea6", kind="concrete", joint="#85827a", pz=pz, noise=0.12), [], seed=292)
    bm = bmesh.new()
    for k in range(n):
        z = zg + k * pz
        bx(bm, x0 - 0.3, x1 + 0.3, -1.5, 0.0, z - 0.2, z)
        bx(bm, x0 - 0.3, x1 + 0.3, -1.5, -1.3, z, z + 1.05)
        bx(bm, x0 - 0.3, x0 - 0.1, -1.5, 0.0, z, z + 1.05)
    for xx in (x0 + 0.2, x1 - 0.2):
        bx(bm, xx - 0.25, xx + 0.25, -1.5, 0.0, 0.0, ze + 1.0)
    bx(bm, x0 - 0.4, x1 + 0.4, -1.6, D, ze + 1.0, ze + 1.4)
    mk(rig, "bp_bands", bm, conc)
    rng = random.Random(29)
    bg, bf, ba, bd = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for k in range(n):
        z = zg + k * pz
        xx = x0
        while xx < x1 - 2.0:
            w = rng.choice((3.4, 6.8))
            if rng.random() < 0.3 and xx + w < x1:
                bx(bg, xx + 0.1, xx + w - 0.1, -1.38, -1.32, z + 1.05, z + pz - 0.25)
                for q in range(int(w / 1.1) + 1):
                    bx(bf, xx + 0.1 + q * (w - 0.2) / max(1, int(w / 1.1)) - 0.03, xx + 0.13 + q * (w - 0.2) / max(1, int(w / 1.1)),
                       -1.4, -1.3, z + 1.05, z + pz - 0.25)
            if rng.random() < 0.25:
                ax_ = xx + rng.uniform(0.5, w - 0.8)
                bx(ba, ax_, ax_ + 0.8, -1.75, -1.5, z + 0.4, z + 0.95)
            if rng.random() < 0.2:
                MU.bm_sphere(0.4, center=(xx + rng.uniform(0.6, w - 0.6), -1.7, z + 1.4), scale=(1.0, 0.35, 1.0), subdiv=2, bm=bd)
            xx += w
    mk(rig, "bp_glz", bg, M.basic("bp_glzm", "#71838f", rough=0.12, spec=0.8, emit={"lights": ("#ffd59a", 0.35)}))
    mk(rig, "bp_glzf", bf, basic("bp_al", "#c9ccce", rough=0.4, metal=0.6))
    mk(rig, "bp_ac", ba, basic("bp_acm", "#e2e2de", rough=0.4))
    mk(rig, "bp_dish", bd, basic("bp_dm", "#d6d6d2", rough=0.4), smooth=True)
    sign = M.basic("bp_sign", "#b8242a", rough=0.4, emit={"lights": ("#ff4a3a", 1.3)})
    bm = bmesh.new()
    bx(bm, x0 + 1.0, x0 + 8.0, -0.1, 0.0, 3.0, 3.5)
    bx(bm, 2.0, 8.0, -0.1, 0.0, 3.0, 3.5)
    mk(rig, "bp_sign", bm, sign)
    return info(W + 0.8, ze + 1.4, D)


# =================================================================================================
# baltic: wooden houses (Riga, Kaunas), Riga Art Nouveau block
# =================================================================================================

def _casings(bm, g, plane, w=0.12, ped=0.35, out=0.06):
    """White carved window casings: side boards, sill and a small pointed pediment."""
    wu, wz = g["win"]
    for (u, zc, i, j) in centres(g):
        a, b = zc - wz / 2 - 0.1, zc + wz / 2 + 0.12
        fbox(bm, g["face"], plane, u - wu / 2 - w, u - wu / 2, a, b, 0.0, out)
        fbox(bm, g["face"], plane, u + wu / 2, u + wu / 2 + w, a, b, 0.0, out)
        fbox(bm, g["face"], plane, u - wu / 2 - w - 0.05, u + wu / 2 + w + 0.05, a - 0.08, a, 0.0, out + 0.04)
        fprism(bm, g["face"], plane, [(u - wu / 2 - w - 0.06, b), (u + wu / 2 + w + 0.06, b), (u, b + ped)], 0.0, out + 0.02)


def baltic_wood(rig, p):
    """Riga / Kaunas wooden house: ochre clapboard on a stone plinth, white corner boards and carved window
    casings, dark red sheet-metal roof with a central cross gable and balcony, glazed veranda on the road
    side, grey picket fence, lilac."""
    W, D = 11.0, 10.0
    x0, x1 = -W / 2, W / 2
    zp, ze = 0.6, 6.4
    fr = dict(frame="#f4f2ec", mull=dict(v=1, h=[0.62], w=0.06), lit=0.5)
    g = [grid("front", -5.1, 4, 2.55, zp, 2, 2.9, (1.0, 1.5), sill=0.7, **fr),
         grid("front", -0.9, 1, 1.8, ze + 0.2, 1, 2.2, (1.0, 1.6), sill=0.2, kind="door", glass="#3b4650", frame="#f4f2ec"),
         grid("left", 7.0, 1, 2.4, zp, 2, 2.9, (1.0, 1.5), sill=0.7, **fr)]
    wood = dict(color="#d9a74a", kind="clap", pitch=0.18, joint="#9c7428", noise=0.06)
    wall = wallmat("bw_wall", wood, g, seed=301,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zp)), surface=dict(color="#8d8a83", kind="ashlar", h=0.3,
                                                                                  w=0.6, strength=0.5))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "bw_body", bm, wall)
    roof = roofmat("bw_roof", "#7d3b2d", "metal")
    zr = ze + (D / 2) * math.tan(math.radians(40))
    saddle(rig, "bw_roof", x0, x1, 0.0, D, ze, zr, roof, axis="x", over_side=0.5, over_end=0.4)
    gable_ends(rig, "bw_ge", x0, x1, 0.0, D, ze, zr, wall, axis="x")
    front_gable(rig, "bw_cg", "tri", 0.0, 4.2, ze, 2.8, wall, y0=0.0, depth=0.4,
                cap_mat=basic("bw_capm", "#f4f2ec", rough=0.6))
    saddle(rig, "bw_cgr", -2.1, 2.1, 0.4, 4.4, ze, ze + 2.8, roof, axis="y", over_side=0.35, over_end=0.0, over_end0=0.4)
    white = basic("bw_white", "#f4f2ec", rough=0.6)
    bm = bmesh.new()
    _casings(bm, g[0], 0.0)
    _casings(bm, g[2], x0)
    for (xx, yy) in ((x0, 0.0), (x1, 0.0), (x0, D)):
        bx(bm, xx - 0.12, xx + 0.12, yy - 0.12 if yy == 0 else yy - 0.12, yy + 0.12, zp, ze)
    bx(bm, x0 - 0.06, x1 + 0.06, -0.08, D + 0.08, zp + 2.85, zp + 3.0)
    bx(bm, -1.5, 1.5, -0.9, 0.0, ze - 0.05, ze + 0.1)
    mk(rig, "bw_trim", bm, white)
    bal = Rails("bw_bal", "#f4f2ec", "balusters", pitch=0.2, h=0.9)
    bal.add_box(-1.5, 1.5, -0.9, -0.84, ze + 0.1)
    bal.build(rig)
    # glazed veranda on the road side
    ver = wallmat("bw_ver", dict(color="#f4f2ec", noise=0.02), [
        grid("left", 1.3, 7, 0.68, 1.4, 2, 0.75, (0.56, 0.62), sill=0.06, frame="#f4f2ec", lit=0.6, glass="#3c4a54"),
        grid("front", -7.4, 3, 0.66, 1.4, 2, 0.75, (0.54, 0.62), sill=0.06, frame="#f4f2ec", lit=0.6, glass="#3c4a54")],
        seed=302)
    bm = bmesh.new()
    bx(bm, x0 - 2.0, x0, 1.3, 6.2, zp, 3.2)
    mk(rig, "bw_veranda", bm, ver)
    saddle(rig, "bw_verr", x0 - 2.2, x0 + 0.05, 1.1, 6.4, 3.2, 3.9, roof, axis="y", over_side=0.15, over_end=0.0)
    fy, fx = -4.0, x0 - 5.0
    fence(rig, "bw_fence", [((fx, fy), (-1.0, fy)), ((1.0, fy), (x1 + 1.5, fy)), ((fx, fy), (fx, D + 1.0))], h=1.2,
          kind="picket", color="#8f8676", pitch=0.15)
    crown(rig, "bw_lilac", (fx + 1.8, -1.5, 1.6), 1.3, 1.1, 1.4, 16, 0.4, 0.6, leaves("bw_ll", "#3f6526", "#5d7f35"), 31,
          disp=0.12, flat_bottom=-1.2)
    flowers(rig, "bw_lilacf", [(fx + 1.8 + 1.1 * math.cos(a), -1.5 - 0.6 + 0.4 * math.sin(a), 1.6 + 0.8 * math.sin(2.3 * a))
                               for a in [k * 0.55 for k in range(14)]], colors=("#9a6ac9", "#b98ad9"), r=0.22, seed=31)
    tree(rig, "bw_apple", fx + 1.6, 4.5, 4.8, 1.8, 32)
    return info(W + 6.6, zr + 0.3, D)


def baltic_wood_b(rig, p):
    """Wooden house with its gable to the street: green clapboard, white trim and carved bargeboards, gable
    balcony, side porch with a small gable canopy, white picket fence, birch."""
    W, D = 9.0, 11.0
    x0, x1 = -W / 2, W / 2
    zp, zt = 0.6, 4.4
    gh = (W / 2) * math.tan(math.radians(45))
    fr = dict(frame="#f4f2ec", mull=dict(v=1, h=[0.62], w=0.06), lit=0.5)
    g = [grid("front", -3.9, 3, 2.6, zp, 1, 3.8, (1.0, 1.5), sill=0.8, **fr),
         grid("front", -2.0, 2, 2.0, zt + 0.2, 1, 2.4, (0.9, 1.4), sill=0.4, **fr),
         grid("front", -0.5, 1, 1.0, zt + 2.9, 1, 1.3, (0.6, 0.8), sill=0.2, top="round", **fr),
         grid("left", 1.2, 1, 2.2, zp, 1, 3.8, (1.0, 1.5), sill=0.8, **fr),
         grid("left", 7.0, 2, 2.0, zp, 1, 3.8, (1.0, 1.5), sill=0.8, **fr),
         grid("left", 4.0, 1, 1.4, zp, 1, 3.8, (1.0, 2.2), sill=0.0, kind="door", glass="#5a4030", frame="#f4f2ec")]
    wood = dict(color="#6f8f60", kind="clap", pitch=0.18, joint="#4d6a42", noise=0.06)
    wall = wallmat("bwb_wall", wood, g, seed=311,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zp)), surface=dict(color="#8d8a83", noise=0.08))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, zt)
    mk(rig, "bwb_body", bm, wall)
    white = basic("bwb_white", "#f4f2ec", rough=0.6)
    front_gable(rig, "bwb_gable", "tri", 0.0, W, zt, gh, wall, y0=0.0, depth=0.3, cap_mat=white)
    front_gable(rig, "bwb_gb", "tri", 0.0, W, zt, gh, wall, y0=D - 0.3, depth=0.3)
    roof = roofmat("bwb_roof", "#4f5358", "metal")
    saddle(rig, "bwb_roof", x0, x1, 0.0, D, zt, zt + gh + 0.1, roof, axis="y", over_side=0.4, over_end=0.4, over_end0=0.5)
    bm = bmesh.new()
    _casings(bm, g[0], 0.0)
    _casings(bm, g[1], 0.0, ped=0.3)
    _casings(bm, g[3], x0)
    _casings(bm, g[4], x0)
    for (xx, yy) in ((x0, 0.0), (x1, 0.0), (x0, D)):
        bx(bm, xx - 0.12, xx + 0.12, yy - 0.12, yy + 0.12, zp, zt)
    bx(bm, x0 - 0.06, x1 + 0.06, -0.08, D + 0.08, zt - 0.12, zt + 0.02)
    bx(bm, -1.6, 1.6, -0.8, 0.0, zt + 0.05, zt + 0.18)
    mk(rig, "bwb_trim", bm, white)
    bal = Rails("bwb_bal", "#f4f2ec", "balusters", pitch=0.2, h=0.85)
    bal.add_box(-1.6, 1.6, -0.8, -0.74, zt + 0.18)
    bal.build(rig)
    bm = bmesh.new()
    bx(bm, x0 - 1.6, x0, 3.2, 4.8, 0.0, 0.6)
    for yy in (3.3, 4.7):
        bx(bm, x0 - 1.55, x0 - 1.4, yy - 0.07, yy + 0.07, 0.6, 2.9)
    mk(rig, "bwb_porch", bm, white)
    saddle(rig, "bwb_canopy", x0 - 1.7, x0, 3.1, 4.9, 2.9, 3.6, roof, axis="x", over_side=0.1, over_end=0.0)
    fy, fx = -4.2, x0 - 4.5
    fence(rig, "bwb_fence", [((fx, fy), (-1.0, fy)), ((1.0, fy), (x1 + 1.5, fy)), ((fx, fy), (fx, D + 1.0))], h=1.1,
          kind="picket", color="#efece4", pitch=0.14)
    tree(rig, "bwb_birch", fx + 1.8, -1.6, 8.0, 1.7, 33, kind="birch", c1="#6f9a32", c2="#93b84a",
         bark_c=("#e8e6df", "#2a2622"))
    return info(W + 6.2, zt + gh + 0.4, D)


def baltic_jugendstil(rig, p):
    """Riga Art Nouveau block (Alberta iela style): pale blue facade with white ornament, pilaster strips,
    two bay windows, round-topped top-floor windows, masks, a tall decorative attic gable with an oculus
    and pinnacles, dark mansard."""
    W, D = 18.0, 14.0
    x0, x1 = -W / 2, W / 2
    zg, pz, n = 4.4, 3.3, 5
    ze = zg + pz * n
    fr = dict(frame="#f6f4ee", mull=dict(v=1, h=[0.7], w=0.05), lit=0.45)
    gf = grid("front", -8.1, 6, 2.7, zg, n - 1, pz, (1.2, 2.1), sill=0.75, skip=[(0, j) for j in range(4)] + [(5, j) for j in range(4)],
              **fr)
    gtop = grid("front", -8.1, 6, 2.7, zg + pz * (n - 1), 1, pz, (1.1, 2.1), sill=0.7, top="round", **fr)
    gs = grid("left", 1.2, 4, 3.0, zg, n, pz, (1.1, 2.0), sill=0.75, **fr)
    shops = [grid("front", -8.1, 6, 2.7, 0.0, 1, zg, (2.0, 3.1), sill=0.4, kind="shop", top="seg", rise=0.2,
                  frame="#2a3a4a", glass="#2e3a42")]
    gatt = grid("front", -1.5, 1, 3.0, ze + 0.8, 1, 2.6, (2.0, 2.0), sill=0.3, top="round", **fr)
    wall = wallmat("bj_wall", dict(color="#a9c3d6", noise=0.05), [gf, gtop, gs, gatt] + shops, seed=321,
                   zones=[dict(box=((-99, 99), (-99, 99), (-1, zg)), surface=dict(color="#d9dcd6", kind="rustic", h=0.5))])
    bm = bmesh.new()
    bx(bm, x0, x1, 0.0, D, 0.0, ze)
    mk(rig, "bj_body", bm, wall)
    # bay windows (Erker) on floors 1-4 at the outer axes
    erk = []
    for xc in (-6.75, 6.75):
        erk.append(grid("front", xc - 1.3, 2, 1.3, zg, n - 1, pz, (0.95, 2.1), sill=0.75, **fr))
        erk.append(grid("left", -0.9, 1, 0.8, zg, n - 1, pz, (0.5, 2.0), sill=0.75, **fr))
    we = wallmat("bj_erk", dict(color="#a9c3d6", noise=0.05), erk, seed=322)
    bm = bmesh.new()
    for xc in (-6.75, 6.75):
        bx(bm, xc - 1.35, xc + 1.35, -0.95, 0.05, zg + 0.3, zg + pz * (n - 1))
    mk(rig, "bj_erker", bm, we)
    front_gable(rig, "bj_att", "round", 0.0, 8.0, ze, 5.6, wall, y0=0.0, depth=0.5,
                cap_mat=basic("bj_capm", "#f6f4ee", rough=0.7))
    st = basic("bj_white", "#f6f4ee", rough=0.75)
    bm = bmesh.new()
    cornice(bm, x0, x1, 0.0, D, zg - 0.3, [(0.15, 0.1), (0.15, 0.2)])
    cornice(bm, x0, x1, 0.0, D, ze - 0.3, [(0.15, 0.12), (0.2, 0.3)])
    for xc in (-6.75, 6.75):
        cornice(bm, xc - 1.35, xc + 1.35, -0.95, 0.0, zg + 0.05, [(0.25, 0.0), (0.15, 0.1)])
        cornice(bm, xc - 1.35, xc + 1.35, -0.95, 0.0, zg + pz * (n - 1), [(0.15, 0.1)])
    for xx in (-4.05, -1.35, 1.35, 4.05):
        fbox(bm, "front", 0.0, xx - 0.22, xx + 0.22, zg, ze - 0.3, 0.0, 0.12)
        MU.bm_sphere(0.3, center=(xx, -0.18, ze - 0.95), scale=(1.0, 0.6, 1.25), subdiv=2, bm=bm)
    for xx in (-8.6, 8.6):
        bx(bm, xx - 0.4, xx + 0.4, -0.1, 0.7, ze - 0.3, ze + 3.0)
        MU.bm_sphere(0.45, center=(xx, 0.3, ze + 3.4), subdiv=2, bm=bm)
    for (u, zc, i, j) in centres(gtop):
        MU.bm_sphere(0.22, center=(u, -0.1, zc + 1.4), scale=(1.0, 0.6, 1.2), subdiv=2, bm=bm)
    mk(rig, "bj_orn", bm, st)
    rails = Rails("bj_rail", "#1f2a2e", "lattice", pitch=0.22, bar=0.03)
    bs = bmesh.new()
    balconies(bs, rails, gtop, 0.0, [0], depth=0.6, ext=0.3, rail_h=0.95, span=(-5.4, 5.4))
    mk(rig, "bj_slab", bs, st)
    rails.build(rig)
    mansard(rig, "bj_mans", x0, x1, 0.0, D, ze + 0.15, 3.0, 1.1, 1.3, roofmat("bj_roof", "#4b5157", "slate"),
            roofmat("bj_roof2", "#5a6066", "metal"), over=0.25)
    return info(W + 0.8, ze + 5.6, D)


# =================================================================================================
# bridge parts
# =================================================================================================

STEEL_GREEN = "#56676a"


def bridge_truss_arch(rig, p):
    """Steel truss arch portal over the whole carriageway (clear width 29.4 m), anchor = road centre;
    two truss planes 1.8 m apart, riveted gusset plates, two suspended lamps. No ground shadow."""
    steel = basic("bta_steel", STEEL_GREEN, rough=0.55, metal=0.45, color2=shade(STEEL_GREEN, 0.85), var_scale=1.5)
    plate = basic("bta_plate", shade(STEEL_GREEN, 0.92), rough=0.5, metal=0.5)
    bm = bmesh.new()
    bp = bmesh.new()
    xi, xo = 14.7, 15.9
    zi, zo = 9.0, 10.6

    def low(x):
        return zi + 4.2 * (1 - (x / xi) ** 2)

    def up(x):
        return zo + 4.7 * (1 - (x / xo) ** 2)

    N = 12
    for y in (0.0, 1.8):
        for s in (-1, 1):
            # posts: inner + outer chord with a lattice
            MU.bm_beam((s * xi, y, 0.0), (s * xi, y, zi), 0.5, 0.55, bm=bm)
            MU.bm_beam((s * xo, y, 0.0), (s * xo, y, zo), 0.55, 0.55, bm=bm)
            zz = 0.6
            k = 0
            while zz < zi - 0.8:
                z2 = min(zz + 1.5, zi)
                a, b = (s * xi, y, zz), (s * xo, y, z2)
                if k % 2:
                    a, b = (s * xo, y, zz), (s * xi, y, z2)
                MU.bm_beam(a, b, 0.2, 0.22, bm=bm)
                MU.bm_beam((s * xi, y, zz), (s * xo, y, zz), 0.18, 0.2, bm=bm)
                for xx in (s * xi, s * xo):
                    bx(bp, xx - 0.25, xx + 0.25, y - 0.32, y - 0.28, zz - 0.25, zz + 0.25)
                zz += 1.5
                k += 1
            bx(bm, min(s * xi, s * xo) - 0.5, max(s * xi, s * xo) + 0.5, y - 0.45, y + 0.45, 0.0, 0.3)
            MU.bm_beam((s * xi, y, zi), (s * xo, y, zo), 0.4, 0.5, bm=bm)
        # arch chords, verticals and diagonals
        xs = [-xi + 2 * xi * k / N for k in range(N + 1)]
        xu = [-xo + 2 * xo * k / N for k in range(N + 1)]
        for k in range(N):
            MU.bm_beam((xs[k], y, low(xs[k])), (xs[k + 1], y, low(xs[k + 1])), 0.55, 0.5, bm=bm, up=(0, 1, 0))
            MU.bm_beam((xu[k], y, up(xu[k])), (xu[k + 1], y, up(xu[k + 1])), 0.6, 0.55, bm=bm, up=(0, 1, 0))
        for k in range(N + 1):
            MU.bm_beam((xs[k], y, low(xs[k])), (xu[k], y, up(xu[k])), 0.26, 0.3, bm=bm)
            if k < N:
                if k < N // 2:
                    MU.bm_beam((xs[k], y, low(xs[k])), (xu[k + 1], y, up(xu[k + 1])), 0.2, 0.24, bm=bm)
                else:
                    MU.bm_beam((xu[k], y, up(xu[k])), (xs[k + 1], y, low(xs[k + 1])), 0.2, 0.24, bm=bm)
            for (xx, zz) in ((xs[k], low(xs[k])), (xu[k], up(xu[k]))):
                bx(bp, xx - 0.32, xx + 0.32, y - 0.3, y - 0.26, zz - 0.32, zz + 0.32)
    # cross ties and portal bracing between the two planes
    for k in range(0, N + 1, 2):
        x = -xo + 2 * xo * k / N
        MU.bm_beam((x, 0.0, up(x)), (x, 1.8, up(x)), 0.3, 0.3, bm=bm)
    for s in (-1, 1):
        for z in (3.0, 6.0, zi):
            MU.bm_beam((s * xo, 0.0, z), (s * xo, 1.8, z), 0.25, 0.25, bm=bm)
    mk(rig, "bta_truss", bm, steel, shadow=False)
    mk(rig, "bta_plates", bp, plate, shadow=False)
    # suspended lamps
    lamp = lamp_mat("bta_lamp", strength=10.0)
    hous = basic("bta_lh", "#3a4144", rough=0.4, metal=0.5)
    bl, bh = bmesh.new(), bmesh.new()
    for x in (-5.0, 5.0):
        zt = low(x)
        MU.bm_beam((x, 0.9, zt - 0.2), (x, 0.9, zt - 1.6), 0.06, bm=bh)
        bx(bh, x - 0.45, x + 0.45, 0.6, 1.2, zt - 1.85, zt - 1.6)
        bx(bl, x - 0.38, x + 0.38, 0.65, 1.15, zt - 1.92, zt - 1.84)
    mk(rig, "bta_lh", bh, hous, shadow=False)
    mk(rig, "bta_lamp", bl, lamp, shadow=False)
    return dict(object=obj_size(2 * xo + 0.6, up(0.0) + 0.3, 1.8))


def bridge_pylon(rig, p):
    """Cable-stayed bridge pylon (Koehlbrand type) for the RIGHT roadside: tapered concrete leg leaning
    slightly towards the road, anchorage head, semi-fan of stay cables from the head down to the deck
    edge on the road side, forwards and backwards along the road; floodlit at night, aviation light.
    Anchor = pylon foot at deck level. No ground shadow (water and deck are drawn by the renderer)."""
    H = 82.0
    lean = math.radians(3.5)
    m, nb = M.new_material("bpy_conc")
    x, y, z = nb.coords()
    mp = nb.node("ShaderNodeMapping")
    nb.links.new(nb.texco(), mp.inputs["Vector"])
    mp.inputs["Scale"].default_value = (5.0, 5.0, 0.25)
    streak = nb.ramp(nb.noise(1.0, detail=2.0, vec=mp.outputs[0]), [(0.4, (0, 0, 0, 1)), (0.8, (1, 1, 1, 1))])
    col = nb.mix(nb.mul(streak, 0.35), M.srgb("#cfcdc6"), M.srgb("#9d9b94"))
    seg = nb.lt(_mod(nb, z, 6.0), 0.05)
    col = nb.mix(nb.mul(seg, 0.5), col, M.srgb("#8e8c86"))
    out = M.principled(nb, col, rough=0.8, spec=0.3)
    flood = nb.color_scale(M.emit_col("#e8ecf6", 0.11), nb.math("POWER", nb.sub(1.0, nb.math("DIVIDE", z, H)), 1.5))
    conc = M.finish(m, nb, out, {"lights": flood})
    rings = []
    for k in range(9):
        t = k / 8
        zz = H * t
        hw, hd = 2.2 - 0.85 * t, 3.0 - 1.2 * t
        cx = -math.tan(lean) * zz
        rings.append([(cx - hw, -hd, zz), (cx + hw, -hd, zz), (cx + hw, hd, zz), (cx - hw, hd, zz)])
    bm = MU.loft(rings, cap0=True, cap1=True)
    mk(rig, "bpy_leg", bm, conc, shadow=False)
    top_x = -math.tan(lean) * H
    bm = bmesh.new()
    bx(bm, top_x - 1.6, top_x + 1.6, -2.0, 2.0, H, H + 1.2)
    MU.prism([(top_x - 1.4, H + 1.2), (top_x + 1.4, H + 1.2), (top_x, H + 6.0)], 3.6, bm=bm, plane="XZ", offset=-1.8)
    bx(bm, -3.0, 3.0, -4.0, 4.0, 0.0, 0.8)
    mk(rig, "bpy_head", bm, conc, shadow=False)
    cable = basic("bpy_cable", "#ecebe6", rough=0.35, metal=0.3)
    anch = basic("bpy_anch", "#7d8287", rough=0.5, metal=0.5)
    bc, ba = bmesh.new(), bmesh.new()
    nca = 10
    xdeck = -4.2
    for side in (-1, 1):
        for k in range(nca):
            za = H - 3.0 - k * 2.6
            xa = -math.tan(lean) * za - (2.2 - 0.85 * za / H) - 0.1
            yd = side * (16.0 + k * 7.4)
            MU.bm_beam((xa, side * 0.6, za), (xdeck, yd, 0.6), 0.24, bm=bc)
            bx(ba, xa - 0.25, xa + 0.05, side * 0.6 - 0.25, side * 0.6 + 0.25, za - 0.25, za + 0.25)
    mk(rig, "bpy_cables", bc, cable, shadow=False)
    mk(rig, "bpy_anch", ba, anch, shadow=False)
    red = M.basic("bpy_red", "#a01010", rough=0.3, emit={"lights": ("#ff2010", 9.0)})
    bm = bmesh.new()
    MU.bm_sphere(0.45, center=(top_x, 0.0, H + 6.3), subdiv=1, bm=bm)
    mk(rig, "bpy_red", bm, red, shadow=False)
    return dict(object=obj_size(9.0, H + 6.8, 2 * (16.0 + (nca - 1) * 7.4)))


def bridge_lamp(rig, p):
    """Ornate cast-iron candelabra for stone bridges: fluted column on a moulded pedestal, gilded rings,
    two scrolled arms with hexagonal lanterns and a crowning lantern. Anchor = foot of the pedestal."""
    iron = basic("bl_iron", "#1f2a24", rough=0.45, metal=0.6)
    gold = basic("bl_gold", "#b8973e", rough=0.35, metal=0.85)
    glass = M.basic("bl_glass", "#f3e7c4", rough=0.15, spec=0.8, emit={"lights": ("#ffd890", 9.0)})
    prof = [(0.0, 0.0), (0.36, 0.0), (0.36, 0.18), (0.3, 0.26), (0.3, 0.7), (0.24, 0.82), (0.24, 1.0), (0.18, 1.12),
            (0.14, 1.2), (0.14, 3.5), (0.11, 3.6), (0.2, 3.72), (0.2, 3.82), (0.0, 3.82)]
    bm = MU.bm_lathe(prof, segs=12)
    mk(rig, "bl_post", bm, iron, smooth=True)
    bm = bmesh.new()
    for zz in (0.72, 1.16, 3.56):
        MU.bm_cyl(0.2 if zz > 1.0 else 0.33, 0.2 if zz > 1.0 else 0.33, 0.05, center=(0.0, 0.0, zz), segs=12, bm=bm)
    mk(rig, "bl_rings", bm, gold, smooth=True)
    bm = bmesh.new()
    for s in (-1, 1):
        pts = [(0.0, 3.75), (s * 0.25, 3.95), (s * 0.55, 4.0), (s * 0.8, 3.92), (s * 0.92, 3.98)]
        for a, b in zip(pts[:-1], pts[1:]):
            MU.bm_beam((a[0], 0.0, a[1]), (b[0], 0.0, b[1]), 0.06, bm=bm)
        # scroll under the arm
        for q in range(6):
            t0, t1 = q / 6 * 1.6 * math.pi, (q + 1) / 6 * 1.6 * math.pi
            r0, r1 = 0.16 * (1 - q / 7), 0.16 * (1 - (q + 1) / 7)
            MU.bm_beam((s * (0.35 + r0 * math.cos(t0)), 0.0, 3.7 + r0 * math.sin(t0)),
                       (s * (0.35 + r1 * math.cos(t1)), 0.0, 3.7 + r1 * math.sin(t1)), 0.035, bm=bm)
    mk(rig, "bl_arms", bm, iron)
    for i, (lx, lz, sc) in enumerate(((-0.92, 4.0, 1.0), (0.92, 4.0, 1.0), (0.0, 3.82, 1.15))):
        bm = MU.bm_lathe([(0.0, lz), (0.09 * sc, lz), (0.16 * sc, lz + 0.12 * sc), (0.0, lz + 0.12 * sc)], segs=6,
                         center=(lx, 0.0, 0.0))
        mk(rig, "bl_lb%d" % i, bm, iron)
        bm = MU.bm_lathe([(0.0, lz + 0.12 * sc), (0.16 * sc, lz + 0.12 * sc), (0.2 * sc, lz + 0.5 * sc), (0.0, lz + 0.5 * sc)],
                         segs=6, center=(lx, 0.0, 0.0))
        mk(rig, "bl_lg%d" % i, bm, glass)
        bm = MU.bm_lathe([(0.0, lz + 0.5 * sc), (0.26 * sc, lz + 0.5 * sc), (0.0, lz + 0.72 * sc)], segs=6,
                         center=(lx, 0.0, 0.0))
        MU.bm_sphere(0.05 * sc, center=(lx, 0.0, lz + 0.78 * sc), subdiv=1, bm=bm)
        mk(rig, "bl_lc%d" % i, bm, iron)
    return dict(object=obj_size(2.2, 4.85, 0.72))


# =================================================================================================
# registry (merged into props.PROPS)
# =================================================================================================

BLD = dict(margins=(0.6, 0.6, 0.35))
GLOW_WIN = {"lights": [(0.07, 0.3), (0.3, 0.08)]}
GLOW_LAMP = {"lights": [(0.08, 0.9), (0.35, 0.6), (1.0, 0.25)]}
GLOW_LANTERN = {"lights": [(0.03, 0.9), (0.12, 0.55), (0.3, 0.25)]}


# one resolution factor for all city buildings (PNG budget, docs/sprites.md "Import und Speicher"):
# e.g. 0.85 shrinks every building sheet by about a quarter; needs a re-render of props/city_
RES_SCALE = 1.0


def _b(fn, fit_h, style, zone, yaw=-20, max_w=512, glow=None, extra=None):
    cam = dict(BLD)
    cam.update(extra or {})
    fit_h = fit_h if RES_SCALE == 1.0 else int(round(fit_h * RES_SCALE / 4.0)) * 4
    return (fn, fit_h, yaw, cam, True, glow or GLOW_WIN, ["building", "city", "mirror_left", style, zone], max_w)


CITY_PROPS = {
    "city_hanse_gabled": _b(hanse_gabled, 304, "hanse", "center"),
    "city_hanse_kontor": _b(hanse_kontor, 352, "hanse", "center"),
    "city_hanse_speicher": _b(hanse_speicher, 352, "hanse", "center"),
    "city_hanse_crane": _b(hanse_crane, 320, "hanse", "outskirts", yaw=-24),
    "city_german_house": _b(german_house, 192, "german", "outskirts", yaw=-24),
    "city_german_mietshaus": _b(german_mietshaus, 256, "german", "outskirts"),
    "city_german_gruenderzeit": _b(german_gruenderzeit, 336, "german", "center"),
    "city_german_office": _b(german_office, 448, "german", "center"),
    "city_german_old_fachwerk": _b(german_old_fachwerk, 288, "german_old", "center"),
    "city_german_old_fachwerk_b": _b(german_old_fachwerk_b, 336, "german_old", "center"),
    "city_german_old_barock": _b(german_old_barock, 304, "german_old", "center"),
    "city_dutch_canal": _b(dutch_canal, 304, "dutch", "center"),
    "city_dutch_canal_b": _b(dutch_canal_b, 304, "dutch", "center"),
    "city_dutch_terrace": _b(dutch_terrace, 208, "dutch", "outskirts"),
    "city_belgian_terrace": _b(belgian_terrace, 256, "belgian", "center"),
    "city_belgian_stone": _b(belgian_stone, 288, "belgian", "center"),
    "city_paris_haussmann": _b(paris_haussmann, 336, "paris", "center"),
    "city_paris_corner": _b(paris_haussmann_corner, 336, "paris", "center"),
    "city_french_maison": _b(french_maison, 224, "french", "outskirts", yaw=-24),
    "city_french_sud": _b(french_sud, 192, "french", "outskirts", yaw=-24),
    "city_french_immeuble": _b(french_immeuble, 288, "french", "center"),
    "city_spanish_block": _b(spanish_block, 336, "spanish", "center"),
    "city_spanish_casa": _b(spanish_casa, 192, "spanish", "outskirts", yaw=-24),
    "city_spanish_ladrillo": _b(spanish_ladrillo, 320, "spanish", "center"),
    "city_italian_palazzo": _b(italian_palazzo, 288, "italian", "center"),
    "city_italian_block": _b(italian_block, 304, "italian", "center"),
    "city_italian_venezia": _b(italian_venezia, 288, "italian", "center"),
    "city_vienna_palais": _b(vienna_palais, 304, "vienna", "center"),
    "city_vienna_kirche": _b(vienna_kirche, 384, "vienna", "center"),
    "city_vienna_zinshaus": _b(vienna_zinshaus, 312, "vienna", "center"),
    "city_swiss_chalet": _b(swiss_chalet, 224, "swiss", "outskirts", yaw=-24),
    "city_swiss_laube": _b(swiss_laube, 288, "swiss", "center"),
    "city_central_barock": _b(central_barock, 288, "central", "center"),
    "city_central_jugendstil": _b(central_jugendstil, 312, "central", "center"),
    "city_central_eckturm": _b(central_eckturm, 336, "central", "center"),
    "city_eastern_house_a": _b(eastern_house_a, 192, "eastern", "outskirts", yaw=-24),
    "city_eastern_house_b": _b(eastern_house_b, 192, "eastern", "outskirts", yaw=-24),
    "city_eastern_house_c": _b(eastern_house_c, 192, "eastern", "outskirts", yaw=-24),
    "city_eastern_plattenbau": _b(eastern_plattenbau, 368, "eastern", "center"),
    "city_balkan_house": _b(balkan_house, 192, "balkan", "outskirts", yaw=-24),
    "city_balkan_house_b": _b(balkan_house_b, 192, "balkan", "outskirts", yaw=-24),
    "city_balkan_church": _b(balkan_church, 320, "balkan", "center"),
    "city_balkan_plattenbau": _b(balkan_plattenbau, 384, "balkan", "center"),
    "city_baltic_wood": _b(baltic_wood, 192, "baltic", "outskirts", yaw=-24),
    "city_baltic_wood_b": _b(baltic_wood_b, 192, "baltic", "outskirts", yaw=-24),
    "city_baltic_jugendstil": _b(baltic_jugendstil, 336, "baltic", "center"),
    "bridge_truss_arch": (bridge_truss_arch, 320, 0, dict(margins=(0.4, 0.4, 0.2)), True, GLOW_LAMP,
                          ["bridge", "overhead"], 768),
    "bridge_pylon": (bridge_pylon, 512, -20, dict(margins=(0.6, 0.6, 0.3)), True, GLOW_LAMP,
                     ["bridge", "mirror_left"], 640),
    "bridge_lamp": (bridge_lamp, 256, 0, dict(margins=(0.6, 0.6, 0.06)), True, GLOW_LANTERN,
                    ["bridge", "road", "mirror_left"], 256),
    "houseboat": (houseboat, 160, -20, dict(margins=(0.4, 0.4, 0.2)), True, GLOW_WIN, ["boat", "water", "mirror_left"],
                  512),
}
UNCENTERED = {k for k in CITY_PROPS if k.startswith("city_")} | {"houseboat", "bridge_pylon", "bridge_lamp"}
CATCHER = {}
