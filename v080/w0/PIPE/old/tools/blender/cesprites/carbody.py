"""Smooth parametric car bodies for the player cars (Blender 5.2 / bmesh).

Vehicle space as everywhere in the pipeline: y = 0 at the rearmost point (rear bumper), +y forward,
x = 0 centre line (+x = right flank), z = 0 ground. All parts are parented to a CENTER empty; after the
build it is moved to (0, -L/2, 0) so that the rig root (rotation about the world origin) turns the car
about its centre (pivot "center").

Body = dense lofts of analytic cross-sections whose key lines are smooth monotone splines
(curves.Profile): lower body (plan width, deck/hood/trunk line, shoulder crease, tucked rocker, wheel
arches with flared lips), greenhouse (roof line incl. windshield and rear window, tumblehome, rounded
roof edge, curved side glass) and bumpers that protrude a few centimetres (ledge on top). Character
lines are sharp edges between smooth-shaded faces.

Everything that sits on the body - glass, lamps (lens + housing + reflector bowls + light guides),
plates, grilles, vents, seams, trims, badges - is a conformal patch: a 2-D outline triangulated finely
and ray-cast onto the body (BVH of the final meshes), raised by a small offset, optionally with side
walls. So details follow every curvature and stay crisp at any resolution.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils import geometry as mgeo
from mathutils.bvhtree import BVHTree

from . import curves as C
from . import materials as M
from . import meshutil as MU

# points per section segment (lower body)
N_UNDER, N_RB, N_LS, N_US, N_RE, N_DECK = 4, 6, 16, 10, 10, 14
# greenhouse
N_GB, N_GS, N_GR, N_ROOF = 3, 14, 10, 14

TAIL_RED = "#ff1a0e"
BRAKE_RED = "#ff2414"


def _prof(v):
    if isinstance(v, C.Profile):
        return v
    if isinstance(v, (int, float)):
        return C.const(float(v))
    return C.Profile(v)


def _norm(dx, dz):
    ln = math.hypot(dx, dz) or 1e-9
    return dx / ln, dz / ln


class Frame:
    """Key values of a lower-body section."""
    __slots__ = ("y", "w", "z_deck", "crown", "z_edge", "x_de", "z_sh", "z_start", "z_bot", "tuck_ref",
                 "tumble_up", "r_e", "r_b")


class SmoothCar:
    def __init__(self, rig, d, paint="#888888", metal=0.4, name="car", rough=0.3):
        self.rig = rig
        self.d = d
        self.name = name
        self.paint_hex = paint
        self.metal = metal
        self.L = d["L"]
        self.W2 = d["W"] / 2.0
        self.R = d["R"]
        self.Ra = d["R"] + d.get("arch_gap", 0.035)
        self.y_ra = d["r_oh"]
        self.y_fa = d["r_oh"] + d["wb"]
        br, bf = d["bump_rear"], d["bump_front"]
        self.lb0 = br["out"]
        self.lb1 = self.L - bf["out"]
        self.plan = _prof(d["plan"])
        self.deck = _prof(d["deck"])
        self.crown = _prof(d.get("crown", 0.03))
        self.under = _prof(d["under"])
        self.shoulder = _prof(d["shoulder"])
        self.roof = _prof(d["roof"])
        self.g_inset = _prof(d.get("g_inset", 0.06))
        self.roof_taper = _prof(d.get("roof_taper", 0.0))
        self.tuck = _prof(d.get("tuck", 0.05))
        self.tumble_up = _prof(d.get("tumble_up", 0.05))
        self.objects = []          # ray-cast targets (body surfaces)
        self.targets = {"all": self.objects}
        self.center = MU.empty(name + "_center", parent=rig.root)
        self._bvh = {}
        self.mats = {}
        self.paint = M.paint(name + "_paint", paint, metal=metal, rough=rough)

    # ------------------------------------------------------------------ profiles / sections

    def arch_z(self, y):
        """Top of the wheel arch opening at station y (None outside the arches)."""
        best = None
        for ya in (self.y_ra, self.y_fa):
            dy = abs(y - ya)
            if dy < self.Ra:
                z = self.R + math.sqrt(self.Ra * self.Ra - dy * dy)
                best = z if best is None else max(best, z)
        return best

    def frame(self, y):
        d = self.d
        f = Frame()
        f.y = y
        y0, y1 = self.lb0, self.lb1
        rp = d.get("r_plan", (0.3, 0.4))
        pp = d.get("p_plan", (2.0, 2.0))
        plan_in = C.round_end(y - y0, rp[0], pp[0]) + C.round_end(y1 - y, rp[1], pp[1])
        rt = d.get("r_top", (0.1, 0.12))
        pt = d.get("p_top", (2.0, 2.0))
        top_in = C.round_end(y - y0, rt[0], pt[0]) + C.round_end(y1 - y, rt[1], pt[1])
        rb = d.get("r_bot", (0.1, 0.1))
        bot_in = C.round_end(y - y0, rb[0]) + C.round_end(y1 - y, rb[1])
        f.w = self.plan(y) - plan_in
        f.z_deck = self.deck(y) - top_in
        f.crown = self.crown(y) * (1.0 - min(1.0, top_in / 0.06) * 0.5)
        f.z_edge = f.z_deck - f.crown
        f.r_e = d.get("r_edge", 0.06)
        f.tumble_up = self.tumble_up(y)
        f.x_de = f.w - f.tumble_up - f.r_e * 0.85
        f.r_b = d.get("r_bottom", 0.04)
        z_bot = self.under(y) + bot_in
        f.tuck_ref = self.under(y) + f.r_b
        za = self.arch_z(y)
        z_start = z_bot if za is None else max(z_bot, za)
        z_sh = self.shoulder(y)
        z_sh = min(z_sh, f.z_edge - f.r_e - 0.02)
        z_start = min(z_start, z_sh - f.r_b - 0.03)
        f.z_sh = z_sh
        f.z_start = z_start
        f.z_bot = z_bot
        return f

    def flare(self, y, z):
        amp, fw = self.d.get("arch_flare", (0.0, 0.1))
        if amp <= 0:
            return 0.0
        out = 0.0
        for ya in (self.y_ra, self.y_fa):
            rr = math.hypot(y - ya, max(0.0, z - self.R) if z > self.R else (z - self.R) * 0.6)
            if rr < self.Ra - 0.005:
                continue
            t = (rr - self.Ra) / fw
            if t < 1.0:
                out = max(out, amp * (1.0 - max(0.0, t)) ** 2)
        return out

    def side_x(self, f, z):
        """Lower side half-width at height z (rocker tuck below the shoulder)."""
        span = max(0.05, f.z_sh - f.tuck_ref)
        t = min(1.4, max(0.0, (f.z_sh - z) / span))
        return f.w - self.tuck(f.y) * t ** 1.8 + self.flare(f.y, z)

    def lower_half(self, y):
        """Half section (x, z) from the bottom centre to the top centre and the shoulder index."""
        f = self.frame(y)
        pts = []
        # underside
        z0 = f.z_start
        x_low = self.side_x(f, z0 + f.r_b)
        xu = max(0.02, x_low - f.r_b)
        for i in range(N_UNDER):
            pts.append((xu * i / N_UNDER, z0))
        # bottom rounding
        pts += C.arc(xu, z0 + f.r_b, f.r_b, -90, 0, N_RB, rx=x_low - xu)
        # lower side up to the shoulder
        zs = [z0 + f.r_b + (f.z_sh - z0 - f.r_b) * t for t in C.spacing(N_LS, "cos")[1:]]
        for z in zs:
            pts.append((self.side_x(f, z), z))
        k_sh = len(pts) - 1
        # upper side: shoulder -> start of the deck edge rounding
        z_e1 = f.z_edge - f.r_e
        x_sh = pts[-1][0]
        xa = f.w - f.tumble_up
        for t in C.spacing(N_US, "lin")[1:]:
            z = f.z_sh + (z_e1 - f.z_sh) * t
            pts.append((x_sh + (xa - x_sh) * t ** 1.35, z))
        # deck edge rounding (Bezier, tangents of upper side and crowned deck)
        dxu = (xa - x_sh) * 1.35 / max(0.02, z_e1 - f.z_sh)
        t0 = _norm(dxu, 1.0)
        x_de = min(f.x_de, xa - 0.02)
        t3 = _norm(-1.0, 2.0 * f.crown / max(0.1, x_de))
        k = 0.55 * f.r_e
        p0 = (xa, z_e1)
        p3 = (x_de, f.z_edge)
        pts += C.bezier(p0, (p0[0] + t0[0] * k, p0[1] + t0[1] * k), (p3[0] - t3[0] * k, p3[1] - t3[1] * k), p3,
                        N_RE, include_start=False)
        # deck
        for t in C.spacing(N_DECK, "lin")[1:]:
            x = x_de * (1.0 - t)
            pts.append((x, f.z_deck - f.crown * (x / x_de) ** 2))
        return pts, k_sh, f

    def deck_z_at(self, y, x):
        f = self.frame(y)
        x_de = min(f.x_de, f.w - f.tumble_up - 0.02)
        if x <= x_de:
            return f.z_deck - f.crown * (x / x_de) ** 2
        return f.z_edge - (x - x_de) * 0.5

    def green_half(self, y):
        d = self.d
        f = self.frame(y)
        x_de = min(f.x_de, f.w - f.tumble_up - 0.02)
        xb = x_de - self.g_inset(y)
        zsurf = min(f.z_deck - f.crown * (xb / x_de) ** 2, f.z_deck)
        zb = zsurf - d.get("g_sink", 0.04)
        zr = max(self.roof(y), zb + 0.012)
        h = zr - zb
        rc = d.get("roof_crown", 0.035) * min(1.0, h / 0.3)
        rr = min(d.get("r_roof", 0.07), 0.42 * max(0.0, h - rc))
        rr = max(rr, 0.002)
        zs = zr - rc - rr
        tb = d.get("tumble", 0.3)
        xs = xb - tb * (zs - zb) - self.roof_taper(y)
        x_rc = max(0.05, xs - rr)
        bulge = d.get("glass_bulge", 0.012) * min(1.0, h / 0.35)
        pts = []
        for i in range(N_GB):
            pts.append((xb * i / N_GB, zb))
        for t in C.spacing(N_GS, "lin"):
            z = zb + (zs - zb) * t
            pts.append((xb + (xs - xb) * t + bulge * math.sin(math.pi * t), z))
        sd = _norm(xs - xb - bulge * math.pi, zs - zb)
        t3 = _norm(-1.0, 2.0 * rc / x_rc)
        k = 0.55 * rr
        p0 = (xs, zs)
        p3 = (x_rc, zr - rc)
        pts += C.bezier(p0, (p0[0] + sd[0] * k, p0[1] + sd[1] * k), (p3[0] - t3[0] * k, p3[1] - t3[1] * k), p3,
                        N_GR, include_start=False)
        for t in C.spacing(N_ROOF, "lin")[1:]:
            x = x_rc * (1.0 - t)
            pts.append((x, zr - rc * (x / x_rc) ** 2))
        return pts, dict(xb=xb, zb=zb, xs=xs, zs=zs, zr=zr, rr=rr, x_rc=x_rc, rc=rc)

    # ------------------------------------------------------------------ meshes

    def _loft_object(self, name, ys, half_fn, mat, crease_idx=(), cap0=True, cap1=True, sharp_ring_ends=()):
        rings = []
        crease_cols = set()
        for y in ys:
            res = half_fn(y)
            half = res[0]
            ring = [(x, y, z) for (x, z) in MU.mirror_ring(half)]
            rings.append(ring)
        n = len(rings[0])
        nh = (n + 2) // 2
        for k in crease_idx:
            crease_cols.add(k)
            crease_cols.add(n - k)
        bm = bmesh.new()
        vr = [[bm.verts.new(p) for p in ring] for ring in rings]
        faces = []
        for a, b in zip(vr[:-1], vr[1:]):
            for i in range(n):
                j = (i + 1) % n
                try:
                    faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
                except ValueError:
                    pass
        if cap0:
            faces.append(bm.faces.new(list(reversed(vr[0]))))
        if cap1:
            faces.append(bm.faces.new(vr[-1]))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        for fc in faces:
            fc.smooth = True
        # sharp edges along crease columns and around the caps
        sharp = set()
        for col in crease_cols:
            for a, b in zip(vr[:-1], vr[1:]):
                e = bm.edges.get((a[col % n], b[col % n]))
                if e:
                    sharp.add(e)
        if cap0:
            for i in range(n):
                e = bm.edges.get((vr[0][i], vr[0][(i + 1) % n]))
                if e:
                    sharp.add(e)
        if cap1:
            for i in range(n):
                e = bm.edges.get((vr[-1][i], vr[-1][(i + 1) % n]))
                if e:
                    sharp.add(e)
        for e in sharp:
            e.smooth = False
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        MU._link(ob, self.center)
        return ob

    def build_lower(self, mat=None):
        d = self.d
        feats = []
        for ya in (self.y_ra, self.y_fa):
            feats += [ya - self.Ra - 0.002, ya - self.Ra + 0.002, ya + self.Ra - 0.002, ya + self.Ra + 0.002]
        dense = [(ya - self.Ra - 0.15, ya + self.Ra + 0.15, 0.012) for ya in (self.y_ra, self.y_fa)]
        rp = d.get("r_plan", (0.3, 0.4))
        rt = d.get("r_top", (0.1, 0.12))
        ys = C.stations(self.lb0, self.lb1, d.get("step", 0.022),
                        ends=((max(rp[0], rt[0]) + 0.02, 14), (max(rp[1], rt[1]) + 0.02, 14)),
                        features=feats + list(d.get("y_features", [])), dense=dense)
        _, k_sh, _ = self.lower_half(ys[len(ys) // 2])
        crease = [k_sh] if d.get("shoulder_crease", True) else []
        ob = self._loft_object(self.name + "_body", ys, self.lower_half, mat or self.paint, crease_idx=crease)
        self.body = ob
        self.objects.append(ob)
        self.targets["body"] = [ob]
        return ob

    def build_greenhouse(self, mat=None):
        d = self.d
        g0, g1 = d["g_range"]
        roof = self.roof
        # densify where the roof line is steep (rear window / windshield)
        ys = set()
        y = g0
        while y < g1:
            ys.add(round(y, 5))
            sl = abs(roof.deriv(y))
            y += max(0.004, d.get("g_step", 0.02) / (1.0 + 1.5 * sl))
        ys.add(g1)
        ys = sorted(ys)
        ob = self._loft_object(self.name + "_greenhouse", ys, self.green_half, mat or self.paint)
        self.green = ob
        self.objects.append(ob)
        self.targets["green"] = [ob]
        return ob

    def bumper_half_fn(self, which):
        d = self.d
        b = d["bump_" + which]
        out = b["out"]
        L = self.L
        zt_p = _prof(b["z_top"])
        zb_p = _prof(b.get("z_bot", d["under"]))
        r_pl = b.get("r_plan", d.get("r_plan", (0.3, 0.4))[0 if which == "rear" else 1] + out)
        p_pl = b.get("p_plan", 2.0)
        r_end_t = b.get("r_end_top", 0.03)
        r_end_b = b.get("r_end_bot", 0.08)
        y_end = 0.0 if which == "rear" else L
        rp = d.get("r_plan", (0.3, 0.4))
        # reference station outside the body's end rounding: the bumper takes the body's side shape (tuck)
        # from there, its width from the plan profile at y and only ITS OWN end rounding (no double inset)
        y_body = self.lb0 + rp[0] + 0.02 if which == "rear" else self.lb1 - rp[1] - 0.02
        y_arch = (self.y_ra - self.Ra) if which == "rear" else (self.y_fa + self.Ra)
        flush = b.get("flush", 0.25)

        def half(y):
            dist = abs(y - y_end)
            yr = max(y, y_body) if which == "rear" else min(y, y_body)
            f = self.frame(yr)
            f.w = self.plan(y)
            f.y = y
            # protrusion fades out towards the wheel arch
            da = abs(y_arch - y)
            o = out * C.smoothstep(0.0, flush, da) + 0.003
            pin = C.round_end(dist, r_pl, p_pl)
            zt = zt_p(y) - C.round_end(dist, r_end_t)
            zb = zb_p(y) + C.round_end(dist, r_end_b)
            rb, rt = 0.03, b.get("r_top_edge", 0.03)
            pts = []
            xbot = self.side_x(f, zb + rb) + o - pin
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
            for t in C.spacing(6, "lin")[1:]:
                pts.append((xin * (1 - t), zt))
            return (pts,)
        return half

    def build_bumpers(self, mat_rear=None, mat_front=None):
        out = []
        for which, mat in (("rear", mat_rear), ("front", mat_front)):
            b = self.d["bump_" + which]
            if which == "rear":
                y0, y1 = 0.0, self.y_ra - self.Ra - 0.004
                ends = ((b.get("r_plan", 0.3) + 0.05, 14), (0.0, 0))
            else:
                y0, y1 = self.y_fa + self.Ra + 0.004, self.L
                ends = ((0.0, 0), (b.get("r_plan", 0.4) + 0.05, 14))
            ys = C.stations(y0, y1, 0.02, ends=ends)
            ob = self._loft_object(self.name + "_bumper_" + which, ys, self.bumper_half_fn(which), mat or self.paint)
            self.objects.append(ob)
            self.targets["bumper_" + which] = [ob]
            out.append(ob)
        self.bumper_rear, self.bumper_front = out
        return out

    def build_liners(self):
        mat = self.mat("liner", "#0b0b0c", rough=0.85)
        bm = bmesh.new()
        for ya in (self.y_ra, self.y_fa):
            f = self.frame(ya)
            xw = f.w - 0.03
            prof = [(self.Ra - 0.004, -xw), (self.Ra - 0.004, xw)]
            segs = 36
            verts = []
            for i in range(segs + 1):
                a = math.radians(-12 + (180 + 24) * i / segs)
                ring = []
                for (r, x) in prof:
                    ring.append(bm.verts.new((x, ya + r * math.cos(a), self.R + r * math.sin(a))))
                verts.append(ring)
            for a_, b_ in zip(verts[:-1], verts[1:]):
                bm.faces.new((a_[0], a_[1], b_[1], b_[0]))
        ob = MU.make(self.name + "_liners", bm, mat, parent=self.center)
        return ob

    # ------------------------------------------------------------------ materials

    def mat(self, key, color, **kw):
        k = self.name + "_" + key
        if k not in self.mats:
            self.mats[k] = M.basic(k, color, **kw)
        return self.mats[k]

    # ------------------------------------------------------------------ ray casting / conformal patches

    def add_target(self, key, obs):
        self.targets[key] = list(obs)
        self._bvh.pop(key, None)

    def bvh(self, target="all", refresh=False):
        if target in self._bvh and not refresh:
            return self._bvh[target]
        deps = bpy.context.evaluated_depsgraph_get()
        deps.update()
        verts, polys = [], []
        for ob in self.targets[target]:
            ev = ob.evaluated_get(deps)
            me = ev.to_mesh()
            mw = ob.matrix_world.copy()
            base = len(verts)
            verts += [mw @ v.co for v in me.vertices]
            polys += [[base + i for i in p.vertices] for p in me.polygons]
            ev.to_mesh_clear()
        self._bvh[target] = BVHTree.FromPolygons(verts, polys, all_triangles=False)
        return self._bvh[target]

    def cast(self, proj, u, v, sign=1, target="all"):
        """Ray cast a projection-plane point onto the body. Returns (location, normal) or None
        (build space: the CENTER empty is still at the origin)."""
        bvh = self.bvh(target)
        if proj == "rear":
            o, dvec = Vector((u, -3.0, v)), Vector((0.0, 1.0, 0.0))
        elif proj == "front":
            o, dvec = Vector((u, self.L + 3.0, v)), Vector((0.0, -1.0, 0.0))
        elif proj == "side":
            o, dvec = Vector((sign * 4.0, u, v)), Vector((-sign, 0.0, 0.0))
        elif proj == "top":
            o, dvec = Vector((u, v, 6.0)), Vector((0.0, 0.0, -1.0))
        else:
            raise ValueError(proj)
        loc, nor, idx, dist = bvh.ray_cast(o, dvec, 50.0)
        if loc is None:
            return None
        if nor.dot(dvec) > 0:
            nor = -nor
        return loc, nor

    def patch(self, outline, proj, mat, offset=0.0015, res=0.012, sym=True, walls=0.0, name="patch",
              wall_mat=None, smooth=True, side=1, normal_offset=True, target="all"):
        """Conformal patch from a counter-clockwise 2-D outline in the projection plane:
        rear/front: (x, z) - mirrored to -x when sym; side: (y, z) on the right flank (+ left when sym);
        top: (x, y). walls > 0: side walls down to the surface (raised element of that height = offset)."""
        outline = C.ccw(outline)
        variants = [(outline, side)]
        if sym:
            if proj in ("rear", "front", "top"):
                variants.append((C.ccw([(-p[0], p[1]) for p in outline]), side))
            else:
                variants.append((outline, -side))
        bm = bmesh.new()
        for (ol, sgn) in variants:
            self._patch_into(bm, ol, proj, offset, res, walls, sgn, normal_offset, target)
        if len(bm.faces) == 0:
            bm.free()
            return None
        mats = [mat] if wall_mat is None else [mat, wall_mat]
        ob = MU.make(self.name + "_" + name, bm, mats, parent=self.center, smooth=smooth, sharp_deg=60)
        return ob

    def _patch_into(self, bm, outline, proj, offset, res, walls, sgn, normal_offset, target="all"):
        # boundary resampled to <= res, interior grid points
        bnd = []
        n = len(outline)
        for i in range(n):
            a, b = outline[i], outline[(i + 1) % n]
            seg = math.hypot(b[0] - a[0], b[1] - a[1])
            k = max(1, int(math.ceil(seg / res)))
            for j in range(k):
                t = j / k
                bnd.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
        xs = [p[0] for p in bnd]
        ys = [p[1] for p in bnd]
        pts = list(bnd)
        gx0, gx1, gy0, gy1 = min(xs), max(xs), min(ys), max(ys)
        nb = len(bnd)
        edges = [(i, (i + 1) % nb) for i in range(nb)]
        x = gx0 + res * 0.5
        poly2 = [Vector((p[0], p[1])) for p in outline]
        while x < gx1:
            y = gy0 + res * 0.5
            while y < gy1:
                if _inside(x, y, outline) and _dist_to_poly(x, y, outline) > res * 0.35:
                    pts.append((x, y))
                y += res
            x += res
        try:
            out = mgeo.delaunay_2d_cdt([Vector(p) for p in pts], edges, [list(range(nb))], 1, 1e-7)
        except Exception:
            return
        vco, _e, faces = out[0], out[1], out[2]
        hits = []
        for p in vco:
            h = self.cast(proj, p[0], p[1], sgn, target)
            hits.append(h)
        vmap = {}
        for fi in faces:
            if any(hits[i] is None for i in fi):
                continue
            vs = []
            for i in fi:
                if i not in vmap:
                    loc, nor = hits[i]
                    vmap[i] = bm.verts.new(loc + nor * offset)
                vs.append(vmap[i])
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            f.material_index = 0
        bm.normal_update()
        # orient outward (along the surface normal)
        for f in bm.faces:
            vi = [k for k, v in vmap.items() if v in f.verts]
            if not vi:
                continue
            nrm = hits[vi[0]][1]
            if f.normal.dot(nrm) < 0:
                f.normal_flip()
        if walls > 0.0:
            inv = {v: k for k, v in vmap.items()}
            bedges = [e for e in bm.edges if e.is_boundary and e.verts[0] in inv and e.verts[1] in inv]
            low = {}
            for e in bedges:
                for v in e.verts:
                    if v not in low:
                        loc, nor = hits[inv[v]]
                        low[v] = bm.verts.new(loc - nor * 0.002)
            for e in bedges:
                a, b = e.verts
                f0 = e.link_faces[0]
                # keep the winding consistent with the top face
                loop = [l for l in f0.loops if l.edge == e][0]
                if loop.vert != a:
                    a, b = b, a
                try:
                    wf = bm.faces.new((b, a, low[a], low[b]))
                    wf.material_index = 1
                except ValueError:
                    pass

    def stripe(self, pts, width, proj, mat, **kw):
        """Conformal line (seams, trims, light guides) along a 2-D polyline."""
        return self.patch(C.stroke(pts, width), proj, mat, **kw)

    def finish(self):
        """Moves the car so that its centre sits on the rig root (rotation pivot)."""
        self.center.location = (0.0, -self.L / 2.0, 0.0)
        bpy.context.view_layer.update()

    def object_size(self):
        h = max(self.roof(y) for y in [self.d["g_range"][0] + i * 0.05 for i in range(200)
                                       if self.d["g_range"][0] + i * 0.05 < self.d["g_range"][1]])
        return {"width_m": round(self.d["W"], 3), "length_m": round(self.L, 3),
                "height_m": round(h + self.d.get("extra_h", 0.0), 3)}


def _inside(x, y, poly):
    c = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-12) + xi):
            c = not c
        j = i
    return c


def _dist_to_poly(x, y, poly):
    best = 1e9
    n = len(poly)
    for i in range(n):
        ax, ay = poly[i]
        bx, by = poly[(i + 1) % n]
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / L2))
        px, py = ax + dx * t, ay + dy * t
        best = min(best, math.hypot(x - px, y - py))
    return best
