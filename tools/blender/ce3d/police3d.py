"""Police cars as real-time models (contract 6, wave 4 "AS2b"; docs/modelle.md section 15).

A police set of the sprite catalog (cesprites.catalog.POLICE: base model, word, livery style, colours) is the traffic
car of ce3d.traffic3d with
  livery  the bands and checks of cesprites.police.livery cut INTO the body (one layer, like every decal of the
          traffic cars): paint = body colour, paint2 = c1, paint3 = c2 - the colours are the paint of the set
          (instance uniforms), the outlines are geometry. A check pattern keeps its cells at lod0; at lod1 only on
          the ends (rear and front, what the chase camera sees), the flanks show the mean of the two colours; at
          lod2 everything shows the mean (cells of 24 cm are one pixel at 120 m and would only shimmer)
  words   the local word for police on both flanks and on the rear, cut into the body from the glyph triangles of
          the font Blender ships (cesprites.textgeo, as the sprite) - at lod0 only (at 40 m a letter is 3 px high)
  bar     the roof light bar: feet, a dark base, two clear blue domes (glass) over three LED modules each - beacon
          A on the left, beacon B on the right (lamp channels 10 / 11; the session alternates them) - and a white
          middle module; at lod1 / lod2 the same outline as blocks without glass. Its top lies 0.13 m over the roof,
          as the sprite's (object height = car + 0.13)
  shadow  the hull of the traffic car with the bar as a block
The traffic car is built by traffic3d itself (its levels, lamps, plates, windows): this builder only hooks into two
of its steps for the time of one build (_hooks: the design without roof rails and the badge under the rear word;
the cut surfaces get livery and words). A rework of the traffic cars therefore reaches the police cars, too.
Model space as every vehicle: origin on the ground under the centre of the collision box, nose at -Z.
"""
import contextlib
import copy
import math
import time

import bmesh
import numpy as np

from . import core, decalgeo, roles
from . import lod as LOD
from .export import Lod, ModelData, Part, sprite_extent

BAR_HEIGHT = 0.13            # the bar's top over the roof (cesprites.police: object height = car + 0.13)
BAR_W = 1.22                 # width of the bar (m)
BAR_D = 0.28                 # depth (along the car)
FOOT_H = 0.025               # feet: roof -> underside of the base
BASE_H = 0.03                # dark base under the domes
MID_W = 0.15                 # white middle module
BEACON = "#2f5bff"           # lit colour of the beacons (cesprites.police.BEACON)
DOME = dict(color="#4a6ee0", rough=0.04, opacity=0.22)     # clear blue dome over the modules (lod0, class glass)
WORD_RANK = 5000             # the words lie over everything else on their faces (a sticker over the door seams)
WORD_RES = 2                 # curve resolution of the glyphs (cesprites.textgeo: 3) - an O of 16 cm is a 16-gon
NOT_TOP = 0.75               # bands leave faces that look up more than this (cesprites.materials.surface)
CHECK_FAR_LEVEL = 1          # from this level on the flanks show a check band in the mean of its two colours (cells of
#                              24 cm: 4 px at 40 m - on the flanks of lod1 they cost 2,700 triangles of a budget of 6,000)
CHECK_END_LEVEL = 2          # ... the ends (rear, front: what the chase camera sees) keep the cells up to this level
# livery lines cut only faces larger than this (m, per level 0 / 1 / 2) across the line; smaller faces take the colour
# of their centre: a saw tooth of at most this size - 1 cm is 0.7 px at 10 m, 4 cm is 0.7 px at 40 m, 10 cm 0.6 px at
# 120 m (focal length 711 px)
SPLIT_MIN_M = (0.01, 0.04, 0.15)
# ... and smaller in area than this (m2): 2 cm2 is a pixel at 10 m, 40 cm2 one at 60 m, 300 cm2 one
# at 170 m - the long thin fan triangles of the wheel arches are not cut
SPLIT_MIN_M2 = (2.0e-4, 4.0e-3, 3.0e-2)
THIN_FAR_M = 0.10            # stripes thinner than this (m) are left out at the far level (Police.bands_at)


# --- the patched steps of traffic3d ------------------------------------------------------------------------

def _row_segments(pts, levels):
    """For every livery level (z) the segment of a half section [(x, z)] it lies on: the first rising segment from
    the bottom up that spans it ([(segment index, z)], sorted). Levels outside the rising part are left out."""
    out = []
    for z in sorted(levels):
        for i in range(len(pts) - 1):
            z0, z1 = pts[i][1], pts[i + 1][1]
            if z1 > z0 + 1e-6 and z0 <= z < z1:
                out.append((i, z))
                break
    return out


def _insert_rows(pts, segs):
    """The half section with one point per livery level on its segment (clamped to the segment's ends where the
    section does not reach the level there: over a wheel arch the point sits on the arch edge). Every station gets
    the same number of points at the same indices - the loft connects them by index."""
    out = []
    by_seg = {}
    for i, z in segs:
        by_seg.setdefault(i, []).append(z)
    for i, p in enumerate(pts):
        out.append(p)
        if i in by_seg and i + 1 < len(pts):
            q = pts[i + 1]
            for z in sorted(by_seg[i]):
                dz = q[1] - p[1]
                t = 0.0 if abs(dz) < 1e-9 else min(1.0, max(0.0, (z - p[1]) / dz))
                out.append((p[0] + (q[0] - p[0]) * t, p[1] + dz * t))
    return out


