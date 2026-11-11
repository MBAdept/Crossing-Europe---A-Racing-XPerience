"""Special crowns of the card trees (AS3; docs/modelle.md section 15): the species whose sprite crown is not a set of
blobs - spruce (tiers of cones), cypress (a lathe flame) and palm (fronds on a curved, ringed trunk). The generator
logs their shapes (cesprites/props_nature.SHAPE_LOG); wood, wind data, fitting to the sprite, impostor and model data
are those of the card-tree builder (ce3d/veg3d.py).

  spruce   every tier of the generator: a closed inner cone in the core cell of the atlas (needle mass; its underside
           faces down and stays dark - the tiers seen from the road), on its top surface sector cards with a branch
           spray each (twig from the trunk to the drooping tip, needles), lod0 two layers turned half a sector
  cypress  blobs laid along the generator's lathe profile (a column of leaf balls that fills the flame), then the
           blob builder of the broadleaf trees: leaf domes, core from the crown's axis, fit to the sprite
  palm     the trunk rebuilt with a ring every RING_M metres (colour bands and a slight bulge per ring); every frond of
           the generator a bent strip along its spine (base to tip), folded to a shallow V, textured with a pinnate
           frond (leaflets); a dark crown shaft and the nuts; no low-poly caster (the fronds cast their leaflets)
"""
import math
import random
import time

import numpy as np

from . import core, leafatlas, roles
from . import veg3d as V

RING_M = 0.24            # palm trunk: one ring per 0.24 m (the generator's bark: rings = 26 per radian of z)


def build(model_id, spec3d, sp, t0):
    sspec, info, wood_soups, crown_pts, blobs, shape = V._source(spec3d, shapes=True)
    kind = sp["shape"]
    if kind == "cypress":
        return _cypress(model_id, spec3d, sp, sspec, info, wood_soups, crown_pts, shape, t0)
    if kind == "spruce":
        return _spruce(model_id, spec3d, sp, sspec, info, wood_soups, crown_pts, shape, t0)
    if kind == "palm":
        return _palm(model_id, spec3d, sp, sspec, info, wood_soups, crown_pts, shape, t0)
    raise ValueError("unknown crown shape %r" % kind)


def _brightness(nor, ao, sp):
    lo, hi, g = sp["ao"]
    return np.clip((lo + (hi - lo) * np.power(np.clip(ao, 0.0, 1.0), g)) * V._sky(nor, sp), 0.08, 1.0)


def _cols(n_vert, amp, phase, stiff, bright):
    col = np.empty((n_vert, 4))
    col[:, 0] = amp
    col[:, 1] = phase
    col[:, 2] = stiff
    col[:, 3] = bright
    return col


def _add_tris(mb, cls, pos, nor, col, uv, tri):
    t = np.asarray(tri, dtype=np.int64)
    mb.add(cls, pos[t], nor[t], np.clip(np.round(col[t] * 255.0), 0, 255).astype(np.uint8), uv[t])


# --- cypress -----------------------------------------------------------------------------------------------------

def _cypress_blobs(prof, seed):
    """A column of blobs that fills the generator's lathe flame: at every height a ring of blobs whose outer surface
    lies on the profile's radius (one blob on the axis where the flame is thin)."""
    rng = random.Random(seed * 31 + 5)
    hs = np.array([h for (_r, h) in prof])
    rs = np.array([r for (r, _h) in prof])
    blobs = []
    z = float(hs.min()) + 0.3
    top = float(hs.max())
    while z < top - 0.2:
        R = float(np.interp(z, hs, rs))
        if R < 0.3:
            n, br, d = 1, max(0.16, R * 1.05), 0.0
        elif R < 0.75:
            n, br, d = 3, R * 0.68, R * 0.42
        else:
            n, br, d = 4, R * 0.62, R * 0.5
        a0 = rng.uniform(0.0, 2.0 * math.pi)
        for k in range(n):
            a = a0 + 2.0 * math.pi * k / n + rng.uniform(-0.25, 0.25)
            dd = d * rng.uniform(0.9, 1.1)
            blobs.append(((dd * math.cos(a), dd * math.sin(a), z + rng.uniform(-0.1, 0.1)), br * rng.uniform(0.92, 1.08),
                          1.3))
        z += max(0.22, br * 0.95)
    return blobs


