"""Card trees, bushes, heather and ground cover for the mode "Modern" (contract D22, A-3; docs/modelle.md
sections 14 and 15).

The sprite generators (cesprites/props_nature.py) ARE the look of every species: their crown blobs, trunks,
branches and colours. This builder adds depth and detail to that design, it does not invent a new one.

Crown of a tree ("blob shells", AS3): every blob of the sprite crown (props_nature.CROWN_LOG: centre, radius, z
scale - an ellipsoid r, r, r zs) gets leaf cards on the part of its surface that no other blob covers. A card
lies on its blob, its plane never flatter than SPECIES el (a flat card on top of a crown is a streak from the
road), its texture upright (the clusters of the leaf atlas have their light side up). The shading normal of
every CORNER is the normal of the blob at that corner (blended with a little of the crown's roundness): each
blob is lit on its sun side and dark on the other like the shaded spheres of the Cycles sprite - per corner, not
per card, so neighbouring cards never jump in brightness (the "restless", noisy crown of wave 2). The brightness
of every corner (COLOR.a) is its ambient occlusion by the other blobs (rays): the creases between the blobs and
the inside of the crown are dark, as in the sprite. A closed leaf-mass core (rays from the crown's axis to the
farthest blob, shrunk; normals of the blob hit) fills what the cards leave open, shaded like them - a hole
between two cards shows deeper leaves, never the sky and never a black pane.
Wood: the generator's trunk and branches (branch parts outside the crown dropped), a limb into every clump of
blobs (k-means), darkened inside the crown by the same occlusion (no light stubs inside a crown); the trunk foot
reaches SPECIES sink metres below the ground with a little root flare (a tree on a slope never floats).

  lod0     wood (vpbr) + core and cards (leaves)              <= 2,500 triangles, <= 450 cards, 2 draw calls
  lod1     trunk and limbs + core, fewer and larger cards      <= 900 triangles, 2 draw calls
  shadow   leaf-mass hull + trunk (vpbr)                        the cheap caster for "Schatten: Mittel"
  impostor picture of lod0 (albedo with the corner brightness and a soft sky shading, lit by billboard.gdshader)
Special crowns: spruce (tiers of branch cards on the generator's cones, props_nature.SHAPE_LOG "tiers"),
cypress (blobs laid along the generator's lathe profile, SHAPE_LOG "profile"), palm (fronds with leaflets as bent
card strips along the generator's frond spines, SHAPE_LOG "fronds"; a trunk rebuilt with rings). Bushes and heather
(builder "bush", kind plant): the same blob shells in the class leaves only (ONE draw call), lod0 <= 400 and lod1 <=
120 triangles, no impostor. Grass tufts (builder "grass"): three crossed upright blade cards per tuft.

Leaf card vertex data (class "leaves", leaves.gdshader): UV = cell of the leaf atlas, COLOR = (sway amplitude by
height 0..1, phase per blob / frond, stiffness, brightness), NORMAL = outwards from the blob (and a little from
the crown): up-facing parts of a crown have up-facing normals (snow, rain: docs/modelle.md section 15).
Variants (catalog "variant_of"): the generator with another seed (and for the species whose generator draws no
random shape, a 3D-only shape parameter), no sets of their own - the set of the species lists them in "variants".
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

# --- species ---------------------------------------------------------------------------------------------------
#
# atlas     leafatlas.cluster parameters: leaf shape, the generator's two leaf colours (base), the gain / saturation
#           that bring the mean of the card tree to the sprite's colour under the race light (measured with
#           tools/models/prop_scene.sh --look=race --sprite), leaf size ...
# bark      [(object name prefix, (colour at the foot, colour higher up))] - first match wins ("" = any)
# cards     leaf cards of lod0 / lod1;  half: half size of a card in radii of its blob (lod0 / lod1)
# el        the card planes' normals stay within these degrees of the horizon (down, up)
# crown_w   share of the crown's roundness in the corner normals (the rest is the blob's);  up_w: lift
# ao        brightness of a corner = lo + (hi - lo) * occlusion ** gamma
# stiff     COLOR.b of the cards (leaves.gdshader: flutter x (1 - stiffness))
# core      leaf-mass core: shrink towards the axis, icosphere subdivisions lod0 / lod1, brightness, half length of
#           the axis the rays start from (slender crowns)
# clumps    k-means clumps of the blobs, one limb each;  limb_r: limb radius at the wood / at the end
# sink      the trunk foot reaches this far below the ground (m);  imp: impostor gain / blue tint / sky shading
# rims ... vis_w (AS3R): lod1 on lod0's rim (_rim_plan: rim_n0 vertices in lod0, every second one in lod1;
#           rings_extra = rings lod0 may add before the rim), the rim frayed (fray: angle share of a step, radius
#           share, hang of every second vertex in blob radii), the domes seen from below and from the side refined
#           first (vis_w); levels: the AS3 per-level plans (rims False: heather)
DEFAULTS = dict(
    levels=(((1, 6, 12), (1, 6, 12, 12)), ((1, 6), (1, 4, 8))), tris=(2480, 890),
    rims=True, rim_n0=12, rings_extra=1, fray=(0.35, 0.12, (0.05, 0.1)), vis_w=1.0,
    caps=((48.0, 118.0), (48.0, 118.0)), cap_margin=14.0, fringe=0.8, rim_out=0.05, jitter=0.07, lift=(1.0, 1.06),
    sky_lo=0.6, limbs1=False,
    cards=(420, 165), half=(0.6, 0.92), roll=0.35, el=(-34.0, 40.0), crown_w=0.22, up_w=0.08,
    ao=(0.42, 1.0, 0.9), stiff=0.55, core=dict(shrink=0.86, subdiv=(1, 0), bright=0.78, axis=0.0),
    shadow=dict(shrink=0.93, subdiv=2), clumps=7, limb_r=(0.1, 0.04), sink=0.55, atlas_seed=7,
    imp=dict(gain=1.22, tint=(1.04, 1.0, 1.25), sky=1.0, relief=0.6, sat=1.08, px=256),
    samples=48, out=0.03, sway0=0.3,
)

SPECIES = {
    "oak": dict(atlas=dict(leaf="lobed", base=("#3d6b25", "#5c8a30"), sat=0.72, gain=1.12, tint=(1.0, 1.0, 1.12)),
                bark=[("", ("#3b3025", "#544536"))], clumps=9, limb_r=(0.13, 0.05), atlas_seed=7, lift=(1.0, 1.14),
                imp=dict(gain=1.1)),
    "birch": dict(atlas=dict(leaf="birch", base=("#6f9a32", "#93b84a"), leaf_w=0.62, twig="#4a3a2a", sat=0.82,
                             gain=0.97, tint=(1.0, 1.0, 1.1)),
                  bark=[("", ("#e4e1d8", "#2b2722"))], birch=True, clumps=7, limb_r=(0.06, 0.025), atlas_seed=11,
                  core=dict(subdiv=(-1, -1)), ao=(0.55, 1.0, 0.9), imp=dict(gain=1.23, tint=(1.04, 1.0, 1.4), sat=1.15)),
    # AS3: broad, dense, bright green crown on a smooth grey trunk
    "beech": dict(atlas=dict(leaf="ovate", base=("#4a7a2a", "#6a9a35"), sat=0.78, gain=1.06, tint=(1.0, 1.0, 1.1)),
                  bark=[("", ("#66645e", "#85837c"))], clumps=9, limb_r=(0.11, 0.045), atlas_seed=23,
                  lift=(1.0, 1.12), imp=dict(gain=1.13)),
    # tall narrow column (avenues): rays of the core from the crown's axis
    "poplar": dict(atlas=dict(leaf="birch", base=("#43712a", "#5f8f35"), leaf_w=0.72, sat=0.8, gain=1.06,
                              tint=(1.0, 1.0, 1.1)),
                   bark=[("", ("#55514a", "#6e695f"))], clumps=8, limb_r=(0.07, 0.03), atlas_seed=29,
                   core=dict(axis=6.0), stiff=0.35, lift=(1.0, 1.13), imp=dict(gain=1.09)),
    # small silver-grey crown on a gnarled twin trunk; narrow leaves with pale undersides (AS3R, art review M10: fewer
    # and less pale undersides - under 20 m the crown read as a camouflage pattern)
    "olive": dict(atlas=dict(leaf="lanceolate", base=("#6f7d4f", "#9aa77a"), leaf_w=0.3, underside="#b4bc9e",
                             underside_share=0.15, sat=0.85, gain=1.04, tint=(1.0, 1.0, 1.06)),
                  bark=[("", ("#463e35", "#5c5246"))], clumps=6, limb_r=(0.09, 0.04), atlas_seed=53, gnarl=0.05,
                  lift=(1.0, 1.12), imp=dict(gain=1.1, tint=(1.0, 1.0, 1.08))),
    # Scots pine (as its sprite): a tall trunk, dark below, orange-red above, flat pads of needles on top
    "pine": dict(atlas=dict(leaf="needles", base=("#2c4f2a", "#3f6634"), sat=0.68, gain=1.16, tint=(1.0, 1.0, 1.08),
                            ball_leaf=(0.05, 0.075), ball_leaves=1300),
                 # AS3R (art review M11): the orange upper trunk and branches 15 % darker, as in the sprite
                 bark=[("pine_trunk2", ("#834829", "#8f5631")), ("pine_br", ("#7e4727", "#885231")),
                       ("pine_trunk", ("#4a382a", "#3c2d22")), ("", ("#7e4727", "#885231"))],
                 # AS3R: the thin pads sparkle in lod1 at 80-150 m - a calmer rim than the broadleaf domes
                 fray=(0.2, 0.06, (0.0, 0.03)),
                 clumps=6, limb_r=(0.08, 0.03), atlas_seed=31, core=dict(subdiv=(-1, -1)), sky_lo=0.5,
                 imp=dict(gain=0.98, tint=(1.04, 1.0, 1.05), sat=0.95)),
    # special crowns (ce3d/veg3d_shapes.py)
    "spruce": dict(shape="spruce", atlas=dict(leaf="needles", base=("#1e3d22", "#2d5530"), sat=0.55, gain=1.16,
                                              tint=(1.06, 1.0, 1.0)),
                   bark=[("", ("#3e2e21", "#4a3626"))], atlas_seed=7, stiff=0.7, lift=(1.0, 1.16),
                   imp=dict(gain=1.38, relief=0.3, lit=0.25, sat=1.05)),
    "cypress": dict(shape="cypress", atlas=dict(leaf="sprig", base=("#1f3a1f", "#2f4e28"), sat=0.45, gain=1.48,
                                                tint=(1.04, 1.0, 1.04), ball_leaf=(0.05, 0.08), ball_leaves=1500),
                    bark=[("", ("#3e2e21", "#4a3626"))], atlas_seed=3, stiff=0.75,
                    core=dict(axis=5.5, shrink=0.85, bright=1.0), imp=dict(gain=1.09, tint=(0.98, 1.0, 1.12))),
    "palm": dict(shape="palm", atlas=dict(leaf="frond", base=("#3f7a2a", "#6f9a38"), sat=0.85, gain=0.83,
                                          tint=(1.0, 1.0, 1.06)),
                 # AS3R (art review M8): a darker trunk (the light, warm pole stayed visible in the fog and at night)
                 # and a 512 px impostor (the thin fronds got lost at 256 px)
                 bark=[("", ("#4e4234", "#5f5141"))], atlas_seed=29, stiff=0.15,
                 imp=dict(gain=1.42, tint=(1.04, 1.0, 1.6), px=512)),
}


def _spec(name):
    sp = dict(DEFAULTS)
    for k, v in SPECIES[name].items():
        if isinstance(v, dict) and isinstance(sp.get(k), dict):
            sp[k] = dict(sp[k], **v)
        else:
            sp[k] = v
    return sp


# bushes: crowns of the generator (props_nature.bush_*) or the parameters of a ground-cover clump
# AS3R (art review M4): the bushes were 19-25 domes in 396 triangles - 5-gon fans, faceted "green boulders" with a
# camouflage pattern, paler than the sprite (saturation 0.34 against 0.42). Now the smallest generator balls merge
# into their neighbours (merge: at most so many domes), so that every dome of lod0 gets a frayed 12-gon rim
# (1, 6, 12); lod1 (from 60 m, no impostor after it) keeps its own coarser plan, with a core and the caps of lod0
# (its dark hole at 100 m); the leaf balls are more saturated with fewer pale highlights (sheen).
BUSHES = {
    "bush_round": dict(atlas=dict(leaf="ovate", base=("#3f6b28", "#5f8a33"), sat=0.72, gain=1.13, tint=(1.0, 1.0, 1.12),
                                  sheen=0.07, contrast=0.2),
                       atlas_seed=13, merge=15, lift=(1.0, 1.27)),
    "bush_low": dict(atlas=dict(leaf="ovate", base=("#466f2c", "#6a9037"), sat=0.72, gain=1.07, tint=(1.0, 1.0, 1.12),
                                sheen=0.07, contrast=0.2),
                     atlas_seed=17, merge=15),
    "cover_bush": dict(atlas=dict(leaf="ovate", base=("#466f2c", "#6a9037"), sat=0.72, gain=1.07, tint=(1.0, 1.0, 1.12),
                                  sheen=0.07, contrast=0.2),
                       atlas_seed=19),
    # AS3: heather - the generator's pink and green tufts (props_nature.SHAPE_LOG "heather"), fine sprigs; the pink
    # ones densely set with blossoms
    "heather": dict(atlas=dict(leaf="sprig", base=("#4d5a2c", "#6b7034"), sat=0.9, gain=0.92, ball_leaf=(0.06, 0.09),
                               ball_leaves=1100),
                    flowers=dict(leaf="sprig", base=("#634470", "#80548e"), flower=("#9658a8", "#a466b6", "#b47ac6"),
                                 flower_share=0.9, sat=0.9, gain=0.92, ball_leaf=(0.06, 0.09), ball_leaves=1100),
                    atlas_seed=47, levels=(((1, 6), (1, 5, 10)), ((1, 3), (1, 5))), tris=(396, 118), sway=0.25,
                    rims=False, core_subdiv=(0, 0), lift=(1.0, 1.16)),
}
# AS3: darker blades with more contrast and more of them - at 15 m the tufts of wave 2 read as one light-green spot
GRASS = dict(colors=("#3f5c22", "#4f6d28", "#5e7a2f", "#38521f", "#6b8236"), shade="#1a2614", tip="#86964a",
             n_blades=110)
GRASS_SINK_M = 0.1

OPAQUE = 0.82            # part of a card (from its centre) that counts as silhouette
IMPOSTOR_PX = 256
IMPOSTOR_MAX_PX = 512
CARDS_MAX = 450          # contract 4.6.9
WOOD_HULL = 0.9          # branches and limbs inside the crown only where they lie within this share of a blob (AS3R:
                         # twigs between the domes stuck out of the crown, art review M3) ...
WOOD_MASS = 0.92         # ... and within this share of the crown's outer surface seen from its axis (_inside_mass)


# --- source ------------------------------------------------------------------------------------------------

def _source(spec3d, shapes=False):
    """Sprite build with the crown log on: wood soups, reference points of the sprite model, blobs (and with
    shapes=True the shape log of the special crowns). The catalog entry's "params" go to the generator."""
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
    N.SHAPE_LOG = {}
    try:
        info = RA.build(rig, sspec)
        blobs = list(N.CROWN_LOG)
        shape = dict(N.SHAPE_LOG)
    finally:
        N.CROWN_LOG = None
        N.SHAPE_LOG = None
        MU.tagging(False)
    objs = core.model_objects(rig)
    wood = [o for o in objs if roles.node_of(o) == "body"]
    crown = [o for o in objs if roles.node_of(o) == "crown"]
    if not crown or (not blobs and not shape):
        raise RuntimeError("%s: the generator logged no crown" % spec3d["source"])
    wood_soups = core.soups_of(wood)
    crown_pts = np.concatenate([s.pos.reshape(-1, 3) for s in core.soups_of(crown)])
    if shapes:
        return sspec, info, wood_soups, crown_pts, blobs, shape
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


