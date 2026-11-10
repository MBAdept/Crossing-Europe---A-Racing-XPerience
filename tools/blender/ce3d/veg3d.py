"""Card trees for the mode "Modern" (contract D22): trunk and branches of the sprite generator, a low-poly
solid core, alpha-scissor leaf cards on the crown blobs of the sprite model (same seed -> same
silhouette), a low-poly shadow caster and an impostor rendered from the card tree.

  lod0     wood + core (vpbr) and all cards (leaves)           <= 2,500 triangles, <= 450 cards, 2 draw calls
  lod1     trunk up to the crown + core, fewer and larger cards <= 900 triangles, 2 draw calls
  shadow   hull of the crown + trunk (vpbr)                      the cheap caster for "Schatten: Mittel"
  impostor picture of lod0 (albedo with soft shading, lit by billboard.gdshader), the level beyond lod1

Leaf card vertex data (class "leaves"): UV = cluster of the leaf atlas, COLOR = (sway amplitude by height,
phase per card, stiffness, brightness), NORMAL = outwards from the crown.
The cards are fitted to the silhouette of the sprite crown (left / right / depth / top), so the model's
extent equals the sprite's.
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

SPECIES = {
    "oak": dict(leaf="lobed", colors=("#3d6b25", "#5c8a30", "#4a7a2a", "#6c9a38"), bark="#3d3125", core="#24401a",
                cards=(6, 2), card_size=((2.3, 3.1), (3.6, 4.8)), leaves=84, seed=77),
}
OPAQUE = 0.82            # part of a card (from its centre) that counts as silhouette
IMPOSTOR_PX = 256
# The impostor picture is the albedo of the tree times this gain (linear): measured against lod1 in the
# contact sheet with the ambient light alone. billboard.gdshader then lights the picture with the renderer's
# own arithmetic, the cards' share of the sun as sun_min .. sun_max (measured for the sun in front, beside
# and behind the tree, by day and by moonlight).
IMPOSTOR_GAIN = 1.19


def _source(spec3d):
    """Sprite build with the crown log on: wood soups, reference points of the sprite model, blobs."""
    import render_all as RA
    from cesprites import meshutil as MU
    from cesprites import props_nature as N
    from cesprites import rig as R
    from .props3d import _sprite_spec
    sspec = _sprite_spec(spec3d["source"])
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


def _wood(soups, bark_hex, z_cut=None):
    """Wood as vpbr corner arrays; z_cut drops triangles above that height (inside the crown)."""
    tr = roles.Translator(overrides={"proc:*": dict(role="flat", color=bark_hex, rough=0.9, metal=0.0),
                                     "flat:*": dict(role="flat", color=bark_hex, rough=0.9, metal=0.0)},
                          glass_class=False)
    mb = core.MeshBuilder()
    for s in soups:
        if z_cut is None:
            tr.add_object(mb, s)
            continue
        keep = s.pos[:, :, 2].mean(axis=1) < z_cut
        if keep.any():
            for mi in np.unique(s.mi[keep]):
                role, d = tr.describe(s.material(int(mi)))
                sel = keep & (s.mi == mi)
                tr.add_role(mb, role, d, s.pos[sel], s.nor[sel])
    return mb


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


def _hull(blobs, centre, shrink, r_part, subdiv, z_min=None):
    """Lumpy closed solid following the blob set: every icosphere direction reaches the support of the
    blobs in that direction (blob centre + r_part * radius) times shrink. Returns per-corner (pos, nor)."""
    v, f = _ico(subdiv)
    bc = np.array([b[0] for b in blobs]) - centre
    br = np.array([b[1] for b in blobs])
    sup = (v @ bc.T + br[None, :] * r_part).max(axis=1)
    p = centre + v * (np.maximum(sup, 0.3) * shrink)[:, None]
    if z_min is not None:
        p[:, 2] = np.maximum(p[:, 2], z_min)
    fn = np.cross(p[f[:, 1]] - p[f[:, 0]], p[f[:, 2]] - p[f[:, 0]])
    vn = np.zeros_like(p)
    for k in range(3):
        np.add.at(vn, f[:, k], fn)
    vn /= np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-9)
    return p[f], vn[f]


def _cards(blobs, centre, per_blob, size_range, rects, seed, top_z):
    """Leaf cards on the blobs. Returns dict(p0 (C, 3), quad (C, 4, 3), uv (C, 4, 2), col (C, 4, 4) float,
    nor (C, 3))."""
    rng = random.Random(seed)
    p0s, quads, uvs, cols, nors = [], [], [], [], []
    r_mean = float(np.mean([b[1] for b in blobs]))
    ext = np.max(np.abs(np.array([b[0] for b in blobs]) - centre), axis=0) + r_mean
    for (bc, r, zs) in blobs:
        bc = np.array(bc)
        out = bc - centre
        out /= (np.linalg.norm(out) + 1e-6)
        for _k in range(per_blob):
            d = np.array([rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1)])
            d = d / (np.linalg.norm(d) + 1e-6) + out * 0.9
            d /= np.linalg.norm(d)
            off = d * r * rng.uniform(0.7, 1.0)
            off[2] *= zs
            p0 = bc + off
            size = rng.uniform(*size_range) * (r / r_mean) ** 0.5
            tmp = np.array([0.0, 0.0, 1.0]) if abs(d[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
            u = np.cross(tmp, d)
            u /= np.linalg.norm(u)
            v = np.cross(d, u)
            roll = rng.uniform(0, 2 * math.pi)
            u2 = u * math.cos(roll) + v * math.sin(roll)
            v2 = -u * math.sin(roll) + v * math.cos(roll)
            tilt = rng.uniform(-0.55, 0.55)
            nrm = d * math.cos(tilt) + v2 * math.sin(tilt)
            v3 = v2 * math.cos(tilt) - d * math.sin(tilt)
            h = size * 0.5
            quad = np.array([p0 - u2 * h - v3 * h, p0 + u2 * h - v3 * h, p0 + u2 * h + v3 * h, p0 - u2 * h + v3 * h])
            (ua, va, ub, vb) = rects[rng.randrange(len(rects))]
            uv = np.array([(ua, vb), (ub, vb), (ub, va), (ua, va)])
            sn = (p0 - centre) / ext
            sn = sn / (np.linalg.norm(sn) + 1e-6) * 0.7 + nrm * 0.2 + np.array([0.0, 0.0, 0.25])
            sn /= np.linalg.norm(sn)
            outer = min(1.0, float(np.linalg.norm((p0 - centre) / ext)))
            top = min(1.0, max(0.0, (p0[2] - centre[2]) / max(0.5, top_z - centre[2]) * 0.5 + 0.5))
            bright = min(1.0, max(0.5, 0.58 + 0.26 * outer + 0.16 * top + rng.uniform(-0.06, 0.06)))
            phase = rng.random()
            stiff = rng.uniform(0.3, 0.9)
            p0s.append(p0)
            quads.append(quad)
            uvs.append(uv)
            cols.append([(0.0, phase, stiff, bright)] * 4)
            nors.append(sn)
    return dict(p0=np.array(p0s), quad=np.array(quads), uv=np.array(uvs), col=np.array(cols), nor=np.array(nors))


def _fit(cards, wood_pts, ref_lo, ref_hi, centre):
    """Moves the cards so that the silhouette of wood + cards has the reference bounds: x and y are mapped
    linearly, z is scaled above the crown centre so that the top matches."""
    eff = cards["p0"][:, None, :] + (cards["quad"] - cards["p0"][:, None, :]) * OPAQUE
    pts = np.concatenate([eff.reshape(-1, 3), wood_pts])
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    q = cards["quad"]
    p = cards["p0"]
    for ax in (0, 1):
        k = (ref_hi[ax] - ref_lo[ax]) / max(1e-6, hi[ax] - lo[ax])
        q[:, :, ax] = ref_lo[ax] + (q[:, :, ax] - lo[ax]) * k
        p[:, ax] = ref_lo[ax] + (p[:, ax] - lo[ax]) * k
    kz = (ref_hi[2] - centre[2]) / max(1e-6, hi[2] - centre[2])
    up = q[:, :, 2] > centre[2]
    q[:, :, 2] = np.where(up, centre[2] + (q[:, :, 2] - centre[2]) * kz, q[:, :, 2])
    p[:, 2] = np.where(p[:, 2] > centre[2], centre[2] + (p[:, 2] - centre[2]) * kz, p[:, 2])
    return cards


def _core_uv(pos, centre, rect):
    """UVs of the core: a planar wrap into the dense middle of one leaf cluster."""
    (ua, va, ub, vb) = rect
    cu, cv = (ua + ub) * 0.5, (va + vb) * 0.5
    du, dv = (ub - ua) * 0.17, (vb - va) * 0.17
    d = pos - centre
    r = np.maximum(np.abs(d).max(), 1e-6)
    a = np.arctan2(d[..., 1], d[..., 0])
    k = np.clip(np.hypot(d[..., 0], d[..., 1]) / r, 0.0, 1.0)
    return np.stack([cu + np.cos(a * 2.0) * k * du + d[..., 2] / r * du * 0.5,
                     cv + np.sin(a * 2.0) * k * dv], axis=-1)


def _core_colors(pos, z0, top_z):
    """Leaves vertex colours of the core: sways with the crown, no flutter, darker than the cards."""
    amp = np.clip((pos[..., 2] - z0) / max(0.5, top_z - z0), 0.0, 1.0)
    col = np.empty(pos.shape[:2] + (4,), dtype=np.float64)
    col[..., 0] = amp
    col[..., 1] = 0.0
    col[..., 2] = 1.0
    col[..., 3] = 0.62
    return np.clip(np.round(col * 255.0), 0, 255).astype(np.uint8)


def _card_arrays(cards, z0, top_z):
    """Per-corner arrays of the cards: pos (2C, 3, 3), nor, uv, col uint8 (sway amplitude by height)."""
    q = cards["quad"]
    amp = np.clip((q[:, :, 2] - z0) / max(0.5, top_z - z0), 0.0, 1.0)
    col = cards["col"].copy()
    col[:, :, 0] = amp
    tri = np.array([[0, 1, 2], [0, 2, 3]])
    pos = q[:, tri, :].reshape(-1, 3, 3)
    uv = cards["uv"][:, tri, :].reshape(-1, 3, 2)
    c8 = np.clip(np.round(col[:, tri, :].reshape(-1, 3, 4) * 255.0), 0, 255).astype(np.uint8)
    nor = np.repeat(cards["nor"], 2, axis=0)[:, None, :].repeat(3, axis=1)
    return pos, nor, uv, c8


def build_tree(model_id, spec3d):
    t0 = time.time()
    sp = SPECIES[spec3d["species"]]
    sspec, info, wood_soups, crown_pts, blobs = _source(spec3d)
    wood_pts = np.concatenate([s.pos.reshape(-1, 3) for s in wood_soups])
    ref = np.concatenate([crown_pts, wood_pts])
    ref_lo, ref_hi = ref.min(axis=0), ref.max(axis=0)
    centre = np.array([b[0] for b in blobs]).mean(axis=0)
    crown_bottom = float(crown_pts[:, 2].min())
    top_z = float(ref_hi[2])
    atlas_img, rects = leafatlas.atlas(sp["leaf"], sp["colors"], n_leaves=sp["leaves"], seed=sp["seed"])
    core_c = np.append(core.srgb8(core.hex_to_lin(sp["core"])), 255).astype(np.uint8)
    meshes = {}
    n_cards = {}
    card_sets = {}
    for li, name in enumerate(("lod0", "lod1")):
        cards = _cards(blobs, centre, sp["cards"][li], sp["card_size"][li], rects, sp["seed"] + li, top_z)
        cards = _fit(cards, wood_pts, ref_lo, ref_hi, centre)
        card_sets[name] = cards
        n_cards[name] = int(cards["quad"].shape[0])
        mb = _wood(wood_soups, sp["bark"], None if li == 0 else crown_bottom + 1.0)
        pos, nor, uv, c8 = _card_arrays(cards, top_z * 0.3, top_z)
        mb.add("leaves", pos, nor, c8, uv)
        # solid core in the leaves class: the dense middle of a leaf cluster, darker than the cards
        hp, hn = _hull(blobs, centre, 0.72, 0.55, 2, z_min=crown_bottom + 0.4)
        mb.add("leaves", hp, hn, _core_colors(hp, top_z * 0.3, top_z), _core_uv(hp, centre, rects[0]))
        meshes[name] = mb
    # shadow caster: crown hull + trunk (leaves.gdshader takes the sun's shadow only in part, so the cards
    # in front of this hull are not darkened by it)
    sh = _wood(wood_soups, sp["bark"], crown_bottom + 1.0)
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
    for sid in (spec3d.get("sets") or [model_id]):
        model.sets[sid] = {"model": model_id}
    t1 = time.time()
    png, size_m, anchor_x = render_impostor(meshes["lod0"], atlas_img, sp, ref_lo, ref_hi)
    model.texture_files["impostor.png"] = png
    model.impostor = {"texture": "impostor.png", "size_m": size_m, "anchor_x": anchor_x}
    model.stats = dict(build_s=round(t1 - t0, 2), impostor_s=round(time.time() - t1, 2), blobs=len(blobs),
                       cards=n_cards)
    return model


def render_impostor(mb, atlas_img, sp, ref_lo, ref_hi, px=IMPOSTOR_PX, samples=16):
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
            nb.links.new(nb.color_scale(tex.outputs["Color"], k), em.inputs["Color"])
            tr = nb.node("ShaderNodeBsdfTransparent")
            mix = nb.node("ShaderNodeMixShader")
            nb.links.new(nb.gt(tex.outputs["Alpha"], 0.42), mix.inputs[0])
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