def _hash_noise(a, h, seed):
    """Smooth deterministic noise of (angle, height) in -1 .. 1 (the lumps of the displaced sprite flame)."""
    return (np.sin(a * 3.0 + h * 1.7 + seed) * 0.5 + np.sin(a * 7.0 - h * 3.1 + seed * 2.3) * 0.3
            + np.sin(h * 5.3 + seed * 0.7) * 0.2)


def _cypress_level(prof, segs, rings, seed, jitter=0.07):
    """The flame as a lathe of the generator's profile: per-vertex positions, normals (of the lathe), and the
    triangles - the radius a little lumpy (the generator displaces its lathe by 0.35 m)."""
    hs = np.array([h for (_r, h) in prof])
    rs = np.array([r for (r, _h) in prof])
    zs = np.linspace(float(hs.min()), float(hs.max()), rings + 1)
    pos, nor = [], []
    for i, z in enumerate(zs):
        r0 = float(np.interp(z, hs, rs))
        dr = (float(np.interp(z + 0.2, hs, rs)) - float(np.interp(z - 0.2, hs, rs))) / 0.4
        for k in range(segs):
            a = 2.0 * math.pi * k / segs + (0.5 * 2.0 * math.pi / segs if i % 2 else 0.0)
            r = r0 * (1.0 + jitter * float(_hash_noise(a, z, seed))) if 0 < i < rings else r0
            pos.append((r * math.cos(a), r * math.sin(a), z))
            n = np.array([math.cos(a), math.sin(a), -dr])
            n = n / np.linalg.norm(n) + np.array([0.0, 0.0, 0.12])
            nor.append(n / np.linalg.norm(n))
    tri = []
    for i in range(rings):
        for k in range(segs):
            a0, a1 = i * segs + k, i * segs + (k + 1) % segs
            b0, b1 = (i + 1) * segs + k, (i + 1) * segs + (k + 1) % segs
            if i % 2 == 0:
                tri += [(a0, a1, b0), (a1, b1, b0)]
            else:
                tri += [(a0, a1, b1), (a0, b1, b0)]
    return np.array(pos), np.array(nor), np.array(tri, dtype=np.int64)


