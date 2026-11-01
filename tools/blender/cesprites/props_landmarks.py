"""Landmarks of the destination cities (docs/staedte.md section 3): big props "landmarks/<name>", modelled
procedurally at real size with the rig, materials and light passes of the other props.

Conventions (as for the buildings in props_buildings): metres, origin = centre of the near face on the
ground (the sprite anchor), the landmark extends along +y (away from the road camera), x to the right,
z up. Every set has one angle "c" (a 3/4 view chosen per landmark with view_yaw), the layers base +
lights (night: floodlighting of the facades, lit windows, aviation lights) and its real size in "object".
Landmarks are never mirrored (no tag mirror_left): towers and wings stay where they belong.

Night look: the base layer is darkened by the game, the lights layer is drawn over it. Floodlit surfaces
emit their own albedo tinted by the floodlight colour (Shade.flood), so stone, brick and copper keep their
colour at night; emission stays <= 1 (the brightness comes from light_gain in the post-processing).
"""
import math

import bmesh
from mathutils import Vector

from . import materials as M
from . import meshutil as MU
from .props_buildings import obj_size

E = 3.0                      # camera elevation (deg): landmarks are seen from far away, nearly level
WARM = "#ffc46b"             # lit windows (as in props_buildings)
FLOOD = "#ffd9a8"            # warm floodlight (sodium / halogen)
FLOOD_WHITE = "#fff1df"
GOLD = "#ffc768"
FLOOD_K = 0.5                # global floodlight calibration (see Shade.flood)
RED_LIGHT = "#ff2a16"


# --- geometry helpers ---------------------------------------------------------------------------

def make(rig, name, bm, mat, smooth=False, sharp=35.0):
    return MU.make(name, bm, mat, parent=rig.root, smooth=smooth, sharp_deg=sharp)


def box(bm, x0, x1, y0, y1, z0, z1, mat_index=0):
    """Axis-aligned box by its bounds."""
    return MU.bm_box(x1 - x0, y1 - y0, z1 - z0, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), bm=bm,
                     mat_index=mat_index)


def beam(bm, a, b, w, h=None, mat_index=0):
    return MU.bm_beam(a, b, w, h, bm=bm, mat_index=mat_index)


def circle(r, n, cx=0.0, cy=0.0, phase=0.0):
    return [(cx + r * math.cos(phase + 2 * math.pi * i / n), cy + r * math.sin(phase + 2 * math.pi * i / n))
            for i in range(n)]


def lathe(bm, prof, segs, cx=0.0, cy=0.0, phase=0.0, mat_index=0, cap=True):
    """Solid of revolution about the vertical axis through (cx, cy). prof: [(r, z)] from bottom to top;
    r = 0 at the ends closes the solid. phase rotates the vertices (octagons with flat faces: pi / 8)."""
    rings = []
    for (r, z) in prof:
        if r <= 1e-6:
            rings.append([bm.verts.new((cx, cy, z))])
        else:
            rings.append([bm.verts.new((cx + r * math.cos(phase + 2 * math.pi * i / segs),
                                        cy + r * math.sin(phase + 2 * math.pi * i / segs), z)) for i in range(segs)])
    faces = []
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                q = (a[0], b[j], b[i])
            elif len(b) == 1:
                q = (a[i], a[j], b[0])
            else:
                q = (a[i], a[j], b[j], b[i])
            try:
                faces.append(bm.faces.new(q))
            except ValueError:
                pass
    if cap and len(rings[0]) > 1:
        faces.append(bm.faces.new(list(reversed(rings[0]))))
    if cap and len(rings[-1]) > 1:
        faces.append(bm.faces.new(rings[-1]))
    for f in faces:
        f.material_index = mat_index
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return bm


def prism(bm, pts, z0, z1, mat_index=0):
    """Vertical prism over a 2D polygon [(x, y)] (any orientation)."""
    a = [bm.verts.new((x, y, z0)) for (x, y) in pts]
    b = [bm.verts.new((x, y, z1)) for (x, y) in pts]
    faces = [bm.faces.new(a), bm.faces.new(list(reversed(b)))]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
    for f in faces:
        f.material_index = mat_index
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return bm


def pyramid(bm, pts, z0, apex, mat_index=0):
    """Pyramid / spire over a 2D base polygon at z0 with apex (x, y, z)."""
    vs = [bm.verts.new((x, y, z0)) for (x, y) in pts]
    top = bm.verts.new(apex)
    faces = [bm.faces.new(list(reversed(vs)))]
    for i in range(len(vs)):
        faces.append(bm.faces.new((vs[i], vs[(i + 1) % len(vs)], top)))
    for f in faces:
        f.material_index = mat_index
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return bm


def frustum(bm, pts0, z0, pts1, z1, mat_index=0, caps=True):
    """Loft between two polygons with the same number of points (tapering shafts, roofs)."""
    a = [bm.verts.new((x, y, z0)) for (x, y) in pts0]
    b = [bm.verts.new((x, y, z1)) for (x, y) in pts1]
    faces = []
    n = len(a)
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
    if caps:
        faces.append(bm.faces.new(list(reversed(a))))
        faces.append(bm.faces.new(b))
    for f in faces:
        f.material_index = mat_index
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return bm


def ray_poly(poly, n, cx, cy, phase=0.0, scale=1.0):
    """n points on a convex polygon, one per ray from (cx, cy) at equal angles (to loft a polygon
    smoothly into a circle with the same number of points)."""
    out = []
    for i in range(n):
        a = phase + 2 * math.pi * i / n
        dx, dy = math.cos(a), math.sin(a)
        best = None
        for j in range(len(poly)):
            (x1, y1), (x2, y2) = poly[j], poly[(j + 1) % len(poly)]
            ex, ey = x2 - x1, y2 - y1
            den = dx * ey - dy * ex
            if abs(den) < 1e-9:
                continue
            t = ((x1 - cx) * ey - (y1 - cy) * ex) / den
            s = ((x1 - cx) * dy - (y1 - cy) * dx) / den
            if t > 0 and -1e-6 <= s <= 1 + 1e-6 and (best is None or t < best):
                best = t
        out.append((cx + dx * best * scale, cy + dy * best * scale))
    return out


def rect(cx, cy, w, d):
    return [(cx - w / 2, cy - d / 2), (cx + w / 2, cy - d / 2), (cx + w / 2, cy + d / 2), (cx - w / 2, cy + d / 2)]


def octagon(cx, cy, r):
    """Regular octagon with flat faces towards the axes; r = inner radius (apothem)."""
    R = r / math.cos(math.pi / 8)
    return circle(R, 8, cx, cy, math.pi / 8)


def gable_roof(bm, x0, x1, y0, y1, z_eave, z_ridge, axis="y", hip=0.0, mat_index=0):
    """Closed gable (or hipped, hip > 0) roof volume over a rectangle; ridge along axis."""
    if axis == "y":
        xm = (x0 + x1) / 2
        pts = [(x0, y0, z_eave), (x1, y0, z_eave), (x1, y1, z_eave), (x0, y1, z_eave),
               (xm, y0 + hip, z_ridge), (xm, y1 - hip, z_ridge)]
        v = [bm.verts.new(q) for q in pts]
        fs = [(v[0], v[1], v[4]), (v[2], v[3], v[5]), (v[1], v[2], v[5], v[4]), (v[3], v[0], v[4], v[5]),
              (v[0], v[3], v[2], v[1])]
    else:
        ym = (y0 + y1) / 2
        pts = [(x0, y0, z_eave), (x1, y0, z_eave), (x1, y1, z_eave), (x0, y1, z_eave),
               (x0 + hip, ym, z_ridge), (x1 - hip, ym, z_ridge)]
        v = [bm.verts.new(q) for q in pts]
        fs = [(v[0], v[1], v[5], v[4]), (v[2], v[3], v[4], v[5]), (v[1], v[2], v[5]), (v[3], v[0], v[4]),
              (v[0], v[3], v[2], v[1])]
    faces = [bm.faces.new(f) for f in fs]
    for f in faces:
        f.material_index = mat_index
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return bm


def pinnacle(bm, x, y, z0, w, h, top=0.45, finial=True, mat_index=0):
    """Gothic pinnacle: square shaft, small pyramid spire (+ finial knob)."""
    zs = z0 + h * (1.0 - top)
    box(bm, x - w / 2, x + w / 2, y - w / 2, y + w / 2, z0, zs, mat_index)
    k = w * 0.62
    pyramid(bm, rect(x, y, k * 1.25, k * 1.25), zs, (x, y, z0 + h), mat_index)
    if finial:
        box(bm, x - w * 0.12, x + w * 0.12, y - w * 0.12, y + w * 0.12, z0 + h - 0.1, z0 + h + w * 0.35, mat_index)
    return bm


def arch_pts(cx, z0, half_w, rise, n=12):
    """Points of a round/segmental arch in the (x, z) plane from left to right (springing at z0)."""
    return [(cx - half_w * math.cos(math.pi * i / n), z0 + rise * math.sin(math.pi * i / n)) for i in range(n + 1)]


def dome_profile(r, h, kind="dome", n=12, z0=0.0, neck=0.0):
    """Lathe profiles [(r, z)] from the base ring to the tip.
    dome: half ellipsoid; onion: bulging bulb with a pointed tip; bell: Dresden-like bell (concave
    flare at the bottom); helmet: Munich 'Welsche Haube' (onion with a waist); pointed: gothic ogive."""
    out = []
    if kind == "dome":
        for i in range(n + 1):
            a = 0.5 * math.pi * i / n
            out.append((r * math.cos(a), z0 + h * math.sin(a)))
    elif kind == "onion":
        # bulge 1.18 r at 0.32 h, then a concave pointed top
        for i in range(n + 1):
            t = i / n
            if t < 0.35:
                rr = r * (1.0 + 0.18 * math.sin(math.pi * t / 0.7))
            else:
                s = (t - 0.35) / 0.65
                rr = r * 1.18 * (math.cos(0.5 * math.pi * s) ** 1.6)
            out.append((max(rr, 0.0), z0 + h * t))
    elif kind == "bell":
        for i in range(n + 1):
            t = i / n
            # concave flare at the bottom, convex shoulder, flat-ish top
            rr = r * (1.0 - 0.25 * math.sin(math.pi * min(t / 0.55, 1.0) * 0.5) ** 2) if t < 0.55 else \
                r * 0.75 * math.cos(0.5 * math.pi * (t - 0.55) / 0.45) ** 0.7
            out.append((max(rr, 0.0), z0 + h * t))
    elif kind == "helmet":
        for i in range(n + 1):
            t = i / n
            if t < 0.45:
                rr = r * (1.0 + 0.12 * math.sin(math.pi * t / 0.45))
            elif t < 0.62:
                rr = r * (1.0 - 1.9 * (t - 0.45))
            else:
                rr = r * 0.68 * (1.0 - (t - 0.62) / 0.38) ** 1.3
            out.append((max(rr, 0.0), z0 + h * t))
    elif kind == "pointed":
        for i in range(n + 1):
            t = i / n
            out.append((r * (1.0 - t) ** 0.65 * math.cos(0.5 * math.pi * t) ** 0.3, z0 + h * t))
    else:
        raise ValueError(kind)
    if neck:
        out.insert(0, (r * neck, z0))
    out[-1] = (0.0, out[-1][1])
    return out


# --- materials ----------------------------------------------------------------------------------

def _rgb(c):
    return M.srgb(c) if isinstance(c, str) else c


class Shade:
    """Material builder: base colour (+ noise / brick), painted masks (windows, bands, patterns),
    emission for the 'lights' layer (floodlight from the albedo, windows, lamps), optional cut-outs."""

    def __init__(self, name, color, rough=0.8, spec=0.3, metal=0.0, noise=0.06, nscale=0.35, color2=None):
        self.m, self.nb = M.new_material(name)
        nb = self.nb
        self.x, self.y, self.z = nb.coords()
        self.nx, self.ny, self.nz = nb.normal()
        c1 = _rgb(color)
        col = c1
        # 'flat' = the albedo without the noise texture: the floodlight emits from it, so lit facades are
        # smooth in the light layer (no texture noise at night, much smaller PNGs); painted masks are kept
        self.flat = c1
        if color2 is not None or noise:
            c2 = _rgb(color2) if color2 is not None else (c1[0] * (1 - 2 * noise), c1[1] * (1 - 2 * noise),
                                                           c1[2] * (1 - 2 * noise), 1.0)
            f = nb.ramp(nb.noise(nscale, detail=3.0), [(0.3, (0, 0, 0, 1)), (0.75, (1, 1, 1, 1))])
            col = nb.mix(f, c1, c2)
            self.flat = ((c1[0] + c2[0]) / 2, (c1[1] + c2[1]) / 2, (c1[2] + c2[2]) / 2, 1.0)
        self.par = dict(col=col, rough=rough, spec=spec, metal=metal)
        self.emit = None
        self.cut = None
        self.vert = nb.lt(nb.absf(self.nz), 0.5)

    # coordinates on a vertical face: u along the face (to the right seen from outside)
    def face_u(self, face):
        nb = self.nb
        if face == "any":
            # every vertical wall, u along the wall (tangent (-ny, nx) of the shading normal)
            return self.vert, nb.madd(self.x, nb.mul(self.ny, -1.0), nb.mul(self.y, self.nx))
        a = math.radians({"front": -90.0, "back": 90.0, "left": 180.0, "right": 0.0}.get(face, face)
                         if not isinstance(face, (int, float)) else face)
        dx, dy = math.cos(a), math.sin(a)
        test = nb.AND(self.vert, nb.gt(nb.madd(self.nx, dx, nb.mul(self.ny, dy)), 0.55))
        u = nb.madd(self.x, -dy, nb.mul(self.y, dx))
        return test, u

    def set_col(self, col):
        """Replaces the base colour by a pattern socket (it is floodlit as it is)."""
        self.par["col"] = col
        self.flat = col

    def paint(self, mask, color, rough=None, spec=None, metal=None):
        nb = self.nb
        self.par["col"] = nb.mix(mask, self.par["col"], _rgb(color))
        self.flat = nb.mix(mask, self.flat, _rgb(color))
        if rough is not None:
            self.par["rough"] = nb.mixf(mask, self.par["rough"], rough)
        if spec is not None:
            self.par["spec"] = nb.mixf(mask, self.par["spec"], spec)
        if metal is not None:
            self.par["metal"] = nb.mixf(mask, self.par["metal"], metal)

    def add_emit(self, term):
        self.emit = term if self.emit is None else self.nb.vadd(self.emit, term)

    def glow(self, mask, color, strength):
        """Constant emission (lamps, lit glass) where mask = 1 (mask None = everywhere)."""
        c = M.emit_col(color, strength)
        self.add_emit(self.nb.color_scale(c, mask) if mask is not None else self.nb.color_scale(c, 1.0))

    def flood(self, tint=FLOOD, strength=1.3, grad=None, mask=None, floor=0.0):
        """Floodlight: emission = albedo * tint * strength * FLOOD_K (* grad(z), * mask). grad = (z0, z1, k1):
        1 below z0, linear to k1 at z1 (lamps at the foot). floor: minimum emission (dark materials).
        The light layer is stored sRGB-encoded (alpha ~ emission^(1/2.2)): light stone at strength 1
        ends up at an alpha of ~0.55-0.6 (lit facade over the darkened base)."""
        nb = self.nb
        vm = nb.node("ShaderNodeVectorMath", operation="MULTIPLY")
        nb.feed(vm.inputs[0], self.flat[:3] if isinstance(self.flat, tuple) else self.flat)
        t = _rgb(tint)
        nb.feed(vm.inputs[1], (t[0], t[1], t[2]))
        e = vm.outputs[0]
        if floor:
            e = nb.vadd(e, (t[0] * floor, t[1] * floor, t[2] * floor))
        strength = strength * FLOOD_K
        k = strength
        if grad is not None:
            z0, z1, k1 = grad
            mr = nb.node("ShaderNodeMapRange", clamp=True)
            nb.feed(mr.inputs["Value"], self.z)
            mr.inputs["From Min"].default_value = z0
            mr.inputs["From Max"].default_value = z1
            mr.inputs["To Min"].default_value = 1.0
            mr.inputs["To Max"].default_value = k1
            k = nb.mul(mr.outputs["Result"], strength)
        if mask is not None:
            k = nb.mul(k, mask)
        self.add_emit(nb.color_scale(e, k))

    def grid(self, face, u, z, pitch, win, lit=0.4, glass="#232b33", frame=None, frame_w=0.12, arch=False,
             color=WARM, strength=1.2, seed=0.0, cx=0.0, cy=0.0, r=None, glass_rough=0.1, pointed=False):
        """Window grid on vertical faces. face: front/back/left/right, an angle in degrees (outward normal
        direction in the xy plane) or 'round' (cylinder about (cx, cy), u = arc length at radius r).
        u = (u0, u1), z = (z0, z1), pitch = (pu, pz), win = (wu, wz); lit = fraction lit at night."""
        nb = self.nb
        if face == "round":
            ang = nb.math("ARCTAN2", nb.sub(self.y, cy), nb.sub(self.x, cx))
            uu = nb.mul(ang, r)
            ftest = self.vert
        else:
            ftest, uu = self.face_u(face)
        u0, u1 = u
        z0, z1 = z
        pu, pz = pitch
        wu, wz = win
        rng = nb.AND(nb.band(uu, u0, u1), nb.band(self.z, z0, z1), ftest)
        fu = nb.math("FLOORED_MODULO", nb.sub(uu, u0), pu)
        fz = nb.math("FLOORED_MODULO", nb.sub(self.z, z0), pz)
        du = nb.absf(nb.sub(fu, pu / 2))
        dz = nb.sub(fz, pz / 2)
        adz = nb.absf(dz)
        w = nb.AND(nb.lt(du, wu / 2), nb.lt(adz, wz / 2))
        if pointed:
            # equilateral gothic arch: arcs of radius wu about the opposite springing points
            cz = nb.sub(dz, wz / 2 - 0.866 * wu)
            dd = nb.add(du, wu / 2)
            w = nb.mul(w, nb.OR(nb.lt(cz, 0.0), nb.lt(nb.add(nb.mul(dd, dd), nb.mul(cz, cz)), wu * wu)))
        elif arch:
            cz = nb.sub(dz, wz / 2 - wu / 2)
            w = nb.mul(w, nb.OR(nb.lt(cz, 0.0), nb.lt(nb.add(nb.mul(du, du), nb.mul(cz, cz)), (wu / 2) ** 2)))
        w = nb.mul(w, rng)
        if frame:
            fr = nb.AND(nb.lt(du, wu / 2 + frame_w), nb.lt(adz, wz / 2 + frame_w), rng)
            if arch or pointed:
                cz2 = nb.sub(dz, wz / 2 - wu / 2)
                fr = nb.mul(fr, nb.OR(nb.lt(cz2, 0.0), nb.lt(nb.add(nb.mul(du, du), nb.mul(cz2, cz2)),
                                                             (wu / 2 + frame_w) ** 2)))
            self.paint(fr, frame, 0.6, 0.3)
        self.paint(w, glass, glass_rough, 0.8, 0.1)
        if lit > 0:
            iu = nb.math("FLOOR", nb.math("DIVIDE", nb.sub(uu, u0), pu))
            iz = nb.math("FLOOR", nb.math("DIVIDE", nb.sub(self.z, z0), pz))
            cmb = nb.node("ShaderNodeCombineXYZ")
            nb.feed(cmb.inputs[0], iu)
            nb.feed(cmb.inputs[1], iz)
            nb.feed(cmb.inputs[2], nb.add(nb.mul(self.nx, 3.1), nb.add(nb.mul(self.ny, 7.3), seed * 1.7 + 0.3)))
            wn = nb.node("ShaderNodeTexWhiteNoise", noise_dimensions="3D")
            nb.links.new(cmb.outputs[0], wn.inputs["Vector"])
            on = nb.mul(w, nb.lt(wn.outputs["Value"], lit))
            bright = nb.madd(wn.outputs["Value"], 0.6 / max(lit, 0.05), 0.55)
            self.add_emit(nb.color_scale(nb.color_scale(M.emit_col(color, strength), bright), on))
        return w

    def bands(self, z_list, color, rough=None):
        """Horizontal bands [(z0, z1)] (cornices, string courses) painted in another colour."""
        nb = self.nb
        ms = [nb.band(self.z, a, b) for (a, b) in z_list]
        self.paint(nb.OR(*ms), color, rough)

    def finish(self, coat=0.0):
        nb = self.nb
        out = M.principled(nb, self.par["col"], rough=self.par["rough"], spec=self.par["spec"],
                           metal=self.par["metal"], coat=coat)
        grp = nb.node("ShaderNodeGroup")
        grp.node_tree = M.pass_group()
        em = nb.node("ShaderNodeEmission")
        if self.emit is not None:
            nb.feed(em.inputs["Color"], nb.color_scale(self.emit, grp.outputs["lights"]))
        else:
            em.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
        em.inputs["Strength"].default_value = 1.0
        mix = nb.node("ShaderNodeMixShader")
        nb.feed(mix.inputs[0], nb.NOT(grp.outputs["base"]))
        nb.links.new(out, mix.inputs[1])
        nb.links.new(em.outputs[0], mix.inputs[2])
        res = mix.outputs[0]
        if self.cut is not None:
            # cut-outs (lattice openings) stay transparent in every pass
            tr = nb.node("ShaderNodeBsdfTransparent")
            m2 = nb.node("ShaderNodeMixShader")
            nb.feed(m2.inputs[0], self.cut)
            nb.links.new(res, m2.inputs[1])
            nb.links.new(tr.outputs[0], m2.inputs[2])
            res = m2.outputs[0]
        o = nb.node("ShaderNodeOutputMaterial")
        nb.links.new(res, o.inputs["Surface"])
        return self.m


def plain(name, color, rough=0.6, metal=0.0, spec=0.4, flood=None, glow=None, noise=0.04):
    """Simple material; flood = (tint, strength) floodlight, glow = (color, strength) lamp."""
    s = Shade(name, color, rough=rough, metal=metal, spec=spec, noise=noise)
    if flood:
        s.flood(flood[0], flood[1])
    if glow:
        s.glow(None, glow[0], glow[1])
    return s.finish()


def lamp(name, color, strength=1.0, base="#f4ead2"):
    """Light source (aviation light, beacon, bulb): pale by day, glowing in the lights layer."""
    return plain(name, base, rough=0.3, glow=(color, strength), noise=0.0)


