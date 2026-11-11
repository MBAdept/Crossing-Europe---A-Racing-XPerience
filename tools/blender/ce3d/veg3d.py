"""Card trees, bushes and ground cover for the mode "Modern" (contract D22, A-3; docs/modelle.md section 14).

Trees (builder "tree"): the trunk and the main branches of the sprite generator, limbs into every leaf clump, a
closed low-poly core and alpha-scissor leaf cards on the OUTER skin of the crown blobs of the sprite model (same
seed -> same silhouette), a low-poly shadow caster and an impostor rendered from the card tree.

  lod0     wood (vpbr) + core and cards (leaves)              <= 2,500 triangles, <= 450 cards, 2 draw calls
  lod1     trunk and limbs + core, fewer and larger cards      <= 900 triangles, 2 draw calls
  shadow   hull of the crown + trunk (vpbr)                     the cheap caster for "Schatten: Mittel"
  impostor picture of lod0 (albedo with soft shading, lit by billboard.gdshader), the level beyond lod1
Bushes and ground cover (builder "bush", kind plant): core + cards in the class leaves only (ONE draw call),
lod0 <= 400 and lod1 <= 120 triangles, no impostor. Grass tufts (builder "grass"): crossed blade cards (the blades stand upright, a tuft is never seen edge-on: three planes).

Leaf card vertex data (class "leaves"): UV = cluster of the leaf atlas, COLOR = (sway amplitude by height,
phase per card, stiffness, brightness), NORMAL = outwards from the crown (blend of the directions from the crown
centre and from the clump centre, lifted a little: soft, round shading).
Brightness = ambient occlusion of the card inside the crown: rays from the card centre over the hemisphere of
its normal against the blob spheres (the inner and lower cards are darker - the volume a crown has).
The cards are fitted to the silhouette of the sprite crown (left / right / depth / top), so the model's extent
equals the sprite's. Variants (catalog "variant_of"): the generator with another seed, no sets of their own -
the set of the species lists them in "variants".
"""
import io
import math
import os
import random
import tempfile
import time

import numpy as np

from . import core, leafatlas, roles
from . import lod as LOD
from .export import Lod, ModelData, Part, sprite_extent

# atlas parameters per leaf type (leafatlas.cluster)
OAK_LEAF = dict(leaf="lobed", colors=("#2f5a1c", "#466f24", "#3b6420", "#55802c", "#5f8a33"), shade="#16290c",
                n_leaves=430, leaf_len=(0.06, 0.088), fill=0.94, twig="#3a2c1e", twig_share=0.25)
BIRCH_LEAF = dict(leaf="birch", colors=("#5d8a2a", "#76a03a", "#86ad45", "#6a9632"), shade="#21360f",
                  n_leaves=330, leaf_len=(0.05, 0.072), fill=0.92, twig="#4a3a2a", leaf_w=0.62, twig_share=0.35)
BUSH_LEAF = dict(leaf="ovate", colors=("#335d22", "#467329", "#3f6a25", "#55822f"), shade="#162a0e",
                 n_leaves=300, leaf_len=(0.07, 0.1), fill=0.95, twig="#3a2c1e", twig_share=0.2)
BUSHL_LEAF = dict(leaf="ovate", colors=("#3d6528", "#517a2e", "#46702a", "#628a35"), shade="#18300f",
                  n_leaves=300, leaf_len=(0.07, 0.1), fill=0.95, twig="#3a2c1e", twig_share=0.2)
GRASS = dict(colors=("#4a6a27", "#5d7d2f", "#6d8a36", "#425f24"), shade="#20301a", tip="#97a656", n_blades=70)

# species of the trees: atlas, bark, clumps, cards per blob (lod0, lod1), card size (m, at the mean blob radius),
# card style (flat: many small plain cards measured best - tents curl at the silhouette, crossed pairs streak)
SPECIES = {
    "oak": dict(atlas=OAK_LEAF, bark=("#3b3025", "#544536"), clumps=9, cards=(7, 3),
                card_size=((1.45, 1.95), (2.25, 2.9)), limb_r=(0.13, 0.05), atlas_seed=7),
    "birch": dict(atlas=BIRCH_LEAF, bark=("#e4e1d8", "#2b2722"), clumps=7, cards=(13, 5),
                  card_size=((0.95, 1.35), (1.45, 1.95)), limb_r=(0.06, 0.025), birch=True, atlas_seed=11,
                  core_bright=0.76),
}
# bushes: crowns of the generator (props_nature.bush_*) or the parameters of a ground-cover clump; lod1 has
# single cards (no pairs: 120 triangles)
BUSHES = {
    "bush_round": dict(atlas=BUSH_LEAF, cards=(8, 2), card_size=((0.62, 0.86), (1.2, 1.5)), atlas_seed=13),
    "bush_low": dict(atlas=BUSHL_LEAF, cards=(7, 2), card_size=((0.62, 0.86), (1.25, 1.55)), atlas_seed=17),
    "cover_bush": dict(atlas=BUSHL_LEAF, cards=(9, 3), card_size=((0.3, 0.4), (0.48, 0.6)), atlas_seed=19),
}
OPAQUE = 0.82            # part of a card (from its centre) that counts as silhouette
IMPOSTOR_PX = 256
IMPOSTOR_MAX_PX = 512
# The impostor picture is the albedo of the tree times this gain (linear): measured against lod1 in the
# contact sheet with the ambient light alone. billboard.gdshader then lights the picture with the renderer's
# own arithmetic, the cards' share of the sun as sun_min .. sun_max.
IMPOSTOR_GAIN = 1.27
# The lit cards also reflect the sky (specular): their mean blue is about a quarter above that of the unlit
# impostor picture (measured against lod1 at 200 m) - the picture gets that blue in its albedo.
IMPOSTOR_TINT = (0.98, 1.0, 1.25)
LOD1_LIFT = 1.06
CARD_TRIS_MAX = 900      # triangles of all cards of lod0 (tents: 4 each); 60 % of it for lod1


# --- source ------------------------------------------------------------------------------------------------