def _cypress(model_id, spec3d, sp, sspec, info, wood_soups, crown_pts, shape, t0):
    """Cypress: the generator's lathe flame, smooth like the sprite's, with a dense sprig texture (the core cell of the
    atlas, every triangle laid flat into it) and a slightly lumpy outline."""
    prof = shape["profile"]
    seed = int(spec3d.get("params", {}).get("seed", 0)) + sp["atlas_seed"]
    wood_pts = np.concatenate([s.pos.reshape(-1, 3) for s in wood_soups])
    ref = np.concatenate([crown_pts, wood_pts])
    ref_lo, ref_hi = ref.min(axis=0), ref.max(axis=0)
    top_z = float(ref_hi[2])
    atlas_img, rects = V._leaf_atlas(sp)
    no_blob = (np.zeros((0, 3)), np.zeros(0), np.zeros(0))
    lv = [_cypress_level(prof, segs, rings, seed) for (segs, rings) in ((20, 30), (10, 14))]
    centre = np.array([0.0, 0.0, float(np.mean([h for (_r, h) in prof]))])
    fit = V._Fit(lv[0][0], wood_pts, ref_lo, ref_hi, centre)
    meshes, n_cards = {}, {}
    for li, name in enumerate(("lod0", "lod1")):
        p, n, t = lv[li]
        mb = core.MeshBuilder()
        wood = V._tree_wood(wood_soups, *no_blob, crown_bottom=0.0, sp=sp)
        V._add_wood(mb, sp, wood, top_z, *no_blob)
        hp = fit(p)[t]
        hn = n[t]
        cc = np.empty(hp.shape[:2] + (4,))
        cc[..., 0] = np.clip(hp[..., 2] / max(1.0, top_z), 0.0, 1.0) * 0.7
        cc[..., 1] = (seed % 97) / 97.0
        cc[..., 2] = sp["stiff"]
        # the folds of the flame: a vertex inside the lumps (radius below the profile) is a little darker
        cc[..., 3] = np.clip(sp["core"]["bright"] * V._sky(hn, sp), 0.08, 1.0)
        mb.add("leaves", hp, hn, np.clip(np.round(cc * 255.0), 0, 255).astype(np.uint8),
               V._core_uv(hp, rects["core"], 1.4))
        meshes[name] = mb
        n_cards[name] = 0
    sh = core.MeshBuilder()
    core_c = np.append(core.srgb8(core.hex_to_lin("#1c3220")), 255).astype(np.uint8)
    p, n, t = _cypress_level(prof, 8, 8, seed, 0.0)
    sh.add("vpbr", fit(p)[t] * np.array([0.95, 0.95, 1.0]), n[t], core_c, (0.92, 0.0), roles.NO_LAMP)
    card_sets = {"lod0": {"eff": fit(lv[0][0])}}
    return V._finish_tree(model_id, spec3d, sp, sspec, info, meshes, sh, card_sets, n_cards, wood_pts, atlas_img,
                          ref_lo, ref_hi, t0, dict(lathe=True))


# --- spruce ------------------------------------------------------------------------------------------------------

def _ring_at(ring, phi):
    """Point of a tier's ring (16 points around the trunk) at angle phi, interpolated in angle."""
    pts = np.array(ring)
    ang = np.mod(np.arctan2(pts[:, 1], pts[:, 0]), 2.0 * math.pi)
    order = np.argsort(ang)
    ang, pts = ang[order], pts[order]
    ang = np.concatenate([ang - 2.0 * math.pi, ang, ang + 2.0 * math.pi])
    pts = np.concatenate([pts, pts, pts])
    a = math.fmod(phi, 2.0 * math.pi)
    if a < 0.0:
        a += 2.0 * math.pi
    r = np.interp(a, ang, np.linalg.norm(pts[:, :2], axis=1))
    z = np.interp(a, ang, pts[:, 2])
    return np.array([r * math.cos(a), r * math.sin(a), z])