def _fib(n):
    """n directions evenly spread over the unit sphere (Fibonacci lattice)."""
    i = np.arange(n, dtype=np.float64) + 0.5
    phi = np.arccos(1.0 - 2.0 * i / n)
    th = math.pi * (1.0 + 5.0 ** 0.5) * i
    return np.stack([np.cos(th) * np.sin(phi), np.sin(th) * np.sin(phi), np.cos(phi)], axis=1)


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


def _tube(path, radii, segs, cap_end=True, colours=None):
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


# --- blobs: ellipsoids (r, r, r zs) ----------------------------------------------------------------------------

def _blob_arrays(blobs):
    bc = np.array([b[0] for b in blobs], dtype=np.float64).reshape(-1, 3)
    br = np.array([b[1] for b in blobs], dtype=np.float64)
    bz = np.array([b[2] for b in blobs], dtype=np.float64)
    return bc, br, bz


def _merge_blobs(bc, br, bz, n_max, grow=1.04):
    """Merges the smallest blob into its nearest neighbour (gap between their surfaces) until at most n_max remain
    (AS3R, bushes): centre and z scale weighted by volume, the volume of both (times grow). Deterministic."""
    c = [np.array(x, dtype=np.float64) for x in bc]
    r = [float(x) for x in br]
    z = [float(x) for x in bz]
    while len(r) > n_max:
        i = int(np.argmin(r))
        gaps = [np.linalg.norm(c[j] - c[i]) - r[j] if j != i else 1e9 for j in range(len(r))]
        j = int(np.argmin(gaps))
        vi, vj = r[i] ** 3 * z[i], r[j] ** 3 * z[j]
        c[j] = (c[i] * vi + c[j] * vj) / (vi + vj)
        z[j] = (z[i] * vi + z[j] * vj) / (vi + vj)
        r[j] = (r[i] ** 3 + r[j] ** 3) ** (1.0 / 3.0) * grow
        del c[i], r[i], z[i]
    return np.array(c), np.array(r), np.array(z)


def _scale3(bz):
    return np.stack([np.ones_like(bz), np.ones_like(bz), bz], axis=1)


def _ell_q(pts, bc, br, bz, shrink=1.0):
    """(P, B): squared distance of every point to every blob centre in units of the blob (1 = on its surface)."""
    d = (pts[:, None, :] - bc[None, :, :]) / _scale3(bz)[None, :, :]
    return (d ** 2).sum(axis=2) / (br[None, :] * shrink) ** 2


def _ell_normal(pts, c, zs):
    """Normals of the ellipsoids (centre c, z scale zs; per point) at pts: the direction of the gradient."""
    d = pts - c
    n = np.stack([d[:, 0], d[:, 1], d[:, 2] / np.maximum(zs, 1e-3) ** 2], axis=1)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)


def _ray_far(org, dirs, bc, br, bz, shrink=1.0):
    """(P, B) distance along each ray (org + t dirs) to the far surface of every blob; -1 where it misses."""
    sc = _scale3(bz)
    oc = (org[:, None, :] - bc[None, :, :]) / sc[None, :, :]
    ds = dirs[:, None, :] / sc[None, :, :]
    a = (ds ** 2).sum(axis=2)
    b = (ds * oc).sum(axis=2)
    c = (oc ** 2).sum(axis=2) - (br[None, :] * shrink) ** 2
    disc = b * b - a * c
    t = (-b + np.sqrt(np.maximum(disc, 0.0))) / np.maximum(a, 1e-12)
    return np.where(disc > 0.0, t, -1.0)


def _occlusion(points, normals, bc, br, bz, rays=16, shrink=0.9, seed=5):
    """Share of free directions (0..1) over the hemisphere of each normal against the blob ellipsoids."""
    rng = np.random.default_rng(seed)
    dirs = rng.normal(size=(rays, 3))
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    sc = _scale3(bz)
    r2 = (br * shrink) ** 2
    out = np.empty(points.shape[0])
    for s in range(0, points.shape[0], 192):
        p = points[s:s + 192]
        n = normals[s:s + 192]
        d = np.where((dirs[None, :, :] * n[:, None, :]).sum(axis=2, keepdims=True) < 0.0, -dirs[None], dirs[None])
        d = d * 0.7 + n[:, None, :] * 0.3
        d /= np.linalg.norm(d, axis=2, keepdims=True)                     # (P, R, 3)
        o = p + n * 0.05
        oc = (o[:, None, :] - bc[None, :, :]) / sc[None, :, :]              # (P, B, 3)
        ds = d[:, :, None, :] / sc[None, None, :, :]                       # (P, R, B, 3)
        a = (ds ** 2).sum(axis=3)
        b = (ds * oc[:, None, :, :]).sum(axis=3)
        c = (oc ** 2).sum(axis=2)[:, None, :] - r2[None, None, :]
        disc = b * b - a * c
        t_far = (-b + np.sqrt(np.maximum(disc, 0.0))) / np.maximum(a, 1e-12)
        hit = (disc > 0.0) & (t_far > 0.05)
        out[s:s + 192] = 1.0 - hit.any(axis=2).mean(axis=1)
    return out


def _star_hull(bc, br, bz, centre, shrink, subdiv, axis_half=0.0, z_min=None):
    """Closed leaf-mass hull of the blob set: rays from the crown's vertical axis (centre +- axis_half, by the
    direction's height) in the directions of an icosphere; every vertex lies at the farthest blob surface along
    its ray, pulled towards the ray's origin by `shrink`. Normal = the normal of the blob that was hit (the lumps
    and creases of the crown). Returns per-corner (pos (T, 3, 3), nor (T, 3, 3))."""
    v, f = _ico(subdiv)
    org = centre[None, :] + np.outer(v[:, 2], [0.0, 0.0, axis_half])
    t = _ray_far(org, v, bc, br, bz)
    best = t.argmax(axis=1)
    tb = t[np.arange(t.shape[0]), best]
    miss = tb <= 0.0
    if miss.all():
        raise RuntimeError("crown hull: no ray hits a blob")
    if miss.any():
        tb[miss] = float(np.median(tb[~miss])) * 0.7
    hit = org + v * tb[:, None]
    nrm = _ell_normal(hit, bc[best], bz[best])
    nrm[miss] = v[miss]
    p = org + v * (tb * shrink)[:, None]
    if z_min is not None:
        p[:, 2] = np.maximum(p[:, 2], z_min)
    return p[f], nrm[f]