# --- Paris: Eiffel Tower ------------------------------------------------------------------------

def _gold_lattice(s, strength=0.42):
    """Golden night illumination of the iron lattice: lamps inside the structure light the inner faces of
    the members, so the brightness varies with the face orientation (keeps the lattice readable)."""
    nb = s.nb
    k = nb.madd(nb.absf(s.ny), 0.45, nb.madd(nb.absf(s.nz), 0.25, 0.4))
    s.add_emit(nb.color_scale(M.emit_col(GOLD, strength), k))


def _eif_out(z):
    """Half width of the outer leg edges (m): 62.5 at the feet, ~35 at the 1st, ~21 at the 2nd and ~9 at
    the 3rd floor (the famous exponential-like curve)."""
    return 55.5 * math.exp(-0.01188 * z) + 7.0


def _eif_in(z):
    """Half width of the inner leg edges (the void between the legs closes above the 2nd floor)."""
    pts = [(0.0, 36.5), (57.6, 20.0), (115.7, 8.5), (165.0, 0.0)]
    if z >= pts[-1][0]:
        return 0.0
    for (za, a), (zb, b) in zip(pts[:-1], pts[1:]):
        if z <= zb:
            return a + (b - a) * (z - za) / (zb - za)
    return 0.0


def eiffel_tower(rig, p):
    """324 m wrought-iron lattice tower (+ antennas: 330 m). Legs 125 m apart at the feet, the four big
    arches under the 1st floor (57 m), 2nd floor at 116 m, closed 3rd floor gallery at 276 m, top lantern
    and antenna mast. 'Brun Tour Eiffel' by day, golden illumination at night."""
    yc = 62.5
    iron = Shade("eif_iron", "#6e5843", rough=0.55, spec=0.35, metal=0.3, noise=0.05, nscale=0.08)
    _gold_lattice(iron)
    iron_m = iron.finish()
    bm = bmesh.new()

    def wch(z):            # chord width
        return 2.4 - 1.5 * min(z, 276.0) / 276.0

    def wdg(z):            # bracing width
        return 1.0 - 0.6 * min(z, 276.0) / 276.0

    # panel levels: legs up to the merge, then the single shaft to the 3rd floor
    levels = [0.0, 7.0, 14.5, 22.5, 31.0, 40.0, 49.0, 57.6, 65.0, 72.5, 80.0, 87.5, 95.0, 102.5, 109.0, 115.7,
              123.0, 131.0, 139.5, 148.0, 156.5, 165.0]
    zz = 165.0
    while zz < 276.0 - 1e-6:
        zz = min(276.0, zz + 9.0 + (zz - 165.0) * 0.02)
        levels.append(zz)

    def P(sx, sy, a, b, z):
        return (sx * a, yc + sy * b, z)

    for sx in (-1, 1):
        for sy in (-1, 1):
            # each leg = square lattice column between the inner and outer edge lines
            for k in range(len(levels) - 1):
                z0, z1 = levels[k], levels[k + 1]
                o0, o1 = _eif_out(z0), _eif_out(z1)
                i0, i1 = _eif_in(z0), _eif_in(z1)
                if z0 >= 165.0 - 1e-6:
                    # single shaft: corner chord + face middle chords (from the merged inner chords)
                    beam(bm, P(sx, sy, o0, o0, z0), P(sx, sy, o1, o1, z1), wch(z0))
                    for (a0, b0, a1, b1) in ((o0, 0.0, o1, 0.0), (0.0, o0, 0.0, o1)):
                        beam(bm, P(sx, sy, a0, b0, z0), P(sx, sy, a1, b1, z1), wch(z0) * 0.6)
                    # X bracing on both faces of the quadrant + ring struts
                    for face in ("x", "y"):
                        if face == "x":
                            c0a, c0b, c1a, c1b = P(sx, sy, o0, 0.0, z0), P(sx, sy, o0, o0, z0), P(sx, sy, o1, 0.0, z1), P(sx, sy, o1, o1, z1)
                        else:
                            c0a, c0b, c1a, c1b = P(sx, sy, 0.0, o0, z0), P(sx, sy, o0, o0, z0), P(sx, sy, 0.0, o1, z1), P(sx, sy, o1, o1, z1)
                        beam(bm, c0a, c1b, wdg(z0))
                        beam(bm, c0b, c1a, wdg(z0))
                        beam(bm, c0a, c0b, wdg(z0) * 0.8)
                    continue
                corners0 = [(o0, o0), (i0, o0), (i0, i0), (o0, i0)]
                corners1 = [(o1, o1), (i1, o1), (i1, i1), (o1, i1)]
                for c in range(4):
                    a0, b0 = corners0[c]
                    a1, b1 = corners1[c]
                    beam(bm, P(sx, sy, a0, b0, z0), P(sx, sy, a1, b1, z1), wch(z0) * (1.0 if c == 0 else 0.8))
                for c in range(4):
                    d = (c + 1) % 4
                    pa0 = P(sx, sy, corners0[c][0], corners0[c][1], z0)
                    pb0 = P(sx, sy, corners0[d][0], corners0[d][1], z0)
                    pa1 = P(sx, sy, corners1[c][0], corners1[c][1], z1)
                    pb1 = P(sx, sy, corners1[d][0], corners1[d][1], z1)
                    beam(bm, pa0, pb0, wdg(z0) * 0.8)
                    beam(bm, pa0, pb1, wdg(z0))
                    beam(bm, pb0, pa1, wdg(z0))
    # the four decorative arches under the 1st floor (lattice bands in the plane of the outer faces)
    for side in range(4):
        for (rad, ww) in ((34.0, 1.3), (31.4, 1.0)):
            pts = []
            n = 28
            for i in range(n + 1):
                th = math.pi * i / n
                x = rad * math.cos(th)
                z = (rad / 34.0) * 52.5 * math.sin(th)
                if z < 9.0:
                    continue
                d = _eif_out(z) - 1.2
                pts.append((x, -d, z))
            for a, b in zip(pts[:-1], pts[1:]):
                pa = _rot_side(a, side, yc)
                pb = _rot_side(b, side, yc)
                beam(bm, pa, pb, ww)
            if rad < 34.0:
                for a in pts[::2]:
                    x, y, z = a
                    th = math.atan2(z / 52.5, x / 34.0)
                    xo, zo = 34.0 * math.cos(th), 52.5 * math.sin(th)
                    beam(bm, _rot_side(a, side, yc), _rot_side((xo, -(_eif_out(zo) - 1.2), zo), side, yc), 0.5)
    make(rig, "eif_lattice", bm, iron_m)
    # 1st and 2nd floor: girder bands with arcade friezes (openings cut out), pavilions on the decks
    frieze = Shade("eif_frieze", "#6e5843", rough=0.55, spec=0.35, metal=0.3, noise=0.05, nscale=0.08)
    nb = frieze.nb
    uu = nb.add(nb.mul(frieze.x, nb.absf(frieze.ny)), nb.mul(frieze.y, nb.absf(frieze.nx)))
    fu = nb.math("FLOORED_MODULO", uu, 4.2)
    du = nb.absf(nb.sub(fu, 2.1))
    hole1 = nb.AND(nb.lt(du, 0.95), nb.band(frieze.z, 53.0, 56.0),
                   nb.OR(nb.lt(frieze.z, 55.05), nb.lt(nb.add(nb.mul(du, du), nb.mul(nb.sub(frieze.z, 55.05), nb.sub(frieze.z, 55.05))), 0.95 ** 2)))
    fu2 = nb.math("FLOORED_MODULO", uu, 3.2)
    du2 = nb.absf(nb.sub(fu2, 1.6))
    hole2 = nb.AND(nb.lt(du2, 0.8), nb.band(frieze.z, 113.2, 115.4))
    frieze.cut = nb.mul(nb.OR(hole1, hole2), frieze.vert)
    frieze.glow(None, GOLD, 0.42)
    fr_m = frieze.finish()
    bm = bmesh.new()
    for (zb, zt, hw) in ((52.5, 59.5, _eif_out(57.6) + 1.2), (112.6, 117.6, _eif_out(115.7) + 1.0)):
        outer = rect(0.0, yc, 2 * hw, 2 * hw)
        for (pa, pb) in [(outer[i], outer[(i + 1) % 4]) for i in range(4)]:
            v = [bm.verts.new((pa[0], pa[1], zb)), bm.verts.new((pb[0], pb[1], zb)), bm.verts.new((pb[0], pb[1], zt)),
                 bm.verts.new((pa[0], pa[1], zt))]
            bm.faces.new(v)
        # deck slab
        box(bm, -hw + 0.5, hw - 0.5, yc - hw + 0.5, yc + hw - 0.5, zt - 0.6, zt)
    make(rig, "eif_friezes", bm, fr_m)
    # deck pavilions (glass and dark roofs), 3rd floor gallery, top lantern, antenna
    pav = Shade("eif_pav", "#8a7560", rough=0.5, spec=0.4, metal=0.2, noise=0.04)
    pav.grid("front", (-30, 30), (59.6, 64.0), (3.0, 4.4), (2.2, 3.4), lit=0.8, glass="#3b4752", color="#ffe2a8", strength=1.2)
    pav.grid("left", (-120, 0), (59.6, 64.0), (3.0, 4.4), (2.2, 3.4), lit=0.8, glass="#3b4752", color="#ffe2a8", strength=1.2, seed=1)
    pav.grid("front", (-15, 15), (117.7, 121.0), (2.6, 3.3), (2.0, 2.6), lit=0.8, glass="#3b4752", color="#ffe2a8", strength=1.2, seed=2)
    pav.grid("left", (-90, 0), (117.7, 121.0), (2.6, 3.3), (2.0, 2.6), lit=0.8, glass="#3b4752", color="#ffe2a8", strength=1.2, seed=3)
    pav.grid("front", (-8, 8), (275.0, 281.6), (1.8, 3.3), (1.4, 2.6), lit=0.9, glass="#38434d", color="#ffe6b8", strength=1.3, seed=4)
    pav.grid("left", (-80, -50), (275.0, 281.6), (1.8, 3.3), (1.4, 2.6), lit=0.9, glass="#38434d", color="#ffe6b8", strength=1.3, seed=5)
    pav.glow(None, GOLD, 0.2)
    pav_m = pav.finish()
    bm = bmesh.new()
    h1 = _eif_out(57.6) - 6.0
    for (cx, cy, w, d) in ((-h1 + 6.0, yc - h1 + 4.0, 18.0, 8.0), (h1 - 6.0, yc - h1 + 4.0, 18.0, 8.0),
                           (-h1 + 4.0, yc + 4.0, 8.0, 26.0)):
        box(bm, cx - w / 2, cx + w / 2, cy - d / 2, cy + d / 2, 59.5, 64.5)
    h2 = _eif_out(115.7) - 4.0
    box(bm, -h2, h2, yc - h2, yc + h2, 117.6, 121.5)
    # 3rd floor: closed gallery, open deck above, lantern, cap
    box(bm, -8.3, 8.3, yc - 8.3, yc + 8.3, 274.5, 282.0)
    make(rig, "eif_pavilions", bm, pav_m)
    bm = bmesh.new()
    box(bm, -9.6, 9.6, yc - 9.6, yc + 9.6, 282.0, 282.8)
    for i in range(4):
        a = math.pi / 2 * i
        for t in range(-9, 10, 3):
            x, y = 9.4, t
            px, py = x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)
            beam(bm, (px, yc + py, 282.8), (px, yc + py, 284.3), 0.3)
    box(bm, -4.6, 4.6, yc - 4.6, yc + 4.6, 282.8, 291.5)
    lathe(bm, [(4.6, 291.5), (5.2, 292.2), (3.4, 293.0), (2.4, 296.0), (1.6, 300.0), (0.0, 300.0)], 8, 0.0, yc, math.pi / 8)
    make(rig, "eif_top", bm, iron_m)
    # antenna mast (light grey) with a few panels
    ant = plain("eif_antenna", "#b9b7b0", rough=0.5, metal=0.4, glow=(GOLD, 0.2))
    bm = bmesh.new()
    lathe(bm, [(1.1, 300.0), (1.0, 312.0), (0.75, 312.0), (0.7, 324.0), (0.45, 324.0), (0.35, 330.0), (0.0, 330.0)], 10, 0.0, yc)
    for z in (304.0, 309.0, 316.0):
        for a in range(3):
            ang = 2 * math.pi * a / 3 + 0.3
            box(bm, math.cos(ang) * 1.4 - 0.45, math.cos(ang) * 1.4 + 0.45, yc + math.sin(ang) * 1.4 - 0.45,
                yc + math.sin(ang) * 1.4 + 0.45, z, z + 2.6)
    make(rig, "eif_antenna", bm, ant)
    # beacon (rotating searchlight) + red aviation lights, stone piers of the four feet
    bm = MU.bm_sphere(1.3, center=(0.0, yc, 297.5), subdiv=2)
    make(rig, "eif_beacon", bm, lamp("eif_beacon", "#fff6dc", 1.0))
    bm = MU.bm_sphere(0.45, center=(0.0, yc, 330.2), subdiv=1)
    make(rig, "eif_red", bm, lamp("eif_red", RED_LIGHT, 1.0, base="#c0302a"))
    stone = plain("eif_pier", "#b9ad98", rough=0.85, flood=(FLOOD, 0.8))
    bm = bmesh.new()
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = (sx * 49.5, yc + sy * 49.5)
            box(bm, c[0] - 14.0, c[0] + 14.0, c[1] - 14.0, c[1] + 14.0, 0.0, 1.8)
    make(rig, "eif_piers", bm, stone)
    return dict(object=obj_size(125.0, 330.0, 125.0))


def _rot_side(pt, side, yc):
    """Rotates a point given for the front face (y relative = -d) to one of the four faces about the tower
    axis (0, yc)."""
    x, y, z = pt
    a = math.pi / 2 * side
    return (x * math.cos(a) - y * math.sin(a), yc + x * math.sin(a) + y * math.cos(a), z)


# --- Berlin: Fernsehturm ------------------------------------------------------------------------