def _spruce_level(tiers, spike, sp, rects, core_rect, li, seed):
    """Tier cones and branch cards of one level: (cards dict for the class leaves: pos, nor, uv, col, tri; core dict;
    the opaque points for the fit)."""
    rng = random.Random(seed)
    n_sec = (9, 6)[li]
    layers = (2, 1)[li]
    cone_seg = (16, 8)[li]
    pos, nor, uv, col, tri = [], [], [], [], []
    cpos, cnor, cuv, ccol, ctri = [], [], [], [], []
    eff = []
    z_top = max(t[0] + t[2] for t in tiers)
    for ti, (z0, rad, hgt, ring) in enumerate(tiers):
        apex = np.array([0.0, 0.0, z0 + hgt])
        slope = hgt / max(0.2, rad)
        phase = rng.random()
        # inner cone: top surface apex -> ring, underside ring -> a point on the trunk
        under = np.array([0.0, 0.0, z0 + 0.25])
        rim = [_ring_at(ring, 2.0 * math.pi * k / cone_seg) * np.array([0.93, 0.93, 1.0]) for k in range(cone_seg)]
        o = len(cpos)
        cpos.append(apex)
        cnor.append(np.array([0.0, 0.0, 1.0]))
        for p in rim:
            d = p[:2] / max(1e-6, np.linalg.norm(p[:2]))
            cpos.append(p)
            n_top = np.array([slope * d[0], slope * d[1], 1.0])
            cnor.append(n_top / np.linalg.norm(n_top))
        cpos.append(under)
        cnor.append(np.array([0.0, 0.0, -1.0]))
        o_rim2 = len(cpos)
        for p in rim:
            d = p[:2] / max(1e-6, np.linalg.norm(p[:2]))
            cpos.append(p + np.array([0.0, 0.0, -0.02]))
            n_bot = np.array([d[0] * 0.6, d[1] * 0.6, -1.0])
            cnor.append(n_bot / np.linalg.norm(n_bot))
        for k in range(cone_seg):
            k2 = (k + 1) % cone_seg
            ctri.append((o, o + 1 + k, o + 1 + k2))
            ctri.append((o + 1 + cone_seg, o_rim2 + k2, o_rim2 + k))
        for _k in range(len(cpos) - len(ccol)):
            ccol.append(None)
        eff += [p for p in rim]
        # branch cards on the top surface: from near the apex out to the drooping tips beyond the rim
        for layer in range(layers):
            off = (0.5 if layer else 0.0) * 2.0 * math.pi / n_sec
            reach = 1.08 if layer == 0 else 1.14
            drop = (0.08 if layer == 0 else 0.16) * rad
            for k in range(n_sec):
                phi = 2.0 * math.pi * k / n_sec + off + rng.uniform(-0.12, 0.12)
                half = math.pi / n_sec * 1.25
                pl, pr = _ring_at(ring, phi - half), _ring_at(ring, phi + half)
                il = apex + (pl - apex) * 0.14
                ir = apex + (pr - apex) * 0.14
                ol = np.array([pl[0] * reach, pl[1] * reach, pl[2] - drop])
                orr = np.array([pr[0] * reach, pr[1] * reach, pr[2] - drop])
                lift = np.array([0.0, 0.0, 0.03 + 0.03 * layer])
                quad = [il + lift, ir + lift, orr + lift, ol + lift]
                b = len(pos)
                for q in quad:
                    d = q[:2] / max(1e-6, np.linalg.norm(q[:2]))
                    n = np.array([slope * d[0], slope * d[1], 1.0])
                    pos.append(q)
                    nor.append(n / np.linalg.norm(n))
                (ua, va, ub, vb) = rects[rng.randrange(len(rects))]
                # the twig's inner end (top of the cell) at the apex, the tip (bottom) at the rim
                uv += [(ua, va), (ub, va), (ub, vb), (ua, vb)]
                rr = [np.linalg.norm(q[:2]) / max(0.3, rad) for q in quad]
                for f in rr:
                    col.append([min(1.0, 0.25 + 0.75 * f), (phase + rng.uniform(-0.05, 0.05)) % 1.0, sp["stiff"],
                                0.55 + 0.45 * min(1.0, f)])
                tri += [(b, b + 1, b + 2), (b, b + 2, b + 3)]
                eff += [ol, orr]
    # the spike on top: a thin cone of the core cell
    if spike is not None:
        r, zc, depth = spike
        o = len(cpos)
        cpos.append(np.array([0.0, 0.0, zc + depth * 0.5]))
        cnor.append(np.array([0.0, 0.0, 1.0]))
        for k in range(6):
            a = 2.0 * math.pi * k / 6
            cpos.append(np.array([r * math.cos(a), r * math.sin(a), zc - depth * 0.5]))
            cnor.append(np.array([math.cos(a), math.sin(a), 0.4]) / math.sqrt(1.16))
        for k in range(6):
            ctri.append((o, o + 1 + k, o + 1 + (k + 1) % 6))
        ccol += [None] * 7
    cpos = np.array(cpos)
    cnor = np.array(cnor)
    # core: one atlas cell, every triangle laid flat into it (veg3d._core_uv works per triangle)
    cards = dict(pos=np.array(pos), nor=np.array(nor), uv=np.array(uv), col=np.array(col), tri=np.array(tri))
    cards["col"][:, 0] = np.clip(cards["col"][:, 0] * np.clip(cards["pos"][:, 2] / max(1.0, z_top), 0.0, 1.0), 0.0, 1.0)
    cards["col"][:, 3] = np.clip(cards["col"][:, 3] * V._sky(cards["nor"], sp), 0.08, 1.0)
    core_d = dict(pos=cpos, nor=cnor, tri=np.array(ctri))
    return cards, core_d, np.array(eff)