# --- leaf cards on the blob shells -----------------------------------------------------------------------------

def _exposed(bc, br, bz, samples, z_floor=None):
    """Points of every blob's surface that no other blob covers (and, with z_floor, that lie above the ground):
    [(blob index, points (n, 3), normals)]."""
    dirs = _fib(samples)
    out = []
    for b in range(bc.shape[0]):
        p = bc[b] + br[b] * dirs * np.array([1.0, 1.0, bz[b]])
        q = _ell_q(p, bc, br, bz, 0.97)
        q[:, b] = 9.0
        free = (q >= 1.0).all(axis=1)
        if z_floor is not None:
            free &= p[:, 2] > z_floor
        if free.any():
            pts = p[free]
            out.append((b, pts, _ell_normal(pts, np.repeat(bc[b][None], pts.shape[0], 0),
                                            np.full(pts.shape[0], bz[b]))))
    return out


def _allocate(weights, total):
    """Largest-remainder split of `total` cards by weight."""
    w = np.asarray(weights, dtype=np.float64)
    if w.sum() <= 0.0:
        return np.zeros(len(w), dtype=np.int64)
    raw = w / w.sum() * total
    k = np.floor(raw).astype(np.int64)
    rest = int(total - k.sum())
    if rest > 0:
        k[np.argsort(-(raw - k), kind="stable")[:rest]] += 1
    return k


def _farthest(pts, k, first):
    """k indices of pts by farthest point sampling, starting with `first`."""
    k = min(k, pts.shape[0])
    sel = [first]
    d = np.linalg.norm(pts - pts[first], axis=1)
    while len(sel) < k:
        i = int(d.argmax())
        sel.append(i)
        d = np.minimum(d, np.linalg.norm(pts - pts[i], axis=1))
    return sel


def _ring_tris(n_in, n_out, o_in, o_out):
    """Triangles between a ring of n_in vertices and one of n_out = k * n_in (a pole when n_in == 1)."""
    tris = []
    if n_in == 1:
        for j in range(n_out):
            tris.append((o_in, o_out + j, o_out + (j + 1) % n_out))
        return tris
    k = n_out // n_in
    for j in range(n_in):
        a, b = o_in + j, o_in + (j + 1) % n_in
        for s in range(k):
            c0 = o_out + (j * k + s) % n_out
            c1 = o_out + (j * k + s + 1) % n_out
            tris.append((a, c0, c1))
        tris.append((a, o_out + ((j + 1) * k) % n_out, b))
    return tris


def _pattern_tris(rings):
    return sum(len(_ring_tris(rings[i], rings[i + 1], 0, rings[i])) for i in range(len(rings) - 1))


def _dome_plan(exp, bc, br, bz, levels, budget, min_exposed):
    """Which blobs get a dome and how finely it is divided: every dome starts at levels[0]; the most important ones
    (exposed surface x how open it is to the outside) are refined level by level while the triangle budget allows;
    if even the base level is over the budget, the least important domes drop to a plain fan (levels[-1] is never
    used for that) or are left out. Returns [(exp index, rings)]."""
    cand = []
    for i, (b, pts, nrm) in enumerate(exp):
        if pts.shape[0] < min_exposed:
            continue
        ao = _occlusion(pts, nrm, bc, br, bz, rays=10, seed=11)
        cand.append((i, pts.shape[0] * br[b] ** 2 * (0.25 + float(ao.mean()))))
    order = [c[0] for c in sorted(cand, key=lambda c: -c[1])]
    cost = [_pattern_tris(r) for r in levels]
    level = {i: 0 for i in order}
    used = cost[0] * len(order)
    # over the budget at the base level: the least important domes become fans of 5 (if that is smaller), then go
    small = (1, 5) if _pattern_tris((1, 5)) < cost[0] else None
    if small is not None:
        for i in reversed(order):
            if used <= budget:
                break
            level[i] = -1
            used -= cost[0] - _pattern_tris(small)
    for i in reversed(order):
        if used <= budget:
            break
        if level[i] is not None:
            used -= _pattern_tris(small) if level[i] == -1 else cost[0]
            level[i] = None
    for li in range(1, len(levels)):
        for i in order:
            if level[i] != li - 1:
                continue
            extra = cost[li] - cost[li - 1]
            if used + extra <= budget:
                level[i] = li
                used += extra
    out = []
    for i in order:
        if level[i] is None:
            continue
        out.append((i, small if level[i] == -1 else levels[level[i]]))
    return sorted(out)