def _recap(soup, levels, check_x):
    """Triangulates the flat end caps of a loft soup (faces at its first / last station, looking along -y / +y)
    anew: the cap outline with the livery lines z = level (and the check lines x = v between their heights) as
    constraint edges (mathutils.geometry.delaunay_2d_cdt). check_x: [(x, z0, z1)]."""
    from mathutils import Vector
    from mathutils import geometry as mgeo
    if soup.n == 0 or not levels:
        return
    pos, nor, mi = soup.pos, soup.nor, soup.mi
    fn = np.cross(pos[:, 1] - pos[:, 0], pos[:, 2] - pos[:, 0])
    fn = fn / np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    keep = np.ones(soup.n, dtype=bool)
    new_p, new_n, new_m = [], [], []
    for sign, y_end in ((-1.0, pos[:, :, 1].min()), (1.0, pos[:, :, 1].max())):
        cap = (fn[:, 1] * sign > 0.999) & (np.abs(pos[:, :, 1] - y_end).max(axis=1) < 1e-5)
        if cap.sum() < 3:
            continue
        mats = np.unique(mi[cap])
        if mats.size != 1:
            continue
        # outline: edges of the cap triangles used once, chained in their winding
        cp = pos[cap][:, :, [0, 2]]
        key = {}
        verts = []

        def vid(p):
            k = (round(float(p[0]) * 1e6), round(float(p[1]) * 1e6))
            if k not in key:
                key[k] = len(verts)
                verts.append((float(p[0]), float(p[1])))
            return key[k]
        tri = [[vid(t[i]) for i in range(3)] for t in cp]
        count = {}
        for a, b, c in tri:
            for e in ((a, b), (b, c), (c, a)):
                count[tuple(sorted(e))] = count.get(tuple(sorted(e)), 0) + 1
        nxt = {}
        for a, b, c in tri:
            for e in ((a, b), (b, c), (c, a)):
                if count[tuple(sorted(e))] == 1:
                    nxt[e[0]] = e[1]
        if not nxt:
            continue
        start = min(nxt)
        loop = [start]
        v = nxt[start]
        while v != start and v in nxt and len(loop) <= len(nxt):
            loop.append(v)
            v = nxt[v]
        if v != start or len(loop) != len(nxt):
            continue                     # not one simple outline: leave the cap as it is
        poly = [verts[i] for i in loop]
        xs = [p[0] for p in poly]
        zs = [p[1] for p in poly]
        edges = []
        cverts = [Vector(p) for p in poly]
        for z in levels:
            if min(zs) < z < max(zs):
                cverts += [Vector((min(xs) - 0.01, z)), Vector((max(xs) + 0.01, z))]
                edges.append((len(cverts) - 2, len(cverts) - 1))
        for (x, z0, z1) in check_x:
            if min(xs) < x < max(xs):
                cverts += [Vector((x, z0)), Vector((x, z1))]
                edges.append((len(cverts) - 2, len(cverts) - 1))
        out = mgeo.delaunay_2d_cdt(cverts, edges, [list(range(len(poly)))], 1, 1e-7, True)
        vco, faces = out[0], out[2]
        n0 = nor[cap][0, 0]
        for f in faces:
            if len(f) != 3:
                continue
            q = [(vco[i][0], y_end, vco[i][1]) for i in f]
            a = np.cross(np.subtract(q[1], q[0]), np.subtract(q[2], q[0]))
            if a[1] * sign < 0:
                q = q[::-1]
            if np.linalg.norm(a) < 1e-12:
                continue
            new_p.append(q)
            new_n.append([n0, n0, n0])
            new_m.append(int(mats[0]))
        keep &= ~cap
    if not new_p:
        return
    soup.pos = np.concatenate([pos[keep], np.array(new_p, dtype=np.float64)])
    soup.nor = np.concatenate([nor[keep], np.array(new_n, dtype=np.float64)])
    soup.mi = np.concatenate([mi[keep], np.array(new_m, dtype=np.int32)])
    soup.n = soup.pos.shape[0]