def _spruce(model_id, spec3d, sp, sspec, info, wood_soups, crown_pts, shape, t0):
    tiers = shape["tiers"]
    spike = shape.get("spike")
    wood_pts = np.concatenate([s.pos.reshape(-1, 3) for s in wood_soups])
    ref = np.concatenate([crown_pts, wood_pts])
    ref_lo, ref_hi = ref.min(axis=0), ref.max(axis=0)
    top_z = float(ref_hi[2])
    seed = int(spec3d.get("params", {}).get("seed", 0)) + sp["atlas_seed"]
    asp = leafatlas.species_atlas(dict(sp["atlas"], fringe=sp["fringe"]))
    atlas_img, rects = leafatlas.special_atlas("branch", asp, size=1024, seed=sp["atlas_seed"])
    no_blob = (np.zeros((0, 3)), np.zeros(0), np.zeros(0))
    levels = [_spruce_level(tiers, spike, sp, rects["leaf"], rects["core"], li, seed) for li in range(2)]
    centre = np.array([0.0, 0.0, float(np.mean([t[0] for t in tiers]))])
    fit = V._Fit(levels[0][2], wood_pts, ref_lo, ref_hi, centre)
    meshes, n_cards = {}, {}
    for li, name in enumerate(("lod0", "lod1")):
        cards, core_d, _eff = levels[li]
        mb = core.MeshBuilder()
        wood = V._tree_wood(wood_soups, *no_blob, crown_bottom=0.0, sp=sp)
        V._add_wood(mb, sp, wood, top_z, *no_blob)
        cp = fit(cards["pos"])
        V_ = dict(cards, pos=cp)
        V_["col"] = cards["col"].copy()
        _add_tris(mb, "leaves", V_["pos"], V_["nor"], V_["col"], V_["uv"], V_["tri"])
        hp = fit(core_d["pos"])[core_d["tri"]]
        hn = core_d["nor"][core_d["tri"]]
        cc = np.empty(hp.shape[:2] + (4,))
        cc[..., 0] = np.clip(hp[..., 2] / max(1.0, top_z), 0.0, 1.0) * 0.8
        cc[..., 1] = 0.0
        cc[..., 2] = 1.0
        cc[..., 3] = np.clip(sp["core"]["bright"] * V._sky(hn, sp), 0.05, 1.0)
        mb.add("leaves", hp, hn, np.clip(np.round(cc * 255.0), 0, 255).astype(np.uint8), V._core_uv(hp, rects["core"], 1.6))
        meshes[name] = mb
        n_cards[name] = int(cards["tri"].shape[0] // 2)
    # shadow caster: the tops of the inner cones + trunk
    sh = core.MeshBuilder()
    core_c = np.append(core.srgb8(core.hex_to_lin("#1c3220")), 255).astype(np.uint8)
    for _name, p, n in V._tree_wood(wood_soups, *no_blob, crown_bottom=0.0, sp=sp):
        sh.add("vpbr", p, n, core_c, (0.92, 0.0), roles.NO_LAMP)
    cd = levels[1][1]
    sh.add("vpbr", fit(cd["pos"])[cd["tri"]], cd["nor"][cd["tri"]], core_c, (0.92, 0.0), roles.NO_LAMP)
    card_sets = {"lod0": {"eff": fit(levels[0][2])}}
    return V._finish_tree(model_id, spec3d, sp, sspec, info, meshes, sh, card_sets, n_cards, wood_pts, atlas_img,
                          ref_lo, ref_hi, t0, dict(tiers=len(tiers)))


# --- palm --------------------------------------------------------------------------------------------------------

def _palm_trunk(pts, rad, segs, sp, z_top):
    """The trunk again with a ring every RING_M metres: alternating bark colours per ring band and a slight bulge
    at every other ring (the leaf scars of a date palm); the foot sinks into the ground."""
    path = np.array(pts, dtype=np.float64)
    radii = np.array(rad, dtype=np.float64)
    s = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])
    m = max(2, int(s[-1] / RING_M))
    t = np.linspace(0.0, s[-1], m + 1)
    dense = np.stack([np.interp(t, s, path[:, k]) for k in range(3)], axis=1)
    r = np.interp(t, s, radii) * np.where(np.arange(m + 1) % 2 == 0, 1.05, 0.97)
    pos, nor = V._tube(list(dense), list(r), segs)
    c1 = np.array(core.srgb8(core.hex_to_lin(sp["bark"][0][1][0])), dtype=np.float64)
    c2 = np.array(core.srgb8(core.hex_to_lin(sp["bark"][0][1][1])), dtype=np.float64)
    zc = pos.mean(axis=1)[:, 2]
    band = (np.floor(zc / RING_M) % 2) == 0
    col = np.where(band[:, None], c1[None, :], c2[None, :])
    col = col * (0.82 + 0.18 * np.clip(zc / max(1.0, z_top), 0.0, 1.0))[:, None]
    out = np.empty(pos.shape[:2] + (4,), dtype=np.uint8)
    out[..., :3] = np.clip(np.round(col), 0, 255).astype(np.uint8)[:, None, :]
    out[..., 3] = 255
    return V._sink(pos, nor, sp["sink"]), nor, out