def _dome_frames(exp, bc, br, bz, centre, sp, cap):
    """Frame of every dome - the same in every level: [{"ei": exposed index, "b": blob, "axis", "e1", "e2", "theta"
    (cap angle), "imp" (exposed area x r^2 x openness), "prio" (imp x visibility from the road)}]. The road sees a
    crown from below and from the side (the chase camera is 3.4 m high): domes whose axis points down or sideways
    are refined first (AS3R, art review M3 - their rims made the "lampshade" edges)."""
    margin = math.radians(sp.get("cap_margin", 14.0))
    lo_cap, hi_cap = (math.radians(a) for a in cap)
    vis_w = float(sp.get("vis_w", 0.0))
    frames = []
    for ei, (b, pts, nrm) in enumerate(exp):
        if pts.shape[0] < sp.get("min_exposed", 2):
            continue
        s3 = np.array([1.0, 1.0, bz[b]])
        dirs = (pts - bc[b]) / (br[b] * s3)
        dirs /= np.maximum(np.linalg.norm(dirs, axis=1, keepdims=True), 1e-9)
        axis = dirs.mean(axis=0)
        if np.linalg.norm(axis) < 0.2:
            axis = bc[b] - centre
        if np.linalg.norm(axis) < 1e-6:
            axis = np.array([0.0, 0.0, 1.0])
        axis = axis / max(1e-9, np.linalg.norm(axis))
        theta = float(np.arccos(np.clip(dirs @ axis, -1.0, 1.0)).max()) + margin
        theta = max(lo_cap, min(hi_cap, theta))
        tmp = np.array([0.0, 0.0, 1.0]) if abs(axis[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        e1 = np.cross(axis, tmp)
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(axis, e1)
        ao = _occlusion(pts, nrm, bc, br, bz, rays=10, seed=11)
        imp = pts.shape[0] * br[b] ** 2 * (0.25 + float(ao.mean()))
        frames.append(dict(ei=ei, b=b, axis=axis, e1=e1, e2=e2, theta=theta, imp=imp,
                           prio=imp * (1.0 + vis_w * 0.5 * (1.0 - float(axis[2])))))
    return frames


def _rim_plan(frames, br, budget0, budget1, sp):
    """Ring patterns of every dome in lod0 and lod1 (AS3R, art review M3/M6). lod0: every dome a frayed rim of
    rim_n0 (12) vertices, (1, 6, 12), refined by a ring of 12 before the rim, (1, 6, 12, 12), in the order of `prio`
    (visibility from the road) within lod0's budget. lod1 lies on the SAME rim: every second of its vertices (same
    position, jitter, hang and texture placement), as (1, 3, 6) where lod1's budget allows (prio order), else as the
    fan (1, 6). (A lod1 of plain fans over the whole rim was tried: the flat cones sink into the blob, the core shows
    through - lod1 was 26 % darker, 15 % smaller and spiky, measured.) Over lod0's budget the least important domes
    become fans of six, then go. Returns ({frame: {"rings", "src"}} lod0, same for lod1); src = rim count the rim
    vertices come from."""
    order = sorted(range(len(frames)), key=lambda i: -frames[i]["prio"])
    n0 = int(sp.get("rim_n0", 12))
    half = n0 // 2
    c_base, c_fan, c_ring = 2 * n0, half, 2 * n0
    plan0 = {i: {"rings": (1, half, n0), "src": n0} for i in order}
    used0 = c_base * len(order)
    for i in reversed(order):
        if used0 <= budget0:
            break
        plan0[i] = {"rings": (1, half), "src": n0}
        used0 -= c_base - c_fan
    for i in reversed(order):
        if used0 <= budget0:
            break
        if i in plan0:
            used0 -= c_fan if len(plan0[i]["rings"]) == 2 else c_base
            plan0.pop(i)
    for _extra in range(int(sp.get("rings_extra", 1))):
        for i in order:
            if i in plan0 and len(plan0[i]["rings"]) >= 3 and used0 + c_ring <= budget0:
                r = plan0[i]["rings"]
                plan0[i] = {"rings": r[:-1] + (n0, n0), "src": n0}
                used0 += c_ring
    plan1 = {}
    used1 = 0
    for i in order:
        if i in plan0 and used1 + half <= budget1:
            plan1[i] = {"rings": (1, half), "src": n0}
            used1 += half
    mid = half // 2
    if mid >= 2 and half % mid == 0:
        extra = mid + _pattern_tris((mid, half)) - half
        for i in order:
            if i in plan1 and used1 + extra <= budget1:
                plan1[i] = {"rings": (1, mid, half), "src": n0}
                used1 += extra
        # budget left (crowns of few domes: pine, olive): the whole rim of lod0, (1, 6, 12) - lod1 is then lod0
        # without its extra ring (the pine's thin pads sparkled with six-cornered rims at 80-150 m)
        up = c_base - (mid + _pattern_tris((mid, half)))
        for i in order:
            if i in plan1 and plan1[i]["rings"] == (1, mid, half) and used1 + up <= budget1:
                plan1[i] = {"rings": (1, half, n0), "src": n0}
                used1 += up
    return plan0, plan1


def _dome_cards(frames, plan, bc, br, bz, centre, ext, rects, seed, sp, blob_rects=None):
    """Leaf domes (AS3): one curved card per blob, lying on its ellipsoid and covering the part of it that no other
    blob covers (its exposed cap, plus a margin that runs into the neighbours): seen from anywhere it is never
    edge-on except at its rim, where the ragged fringe of the leaf-ball texture makes the blob's outline leafy.
    plan: {frame index: ring pattern} (vertices per ring from the pole outwards, e.g. (1, 6, 12)).
    The rim (AS3R, art review M3/M6) comes from the blob's own random stream, so it is the same in every level with
    the same rim count: its vertices are frayed (angle +- fray[0] of a step, radius +- fray[1]) and every second one
    hangs a little lower (fray[2] of the radius) - hanging leaves instead of a straight polygon edge. Inner rings use
    a stream of their own. Returns a dome dict: pos (V, 3), nor (V, 3), uv (V, 2), col (V, 4) floats, tri (T, 3) int,
    eff (N, 3) the opaque part, blob_of_v (V), domes (count)."""
    pos, nor, uvs, cols, tris, eff, owner = [], [], [], [], [], [], []
    fringe = sp.get("fringe", 0.86)          # radius of the opaque part of a leaf ball (share of the cell radius)
    fray_a, fray_r, hang = sp.get("fray", (0.35, 0.12, (0.05, 0.1)))
    jit = sp.get("jitter", 0.0)
    domes = 0
    for fi, fr in enumerate(frames):
        if fi not in plan:
            continue
        p_entry = plan[fi]
        if isinstance(p_entry, dict):
            rings, src = tuple(p_entry["rings"]), int(p_entry["src"])
        else:
            rings, src = tuple(p_entry), int(p_entry[-1])
        n_rings = len(rings)
        b = fr["b"]
        axis, e1, e2, theta = fr["axis"], fr["e1"], fr["e2"], fr["theta"]
        s3 = np.array([1.0, 1.0, bz[b]])
        # cell, turn, wind phase and rim of a blob are the same in every level (its own random stream): at a level
        # swap the leaves of a blob stay where they were
        brng = random.Random(seed * 7919 + b)
        rot = brng.uniform(0.0, 2.0 * math.pi)
        cells = rects if blob_rects is None else blob_rects[b]
        (ua, va, ub, vb) = cells[brng.randrange(len(cells))]
        cu, cv = (ua + ub) * 0.5, (va + vb) * 0.5
        ru, rv = (ub - ua) * 0.5 * 0.98, (vb - va) * 0.5 * 0.98
        ph = brng.random()
        # the rim of `src` vertices (lod0's); a coarser level takes every step-th of them, unchanged
        step = max(1, src // rings[-1])
        rim_turn = brng.uniform(0.0, 2.0 * math.pi / src)
        rim = [(brng.uniform(-fray_a, fray_a), brng.uniform(-fray_r, fray_r),
                brng.uniform(hang[0], hang[1]) if j % 2 else 0.0, brng.uniform(-0.04, 0.04)) for j in range(src)]
        irng = random.Random(seed * 104729 + b * 31 + n_rings)
        o0 = len(pos)
        offs = []
        for ri, n in enumerate(rings):
            offs.append(len(pos) - o0)
            f = ri / max(1, n_rings - 1)
            psi = theta * f
            last = ri == n_rings - 1
            for j in range(n):
                if last:
                    js = j * step
                    ja, jr, jh, jp = rim[js]
                    phi = 2.0 * math.pi * (js + ja) / src + rim_turn
                    out = 1.0 + sp["out"] + sp.get("rim_out", 0.04) + jr
                elif ri == 0:
                    jh, jp, phi = 0.0, irng.uniform(-0.04, 0.04), 0.0
                    out = 1.0 + sp["out"]
                else:
                    # an irregular outline: every vertex a little off its ring (angle) and off the blob (radius) -
                    # the displaced spheres of the sprite are lumpy, a regular polygon would read as a cut gem
                    twist = (0.5 / n) * 2.0 * math.pi if ri % 2 else 0.0
                    jh, jp = 0.0, irng.uniform(-0.04, 0.04)
                    phi = 2.0 * math.pi * (j + irng.uniform(-0.22, 0.22)) / n + twist + rim_turn
                    out = 1.0 + sp["out"] + sp.get("rim_out", 0.04) * f * f + irng.uniform(-jit, jit) * f
                d = math.cos(psi) * axis + math.sin(psi) * (math.cos(phi) * e1 + math.sin(phi) * e2)
                p = bc[b] + br[b] * out * d * s3
                p[2] -= jh * br[b]
                pos.append(p)
                uvs.append((cu + f * ru * math.cos(phi + rot), cv + f * rv * math.sin(phi + rot)))
                cols.append((0.0, (ph + jp) % 1.0, sp["stiff"], 1.0))
                owner.append(b)
                if last:
                    de = math.cos(psi * fringe) * axis + math.sin(psi * fringe) * (math.cos(phi) * e1 + math.sin(phi) * e2)
                    eff.append(bc[b] + br[b] * (1.0 + sp["out"]) * de * s3)
                elif ri > 0:
                    eff.append(pos[-1])
        for ri in range(n_rings - 1):
            tris += _ring_tris(rings[ri], rings[ri + 1], o0 + offs[ri], o0 + offs[ri + 1])
        domes += 1
    pos = np.array(pos)
    tri = np.array(tris, dtype=np.int64)
    owner = np.array(owner, dtype=np.int64)
    # outward winding (the leaves shader draws both faces; the validator and the caster count windings)
    fn = np.cross(pos[tri[:, 1]] - pos[tri[:, 0]], pos[tri[:, 2]] - pos[tri[:, 0]])
    out_dir = pos[tri].mean(axis=1) - bc[owner[tri[:, 0]]]
    flip = (fn * out_dir).sum(axis=1) < 0.0
    tri[flip] = tri[flip][:, ::-1]
    d = dict(pos=pos, uv=np.array(uvs), col=np.array(cols), tri=tri, eff=np.array(eff), blob_of_v=owner,
             domes=domes)
    d["nor"] = _vertex_normals(pos, owner, bc, bz, centre, ext, sp)
    ao = _occlusion(pos, d["nor"], bc, br, bz)
    lo, hi, g = sp["ao"]
    d["col"][:, 3] = np.clip((lo + (hi - lo) * np.power(np.clip(ao, 0.0, 1.0), g)) * _sky(d["nor"], sp), 0.08, 1.0)
    return d


def _level_plans(exp, frames, bc, br, bz, budgets, sp):
    """Dome plans of lod0 and lod1: shared rims (_rim_plan, sp rims True) or, for heather, a plan of its own per level
    from sp levels (_dome_plan, the AS3 way: 30 small tufts cannot share rims within 120 triangles)."""
    if sp.get("rims", True):
        return _rim_plan(frames, br, budgets[0], budgets[1], sp)
    fi_of = {fr["ei"]: fi for fi, fr in enumerate(frames)}
    out = []
    for li in range(2):
        plan = _dome_plan(exp, bc, br, bz, sp["levels"][li], budgets[li], sp.get("min_exposed", 2))
        out.append({fi_of[ei]: rings for (ei, rings) in plan if ei in fi_of})
    return out[0], out[1]


def _sky(nor, sp):
    """Light from the sky above (the ambient light of the renderer comes from all sides alike): the underside of a
    blob gets less of it - sky_lo for a normal straight down, 1 straight up (the shaded spheres of the sprite)."""
    lo = float(sp.get("sky_lo", 0.6))
    return lo + (1.0 - lo) * (0.5 + 0.5 * np.clip(nor[..., 2], -1.0, 1.0))


def _vertex_normals(pos, owner, bc, bz, centre, ext, sp):
    nb = _ell_normal(pos, bc[owner], bz[owner])
    rc = (pos - centre) / ext
    rc /= np.maximum(np.linalg.norm(rc, axis=1, keepdims=True), 1e-9)
    n = nb * (1.0 - sp["crown_w"]) + rc * sp["crown_w"] + np.array([0.0, 0.0, sp["up_w"]])
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)


def _dome_arrays(d, z0, top_z, amp_k=1.0):
    """Per-corner triangle arrays of the domes: pos, nor, uv, col uint8 (sway amplitude by height in COLOR.r)."""
    col = d["col"].copy()
    col[:, 0] = np.clip((d["pos"][:, 2] - z0) / max(0.5, top_z - z0), 0.0, 1.0) * amp_k
    t = d["tri"]
    return (d["pos"][t], d["nor"][t], d["uv"][t],
            np.clip(np.round(col[t] * 255.0), 0, 255).astype(np.uint8))


def _card_frame(n, p, centre, el_lim, rng, roll_max):
    """Axes (u right, v up) of a card at p whose blob normal is n: its plane normal keeps n's direction but no
    more than el_lim (degrees) above / below the horizon; v points up the card (the leaf clusters stay upright)."""
    h = n[:2]
    if np.linalg.norm(h) < 0.2:
        h = (p - centre)[:2]
    if np.linalg.norm(h) < 1e-3:
        a = rng.uniform(0.0, 2.0 * math.pi)
        h = np.array([math.cos(a), math.sin(a)])
    az = math.atan2(h[1], h[0])
    el = math.asin(max(-1.0, min(1.0, float(n[2]))))
    el = max(math.radians(el_lim[0]), min(math.radians(el_lim[1]), el))
    m = np.array([math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)])
    u = np.cross(np.array([0.0, 0.0, 1.0]), m)
    u /= np.linalg.norm(u)
    v = np.cross(m, u)
    roll = rng.uniform(-roll_max, roll_max)
    return u * math.cos(roll) + v * math.sin(roll), -u * math.sin(roll) + v * math.cos(roll), m


def _shell_cards(bc, br, bz, centre, ext, n_cards, half_k, rects, seed, sp, weights=None, bright_mul=1.0,
                 blob_rects=None):
    """Leaf cards on the exposed shells of the blobs (see the module text). blob_rects: per blob its own list of
    atlas cells (heather: flowers or foliage). Returns a card dict: quad (C, 4, 3), nor (C, 4, 3) corner normals,
    uv (C, 4, 2), col (C, 4, 4) floats (r filled later), blob (C), p0 (C, 3)."""
    rng = random.Random(seed)
    exp = _exposed(bc, br, bz, sp["samples"], sp.get("z_floor"))
    w = [pts.shape[0] * br[b] ** 2 * (1.0 if weights is None else weights[b]) for (b, pts, _n) in exp]
    ks = _allocate(w, n_cards)
    quads, nors, uvs, cols, blob_ids, p0s = [], [], [], [], [], []
    phase = {}
    for (b, pts, nrm), k in zip(exp, ks):
        if k <= 0:
            continue
        outward = ((pts - centre) / np.maximum(np.linalg.norm(pts - centre, axis=1, keepdims=True), 1e-9) * nrm).sum(axis=1)
        for i in _farthest(pts, int(k), int(outward.argmax())):
            p, n = pts[i], nrm[i]
            u, v, _m = _card_frame(n, p, centre, sp["el"], rng, sp["roll"])
            h = half_k * br[b] * rng.uniform(0.88, 1.12)
            p0 = p + n * br[b] * sp["out"]
            quads.append(np.array([p0 - u * h - v * h, p0 + u * h - v * h, p0 + u * h + v * h, p0 - u * h + v * h]))
            cells = rects if blob_rects is None else blob_rects[b]
            (ua, va, ub, vb) = cells[rng.randrange(len(cells))]
            uvs.append(np.array([(ua, vb), (ub, vb), (ub, va), (ua, va)]))
            if b not in phase:
                phase[b] = rng.random()
            cols.append(np.array([[0.0, (phase[b] + rng.uniform(-0.06, 0.06)) % 1.0, sp["stiff"], 1.0]] * 4))
            blob_ids.append(b)
            p0s.append(p0)
    quad = np.array(quads)
    cards = dict(quad=quad, uv=np.array(uvs), col=np.array(cols), blob=np.array(blob_ids, dtype=np.int64),
                 p0=np.array(p0s))
    cards["nor"] = _corner_normals(quad, cards["blob"], bc, bz, centre, ext, sp)
    _shade_corners(cards, bc, br, bz, sp, bright_mul)
    return cards


def _corner_normals(quad, blob, bc, bz, centre, ext, sp):
    """Shading normal of every corner: the blob's normal there, a share of the crown's roundness, a lift."""
    c = quad.reshape(-1, 3)
    bi = np.repeat(blob, 4)
    nb = _ell_normal(c, bc[bi], bz[bi])
    rc = (c - centre) / ext
    rc /= np.maximum(np.linalg.norm(rc, axis=1, keepdims=True), 1e-9)
    n = nb * (1.0 - sp["crown_w"]) + rc * sp["crown_w"] + np.array([0.0, 0.0, sp["up_w"]])
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    return n.reshape(quad.shape)


def _shade_corners(cards, bc, br, bz, sp, bright_mul=1.0):
    """COLOR.a of every corner: occlusion by the blobs (the creases and the inside of the crown are dark)."""
    c = cards["quad"].reshape(-1, 3)
    n = cards["nor"].reshape(-1, 3)
    ao = _occlusion(c, n, bc, br, bz)
    lo, hi, g = sp["ao"]
    b = (lo + (hi - lo) * np.power(np.clip(ao, 0.0, 1.0), g)) * bright_mul
    cards["col"][:, :, 3] = np.clip(b, 0.08, 1.0).reshape(-1, 4)


def _card_arrays(cards, z0, top_z):
    """Per-corner triangle arrays of the cards (two triangles each): pos (T, 3, 3), nor, uv, col uint8 (sway
    amplitude by height in COLOR.r)."""
    tri = np.array([[0, 1, 2], [0, 2, 3]])
    col = cards["col"].copy()
    col[:, :, 0] = np.clip((cards["quad"][:, :, 2] - z0) / max(0.5, top_z - z0), 0.0, 1.0)
    pos = cards["quad"][:, tri, :].reshape(-1, 3, 3)
    nor = cards["nor"][:, tri, :].reshape(-1, 3, 3)
    uv = cards["uv"][:, tri, :].reshape(-1, 3, 2)
    c8 = np.clip(np.round(col[:, tri, :].reshape(-1, 3, 4) * 255.0), 0, 255).astype(np.uint8)
    return pos, nor, uv, c8


def _subset(cards, keep):
    return {k: v[keep] for k, v in cards.items()}


# --- fitting the silhouette to the sprite -------------------------------------------------------------------------

class _Fit:
    """Maps the crown so that the silhouette of cards (their opaque part) and wood has the sprite's bounds: x and
    y linearly, z above the crown centre scaled so that the top matches. The same map moves every level's
    cards, core and shadow hull."""

    def __init__(self, eff_pts, wood_pts, ref_lo, ref_hi, centre):
        pts = np.concatenate([eff_pts, wood_pts]) if wood_pts.shape[0] else eff_pts
        self.lo, self.hi = pts.min(axis=0), pts.max(axis=0)
        self.ref_lo, self.ref_hi = ref_lo, ref_hi
        self.c = float(centre[2])
        self.kz = (ref_hi[2] - self.c) / max(1e-6, self.hi[2] - self.c)
        self.k = [(ref_hi[ax] - ref_lo[ax]) / max(1e-6, self.hi[ax] - self.lo[ax]) for ax in (0, 1)]

    def __call__(self, a):
        a = np.array(a, dtype=np.float64, copy=True)
        for ax in (0, 1):
            a[..., ax] = self.ref_lo[ax] + (a[..., ax] - self.lo[ax]) * self.k[ax]
        a[..., 2] = np.where(a[..., 2] > self.c, self.c + (a[..., 2] - self.c) * self.kz, a[..., 2])
        return a


def _eff(cards):
    """The opaque part of the cards (OPAQUE of each corner's distance from the card centre): (N, 3)."""
    return (cards["p0"][:, None, :] + (cards["quad"] - cards["p0"][:, None, :]) * OPAQUE).reshape(-1, 3)


# --- wood ----------------------------------------------------------------------------------------------------

def _bark_pair(sp, name):
    for prefix, pair in sp["bark"]:
        if name.startswith(prefix):
            return pair
    return sp["bark"][-1][1]


def _bark_colour(pair, pos, z_top):
    """Vertex colours of the wood (sRGB floats 0..255): darker at the foot. (Birch trunks: _birch_trunk.)"""
    c1 = np.array(core.srgb8(core.hex_to_lin(pair[0])), dtype=np.float64)
    c2 = np.array(core.srgb8(core.hex_to_lin(pair[1])), dtype=np.float64)
    z = pos[..., 2]
    t = np.clip(z / max(1.0, z_top), 0.0, 1.0)
    col = c1[None, None, :] * (1.0 - t[..., None] * 0.35) + c2[None, None, :] * (t[..., None] * 0.35)
    col = col * (0.9 + 0.1 * np.clip(z / 1.5, 0.0, 1.0))[..., None]
    return col


def _wood_shade(pos, nor, bc, br, bz):
    """Darkening of wood by the crown above and around it (occlusion against the blobs): 0.35 .. 1."""
    if bc.shape[0] == 0:
        return np.ones(pos.shape[:2])
    ao = _occlusion(pos.reshape(-1, 3), nor.reshape(-1, 3), bc, br, bz, rays=12, shrink=0.95)
    return (0.35 + 0.65 * ao).reshape(pos.shape[:2])


def _add_wood(mb, sp, parts, z_top, bc, br, bz, rough=0.9):
    """parts: [(object name, pos (T, 3, 3), nor)] or [(name, pos, nor, colours (T, 3, 3) sRGB 0..255)] (a birch
    trunk brings its bark) -> one vpbr chunk with bark colours and crown shading."""
    if not parts:
        return
    poss, nors, cols = [], [], []
    for item in parts:
        name, pos, nor = item[:3]
        if pos.shape[0] == 0:
            continue
        if len(item) > 3 and item[3] is not None:
            col = item[3]
        else:
            col = _bark_colour(_bark_pair(sp, name), pos, z_top)
        col = col * _wood_shade(pos, nor, bc, br, bz)[..., None]
        poss.append(pos)
        nors.append(nor)
        cols.append(col)
    pos = np.concatenate(poss)
    nor = np.concatenate(nors)
    out = np.empty(pos.shape[:2] + (4,), dtype=np.uint8)
    out[..., :3] = np.clip(np.round(np.concatenate(cols)), 0, 255).astype(np.uint8)
    out[..., 3] = 255
    pos, nor, out = _wind(pos, nor, out)
    mb.add("vpbr", pos, nor, out, (rough, 0.0), roles.NO_LAMP)


def _wind(pos, nor, *extra):
    """Every triangle wound along its shading normal (a gnarled or displaced surface folds a few of them over)."""
    if pos.shape[0] == 0:
        return (pos, nor) + extra
    fn = np.cross(pos[:, 1] - pos[:, 0], pos[:, 2] - pos[:, 0])
    flip = (fn * nor.mean(axis=1)).sum(axis=1) < 0.0
    if not flip.any():
        return (pos, nor) + extra
    out = []
    for a in (pos, nor) + extra:
        a = np.array(a, copy=True)
        a[flip] = a[flip][:, ::-1]
        out.append(a)
    return tuple(out)


def _inside_crown(pts, bc, br, bz, shrink=0.97):
    """True for points inside one of the blobs (scaled by shrink)."""
    if bc.shape[0] == 0:
        return np.zeros(pts.shape[0], dtype=bool)
    return (_ell_q(pts, bc, br, bz, shrink) < 1.0).any(axis=1)


def _inside_mass(pts, bc, br, bz, centre, axis_half=0.0, k=WOOD_MASS):
    """True for points deep inside the crown as a whole (AS3R): nearer to the crown's axis than k x the farthest blob
    surface along the ray from the axis (the rays of the core, _star_hull). A twig inside one blob can still lie just
    under the crown's outer surface, where the domes leave gaps - it showed as a dark stick on the crown top."""
    if bc.shape[0] == 0 or pts.shape[0] == 0:
        return np.ones(pts.shape[0], dtype=bool)
    d = pts - centre
    dn = d / np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-9)
    org = centre[None, :] + np.outer(dn[:, 2], [0.0, 0.0, axis_half])
    rel = pts - org
    dist = np.linalg.norm(rel, axis=1)
    dirs = rel / np.maximum(dist[:, None], 1e-9)
    t = _ray_far(org, dirs, bc, br, bz).max(axis=1)
    return (t > 0.0) & (dist <= k * t)