@contextlib.contextmanager
def _hooks(pol):
    """For the time of one build: traffic3d.traffic_design without roof rails and without rear decals under the
    rear word (the badge); decalgeo.car_surfaces followed by the livery and the words (pol.apply); the lower body
    of SmoothCar with a row of loft points at every livery level (pol.rows_on) - the edges of the bands are then
    edges of the loft (a cut along a line through the quads of a flank costs twice the triangles of a row)."""
    from cesprites import carbody as CB

    from . import traffic3d as T
    orig_design, orig_surfaces, orig_lower = T.traffic_design, decalgeo.car_surfaces, CB.SmoothCar.lower_half
    orig_bumper = CB.SmoothCar.bumper_half_fn

    def lower_half(self, y):
        pts, k_sh, f = orig_lower(self, y)
        if not pol.rows_on:
            return pts, k_sh, f
        segs = self.__dict__.get("_police_rows")
        if segs is None:
            ref = orig_lower(self, 0.5 * (self.lb0 + self.lb1))[0]
            segs = _row_segments(ref, pol.row_levels(pol.cur_level))
            self._police_rows = segs
        return _insert_rows(pts, segs), k_sh + sum(1 for (i, _z) in segs if i < k_sh), f

    def bumper_half_fn(self, which):
        """The bumper lofts get the livery rows, too (reference: the bumper at its full height, next to the
        wheel arch)."""
        half = orig_bumper(self, which)
        if not pol.rows_on:
            return half
        y_ref = (self.y_ra - self.Ra - 0.06) if which == "rear" else (self.y_fa + self.Ra + 0.06)
        segs = _row_segments(half(y_ref)[0], pol.row_levels(pol.cur_level))

        def half_rows(y):
            res = half(y)
            return (_insert_rows(res[0], segs),) + tuple(res[1:])
        return half_rows

    def design(name):
        d = orig_design(name)
        d.setdefault("extras", {}).pop("roof_rails", None)
        box = pol.rear_word_box()
        if box is not None:
            keep = []
            for dec in d.get("body_decals_3d", []):
                if dec.get("face") == "rear" and not dec.get("lamp") and not dec.get("emit"):
                    pts = np.array(dec["poly"], dtype=np.float64).reshape(-1, 2)
                    cx, cz = float(pts[:, 0].mean()), float(pts[:, 1].mean())
                    if box[0] <= cx <= box[2] and box[1] <= cz <= box[3]:
                        continue            # the badge would show between the letters of the word
                keep.append(dec)
            d["body_decals_3d"] = keep
        return d

    def surfaces(car, soups, *args, **kw):
        level = int(kw.get("level", args[1] if len(args) > 1 else 0))
        # the flat end caps of the lower body and the bumpers are fans of long triangles over the whole width: every
        # livery line crossed all of them. Triangulated anew with the livery lines as edges, they cost nothing
        bumpers = [ob.name for ob in getattr(car, "bumper_obs", {}).values()]
        for name in [car.body.name] + bumpers:
            if name in soups:
                ends = pol.ends_here(level, name in bumpers)
                _recap(soups[name], sorted(set(pol.row_levels(level)) | set(pol.end_rows(level) if ends else [])),
                       pol.check_x(level) if ends else [])
        pal, tris, stats = orig_surfaces(car, soups, *args, **kw)
        stats["police"] = pol.apply(car, pal, tris, level)
        return pal, tris, stats

    T.traffic_design, decalgeo.car_surfaces, CB.SmoothCar.lower_half = design, surfaces, lower_half
    CB.SmoothCar.bumper_half_fn = bumper_half_fn
    try:
        yield
    finally:
        T.traffic_design, decalgeo.car_surfaces, CB.SmoothCar.lower_half = orig_design, orig_surfaces, orig_lower
        CB.SmoothCar.bumper_half_fn = orig_bumper


# --- livery and words ----------------------------------------------------------------------------------------

def _split_coord(t, k, value, where=None):
    """decalgeo.Tris.split_z for the coordinate k (0 x, 1 y, 2 z): splits the triangles the plane crosses."""
    if k == 2:
        t.split_z(value, where)
        return
    perm = [0, 1, 2]
    perm[k], perm[2] = 2, k
    t.pos = t.pos[:, :, perm]
    t.nor = t.nor[:, :, perm]
    try:
        t.split_z(value, where)
    finally:
        t.pos = t.pos[:, :, perm]
        t.nor = t.nor[:, :, perm]


def _hex_mix(a, b):
    """Mean of two sRGB colours in linear light, as sRGB hex."""
    return core.lin_to_hex((core.hex_to_lin(a) + core.hex_to_lin(b)) * 0.5)