def _frond_strip(top, a, ln, lift, n_seg, rect, phase, sp, fold=0.42, widen=1.12):
    """One frond as a folded strip along the generator's spine: vertices (left, middle, right) per station."""
    d = np.array([math.cos(a), math.sin(a), 0.0])
    side = np.array([-d[1], d[0], 0.0])
    (ua, va, ub, vb) = rect
    pos, nor, uv, col, tri = [], [], [], [], []
    for i in range(n_seg + 1):
        t = i / n_seg
        p = np.asarray(top) + d * (ln * t) + np.array([0.0, 0.0, lift * math.sin(t * math.pi * 0.8) - 1.6 * t * t])
        w = (0.55 * math.sin(math.pi * min(1.0, t * 1.1)) + 0.03) * widen
        # direction of the spine at t (for the frond's surface normal)
        dz = lift * math.cos(t * math.pi * 0.8) * math.pi * 0.8 - 3.2 * t
        along = d * ln + np.array([0.0, 0.0, dz])
        along /= np.linalg.norm(along)
        up = np.cross(side, along)
        if up[2] < 0.0:
            up = -up
        for k, sgn in ((0, -1.0), (1, 0.0), (2, 1.0)):
            e = p + side * (sgn * w * math.cos(fold)) - np.array([0.0, 0.0, abs(sgn) * w * math.sin(fold)])
            pos.append(e)
            n = up * 0.75 + side * (sgn * 0.35) + np.array([0.0, 0.0, 0.15])
            nor.append(n / np.linalg.norm(n))
            uv.append((ua + (ub - ua) * (k * 0.5), vb + (va - vb) * t))
            col.append([0.35 + 0.65 * t, phase, sp["stiff"], 0.72 + 0.28 * t])
    for i in range(n_seg):
        b = i * 3
        for k in (0, 1):
            tri.append((b + k, b + k + 1, b + 3 + k + 1))
            tri.append((b + k, b + 3 + k + 1, b + 3 + k))
    return np.array(pos), np.array(nor), np.array(uv), np.array(col), np.array(tri, dtype=np.int64)