def _sink(pos, nor, depth, flare=1.12):
    """The foot of a trunk reaches `depth` below the ground: vertices at the ground go down, a little wider."""
    if depth <= 0.0:
        return pos
    pos = pos.copy()
    low = pos[..., 2] < 0.03
    pos[..., 2] = np.where(low, pos[..., 2] - depth, pos[..., 2])
    pos[..., 0] = np.where(low, pos[..., 0] * flare, pos[..., 0])
    pos[..., 1] = np.where(low, pos[..., 1] * flare, pos[..., 1])
    return pos


def _tree_wood(soups, bc, br, bz, crown_bottom, sp, z_cut=None, seed=0, centre=None):
    """[(name, pos, nor)] of the wood of a tree: the generator's trunk and branches; branch parts that are not well
    inside the crown (WOOD_HULL of the blobs and, with `centre`, WOOD_MASS of the whole crown: twigs sticking out of
    the leaf domes, AS3R) are dropped; birch
    trunks are rebuilt with the bands of their bark (_birch_trunk: [(name, pos, nor, colours)]); the trunk foot
    sinks into the ground."""
    out = []
    for s in soups:
        cen = s.pos.mean(axis=1)
        keep = np.ones(s.n, dtype=bool)
        trunk = "trunk" in s.name or "_t1" in s.name or "_t2" in s.name
        if not trunk:
            # a trunk is never cut (a half tube shows the sky through it); branches end at the level's cut
            if z_cut is not None:
                keep &= cen[:, 2] < z_cut
            deep = _inside_crown(cen, bc, br, bz, WOOD_HULL)
            if centre is not None:
                deep &= _inside_mass(cen, bc, br, bz, centre, sp["core"]["axis"])
            keep &= (cen[:, 2] < crown_bottom + 0.5) | deep
        if trunk and sp.get("birch"):
            p, n, c = _birch_trunk(s, sp, crown_bottom, z_cut, seed)
            out.append((s.name, _sink(p, n, sp["sink"]), n, c))
            continue
        if keep.any():
            p = s.pos[keep]
            if sp.get("gnarl"):
                p = _gnarl(p, s.nor[keep], sp["gnarl"])
            out.append((s.name, _sink(p, s.nor[keep], sp["sink"]) if trunk else p, s.nor[keep]))
    return out


def _gnarl(pos, nor, amount):
    """Gnarled wood (olive): every corner pushed along its normal by a smooth pseudo-noise of its position."""
    x, y, z = pos[..., 0], pos[..., 1], pos[..., 2]
    k = (np.sin(x * 7.1 + y * 3.7 + z * 5.3) * np.cos(z * 4.2 + x * 2.1) + 0.5 * np.sin(z * 11.0 + y * 6.0)) / 1.5
    return pos + nor * (k * amount)[..., None]


# Birch bark (AS3R, art review M1: the trunk was a checkerboard of black and white triangles): white bark with thin
# horizontal bands - every mark a band of its own pair of rings, dark over 1..3 of the BIRCH_SEGS segments (crisp:
# one colour per quad, the welder keeps the colours apart), denser, taller and wider near the foot, sparse inside the
# crown. lod1 draws the same marks (same heights and segments: nothing jumps at the swap) but only the larger ones,
# twice as tall and half as dark - the same mean colour, and no sub-pixel stripes that crawl at 60 m and beyond.
BIRCH_SEGS = 6
BIRCH_WHITE = "#e4e1d8"
BIRCH_MARK = "#2b2722"
BIRCH_GREY = "#8e887d"
BIRCH_FOOT_M = 1.6        # the dense, dark zone of the marks
BIRCH_FILL_M = (0.32, 0.6)  # longest plain stretch between two rings (lod0 / lod1)