class _Police:
    """Livery and words of one police set; apply() runs on the cut surfaces of every level."""

    def __init__(self, cc, p, design):
        from cesprites import police as P
        self.cc = cc
        self.p = p
        self.base = p["model"]
        self.design = design
        self.bands, self.word_z, self.word_bg = P.livery(p["style"], design, p["body"], p["c1"], p["c2"])
        self.rear_word = P.REAR_WORD[self.base]           # (z centre, max width, text height)
        self.rear_extent = None                           # x half width of the rear word (set by apply at lod0)
        self.word_colors = (P._text_on(self.word_bg, p["c1"]),
                            P._text_on(P._bg_at(self.bands, p["body"], self.rear_word[0]), p["c1"]))
        self.stats = {}
        self.rows_on = True              # _hooks: livery rows in the lower body (not for the shadow caster)
        self.cur_level = 0               # the level being built (0, 1, 2)

    def bands_at(self, level):
        """The bands a level shows: the far level leaves out stripes thinner than THIN_FAR_M (a pin stripe of 3 - 7 cm
        is a third of a pixel at 120 m; each of its lines costs a row or a cut along the whole car)."""
        if level < 2:
            return list(self.bands)
        return [b for b in self.bands if b["z"][1] - b["z"][0] >= THIN_FAR_M]

    def row_levels(self, level):
        """Heights of the livery lines of a level: band edges and the rows of the checks where the level shows them."""
        out = set()
        for b in self.bands_at(level):
            out.update(round(float(v), 5) for v in b["z"])
            if "check" in b and level < CHECK_FAR_LEVEL:
                ch = b["check"][1]
                z = b["z"][0] + ch
                while z < b["z"][1] - 1e-4:
                    out.add(round(z, 5))
                    z += ch
        return sorted(v for v in out if v > 0.0)

    @staticmethod
    def ends_here(level, bumper):
        """Whether a soup shows the cells of a check band on its ends at a level: everywhere up to CHECK_FAR_LEVEL,
        then only the bumpers - the ends of the lower body lie behind them in the band (at lod1 their cells cost 770
        hidden triangles), above the bumpers remains a strip of a few cm in the mean colour (below a pixel at 40 m)."""
        return level < CHECK_FAR_LEVEL or (bumper and level < CHECK_END_LEVEL)

    def end_rows(self, level):
        """The row lines of the checks on the ends of a level where its flanks show the mean (no loft rows there)."""
        out = []
        if not CHECK_FAR_LEVEL <= level < CHECK_END_LEVEL:
            return out
        for b in self.bands_at(level):
            if "check" in b:
                ch = b["check"][1]
                z = b["z"][0] + ch
                while z < b["z"][1] - 1e-4:
                    out.append(round(z, 5))
                    z += ch
        return out

    def check_x(self, level):
        """The cell lines of the checks on the ends of the car: [(x, z0, z1)] (none where the level shows the mean)."""
        out = []
        if level >= CHECK_END_LEVEL:
            return out
        for b in self.bands_at(level):
            if "check" in b:
                cw = b["check"][0]
                for k in range(-6, 7):
                    out.append((round(k * cw, 5), b["z"][0], b["z"][1]))
        return out

    def rear_word_box(self):
        """(x0, z0, x1, z1) around the rear word (with some room) - rear decals there go."""
        zc, maxw, rh = self.rear_word
        return (-0.5 * maxw - 0.03, zc - 0.6 * rh - 0.02, 0.5 * maxw + 0.03, zc + 0.6 * rh + 0.02)

    # -- materials of the palette
    def _slot(self, pal, base_data, slot):
        d = dict(base_data)
        d["slot"] = slot
        return pal.add("police_" + slot, "paint", d)

    def _colour_index(self, pal, base_data, i_paint, col):
        """Palette index of a livery colour: the paint slot that carries it, else a fixed colour."""
        p = self.p
        if col == p["c1"]:
            return self._slot(pal, base_data, "paint2")
        if col == p["c2"]:
            return self._slot(pal, base_data, "paint3")
        if col == p["body"]:
            return i_paint
        return pal.add("police_fixed_" + col, "flat", dict(color=col, rough=base_data.get("rough", 0.3),
                                                           metal=base_data.get("metal", 0.1)))

    def apply(self, car, pal, tris, level):
        i_paint = pal._index["paint"]
        base_data = pal.items[i_paint][1]
        st = dict(before=int(sum(t.pos.shape[0] for t in tris.values())))
        bumpers = {ob.name for ob in getattr(car, "bumper_obs", {}).values()}
        for name in sorted(tris):
            n0 = tris[name].pos.shape[0]
            self._bands(tris[name], pal, base_data, i_paint, level, self.ends_here(level, name in bumpers))
            st["bands_" + name.split("_")[-1]] = int(tris[name].pos.shape[0] - n0)
        st["bands"] = int(sum(t.pos.shape[0] for t in tris.values())) - st["before"]
        if level == 0:
            n0 = int(sum(t.pos.shape[0] for t in tris.values()))
            self._words(car, tris[car.body.name], pal)
            st["words"] = int(sum(t.pos.shape[0] for t in tris.values())) - n0
        self.stats["lod%d" % level] = st
        return st

    def _bands(self, t, pal, base_data, i_paint, level, ends=True):
        """ends: the soup shows the cells of a check band on its ends (_Police.ends_here)."""
        bands = self.bands_at(level)
        if not bands:
            return
        lines = set(self.row_levels(level))
        thr = SPLIT_MIN_M[min(level, 2)]
        amin = SPLIT_MIN_M2[min(level, 2)]

        def big(k):
            """Triangles that are cut along a line across coordinate k: larger than the level's thresholds - in the
            direction across the line and in area. A smaller one takes the colour of its centre: the fans of the
            wheel arches and the lips around them cost hundreds of triangles per line, and their colour error is
            far below a pixel at the distances of the level."""
            e = t.pos[:, :, k]
            area = 0.5 * np.linalg.norm(np.cross(t.pos[:, 1] - t.pos[:, 0], t.pos[:, 2] - t.pos[:, 0]), axis=1)
            return ((e.max(axis=1) - e.min(axis=1)) > thr) & (area > amin)
        for z in sorted(lines):
            t.split_z(z, where=(t.mat == i_paint) & big(2))
        # the faces that look up keep the body colour - only where a band lies (the line nz = 0.75 runs over the
        # whole car: split everywhere it cost a thousand triangles at lod1)
        zlo, zhi = min(b["z"][0] for b in bands), max(b["z"][1] for b in bands)
        zc = t.pos[:, :, 2].mean(axis=1)
        t.split_level((0.0, 0.0, 1.0), NOT_TOP, where=(t.mat == i_paint) & (zc > zlo) & (zc < zhi) & big(2))
        checks = [b for b in bands if "check" in b]
        ends_only = CHECK_FAR_LEVEL <= level
        if checks and ends:
            for b in checks:
                z0, z1 = b["z"]
                cw, ch = b["check"][0], b["check"][1]

                def inside():
                    zc = t.pos[:, :, 2].mean(axis=1)
                    return (t.mat == i_paint) & (zc > z0) & (zc < z1)

                def flank():
                    n = t.nor.mean(axis=1)
                    return np.abs(n[:, 0]) > np.abs(n[:, 1])
                if ends_only:
                    # the rows of the cells are no loft rows here (the flanks show the mean): split the ends along
                    # them; a face where the normal turns takes the side of its mean normal
                    z = z0 + ch
                    while z < z1 - 1e-4:
                        t.split_z(z, where=inside() & ~flank() & big(2))
                        z += ch
                else:
                    # side faces count the cells along y, the ends along x (materials.surface: |nx| > |ny|): split
                    # where the smooth normal turns from one to the other, then along the cell lines
                    for axis in ((1.0, -1.0, 0.0), (1.0, 1.0, 0.0)):
                        t.split_level(axis, 0.0, where=inside() & big(2))
                for k, lo, hi in ((1, 0.0, _car_len(t)), (0, -1.2, 1.2)):
                    if ends_only and k == 1:
                        continue
                    v = math.floor(lo / cw) * cw
                    while v <= hi:
                        side = flank()
                        _split_coord(t, k, v, where=inside() & (side if k == 1 else ~side) & big(k))
                        v += cw
        zc = t.pos[:, :, 2].mean(axis=1)
        nz = t.nor.mean(axis=1)[:, 2]
        n = t.nor.mean(axis=1)
        side = np.abs(n[:, 0]) > np.abs(n[:, 1])
        paint = t.mat == i_paint
        new = t.mat.copy()
        for b in bands:
            z0, z1 = b["z"]
            m = paint & (zc >= z0) & (zc <= z1)
            if b.get("not_top"):
                m &= nz < NOT_TOP
            if not m.any():
                continue
            if "check" in b:
                cw, ch, c2 = b["check"]
                cells = m
                if level >= CHECK_FAR_LEVEL:
                    # flanks (and where the soup shows no cells on its ends, everything): the mean of the two colours
                    cells = m & ~side if ends else np.zeros_like(m)
                    new[m & ~cells] = self._colour_index(pal, base_data, i_paint, _hex_mix(b["color"], c2))
                    if not cells.any():
                        continue
                c = t.pos.mean(axis=1)
                u = np.where(side, c[:, 1], c[:, 0])
                par = (np.floor(u / cw) + np.floor((c[:, 2] - z0) / ch)).astype(np.int64) % 2
                i1 = self._colour_index(pal, base_data, i_paint, b["color"])
                i2 = self._colour_index(pal, base_data, i_paint, c2)
                new[cells & (par == 0)] = i1
                new[cells & (par == 1)] = i2
            else:
                new[m] = self._colour_index(pal, base_data, i_paint, b["color"])
        t.mat = new

    def _glyphs(self, rig, word, size):
        return glyph_outlines(rig, word, size)

    def _words(self, car, t, pal):
        from cesprites.vehicles import interp
        d = self.design
        word = self.p["word"]
        i_side = pal.add("police_word_side", "flat", dict(color=self.word_colors[0], rough=0.35, metal=0.0))
        i_rear = pal.add("police_word_rear", "flat", dict(color=self.word_colors[1], rough=0.35, metal=0.0))
        # flanks: on the doors, centred between the axles (cesprites.police._words)
        y_mid = (car.y_ra + car.y_fa) / 2 + 0.05
        span = (car.y_fa - car.y_ra) - 2 * car.Ra - 0.25
        th = min(0.16, (interp(d["lower"], y_mid) - d["clearance"]) * 0.2)
        def items_of(loops, mat, n_min, to_uv):
            """Outer contours in the word's colour, then the holes: they keep what lies under the word (mat None)
            and rank higher, so the top-most outline of a point decides (decalgeo.Tris.apply)."""
            out = []
            for lp, hole in loops:
                out.append(dict(poly=[to_uv(x, y) for (x, y) in lp], mat=None if hole else mat,
                                rank=WORD_RANK + (1 if hole else 0), n_min=n_min))
            return out

        def width(loops):
            xs = np.concatenate([lp[:, 0] for lp, _h in loops])
            return float(xs.max() - xs.min())
        g = self._glyphs(car.rig, word, th)
        w = width(g)
        k = min(1.0, span / w) if w > 0 else 1.0
        area0 = decalgeo._area3(t.pos)
        for sgn in (1, -1):
            t.apply("side", sgn, items_of(g, i_side, 0.5, lambda x, y, s=sgn: (y_mid + s * k * x, self.word_z + k * y)),
                    cut=True)
        # rear
        zc, maxw, rh = self.rear_word
        g = self._glyphs(car.rig, word, rh)
        w = width(g)
        k = min(1.0, maxw / w) if w > 0 else 1.0
        self.rear_extent = 0.5 * w * k
        t.apply("rear", 1, items_of(g, i_rear, 0.35, lambda x, y: (k * x, zc + k * y)), cut=True)
        lost = area0 - decalgeo._area3(t.pos)
        if abs(lost) > 1.0e-4:
            raise RuntimeError("police %s: the words changed the surface by %.1f cm2" % (self.cc, lost * 1e4))