def _sphere(c, r, subdiv=0):
    v, f = V._ico(subdiv)
    p = np.asarray(c) + v * r
    return p[f], v[f]


def _palm(model_id, spec3d, sp, sspec, info, wood_soups, crown_pts, shape, t0):
    pts, rad = shape["trunk"]
    fronds = shape["fronds"]
    wood_pts = np.concatenate([s.pos.reshape(-1, 3) for s in wood_soups])
    ref = np.concatenate([crown_pts, wood_pts])
    ref_lo, ref_hi = ref.min(axis=0), ref.max(axis=0)
    top_z = float(ref_hi[2])
    seed = int(spec3d.get("params", {}).get("seed", 0)) + sp["atlas_seed"]
    rng = random.Random(seed)
    asp = leafatlas.species_atlas(dict(sp["atlas"], fringe=sp["fringe"]))
    asp["twig"] = "#9a8a4a"
    atlas_img, rects = leafatlas.special_atlas("frond", asp, size=1024, seed=sp["atlas_seed"])
    top = np.array(pts[-1])
    strips = {}
    for li, n_seg in enumerate((8, 4)):
        rr = random.Random(seed)
        strips[li] = [_frond_strip(f[0], f[1], f[2], f[3], n_seg, rects["leaf"][rr.randrange(4)], rr.random(), sp)
                      for f in fronds]
    eff = np.concatenate([s[0][0::3] for s in strips[0]] + [s[0][2::3] for s in strips[0]])
    fit = V._Fit(eff, wood_pts, ref_lo, ref_hi, np.array([0.0, 0.0, float(top[2]) - 1.0]))
    meshes, n_cards = {}, {}
    for li, name in enumerate(("lod0", "lod1")):
        mb = core.MeshBuilder()
        tp, tn, tc = _palm_trunk(pts, rad, (8, 6)[li], sp, top_z)
        mb.add("vpbr", tp, tn, tc, (0.9, 0.0), roles.NO_LAMP)
        # the crown shaft: a dark green-brown ellipsoid of frond bases at the top of the trunk
        hp, hn = _sphere(top + np.array([0.0, 0.0, 0.1]), 1.0, 1 if li == 0 else 0)
        hp = top + (hp - top) * np.array([0.42, 0.42, 0.55])
        shaft = np.append(core.srgb8(core.hex_to_lin("#4a4a26")), 255).astype(np.uint8)
        mb.add("vpbr", hp, hn, shaft, (0.85, 0.0), roles.NO_LAMP)
        if li == 0:
            nut = np.append(core.srgb8(core.hex_to_lin("#5a4a22")), 255).astype(np.uint8)
            for k in range(5):
                ak = k * 1.3
                p, n = _sphere(top + np.array([math.cos(ak) * 0.3, math.sin(ak) * 0.3, -0.42]), 0.15, 0)
                mb.add("vpbr", p, n, nut, (0.6, 0.0), roles.NO_LAMP)
        for (p, n, uv, col, tri) in strips[li]:
            pf = fit(p)
            c = col.copy()
            ao = np.ones(len(p))
            c[:, 3] = np.clip(c[:, 3] * V._sky(n, sp) * ao, 0.08, 1.0)
            _add_tris(mb, "leaves", pf, n, c, uv, tri)
        meshes[name] = mb
        n_cards[name] = len(fronds) * (8, 4)[li] * 2
    card_sets = {"lod0": {"eff": fit(eff)}}
    model = V._finish_tree(model_id, spec3d, sp, sspec, info, meshes, core.MeshBuilder(), card_sets, n_cards, wood_pts,
                           atlas_img, ref_lo, ref_hi, t0, dict(fronds=len(fronds)))
    model.shadow = None           # the fronds cast their leaflets themselves (props builder: no caster -> lod casts)
    return model