def _source(spec3d):
    """Sprite build with the crown log on: wood soups, reference points of the sprite model, blobs. The catalog
    entry's "params" go to the generator (variants: another seed)."""
    import render_all as RA
    from cesprites import meshutil as MU
    from cesprites import props_nature as N
    from cesprites import rig as R
    from .props3d import _sprite_spec
    sspec = dict(_sprite_spec(spec3d["source"]))
    if spec3d.get("params"):
        sspec["params"] = dict(sspec["params"], **spec3d["params"])
    rig = R.Rig(quick=True)
    MU.tagging(True)
    N.CROWN_LOG = []
    try:
        info = RA.build(rig, sspec)
        blobs = list(N.CROWN_LOG)
    finally:
        N.CROWN_LOG = None
        MU.tagging(False)
    objs = core.model_objects(rig)
    wood = [o for o in objs if roles.node_of(o) == "body"]
    crown = [o for o in objs if roles.node_of(o) == "crown"]
    if not blobs or not crown:
        raise RuntimeError("%s: the generator logged no crown blobs" % spec3d["source"])
    wood_soups = core.soups_of(wood)
    crown_pts = np.concatenate([s.pos.reshape(-1, 3) for s in core.soups_of(crown)])
    return sspec, info, wood_soups, crown_pts, blobs


def _crown_blobs(rig_fn, args, seed):
    """Blobs of a crown built with the generator's crown() (ground cover): [(centre, r, zs)]."""
    from cesprites import meshutil as MU
    from cesprites import props_nature as N
    from cesprites import rig as R
    rig = R.Rig(quick=True)
    MU.tagging(True)
    N.CROWN_LOG = []
    try:
        lv = N.leaves("cover_leaves", "#466f2c", "#6a9037", scale=2.4)
        rig_fn(rig, "cover", *args, lv, seed)
        blobs = list(N.CROWN_LOG)
    finally:
        N.CROWN_LOG = None
        MU.tagging(False)
    pts = np.concatenate([s.pos.reshape(-1, 3) for s in core.soups_of(core.model_objects(rig))])
    return blobs, pts


# --- geometry helpers ----------------------------------------------------------------------------------------

def _ico(subdiv):
    """Unit icosphere: (verts (N, 3), faces (M, 3)) with outward winding."""
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    bm.verts.ensure_lookup_table()
    v = np.array([vv.co[:] for vv in bm.verts], dtype=np.float64)
    f = np.array([[x.index for x in ff.verts] for ff in bm.faces], dtype=np.int64)
    bm.free()
    cen = v[f].mean(axis=1)
    nrm = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    flip = (nrm * cen).sum(axis=1) < 0
    f[flip] = f[flip][:, ::-1]
    return v, f


def _hull(blobs, centre, shrink, r_part, subdiv, z_min=None, scale=None):
    """Lumpy closed solid following the blob set: every icosphere direction reaches the support of the
    blobs in that direction (blob centre + r_part * radius) times shrink. Returns per-corner (pos, nor)."""
    v, f = _ico(subdiv)
    if scale is not None:
        v = v * np.asarray(scale)[None, :]
        v /= np.linalg.norm(v, axis=1, keepdims=True)
    bc = np.array([b[0] for b in blobs]) - centre
    br = np.array([b[1] for b in blobs])
    sup = (v @ bc.T + br[None, :] * r_part).max(axis=1)
    p = centre + v * (np.maximum(sup, 0.05) * shrink)[:, None]
    if z_min is not None:
        p[:, 2] = np.maximum(p[:, 2], z_min)
    fn = np.cross(p[f[:, 1]] - p[f[:, 0]], p[f[:, 2]] - p[f[:, 0]])
    vn = np.zeros_like(p)
    for k in range(3):
        np.add.at(vn, f[:, k], fn)
    vn /= np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-9)
    # soften: the shading normal leans towards the direction from the centre (a crown, not a faceted rock)
    radial = (p - centre) / np.maximum(np.linalg.norm(p - centre, axis=1, keepdims=True), 1e-9)
    vn = vn * 0.5 + radial * 0.5
    vn /= np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-9)
    return p[f], vn[f]


def _kmeans(pts, k, seed, iters=25):
    """Deterministic k-means of (N, 3) points: (labels (N), centres (k, 3))."""
    rng = np.random.default_rng(seed)
    k = max(1, min(k, pts.shape[0]))
    cen = pts[rng.choice(pts.shape[0], size=k, replace=False)].copy()
    lab = np.zeros(pts.shape[0], dtype=np.int64)
    for _ in range(iters):
        d = ((pts[:, None, :] - cen[None, :, :]) ** 2).sum(axis=2)
        lab = d.argmin(axis=1)
        for j in range(k):
            sel = lab == j
            if sel.any():
                cen[j] = pts[sel].mean(axis=0)
    return lab, cen


def _tube(path, radii, segs, cap_end=True):
    """Tapered tube along a polyline: per-corner (pos (T, 3, 3), nor (T, 3, 3)) with smooth normals."""
    path = [np.asarray(p, dtype=np.float64) for p in path]
    rings = []
    norms = []
    for i, (p, r) in enumerate(zip(path, radii)):
        d = (path[i + 1] - p) if i < len(path) - 1 else (p - path[i - 1])
        d = d / max(1e-9, np.linalg.norm(d))
        up = np.array([0.0, 0.0, 1.0]) if abs(d[2]) < 0.95 else np.array([1.0, 0.0, 0.0])
        u = np.cross(d, up)
        u /= np.linalg.norm(u)
        w = np.cross(d, u)
        ring, nrm = [], []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            n = u * math.cos(a) + w * math.sin(a)
            ring.append(p + n * r)
            nrm.append(n)
        rings.append(ring)
        norms.append(nrm)
    pos, nor = [], []
    for i in range(len(rings) - 1):
        for k in range(segs):
            k2 = (k + 1) % segs
            a, b, c, d = rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]
            na, nb, nc, nd = norms[i][k], norms[i][k2], norms[i + 1][k2], norms[i + 1][k]
            pos += [(a, b, c), (a, c, d)]
            nor += [(na, nb, nc), (na, nc, nd)]
    if cap_end and radii[-1] > 0.01:
        tip = path[-1]
        dn = (path[-1] - path[-2])
        dn = dn / max(1e-9, np.linalg.norm(dn))
        last = rings[-1]
        for k in range(segs):
            pos.append((last[k], last[(k + 1) % segs], tip + dn * radii[-1] * 0.5))
            nor.append((norms[-1][k], norms[-1][(k + 1) % segs], dn))
    pos = np.array(pos, dtype=np.float64)
    nor = np.array(nor, dtype=np.float64)
    # winding: outward (the cross product of the corners along the normal)
    fn = np.cross(pos[:, 1] - pos[:, 0], pos[:, 2] - pos[:, 0])
    flip = (fn * nor.mean(axis=1)).sum(axis=1) < 0
    pos[flip] = pos[flip][:, ::-1]
    nor[flip] = nor[flip][:, ::-1]
    return pos, nor


# --- wood --------------------------------------------------------------------------------------------------