def glyph_outlines(rig, word, size, res=None):
    """Outlines of the word in its own plane (x reading, y up), centred: [(points (N, 2), is_hole)], outer
    contours first. The text is set as the sprite sets it (cesprites.textgeo.text_mesh: the font Blender ships,
    bold offset 0.035 x size), at curve resolution WORD_RES; the outlines are the boundary loops of its fill,
    a loop inside an odd number of others is a hole (the counter of an O, P, A ...)."""
    import bpy

    from cesprites import textgeo
    cu = bpy.data.curves.new("pol_word_tmp", "FONT")
    cu.body = word
    cu.font = textgeo.font()
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.offset = 0.035 * size
    cu.extrude = 0.0
    cu.resolution_u = WORD_RES if res is None else res
    ob = bpy.data.objects.new("pol_word_tmp", cu)
    rig.col.objects.link(ob)
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(deps))
    bpy.data.objects.remove(ob)
    me.calc_loop_triangles()
    co = np.array([v.co[:2] for v in me.vertices], dtype=np.float64)
    tris = [lt.vertices[:] for lt in me.loop_triangles]
    bpy.data.meshes.remove(me)
    # boundary edges in the winding of their triangle: the filled glyph lies on the same side of every one
    # of them, so an outline turns the way the triangles turn and a hole the other way. (Containment does not
    # work: with the bold offset of the sprite text neighbouring letters overlap - the L of POLIZEI lay in
    # the O and came out as a hole.)
    count = {}
    for vs in tris:
        for i in range(3):
            a, b = vs[i], vs[(i + 1) % 3]
            count[(min(a, b), max(a, b))] = count.get((min(a, b), max(a, b)), 0) + 1
    nxt = {}
    turn = 0.0
    for vs in tris:
        p = co[list(vs)]
        turn += (p[1, 0] - p[0, 0]) * (p[2, 1] - p[0, 1]) - (p[2, 0] - p[0, 0]) * (p[1, 1] - p[0, 1])
        for i in range(3):
            a, b = vs[i], vs[(i + 1) % 3]
            if count[(min(a, b), max(a, b))] == 1:
                nxt.setdefault(a, []).append(b)
    loops, used = [], set()
    for start in sorted(nxt):
        for first in nxt[start]:
            if (start, first) in used:
                continue
            loop, cur, v = [start], start, first
            used.add((start, first))
            while v != start:
                loop.append(v)
                cand = [w for w in nxt.get(v, []) if (v, w) not in used]
                if not cand:
                    break
                used.add((v, cand[0]))
                cur, v = v, cand[0]
            if v == start and len(loop) >= 3:
                loops.append(co[loop])
    out = []
    for lp in loops:
        area = decalgeo._area2([tuple(p) for p in lp])
        out.append((lp, area * turn < 0.0))
    out.sort(key=lambda e: e[1])
    return out