def _birch_marks(z0, z1, crown_bottom, seed):
    """Marks of a birch trunk: [(z_a, z_b, first segment, segments, colour key)] from z0 up to z1."""
    rng = random.Random(seed * 131 + 17)
    marks = []
    z = z0 + rng.uniform(0.08, 0.16)
    while z < z1 - 0.12:
        foot = z < BIRCH_FOOT_M
        crown = z > crown_bottom + 0.6
        h = rng.uniform(0.05, 0.085) * (1.35 if foot else 1.0)
        m = rng.choice((2, 2, 3, 3, 4) if foot else (1, 1, 2, 2, 3))
        dark = "grey" if rng.random() < 0.18 else "mark"
        marks.append((z, z + h, rng.randrange(BIRCH_SEGS), m, dark))
        gap = rng.uniform(0.16, 0.36)
        z += h + gap * (0.65 if foot else (1.9 if crown else 1.0))
    return marks


def _birch_trunk(soup, sp, crown_bottom, z_cut=None, seed=0):
    """The generator's birch trunk again as a tube (its axis and radius from the centroids of height slices of the
    generator's tube) with the bands of the bark: (pos (T, 3, 3), nor, colours (T, 3, 3) sRGB 0..255)."""
    p = soup.pos.reshape(-1, 3)
    z0, z1 = float(p[:, 2].min()), float(p[:, 2].max())
    lod1 = z_cut is not None
    marks = _birch_marks(z0, z1, crown_bottom, seed)
    if lod1:
        z1 = min(z1, z_cut)
        # the larger marks only, twice as tall (the same middle), half as dark
        marks = [(0.5 * (a + b) - (b - a), 0.5 * (a + b) + (b - a), k, m, c) for (a, b, k, m, c) in marks
                 if (m >= 2 or a < BIRCH_FOOT_M) and b < z1 - 0.05]
    else:
        marks = [mk for mk in marks if mk[1] < z1 - 0.05]
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
    # ring heights: both edges of every band, plain rings in between (never more than BIRCH_FILL_M apart)
    zs = {round(z0, 4), round(z1, 4)}
    for (a, b, _k, _m, _c) in marks:
        zs.add(round(max(z0, a), 4))
        zs.add(round(min(z1, b), 4))
    zs = sorted(zs)
    fill = BIRCH_FILL_M[1 if lod1 else 0]
    # plain fill rings, evenly between two band edges
    rings = [zs[0]]
    for z in zs[1:]:
        lo = rings[-1]
        k = max(1, int(math.ceil((z - lo) / fill - 1e-6)))
        for j in range(1, k):
            rings.append(lo + (z - lo) * j / k)
        rings.append(z)
    rings = np.array(rings)
    dense = np.stack([np.interp(rings, path[:, 2], path[:, k]) for k in range(3)], axis=1)
    dense[:, 2] = rings
    rad = np.interp(rings, path[:, 2], radii)
    pos, nor = _tube(list(dense), list(rad), BIRCH_SEGS)
    # colours: per corner the white bark (a little grey variation per quad, the dark foot as a smooth gradient of
    # the height), per quad of a band the mark
    white = np.array(core.srgb8(core.hex_to_lin(BIRCH_WHITE)), dtype=np.float64)
    tones = {"mark": np.array(core.srgb8(core.hex_to_lin(BIRCH_MARK)), dtype=np.float64),
             "grey": np.array(core.srgb8(core.hex_to_lin(BIRCH_GREY)), dtype=np.float64)}
    n_side = (len(rings) - 1) * BIRCH_SEGS * 2
    t_idx = np.arange(pos.shape[0])
    ring_of = np.minimum(t_idx // (2 * BIRCH_SEGS), len(rings) - 2)
    seg_of = (t_idx // 2) % BIRCH_SEGS
    vary = ((np.sin(ring_of * 12.9898 + seg_of * 78.233) * 43758.5453) % 1.0) * 0.05
    z = pos[..., 2]
    foot = np.clip(1.0 - z / 1.1, 0.0, 1.0) ** 1.5
    col = white[None, None, :] * (1.0 - vary[:, None, None])
    col = col * (1.0 - foot[..., None] * 0.75) + tones["mark"][None, None, :] * (foot[..., None] * 0.75)
    side = t_idx < n_side
    lo_r, hi_r = rings[:-1], rings[1:]
    for (a, b, k0, m, c) in marks:
        # every ring interval inside the band (overlapping bands of lod1 share their intervals)
        inside = np.nonzero((lo_r >= round(max(z0, a), 4) - 1e-4) & (hi_r <= round(min(z1, b), 4) + 1e-4))[0]
        if inside.size == 0:
            continue
        segs = [(k0 + j) % BIRCH_SEGS for j in range(m)]
        sel = side & np.isin(ring_of, inside) & np.isin(seg_of, segs)
        tone = tones[c] if not lod1 else 0.5 * (tones[c] + white)
        col[sel] = tone[None, :]
    return pos, nor, col


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


# --- core -----------------------------------------------------------------------------------------------------

def _core_uv(pos, rect, metres=2.4):
    """UVs of the core: every triangle is projected flat (true lengths, no stretching) into the opaque core cell
    of the atlas, `metres` across the cell, around a shifted middle per triangle."""
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


def _core_mesh(mb, hp, hn, bc, br, bz, rect, z0, top_z, bright, metres=2.4, amp_k=1.0):
    """The leaf-mass core in the class leaves: occlusion per corner like the cards, no flutter."""
    ao = _occlusion(hp.reshape(-1, 3), hn.reshape(-1, 3), bc, br, bz, rays=12)
    col = np.empty(hp.shape[:2] + (4,), dtype=np.float64)
    col[..., 0] = np.clip((hp[..., 2] - z0) / max(0.5, top_z - z0), 0.0, 1.0) * amp_k
    col[..., 1] = 0.0
    col[..., 2] = 1.0
    col[..., 3] = (bright * (0.62 + 0.38 * ao)).reshape(hp.shape[:2])
    mb.add("leaves", hp, hn, np.clip(np.round(col * 255.0), 0, 255).astype(np.uint8), _core_uv(hp, rect, metres))


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


def _leaf_atlas(sp, size=1024, grid=(4, 4)):
    a = dict(sp["atlas"], fringe=sp["fringe"])
    return leafatlas.atlas(leafatlas.species_atlas(a), size=size, grid=grid, seed=sp["atlas_seed"], cells="ball")


def build_tree(model_id, spec3d):
    t0 = time.time()
    sp = _spec(spec3d["species"])
    if sp.get("shape"):
        from . import veg3d_shapes as SH          # spruce, cypress, palm (AS3): crowns that are not blob sets
        return SH.build(model_id, spec3d, sp, t0)
    sspec, info, wood_soups, crown_pts, blobs = _source(spec3d)
    return _blob_tree(model_id, spec3d, sp, sspec, info, wood_soups, crown_pts, blobs, t0)


def _blob_tree(model_id, spec3d, sp, sspec, info, wood_soups, crown_pts, blobs, t0):
    wood_pts = np.concatenate([s.pos.reshape(-1, 3) for s in wood_soups])
    ref = np.concatenate([crown_pts, wood_pts])
    ref_lo, ref_hi = ref.min(axis=0), ref.max(axis=0)
    bc, br, bz = _blob_arrays(blobs)
    centre = bc.mean(axis=0)
    crown_bottom = float(crown_pts[:, 2].min())
    top_z = float(ref_hi[2])
    ext = np.maximum(np.max(np.abs(bc - centre), axis=0) + float(br.mean()), 0.3)
    seed = int(spec3d.get("params", {}).get("seed", 0)) + sp["atlas_seed"]
    atlas_img, rects = _leaf_atlas(sp)
    lab, ccen = _kmeans(bc, sp["clumps"], seed)
    z_sway0 = top_z * sp["sway0"]
    # wood and core of every level first: the domes get what is left of the triangle budget
    woods, cores = [], []
    for li in range(2):
        if li == 0:
            wood = _tree_wood(wood_soups, bc, br, bz, crown_bottom, sp, seed=seed, centre=centre)
            lp, ln = _limbs(ccen, wood_pts, sp["limb_r"][0], sp["limb_r"][1], 6)
        else:
            # the trunk up to the crown (and coarse limbs where the crown lets them show)
            wood = _tree_wood(wood_soups, bc, br, bz, crown_bottom, sp, crown_bottom + 1.0, seed=seed, centre=centre)
            if sp["limbs1"]:
                lp, ln = _limbs(ccen, wood_pts, sp["limb_r"][0], sp["limb_r"][1], 4)
            else:
                lp, ln = np.zeros((0, 3, 3)), np.zeros((0, 3, 3))
        if lp.shape[0]:
            # limb parts outside the crown are dropped like the generator's branches (dark sticks on a flat crown)
            cen = lp.mean(axis=1)
            keep = (cen[:, 2] < crown_bottom + 0.5) | (_inside_crown(cen, bc, br, bz, WOOD_HULL)
                                                       & _inside_mass(cen, bc, br, bz, centre, sp["core"]["axis"]))
            if keep.any():
                wood.append(("limb", lp[keep], ln[keep]))
        woods.append(wood)
        cs = sp["core"]
        cores.append(_star_hull(bc, br, bz, centre, cs["shrink"], cs["subdiv"][li], cs["axis"], z_min=crown_bottom + 0.3)
                     if cs and cs["subdiv"][li] >= 0 else None)
    exp = _exposed(bc, br, bz, sp["samples"], sp.get("z_floor"))
    frames = _dome_frames(exp, bc, br, bz, centre, sp, sp["caps"][0])
    budgets = [sp["tris"][li] - sum(item[1].shape[0] for item in woods[li])
               - (cores[li][0].shape[0] if cores[li] is not None else 0) for li in range(2)]
    plans = _level_plans(exp, frames, bc, br, bz, budgets, sp)
    card_sets = {}
    for li, name in enumerate(("lod0", "lod1")):
        card_sets[name] = _dome_cards(frames, plans[li], bc, br, bz, centre, ext, rects["leaf"], seed, sp)
        # the coarser level may show more of its darker corners: lifted to the mean of lod0 at the switch distance
        # (measured with tools/models/prop_scene.sh --mode=lods --look=race)
        card_sets[name]["col"][:, 3] = np.clip(card_sets[name]["col"][:, 3] * sp["lift"][li], 0.0, 1.0)
    fit = _Fit(card_sets["lod0"]["eff"], wood_pts, ref_lo, ref_hi, centre)
    meshes = {}
    n_cards = {}
    for li, name in enumerate(("lod0", "lod1")):
        cards = card_sets[name]
        cards["pos"] = fit(cards["pos"])
        cards["eff"] = fit(cards["eff"])
        n_cards[name] = int(cards["domes"])
        mb = core.MeshBuilder()
        _add_wood(mb, sp, woods[li], top_z, bc, br, bz)
        pos, nor, uv, c8 = _dome_arrays(cards, z_sway0, top_z)
        mb.add("leaves", pos, nor, c8, uv)
        if cores[li] is not None:
            hp, hn = cores[li]
            _core_mesh(mb, fit(hp), hn, bc, br, bz, rects["core"], z_sway0, top_z, sp["core"]["bright"])
        meshes[name] = mb
    # shadow caster: leaf-mass hull + trunk (leaves.gdshader takes the sun's shadow only in part, so the cards in
    # front of this hull are not darkened by it)
    sh = core.MeshBuilder()
    core_c = np.append(core.srgb8(core.hex_to_lin("#24401a")), 255).astype(np.uint8)
    for item in _tree_wood(wood_soups, bc, br, bz, crown_bottom, dict(sp, birch=False), crown_bottom + 1.0, seed=seed,
                           centre=centre):
        p, n = _wind(item[1], item[2])
        sh.add("vpbr", p, n, core_c, (0.92, 0.0), roles.NO_LAMP)
    hp, hn = _star_hull(bc, br, bz, centre, sp["shadow"]["shrink"], sp["shadow"]["subdiv"], sp["core"]["axis"],
                        z_min=crown_bottom)
    sh.add("vpbr", fit(hp), hn, core_c, (0.92, 0.0), roles.NO_LAMP)
    return _finish_tree(model_id, spec3d, sp, sspec, info, meshes, sh, card_sets, n_cards, wood_pts, atlas_img,
                        ref_lo, ref_hi, t0, dict(blobs=len(blobs), clumps=int(ccen.shape[0])))


def _leaf_texture(model, spec3d, atlas_img):
    """The leaf atlas of a model. A seed variant ("variant_of") draws with the atlas of its species' model - the
    same picture (same species parameters, same atlas seed) - instead of a copy of its own (AS3R, art review M9:
    15.8 MB of the texture budget were byte-identical copies; one texture and one material per species in the
    race): its manifest entry names the file in the species' folder and carries "variant_of"
    (validate_models.py accepts a texture there for exactly that model)."""
    base = spec3d.get("variant_of")
    if base:
        model.textures["leaves"] = base + "/leaves.png"
        model.extra["variant_of"] = base
    else:
        model.textures["leaves"] = "leaves.png"
        model.texture_files["leaves.png"] = leafatlas.png_bytes(atlas_img)


def _finish_tree(model_id, spec3d, sp, sspec, info, meshes, sh, card_sets, n_cards, wood_pts, atlas_img, ref_lo,
                 ref_hi, t0, stats):
    """Model data of a card tree (all species): levels, caster, textures, impostor, extent."""
    if n_cards["lod0"] > CARDS_MAX:
        raise RuntimeError("%s: %d cards (budget %d)" % (model_id, n_cards["lod0"], CARDS_MAX))
    model = ModelData(model_id, "tree", dict(info.get("object") or {}))
    eff = card_sets["lod0"]["eff"]
    model.extent_m = sprite_extent(np.concatenate([eff, wood_pts]), sspec["camera"].get("view_yaw", 0.0))
    model.tags = list(sspec.get("tags", []))
    model.lods = [Lod("lod0", LOD.PROP_LOD_DIST["lod0"], [Part("body", "lod0_body", meshes["lod0"].finish())]),
                  Lod("lod1", LOD.PROP_LOD_DIST["lod1"], [Part("body", "lod1_body", meshes["lod1"].finish())])]
    model.shadow = Part("body", "shadow", sh.finish())
    _leaf_texture(model, spec3d, atlas_img)
    model.extra["cards"] = n_cards
    model.sets = _sets_of(model_id, spec3d)
    t1 = time.time()
    png, size_m, anchor_x = render_impostor(meshes["lod0"], atlas_img, ref_lo, ref_hi, sp["imp"],
                                            px=int(sp["imp"].get("px", IMPOSTOR_PX)))
    model.texture_files["impostor.png"] = png
    model.impostor = {"texture": "impostor.png", "size_m": size_m, "anchor_x": anchor_x}
    model.stats = dict(build_s=round(t1 - t0, 2), impostor_s=round(time.time() - t1, 2), cards=n_cards,
                       tris={n: meshes[n].triangles() for n in meshes}, **stats,
                       coverage=leafatlas.coverage(atlas_img.crop((0, 0, 256, 256))))
    return model


# --- bushes, heather and ground cover -----------------------------------------------------------------------------

def _bush_mesh(frames, plan, bc, br, bz, centre, ext, top_z, rects, sp, li, seed, ref, z_sway0, fit=None,
               blob_rects=None):
    cards = _dome_cards(frames, plan, bc, br, bz, centre, ext, rects["leaf"], seed, sp, blob_rects)
    cards["col"][:, 3] = np.clip(cards["col"][:, 3] * sp["lift"][li], 0.0, 1.0)
    if fit is None:
        fit = _Fit(cards["eff"], np.zeros((0, 3)), ref[0], ref[1], centre)
    cards["pos"] = fit(cards["pos"])
    cards["eff"] = fit(cards["eff"])
    mb = core.MeshBuilder()
    # bushes sway little: amplitude scaled down (leaves.gdshader: sway_m x amp^2)
    pos, nor, uv, c8 = _dome_arrays(cards, z_sway0, top_z, sp["sway"])
    mb.add("leaves", pos, nor, c8, uv)
    if sp["core_subdiv"][li] >= 0:
        # a small core: a bush may show the ground through its rim, not through its middle; its foot reaches below
        # the ground (AS3R, art review M7: on a slope the downhill side showed a gap under the bush)
        hp, hn = _bush_core(bc, br, bz, centre, sp, li)
        _core_mesh(mb, fit(hp), hn, bc, br, bz, rects["core"], z_sway0, top_z, sp["core_bright"], metres=1.2,
                   amp_k=sp["sway"])
    return mb, int(cards["domes"]), cards["eff"], fit


def _bush_core(bc, br, bz, centre, sp, li):
    """Core of a bush or heather: the star hull of its blobs, its lower part drawn down into the ground as a skirt
    (vertices below SKIRT_TOP_M go down by up to SKIRT_M, a little wider)."""
    hp, hn = _star_hull(bc, br, bz, centre, sp["core_shrink"], sp["core_subdiv"][li], 0.0)
    z = hp[..., 2]
    low = z < SKIRT_TOP_M
    k = np.where(low, 1.0 - np.clip(z, 0.0, None) / SKIRT_TOP_M, 0.0)
    hp = hp.copy()
    hp[..., 2] = z - (SKIRT_M + np.clip(z, 0.0, None)) * k
    for ax in (0, 1):
        hp[..., ax] = centre[ax] + (hp[..., ax] - centre[ax]) * (1.0 + 0.08 * k)
    return hp, hn


SKIRT_TOP_M = 0.18       # bushes and heather: the core's skirt starts this high ...
SKIRT_M = 0.4            # ... and reaches this far below the ground (contract: base below 0 - on a slope no gap)
BUSH_DEFAULTS = dict(sway=0.45, core_shrink=0.8, core_bright=0.78, core_subdiv=(0, 0), tris=(396, 118),
                     caps=((48.0, 118.0), (48.0, 118.0)), lift=(1.0, 1.05), vis_w=0.5,
                     levels=(((1, 6, 12), (1, 6, 12, 12)), ((1, 6), (1, 4, 8))),
                     crown_w=0.3, up_w=0.1, ao=(0.45, 1.0, 0.9), stiff=0.6, samples=40, out=0.03, z_floor=0.02)


def _bush_spec(name):
    sp = dict(DEFAULTS)
    sp.update(BUSH_DEFAULTS)
    sp.update(BUSHES[name])
    if isinstance(sp["core_subdiv"], int):
        sp["core_subdiv"] = (sp["core_subdiv"], -1)
    return sp


def build_bush(model_id, spec3d):
    """Bushes (props/bush_round, bush_low), heather and the ground cover clump (props/cover_bush): leaves only."""
    t0 = time.time()
    name = spec3d["bush"]
    sp = _bush_spec(name)
    seed = int(spec3d.get("params", {}).get("seed", 0)) + sp["atlas_seed"]
    if spec3d.get("cover"):
        from cesprites import props_nature as N
        c = spec3d["cover"]
        blobs, ref = _crown_blobs(N.crown, (c["centre"], c["a"], c["b"], c["c"], c["n"], c["r0"], c["r1"]), seed)
        sspec = None
        info = {"object": dict(spec3d["object"])}
    elif name == "heather":
        sspec, info, _wood, ref, _blobs, shape = _source(spec3d, shapes=True)
        blobs = [(c, r, zs) for (c, r, zs, _k) in shape["heather"]]
        kinds = [k for (_c, _r, _zs, k) in shape["heather"]]
    else:
        sspec, info, _wood, ref, blobs = _source(spec3d)
    bc, br, bz = _blob_arrays(blobs)
    if sp.get("merge") and bc.shape[0] > sp["merge"]:
        bc, br, bz = _merge_blobs(bc, br, bz, int(sp["merge"]))
    # the generator sets the lowest blobs of a bush partly into the ground: the foot is already below it (slopes)
    centre = bc.mean(axis=0)
    ext = np.maximum(np.max(np.abs(bc - centre), axis=0) + float(br.mean()), 0.1)
    ref_lo, ref_hi = ref.min(axis=0), ref.max(axis=0)
    if spec3d.get("cover"):
        # ground cover: the box of its object size (never above the 0.5 m of A-3)
        o = spec3d["object"]
        ref_lo = np.array([-o["width_m"] * 0.5, -o.get("length_m", o["width_m"]) * 0.5, 0.0])
        ref_hi = np.array([o["width_m"] * 0.5, o.get("length_m", o["width_m"]) * 0.5, o["height_m"]])
    top_z = float(ref_hi[2])
    blob_rects = None
    if name == "heather":
        fl = leafatlas.species_atlas(dict(sp["flowers"], fringe=sp["fringe"]))
        gr = leafatlas.species_atlas(dict(sp["atlas"], fringe=sp["fringe"]))
        atlas_img, rects = leafatlas.mixed_atlas([(fl, 2), (gr, 1)], size=512, grid=(2, 2), seed=sp["atlas_seed"])
        blob_rects = [rects["groups"][0] if k == "pink" else rects["groups"][1] for k in kinds]
    else:
        atlas_img, rects = _leaf_atlas(sp, size=512, grid=(2, 2))
    meshes, n_cards = {}, {}
    eff0 = None
    fit = None
    exp = _exposed(bc, br, bz, sp["samples"], sp.get("z_floor"))
    frames = _dome_frames(exp, bc, br, bz, centre, sp, sp["caps"][0])
    budgets = [sp["tris"][li] - (20 * 4 ** sp["core_subdiv"][li] if sp["core_subdiv"][li] >= 0 else 0)
               for li in range(2)]
    plans = _level_plans(exp, frames, bc, br, bz, budgets, sp)
    for li, ln in enumerate(("lod0", "lod1")):
        mb, nc, eff, fit = _bush_mesh(frames, plans[li], bc, br, bz, centre, ext, top_z, rects, sp, li, seed,
                                      (ref_lo, ref_hi), 0.0, fit, blob_rects)
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
    _leaf_texture(model, spec3d, atlas_img)
    model.extra["cards"] = n_cards
    model.sets = _sets_of(model_id, spec3d)
    model.tags = _ground_tags(model.tags, "ground_align")
    model.stats = dict(build_s=round(time.time() - t0, 2), blobs=len(blobs), domes=int(bc.shape[0]), cards=n_cards,
                       tris={n: meshes[n].triangles() for n in meshes})
    return model


def _ground_tags(tags, how):
    """Tags of a model plus how it wants to stand on a slope (AS3R, art review M7; for the props builder, R2/R7):
    "ground_align" - a flat, wide plant (heather, bushes, ground cover): turned to the ground's normal like its
    contact shadow; "ground_sink" - a rock: set on the lowest ground point under its footprint. Until the props builder
    reads them, the models reach below the ground themselves (cores with a skirt, rock feet sunk)."""
    out = list(tags)
    if how not in out:
        out.append(how)
    return out


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
                # the blades start GRASS_SINK_M below the ground (AS3R, art review M7: on a slope no gap below them)
                q = np.array([[cx - dx, cy - dy, -GRASS_SINK_M], [cx + dx, cy + dy, -GRASS_SINK_M],
                              [cx + dx, cy + dy, hh], [cx - dx, cy - dy, hh]])
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
    model.tags = ["prop", "plant", "ground_cover", "ground_align"]
    model.lods = [Lod("lod0", LOD.PROP_LOD_DIST["lod0"], [Part("body", "lod0_body", meshes["lod0"].finish())]),
                  Lod("lod1", LOD.PROP_LOD_DIST["lod1"], [Part("body", "lod1_body", meshes["lod1"].finish())])]
    model.textures["leaves"] = "leaves.png"
    model.texture_files["leaves.png"] = leafatlas.png_bytes(atlas_img)
    model.extra["cards"] = n_cards
    model.sets = _sets_of(model_id, spec3d)
    model.stats = dict(build_s=round(time.time() - t0, 2), cards=n_cards, tris={n: meshes[n].triangles() for n in meshes})
    return model


# --- impostor ------------------------------------------------------------------------------------------------

IMPOSTOR_WRAP = 0.35     # leaves.gdshader wrap: the relief of the impostor is lit like the leaves
IMPOSTOR_SKY = 0.4       # share of the relief that comes from the sky above (the rest from the sprite's sun)
IMPOSTOR_HALO = 0.32     # alpha of the texels next to the picture (billboard scissor 0.5, BC3 margin): thin trunks
                         # and fronds keep their width in the coarser mipmaps (art review: olive trunk too thin far off)


def _relief(nor, sun):
    """Relief light of a normal (AS3R, impostor): sky from above + the sprite rig's sun with the leaves' wrap."""
    sky = 0.5 + 0.5 * nor[..., 2]
    s = np.clip(((nor * sun).sum(axis=-1) + IMPOSTOR_WRAP) / (1.0 + IMPOSTOR_WRAP), 0.0, None)
    return IMPOSTOR_SKY * sky + (1.0 - IMPOSTOR_SKY) * s


def _lit_blend(rig, flat, tmp, lit, samples):
    """The impostor once more under the sprite rig's light (sky + sun with its shadows, Cycles; AS3R, art review M5:
    the spruce's tiers only show through the shadow each tier casts on the one below), normalised to the mean of the
    plain picture `flat` and blended into it by `lit` (0..1): the shadows come in, the mean (the gain measured
    against lod1) stays. Every emission of the impostor materials becomes a diffuse surface of the same colour."""
    import bpy
    from PIL import Image
    for mat in bpy.data.materials:
        if not mat.name.startswith("imp_") or mat.node_tree is None:
            continue
        nt = mat.node_tree
        for em in [n for n in nt.nodes if n.type == "EMISSION"]:
            dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
            if em.inputs["Color"].links:
                nt.links.new(em.inputs["Color"].links[0].from_socket, dif.inputs["Color"])
            else:
                dif.inputs["Color"].default_value = em.inputs["Color"].default_value
            for link in list(em.outputs[0].links):
                nt.links.new(dif.outputs[0], link.to_socket)
    sc = rig.scene
    sc.world = rig.world_sky
    rig.sun.hide_render = False
    sc.cycles.samples = max(samples, 32)
    sc.cycles.max_bounces = 2
    sc.cycles.diffuse_bounces = 1
    path = os.path.join(tmp, "impostor_lit.png")
    rig.render(path)
    a = np.array(flat).astype(np.float64)
    b = np.array(Image.open(path).convert("RGBA")).astype(np.float64)
    m = a[:, :, 3] >= 128
    w = np.array([0.2126, 0.7152, 0.0722])
    k = float((a[m][:, :3] @ w).mean()) / max(1e-3, float((b[m][:, :3] @ w).mean()))
    out = a.copy()
    out[:, :, :3] = np.clip(a[:, :, :3] * (1.0 - lit) + b[:, :, :3] * k * lit, 0.0, 255.0)
    return Image.fromarray(np.round(out).astype(np.uint8), "RGBA")


def render_impostor(mb, atlas_img, ref_lo, ref_hi, imp=None, px=IMPOSTOR_PX, samples=16):
    """Picture of the card tree seen from the road (orthographic): the albedo of leaves and wood with the corner
    brightness and a soft sky shading (a part `sky` of the light comes regardless of the normal, the rest grows
    with the normal's height), no directional light - billboard.gdshader lights it with ambient + sun of the
    moment. imp: {"gain", "tint", "sky", "relief", "sat"}.
    AS3R (art review M5: the far level lost 30-80 % of lod1's contrast - billboard.gdshader gives the whole picture
    one sun factor, and the picture had no light and shade of its own): a share `relief` of the brightness is the
    light of the sprite rig (cesprites/rig.py SUN_DIR, the light the Arcade sprites carry) on the leaves' normals,
    wrapped like leaves.gdshader, normalised to a mean of 1 over the corners facing the road - the sun side and the
    creases of the crown come back, the mean (the gains measured against lod1) stays. `sat` raises the saturation
    about the luma (the picture averages leaves with the darker core). The alpha gets a halo (IMPOSTOR_HALO).
    Returns (PNG bytes RGBA, [width_m, height_m], anchor_x)."""
    import bpy
    from cesprites import materials as M
    from cesprites import rig as R
    imp = dict(DEFAULTS["imp"], **(imp or {}))
    gain = float(imp["gain"])
    sky = float(imp["sky"])
    relief = float(imp.get("relief", 0.0))
    sat = float(imp.get("sat", 1.0))
    sun = np.array(R.SUN_DIR[:], dtype=np.float64)
    # mean relief over the corners facing the road (the camera looks along +y)
    nn = []
    for cls in ("leaves", "vpbr"):
        for c in mb.chunks.get(cls, []):
            nn.append(c[1].reshape(-1, 3))
    nn = np.concatenate(nn) if nn else np.zeros((1, 3))
    front = nn[:, 1] < 0.25
    r_mean = float(_relief(nn[front] if front.any() else nn, sun).mean())
    k_rel = relief / max(1e-3, r_mean)
    rig = R.Rig(quick=False)
    tmp = tempfile.mkdtemp(prefix="ce_imp_")
    atlas_path = os.path.join(tmp, "leaves.png")
    atlas_img.save(atlas_path)
    img = bpy.data.images.load(atlas_path)
    img.alpha_mode = "STRAIGHT"

    def relief_of(nb, normal):
        """(1 - relief) + relief / mean x _relief(normal) as nodes."""
        dot = nb.node("ShaderNodeVectorMath", operation="DOT_PRODUCT")
        nb.links.new(normal, dot.inputs[0])
        dot.inputs[1].default_value = tuple(float(v) for v in sun)
        s = nb.math("MAXIMUM", nb.math("MULTIPLY_ADD", dot.outputs["Value"], 1.0 / (1.0 + IMPOSTOR_WRAP),
                                       IMPOSTOR_WRAP / (1.0 + IMPOSTOR_WRAP)), 0.0)
        sep = nb.node("ShaderNodeSeparateXYZ")
        nb.links.new(normal, sep.inputs[0])
        skyp = nb.math("MULTIPLY_ADD", sep.outputs[2], 0.5 * IMPOSTOR_SKY, 0.5 * IMPOSTOR_SKY)
        r = nb.math("MULTIPLY_ADD", s, 1.0 - IMPOSTOR_SKY, skyp)
        return nb.math("MULTIPLY_ADD", r, k_rel, 1.0 - relief)

    def emission_mat(name, textured):
        m, nb = M.new_material(name)
        att = nb.node("ShaderNodeAttribute")
        att.attribute_name = "ce_col"
        geo = nb.node("ShaderNodeNewGeometry")
        sep = nb.node("ShaderNodeSeparateXYZ")
        nb.links.new(geo.outputs["Normal"], sep.inputs[0])
        # sky shading: sky + (1 - sky) * (0.5 + 0.5 n.z), its mean over a sphere is 1 (times the gain)
        k_up = (1.0 - sky) * 0.5
        shade = nb.math("MULTIPLY_ADD", sep.outputs[2], k_up * gain, (sky + k_up) * gain)
        if relief > 0.0:
            # the model's own shading normal (attribute ce_nrm): Cycles turns the normal of a face seen from its
            # back towards the camera - a card seen from behind would get the light of its other side
            att_n = nb.node("ShaderNodeAttribute")
            att_n.attribute_name = "ce_nrm"
            shade = nb.mul(shade, relief_of(nb, att_n.outputs["Vector"]))
        em = nb.node("ShaderNodeEmission")
        if textured:
            tex = nb.node("ShaderNodeTexImage")
            tex.image = img
            k = nb.mul(shade, nb.math("POWER", att.outputs["Alpha"], 2.2))  # card brightness (sRGB factor)
            tint = nb.node("ShaderNodeVectorMath", operation="MULTIPLY")
            nb.links.new(nb.color_scale(tex.outputs["Color"], k), tint.inputs[0])
            tint.inputs[1].default_value = tuple(imp["tint"])
            col_out = tint.outputs[0]
            if abs(sat - 1.0) > 1e-3:
                hs = nb.node("ShaderNodeHueSaturation")
                hs.inputs["Saturation"].default_value = sat
                nb.links.new(col_out, hs.inputs["Color"])
                col_out = hs.outputs["Color"]
            nb.links.new(col_out, em.inputs["Color"])
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
        nrm4 = np.concatenate([nor.reshape(-1, 3), np.ones((nor.reshape(-1, 3).shape[0], 1))], axis=1)
        na = me.color_attributes.new("ce_nrm", "FLOAT_COLOR", "CORNER")
        na.data.foreach_set("color", nrm4.reshape(-1).astype(np.float32))
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
    im = Image.open(path).convert("RGBA")
    lit = float(imp.get("lit", 0.0))
    if lit > 0.0:
        im = _lit_blend(rig, im, tmp, lit, samples)
    if imp.get("halo", True):
        im = leafatlas.halo(im, alpha=IMPOSTOR_HALO, px=2, scissor=0.5)
    im = leafatlas.bleed(im, steps=8)
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)
    return buf.getvalue(), [round(width_m, 3), round(height_m, 3)], round(anchor_x, 4)