def fernsehturm_berlin(rig, p):
    """TV tower at Alexanderplatz: 368 m. Concrete shaft 32 m wide at the foot (flared) tapering to ~9 m,
    steel-clad sphere (32 m, centre 213.8 m) with the window band of the observation deck (204 m) and the
    restaurant (207 m), red and white antenna (250-368 m), folded-roof pavilion around the foot."""
    yc = 39.0
    conc = Shade("ft_concrete", "#c9c7c1", rough=0.8, spec=0.3, noise=0.05, nscale=0.2)
    nb = conc.nb
    seams = nb.lt(nb.math("FLOORED_MODULO", conc.z, 3.2), 0.12)
    conc.paint(nb.mul(seams, 0.35), "#9d9b95")
    conc.flood(FLOOD_WHITE, 0.3, grad=(0.0, 200.0, 0.3))
    conc_m = conc.finish()
    bm = bmesh.new()
    prof = [(16.0, 0.0), (12.4, 5.0), (10.0, 12.0), (8.5, 22.0), (7.6, 38.0), (6.9, 70.0), (6.2, 115.0),
            (5.6, 160.0), (5.15, 199.0), (4.8, 230.0), (4.5, 241.0), (3.9, 250.0), (0.0, 250.0)]
    lathe(bm, prof, 32, 0.0, yc)
    make(rig, "ft_shaft", bm, conc_m, smooth=True, sharp=50.0)
    # sphere: stainless steel triangles, window band (two storeys) below the equator
    zc, R = 213.8, 16.0
    sph = Shade("ft_sphere", "#c9d0d7", rough=0.5, spec=0.55, metal=0.25, noise=0.03, nscale=0.4)
    nb = sph.nb
    ang = nb.math("ARCTAN2", nb.sub(sph.y, yc), sph.x)
    lon = nb.math("FLOORED_MODULO", nb.mul(ang, 24.0 / math.pi), 1.0)
    dz = nb.sub(sph.z, zc)
    lat = nb.math("FLOORED_MODULO", nb.mul(dz, 0.42), 1.0)
    tri = nb.lt(nb.absf(nb.sub(lon, lat)), 0.035)
    seam = nb.OR(nb.lt(lon, 0.04), nb.lt(lat, 0.04), tri)
    sph.paint(nb.mul(seam, 0.6), "#7d848c", 0.45)
    band = nb.band(sph.z, 201.2, 209.6)
    mull = nb.lt(nb.math("FLOORED_MODULO", nb.mul(ang, 60.0 / math.pi), 1.0), 0.16)
    mid = nb.band(sph.z, 205.0, 205.7)
    glass = nb.AND(band, nb.NOT(nb.OR(mull, mid)))
    sph.paint(band, "#2f3438", 0.4, 0.5, 0.6)
    sph.paint(glass, "#222c35", 0.06, 0.9, 0.2)
    sph.glow(glass, "#ffe0b0", 0.7)
    sph.flood("#dfe8ff", 0.14, mask=nb.NOT(band))
    sph_m = sph.finish()
    bm = MU.bm_sphere(R, center=(0.0, yc, zc), uv=(48, 28))
    make(rig, "ft_sphere", bm, sph_m, smooth=True)
    # antenna: red/white sections with platforms
    ant = Shade("ft_antenna", "#ece9e2", rough=0.45, spec=0.4, noise=0.0)
    nb = ant.nb
    stripe = nb.lt(nb.math("FLOORED_MODULO", nb.sub(ant.z, 250.0), 17.0), 8.5)
    ant.paint(nb.mul(stripe, nb.gt(ant.z, 250.0)), "#c4372e")
    ant.flood(FLOOD_WHITE, 0.18)
    ant_m = ant.finish()
    bm = bmesh.new()
    lathe(bm, [(3.9, 250.0), (2.3, 251.5), (2.1, 282.0), (1.6, 284.0), (1.55, 318.0), (1.2, 320.0), (1.1, 350.0),
               (0.8, 352.0), (0.7, 366.5), (0.0, 368.0)], 16, 0.0, yc)
    for z in (283.0, 319.0, 351.0):
        lathe(bm, [(0.0, z - 0.4), (2.6, z - 0.4), (2.6, z + 0.4), (0.0, z + 0.4)], 16, 0.0, yc)
    make(rig, "ft_antenna", bm, ant_m, smooth=True, sharp=40.0)
    red = lamp("ft_red", RED_LIGHT, 1.0, base="#b8322a")
    bm = bmesh.new()
    for (z, r) in ((250.6, 4.2), (284.5, 2.7), (320.4, 2.0), (352.4, 1.3)):
        for a in range(4):
            ang = math.pi / 2 * a + math.pi / 4
            MU.bm_sphere(0.55, center=(math.cos(ang) * r, yc + math.sin(ang) * r, z), subdiv=1, bm=bm)
    MU.bm_sphere(0.6, center=(0.0, yc, 368.2), subdiv=1, bm=bm)
    for a in range(6):
        ang = math.pi / 3 * a
        MU.bm_sphere(0.55, center=(math.cos(ang) * 16.2, yc + math.sin(ang) * 16.2, zc), subdiv=1, bm=bm)
    make(rig, "ft_red", bm, red)
    # pavilion around the foot: six wings with folded (zigzag) roofs, glazed walls
    pav = Shade("ft_pavilion", "#e3e0d8", rough=0.7, spec=0.3, noise=0.03)
    pav.grid("any", (-400, 400), (0.6, 6.6), (2.4, 6.6), (2.0, 5.6), lit=0.75, glass="#2d3740",
             color="#ffe7c4", strength=1.1)
    pav.flood(FLOOD_WHITE, 0.25)
    pav_m = pav.finish()
    bm = bmesh.new()
    for k in range(6):
        a = math.radians(90.0 + 60.0 * k)
        # wing: 26 m long, 15 m wide, along direction a, starting at the shaft
        L, W, Hh = 27.0, 14.0, 7.0
        d = Vector((math.cos(a), math.sin(a), 0.0))
        nrm = Vector((-d.y, d.x, 0.0))
        c0 = Vector((0.0, yc, 0.0)) + d * 12.0
        pts = [c0 - nrm * W / 2, c0 + d * L - nrm * W / 2, c0 + d * L + nrm * W / 2, c0 + nrm * W / 2]
        prism(bm, [(q.x, q.y) for q in pts], 0.0, Hh)
        # folded roof: sawtooth ridges across the wing
        n = 5
        for j in range(n):
            t0, t1 = j / n, (j + 1) / n
            tm = (t0 + t1) / 2
            q = [c0 + d * (L * t0) - nrm * W / 2, c0 + d * (L * t1) - nrm * W / 2,
                 c0 + d * (L * t1) + nrm * W / 2, c0 + d * (L * t0) + nrm * W / 2]
            ridge0 = c0 + d * (L * tm) - nrm * W / 2
            ridge1 = c0 + d * (L * tm) + nrm * W / 2
            v = [bm.verts.new((qq.x, qq.y, Hh)) for qq in q]
            r0 = bm.verts.new((ridge0.x, ridge0.y, Hh + 3.2))
            r1 = bm.verts.new((ridge1.x, ridge1.y, Hh + 3.2))
            bm.faces.new((v[0], v[1], r0))
            bm.faces.new((v[3], r1, v[2]))
            bm.faces.new((v[0], r0, r1, v[3]))
            bm.faces.new((v[1], v[2], r1, r0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    make(rig, "ft_pavilion", bm, pav_m)
    return dict(object=obj_size(78.0, 368.0, 70.0))


# --- Vienna: Riesenrad --------------------------------------------------------------------------

def riesenrad(rig, p):
    """Giant Ferris wheel in the Prater (1897): 64.75 m, 60.96 m between the gondola axles, axle at 33.5 m,
    15 red gondolas, two lattice rims, 120 spokes, two pylons of lattice girders on each side, station
    building. At night: lit gondolas and a string of bulbs along the rims."""
    AX, RS = 33.5, 30.48
    yc = 12.0
    steel = Shade("rr_steel", "#5d3a2e", rough=0.6, spec=0.3, metal=0.35, noise=0.05, nscale=0.1)
    steel.flood(FLOOD, 0.75, floor=0.08)
    steel_m = steel.finish()
    spoke_m = plain("rr_spoke", "#5d3a2e", rough=0.6, metal=0.35, flood=(FLOOD, 0.35))
    bm = bmesh.new()
    bms = bmesh.new()
    n = 120
    for side in (-1, 1):
        y = yc + side * 1.6
        # rim truss: outer + inner ring, zigzag lacing
        for i in range(n):
            a0 = 2 * math.pi * i / n
            a1 = 2 * math.pi * (i + 1) / n
            for r in (31.2, 28.6):
                beam(bm, (r * math.cos(a0), y, AX + r * math.sin(a0)), (r * math.cos(a1), y, AX + r * math.sin(a1)), 0.45)
            ra, rb = (31.2, 28.6) if i % 2 == 0 else (28.6, 31.2)
            beam(bm, (ra * math.cos(a0), y, AX + ra * math.sin(a0)), (rb * math.cos(a1), y, AX + rb * math.sin(a1)), 0.22)
        # spokes: from the inner rim to the hub ends (crossing), every second one to the far end
        for i in range(0, n, 2):
            a = 2 * math.pi * i / n + (math.pi / n if side > 0 else 0.0)
            hub_y = yc + side * (5.4 if i % 4 == 0 else -5.4)
            beam(bms, (28.6 * math.cos(a), y, AX + 28.6 * math.sin(a)), (0.9 * math.cos(a), hub_y, AX + 0.9 * math.sin(a)), 0.14)
    # cross ties between the two rims
    for i in range(0, n, 4):
        a = 2 * math.pi * i / n
        for r in (31.2, 28.6):
            beam(bm, (r * math.cos(a), yc - 1.6, AX + r * math.sin(a)), (r * math.cos(a), yc + 1.6, AX + r * math.sin(a)), 0.25)
    # hub + axle
    MU.bm_cyl(1.3, 1.3, 11.4, center=(0.0, yc, AX), axis="Y", segs=16, bm=bm)
    # pylons: on each side an A-frame of two lattice legs + a raking back leg
    for side in (-1, 1):
        top = Vector((0.0, yc + side * 5.6, AX + 0.6))
        feet = [Vector((-17.0, yc + side * 10.5, 0.0)), Vector((17.0, yc + side * 10.5, 0.0))]
        for f in feet:
            _lattice_leg(bm, f, top, 1.6)
        beam(bm, feet[0] + (top - feet[0]) * 0.32, feet[1] + (top - feet[1]) * 0.32, 0.5)
        beam(bm, feet[0] + (top - feet[0]) * 0.62, feet[1] + (top - feet[1]) * 0.62, 0.45)
    make(rig, "rr_wheel", bm, steel_m)
    make(rig, "rr_spokes", bms, spoke_m)
    # gondolas: red cabins with cream window frames, lit at night
    gon = Shade("rr_gondola", "#b3262a", rough=0.45, spec=0.45, noise=0.02)
    win = Shade("rr_window", "#33404b", rough=0.1, spec=0.8, noise=0.0)
    win.glow(None, "#ffe2a6", 1.0)
    win_m = win.finish()
    gon.flood(FLOOD, 0.45)
    gon_m = gon.finish()
    roof_m = plain("rr_roof", "#e8e2d2", rough=0.6, flood=(FLOOD, 0.35))
    bm_b = bmesh.new()
    bm_w = bmesh.new()
    bm_r = bmesh.new()
    for i in range(15):
        a = 2 * math.pi * i / 15 + math.radians(6.0)
        sx, sz = RS * math.cos(a), AX + RS * math.sin(a)
        # cabin hangs below its suspension axle (5.4 m x 2.5 m x 2.9 m)
        x0, x1 = sx - 2.7, sx + 2.7
        y0, y1 = yc - 1.25, yc + 1.25
        z1 = sz - 0.5
        z0 = z1 - 2.9
        box(bm_b, x0, x1, y0, y1, z0, z0 + 0.95)
        for k in range(5):
            xa = x0 + 0.15 + k * 1.05
            box(bm_w, xa, xa + 0.85, y0 - 0.05, y1 + 0.05, z0 + 1.0, z1 - 0.45)
        for k in range(6):
            xa = x0 + k * 1.05
            box(bm_b, xa - 0.08 if k else xa, xa + 0.12, y0, y1, z0 + 0.95, z1 - 0.4)
        box(bm_r, x0 - 0.2, x1 + 0.2, y0 - 0.15, y1 + 0.15, z1 - 0.4, z1)
        beam(bm_b, (sx, y0 - 0.3, sz), (sx, y1 + 0.3, sz), 0.25)
    make(rig, "rr_gondola", bm_b, gon_m)
    make(rig, "rr_windows", bm_w, win_m)
    make(rig, "rr_roofs", bm_r, roof_m)
    # bulbs along both rims
    bulb = lamp("rr_bulb", "#ffe9b8", 1.0)
    bm = bmesh.new()
    for side in (-1, 1):
        for i in range(90):
            a = 2 * math.pi * i / 90
            MU.bm_sphere(0.32, center=(31.5 * math.cos(a), yc + side * 1.6, AX + 31.5 * math.sin(a)), subdiv=1, bm=bm)
    make(rig, "rr_bulbs", bm, bulb)
    # station building under the wheel
    st = Shade("rr_station", "#e6dcc4", rough=0.8, spec=0.3, noise=0.05)
    st.grid("front", (-14, 14), (0.8, 3.8), (2.8, 4.0), (1.8, 2.6), lit=0.8, frame="#7b2a22", frame_w=0.15, arch=True)
    st.grid("left", (-30, 30), (0.8, 3.8), (2.8, 4.0), (1.8, 2.6), lit=0.8, frame="#7b2a22", frame_w=0.15, arch=True, seed=1)
    st.flood(FLOOD, 0.5)
    st_m = st.finish()
    bm = bmesh.new()
    box(bm, -15.0, 15.0, yc - 6.0, yc + 6.0, 0.0, 4.6)
    make(rig, "rr_station", bm, st_m)
    bm = bmesh.new()
    gable_roof(bm, -15.6, 15.6, yc - 6.6, yc + 6.6, 4.6, 7.4, axis="x", hip=3.0)
    make(rig, "rr_station_roof", bm, plain("rr_station_roof", "#6d2a24", rough=0.7, flood=(FLOOD, 0.35)))
    return dict(object=obj_size(63.0, 64.75, 24.0))


def _lattice_leg(bm, foot, top, w):
    """Lattice girder from foot to top: two chords (in the wheel plane) with zigzag lacing."""
    d = top - foot
    L = d.length
    side = Vector((1.0, 0.0, 0.0)) if abs(d.normalized().x) < 0.7 else Vector((0.0, 0.0, 1.0))
    nrm = d.cross(side).normalized().cross(d.normalized()).normalized() * (w / 2)
    a0, a1 = foot - nrm * 2.2, top - nrm * 0.4
    b0, b1 = foot + nrm * 2.2, top + nrm * 0.4
    beam(bm, a0, a1, 0.55)
    beam(bm, b0, b1, 0.55)
    n = max(4, int(L / 2.6))
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        pa = a0.lerp(a1, t0) if i % 2 == 0 else b0.lerp(b1, t0)
        pb = b0.lerp(b1, t1) if i % 2 == 0 else a0.lerp(a1, t1)
        beam(bm, pa, pb, 0.22)


# --- shared materials and parts -------------------------------------------------------------------

def copper(name, flood=0.8, color="#62a08a", color2="#4c8572"):
    """Verdigris copper roofs and domes (returns the Shade; call finish())."""
    s = Shade(name, color, rough=0.55, spec=0.35, metal=0.15, color2=color2, nscale=0.5)
    s.flood("#f1f5ee", flood)
    return s


def gold(name, flood=0.8):
    s = Shade(name, "#d4a838", rough=0.28, spec=0.6, metal=1.0, noise=0.03)
    s.glow(None, "#ffd27a", flood)
    return s.finish()


def block_patches(s, dark, p_lo=0.05, p_hi=0.75, region=0.55, rscale=0.045, bw=1.3, bh=0.65, zfade=None):
    """Dark (old, weathered) stone blocks in irregular regions - Dresden's Frauenkirche."""
    nb = s.nb
    u = nb.madd(s.x, nb.absf(s.ny), nb.mul(s.y, nb.absf(s.nx)))
    cmb = nb.node("ShaderNodeCombineXYZ")
    nb.feed(cmb.inputs[0], nb.math("FLOOR", nb.math("DIVIDE", u, bw)))
    nb.feed(cmb.inputs[1], nb.math("FLOOR", nb.math("DIVIDE", s.z, bh)))
    nb.feed(cmb.inputs[2], nb.mul(s.nz, 5.0))
    wn = nb.node("ShaderNodeTexWhiteNoise", noise_dimensions="3D")
    nb.links.new(cmb.outputs[0], wn.inputs["Vector"])
    reg = nb.gt(nb.noise(rscale, detail=2.0), region)
    if zfade is not None:
        reg = nb.mul(reg, nb.lt(s.z, zfade))
    prob = nb.mixf(reg, p_lo, p_hi)
    s.paint(nb.lt(wn.outputs["Value"], prob), dark)


def merge(bm, other):
    """Copies the faces of another bmesh into bm (and frees it)."""
    m = {v: bm.verts.new(v.co) for v in other.verts}
    for f in other.faces:
        nf = bm.faces.new([m[v] for v in f.verts])
        nf.material_index = f.material_index
    other.free()
    return bm


def gable_xz(bm, pts, y0, depth):
    """Vertical gable/wall piece: polygon [(x, z)] extruded along +y from y0."""
    return merge(bm, MU.prism(pts, depth, plane="XZ", offset=y0))


def face_gable(bm, c, a, half_w, z0, z1, depth=0.4):
    """Small gable (wimperg) standing on a face with outward direction angle a, centred at c (x, y)."""
    t = Vector((-math.sin(a), math.cos(a), 0.0))
    nv = Vector((math.cos(a), math.sin(a), 0.0))
    cc = Vector((c[0], c[1], 0.0))
    p3 = [cc - t * half_w + Vector((0, 0, z0)), cc + t * half_w + Vector((0, 0, z0)), cc + Vector((0, 0, z1))]
    v = [bm.verts.new(q) for q in p3] + [bm.verts.new(q + nv * depth) for q in p3]
    for f in ((v[0], v[1], v[2]), (v[3], v[5], v[4]), (v[0], v[3], v[4], v[1]), (v[1], v[4], v[5], v[2]),
              (v[2], v[5], v[3], v[0])):
        bm.faces.new(f)
    return bm


def _wave(x, crests, sags):
    """Roof line of concave sweeps between sharp crests [(x, z)] (sag per span)."""
    for i in range(len(crests) - 1):
        (xa, za), (xb, zb) = crests[i], crests[i + 1]
        if x <= xb or i == len(crests) - 2:
            t = min(max((x - xa) / (xb - xa), 0.0), 1.0)
            return za + (zb - za) * t - sags[i] * math.sin(math.pi * t)
    return crests[-1][1]


def _cell_noise(nb, u, v, pu, pv, salt):
    """White noise (Value, Color) per cell of a (u, v) grid."""
    cmb = nb.node("ShaderNodeCombineXYZ")
    nb.feed(cmb.inputs[0], nb.math("FLOOR", nb.math("DIVIDE", u, pu)))
    nb.feed(cmb.inputs[1], nb.math("FLOOR", nb.math("DIVIDE", v, pv)))
    nb.feed(cmb.inputs[2], salt)
    wn = nb.node("ShaderNodeTexWhiteNoise", noise_dimensions="3D")
    nb.links.new(cmb.outputs[0], wn.inputs["Vector"])
    sep = nb.node("ShaderNodeSeparateColor")
    nb.links.new(wn.outputs["Color"], sep.inputs[0])
    return wn.outputs["Value"], sep.outputs[0], sep.outputs[1]


# --- Hamburg: Elbphilharmonie -------------------------------------------------------------------

def elbphilharmonie(rig, p):
    """Concert hall on top of Kaispeicher A (2017): dark-red brick warehouse (37 m) with a grid of small
    windows, the plaza band (37 m) and a glass superstructure of curved, printed panels whose roof rises
    in concave waves to 110 m at the western tip. Wedge-shaped plan ~110 m long, 32 m wide at the west
    end and 78 m at the east end. 3/4 view from the south-west (Elbe side + western tip)."""
    XW, XE = -55.0, 55.0

    def yn(x):
        return 32.0 + (x - XW) / (XE - XW) * 46.0
    SC = [(-55.0, 110.0), (-22.0, 102.0), (12.0, 96.0), (38.0, 92.0), (55.0, 89.0)]
    SS = [17.0, 12.0, 9.0, 5.0]
    NC = [(-55.0, 105.0), (-17.0, 99.0), (17.0, 94.0), (41.0, 90.0), (55.0, 86.0)]
    NS = [14.0, 11.0, 8.0, 4.0]
    ZB, ZP = 37.0, 41.5
    # brick warehouse with a dense grid of small windows
    br = Shade("ep_brick", "#6e3a2b", rough=0.85, spec=0.25, color2="#5a2f24", nscale=0.8)
    br.grid("any", (-400, 400), (2.0, 36.2), (2.6, 4.3), (1.15, 1.75), lit=0.3, glass="#262626",
            color="#ffd9a0", strength=1.0)
    br.flood(FLOOD, 0.75, grad=(0.0, 37.0, 0.6))
    br_m = br.finish()
    bm = bmesh.new()
    prism(bm, [(XW, 0.0), (XE, 0.0), (XE, yn(XE)), (XW, yn(XW))], 0.0, ZB)
    make(rig, "ep_base", bm, br_m)
    # plaza band: recessed, glazed, brightly lit at night
    pl = Shade("ep_plaza", "#39424a", rough=0.15, spec=0.8, metal=0.2, noise=0.0)
    nb = pl.nb
    u = nb.madd(pl.x, nb.mul(pl.ny, -1.0), nb.mul(pl.y, pl.nx))
    post = nb.lt(nb.math("FLOORED_MODULO", u, 6.0), 0.9)
    pl.paint(post, "#d9d6cf", 0.7, 0.3)
    pl.glow(nb.NOT(post), "#ffe6bf", 0.7)
    pl_m = pl.finish()
    bm = bmesh.new()
    prism(bm, [(XW + 1.0, 1.0), (XE - 1.0, 1.0), (XE - 1.0, yn(XE) - 1.0), (XW + 1.0, yn(XW) - 1.0)], ZB, ZP)
    make(rig, "ep_plaza", bm, pl_m)
    # glass superstructure: curved printed panels (random brightness), floor lines, U-shaped loggias
    gl = Shade("ep_glass", "#a8bccb", rough=0.08, spec=0.9, metal=0.2, noise=0.0)
    nb = gl.nb
    u = nb.madd(gl.x, nb.mul(gl.ny, -1.0), nb.mul(gl.y, gl.nx))
    pu, pz = 3.4, 3.35
    zz = nb.sub(gl.z, ZP)
    rnd, r2, r3 = _cell_noise(nb, u, zz, pu, pz, nb.add(nb.mul(gl.nx, 3.0), nb.mul(gl.ny, 5.0)))
    gl.set_col(nb.ramp(rnd, [(0.0, M.srgb("#9db3c4")), (0.5, M.srgb("#c3d3de")), (1.0, M.srgb("#e6edf2"))]))
    fu = nb.math("FLOORED_MODULO", u, pu)
    fz = nb.math("FLOORED_MODULO", zz, pz)
    gl.paint(nb.lt(fz, 0.28), "#e9ebec", 0.5, 0.4)
    du = nb.absf(nb.sub(fu, pu / 2))
    cz = nb.sub(fz, 2.25)
    ush = nb.AND(nb.gt(r2, 0.92), nb.lt(du, 1.25), nb.gt(fz, 0.45),
                 nb.OR(nb.lt(cz, 0.0), nb.lt(nb.add(nb.mul(du, du), nb.mul(cz, cz)), 1.25 ** 2)))
    gl.paint(ush, "#28323a", 0.3, 0.5)
    lit = nb.lt(r3, 0.36)
    gl.add_emit(nb.color_scale(nb.color_scale(M.emit_col("#ffe8c4", 0.5), nb.madd(rnd, 0.6, 0.5)), lit))
    gl.glow(nb.NOT(lit), "#c9d8ec", 0.035)
    gl_m = gl.finish()
    roof_m = plain("ep_roof", "#e0e3e5", rough=0.35, spec=0.6, flood=("#e8eef5", 0.35))
    n = 110
    xs = [XW + i * (XE - XW) / n for i in range(n + 1)]
    bm = bmesh.new()
    S0 = [bm.verts.new((x, 0.0, ZP)) for x in xs]
    S1 = [bm.verts.new((x, 0.0, _wave(x, SC, SS))) for x in xs]
    N0 = [bm.verts.new((x, yn(x), ZP)) for x in xs]
    N1 = [bm.verts.new((x, yn(x), _wave(x, NC, NS))) for x in xs]
    faces = []
    for i in range(n):
        faces.append((bm.faces.new((S0[i], S0[i + 1], S1[i + 1], S1[i])), 0))
        faces.append((bm.faces.new((N0[i + 1], N0[i], N1[i], N1[i + 1])), 0))
        faces.append((bm.faces.new((S1[i], S1[i + 1], N1[i + 1], N1[i])), 1))
        faces.append((bm.faces.new((S0[i + 1], S0[i], N0[i], N0[i + 1])), 0))
    faces.append((bm.faces.new((S0[0], S1[0], N1[0], N0[0])), 0))
    faces.append((bm.faces.new((S0[-1], N0[-1], N1[-1], S1[-1])), 0))
    for f, mi in faces:
        f.material_index = mi
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    make(rig, "ep_glass", bm, [gl_m, roof_m])
    return dict(object=obj_size(XE - XW, 110.0, yn(XE)))


# --- Hamburg: St. Michaelis ("Michel") -----------------------------------------------------------

def michel(rig, p):
    """Baroque main church St. Michaelis: brick hall church on a cross plan with a copper roof, west
    tower 132 m: brick shaft with sandstone corners, the 8 m tower clocks, platform (82 m) and the
    copper-green octagonal top with two colonnade stages, dome, lantern and spire. South side, tower on
    the left (west)."""
    br = Shade("mi_brick", "#9e4c37", rough=0.85, spec=0.25, color2="#88402f", nscale=0.8)
    kw = dict(lit=0.25, glass="#283037", frame="#dccdaa", frame_w=0.4, arch=True, color="#ffd9a0", strength=1.0)
    br.grid("front", (-27.0, 31.0), (11.5, 21.0), (6.4, 12.0), (2.8, 9.0), **kw)
    br.grid("front", (-27.0, 31.0), (3.0, 7.6), (6.4, 6.0), (2.2, 4.2), seed=1, **kw)
    br.grid("left", (-44.0, 0.0), (11.5, 21.0), (6.4, 12.0), (2.8, 9.0), seed=2, **kw)
    br.grid("left", (-44.0, 0.0), (3.0, 7.6), (6.4, 6.0), (2.2, 4.2), seed=3, **kw)
    br.bands([(23.0, 24.4)], "#dccdaa", 0.8)
    br.flood(FLOOD, 1.0, grad=(0.0, 30.0, 0.75))
    br_m = br.finish()
    bm = bmesh.new()
    box(bm, -27.0, 31.0, 6.0, 38.0, 0.0, 24.4)          # nave
    box(bm, -6.0, 14.0, 0.0, 44.0, 0.0, 24.4)           # transept
    make(rig, "mi_body", bm, br_m)
    sand = Shade("mi_sand", "#d8c9a6", rough=0.85, spec=0.25, noise=0.06)
    sand.flood(FLOOD, 1.1)
    sand_m = sand.finish()
    bm = bmesh.new()
    for (x, y) in ((-27.0, 6.0), (31.0, 6.0), (-6.0, 0.0), (14.0, 0.0), (-27.0, 38.0), (31.0, 38.0)):
        box(bm, x - 0.8, x + 0.8, y - 0.8, y + 0.8, 0.0, 24.6)
    make(rig, "mi_pilasters", bm, sand_m)
    cu_m = copper("mi_copper", flood=0.75).finish()
    bm = bmesh.new()
    gable_roof(bm, -27.6, 31.6, 5.4, 38.6, 24.4, 40.0, axis="x", hip=10.0)
    gable_roof(bm, -6.6, 14.6, -0.6, 44.6, 24.4, 40.0, axis="y", hip=9.0)
    make(rig, "mi_roof", bm, cu_m)
    # tower: brick shaft, sandstone corners and cornices, clocks
    tx, ty, tw = -34.0, 22.0, 14.0
    tb = Shade("mi_tower", "#9e4c37", rough=0.85, spec=0.25, color2="#88402f", nscale=0.8)
    for i, face in enumerate(("front", "left", "back")):
        tb.grid(face, (-200.0, 200.0), (30.0, 52.0), (14.0, 11.0), (2.4, 8.0), lit=0.0, glass="#2a2f33",
                frame="#dccdaa", frame_w=0.4, arch=True, seed=i)
    tb.flood(FLOOD, 1.05, grad=(0.0, 75.0, 0.8))
    tb_m = tb.finish()
    bm = bmesh.new()
    frustum(bm, rect(tx, ty, tw, tw), 0.0, rect(tx, ty, tw - 1.0, tw - 1.0), 70.0)
    make(rig, "mi_tower", bm, tb_m)
    bm = bmesh.new()
    for sx in (-1, 1):
        for sy in (-1, 1):
            frustum(bm, rect(tx + sx * (tw / 2 - 0.6), ty + sy * (tw / 2 - 0.6), 2.0, 2.0), 0.0,
                    rect(tx + sx * (tw / 2 - 1.1), ty + sy * (tw / 2 - 1.1), 2.0, 2.0), 70.4)
    box(bm, tx - 7.4, tx + 7.4, ty - 7.4, ty + 7.4, 56.0, 57.2)
    box(bm, tx - 7.2, tx + 7.2, ty - 7.2, ty + 7.2, 70.0, 72.0)
    box(bm, tx - 7.4, tx - 6.6, ty - 3.5, ty + 3.5, 0.0, 12.0)          # west portal
    make(rig, "mi_tower_trim", bm, sand_m)
    dial = Shade("mi_dial", "#23282c", rough=0.4, spec=0.4, noise=0.0)
    dial.glow(None, "#fff1d0", 0.35)
    dial_m = dial.finish()
    gd_m = gold("mi_gold", flood=0.85)
    bm = bmesh.new()
    bmg = bmesh.new()
    zc, rc = 63.5, 4.0
    for (nx, ny) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        hw = tw / 2 - 0.85
        c = Vector((tx + nx * (hw + 0.25), ty + ny * (hw + 0.25), zc))
        MU.bm_cyl(rc, rc, 0.5, center=tuple(c), axis="Y" if ny else "X", segs=32, bm=bm)
        t = Vector((-ny, nx, 0.0))
        o = Vector((nx, ny, 0.0)) * 0.35
        for k in range(12):
            a = 2 * math.pi * k / 12
            q = c + o + t * (math.cos(a) * rc * 0.82) + Vector((0, 0, math.sin(a) * rc * 0.82))
            MU.bm_box(0.5, 0.5, 0.5, tuple(q), bm=bmg)
        beam(bmg, c + o, c + o + t * 1.2 + Vector((0, 0, 3.2)), 0.35)
        beam(bmg, c + o, c + o + t * 2.2 + Vector((0, 0, -0.6)), 0.3)
    make(rig, "mi_dials", bm, dial_m)
    # copper top: transition, two octagonal colonnade stages, dome, lantern, spire
    cu2 = copper("mi_top", flood=0.8)
    cu2.grid("round", (-200.0, 200.0), (82.5, 94.0), (4.6, 12.0), (2.2, 9.0), lit=0.6, glass="#1d2422", arch=True,
             cx=tx, cy=ty, r=4.8, color="#ffd28a", strength=0.9)
    cu2.grid("round", (-200.0, 200.0), (100.5, 108.5), (3.3, 9.0), (1.6, 6.6), lit=0.6, glass="#1d2422", arch=True,
             cx=tx, cy=ty, r=3.2, color="#ffd28a", strength=0.9, seed=1)
    top_m = cu2.finish()
    bm = bmesh.new()
    frustum(bm, rect(tx, ty, tw - 1.0, tw - 1.0), 72.0, rect(tx, ty, 9.2, 9.2), 79.0)
    lathe(bm, [(7.0, 79.0), (7.0, 80.6), (0.0, 80.6)], 8, tx, ty, math.pi / 8)        # platform
    lathe(bm, [(4.8, 80.6), (4.8, 95.0), (0.0, 95.0)], 8, tx, ty, math.pi / 8)         # core 1
    lathe(bm, [(6.4, 95.0), (6.4, 96.6), (4.9, 99.0), (0.0, 99.0)], 8, tx, ty, math.pi / 8)
    lathe(bm, [(3.2, 99.0), (3.2, 109.0), (0.0, 109.0)], 8, tx, ty, math.pi / 8)      # core 2
    lathe(bm, [(4.3, 109.0), (4.3, 110.2), (3.4, 111.4), (0.0, 111.4)], 8, tx, ty, math.pi / 8)
    lathe(bm, dome_profile(3.3, 7.6, "bell", 10, z0=111.4), 8, tx, ty, math.pi / 8)      # dome
    lathe(bm, [(1.1, 117.5), (1.1, 121.8), (1.5, 122.4), (0.0, 122.6)], 8, tx, ty, math.pi / 8)
    lathe(bm, [(0.55, 122.4), (0.12, 130.8), (0.0, 130.8)], 8, tx, ty)
    for (r, z0, z1, w) in ((6.0, 80.6, 95.0, 0.7), (4.05, 99.0, 109.0, 0.5)):    # colonnades
        for k in range(8):
            a = 2 * math.pi * k / 8
            for d in (-0.12, 0.12):
                x, y = tx + r * math.cos(a + d), ty + r * math.sin(a + d)
                box(bm, x - w / 2, x + w / 2, y - w / 2, y + w / 2, z0, z1)
    for k in range(40):                                                                 # balustrade
        a = 2 * math.pi * k / 40
        x, y = tx + 6.9 * math.cos(a), ty + 6.9 * math.sin(a)
        box(bm, x - 0.12, x + 0.12, y - 0.12, y + 0.12, 80.6, 81.8)
    lathe(bm, [(6.95, 81.8), (6.95, 82.1), (6.75, 82.1), (6.75, 81.8)], 32, tx, ty)
    make(rig, "mi_top", bm, top_m)
    MU.bm_sphere(0.75, center=(tx, ty, 125.0), subdiv=2, bm=bmg)
    beam(bmg, (tx, ty, 125.0), (tx, ty, 132.0), 0.25)
    beam(bmg, (tx - 1.1, ty, 130.2), (tx + 1.1, ty, 130.2), 0.22)
    make(rig, "mi_gold", bmg, gd_m)
    return dict(object=obj_size(72.0, 132.0, 44.0))


# --- Vienna: Stephansdom -----------------------------------------------------------------------

def zigzag_roof(name, flood=0.7):
    """Stephansdom roof: glazed tiles in big chevron bands (ochre, green, dark brown, cream)."""
    s = Shade(name, "#c9972e", rough=0.4, spec=0.55, noise=0.03)
    nb = s.nb
    period, amp, bandh = 5.6, 2.9, 1.45
    tri = nb.absf(nb.sub(nb.math("FLOORED_MODULO", nb.mul(s.x, 1.0 / period), 1.0), 0.5))
    v = nb.madd(tri, amp * 2.0, s.z)
    idx = nb.math("FLOORED_MODULO", nb.math("FLOOR", nb.math("DIVIDE", v, bandh)), 6.0)
    col = nb.ramp(nb.math("DIVIDE", nb.add(idx, 0.5), 6.0), [
        (0.0, M.srgb("#d3a332")), (0.166, M.srgb("#2f6a4c")), (0.333, M.srgb("#d3a332")), (0.5, M.srgb("#2b2522")),
        (0.666, M.srgb("#d8cfb6")), (0.833, M.srgb("#2f6a4c"))])
    ramp = col.node
    ramp.color_ramp.interpolation = "CONSTANT"
    s.set_col(nb.mix(nb.lt(nb.math("FLOORED_MODULO", s.z, 0.45), 0.06), col, M.srgb("#3a3128")))
    s.flood(FLOOD, flood)
    return s.finish()


def stephansdom(rig, p):
    """St. Stephen's Cathedral: 107 m long, steep roof (ridge ~61 m) with the zigzag tile pattern,
    gothic south tower 'Steffl' 136.4 m, unfinished north tower (68 m) with the Renaissance cap, the two
    Heidentuerme at the west front, buttresses with pinnacles and gables along the south wall."""
    S_Y, N_Y, X_W, X_E = 4.0, 38.0, -50.0, 57.0
    lime = Shade("sd_stone", "#b3aa98", rough=0.85, spec=0.25, noise=0.09, nscale=0.18, color2="#8a8172")
    lime.grid("front", (-46.0, 45.0), (5.0, 21.0), (9.4, 30.0), (3.6, 15.5), lit=0.25, glass="#2a2e33",
              pointed=True, frame="#9c9383", frame_w=0.3, color="#ffcf8f", strength=0.9)
    lime.grid("left", (-34.0, -8.0), (27.0, 45.0), (26.0, 30.0), (7.0, 17.0), lit=0.0, glass="#2d3135",
              pointed=True, frame="#9c9383", frame_w=0.4)
    lime.flood(FLOOD, 1.15, grad=(0.0, 140.0, 0.7))
    lime_m = lime.finish()
    bm = bmesh.new()
    prism(bm, [(X_W, S_Y), (48.0, S_Y), (X_E, 13.0), (X_E, 29.0), (48.0, N_Y), (X_W, N_Y)], 0.0, 25.0)
    # west gable wall (the roof is open at the west end)
    v = [bm.verts.new(q) for q in ((X_W - 0.4, S_Y, 25.0), (X_W - 0.4, N_Y, 25.0), (X_W - 0.4, 21.0, 61.0),
                                   (X_W + 0.6, S_Y, 25.0), (X_W + 0.6, N_Y, 25.0), (X_W + 0.6, 21.0, 61.0))]
    for f in ((v[0], v[1], v[2]), (v[3], v[5], v[4]), (v[0], v[3], v[4], v[1]), (v[0], v[2], v[5], v[3]),
              (v[1], v[4], v[5], v[2])):
        bm.faces.new(f)
    for k in range(7):
        t = (k + 0.5) / 7
        pinnacle(bm, X_W - 0.2, S_Y + (N_Y - S_Y) * t, 24.0 + (61.0 - 25.0) * (1.0 - abs(2 * t - 1.0)), 0.8, 4.5)
    # buttresses with pinnacles along the south wall, gables (Wimperge) between them
    for i in range(11):
        x = -45.3 + i * 9.4
        box(bm, x - 1.0, x + 1.0, S_Y - 2.4, S_Y, 0.0, 22.0)
        pinnacle(bm, x, S_Y - 1.2, 22.0, 1.4, 9.5)
        if i < 10:
            xm = x + 4.7
            gable_xz(bm, [(xm - 3.6, 25.0), (xm + 3.6, 25.0), (xm, 33.5)], S_Y - 0.8, 0.6)
            pinnacle(bm, xm, S_Y - 0.5, 31.5, 0.6, 4.0)
    # Heidentuerme (west front)
    for y in (S_Y + 4.0, N_Y - 4.0):
        lathe(bm, [(3.6, 0.0), (3.6, 50.0), (3.9, 50.6), (3.9, 51.4), (0.0, 51.4)], 8, X_W - 2.0, y, math.pi / 8)
        lathe(bm, [(3.4, 51.4), (0.0, 65.0)], 8, X_W - 2.0, y, math.pi / 8)
    # north tower (unfinished, 68 m with the cap)
    nx_, ny_ = -6.0, N_Y + 4.5
    frustum(bm, rect(nx_, ny_, 12.0, 12.0), 0.0, rect(nx_, ny_, 11.0, 11.0), 56.0)
    make(rig, "sd_stone", bm, lime_m)
    # south tower 'Steffl'
    sx_, sy_ = -6.0, 6.5
    tw = Shade("sd_tower", "#ab9f8b", rough=0.85, spec=0.25, noise=0.1, nscale=0.15, color2="#857a69")
    for i, face in enumerate(("front", "left", "right")):
        tw.grid(face, (-200.0, 200.0), (18.0, 56.0), (4.2, 19.0), (1.8, 12.0), lit=0.0, glass="#2b2e31",
                pointed=True, seed=i)
    tw.grid("round", (-200.0, 200.0), (73.0, 91.0), (3.0, 18.0), (1.4, 15.0), lit=0.0, glass="#2b2e31",
            pointed=True, cx=sx_, cy=sy_, r=4.0)
    tw.flood(FLOOD, 1.2, grad=(0.0, 136.0, 0.7))
    tw_m = tw.finish()
    bm = bmesh.new()
    frustum(bm, rect(sx_, sy_, 13.0, 13.0), 0.0, rect(sx_, sy_, 12.0, 12.0), 34.0)
    for ddx in (-1, 1):
        for ddy in (-1, 1):
            cx, cy = sx_ + ddx * 6.3, sy_ + ddy * 6.3
            frustum(bm, rect(cx, cy, 2.6, 2.6), 0.0, rect(cx - ddx * 0.6, cy - ddy * 0.6, 1.8, 1.8), 36.0)
            pinnacle(bm, cx - ddx * 0.6, cy - ddy * 0.6, 36.0, 1.6, 9.0)
    frustum(bm, rect(sx_, sy_, 11.0, 11.0), 34.0, rect(sx_, sy_, 9.6, 9.6), 58.0)
    for ddx in (-1, 1):
        for ddy in (-1, 1):
            pinnacle(bm, sx_ + ddx * 4.6, sy_ + ddy * 4.6, 58.0, 1.3, 8.0)
    for (ddx, ddy) in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        pinnacle(bm, sx_ + ddx * 4.9, sy_ + ddy * 4.9, 58.0, 0.9, 6.5)
    frustum(bm, octagon(sx_, sy_, 4.7), 58.0, octagon(sx_, sy_, 4.2), 72.0)
    frustum(bm, octagon(sx_, sy_, 4.1), 72.0, octagon(sx_, sy_, 3.3), 99.0)
    R8 = 1.0 / math.cos(math.pi / 8)
    for k in range(8):
        a = 2 * math.pi * k / 8
        pinnacle(bm, sx_ + 4.2 * R8 * math.cos(a + math.pi / 8), sy_ + 4.2 * R8 * math.sin(a + math.pi / 8),
                 72.0, 0.9, 7.0)
        pinnacle(bm, sx_ + 3.5 * R8 * math.cos(a + math.pi / 8), sy_ + 3.5 * R8 * math.sin(a + math.pi / 8),
                 96.0, 0.7, 6.5)
        face_gable(bm, (sx_ + 3.55 * math.cos(a), sy_ + 3.55 * math.sin(a)), a, 1.3, 92.0, 97.5)
    pyramid(bm, octagon(sx_, sy_, 3.35), 99.0, (sx_, sy_, 134.0))
    for k in range(8):                                     # crockets along the spire edges
        a = 2 * math.pi * k / 8 + math.pi / 8
        for j in range(1, 9):
            t = j / 9.5
            r = 3.35 * R8 * (1 - t)
            MU.bm_box(0.55, 0.55, 0.55, (sx_ + r * math.cos(a), sy_ + r * math.sin(a), 99.0 + 35.0 * t), bm=bm)
    beam(bm, (sx_, sy_, 133.5), (sx_, sy_, 136.4), 0.35)
    beam(bm, (sx_ - 0.9, sy_, 135.4), (sx_ + 0.9, sy_, 135.4), 0.25)
    make(rig, "sd_tower", bm, tw_m)
    # roof: south/north slopes, hipped polygonal choir end
    roof_m = zigzag_roof("sd_roof")
    ZE, ZR, XR = 25.0, 61.0, 44.0
    bm = bmesh.new()
    ys, yn_ = S_Y - 0.6, N_Y + 0.6
    v = {k: bm.verts.new(q) for k, q in {
        "sw": (X_W, ys, ZE), "se": (48.3, ys, ZE), "e1": (X_E + 0.6, 12.8, ZE), "e2": (X_E + 0.6, 29.2, ZE),
        "ne": (48.3, yn_, ZE), "nw": (X_W, yn_, ZE), "rw": (X_W, 21.0, ZR), "re": (XR, 21.0, ZR)}.items()}
    for f in (("sw", "se", "re", "rw"), ("ne", "nw", "rw", "re"), ("se", "e1", "re"), ("e1", "e2", "re"),
              ("e2", "ne", "re"), ("sw", "rw", "nw"), ("sw", "nw", "ne", "e2", "e1", "se")):
        bm.faces.new([v[k] for k in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    make(rig, "sd_roof", bm, roof_m)
    # north tower cap (Renaissance helmet, copper)
    cu_m = copper("sd_cap", flood=0.7).finish()
    bm = bmesh.new()
    lathe(bm, dome_profile(5.2, 7.5, "helmet", 12, z0=56.0), 12, nx_, ny_)
    lathe(bm, [(1.1, 63.0), (1.1, 65.6), (0.0, 68.3)], 8, nx_, ny_)
    make(rig, "sd_cap", bm, cu_m)
    return dict(object=obj_size(X_E - X_W + 6.0, 136.4, N_Y + 11.0))


# --- Dresden: Frauenkirche ----------------------------------------------------------------------

def frauenkirche_dresden(rig, p):
    """Baroque Frauenkirche (1743, rebuilt 2005): square body with chamfered corners and four corner
    staircase towers, the stone bell dome ('Steinerne Glocke', ~26 m wide), lantern and gilded cross at
    91 m. Light new sandstone mixed with dark old stones from the ruin."""
    yc, hw, ch = 25.0, 21.0, 7.0
    st = Shade("fk_stone", "#dccda6", rough=0.85, spec=0.25, noise=0.06, nscale=0.3)
    block_patches(st, "#5a4f44", p_lo=0.0, p_hi=0.6, region=0.56, rscale=0.07, bw=1.6, bh=0.8, zfade=33.0)
    kw = dict(lit=0.3, glass="#2b2f33", frame="#c9b88f", frame_w=0.35, arch=True, color="#ffd49a", strength=0.9)
    for i, (face, ur) in enumerate((("front", (-12.5, 12.5)), ("left", (-yc - 12.5, -yc + 12.5)),
                                    ("right", (yc - 12.5, yc + 12.5)))):
        st.grid(face, ur, (4.0, 13.0), (5.0, 12.0), (2.3, 8.0), seed=i, **kw)
        st.grid(face, ur, (15.5, 23.0), (5.0, 9.0), (2.3, 6.2), seed=i + 3, **kw)
    st.bands([(13.8, 14.6), (24.0, 26.0)], "#cdbd96")
    st.flood(FLOOD, 0.95, grad=(0.0, 91.0, 0.8))
    st_m = st.finish()
    poly = [(-hw + ch, yc - hw), (hw - ch, yc - hw), (hw, yc - hw + ch), (hw, yc + hw - ch), (hw - ch, yc + hw),
            (-hw + ch, yc + hw), (-hw, yc + hw - ch), (-hw, yc - hw + ch)]
    bm = bmesh.new()
    prism(bm, poly, 0.0, 26.0)
    # porticos on the three visible sides, apse at the back
    box(bm, -7.0, 7.0, yc - hw - 2.2, yc - hw, 0.0, 19.0)
    gable_roof(bm, -7.6, 7.6, yc - hw - 2.6, yc - hw, 19.0, 23.5, axis="y")
    for sx in (-1, 1):
        box(bm, min(sx * hw, sx * (hw + 2.2)), max(sx * hw, sx * (hw + 2.2)), yc - 7.0, yc + 7.0, 0.0, 19.0)
    lathe(bm, [(11.0, 0.0), (11.0, 24.0), (0.0, 24.0)], 20, 0.0, yc + hw)
    # roof zone: concave stone transition from the chamfered square up to the dome
    rings = [(ray_poly(poly, 48, 0.0, yc, 0.0, k), z) for (k, z) in ((1.0, 26.0), (0.97, 27.2), (0.93, 28.0))]
    for t, z in ((0.25, 29.6), (0.5, 31.2), (0.75, 32.7), (1.0, 34.0)):
        src = ray_poly(poly, 48, 0.0, yc, 0.0, 0.93)
        dst = circle(15.2, 48, 0.0, yc, 0.0)
        tt = 1.0 - (1.0 - t) ** 1.6
        rings.append(([(a[0] + (b[0] - a[0]) * tt, a[1] + (b[1] - a[1]) * tt) for a, b in zip(src, dst)], z))
    for (p0, z0), (p1, z1) in zip(rings[:-1], rings[1:]):
        frustum(bm, p0, z0, p1, z1, caps=False)
    # corner staircase towers with their small domes
    for (cx, cy) in ((-hw + 2.6, yc - hw + 2.6), (hw - 2.6, yc - hw + 2.6), (hw - 2.6, yc + hw - 2.6),
                     (-hw + 2.6, yc + hw - 2.6)):
        lathe(bm, [(4.0, 0.0), (4.0, 36.0), (4.4, 36.6), (4.4, 37.4), (3.6, 37.6), (3.4, 41.0), (0.0, 41.0)], 16, cx, cy)
        lathe(bm, dome_profile(3.4, 4.6, "bell", 8, z0=41.0), 16, cx, cy)
        lathe(bm, [(1.0, 45.4), (1.0, 48.0), (1.2, 48.4), (0.0, 50.5)], 8, cx, cy)
    # stone bell dome, lantern drum, lantern, cap
    lathe(bm, [(15.2, 34.0), (13.6, 36.0), (13.2, 39.0), (13.0, 43.0), (12.6, 47.5), (11.8, 51.5), (10.2, 55.5),
               (8.0, 58.8), (6.0, 61.0), (5.0, 62.2), (0.0, 62.2)], 32, 0.0, yc)
    lathe(bm, [(5.0, 62.2), (4.7, 67.0), (5.6, 67.2), (5.6, 67.9), (0.0, 67.9)], 16, 0.0, yc)
    lathe(bm, [(3.5, 67.9), (3.3, 75.0), (3.9, 75.4), (3.9, 76.2), (0.0, 76.2)], 16, 0.0, yc)
    lathe(bm, dome_profile(3.6, 5.8, "bell", 10, z0=76.2), 16, 0.0, yc)
    lathe(bm, [(0.9, 81.8), (0.7, 84.0), (0.0, 84.0)], 8, 0.0, yc)
    make(rig, "fk_body", bm, st_m)
    # lantern openings (dark), gilded orb and cross
    dk = plain("fk_open", "#25282b", rough=0.6, glow=("#ffd49a", 0.55))
    bm = bmesh.new()
    for k in range(8):
        a = 2 * math.pi * k / 8
        MU.bm_box(0.6, 0.6, 5.0, (3.38 * math.cos(a), yc + 3.38 * math.sin(a), 71.6), bm=bm)
    make(rig, "fk_open", bm, dk)
    bm = MU.bm_sphere(1.0, center=(0.0, yc, 85.0), subdiv=2)
    beam(bm, (0.0, yc, 84.0), (0.0, yc, 91.0), 0.32)
    beam(bm, (-1.5, yc, 89.0), (1.5, yc, 89.0), 0.3)
    make(rig, "fk_gold", bm, gold("fk_gold", flood=0.85))
    return dict(object=obj_size(2 * hw + 4.4, 91.0, 2 * hw + 2.2 + 11.0))


# --- Munich: Frauenkirche ----------------------------------------------------------------------

def frauenkirche_muenchen(rig, p):
    """Late gothic brick cathedral (1488): 109 m long, 40 m wide, huge tiled roof, twin west towers
    (98.5 m) with the green 'Welsche Hauben'. West front towards the road, nave going back."""
    TW, GAP = 12.0, 7.5
    br = Shade("fm_brick", "#9c4f3a", rough=0.85, spec=0.25, color2="#87432f", nscale=0.8)
    kw = dict(lit=0.15, glass="#2a2e32", pointed=True, color="#ffd49a", strength=0.9)
    br.grid("left", (-104.0, -15.0), (6.0, 27.0), (7.2, 30.0), (2.2, 19.0), **kw)
    br.grid("front", (-7.0, 7.0), (14.0, 26.0), (14.0, 20.0), (4.4, 11.0), seed=1, **kw)
    br.grid("front", (-20.0, 20.0), (40.0, 58.0), (3.5, 6.0), (0.9, 1.8), lit=0.0, glass="#2b2b2b", seed=5)
    br.bands([(31.0, 32.0)], "#d6c6ab")
    br.flood(FLOOD, 0.85, grad=(0.0, 100.0, 0.75))
    br_m = br.finish()
    bm = bmesh.new()
    prism(bm, [(-20.0, 10.0), (20.0, 10.0), (20.0, 101.0), (13.0, 108.0), (-13.0, 108.0), (-20.0, 101.0)],
          0.0, 32.0)                                                      # nave + polygonal choir
    box(bm, -GAP, GAP, 0.0, 10.0, 0.0, 32.0)                              # west wall between the towers
    gable_xz(bm, [(-GAP, 32.0), (GAP, 32.0), (0.0, 46.0)], 1.0, 1.0)
    for sx in (-1, 1):                                                    # towers
        cx = sx * (GAP + TW / 2)
        box(bm, cx - TW / 2, cx + TW / 2, 0.0, TW, 0.0, 63.0)
        lathe(bm, [(6.3, 63.0), (6.3, 77.0), (0.0, 77.0)], 8, cx, TW / 2, math.pi / 8)
        for ddx in (-1, 1):                                               # corner gables square -> octagon
            for ddy in (-1, 1):
                x0, y0 = cx + ddx * (TW / 2 - 1.5), TW / 2 + ddy * (TW / 2 - 1.5)
                pyramid(bm, rect(x0, y0, 3.0, 3.0), 63.0, (x0, y0, 67.5))
    make(rig, "fm_brick", bm, br_m)
    # belfry openings (dark lancets) on the octagons
    op = plain("fm_open", "#26292c", rough=0.6, glow=("#ffd49a", 0.25))
    bm = bmesh.new()
    for sx in (-1, 1):
        cx = sx * (GAP + TW / 2)
        for k in range(8):
            a = 2 * math.pi * k / 8
            c = Vector((cx + 5.86 * math.cos(a), TW / 2 + 5.86 * math.sin(a), 0.0))
            t3 = Vector((-math.sin(a), math.cos(a), 0.0))
            v = [bm.verts.new(c + t3 * d + Vector((0, 0, zz))) for (d, zz) in
                 ((-0.7, 67.0), (0.7, 67.0), (0.7, 73.5), (0.0, 74.7), (-0.7, 73.5))]
            bm.faces.new(v)
    make(rig, "fm_open", bm, op)
    roof = Shade("fm_roof", "#8d3b2b", rough=0.75, spec=0.3, noise=0.08, nscale=0.6)
    roof.flood(FLOOD, 0.45)
    bm = bmesh.new()
    gable_roof(bm, -20.8, 20.8, 9.5, 102.0, 32.0, 56.0, axis="y")
    pyramid(bm, [(-20.8, 101.5), (20.8, 101.5), (13.4, 108.8), (-13.4, 108.8)], 32.0, (0.0, 101.5, 56.0))
    make(rig, "fm_roof", bm, roof.finish())
    # Welsche Hauben (copper green) with lanterns, orbs and crosses
    cu_m = copper("fm_dome", flood=0.85).finish()
    bm = bmesh.new()
    bmg = bmesh.new()
    for sx in (-1, 1):
        cx, cy = sx * (GAP + TW / 2), TW / 2
        lathe(bm, [(6.1, 77.0), (6.6, 79.2), (6.7, 81.0), (6.3, 83.0), (5.0, 85.2), (3.2, 86.6), (2.25, 87.6),
                   (2.0, 88.4), (2.0, 91.6), (2.6, 92.0), (2.5, 93.4), (1.7, 94.8), (0.72, 96.0), (0.27, 96.6),
                   (0.0, 96.8)], 24, cx, cy)
        MU.bm_sphere(0.55, center=(cx, cy, 97.2), subdiv=2, bm=bmg)
        beam(bmg, (cx, cy, 96.6), (cx, cy, 98.6), 0.18)
        beam(bmg, (cx - 0.6, cy, 98.1), (cx + 0.6, cy, 98.1), 0.16)
    make(rig, "fm_domes", bm, cu_m, smooth=True, sharp=50.0)
    make(rig, "fm_gold", bmg, gold("fm_gold", flood=0.8))
    return dict(object=obj_size(40.0, 98.6, 109.0))


# --- Barcelona: Sagrada Familia ------------------------------------------------------------------

def _gaudi_tower(bm, cx, cy, r0, z0, z1, k_cyl=0.4, n=12):
    """Gaudi tower: cylinder turning into a slender paraboloid; returns the top (z, r)."""
    h = z1 - z0
    prof = [(r0 * 1.06, z0), (r0, z0 + 0.03 * h), (r0, z0 + k_cyl * h)]
    for i in range(1, n + 1):
        t = i / n
        prof.append((r0 * math.sqrt(max(0.0, 1.0 - 0.93 * t)), z0 + (k_cyl + (1.0 - k_cyl) * t) * h))
    r_top = prof[-1][0]
    prof.append((0.0, z1))
    lathe(bm, prof, 16, cx, cy)
    return z1, r_top


def _finial(bmc, bmw, cx, cy, z0, s=1.0):
    """Mosaic finial of an apostle tower: stem, mitre-like coloured crown, white cross."""
    lathe(bmc, [(0.9 * s, z0), (0.6 * s, z0 + 3.5 * s), (1.5 * s, z0 + 5.0 * s), (1.7 * s, z0 + 6.6 * s),
                (1.0 * s, z0 + 8.4 * s), (0.0, z0 + 9.0 * s)], 12, cx, cy)
    for k in range(8):
        a = 2 * math.pi * k / 8
        MU.bm_sphere(0.45 * s, center=(cx + 1.7 * s * math.cos(a), cy + 1.7 * s * math.sin(a), z0 + 5.8 * s),
                     subdiv=1, bm=bmw)
    beam(bmw, (cx, cy, z0 + 8.6 * s), (cx, cy, z0 + 12.0 * s), 0.55 * s)
    beam(bmw, (cx - 1.3 * s, cy, z0 + 10.9 * s), (cx + 1.3 * s, cy, z0 + 10.9 * s), 0.5 * s)
    beam(bmw, (cx, cy - 1.3 * s, z0 + 10.9 * s), (cx, cy + 1.3 * s, z0 + 10.9 * s), 0.5 * s)


def sagrada_familia(rig, p):
    """Basilica of the Sagrada Familia (exterior completed 2026): seen from the Nativity facade - its four
    ochre apostle towers (98-107 m) with mosaic finials in front, the light central cluster behind: the
    tower of Jesus Christ with its four-armed cross (172.5 m), the four evangelists (135 m) and the tower
    of Mary with the star (138 m); the Passion facade towers (107-112 m) at the back."""
    old = Shade("sf_old", "#a99272", rough=0.85, spec=0.25, noise=0.12, nscale=0.6, color2="#7f6a50")
    old.grid("round", (-400, 400), (40.0, 92.0), (2.0, 2.9), (0.8, 1.6), lit=0.0, glass="#3a3027", cx=0.0, cy=0.0, r=3.8)
    old.flood(FLOOD, 1.1, grad=(0.0, 112.0, 0.8))
    old_m = old.finish()
    new = Shade("sf_new", "#d8cfbf", rough=0.8, spec=0.3, noise=0.06, nscale=0.4)
    nb = new.nb
    slots = nb.AND(nb.lt(nb.math("FLOORED_MODULO", new.z, 3.1), 1.3),
                   nb.lt(nb.math("FLOORED_MODULO", nb.add(new.x, new.y), 2.4), 0.7), nb.gt(new.z, 60.0), new.vert)
    new.paint(slots, "#5d564d", 0.7)
    new.grid("front", (-44.0, 14.0), (8.0, 38.0), (7.4, 32.0), (3.0, 22.0), lit=0.3, glass="#3b3631", pointed=True,
             color="#ffd9a0", strength=0.8)
    new.grid("left", (-52.0, -8.0), (6.0, 30.0), (8.8, 26.0), (3.4, 18.0), lit=0.0, glass="#3b3631", pointed=True,
             seed=1)
    new.flood(FLOOD_WHITE, 1.05, grad=(0.0, 172.0, 0.85))
    new_m = new.finish()
    yc = 30.0
    bm = bmesh.new()                        # old stone: Nativity + Passion facades and their towers
    bmc = bmesh.new()                       # mosaic crowns
    bmw = bmesh.new()                       # white crosses / balls
    for (yy, hs) in ((3.0, (98.0, 107.0, 107.0, 98.0)), (57.0, (107.0, 112.0, 112.0, 107.0))):
        for x, h in zip((-11.25, -3.75, 3.75, 11.25), hs):
            ztop, _r = _gaudi_tower(bm, x, yy, 3.8, 0.0, h - 15.0)
            _finial(bmc, bmw, x, yy, ztop - 0.8, 1.3)
        ys = yy - 3.0 if yy < yc else yy - 5.0
        box(bm, -15.5, 15.5, ys, ys + 8.0, 0.0, 42.0)
        for (gx, gw, gz) in ((-8.0, 6.0, 52.0), (0.0, 7.5, 60.0), (8.0, 6.0, 52.0)):
            pyramid(bm, rect(gx, ys + 4.0, gw, 7.0), 42.0, (gx, ys + 4.0, gz))
    make(rig, "sf_old", bm, old_m)
    # the cypress (tree of life, green) above the Nativity portal
    cyp = plain("sf_cypress", "#3f7a4a", rough=0.7, flood=(FLOOD, 0.9))
    bmcy = bmesh.new()
    lathe(bmcy, [(0.0, 52.0), (2.4, 54.0), (2.0, 60.0), (0.0, 66.0)], 12, 0.0, 1.5)
    make(rig, "sf_cypress", bmcy, cyp)
    # nave, apse, glory front (light stone), central towers
    bm = bmesh.new()
    box(bm, -45.0, 30.0, 8.0, 52.0, 0.0, 45.0)                       # nave body
    lathe(bm, [(17.0, 0.0), (17.0, 40.0), (0.0, 40.0)], 24, 30.0, yc)  # apse
    for k in range(7):
        a = -math.pi / 2 + math.pi * k / 6
        _gaudi_tower(bm, 30.0 + 15.5 * math.cos(a), yc + 15.5 * math.sin(a), 2.0, 30.0, 66.0, k_cyl=0.3, n=6)
    for i in range(10):                                                 # lanterns along the nave roof
        for yy in (11.0, 49.0):
            _gaudi_tower(bm, -42.0 + i * 7.4, yy, 1.6, 45.0, 57.0, k_cyl=0.2, n=5)
    _gaudi_tower(bm, 0.0, yc, 8.5, 0.0, 155.5, k_cyl=0.5, n=14)        # Jesus Christ
    for (ex, ey) in ((-11.0, yc - 11.0), (11.0, yc - 11.0), (-11.0, yc + 11.0), (11.0, yc + 11.0)):
        _gaudi_tower(bm, ex, ey, 5.4, 0.0, 128.0, k_cyl=0.5, n=12)    # evangelists
    _gaudi_tower(bm, 22.0, yc, 6.0, 0.0, 129.0, k_cyl=0.5, n=12)       # Mary
    box(bm, -48.0, -45.0, 10.0, 50.0, 0.0, 34.0)                       # glory facade (unfinished)
    make(rig, "sf_new", bm, new_m)
    crown = Shade("sf_mosaic", "#c23a2c", rough=0.3, spec=0.6, noise=0.0)
    nb = crown.nb
    chk = nb.math("FLOORED_MODULO", nb.add(nb.math("FLOOR", nb.mul(crown.z, 1.3)),
                                           nb.math("FLOOR", nb.mul(nb.add(crown.x, crown.y), 1.3))), 3.0)
    crown.paint(nb.lt(chk, 1.0), "#e3b52f")
    crown.paint(nb.gt(chk, 1.9), "#f1ece0")
    crown.flood(FLOOD, 1.2)
    make(rig, "sf_mosaic", bmc, crown.finish())
    # evangelists' symbols, Mary's star, the cross of Jesus (white, lit at night)
    for (ex, ey) in ((-11.0, yc - 11.0), (11.0, yc - 11.0), (-11.0, yc + 11.0), (11.0, yc + 11.0)):
        MU.bm_sphere(2.0, center=(ex, ey, 130.5), subdiv=2, bm=bmw)
        beam(bmw, (ex - 2.6, ey, 131.5), (ex + 2.6, ey, 131.5), 0.9, 1.6)
        beam(bmw, (ex, ey, 128.0), (ex, ey, 135.0), 0.8)
    for k in range(6):
        a = math.pi * k / 6
        beam(bmw, (22.0 + 4.5 * math.cos(a), yc, 133.5 + 4.5 * math.sin(a)),
             (22.0 - 4.5 * math.cos(a), yc, 133.5 - 4.5 * math.sin(a)), 1.0)
    beam(bmw, (0.0, yc, 155.0), (0.0, yc, 172.5), 2.2)
    beam(bmw, (-6.8, yc, 166.0), (6.8, yc, 166.0), 2.0)
    beam(bmw, (0.0, yc - 6.8, 166.0), (0.0, yc + 6.8, 166.0), 2.0)
    white = Shade("sf_white", "#eeeae2", rough=0.35, spec=0.6, noise=0.0)
    white.glow(None, "#fff6e6", 0.85)
    make(rig, "sf_white", bmw, white.finish())
    return dict(object=obj_size(93.0, 172.5, 62.0))


# --- Milan: Duomo --------------------------------------------------------------------------------

def duomo_milano(rig, p):
    """Milan Cathedral: white-pink Candoglia marble, five-aisled gothic nave (158 m long), the gabled
    west facade (61.5 m wide, 56 m) with its buttress pinnacles, a forest of spires (guglie) along every
    buttress line and the crossing spire with the golden Madonnina (108.5 m)."""
    L = 158.0
    mb = Shade("dm_marble", "#ebe4da", rough=0.7, spec=0.35, noise=0.05, nscale=0.3, color2="#d9cfc4")
    mb.grid("front", (-30.0, 30.0), (4.0, 14.0), (10.25, 12.0), (3.8, 7.0), lit=0.2, glass="#2c3035",
            frame="#d2c8bb", frame_w=0.3, color="#ffd9a6", strength=0.8)
    mb.grid("front", (-30.0, 30.0), (16.0, 27.0), (10.25, 14.0), (3.0, 9.0), lit=0.0, glass="#2c3035",
            pointed=True, seed=1)
    mb.grid("left", (-L, -6.0), (8.0, 22.0), (8.6, 20.0), (4.0, 13.0), lit=0.25, glass="#2c3035", pointed=True,
            color="#ffd9a6", strength=0.8, seed=2)
    mb.grid("left", (-L, -6.0), (29.0, 40.0), (8.6, 20.0), (3.6, 9.5), lit=0.0, glass="#2c3035", pointed=True,
            seed=3)
    mb.flood(FLOOD_WHITE, 0.85, grad=(0.0, 108.0, 0.8))
    mb_m = mb.finish()
    bm = bmesh.new()
    # aisles (outer 26 m, inner 35 m), central nave 44 m with a low roof, transept, polygonal apse
    box(bm, -30.0, 30.0, 0.0, 128.0, 0.0, 26.0)
    box(bm, -20.0, 20.0, 0.0, 128.0, 0.0, 35.0)
    box(bm, -10.0, 10.0, 0.0, 128.0, 0.0, 44.0)
    gable_roof(bm, -10.5, 10.5, 0.0, 128.0, 44.0, 49.0, axis="y")
    box(bm, -46.0, 46.0, 82.0, 104.0, 0.0, 35.0)
    gable_roof(bm, -46.0, 46.0, 82.0, 104.0, 35.0, 42.0, axis="x")
    apse = [(-30.0, 128.0), (30.0, 128.0), (27.0, 142.0), (17.0, 153.0), (0.0, L), (-17.0, 153.0), (-27.0, 142.0)]
    prism(bm, apse, 0.0, 35.0)
    # west facade: gabled outline
    half = [(30.75, 0.0), (30.75, 27.0), (20.0, 34.0), (11.0, 36.5), (11.0, 44.0), (0.0, 56.0)]
    outline = half + [(-x, z) for (x, z) in reversed(half[:-1])]
    gable_xz(bm, outline, -1.2, 1.4)
    # facade piers with tall pinnacles (statues on top)
    for x in (-30.75, -20.0, -10.5, 10.5, 20.0, 30.75):
        top = {30.75: 27.0, 20.0: 34.0, 10.5: 44.0}[abs(x)]
        box(bm, x - 1.3, x + 1.3, -2.4, 0.2, 0.0, top + 3.0)
        pinnacle(bm, x, -1.1, top + 3.0, 1.8, 13.0, top=0.6)
    for x in (-5.5, 5.5):
        pinnacle(bm, x, -0.8, 49.0, 1.1, 9.0, top=0.6)
    # forest of spires along the buttress lines
    for x in (-30.0, -20.0, -10.0, 10.0, 20.0, 30.0):
        z0 = {30.0: 26.0, 20.0: 35.0, 10.0: 44.0}[abs(x)]
        for k in range(15):
            y = 6.0 + k * 8.5
            if 82.0 < y < 104.0 and abs(x) > 10.0:
                continue
            pinnacle(bm, x, y, z0, 1.3 if abs(x) < 25 else 1.5, 12.0 if abs(x) > 15 else 9.0, top=0.6)
            if abs(x) > 15.0 and k % 1 == 0:
                # flying buttress towards the nave
                xi = x - math.copysign(9.6, x)
                beam(bm, (x, y, z0 + 2.0), (xi, y, z0 + 7.5), 0.7, 1.1)
    for (x, y) in ((-46.0, 84.0), (-46.0, 102.0), (46.0, 84.0), (46.0, 102.0), (-38.0, 84.0), (38.0, 84.0),
                   (-38.0, 102.0), (38.0, 102.0)):
        pinnacle(bm, x, y, 35.0, 1.5, 12.0, top=0.6)
    for (x, y) in apse[2:]:
        pinnacle(bm, x, y, 35.0, 1.5, 12.0, top=0.6)
    # crossing: octagonal tiburio with pinnacles, main spire
    cx, cy = 0.0, 93.0
    lathe(bm, [(10.0, 44.0), (10.0, 64.0), (0.0, 64.0)], 8, cx, cy, math.pi / 8)
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        R = 10.0 / math.cos(math.pi / 8)
        pinnacle(bm, cx + R * math.cos(a), cy + R * math.sin(a), 44.0, 1.8, 30.0, top=0.35)
    lathe(bm, [(4.6, 64.0), (4.6, 78.0), (3.6, 79.0), (0.0, 79.0)], 8, cx, cy, math.pi / 8)
    pyramid(bm, octagon(cx, cy, 3.4), 79.0, (cx, cy, 103.0))
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        R0 = 3.4 / math.cos(math.pi / 8)
        pinnacle(bm, cx + 4.6 / math.cos(math.pi / 8) * math.cos(a), cy + 4.6 / math.cos(math.pi / 8) * math.sin(a),
                 64.0, 1.0, 19.0, top=0.4)
        for j in range(1, 7):
            t = j / 7.5
            MU.bm_box(0.5, 0.5, 0.5, (cx + R0 * (1 - t) * math.cos(a), cy + R0 * (1 - t) * math.sin(a), 79.0 + 24.0 * t),
                      bm=bm)
    make(rig, "dm_body", bm, mb_m)
    bm = MU.bm_sphere(1.0, center=(cx, cy, 104.4), scale=(0.7, 0.7, 1.0), subdiv=2)
    lathe(bm, [(0.9, 102.8), (0.7, 104.0), (0.5, 106.5), (0.25, 108.0), (0.0, 108.5)], 10, cx, cy)
    beam(bm, (cx - 1.3, cy, 106.2), (cx + 1.3, cy, 106.2), 0.25)
    make(rig, "dm_madonnina", bm, gold("dm_gold", flood=0.9))
    return dict(object=obj_size(92.0, 108.5, L))


# --- Venice: Campanile di San Marco + basilica domes ---------------------------------------------

def campanile_venezia(rig, p):
    """St Mark's Campanile (98.6 m): brick shaft with lesenes, white loggia belfry, attic with reliefs,
    green pyramid and the golden archangel; behind it the five lead-grey domes of the basilica with their
    lanterns and its arched facade."""
    tx, ty, W = -24.0, 7.0, 12.0
    br = Shade("cv_brick", "#a35b43", rough=0.85, spec=0.25, color2="#8c4a35", nscale=0.7)
    nb = br.nb
    u = nb.madd(br.x, nb.absf(br.ny), nb.mul(br.y, nb.absf(br.nx)))
    les = nb.AND(nb.gt(nb.math("FLOORED_MODULO", nb.sub(u, 0.5), 2.2), 1.75), nb.lt(br.z, 48.0), br.vert)
    br.paint(les, "#7d3f2d")
    br.flood(FLOOD, 1.25, grad=(0.0, 50.0, 0.85))
    br_m = br.finish()
    bm = bmesh.new()
    box(bm, tx - W / 2, tx + W / 2, ty - W / 2, ty + W / 2, 0.0, 49.0)
    make(rig, "cv_shaft", bm, br_m)
    ist = Shade("cv_istria", "#e6e0d3", rough=0.75, spec=0.3, noise=0.05)
    ist.grid("front", (tx - 6.0, tx + 6.0), (51.5, 59.0), (3.0, 9.0), (2.0, 6.6), lit=0.0, glass="#2a2d30", arch=True)
    ist.grid("left", (-ty - 6.0, -ty + 6.0), (51.5, 59.0), (3.0, 9.0), (2.0, 6.6), lit=0.0, glass="#2a2d30", arch=True)
    ist.grid("right", (ty - 6.0, ty + 6.0), (51.5, 59.0), (3.0, 9.0), (2.0, 6.6), lit=0.0, glass="#2a2d30", arch=True)
    nb = ist.nb
    relief = nb.AND(nb.band(ist.z, 63.0, 69.0), nb.lt(nb.absf(nb.sub(nb.madd(ist.x, nb.absf(ist.ny),
                    nb.mul(ist.y, nb.absf(ist.nx))), nb.add(nb.mul(nb.absf(ist.ny), tx), nb.mul(nb.absf(ist.nx), ty)))), 2.6),
                    ist.vert)
    ist.paint(relief, "#b9b0a0")
    ist.flood(FLOOD_WHITE, 1.1)
    ist_m = ist.finish()
    bm = bmesh.new()
    box(bm, tx - 6.3, tx + 6.3, ty - 6.3, ty + 6.3, 49.0, 50.6)       # balustrade base
    box(bm, tx - 5.6, tx + 5.6, ty - 5.6, ty + 5.6, 50.6, 60.2)       # loggia
    box(bm, tx - 6.4, tx + 6.4, ty - 6.4, ty + 6.4, 60.2, 61.6)       # cornice
    box(bm, tx - 5.8, tx + 5.8, ty - 5.8, ty + 5.8, 61.6, 70.0)       # attic with reliefs
    box(bm, tx - 6.3, tx + 6.3, ty - 6.3, ty + 6.3, 70.0, 71.2)
    for dx in (-5.9, 5.9):
        for dy in (-5.9, 5.9):
            pinnacle(bm, tx + dx, ty + dy, 71.2, 0.8, 3.2)
    make(rig, "cv_belfry", bm, ist_m)
    cu = copper("cv_pyramid", flood=0.75)
    bm = bmesh.new()
    pyramid(bm, rect(tx, ty, 11.2, 11.2), 71.2, (tx, ty, 95.6))
    make(rig, "cv_pyramid", bm, cu.finish())
    bm = MU.bm_sphere(0.7, center=(tx, ty, 95.8), subdiv=2)
    lathe(bm, [(0.6, 96.2), (0.5, 97.4), (0.3, 98.4), (0.0, 98.6)], 8, tx, ty)
    beam(bm, (tx - 1.2, ty, 97.6), (tx + 1.2, ty, 97.2), 0.5, 0.15)
    make(rig, "cv_angel", bm, gold("cv_gold", flood=0.9))
    # basilica: arched facade with gilded mosaics, five domes with lanterns
    bx0, bx1, by0, by1 = -8.0, 46.0, 14.0, 80.0
    ba = Shade("cv_basilica", "#d9cdb8", rough=0.75, spec=0.3, noise=0.07, color2="#c4b49b")
    ba.grid("front", (bx0 + 1.0, bx1 - 1.0), (0.5, 16.0), (10.4, 15.5), (7.0, 12.5), lit=0.0, glass="#b8902f",
            arch=True, glass_rough=0.35)
    ba.grid("front", (bx0 + 1.0, bx1 - 1.0), (15.0, 25.0), (10.4, 15.0), (6.2, 9.0), lit=0.0, glass="#3a3020",
            arch=True, seed=1)
    ba.flood(FLOOD, 1.1)
    ba_m = ba.finish()
    bm = bmesh.new()
    box(bm, bx0, bx1, by0, by1, 0.0, 26.0)
    for i in range(5):                       # ogee-arched gables over the five bays (simplified as arcs)
        x = bx0 + 1.0 + 10.4 * (i + 0.5)
        gable_xz(bm, arch_pts(x, 26.0, 4.8, 5.5, 10)[::-1], by0 - 0.2, 0.8)
    for i in range(6):
        pinnacle(bm, bx0 + 1.0 + 10.4 * i, by0 + 0.3, 26.0, 0.9, 6.5)
    make(rig, "cv_basilica", bm, ba_m)
    lead = Shade("cv_lead", "#8d9396", rough=0.55, spec=0.4, metal=0.3, noise=0.05)
    lead.flood(FLOOD_WHITE, 0.9)
    lead_m = lead.finish()
    bm = bmesh.new()
    bmg = bmesh.new()
    cxm, cym = (bx0 + bx1) / 2, (by0 + by1) / 2
    for (dx, dy, r) in ((0.0, 0.0, 7.2), (0.0, -20.0, 6.0), (0.0, 20.0, 6.0), (-19.0, 0.0, 6.0), (19.0, 0.0, 6.0)):
        x, y = cxm + dx, cym + dy
        lathe(bm, [(r * 1.05, 26.0), (r, 28.5)] + [(rr, z) for (rr, z) in dome_profile(r, r * 1.55, "onion", 12,
                                                                                             z0=28.5)][1:], 20, x, y)
        zt = 28.5 + r * 1.55
        lathe(bm, [(0.9, zt - 0.3), (0.9, zt + 1.8), (1.3, zt + 2.3), (0.0, zt + 3.6)], 10, x, y)
        beam(bmg, (x, y, zt + 3.4), (x, y, zt + 6.0), 0.3)
        beam(bmg, (x - 0.8, y, zt + 5.2), (x + 0.8, y, zt + 5.2), 0.25)
    make(rig, "cv_domes", bm, lead_m, smooth=True, sharp=50.0)
    make(rig, "cv_crosses", bmg, gold("cv_gold2", flood=0.8))
    return dict(object=obj_size(76.0, 98.6, 80.0))


# --- Budapest: Parliament ------------------------------------------------------------------------

def parlament_budapest(rig, p):
    """Hungarian Parliament (1904): 268 m long Danube facade in white neo-gothic stone with red roofs,
    ribbed central dome (96 m) with lantern and spire, the two chamber halls with their steep roofs and
    corner towers, end pavilions and a dense row of pinnacles. Golden floodlight at night."""
    st = Shade("pb_stone", "#e7dfcc", rough=0.8, spec=0.3, noise=0.05, nscale=0.3)
    kw = dict(glass="#2e3236", pointed=True, color="#ffd28a", strength=0.85)
    st.grid("front", (-134.0, 134.0), (2.0, 8.5), (5.6, 10.0), (2.6, 5.5), lit=0.35, **kw)
    st.grid("front", (-134.0, 134.0), (10.5, 19.5), (5.6, 10.0), (2.2, 7.0), lit=0.4, seed=1, **kw)
    st.grid("left", (-130.0, 0.0), (2.0, 8.5), (5.6, 10.0), (2.6, 5.5), lit=0.35, seed=2, **kw)
    st.grid("left", (-130.0, 0.0), (10.5, 19.5), (5.6, 10.0), (2.2, 7.0), lit=0.4, seed=3, **kw)
    st.grid("round", (-400.0, 400.0), (44.0, 54.0), (3.4, 12.0), (1.6, 7.5), lit=0.6, cx=0.0, cy=30.0, r=17.0,
            seed=4, **kw)
    st.flood("#ffd08a", 1.25, grad=(0.0, 96.0, 0.85))
    st_m = st.finish()
    rf = Shade("pb_roof", "#9a4334", rough=0.65, spec=0.35, noise=0.08, nscale=0.5, color2="#7f3328")
    rf.flood("#ffcf8a", 0.9)
    rf_m = rf.finish()
    bm = bmesh.new()
    bmr = bmesh.new()
    # river wing along the whole length + end pavilions + chamber halls + central block
    box(bm, -134.0, 134.0, 0.0, 24.0, 0.0, 23.0)
    gable_roof(bmr, -134.0, 134.0, 0.0, 24.0, 23.0, 33.0, axis="x", hip=0.0)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 116.0, sx * 134.0))
        box(bm, x0, x1, -2.0, 30.0, 0.0, 27.0)
        gable_roof(bmr, x0, x1, -2.0, 30.0, 27.0, 40.0, axis="y", hip=5.0)
        x0, x1 = sorted((sx * 52.0, sx * 96.0))
        box(bm, x0, x1, 10.0, 62.0, 0.0, 30.0)                                    # chamber hall
        gable_roof(bmr, x0, x1, 10.0, 62.0, 30.0, 50.0, axis="x", hip=9.0)
        for (tx, ty) in ((x0, 10.0), (x1, 10.0), (x0, 62.0), (x1, 62.0)):         # corner towers
            lathe(bm, [(3.0, 0.0), (3.0, 46.0), (0.0, 46.0)], 8, tx, ty, math.pi / 8)
            lathe(bmr, [(3.2, 46.0), (0.0, 60.0)], 8, tx, ty, math.pi / 8)
        for (tx, ty) in ((sx * 116.0, -2.0), (sx * 134.0, -2.0)):                 # pavilion towers
            lathe(bm, [(2.6, 0.0), (2.6, 38.0), (0.0, 38.0)], 8, tx, ty, math.pi / 8)
            lathe(bmr, [(2.8, 38.0), (0.0, 50.0)], 8, tx, ty, math.pi / 8)
    box(bm, -28.0, 28.0, -3.0, 58.0, 0.0, 31.0)                                     # central block
    gable_roof(bmr, -28.0, 28.0, -3.0, 6.0, 31.0, 40.0, axis="x", hip=0.0)
    for tx in (-28.0, -14.0, 14.0, 28.0):
        pinnacle(bm, tx, -3.0, 31.0, 2.2, 14.0, top=0.5)
    # dome: 16-sided drum with windows, ribbed dome, lantern, spire
    lathe(bm, [(18.0, 31.0), (18.0, 42.0), (17.0, 42.5), (17.0, 56.0), (17.6, 56.8), (0.0, 56.8)], 16, 0.0, 30.0)
    lathe(bmr, [(17.4, 56.8), (16.6, 62.0), (14.8, 67.5), (11.6, 72.5), (7.4, 76.5), (4.0, 78.6), (0.0, 79.0)], 16,
          0.0, 30.0, math.pi / 16)
    lathe(bm, [(3.6, 78.4), (3.6, 84.0), (4.2, 84.6), (0.0, 84.6)], 16, 0.0, 30.0)
    lathe(bmr, [(3.4, 84.6), (0.0, 96.0)], 8, 0.0, 30.0)
    for k in range(16):                                                             # white ribs + pinnacles
        a = 2 * math.pi * k / 16
        pts = [(17.6, 56.8), (16.8, 62.0), (15.0, 67.5), (11.8, 72.5), (7.6, 76.5), (4.1, 78.6)]
        for (r0, z0), (r1, z1) in zip(pts[:-1], pts[1:]):
            beam(bm, (r0 * math.cos(a), 30.0 + r0 * math.sin(a), z0), (r1 * math.cos(a), 30.0 + r1 * math.sin(a), z1), 0.7)
        pinnacle(bm, 18.4 * math.cos(a), 30.0 + 18.4 * math.sin(a), 56.0, 1.0, 7.0)
    # dense row of pinnacles along the river facade (buttresses)
    for i in range(48):
        x = -131.0 + i * 5.6
        if abs(x) < 29.0:
            continue
        pinnacle(bm, x, -0.6, 23.0, 0.9, 7.5 if i % 2 else 5.5)
    make(rig, "pb_stone", bm, st_m)
    make(rig, "pb_roof", bmr, rf_m)
    return dict(object=obj_size(268.0, 96.0, 123.0))


# --- Prague: St. Vitus Cathedral above the castle front --------------------------------------------

def veitsdom_prag(rig, p):
    """St. Vitus Cathedral rising behind the long south front of Prague Castle: twin neo-gothic west
    spires (82 m), the great south tower (96.5 m) with its green baroque helmet, steep dark copper roofs,
    flying buttresses of the choir; in front the plastered palace wing with rows of windows."""
    pal = Shade("vp_palace", "#ece6d6", rough=0.85, spec=0.25, noise=0.04)
    pal.grid("front", (-92.0, 82.0), (2.0, 20.0), (3.6, 3.7), (1.4, 2.2), lit=0.3, glass="#2f3336", frame="#d2c9b4",
             frame_w=0.18, color="#ffd9a0", strength=0.9)
    pal.grid("left", (-30.0, 0.0), (2.0, 20.0), (3.6, 3.7), (1.4, 2.2), lit=0.3, glass="#2f3336", seed=1,
             color="#ffd9a0", strength=0.9)
    pal.bands([(0.0, 1.6), (20.6, 21.6)], "#d9d0bc")
    pal.flood(FLOOD, 1.0)
    pal_m = pal.finish()
    bm = bmesh.new()
    box(bm, -92.0, 82.0, 0.0, 16.0, 0.0, 21.6)
    box(bm, -12.0, 12.0, -1.5, 16.0, 0.0, 24.0)                         # central risalit
    make(rig, "vp_palace", bm, pal_m)
    cu = copper("vp_copper", flood=0.6, color="#5b8e7c", color2="#456f61")
    cu_m = cu.finish()
    bm = bmesh.new()
    gable_roof(bm, -92.4, 82.4, -0.4, 16.4, 21.6, 28.0, axis="x", hip=4.0)
    gable_roof(bm, -12.4, 12.4, -1.9, 16.4, 24.0, 30.0, axis="x", hip=3.0)
    make(rig, "vp_roofs", bm, cu_m)
    # cathedral roofs: dark, weathered copper
    dk_m = copper("vp_dark", flood=0.5, color="#3f5953", color2="#2f433e").finish()
    bm = bmesh.new()
    gable_roof(bm, -60.0, 66.0, 40.0, 70.0, 33.0, 56.0, axis="x", hip=10.0)
    gable_roof(bm, 6.0, 24.0, 30.0, 80.0, 33.0, 54.0, axis="y", hip=0.0)
    make(rig, "vp_cathedral_roof", bm, dk_m)
    ss = Shade("vp_stone", "#8f8a80", rough=0.85, spec=0.25, noise=0.1, nscale=0.25, color2="#6e6a62")
    ss.grid("front", (-60.0, 70.0), (8.0, 30.0), (8.0, 30.0), (3.6, 18.0), lit=0.2, glass="#2a2d31", pointed=True,
            color="#ffd29a", strength=0.8)
    ss.grid("left", (-70.0, -40.0), (35.0, 50.0), (30.0, 20.0), (9.0, 9.0), lit=0.0, glass="#2a2d31", pointed=True,
            seed=1)
    ss.flood(FLOOD, 1.35, grad=(0.0, 96.0, 0.8))
    ss_m = ss.finish()
    bm = bmesh.new()
    prism(bm, [(-60.0, 40.0), (58.0, 40.0), (66.0, 47.0), (66.0, 63.0), (58.0, 70.0), (-60.0, 70.0)], 0.0, 33.0)
    box(bm, 6.0, 24.0, 30.0, 80.0, 0.0, 33.0)                           # transept
    gable_xz(bm, [(6.0, 33.0), (24.0, 33.0), (15.0, 50.0)], 29.6, 0.6)
    for x in range(-52, 64, 9):                                           # buttresses + pinnacles
        box(bm, x - 0.9, x + 0.9, 37.0, 40.0, 0.0, 30.0)
        pinnacle(bm, x, 38.4, 30.0, 1.2, 8.0)
        beam(bm, (x, 38.4, 30.0), (x, 41.0, 36.0), 0.6, 0.9)              # flying buttress stub
    for y in (44.0, 66.0):                                                # west spires
        box(bm, -66.0, -58.0, y - 4.0, y + 4.0, 0.0, 52.0)
        pinnacle(bm, -66.0, y - 4.0, 52.0, 1.2, 6.0)
        pinnacle(bm, -58.0, y - 4.0, 52.0, 1.2, 6.0)
        pinnacle(bm, -66.0, y + 4.0, 52.0, 1.2, 6.0)
        pinnacle(bm, -58.0, y + 4.0, 52.0, 1.2, 6.0)
        pyramid(bm, octagon(-62.0, y, 3.4), 52.0, (-62.0, y, 82.0))
    # great south tower: gothic stone shaft
    tx, ty = 14.0, 33.0
    box(bm, tx - 7.5, tx + 7.5, ty - 7.5, ty + 7.5, 0.0, 56.0)
    for ddx in (-1, 1):
        for ddy in (-1, 1):
            pinnacle(bm, tx + ddx * 7.0, ty + ddy * 7.0, 56.0, 1.4, 6.0)
    make(rig, "vp_cathedral", bm, ss_m)
    # renaissance gallery + baroque helmet (green copper) of the south tower
    helm = copper("vp_helmet", flood=0.7)
    bm = bmesh.new()
    lathe(bm, [(7.0, 56.0), (7.0, 58.6), (6.2, 59.2), (0.0, 59.2)], 8, tx, ty, math.pi / 8)
    lathe(bm, [(5.6, 59.2), (6.3, 62.0), (6.0, 65.0), (4.2, 68.0), (2.6, 69.4), (2.6, 74.0), (3.8, 75.6),
               (3.6, 78.4), (2.0, 80.6), (1.3, 81.4), (1.3, 85.0), (2.0, 86.2), (1.6, 88.4), (0.7, 90.0),
               (0.3, 94.0), (0.0, 94.5)], 12, tx, ty)
    make(rig, "vp_helmet", bm, helm.finish(), smooth=True, sharp=50.0)
    bm = MU.bm_sphere(0.6, center=(tx, ty, 94.6), subdiv=2)
    beam(bm, (tx, ty, 94.0), (tx, ty, 96.5), 0.2)
    make(rig, "vp_gold", bm, gold("vp_gold", flood=0.8))
    return dict(object=obj_size(174.0, 96.5, 80.0))


# --- Warsaw: Palace of Culture and Science ---------------------------------------------------------

def kulturpalast_warschau(rig, p):
    """Palace of Culture and Science (1955): socialist-classicist 'wedding cake' tower with stepped
    setbacks, vertical pilasters, decorative attics with pinnacles at every stage, clocks and the spire
    (237 m); wide wings at its foot. Beige ceramic cladding, floodlit at night."""
    yc = 45.0
    st = Shade("kp_stone", "#ddd2b8", rough=0.8, spec=0.3, noise=0.05, nscale=0.3)
    nb = st.nb
    u = nb.madd(st.x, nb.absf(st.ny), nb.mul(st.y, nb.absf(st.nx)))
    rib = nb.AND(nb.lt(nb.math("FLOORED_MODULO", u, 3.0), 0.9), st.vert)
    st.grid("any", (-400.0, 400.0), (4.0, 160.0), (3.0, 3.6), (1.5, 2.2), lit=0.22, glass="#3a3e42",
            color="#ffe2b0", strength=0.75)
    st.paint(rib, "#c8bb9f")
    st.flood(FLOOD_WHITE, 0.85, grad=(0.0, 237.0, 0.7))
    st_m = st.finish()
    bm = bmesh.new()
    box(bm, -95.0, 95.0, yc - 25.0, yc + 25.0, 0.0, 20.0)               # wings
    box(bm, -40.0, 40.0, yc - 34.0, yc + 34.0, 0.0, 34.0)               # podium
    stages = [(28.0, 34.0, 62.0), (23.0, 62.0, 104.0), (17.0, 104.0, 120.0), (12.0, 120.0, 140.0),
              (8.0, 140.0, 160.0), (5.0, 160.0, 175.0)]
    for (hw, z0, z1) in stages:
        box(bm, -hw, hw, yc - hw, yc + hw, z0, z1)
        # corner piers rising above every stage + attic pinnacles along the edges
        for ddx in (-1, 1):
            for ddy in (-1, 1):
                pinnacle(bm, ddx * (hw - 0.8), yc + ddy * (hw - 0.8), z1, min(2.6, hw * 0.18), 4.0 + hw * 0.18,
                         top=0.5)
        nps = max(2, int(2 * hw / 5.5))
        for i in range(1, nps):
            t = -hw + 2 * hw * i / nps
            for (px, py) in ((t, yc - hw + 0.4), (t, yc + hw - 0.4), (-hw + 0.4, yc + t), (hw - 0.4, yc + t)):
                pinnacle(bm, px, py, z1, 0.9, 3.0, top=0.5)
    for (hw, z1) in ((40.0, 34.0), (95.0, 20.0)):
        for i in range(0, int(2 * hw / 6.0) + 1):
            x = -hw + i * 6.0
            pinnacle(bm, x, yc - (34.0 if hw == 40.0 else 25.0) + 0.4, z1, 0.9, 2.6, top=0.5)
    pyramid(bm, rect(0.0, yc, 10.0, 10.0), 175.0, (0.0, yc, 186.0))
    make(rig, "kp_body", bm, st_m)
    # clocks on the 150 m stage and the spire
    dial = Shade("kp_dial", "#f1ece0", rough=0.4, spec=0.4, noise=0.0)
    dial.glow(None, "#fff4dc", 0.7)
    bm = bmesh.new()
    for (nx, ny) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        MU.bm_cyl(3.2, 3.2, 0.4, center=(nx * 8.1, yc + ny * 8.1, 151.0), axis="Y" if ny else "X", segs=24, bm=bm)
    make(rig, "kp_dials", bm, dial.finish())
    sp = Shade("kp_spire", "#d3c7ac", rough=0.6, spec=0.4, metal=0.3, noise=0.03)
    sp.flood(FLOOD_WHITE, 1.0)
    bm = bmesh.new()
    lathe(bm, [(2.4, 186.0), (1.8, 200.0), (1.2, 215.0), (0.7, 228.0), (0.3, 236.0), (0.0, 237.0)], 8, 0.0, yc)
    make(rig, "kp_spire", bm, sp.finish())
    bm = MU.bm_sphere(0.6, center=(0.0, yc, 237.2), subdiv=1)
    make(rig, "kp_red", bm, lamp("kp_red", RED_LIGHT, 1.0, base="#b8322a"))
    return dict(object=obj_size(190.0, 237.0, 68.0))


# --- Sofia: Alexander Nevsky Cathedral ---------------------------------------------------------

def nevsky_kathedrale(rig, p):
    """Patriarchal Cathedral St. Alexander Nevsky (1912): neo-byzantine cross-in-square, gilded main
    dome on a high drum (45 m, cross 46.3 m), green copper half-domes and small domes, arcaded porch and
    the bell tower with its gilded dome (53 m). 72 m long, 55 m wide."""
    yc = 34.0
    st = Shade("an_stone", "#e6e0d2", rough=0.8, spec=0.3, noise=0.05)
    kw = dict(glass="#2b2f33", arch=True, color="#ffd49a", strength=0.85, frame="#bfae92", frame_w=0.3)
    st.grid("front", (-27.0, 27.0), (6.0, 13.0), (4.6, 10.0), (2.0, 5.8), lit=0.3, **kw)
    st.grid("left", (-70.0, 0.0), (6.0, 13.0), (4.6, 10.0), (2.0, 5.8), lit=0.3, seed=1, **kw)
    st.grid("round", (-400.0, 400.0), (24.5, 31.0), (3.2, 8.0), (1.5, 5.0), lit=0.5, cx=0.0, cy=yc, r=9.0, seed=2, **kw)
    st.bands([(15.4, 16.2)], "#c7b18f")
    st.flood(FLOOD, 1.2)
    st_m = st.finish()
    cu = copper("an_copper", flood=0.7, color="#5f9e86", color2="#4a8270")
    cu_m = cu.finish()
    gd_m = gold("an_gold", flood=0.75)
    bm = bmesh.new()
    bmc = bmesh.new()
    bmg = bmesh.new()
    # cross-in-square body, arms with half domes, apse
    box(bm, -16.0, 16.0, yc - 16.0, yc + 16.0, 0.0, 22.0)
    for (x0, x1, y0, y1) in ((-27.5, 27.5, yc - 10.0, yc + 10.0), (-10.0, 10.0, 8.0, yc + 30.0)):
        box(bm, x0, x1, y0, y1, 0.0, 17.0)
    for (cx, cy) in ((-18.0, yc), (18.0, yc), (0.0, yc + 21.0)):          # domes over the three arms
        lathe(bmc, dome_profile(9.5, 8.0, "dome", 8, z0=17.0), 24, cx, cy)
    lathe(bm, [(10.0, 0.0), (10.0, 17.0), (0.0, 17.0)], 24, 0.0, yc + 30.0)     # apse
    gable_roof(bmc, -27.5, 27.5, yc - 10.5, yc + 10.5, 17.0, 23.0, axis="x")
    gable_roof(bmc, -10.5, 10.5, 8.0, yc + 30.0, 17.0, 23.0, axis="y")
    # porch with arcade
    box(bm, -14.0, 14.0, 2.0, 8.0, 0.0, 11.0)
    gable_roof(bmc, -14.4, 14.4, 1.6, 8.4, 11.0, 14.0, axis="x")
    # small domes at the corners of the square
    for (dx, dy) in ((-11.5, -11.5), (11.5, -11.5), (-11.5, 11.5), (11.5, 11.5)):
        lathe(bm, [(4.0, 22.0), (4.0, 27.0), (0.0, 27.0)], 12, dx, yc + dy)
        lathe(bmc, dome_profile(4.2, 4.2, "dome", 8, z0=27.0), 16, dx, yc + dy)
        lathe(bmg, [(0.6, 31.0), (0.6, 32.0), (0.0, 33.2)], 8, dx, yc + dy)
    # main drum and gilded dome
    lathe(bm, [(10.5, 22.0), (10.5, 23.4), (9.4, 23.6), (9.4, 32.6), (10.0, 33.2), (0.0, 33.2)], 24, 0.0, yc)
    lathe(bmg, dome_profile(9.6, 10.4, "dome", 14, z0=33.2), 32, 0.0, yc)
    lathe(bmg, [(1.0, 43.4), (1.0, 44.4), (0.0, 44.6)], 10, 0.0, yc)
    beam(bmg, (0.0, yc, 44.0), (0.0, yc, 46.3), 0.3)
    beam(bmg, (-0.9, yc, 45.6), (0.9, yc, 45.6), 0.25)
    # bell tower at the west front with arched belfry and gilded dome
    bx, by = 0.0, 3.0
    box(bm, bx - 5.5, bx + 5.5, by - 5.5, by + 5.5, 0.0, 33.0)
    lathe(bm, [(5.0, 33.0), (5.0, 39.5), (5.6, 40.0), (0.0, 40.0)], 16, bx, by)
    lathe(bmg, dome_profile(5.0, 6.8, "onion", 12, z0=40.0), 24, bx, by)
    lathe(bmg, [(0.7, 46.6), (0.7, 48.6), (0.0, 49.6)], 8, bx, by)
    beam(bmg, (bx, by, 48.0), (bx, by, 53.0), 0.32)
    beam(bmg, (bx - 1.1, by, 51.8), (bx + 1.1, by, 51.8), 0.28)
    make(rig, "an_stone", bm, st_m)
    make(rig, "an_copper", bmc, cu_m, smooth=True, sharp=40.0)
    make(rig, "an_gold", bmg, gd_m, smooth=True, sharp=40.0)
    # belfry openings (dark arches)
    op = plain("an_open", "#26292c", rough=0.6, glow=("#ffd49a", 0.2))
    bm = bmesh.new()
    for (nx, ny) in ((0, -1), (-1, 0), (1, 0)):
        for k in (-1, 1):
            t = Vector((-ny, nx, 0.0))
            c = Vector((bx + nx * 5.52, by + ny * 5.52, 0.0)) + t * (k * 2.1)
            v = [bm.verts.new(c + t * d + Vector((0, 0, z))) for (d, z) in
                 ((-1.0, 24.0), (1.0, 24.0), (1.0, 29.5), (0.6, 30.4), (0.0, 30.7), (-0.6, 30.4), (-1.0, 29.5))]
            bm.faces.new(v)
    make(rig, "an_open", bm, op)
    return dict(object=obj_size(55.0, 53.0, 72.0))


# --- optional landmarks ------------------------------------------------------------------------------

def frankfurt_skyline(rig, p):
    """Frankfurt's banking district as one skyline group (moved closer together, as seen from the motorway):
    Westend Tower with its crown (208 m), Messeturm with the pyramid (257 m), Trianon (186 m), the
    Deutsche Bank twins (155 m), Main Tower with its antenna (240 m) and Commerzbank Tower (259 m, mast
    300 m). Office windows lit at night, aviation lights."""
    def curtain(name, glass, band, pu=3.0, pz=3.8, lit=0.2, metal=0.4, rough=0.08, spec=0.9, warm="#fff0d6",
                frame_z=0.9, frame_u=0.3, round_c=None):
        s = Shade(name, glass, rough=rough, spec=spec, metal=metal, noise=0.03)
        nb = s.nb
        if round_c is None:
            u = nb.madd(s.x, nb.mul(s.ny, -1.0), nb.mul(s.y, s.nx))
        else:                    # cylinder: arc length (a planar u would alias with the curving normal)
            u = nb.mul(nb.math("ARCTAN2", nb.sub(s.y, round_c[1]), nb.sub(s.x, round_c[0])), round_c[2])
        fz = nb.math("FLOORED_MODULO", s.z, pz)
        fu = nb.math("FLOORED_MODULO", u, pu)
        frame = nb.OR(nb.lt(fz, frame_z), nb.lt(fu, frame_u))
        s.paint(frame, band, 0.5, 0.4, 0.2)
        salt = nb.add(nb.mul(s.nx, 3.0), nb.mul(s.ny, 5.0)) if round_c is None else 2.0   # per facade / constant
        v, r2, _r3 = _cell_noise(nb, u, s.z, pu, pz, salt)
        on = nb.AND(nb.NOT(frame), nb.lt(v, lit), s.vert, nb.gt(s.z, 6.0))
        s.add_emit(nb.color_scale(nb.color_scale(M.emit_col(warm, 0.5), nb.madd(r2, 0.6, 0.5)), on))
        return s

    red = lamp("ff_red", RED_LIGHT, 1.0, base="#b8322a")
    bm_red = bmesh.new()
    # Westend Tower (Kronenhochhaus): light stone, punched windows, the crown of curved fins
    s = Shade("ff_westend", "#dcd7cc", rough=0.7, spec=0.4, noise=0.03)
    s.grid("any", (-400.0, 400.0), (6.0, 176.0), (3.0, 3.7), (1.8, 2.4), lit=0.2, glass="#41505c", color="#fff0d6",
           strength=0.5)
    s.flood(FLOOD_WHITE, 0.25)
    bm = bmesh.new()
    wx, wy = -136.0, 40.0
    lathe(bm, [(17.0, 0.0), (17.0, 178.0), (15.6, 179.0), (0.0, 179.0)], 8, wx, wy, math.pi / 8)
    make(rig, "ff_westend", bm, s.finish())
    crown = Shade("ff_crown", "#e9e6de", rough=0.4, spec=0.5, metal=0.3, noise=0.0)
    crown.glow(None, "#fff3d8", 0.75)
    bm = bmesh.new()
    for k in range(24):
        a = 2 * math.pi * k / 24
        pts = [(10.4, 178.0), (11.6, 188.0), (12.8, 198.0), (13.5, 208.0)]
        for (r0, z0), (r1, z1) in zip(pts[:-1], pts[1:]):
            beam(bm, (wx + r0 * math.cos(a), wy + r0 * math.sin(a), z0), (wx + r1 * math.cos(a), wy + r1 * math.sin(a), z1),
                 0.9, 0.5)
    lathe(bm, [(13.6, 206.8), (13.6, 208.0), (12.9, 208.0), (12.9, 206.8)], 24, wx, wy)
    make(rig, "ff_crown", bm, crown.finish())
    # Messeturm: red granite with blue window strips, cylinder top, glass pyramid
    s = Shade("ff_messe", "#a9665a", rough=0.5, spec=0.5, noise=0.04)
    nb = s.nb
    u = nb.madd(s.x, nb.mul(s.ny, -1.0), nb.mul(s.y, s.nx))
    strip = nb.AND(nb.lt(nb.math("FLOORED_MODULO", u, 3.4), 1.9), s.vert, nb.gt(s.z, 8.0),
                   nb.lt(nb.math("FLOORED_MODULO", s.z, 3.7), 2.6))
    s.paint(strip, "#2e4258", 0.1, 0.9, 0.3)
    v, r2, _r3 = _cell_noise(nb, u, s.z, 3.4, 3.7, 1.0)
    s.add_emit(nb.color_scale(M.emit_col("#fff0d6", 0.5), nb.mul(strip, nb.lt(v, 0.2))))
    s.flood(FLOOD, 0.35)
    mx, my = -84.0, 2.5
    bm = bmesh.new()
    notch = [(-18.0, -14.5), (-14.5, -18.0), (14.5, -18.0), (18.0, -14.5), (18.0, 14.5), (14.5, 18.0),
             (-14.5, 18.0), (-18.0, 14.5)]
    prism(bm, [(mx + a, my + 20.5 + b) for (a, b) in notch], 0.0, 214.0)
    lathe(bm, [(14.5, 214.0), (14.5, 222.0), (0.0, 222.0)], 24, mx, my + 20.5)
    make(rig, "ff_messe", bm, s.finish())
    pyr = Shade("ff_pyramid", "#c9ced2", rough=0.25, spec=0.7, metal=0.6, noise=0.0)
    pyr.glow(None, "#fff4e0", 0.6)
    bm = bmesh.new()
    pyramid(bm, rect(mx, my + 20.5, 24.6, 24.6), 222.0, (mx, my + 20.5, 257.0))
    make(rig, "ff_pyramid", bm, pyr.finish())
    MU.bm_sphere(0.6, center=(mx, my + 20.5, 257.3), subdiv=1, bm=bm_red)
    # Trianon: rotated square shaft, the inverted-pyramid top
    s = curtain("ff_trianon", "#3f5a66", "#c6ccd0")
    s.flood(FLOOD_WHITE, 0.2)
    tx, ty = -34.0, 56.0
    sq = [(tx + 15.0 * math.cos(a), ty + 15.0 * math.sin(a)) for a in (0.0, math.pi / 2, math.pi, 1.5 * math.pi)]
    sq2 = [(tx + 21.0 * math.cos(a), ty + 21.0 * math.sin(a)) for a in (0.0, math.pi / 2, math.pi, 1.5 * math.pi)]
    bm = bmesh.new()
    prism(bm, sq, 0.0, 160.0)
    frustum(bm, sq, 160.0, sq2, 182.0)
    prism(bm, sq2, 182.0, 186.0)
    make(rig, "ff_trianon", bm, s.finish())
    # Deutsche Bank twins: mirrored blue-grey glass, silver lines
    s = curtain("ff_twins", "#4a6378", "#c3cbd2")
    s.flood(FLOOD_WHITE, 0.15)
    bm = bmesh.new()
    for (cx, cy, rot) in ((4.0, 30.0, 0.35), (30.0, 50.0, 0.35)):
        pts = [(cx + 16.0 * math.cos(rot + a), cy + 16.0 * math.sin(rot + a)) for a in
               (math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4)]
        prism(bm, pts, 0.0, 155.0)
    box(bm, -4.0, 38.0, 24.0, 56.0, 0.0, 18.0)
    make(rig, "ff_twins", bm, s.finish())
    # Main Tower: blue glass cylinder + stone-clad block, red/white antenna
    s = curtain("ff_main", "#3c6688", "#a9b8c4", round_c=(78.0, 24.0, 18.0))
    s.flood(FLOOD_WHITE, 0.15)
    bm = bmesh.new()
    lathe(bm, [(18.0, 0.0), (18.0, 200.0), (0.0, 200.0)], 40, 78.0, 24.0)
    make(rig, "ff_main", bm, s.finish(), smooth=True, sharp=30.0)
    s = Shade("ff_main_block", "#cfc8b9", rough=0.7, spec=0.4, noise=0.03)
    s.grid("any", (-400.0, 400.0), (6.0, 168.0), (3.0, 3.7), (1.8, 2.5), lit=0.2, glass="#3d4a55", color="#fff0d6",
           strength=0.5)
    s.flood(FLOOD_WHITE, 0.25)
    bm = bmesh.new()
    box(bm, 82.0, 102.0, 28.0, 48.0, 0.0, 170.0)
    make(rig, "ff_main_block", bm, s.finish())
    ant = Shade("ff_antenna", "#ece9e2", rough=0.45, spec=0.4, noise=0.0)
    nb = ant.nb
    ant.paint(nb.lt(nb.math("FLOORED_MODULO", ant.z, 8.0), 4.0), "#c4372e")
    bm = bmesh.new()
    lathe(bm, [(1.4, 200.0), (1.0, 220.0), (0.6, 236.0), (0.0, 240.0)], 10, 78.0, 24.0)
    lathe(bm, [(1.0, 255.0), (0.9, 275.0), (0.5, 295.0), (0.0, 300.0)], 10, 134.0, 52.0)
    make(rig, "ff_antenna", bm, ant.finish())
    MU.bm_sphere(0.55, center=(78.0, 24.0, 240.3), subdiv=1, bm=bm_red)
    MU.bm_sphere(0.55, center=(134.0, 52.0, 300.3), subdiv=1, bm=bm_red)
    # Commerzbank Tower: rounded triangle, light grey, sky-garden recesses, corner shafts + mast
    s = curtain("ff_commerz", "#7b8e9b", "#d6d9dc")
    nb = s.nb
    garden = nb.AND(nb.lt(nb.math("FLOORED_MODULO", s.z, 45.6), 7.6), nb.gt(s.z, 20.0), nb.lt(s.ny, -0.3))
    s.paint(garden, "#66786a", 0.6, 0.3, 0.0)
    s.flood(FLOOD_WHITE, 0.15)
    cx, cy = 134.0, 52.0
    tri = []
    for k in range(3):
        a0 = -math.pi / 2 + 2 * math.pi * k / 3
        for j in range(5):
            a = a0 - math.radians(40.0) + math.radians(80.0) * j / 4
            tri.append((cx + 30.0 * math.cos(a0) + 4.0 * math.cos(a), cy + 30.0 * math.sin(a0) + 4.0 * math.sin(a)))
    tri = ray_poly(tri, 48, cx, cy, 0.0, 1.0)
    bm = bmesh.new()
    prism(bm, tri, 0.0, 246.0)
    make(rig, "ff_commerz", bm, s.finish())
    top = Shade("ff_commerz_top", "#e3e5e6", rough=0.4, spec=0.5, metal=0.3, noise=0.0)
    top.glow(None, "#ffe08a", 0.65)
    bm = bmesh.new()
    for k in range(3):
        a0 = -math.pi / 2 + 2 * math.pi * k / 3
        x, y = cx + 26.5 * math.cos(a0), cy + 26.5 * math.sin(a0)
        box(bm, x - 2.0, x + 2.0, y - 2.0, y + 2.0, 246.0, 259.0)
        beam(bm, (x, y, 258.0), (cx, cy, 258.0), 1.2)
    box(bm, cx - 2.5, cx + 2.5, cy - 2.5, cy + 2.5, 246.0, 256.0)
    make(rig, "ff_commerz_top", bm, top.finish())
    MU.bm_sphere(0.5, center=(wx, wy, 208.6), subdiv=1, bm=bm_red)
    make(rig, "ff_red", bm_red, red)
    return dict(object=obj_size(320.0, 300.0, 80.0))


def kaiserburg_nuernberg(rig, p):
    """Imperial Castle of Nuremberg on its sandstone rock above the old town: Palas and the double chapel
    with the square Heidenturm, the round Sinwell Tower with its half-timbered top, the long Kaiserstallung
    with the Luginsland tower; red sandstone, steep red tiled roofs, floodlit at night."""
    rock = Shade("kb_rock", "#8a7663", rough=0.95, spec=0.2, color2="#665747", nscale=0.25)
    rock.flood(FLOOD, 0.7)
    bm = bmesh.new()
    front = [(-78.0, 4.0), (-60.0, 1.0), (-38.0, 3.5), (-20.0, 0.0), (0.0, 2.5), (22.0, 0.5), (44.0, 3.0),
             (62.0, 1.0), (80.0, 4.0)]
    outline = front + [(80.0, 46.0), (-78.0, 46.0)]
    prism(bm, outline, 0.0, 15.0)
    make(rig, "kb_rock", bm, rock.finish())
    ss = Shade("kb_stone", "#b98f6c", rough=0.85, spec=0.25, color2="#9c7457", nscale=0.6)
    kw = dict(lit=0.3, glass="#2c2a28", color="#ffd49a", strength=0.85)
    ss.grid("front", (-62.0, -22.0), (19.0, 29.0), (3.6, 5.0), (1.4, 2.4), **kw)
    ss.grid("front", (22.0, 68.0), (17.0, 25.0), (3.0, 4.2), (1.0, 1.6), seed=1, **kw)
    ss.grid("left", (-46.0, -2.0), (19.0, 29.0), (3.6, 5.0), (1.4, 2.4), seed=2, **kw)
    ss.flood(FLOOD, 1.0, grad=(15.0, 65.0, 0.75))
    bm = bmesh.new()
    box(bm, -76.0, 78.0, 4.0, 7.0, 15.0, 20.0)                            # curtain wall
    for i in range(52):
        x = -75.0 + i * 3.0
        box(bm, x - 0.6, x + 0.6, 4.0, 5.0, 20.0, 21.2)
    box(bm, -62.0, -22.0, 6.0, 22.0, 15.0, 31.0)                          # Palas
    box(bm, -20.0, -8.0, 7.0, 18.0, 15.0, 36.0)                           # double chapel
    box(bm, -19.0, -11.0, 7.5, 15.5, 36.0, 49.0)                          # Heidenturm
    lathe(bm, [(6.2, 15.0), (6.2, 44.0), (0.0, 44.0)], 20, 6.0, 16.0)     # Sinwell Tower
    box(bm, 22.0, 70.0, 6.0, 18.0, 15.0, 27.0)                            # Kaiserstallung
    box(bm, 63.0, 72.0, 7.0, 16.0, 15.0, 47.0)                            # Luginsland
    make(rig, "kb_stone", bm, ss.finish())
    ht = Shade("kb_timber", "#ece4d3", rough=0.8, spec=0.25, noise=0.03)
    nb = ht.nb
    ang = nb.math("ARCTAN2", nb.sub(ht.y, 16.0), nb.sub(ht.x, 6.0))
    post = nb.lt(nb.math("FLOORED_MODULO", nb.mul(ang, 6.5), 1.0), 0.18)
    rail = nb.lt(nb.math("FLOORED_MODULO", ht.z, 3.0), 0.35)
    ht.paint(nb.OR(post, rail), "#4a3022", 0.7)
    ht.flood(FLOOD, 0.9)
    bm = bmesh.new()
    lathe(bm, [(6.9, 44.0), (6.9, 50.0), (0.0, 50.0)], 20, 6.0, 16.0)
    make(rig, "kb_timber", bm, ht.finish())
    rf = Shade("kb_roof", "#9a3f2c", rough=0.75, spec=0.3, color2="#7e3324", nscale=0.6)
    rf.flood(FLOOD, 0.5)
    bm = bmesh.new()
    gable_roof(bm, -62.6, -21.4, 5.4, 22.6, 31.0, 44.0, axis="x")
    gable_roof(bm, -20.6, -7.4, 6.4, 18.6, 36.0, 45.0, axis="y")
    pyramid(bm, rect(-15.0, 11.5, 9.0, 9.0), 49.0, (-15.0, 11.5, 55.0))
    lathe(bm, [(7.3, 50.0), (0.0, 66.0)], 20, 6.0, 16.0)
    gable_roof(bm, 21.4, 70.6, 5.4, 18.6, 27.0, 40.0, axis="x")
    gable_roof(bm, 62.4, 72.6, 6.4, 16.6, 47.0, 56.0, axis="x", hip=2.5)
    for i in range(6):                                                    # dormers on the Kaiserstallung
        x = 26.0 + i * 6.5
        gable_roof(bm, x - 1.2, x + 1.2, 7.4, 10.0, 31.0, 33.6, axis="y")
    make(rig, "kb_roof", bm, rf.finish())
    return dict(object=obj_size(158.0, 66.0, 46.0))


def st_petri_riga(rig, p):
    """St. Peter's Church, Riga: gothic brick hall church with the 123 m baroque tower - brick shaft, dark
    copper spire with two open galleries, bulbs and the long needle with the golden rooster."""
    br = Shade("sp_brick", "#8e4636", rough=0.85, spec=0.25, color2="#743829", nscale=0.8)
    kw = dict(lit=0.2, glass="#2a2c2e", pointed=True, color="#ffd49a", strength=0.85)
    br.grid("front", (-16.0, 44.0), (5.0, 21.0), (6.4, 20.0), (2.6, 14.0), **kw)
    br.grid("front", (-31.0, -17.0), (24.0, 52.0), (7.0, 14.0), (2.0, 9.0), lit=0.0, glass="#2a2c2e", pointed=True)
    br.grid("left", (-15.0, -1.0), (24.0, 52.0), (7.0, 14.0), (2.0, 9.0), lit=0.0, glass="#2a2c2e", pointed=True,
            seed=1)
    br.flood(FLOOD, 1.1, grad=(0.0, 60.0, 0.8))
    tx, ty = -24.0, 8.0
    bm = bmesh.new()
    box(bm, tx - 7.0, tx + 7.0, ty - 7.0, ty + 7.0, 0.0, 58.0)
    for ddx in (-1, 1):
        for ddy in (-1, 1):
            box(bm, tx + ddx * 6.6 - 0.8, tx + ddx * 6.6 + 0.8, ty + ddy * 6.6 - 0.8, ty + ddy * 6.6 + 0.8, 0.0, 56.0)
    prism(bm, [(-17.0, 2.0), (34.0, 2.0), (44.0, 9.0), (44.0, 23.0), (34.0, 30.0), (-17.0, 30.0)], 0.0, 24.0)
    make(rig, "sp_brick", bm, br.finish())
    rf = Shade("sp_roof", "#3f4f4b", rough=0.6, spec=0.35, color2="#33413e", nscale=0.6)
    rf.flood(FLOOD_WHITE, 0.45)
    bm = bmesh.new()
    gable_roof(bm, -17.0, 34.5, 1.4, 30.6, 24.0, 44.0, axis="x")
    pyramid(bm, [(34.0, 1.4), (44.6, 8.6), (44.6, 23.4), (34.0, 30.6)], 24.0, (34.0, 16.0, 44.0))
    make(rig, "sp_roof", bm, rf.finish())
    cu = copper("sp_spire", flood=0.6, color="#4f6d63", color2="#3e5850")
    cu.grid("round", (-200.0, 200.0), (63.5, 70.5), (2.6, 8.0), (1.3, 5.6), lit=0.5, glass="#1d2422", arch=True,
            cx=tx, cy=ty, r=5.0, color="#ffd28a", strength=0.8)
    cu.grid("round", (-200.0, 200.0), (79.5, 85.0), (1.9, 7.0), (0.9, 4.4), lit=0.5, glass="#1d2422", arch=True,
            cx=tx, cy=ty, r=2.6, color="#ffd28a", strength=0.8, seed=1)
    bm = bmesh.new()
    frustum(bm, rect(tx, ty, 14.0, 14.0), 58.0, rect(tx, ty, 10.0, 10.0), 62.0)
    lathe(bm, [(5.4, 62.0), (5.4, 71.6), (6.4, 72.0), (6.4, 72.6), (0.0, 72.6)], 8, tx, ty, math.pi / 8)
    lathe(bm, [(4.8, 72.6), (5.0, 74.0), (4.4, 76.0), (3.0, 77.6), (2.7, 78.4), (0.0, 78.4)], 16, tx, ty)
    lathe(bm, [(2.7, 78.4), (2.7, 85.6), (3.6, 86.0), (3.6, 86.5), (0.0, 86.5)], 8, tx, ty, math.pi / 8)
    lathe(bm, [(2.4, 86.5), (2.6, 87.6), (2.0, 89.2), (1.1, 90.4), (0.9, 91.0), (0.0, 91.0)], 16, tx, ty)
    lathe(bm, [(0.95, 91.0), (0.7, 100.0), (0.4, 112.0), (0.15, 121.0), (0.0, 121.2)], 12, tx, ty)
    for (r, z) in ((6.3, 72.6), (3.5, 86.5)):                             # gallery railings
        for k in range(24):
            a = 2 * math.pi * k / 24
            box(bm, tx + r * math.cos(a) - 0.08, tx + r * math.cos(a) + 0.08, ty + r * math.sin(a) - 0.08,
                ty + r * math.sin(a) + 0.08, z, z + 1.1)
    make(rig, "sp_spire", bm, cu.finish())
    bm = MU.bm_sphere(0.65, center=(tx, ty, 121.4), subdiv=2)
    MU.bm_box(1.5, 0.25, 1.3, (tx, ty, 122.6), bm=bm)
    make(rig, "sp_rooster", bm, gold("sp_gold", flood=0.8))
    return dict(object=obj_size(75.0, 123.25, 30.0))


def freiheitsdenkmal_riga(rig, p):
    """Freedom Monument, Riga (1935, 42 m): stepped red granite base with sculpture groups, the travertine
    column and the copper figure of Liberty ('Milda') holding up three gilded stars."""
    gr = Shade("fd_granite", "#8c5a4c", rough=0.6, spec=0.4, noise=0.06)
    gr.flood(FLOOD, 0.9)
    tr = Shade("fd_travertine", "#d9cfb7", rough=0.75, spec=0.3, noise=0.05)
    nb = tr.nb
    tr.paint(nb.AND(nb.band(tr.z, 15.0, 17.5), tr.vert), "#bfb399")
    tr.flood(FLOOD_WHITE, 1.1)
    bm = bmesh.new()
    box(bm, -9.0, 9.0, 0.0, 18.0, 0.0, 1.2)
    box(bm, -7.5, 7.5, 1.5, 16.5, 1.2, 2.4)
    box(bm, -5.5, 5.5, 3.5, 14.5, 2.4, 9.0)
    for (x, y) in ((-6.4, 4.6), (6.4, 4.6), (-6.4, 13.4), (6.4, 13.4)):      # sculpture groups
        box(bm, x - 1.6, x + 1.6, y - 1.6, y + 1.6, 2.4, 7.4)
    make(rig, "fd_granite", bm, gr.finish())
    bm = bmesh.new()
    frustum(bm, rect(0.0, 9.0, 6.2, 4.6), 9.0, rect(0.0, 9.0, 4.4, 3.2), 32.0)
    box(bm, -2.6, 2.6, 7.0, 11.0, 32.0, 33.0)
    make(rig, "fd_column", bm, tr.finish())
    cu_m = copper("fd_milda", flood=0.8).finish()
    bm = bmesh.new()
    lathe(bm, [(1.2, 33.0), (1.0, 36.0), (0.75, 38.5), (0.55, 39.4), (0.0, 39.6)], 10, 0.0, 9.0)
    MU.bm_sphere(0.45, center=(0.0, 9.0, 40.0), subdiv=1, bm=bm)
    beam(bm, (-0.4, 9.0, 39.0), (-0.9, 9.0, 41.3), 0.28)
    beam(bm, (0.4, 9.0, 39.0), (0.9, 9.0, 41.3), 0.28)
    beam(bm, (-0.9, 9.0, 41.2), (0.9, 9.0, 41.2), 0.25)
    make(rig, "fd_milda", bm, cu_m)
    bm = bmesh.new()
    for x in (-1.0, 0.0, 1.0):
        for k in range(5):
            a = math.pi / 2 + 2 * math.pi * k / 5
            beam(bm, (x, 9.0, 41.8), (x + 0.55 * math.cos(a), 9.0, 41.8 + 0.55 * math.sin(a)), 0.18, 0.12)
    make(rig, "fd_stars", bm, gold("fd_gold", flood=1.0))
    return dict(object=obj_size(18.0, 42.0, 18.0))


def kathedrale_burgos(rig, p):
    """Burgos Cathedral: white limestone gothic, west front with rose window and the two openwork spires
    (88 m), the octagonal crossing lantern (cimborrio) with its corner spires, the Constable's chapel."""
    st = Shade("bu_stone", "#e4ddcc", rough=0.8, spec=0.3, noise=0.06, color2="#d0c6b0", nscale=0.4)
    kw = dict(glass="#2d3034", pointed=True, color="#ffd49a", strength=0.85)
    st.grid("front", (-6.0, 6.0), (6.0, 18.0), (12.0, 20.0), (5.0, 11.0), lit=0.0, **kw)
    st.grid("left", (-104.0, -10.0), (6.0, 22.0), (8.5, 22.0), (3.4, 13.0), lit=0.2, seed=1, **kw)
    st.grid("front", (-15.5, 15.5), (24.0, 52.0), (4.0, 7.0), (1.4, 4.6), lit=0.0, seed=2, **kw)
    nb = st.nb
    rose = nb.AND(nb.lt(nb.add(nb.mul(st.x, st.x), nb.mul(nb.sub(st.z, 30.0), nb.sub(st.z, 30.0))), 16.0),
                  nb.lt(st.ny, -0.5))
    st.paint(rose, "#3a3836", 0.4)
    st.flood(FLOOD, 1.0, grad=(0.0, 88.0, 0.8))
    bm = bmesh.new()
    box(bm, -6.5, 6.5, 0.0, 10.0, 0.0, 42.0)                              # central front
    for sx in (-1, 1):
        cx = sx * 11.0
        box(bm, cx - 4.5, cx + 4.5, 0.0, 9.0, 0.0, 56.0)                  # towers
        for ddx in (-1, 1):
            for ddy in (0, 1):
                pinnacle(bm, cx + ddx * 4.1, ddy * 8.2 + 0.4, 56.0, 1.0, 9.0)
    for x in (-5.0, -2.5, 0.0, 2.5, 5.0):                                 # statue gallery
        pinnacle(bm, x, 0.4, 42.0, 0.7, 4.5)
    box(bm, -14.0, 14.0, 9.0, 106.0, 0.0, 26.0)                            # nave
    box(bm, -29.5, 29.5, 46.0, 62.0, 0.0, 24.0)                            # transept
    gable_roof(bm, -14.4, 14.4, 9.0, 106.0, 26.0, 33.0, axis="y")
    gable_roof(bm, -29.9, 29.9, 45.6, 62.4, 24.0, 30.0, axis="x")
    lathe(bm, [(9.0, 26.0), (9.0, 48.0), (9.6, 48.5), (9.6, 49.6), (0.0, 49.6)], 8, 0.0, 54.0, math.pi / 8)
    R8 = 1.0 / math.cos(math.pi / 8)
    for k in range(8):                                                     # cimborrio corner spires
        a = 2 * math.pi * k / 8 + math.pi / 8
        x, y = 9.2 * R8 * math.cos(a), 54.0 + 9.2 * R8 * math.sin(a)
        lathe(bm, [(1.3, 26.0), (1.3, 48.0), (0.0, 48.0)], 8, x, y, math.pi / 8)
        pyramid(bm, octagon(x, y, 1.2), 48.0, (x, y, 60.0))
    for k in range(8):
        a = 2 * math.pi * k / 8
        face_gable(bm, (8.7 * math.cos(a), 54.0 + 8.7 * math.sin(a)), a, 2.6, 49.6, 54.5)
    lathe(bm, [(7.0, 20.0), (7.0, 38.0), (0.0, 38.0)], 8, 0.0, 100.0, math.pi / 8)  # Constable's chapel
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        pinnacle(bm, 7.4 * R8 * math.cos(a), 100.0 + 7.4 * R8 * math.sin(a), 38.0, 1.0, 8.0)
    make(rig, "bu_stone", bm, st.finish())
    # openwork spires: octagonal pyramids with cut-out tracery
    sp = Shade("bu_spire", "#e2dbca", rough=0.8, spec=0.3, noise=0.05)
    nb = sp.nb
    u = nb.madd(sp.x, nb.mul(sp.ny, -1.0), nb.mul(sp.y, sp.nx))
    fu = nb.sub(nb.math("FLOORED_MODULO", u, 1.1), 0.55)
    fz = nb.sub(nb.math("FLOORED_MODULO", sp.z, 1.6), 0.8)
    hole = nb.AND(nb.lt(nb.add(nb.mul(fu, fu), nb.mul(fz, fz)), 0.13), nb.gt(sp.z, 59.0), nb.lt(sp.z, 85.0))
    sp.cut = hole
    sp.flood(FLOOD, 1.0, grad=(0.0, 88.0, 0.8))
    bm = bmesh.new()
    for sx in (-1, 1):
        cx = sx * 11.0
        pyramid(bm, octagon(cx, 4.5, 3.9), 56.0, (cx, 4.5, 86.5))
        beam(bm, (cx, 4.5, 86.0), (cx, 4.5, 88.0), 0.3)
    make(rig, "bu_spires", bm, sp.finish())
    return dict(object=obj_size(59.0, 88.0, 106.0))


def basilica_pilar(rig, p):
    """Basilica of Our Lady of the Pillar, Zaragoza: long baroque brick church on the Ebro (130 x 67 m),
    four corner towers (~92 m) and eleven domes covered with green, yellow, white and blue glazed tiles."""
    br = Shade("bp_brick", "#c2936a", rough=0.85, spec=0.25, color2="#a87a55", nscale=0.6)
    kw = dict(glass="#2e2b28", arch=True, color="#ffd49a", strength=0.85)
    br.grid("front", (-60.0, 60.0), (6.0, 25.0), (7.4, 24.0), (2.6, 9.0), lit=0.25, **kw)
    br.grid("left", (-62.0, -5.0), (6.0, 25.0), (7.4, 24.0), (2.6, 9.0), lit=0.25, seed=1, **kw)
    br.bands([(28.0, 30.0)], "#e2d3b8")
    br.flood(FLOOD, 1.1, grad=(0.0, 92.0, 0.8))
    bm = bmesh.new()
    box(bm, -65.0, 65.0, 0.0, 67.0, 0.0, 30.0)
    for sx in (-1, 1):                                                     # corner towers
        for y in (0.0, 67.0):
            cx = sx * 65.0
            box(bm, cx - 5.5, cx + 5.5, y - 5.5, y + 5.5, 0.0, 64.0)
            box(bm, cx - 4.3, cx + 4.3, y - 4.3, y + 4.3, 64.0, 74.0)
            lathe(bm, [(3.6, 74.0), (3.6, 81.0), (0.0, 81.0)], 8, cx, y, math.pi / 8)
    make(rig, "bp_brick", bm, br.finish())
    op = plain("bp_open", "#2a2826", rough=0.6, glow=("#ffd49a", 0.3))
    bm = bmesh.new()
    for sx in (-1, 1):
        for y in (0.0, 67.0):
            cx = sx * 65.0
            for (nx, ny) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                c = Vector((cx + nx * 4.32, y + ny * 4.32, 0.0))
                t = Vector((-ny, nx, 0.0))
                v = [bm.verts.new(c + t * d + Vector((0, 0, z))) for (d, z) in
                     ((-1.3, 65.5), (1.3, 65.5), (1.3, 70.5), (0.0, 72.0), (-1.3, 70.5))]
                bm.faces.new(v)
    make(rig, "bp_open", bm, op)
    tl = Shade("bp_tiles", "#2f7a4f", rough=0.35, spec=0.6, noise=0.0)
    nb = tl.nb
    ang = nb.math("ARCTAN2", tl.y, tl.x)
    tri = nb.absf(nb.sub(nb.math("FLOORED_MODULO", nb.mul(ang, 24.0 / (2 * math.pi)), 1.0), 0.5))
    v = nb.madd(tri, 2.4, tl.z)
    idx = nb.math("FLOORED_MODULO", nb.math("FLOOR", nb.math("DIVIDE", v, 1.3)), 4.0)
    col = nb.ramp(nb.math("DIVIDE", nb.add(idx, 0.5), 4.0), [
        (0.0, M.srgb("#2f7a4f")), (0.25, M.srgb("#e0b83a")), (0.5, M.srgb("#efe9da")), (0.75, M.srgb("#2b5c9a"))])
    col.node.color_ramp.interpolation = "CONSTANT"
    tl.set_col(col)
    tl.flood(FLOOD_WHITE, 0.9)
    tiles_m = tl.finish()
    st = Shade("bp_stone", "#e6dcc8", rough=0.8, spec=0.3, noise=0.04)
    st.grid("round", (-400.0, 400.0), (31.5, 37.0), (3.0, 7.0), (1.4, 4.2), lit=0.5, cx=0.0, cy=33.5, r=11.0,
            glass="#2e2b28", arch=True, color="#ffd49a", strength=0.8)
    st.flood(FLOOD, 1.0)
    bmd = bmesh.new()
    bmt = bmesh.new()
    # eleven domes (x, y, radius, drum height): the big central one, four on the nave axis, six small ones
    domes = [(0.0, 33.5, 11.0, 8.0)] + [(x, 33.5, 7.0, 4.0) for x in (-22.0, 22.0, -44.0, 44.0)] + \
        [(x, y, 5.0, 2.5) for x in (-33.0, 33.0) for y in (12.0, 55.0)] + [(x, 33.5, 5.0, 2.5) for x in (-56.0, 56.0)]
    for (x, y, r, drum) in domes:
        lathe(bmd, [(r, 30.0), (r, 30.0 + drum), (r + 0.5, 30.4 + drum), (0.0, 30.4 + drum)], 24, x, y)
        z0 = 30.4 + drum
        prof = dome_profile(r, r * 1.05, "dome", 10, z0=z0)
        lathe(bmt, prof, 32, x, y)
        zt = z0 + r * 1.05
        lathe(bmd, [(r * 0.2, zt - 0.4), (r * 0.2, zt + r * 0.35), (r * 0.26, zt + r * 0.4), (0.0, zt + r * 0.62)], 12, x, y)
        lathe(bmt, dome_profile(r * 0.24, r * 0.3, "dome", 6, z0=zt + r * 0.4), 12, x, y)
    for sx in (-1, 1):                                                     # tower cupolas
        for y in (0.0, 67.0):
            lathe(bmt, dome_profile(3.8, 4.4, "onion", 10, z0=81.0), 16, sx * 65.0, y)
            lathe(bmd, [(0.8, 85.2), (0.8, 88.0), (0.0, 92.0)], 8, sx * 65.0, y)
    make(rig, "bp_drums", bmd, st.finish())
    make(rig, "bp_tiles", bmt, tiles_m, smooth=True, sharp=50.0)
    return dict(object=obj_size(141.0, 92.0, 78.0))


# --- registry -------------------------------------------------------------------------------------

#  glow per light layer [(sigma_m, strength)] (bloom in post), margins (side, top, bottom) in metres
G_FLOOD = {"lights": [(0.3, 0.15), (2.0, 0.08)]}
G_TOWER = {"lights": [(0.4, 0.2), (2.5, 0.1)]}
G_LATTICE = {"lights": [(0.15, 0.15), (1.0, 0.06)]}

#  name: (builder, fit_h px, view_yaw, margins m, glow, catcher m, max_w px, light_gain)
LANDMARKS = {
    "eiffel_tower": (eiffel_tower, 1024, -14.0, (4.0, 5.0, 2.0), G_LATTICE, 170.0, 640, 1.0),
    "fernsehturm_berlin": (fernsehturm_berlin, 1024, -20.0, (4.0, 5.0, 2.0), G_TOWER, 110.0, 384, 1.0),
    "riesenrad": (riesenrad, 416, -24.0, (2.0, 2.5, 1.2), G_LATTICE, 70.0, 512, 1.0),
    "elbphilharmonie": (elbphilharmonie, 512, -28.0, (2.0, 3.0, 1.2), G_FLOOD, 160.0, 704, 1.0),
    "michel": (michel, 640, -22.0, (2.0, 3.0, 1.2), G_FLOOD, 110.0, 512, 1.0),
    "stephansdom": (stephansdom, 600, -22.0, (2.0, 3.0, 1.2), G_FLOOD, 140.0, 640, 1.0),
    "frauenkirche_dresden": (frauenkirche_dresden, 480, -18.0, (2.0, 2.5, 1.2), G_FLOOD, 80.0, 384, 1.0),
    "frauenkirche_muenchen": (frauenkirche_muenchen, 512, -24.0, (2.0, 2.5, 1.2), G_FLOOD, 130.0, 512, 1.0),
    "sagrada_familia": (sagrada_familia, 768, -20.0, (2.5, 3.0, 1.2), G_FLOOD, 110.0, 512, 1.0),
    "duomo_milano": (duomo_milano, 512, -14.0, (2.0, 3.0, 1.2), G_FLOOD, 170.0, 640, 1.0),
    "campanile_venezia": (campanile_venezia, 512, -16.0, (2.0, 2.5, 1.2), G_FLOOD, 100.0, 512, 1.0),
    "parlament_budapest": (parlament_budapest, 384, -14.0, (2.0, 2.5, 1.2), G_FLOOD, 280.0, 960, 1.0),
    "veitsdom_prag": (veitsdom_prag, 448, -12.0, (2.0, 2.5, 1.2), G_FLOOD, 190.0, 800, 1.0),
    "kulturpalast_warschau": (kulturpalast_warschau, 800, -22.0, (3.0, 3.0, 1.5), G_FLOOD, 200.0, 704, 1.0),
    "nevsky_kathedrale": (nevsky_kathedrale, 352, -26.0, (1.5, 2.0, 1.0), G_FLOOD, 80.0, 448, 1.0),
    # optional (cities without a must-have landmark)
    "frankfurt_skyline": (frankfurt_skyline, 640, -10.0, (3.0, 3.0, 1.5), G_FLOOD, 300.0, 640, 1.0),
    "kaiserburg_nuernberg": (kaiserburg_nuernberg, 352, -16.0, (1.5, 2.0, 1.0), G_FLOOD, 170.0, 640, 1.0),
    "st_petri_riga": (st_petri_riga, 576, -20.0, (2.0, 2.5, 1.2), G_FLOOD, 90.0, 448, 1.0),
    "freiheitsdenkmal_riga": (freiheitsdenkmal_riga, 288, -20.0, (1.0, 1.5, 0.6), G_FLOOD, 30.0, 256, 1.0),
    "kathedrale_burgos": (kathedrale_burgos, 448, -22.0, (1.5, 2.0, 1.0), G_FLOOD, 130.0, 512, 1.0),
    "basilica_pilar": (basilica_pilar, 448, -12.0, (1.5, 2.0, 1.0), G_FLOOD, 160.0, 704, 1.0),
}


def _revisions():
    """Per-landmark source revision for the render cache: the shared part of this module (helpers,
    materials, constants - everything except the landmark builders and the registry) + the landmark's
    own builder. Editing one landmark re-renders only that landmark (render_all hashes this module
    through the 'rev' parameter instead of as a whole)."""
    import hashlib
    import inspect
    import sys
    src = inspect.getsource(sys.modules[__name__])
    own = {}
    for name, entry in LANDMARKS.items():
        own[name] = inspect.getsource(entry[0])
        src = src.replace(own[name], "")
    reg0 = src.find("\nLANDMARKS = {")
    reg1 = src.find("\n}\n", reg0)
    shared = src[:reg0] + src[reg1:]
    return {n: hashlib.sha1((shared + o).encode("utf-8")).hexdigest()[:12] for n, o in own.items()}


def landmark_sets():
    out = []
    revs = _revisions()
    for name, (_fn, fit_h, vy, margins, glow, catcher, max_w, gain) in LANDMARKS.items():
        cam = dict(mode="ortho", elevation=E, fit_h=fit_h, view_yaw=float(vy), angles=[("c", 0.0)], max_w=max_w,
                   centered=False, margins=margins)
        out.append(dict(
            id="landmarks/" + name, builder="landmark", params=dict(name=name, rev=revs[name]), paint=[],
            camera=cam, layers=["base", "lights"], glow=glow, light_gain={"lights": gain},
            tags=["prop", "landmark"], shadow=0.55, catcher=catcher))
    return out


def _ground_bounce(rig):
    """Weak warm fill light from below (light reflected by the ground), without shadows: downward-facing
    surfaces (the TV tower sphere, dome bottoms, platform undersides) are not black. Affects only the
    base pass: emission passes ignore lights and the shadow catcher is lit from above."""
    import bpy
    d = bpy.data.lights.new("ground_bounce", "SUN")
    d.energy = 0.6
    d.angle = math.radians(40.0)
    d.color = (0.85, 0.8, 0.72)
    d.use_shadow = False
    ob = bpy.data.objects.new("ground_bounce", d)
    ob.rotation_euler = Vector((0.15, -0.45, -1.0)).normalized().to_track_quat("Z", "Y").to_euler()
    rig.col.objects.link(ob)


def build(rig, p):
    info = LANDMARKS[p["name"]][0](rig, p)
    _ground_bounce(rig)
    return info