def _car_len(t):
    """Largest y of a triangle set (the length of the car in build space) and some room."""
    return float(t.pos[:, :, 1].max()) + 0.3


# --- the light bar -------------------------------------------------------------------------------------------

def _roof(sc, car):
    """(y, roof height at the centre line, function x -> roof height) where the bar stands: the middle of the flat
    roof + 0.15 m (cesprites.police._roof), on the greenhouse of the 3D build."""
    cab = car.d["cabin"]
    zr = max(q[1] for q in cab)
    flat = [q for q in cab if q[1] > zr - 0.07]
    y = (flat[0][0] + flat[-1][0]) / 2 + 0.15
    gh = sc.green_half(y)[1]

    def at(x):
        x = abs(x)
        if x <= gh["x_rc"]:
            return gh["zr"] - gh["rc"] * (x / gh["x_rc"]) ** 2
        return gh["zr"] - gh["rc"] - (x - gh["x_rc"]) * 0.6
    return y, gh["zr"], at


def _rbox(MU, x0, x1, y0, y1, z0, z1, bm=None, drop_bottom=False):
    bm = MU.bm_box(x1 - x0, y1 - y0, z1 - z0, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), bm=bm)
    if drop_bottom:
        bm.normal_update()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z < -0.99 and abs(f.calc_center_median().z - z0) < 1e-6],
                         context="FACES")
    return bm