def _bark_colour(sp, n_corners, pos, rng, z_top):
    """Vertex colours of the wood (sRGB bytes): darker at the foot, birches white with black marks (the birch
    trunk is rebuilt with dense rings for them: _birch_trunk)."""
    c1 = np.array(core.srgb8(core.hex_to_lin(sp["bark"][0])), dtype=np.float64)
    c2 = np.array(core.srgb8(core.hex_to_lin(sp["bark"][1])), dtype=np.float64)
    z = pos[..., 2]
    if sp.get("birch"):
        # white bark, dark marks in short horizontal bands; the foot is dark and rough
        ring = np.floor(z / 0.25)
        ang = np.floor((np.arctan2(pos[..., 1], pos[..., 0]) + math.pi) / (2 * math.pi) * 8.0)
        h1 = (np.sin(ring * 12.9898 + ang * 78.233) * 43758.5453) % 1.0
        mark = h1 > 0.78
        grey = ((np.sin(ring * 4.1 + ang * 1.7) * 9631.7) % 1.0) * 0.12
        foot = np.clip(1.0 - z / 1.1, 0.0, 1.0) ** 1.5
        col = np.where(mark[..., None], c2[None, None, :], c1[None, None, :] * (1.0 - grey[..., None]))
        col = col * (1.0 - foot[..., None] * 0.75) + c2[None, None, :] * (foot[..., None] * 0.75)
    else:
        t = np.clip(z / max(1.0, z_top), 0.0, 1.0)
        col = c1[None, None, :] * (1.0 - t[..., None] * 0.35) + c2[None, None, :] * (t[..., None] * 0.35)
        col *= (0.9 + 0.1 * np.clip(z / 1.5, 0.0, 1.0))[..., None]
    out = np.empty(pos.shape[:2] + (4,), dtype=np.uint8)
    out[..., :3] = np.clip(np.round(col), 0, 255).astype(np.uint8)
    out[..., 3] = 255
    return out


def _add_wood(mb, sp, pos, nor, z_top, rough=0.9):
    rng = random.Random(3)
    if sp.get("birch"):
        # one colour per triangle: the marks of a birch stay crisp bands (the welder never shares a vertex
        # between two colours), instead of smears over the long triangles of the trunk
        cen = np.repeat(pos.mean(axis=1, keepdims=True), 3, axis=1)
        col = _bark_colour(sp, pos.shape[0], cen, rng, z_top)
    else:
        col = _bark_colour(sp, pos.shape[0], pos, rng, z_top)
    mb.add("vpbr", pos, nor, col, (rough, 0.0), roles.NO_LAMP)


def _wood_soups(soups, z_cut=None):
    """(pos, nor) of the generator wood, triangles above z_cut dropped."""
    ps, ns = [], []
    for s in soups:
        keep = np.ones(s.n, dtype=bool) if z_cut is None else s.pos[:, :, 2].mean(axis=1) < z_cut
        if keep.any():
            ps.append(s.pos[keep])
            ns.append(s.nor[keep])
    if not ps:
        return np.zeros((0, 3, 3)), np.zeros((0, 3, 3))
    return np.concatenate(ps), np.concatenate(ns)


def _inside_crown(pts, blobs, centre, shrink=0.97, r_part=0.9):
    """True for points inside the crown volume (the support of the blob set from the centre)."""
    bc = np.array([b[0] for b in blobs]) - centre
    br = np.array([b[1] for b in blobs])
    rel = pts - centre
    dist = np.linalg.norm(rel, axis=-1)
    d = rel / np.maximum(dist[..., None], 1e-9)
    sup = (d.reshape(-1, 3) @ bc.T + br[None, :] * r_part).max(axis=1).reshape(dist.shape)
    return dist < sup * shrink


def _tree_wood(soups, blobs, centre, crown_bottom, sp, z_cut=None):
    """(pos, nor) of the wood of a tree: the generator's trunk and branches; branch parts that stick out of the
    crown are dropped (white sticks poking out of a birch crown); birch trunks are rebuilt with dense rings
    (_birch_trunk) for the marks of the bark."""
    ps, ns = [], []
    for s in soups:
        cen = s.pos.mean(axis=1)
        keep = np.ones(s.n, dtype=bool)
        if z_cut is not None:
            keep &= cen[:, 2] < z_cut
        trunk = "trunk" in s.name
        if not trunk:
            keep &= (cen[:, 2] < crown_bottom + 0.5) | _inside_crown(cen, blobs, centre)
        if trunk and sp.get("birch"):
            p, n = _birch_trunk(s, z_cut, ring_m=0.25 if z_cut is None else 0.5, segs=6 if z_cut is None else 5)
            ps.append(p)
            ns.append(n)
            continue
        if keep.any():
            ps.append(s.pos[keep])
            ns.append(s.nor[keep])
    if not ps:
        return np.zeros((0, 3, 3)), np.zeros((0, 3, 3))
    return np.concatenate(ps), np.concatenate(ns)


def _birch_trunk(soup, z_cut=None, ring_m=0.16, segs=8):
    """The generator's birch trunk again as a tube with a ring every ring_m metres: its axis and radius from the
    centroids of height slices of the generator's tube."""
    p = soup.pos.reshape(-1, 3)
    z0, z1 = float(p[:, 2].min()), float(p[:, 2].max())
    if z_cut is not None:
        z1 = min(z1, z_cut)
    n = max(2, int((z1 - z0) / 0.5))
    path, radii = [], []
    for i in range(n + 1):
        zz = z0 + (z1 - z0) * i / n
        sel = np.abs(p[:, 2] - zz) < max(0.3, (z1 - z0) / n)
        if not sel.any():
            continue
        c = p[sel].mean(axis=0)
        c[2] = zz
        path.append(c)
        radii.append(float(np.median(np.linalg.norm((p[sel] - c)[:, :2], axis=1))))
    path = np.array(path)
    radii = np.array(radii)
    # resample with dense rings
    s = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])
    m = max(2, int(s[-1] / ring_m))
    t = np.linspace(0.0, s[-1], m + 1)
    dense = np.stack([np.interp(t, s, path[:, k]) for k in range(3)], axis=1)
    rad = np.interp(t, s, radii)
    return _tube(list(dense), list(rad), segs)


def _limbs(clump_cen, wood_pts, r0, r1, segs):
    """A limb from the wood into every leaf clump: it leaves the wood surface point nearest to the clump (below
    the clump centre) and ends inside the clump, a little curved upwards."""
    pos, nor = [], []
    for c in clump_cen:
        below = wood_pts[wood_pts[:, 2] < c[2] - 0.3]
        if below.shape[0] == 0:
            continue
        start = below[np.argmin(np.linalg.norm(below - c, axis=1))]
        end = c - (c - start) * 0.3
        length = float(np.linalg.norm(end - start))
        if length < 0.8:
            continue
        mid = start + (end - start) * 0.5 + np.array([0.0, 0.0, 0.12 * length])
        p, n = _tube([start, mid, end], [r0, (r0 + r1) * 0.5, r1], segs)
        pos.append(p)
        nor.append(n)
    if not pos:
        return np.zeros((0, 3, 3)), np.zeros((0, 3, 3))
    return np.concatenate(pos), np.concatenate(nor)


# --- cards ---------------------------------------------------------------------------------------------------

def _occlusion(points, normals, blobs, centre, rays=14, shrink=0.85):
    """Share of free directions (0..1) over the hemisphere of each normal against the blob spheres."""
    bc = np.array([b[0] for b in blobs])
    br = np.array([b[1] for b in blobs]) * shrink
    rng = np.random.default_rng(5)
    dirs = rng.normal(size=(rays, 3))
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    out = np.zeros(points.shape[0])
    for i in range(points.shape[0]):
        n = normals[i]
        d = np.where((dirs @ n)[:, None] < 0, -dirs, dirs)
        d = d * 0.7 + n[None, :] * 0.3
        d /= np.linalg.norm(d, axis=1, keepdims=True)
        o = points[i] + n * 0.05
        oc = bc - o                                         # (B, 3)
        t_mid = d @ oc.T                                    # (R, B)
        dist2 = (oc ** 2).sum(axis=1)[None, :] - t_mid ** 2
        hit = (t_mid > 0.05) & (dist2 < (br ** 2)[None, :])
        out[i] = 1.0 - hit.any(axis=1).mean()
    return out


TENT_RISE = 0.5          # apex of a tent card over its plane, in half card sizes (facets at 27 degrees)