def _bar_objects(sc, car, level):
    """Blender objects of the light bar at a level (build space), parented to the rig root."""
    import json

    from cesprites import materials as M
    from cesprites import meshutil as MU
    y, z_top_roof, roof_at = _roof(sc, car)
    root = car.rig.root
    hw, hd = BAR_W / 2.0, BAR_D / 2.0
    zb = z_top_roof + FOOT_H                 # underside of the base
    z_base = zb + BASE_H
    z_top = z_top_roof + BAR_HEIGHT
    obs = []
    base = M.basic("pol_base", "#1b1c1f", rough=0.45, metal=0.2)
    white = M.basic("pol_white", "#d9dde2", rough=0.25)
    feet_mat = M.basic("pol_feet", "#2a2c2f", rough=0.5, metal=0.3)
    lamp_tags = {-1: "beacon_a:1:" + BEACON, 1: "beacon_b:1:" + BEACON}
    # feet on the roof (the roof falls off towards the sides)
    bm = bmesh.new()
    for fx in (-0.46, 0.46):
        for fy in (-0.085, 0.085):
            zf = roof_at(fx) - 0.01
            MU.bm_box(0.05, 0.05, zb - zf, (fx, y + fy, (zb + zf) / 2), bm=bm)
    if level <= 1:
        obs.append(MU.make("pol_feet", bm, feet_mat, parent=root))
    else:
        bm.free()
    if level == 0:
        # base tray, rounded
        ob = MU.make("pol_base", _rbox(MU, -hw, hw, y - hd, y + hd, zb, z_base), base, parent=root, smooth=True,
                     sharp_deg=40)
        m = MU.bevel(ob, 0.012, 2)
        m.harden_normals = True
        obs.append(ob)
        dome = M.glass("pol_dome", tint=DOME["color"], rough=DOME["rough"])
        data = json.loads(dome["ce_data"])
        data["opacity"] = DOME["opacity"]
        dome["ce_data"] = json.dumps(data, sort_keys=True)
        chrome = M.basic("pol_reflector", "#c9ccd1", rough=0.15, metal=0.9)
        for sgn in (-1, 1):
            xa, xb = sorted((sgn * (MID_W / 2 + 0.005), sgn * (hw - 0.005)))
            # clear dome over the modules: a rounded box without its floor (it stands on the base)
            ob = MU.make("pol_dome", _rbox(MU, xa, xb, y - hd + 0.012, y + hd - 0.012, z_base, z_top, drop_bottom=True),
                         dome, parent=root, smooth=True, sharp_deg=40)
            m = MU.bevel(ob, 0.028, 3, angle_deg=40.0)
            m.harden_normals = True
            obs.append(ob)
            # reflector bed and three LED modules inside (lit on top and on all sides: a beacon is seen from
            # everywhere; the anchor looks up)
            bm = _rbox(MU, xa + 0.02, xb - 0.02, y - hd + 0.045, y + hd - 0.045, z_base, z_base + 0.012)
            obs.append(MU.make("pol_reflector", bm, chrome, parent=root))
            bm = bmesh.new()
            for i in range(3):
                cx = sgn * (MID_W / 2 + 0.02 + 0.079 + i * 0.168)      # three modules of 0.158 m from 0.095 to 0.59
                _rbox(MU, cx - 0.079, cx + 0.079, y - 0.11, y + 0.11, z_base + 0.012, z_base + 0.066, bm=bm,
                      drop_bottom=True)
            ob = MU.make("pol_led", bm, M.basic("pol_led", "#18265e", rough=0.15), parent=root)
            MU.tag(ob, lamp=lamp_tags[sgn])
            ob["ce_lamp"] = lamp_tags[sgn]
            obs.append(ob)
        ob = MU.make("pol_mid", _rbox(MU, -MID_W / 2, MID_W / 2, y - hd + 0.02, y + hd - 0.02, z_base, z_top - 0.012),
                     white, parent=root, smooth=True, sharp_deg=40)
        m = MU.bevel(ob, 0.012, 2)
        m.harden_normals = True
        obs.append(ob)
    else:
        # lod1 / lod2: the outline as blocks - base, two lit lens blocks, the white middle
        obs.append(MU.make("pol_base", _rbox(MU, -hw, hw, y - hd, y + hd, zb, z_base), base, parent=root))
        for sgn in (-1, 1):
            # (the lit block of the far levels has the size of the modules of lod0, up to the top of the bar)
            xa, xb = sorted((sgn * (MID_W / 2 + 0.02), sgn * (MID_W / 2 + 0.515)))
            ob = MU.make("pol_lens", _rbox(MU, xa, xb, y - 0.11, y + 0.11, z_base, z_top, drop_bottom=True),
                         M.basic("pol_lens_far", "#18265e", rough=0.15), parent=root)
            ob["ce_lamp"] = lamp_tags[sgn]
            obs.append(ob)
        obs.append(MU.make("pol_mid", _rbox(MU, -MID_W / 2, MID_W / 2, y - hd + 0.02, y + hd - 0.02, z_base, z_top - 0.012,
                                            drop_bottom=True), white, parent=root))
    return obs, (y, zb, z_top)