def _cards(blobs, centre, ext, clump_lab, clump_cen, per_blob, size_range, rects, seed, top_z, blob_scale=1.0,
           skin=True, style="tent"):
    """Leaf cards on the outer skin of the blobs. style:
      "tent"  a quad whose middle is raised along its normal (4 triangles): seen edge-on it still shows two
              facets at 27 degrees - a flat card seen edge-on is a streak; the raised middle (the dense middle of
              the leaf cluster) makes every card a small dome
      "flat"  a plain quad (2 triangles; the far levels of bushes)
    Returns dict(p0 (C, 3), quad (C, 4, 3), apex (C, 3), tent (C) bool, uv (C, 4, 2), col (C, 4, 4) float,
    nor (C, 3))."""
    rng = random.Random(seed)
    bc = np.array([b[0] for b in blobs])
    br = np.array([b[1] for b in blobs])
    r_mean = float(br.mean())
    p0s, quads, uvs, cols, nors, apexes = [], [], [], [], [], []
    for bi, (c0, r, zs) in enumerate(blobs):
        c0 = np.array(c0)
        cc = clump_cen[clump_lab[bi]]
        out = c0 - (centre * 0.6 + cc * 0.4)
        out /= (np.linalg.norm(out) + 1e-6)
        made = 0
        tries = 0
        while made < per_blob and tries < per_blob * 12:
            tries += 1
            d = np.array([rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1)])
            d = d / (np.linalg.norm(d) + 1e-6) + out * 0.85
            d /= np.linalg.norm(d)
            off = d * r * blob_scale * rng.uniform(0.78, 1.0)
            off[2] *= zs
            p0 = c0 + off
            if skin and tries < per_blob * 10:
                # hidden inside another blob: a card there is never seen - put it elsewhere
                inside = np.linalg.norm(bc - p0, axis=1) < br * 0.78
                inside[bi] = False
                if inside.any():
                    continue
            made += 1
            size = rng.uniform(*size_range) * (r / r_mean) ** 0.5
            # the card plane: facing out of the blob, but never lying flat - a horizontal card on top of the crown
            # is seen from the road at a grazing angle (a streak); the shading normal keeps the true direction
            dc = d * np.array([1.0, 1.0, 0.45])
            dc /= np.linalg.norm(dc)
            tmp = np.array([0.0, 0.0, 1.0]) if abs(dc[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
            u = np.cross(tmp, dc)
            u /= np.linalg.norm(u)
            v = np.cross(dc, u)
            roll = rng.uniform(0, 2 * math.pi)
            u2 = u * math.cos(roll) + v * math.sin(roll)
            v2 = -u * math.sin(roll) + v * math.cos(roll)
            tilt = rng.uniform(-0.45, 0.45)
            v3 = v2 * math.cos(tilt) - dc * math.sin(tilt)
            n3 = np.cross(u2, v3)
            n3 /= np.linalg.norm(n3)
            if n3 @ dc < 0:
                n3 = -n3
            # shading normal: mostly the blob's own direction (every blob a lit and a shaded side - the volume of
            # the clumps), then the crown's, lifted a little
            sc = (p0 - centre) / ext
            sc = sc / (np.linalg.norm(sc) + 1e-6)
            sn = d * 0.55 + sc * 0.3 + np.array([0.0, 0.0, 0.15])
            sn /= np.linalg.norm(sn)
            h = size * 0.5
            quad = np.array([p0 - u2 * h - v3 * h, p0 + u2 * h - v3 * h, p0 + u2 * h + v3 * h, p0 - u2 * h + v3 * h])
            (ua, va, ub, vb) = rects[rng.randrange(len(rects))]
            p0s.append(p0)
            quads.append(quad)
            apexes.append(p0 + n3 * h * TENT_RISE if style == "tent" else p0)
            uvs.append(np.array([(ua, vb), (ub, vb), (ub, va), (ua, va)]))
            cols.append([(0.0, rng.random(), rng.uniform(0.3, 0.9), 1.0)] * 4)
            nors.append(sn)
    n = len(p0s)
    return dict(p0=np.array(p0s), quad=np.array(quads), apex=np.array(apexes), tent=np.full(n, style == "tent"),
                uv=np.array(uvs), col=np.array(cols), nor=np.array(nors))


def _shade_cards(cards, blobs, centre, top_z, lo=0.36, hi=1.0, seed=1):
    """Card brightness = occlusion inside the crown (rays against the blobs) and height."""
    ao = _occlusion(cards["p0"], cards["nor"], blobs, centre)
    h = np.clip((cards["p0"][:, 2] - centre[2]) / max(0.5, top_z - centre[2]) * 0.5 + 0.5, 0.0, 1.0)
    rng = np.random.default_rng(seed)
    b = lo + (hi - lo) * (ao ** 0.8) * (0.82 + 0.18 * h) + rng.uniform(-0.04, 0.04, size=ao.shape)
    cards["col"][:, :, 3] = np.clip(b, 0.3, 1.0)[:, None]
    return ao


def _fit(cards, wood_pts, ref_lo, ref_hi, centre):
    """Moves the cards so that the silhouette of wood + cards has the reference bounds: x and y are mapped
    linearly, z is scaled above the crown centre so that the top matches."""
    eff = cards["p0"][:, None, :] + (cards["quad"] - cards["p0"][:, None, :]) * OPAQUE
    pts = np.concatenate([eff.reshape(-1, 3), wood_pts])
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    kz = (ref_hi[2] - centre[2]) / max(1e-6, hi[2] - centre[2])

    def remap(a):
        for ax in (0, 1):
            k = (ref_hi[ax] - ref_lo[ax]) / max(1e-6, hi[ax] - lo[ax])
            a[..., ax] = ref_lo[ax] + (a[..., ax] - lo[ax]) * k
        a[..., 2] = np.where(a[..., 2] > centre[2], centre[2] + (a[..., 2] - centre[2]) * kz, a[..., 2])
    for key in ("quad", "p0", "apex"):
        remap(cards[key])
    return cards


def _core_uv(pos, centre, rect, metres=2.4):
    """UVs of the core: every triangle is projected flat (true lengths, no stretching) into the opaque core cell
    of the atlas, `metres` across the cell, around a shifted middle per triangle. The core cell is an even leaf
    mass, so the seams between triangles do not show."""
    (ua, va, ub, vb) = rect
    cu, cv = (ua + ub) * 0.5, (va + vb) * 0.5
    hu, hv = (ub - ua) * 0.5, (vb - va) * 0.5
    fn = np.cross(pos[:, 1] - pos[:, 0], pos[:, 2] - pos[:, 0])
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    up = np.where(np.abs(fn[:, 2:3]) < 0.9, np.array([[0.0, 0.0, 1.0]]), np.array([[1.0, 0.0, 0.0]]))
    t1 = np.cross(up, fn)
    t1 /= np.maximum(np.linalg.norm(t1, axis=1, keepdims=True), 1e-12)
    t2 = np.cross(fn, t1)
    rel = pos - pos.mean(axis=1, keepdims=True)
    k = 2.0 / metres
    su = (rel * t1[:, None, :]).sum(axis=2) * k
    sv = (rel * t2[:, None, :]).sum(axis=2) * k
    idx = np.arange(pos.shape[0])
    ou = ((idx * 0.618034) % 1.0 - 0.5) * 0.5
    ov = ((idx * 0.414214) % 1.0 - 0.5) * 0.5
    su = np.clip(su + ou[:, None], -0.92, 0.92)
    sv = np.clip(sv + ov[:, None], -0.92, 0.92)
    return np.stack([cu + su * hu, cv + sv * hv], axis=-1)


def _core_colors(pos, z0, top_z, bright=0.62):
    """Leaves vertex colours of the core: sways with the crown, no flutter, darker than the cards."""
    amp = np.clip((pos[..., 2] - z0) / max(0.5, top_z - z0), 0.0, 1.0)
    col = np.empty(pos.shape[:2] + (4,), dtype=np.float64)
    col[..., 0] = amp
    col[..., 1] = 0.0
    col[..., 2] = 1.0
    col[..., 3] = bright
    return np.clip(np.round(col * 255.0), 0, 255).astype(np.uint8)


def _card_arrays(cards, z0, top_z):
    """Per-corner arrays of the cards: pos (T, 3, 3), nor, uv, col uint8 (sway amplitude by height). Flat cards
    are two triangles, tents four (corners 0-3, apex 4 in the middle of the cluster)."""
    q = np.concatenate([cards["quad"], cards["apex"][:, None, :]], axis=1)          # (C, 5, 3)
    uvc = cards["uv"].mean(axis=1, keepdims=True)
    uv5 = np.concatenate([cards["uv"], uvc], axis=1)
    col = np.concatenate([cards["col"], cards["col"][:, :1]], axis=1).copy()
    col[:, :, 0] = np.clip((q[:, :, 2] - z0) / max(0.5, top_z - z0), 0.0, 1.0)
    out_p, out_n, out_uv, out_c = [], [], [], []
    for tent, tri in ((False, np.array([[0, 1, 2], [0, 2, 3]])),
                      (True, np.array([[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4]]))):
        sel = cards["tent"] == tent
        if not sel.any():
            continue
        k = tri.shape[0]
        out_p.append(q[sel][:, tri, :].reshape(-1, 3, 3))
        out_uv.append(uv5[sel][:, tri, :].reshape(-1, 3, 2))
        out_c.append(np.clip(np.round(col[sel][:, tri, :].reshape(-1, 3, 4) * 255.0), 0, 255).astype(np.uint8))
        out_n.append(np.repeat(cards["nor"][sel], k, axis=0)[:, None, :].repeat(3, axis=1))
    return np.concatenate(out_p), np.concatenate(out_n), np.concatenate(out_uv), np.concatenate(out_c)


def _subset(cards, keep):
    return {k: v[keep] for k, v in cards.items()}


# --- trees ---------------------------------------------------------------------------------------------------

def _sets_of(model_id, spec3d):
    """Manifest sets of a model: none for a variant, else the catalog's sets (dict entries merged)."""
    if spec3d.get("variant_of"):
        return {}
    sets = spec3d.get("sets") or [model_id]
    out = {}
    for sid in (sorted(sets) if isinstance(sets, dict) else sets):
        e = {"model": model_id}
        if isinstance(sets, dict):
            e.update(sets[sid])
        out[sid] = e
    return out


def build_tree(model_id, spec3d):
    t0 = time.time()
    sp = SPECIES[spec3d["species"]]
    sspec, info, wood_soups, crown_pts, blobs = _source(spec3d)
    wood_pts = np.concatenate([s.pos.reshape(-1, 3) for s in wood_soups])
    ref = np.concatenate([crown_pts, wood_pts])
    ref_lo, ref_hi = ref.min(axis=0), ref.max(axis=0)
    bc = np.array([b[0] for b in blobs])
    br = np.array([b[1] for b in blobs])
    centre = bc.mean(axis=0)
    crown_bottom = float(crown_pts[:, 2].min())
    top_z = float(ref_hi[2])
    ext = np.max(np.abs(bc - centre), axis=0) + float(br.mean())
    seed = int(spec3d.get("params", {}).get("seed", 0)) + sp["atlas_seed"]
    atlas_img, rects = leafatlas.atlas(sp["atlas"], seed=sp["atlas_seed"])
    lab, ccen = _kmeans(bc, sp["clumps"], seed)
    meshes = {}
    n_cards = {}
    card_sets = {}
    for li, name in enumerate(("lod0", "lod1")):
        style = sp.get("style", "flat")
        cards = _cards(blobs, centre, ext, lab, ccen, sp["cards"][li], sp["card_size"][li], rects["leaf"], seed + li,
                       top_z, style=style)
        tpc = 4 if style == "tent" else 2
        if cards["quad"].shape[0] * tpc > CARD_TRIS_MAX * (1 if li == 0 else 0.6):
            # over the card budget: drop cards, spread evenly
            n_max = int(CARD_TRIS_MAX * (1 if li == 0 else 0.6)) // tpc
            keep = np.zeros(cards["quad"].shape[0], dtype=bool)
            keep[np.linspace(0, cards["quad"].shape[0] - 1, n_max).astype(int)] = True
            cards = _subset(cards, keep)
        cards = _fit(cards, wood_pts, ref_lo, ref_hi, centre)
        _shade_cards(cards, blobs, centre, top_z, seed=seed + li)
        if li == 1:
            # the larger cards of lod1 let more of the dark core through: lifted so that lod0 and lod1 show the
            # same mean colour at the switch distance (measured with tools/models_prop_scene.sh --mode=lods)
            cards["col"][:, :, 3] = np.clip(cards["col"][:, :, 3] * LOD1_LIFT, 0.0, 1.0)
        card_sets[name] = cards
        n_cards[name] = int(cards["quad"].shape[0])
        mb = core.MeshBuilder()
        if li == 0:
            wp, wn = _tree_wood(wood_soups, blobs, centre, crown_bottom, sp)
            lp, ln = _limbs(ccen, wood_pts, sp["limb_r"][0], sp["limb_r"][1], 6)
        else:
            # the trunk up to the crown and coarse limbs
            wp, wn = _tree_wood(wood_soups, blobs, centre, crown_bottom, sp, crown_bottom + 1.0)
            lp, ln = _limbs(ccen, wood_pts, sp["limb_r"][0], sp["limb_r"][1], 4)
        _add_wood(mb, sp, np.concatenate([wp, lp]), np.concatenate([wn, ln]), top_z)
        pos, nor, uv, c8 = _card_arrays(cards, top_z * 0.3, top_z)
        mb.add("leaves", pos, nor, c8, uv)
        # solid core in the leaves class: the dense middle of the crown, darker than the cards
        hp, hn = _hull(blobs, centre, 0.74, 0.62, 2 if li == 0 else 1, z_min=crown_bottom + 0.5)
        mb.add("leaves", hp, hn, _core_colors(hp, top_z * 0.3, top_z, sp.get("core_bright", 0.62)),
               _core_uv(hp, centre, rects["core"]))
        meshes[name] = mb
    # shadow caster: crown hull + trunk (leaves.gdshader takes the sun's shadow only in part, so the cards
    # in front of this hull are not darkened by it)
    sh = core.MeshBuilder()
    wp, wn = _wood_soups(wood_soups, crown_bottom + 1.0)
    core_c = np.append(core.srgb8(core.hex_to_lin("#24401a")), 255).astype(np.uint8)
    sh.add("vpbr", wp, wn, core_c, (0.92, 0.0), roles.NO_LAMP)
    hp, hn = _hull(blobs, centre, 0.92, 0.75, 2, z_min=crown_bottom)
    sh.add("vpbr", hp, hn, core_c, (0.92, 0.0), roles.NO_LAMP)
    model = ModelData(model_id, "tree", dict(info.get("object") or {}))
    eff = card_sets["lod0"]["p0"][:, None, :] + (card_sets["lod0"]["quad"] - card_sets["lod0"]["p0"][:, None, :]) * OPAQUE
    model.extent_m = sprite_extent(np.concatenate([eff.reshape(-1, 3), wood_pts]),
                                   sspec["camera"].get("view_yaw", 0.0))
    model.tags = list(sspec.get("tags", []))
    model.lods = [Lod("lod0", LOD.PROP_LOD_DIST["lod0"], [Part("body", "lod0_body", meshes["lod0"].finish())]),
                  Lod("lod1", LOD.PROP_LOD_DIST["lod1"], [Part("body", "lod1_body", meshes["lod1"].finish())])]
    model.shadow = Part("body", "shadow", sh.finish())
    model.textures["leaves"] = "leaves.png"
    model.texture_files["leaves.png"] = leafatlas.png_bytes(atlas_img)
    model.extra["cards"] = n_cards
    model.sets = _sets_of(model_id, spec3d)
    t1 = time.time()
    png, size_m, anchor_x = render_impostor(meshes["lod0"], atlas_img, ref_lo, ref_hi)
    model.texture_files["impostor.png"] = png
    model.impostor = {"texture": "impostor.png", "size_m": size_m, "anchor_x": anchor_x}
    model.stats = dict(build_s=round(t1 - t0, 2), impostor_s=round(time.time() - t1, 2), blobs=len(blobs),
                       clumps=int(ccen.shape[0]), cards=n_cards,
                       tris={n: meshes[n].triangles() for n in meshes}, coverage=leafatlas.coverage(
                           atlas_img.crop((0, 0, 256, 256))))
    return model


# --- bushes and ground cover --------------------------------------------------------------------------------

def _bush_mesh(blobs, centre, ext, top_z, bottom, rects, sp, li, seed, lab, ccen, z_sway0, ref_lo, ref_hi):
    cards = _cards(blobs, centre, ext, lab, ccen, sp["cards"][li], sp["card_size"][li], rects["leaf"], seed + li,
                   top_z, blob_scale=1.0, style="flat")
    cards = _fit(cards, np.zeros((0, 3)), ref_lo, ref_hi, centre)
    _shade_cards(cards, blobs, centre, top_z, lo=0.48, seed=seed + li)
    mb = core.MeshBuilder()
    pos, nor, uv, c8 = _card_arrays(cards, z_sway0, top_z)
    # bushes sway little: amplitude scaled down (leaves.gdshader: sway_m x amp^2)
    c8 = c8.copy()
    c8[..., 0] = (c8[..., 0].astype(np.float64) * 0.45).astype(np.uint8)
    mb.add("leaves", pos, nor, c8, uv)
    if li == 0:
        # a small core: a bush may show the ground through its rim, not through its middle; a large dark core
        # showed as flat dark panes between the cards
        hp, hn = _hull(blobs, centre, 0.58, 0.55, 0, z_min=bottom)
        cc = _core_colors(hp, z_sway0, top_z, bright=0.7)
        cc[..., 0] = (cc[..., 0].astype(np.float64) * 0.45).astype(np.uint8)
        mb.add("leaves", hp, hn, cc, _core_uv(hp, centre, rects["core"], metres=1.2))
    eff = cards["p0"][:, None, :] + (cards["quad"] - cards["p0"][:, None, :]) * OPAQUE
    return mb, int(cards["quad"].shape[0]), eff.reshape(-1, 3)


def build_bush(model_id, spec3d):
    """Bushes (props/bush_round, bush_low) and the ground cover clump (props/cover_bush): leaves class only."""
    t0 = time.time()
    name = spec3d["bush"]
    sp = BUSHES[name]
    seed = int(spec3d.get("params", {}).get("seed", 0)) + sp["atlas_seed"]
    if spec3d.get("cover"):
        from cesprites import props_nature as N
        c = spec3d["cover"]
        blobs, ref = _crown_blobs(N.crown, (c["centre"], c["a"], c["b"], c["c"], c["n"], c["r0"], c["r1"]), seed)
        sspec = None
        info = {"object": dict(spec3d["object"])}
    else:
        sspec, info, _wood, ref, blobs = _source(spec3d)
    bc = np.array([b[0] for b in blobs])
    br = np.array([b[1] for b in blobs])
    centre = bc.mean(axis=0)
    ext = np.max(np.abs(bc - centre), axis=0) + float(br.mean())
    ref_lo, ref_hi = ref.min(axis=0), ref.max(axis=0)
    if spec3d.get("cover"):
        # ground cover: the box of its object size (never above the 0.5 m of A-3)
        o = spec3d["object"]
        ref_lo = np.array([-o["width_m"] * 0.5, -o.get("length_m", o["width_m"]) * 0.5, 0.0])
        ref_hi = np.array([o["width_m"] * 0.5, o.get("length_m", o["width_m"]) * 0.5, o["height_m"]])
    top_z = float(ref_hi[2])
    atlas_img, rects = leafatlas.atlas(sp["atlas"], size=512, grid=(2, 2), seed=sp["atlas_seed"])
    lab, ccen = _kmeans(bc, 3, seed)
    meshes, n_cards = {}, {}
    eff0 = None
    for li, ln in enumerate(("lod0", "lod1")):
        # the cards are fitted to the bounds of the generator's crown (the sprite's object size)
        mb, nc, eff = _bush_mesh(blobs, centre, ext, top_z, max(0.0, float(ref_lo[2])), rects, sp, li, seed, lab,
                                 ccen, 0.0, ref_lo, ref_hi)
        meshes[ln] = mb
        n_cards[ln] = nc
        if eff0 is None:
            eff0 = eff
    obj = dict(info.get("object") or {})
    model = ModelData(model_id, "plant", obj)
    model.extent_m = sprite_extent(eff0, sspec["camera"].get("view_yaw", 0.0) if sspec else 0.0)
    model.tags = list(sspec.get("tags", [])) if sspec else ["prop", "plant", "ground_cover"]
    model.lods = [Lod("lod0", LOD.PROP_LOD_DIST["lod0"], [Part("body", "lod0_body", meshes["lod0"].finish())]),
                  Lod("lod1", LOD.PROP_LOD_DIST["lod1"], [Part("body", "lod1_body", meshes["lod1"].finish())])]
    model.textures["leaves"] = "leaves.png"
    model.texture_files["leaves.png"] = leafatlas.png_bytes(atlas_img)
    model.extra["cards"] = n_cards
    model.sets = _sets_of(model_id, spec3d)
    model.stats = dict(build_s=round(time.time() - t0, 2), blobs=len(blobs), cards=n_cards,
                       tris={n: meshes[n].triangles() for n in meshes})
    return model


def build_grass(model_id, spec3d):
    """Grass tufts (props/cover_grass): a few clumps of crossed blade cards, leaves class only."""
    t0 = time.time()
    g = spec3d["grass"]
    rng = random.Random(int(g.get("seed", 23)))
    atlas_img, rects = leafatlas.grass_atlas(GRASS, seed=int(g.get("seed", 23)))
    h_max = float(spec3d["object"]["height_m"])
    w = float(spec3d["object"]["width_m"])
    meshes, n_cards = {}, {}
    for li, ln in enumerate(("lod0", "lod1")):
        mb = core.MeshBuilder()
        rng = random.Random(int(g.get("seed", 23)))
        n = 0
        for k in range(g["tufts"] if li == 0 else max(2, g["tufts"] // 2)):
            cx = rng.uniform(-w * 0.38, w * 0.38)
            cy = rng.uniform(-w * 0.3, w * 0.3)
            hh = h_max * rng.uniform(0.62, 1.0) if k else h_max
            ww = hh * rng.uniform(1.0, 1.3)
            crosses = 3 if li == 0 else 2
            a0 = rng.uniform(0, math.pi)
            (ua, va, ub, vb) = rects["leaf"][rng.randrange(len(rects["leaf"]))]
            for j in range(crosses):
                a = a0 + math.pi * j / crosses
                dx, dy = math.cos(a) * ww * 0.5, math.sin(a) * ww * 0.5
                lean = np.array([rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), 0.0]) * hh
                q = np.array([[cx - dx, cy - dy, 0.0], [cx + dx, cy + dy, 0.0],
                              [cx + dx, cy + dy, hh], [cx - dx, cy - dy, hh]]) + np.array([0, 0, 0.0])
                q[2:] += lean
                uv = np.array([(ua, vb), (ub, vb), (ub, va), (ua, va)])
                tri = np.array([[0, 1, 2], [0, 2, 3]])
                pos = q[tri]
                # normals point up and out (grass is lit like the ground under it)
                nrm = np.array([0.0, 0.0, 1.0]) * 0.75 + np.array([math.sin(a), -math.cos(a), 0.0]) * 0.25
                nrm /= np.linalg.norm(nrm)
                nor = np.broadcast_to(nrm, (2, 3, 3)).copy()
                col = np.zeros((2, 3, 4))
                amp = (pos[..., 2] / max(0.05, hh)) * 0.5
                col[..., 0] = amp
                col[..., 1] = rng.random()
                col[..., 2] = 0.2
                col[..., 3] = rng.uniform(0.82, 1.0)
                mb.add("leaves", pos, nor, np.clip(np.round(col * 255), 0, 255).astype(np.uint8), uv[tri])
                n += 1
        meshes[ln] = mb
        n_cards[ln] = n
    model = ModelData(model_id, "plant", dict(spec3d["object"]))
    pts = meshes["lod0"].points()
    model.extent_m = sprite_extent(pts, 0.0)
    model.tags = ["prop", "plant", "ground_cover"]
    model.lods = [Lod("lod0", LOD.PROP_LOD_DIST["lod0"], [Part("body", "lod0_body", meshes["lod0"].finish())]),
                  Lod("lod1", LOD.PROP_LOD_DIST["lod1"], [Part("body", "lod1_body", meshes["lod1"].finish())])]
    model.textures["leaves"] = "leaves.png"
    model.texture_files["leaves.png"] = leafatlas.png_bytes(atlas_img)
    model.extra["cards"] = n_cards
    model.sets = _sets_of(model_id, spec3d)
    model.stats = dict(build_s=round(time.time() - t0, 2), cards=n_cards, tris={n: meshes[n].triangles() for n in meshes})
    return model


# --- impostor ------------------------------------------------------------------------------------------------

def render_impostor(mb, atlas_img, ref_lo, ref_hi, px=IMPOSTOR_PX, samples=16):
    """Picture of the card tree seen from the road (orthographic): the albedo of leaves and wood with the
    card brightness and a soft top-down shading, no directional light - billboard.gdshader lights it with
    ambient + sun of the moment. Returns (PNG bytes RGBA, [width_m, height_m], anchor_x)."""
    import bpy
    from cesprites import materials as M
    from cesprites import rig as R
    rig = R.Rig(quick=False)
    tmp = tempfile.mkdtemp(prefix="ce_imp_")
    atlas_path = os.path.join(tmp, "leaves.png")
    atlas_img.save(atlas_path)
    img = bpy.data.images.load(atlas_path)
    img.alpha_mode = "STRAIGHT"

    def emission_mat(name, textured):
        m, nb = M.new_material(name)
        att = nb.node("ShaderNodeAttribute")
        att.attribute_name = "ce_col"
        geo = nb.node("ShaderNodeNewGeometry")
        sep = nb.node("ShaderNodeSeparateXYZ")
        nb.links.new(geo.outputs["Normal"], sep.inputs[0])
        shade = nb.math("MULTIPLY_ADD", sep.outputs[2], 0.15 * IMPOSTOR_GAIN, 0.85 * IMPOSTOR_GAIN)
        em = nb.node("ShaderNodeEmission")
        if textured:
            tex = nb.node("ShaderNodeTexImage")
            tex.image = img
            k = nb.mul(shade, nb.math("POWER", att.outputs["Alpha"], 2.2))  # card brightness (sRGB factor)
            tint = nb.node("ShaderNodeVectorMath", operation="MULTIPLY")
            nb.links.new(nb.color_scale(tex.outputs["Color"], k), tint.inputs[0])
            tint.inputs[1].default_value = IMPOSTOR_TINT
            nb.links.new(tint.outputs[0], em.inputs["Color"])
            tr = nb.node("ShaderNodeBsdfTransparent")
            mix = nb.node("ShaderNodeMixShader")
            nb.links.new(nb.gt(tex.outputs["Alpha"], leafatlas.SCISSOR), mix.inputs[0])
            nb.links.new(tr.outputs[0], mix.inputs[1])
            nb.links.new(em.outputs[0], mix.inputs[2])
            res = mix.outputs[0]
        else:
            nb.links.new(nb.color_scale(att.outputs["Color"], shade), em.inputs["Color"])
            res = em.outputs[0]
        out = nb.node("ShaderNodeOutputMaterial")
        nb.links.new(res, out.inputs["Surface"])
        return m
    for cls, mat in (("vpbr", emission_mat("imp_wood", False)), ("leaves", emission_mat("imp_leaves", True))):
        chunks = mb.chunks.get(cls, [])
        if not chunks:
            continue
        pos = np.concatenate([c[0] for c in chunks])
        nor = np.concatenate([c[1] for c in chunks])
        col = np.concatenate([c[2] for c in chunks]).astype(np.float64) / 255.0
        t = pos.shape[0]
        me = bpy.data.meshes.new("imp_" + cls)
        me.from_pydata(pos.reshape(-1, 3).tolist(), [], np.arange(t * 3).reshape(-1, 3).tolist())
        if cls == "leaves":
            uv = np.concatenate([c[3] for c in chunks]).copy()
            uv[:, :, 1] = 1.0 - uv[:, :, 1]
            lay = me.uv_layers.new(name="uv")
            lay.data.foreach_set("uv", uv.reshape(-1).astype(np.float32))
        else:
            col[:, :, :3] = core.srgb_to_lin(col[:, :, :3])     # vertex colours are sRGB bytes
        ca = me.color_attributes.new("ce_col", "FLOAT_COLOR", "CORNER")
        ca.data.foreach_set("color", col.reshape(-1).astype(np.float32))
        for p in me.polygons:
            p.use_smooth = True
        me.normals_split_custom_set(nor.reshape(-1, 3).tolist())
        me.materials.append(mat)
        ob = bpy.data.objects.new("imp_" + cls, me)
        rig.col.objects.link(ob)
        ob.parent = rig.root
    margin = 0.25
    x0, x1 = float(ref_lo[0]) - margin, float(ref_hi[0]) + margin
    width_m = x1 - x0
    height_m = float(ref_hi[2]) + margin
    cw = px
    ch = int(math.ceil(px * height_m / width_m / 4.0)) * 4
    if ch > IMPOSTOR_MAX_PX:
        # slender trees: the longer side is capped (validator: impostor <= 512 px)
        ch = IMPOSTOR_MAX_PX
        cw = int(math.floor(IMPOSTOR_MAX_PX * width_m / height_m / 4.0)) * 4
    height_m = width_m * ch / cw
    anchor_x = -x0 / width_m
    # emission only: black world, no sun, plain sampling
    sc = rig.scene
    sc.world = rig.world_black
    rig.sun.hide_render = True
    sc.render.dither_intensity = 0.0
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.cycles.use_adaptive_sampling = False
    sc.cycles.max_bounces = 0
    sc.cycles.transparent_max_bounces = 48
    rig.frame_ortho(0.0, width_m, (cw, ch), (anchor_x, 1.0))
    path = os.path.join(tmp, "impostor.png")
    rig.render(path)
    from PIL import Image
    im = leafatlas.bleed(Image.open(path).convert("RGBA"), steps=8)
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)
    return buf.getvalue(), [round(width_m, 3), round(height_m, 3)], round(anchor_x, 4)