def _shadow_bar(mb, sc, car):
    """The bar in the shadow caster, inside the visible bar of every level: the base, a block in each LED module of
    lod0 (= inside the lens blocks of lod1 / lod2) and the white middle, all at least 1 cm in. (One block over the
    whole bar enclosed the modules and the lens blocks: they lay in its shadow by day and looked dark.)"""
    from .truck3d import _box_faces
    from .vehicles3d import GREY
    y, z_roof, _at = _roof(sc, car)
    e = 0.01
    hw, hd = BAR_W / 2.0, BAR_D / 2.0
    zb = z_roof + FOOT_H
    z_base = zb + BASE_H
    z_top = z_roof + BAR_HEIGHT
    boxes = [(-hw + e, hw - e, y - hd + e, y + hd - e, zb + e, z_base - e),
             (-MID_W / 2 + 0.015, MID_W / 2 - 0.015, y - hd + 0.035, y + hd - 0.035, z_base - 2 * e, z_top - 0.025)]
    for sgn in (-1, 1):
        for i in range(3):
            cx = sgn * (MID_W / 2 + 0.02 + 0.079 + i * 0.168)          # the modules of _bar_objects
            # y: inside the reflector bed of lod0 (+-0.095) and the modules / lens blocks (+-0.11)
            boxes.append((cx - 0.069, cx + 0.069, y - 0.085, y + 0.085, z_base - 2 * e, z_base + 0.056))
    pos, nor = [], []
    for b in boxes:
        f = _box_faces(*b, faces="rflRt")
        pos += [q[0] for q in f.values()]
        nor += [q[1] for q in f.values()]
    mb.add("vpbr", np.concatenate(pos), np.concatenate(nor), GREY, (0.8, 0.0), roles.NO_LAMP)


# --- the model -------------------------------------------------------------------------------------------------

def build_police(model_id, spec3d):
    from cesprites import catalog, designs

    from . import catalog3d
    from . import traffic3d as T
    from .vehicles3d import SLIVER_M, _add_soup, _sprite_spec, _wheel_parts
    t0 = time.time()
    cc = spec3d["cc"]
    p = catalog.POLICE[cc]
    base = p["model"]
    traffic = catalog3d.MODELS["traffic/" + base]
    # the traffic car's own options (detail per level, far sill), police overrides on top
    detail = copy.deepcopy(traffic.get("detail", {}))
    for lv, over in spec3d.get("detail", {}).items():
        detail.setdefault(lv, {}).update(over)
    tspec = dict(design=base, detail=detail, far_sill=spec3d.get("far_sill", traffic.get("far_sill", True)))
    pol = _Police(cc, p, designs.TRAFFIC_MODELS[base])
    metal = float(p.get("metal", 0.12))
    sspec = _sprite_spec(spec3d["source"])
    lods = []
    stats = {}
    model = None
    fine = None
    with _hooks(pol):
        for level in ("lod0", "lod1", "lod2"):
            pol.cur_level = {"lod0": 0, "lod1": 1, "lod2": 2}[level]
            car, sc, nodes, pivots, origin, tr, st, lofts = T._level(tspec, level, p["body"], metal, fine)
            lv = {"lod0": 0, "lod1": 1, "lod2": 2}[level]
            obs, bar = _bar_objects(sc, car, lv)
            for s in core.soups_of(obs):
                _add_soup(nodes, tr, s, "body")
            stats[level] = dict(st, bar=sum(s.n for s in core.soups_of(obs)))
            if level == "lod0":
                fine = lofts
                size = car.object_size()
                size["height_m"] = round(size["height_m"] + BAR_HEIGHT, 3)
                model = ModelData(model_id, "vehicle", size)
                pts = np.concatenate([mb.points() for mb in nodes.values()])
                model.extent_m = sprite_extent(pts - origin, 0.0)
                model.lights = tr.lights(origin=origin)
                same = "tw_r" not in sc.d
                parts = [Part("body", "lod0_body", nodes["body"].finish(origin=origin, min_height=SLIVER_M))]
                parts += _wheel_parts(nodes, pivots, origin, sc.R, "wheel", same)
                lods.append(Lod("lod0", LOD.VEHICLE_LOD_DIST["lod0"], parts))
                stats["bar_m"] = [round(float(v), 3) for v in bar]
            else:
                lods.append(Lod(level, LOD.VEHICLE_LOD_DIST[level],
                                [Part("body", level + "_body", nodes["body"].finish(origin=origin, min_height=SLIVER_M))]))
        pol.rows_on = False
        car, sc, nodes, _p, origin, _tr, stats["shadow"], _l = T._level(tspec, "shadow", p["body"], metal, fine)
        _shadow_bar(nodes["body"], sc, car)
    model.shadow = Part("body", "shadow", nodes["body"].finish(origin=origin, min_height=SLIVER_M))
    model.lods = lods
    paint = {"paint": p["body"], "paint2": p["c1"], "paint3": p["c2"], "metal": metal}
    model.paint = paint
    model.tags = list(sspec.get("tags", []))
    for sid in (spec3d.get("sets") or [model_id]):
        model.sets[sid] = {"model": model_id, "paint": dict(paint)}
    model.stats = dict(build_s=round(time.time() - t0, 2), levels=stats, livery=pol.stats)
    return model
