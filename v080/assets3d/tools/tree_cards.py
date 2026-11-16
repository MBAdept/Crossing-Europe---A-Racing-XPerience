#!/usr/bin/env python3
"""Vegetation prototype: oak with trunk/branches from the real generator, a low-poly solid core and
alpha-tested leaf cards placed on the crown blobs of the sprite model (same seed -> same silhouette).
Usage: bpy-python tree_cards.py OUT_DIR"""
import io
import math
import os
import random
import sys

REPO = "/home/user/crossing-europe---a-racing-xperience"
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

from ce3d import core  # noqa: E402
from ce3d.glb import Glb  # noqa: E402
from cesprites import meshutil as MU  # noqa: E402
from cesprites import props_nature as N  # noqa: E402
from cesprites import rig as R  # noqa: E402


def leaf_texture(size=256, n=46, seed=3, cols=("#3d6b25", "#5c8a30", "#4a7a2a", "#6c9a38")):
    """RGBA leaf cluster: lobed leaves on a transparent ground (premultiplied-safe: colour bleeds outward)."""
    rng = random.Random(seed)
    S = size * 4
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)

    def hexc(h, k=1.0):
        h = h.lstrip("#")
        return tuple(min(255, int(int(h[i:i + 2], 16) * k)) for i in (0, 2, 4))
    for i in range(n):
        # leaves cluster towards the centre, pointing outward
        a = rng.uniform(0, 2 * math.pi)
        rr = S * 0.5 * rng.uniform(0.05, 0.86) ** 0.8
        cx, cy = S / 2 + math.cos(a) * rr, S / 2 + math.sin(a) * rr
        ln = S * rng.uniform(0.11, 0.17)
        wd = ln * rng.uniform(0.42, 0.55)
        rot = a + rng.uniform(-0.7, 0.7)
        col = hexc(rng.choice(cols), rng.uniform(0.75, 1.15))
        pts = []
        for k in range(28):
            t = k / 27.0
            u = t * 2 - 1
            lobes = 1.0 + 0.16 * math.sin(t * math.pi * 7)
            w = wd * 0.5 * math.sin(math.pi * t) ** 0.7 * lobes
            pts.append((u * ln * 0.5, w))
        pts2 = pts + [(x, -y) for (x, y) in reversed(pts)]
        ca, sa = math.cos(rot), math.sin(rot)
        poly = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for (x, y) in pts2]
        dr.polygon(poly, fill=col + (255,))
        # midrib
        dr.line([(cx - ca * ln * 0.5, cy - sa * ln * 0.5), (cx + ca * ln * 0.5, cy + sa * ln * 0.5)],
                fill=hexc("#2c4f1c") + (255,), width=max(1, S // 256))
    img = img.resize((size, size), Image.LANCZOS)
    # bleed colour into transparent texels (no dark halos under bilinear filtering / mipmaps)
    a = np.array(img).astype(np.float32)
    rgb, al = a[:, :, :3], a[:, :, 3:4] / 255.0
    acc = rgb * al
    wsum = al.copy()
    for _ in range(12):
        acc_n = acc.copy()
        w_n = wsum.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            acc_n += np.roll(acc, (dy, dx), axis=(0, 1))
            w_n += np.roll(wsum, (dy, dx), axis=(0, 1))
        mask = wsum < 1e-3
        acc = np.where(mask, acc_n, acc)
        wsum = np.where(mask, w_n, wsum)
    out = np.where(wsum > 1e-3, acc / np.maximum(wsum, 1e-3), 80.0)
    res = np.concatenate([np.clip(out, 0, 255), a[:, :, 3:4]], axis=2).astype(np.uint8)
    return Image.fromarray(res, "RGBA")


def build_oak(out_dir, name="tree_oak_cards", cards_per_blob=6, card_size=(2.3, 3.4), core_scale=0.6):
    rig = R.Rig(quick=True)
    blobs = []
    orig_crown = N.crown

    def crown(rig_, cname, center, a, b, c, n, r0, r1, mat, seed, disp=0.35, shell=0.6, subdiv=2, flat_bottom=None):
        rng = random.Random(seed)
        for i in range(n):
            p = N._rand_in_ellipsoid(rng, a, b, c, shell)
            if flat_bottom is not None and p.z < flat_bottom:
                p.z = flat_bottom + (p.z - flat_bottom) * 0.3
            r = rng.uniform(r0, r1) * (0.75 + 0.25 * (1 - abs(p.z) / c))
            rng.uniform(0.75, 1.0)
            blobs.append((np.array([center[0] + p.x, center[1] + p.y, center[2] + p.z]), r))
        # low-poly solid core instead of the displaced blob union
        import bmesh
        bm = bmesh.new()
        rng2 = random.Random(seed + 1)
        for (cpos, r) in blobs[::2]:
            MU.bm_sphere(r * core_scale, center=tuple(cpos), scale=(1.0, 1.0, 0.85), subdiv=1, bm=bm)
        return MU.make(cname + "_core", bm, mat, parent=rig_.root, smooth=True, sharp_deg=80)
    N.crown = crown
    try:
        N.tree_oak(rig, {})
    finally:
        N.crown = orig_crown
    objs = core.model_objects(rig)
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    g = Glb()
    bark_c = np.clip(core.lin_to_srgb(np.array([0.066, 0.043, 0.024])) * 255, 0, 255).astype(np.uint8)
    core_c = np.clip(core.lin_to_srgb(np.array([0.035, 0.10, 0.022])) * 255, 0, 255).astype(np.uint8)
    prims = []
    stats = {}
    H = 13.5
    for kind in ("bark", "core"):
        pos, nor = [], []
        for ob in objs:
            is_core = ob.name.endswith("_core")
            if (kind == "core") != is_core:
                continue
            s = core.Soup(ob, deps)
            pos.append(s.pos)
            nor.append(s.nor)
        pos = np.concatenate(pos)
        nor = np.concatenate(nor)
        n = pos.shape[0]
        col = np.empty((n, 3, 4), dtype=np.uint8)
        col[:, :, :3] = bark_c if kind == "bark" else core_c
        # alpha = sway weight (height^2), used by the wind shader
        col[:, :, 3] = np.clip((pos[:, :, 2] / H) ** 2 * 255, 0, 255).astype(np.uint8)
        uv = np.empty((n, 3, 2), dtype=np.float32)
        uv[:, :, 0] = 0.9 if kind == "bark" else 0.95
        uv[:, :, 1] = 0.0
        w = core.weld(core.to_gltf_axes(pos.reshape(-1, 3)).reshape(-1, 3, 3),
                      core.to_gltf_axes(nor.reshape(-1, 3)).reshape(-1, 3, 3), uv, col)
        mi = g.material("trim", rough=0.9, extras={"role": "trim"})
        prims.append(dict(pos=w["pos"], nor=w["nor"], idx=w["idx"], uv=w["uv"], col=w["col"], material=mi))
        stats[kind] = int(len(w["idx"]) // 3)
    # --- leaf cards
    rng = random.Random(77)
    cpos, cnor, cuv, ccol = [], [], [], []
    centre = np.mean([b[0] for b in blobs], axis=0)
    for (bc, r) in blobs:
        for k in range(cards_per_blob):
            # random direction, biased outward from the crown centre
            d = np.array([rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1)])
            out = bc - centre
            out = out / (np.linalg.norm(out) + 1e-6)
            d = d / (np.linalg.norm(d) + 1e-6) + out * 0.9
            d /= np.linalg.norm(d)
            p0 = bc + d * r * rng.uniform(0.75, 1.05)
            size = rng.uniform(*card_size)
            # card plane: roughly facing outward (normal = d), random roll, slight tilt
            tmp = np.array([0.0, 0.0, 1.0]) if abs(d[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
            u = np.cross(tmp, d)
            u /= np.linalg.norm(u)
            v = np.cross(d, u)
            roll = rng.uniform(0, 2 * math.pi)
            u2 = u * math.cos(roll) + v * math.sin(roll)
            v2 = -u * math.sin(roll) + v * math.cos(roll)
            tilt = rng.uniform(-0.5, 0.5)
            nrm = d * math.cos(tilt) + v2 * math.sin(tilt)
            v3 = v2 * math.cos(tilt) - d * math.sin(tilt)
            h = size * 0.5
            quad = [p0 - u2 * h - v3 * h, p0 + u2 * h - v3 * h, p0 + u2 * h + v3 * h, p0 - u2 * h + v3 * h]
            uvq = [(0, 1), (1, 1), (1, 0), (0, 0)]
            # shading normal: outward from the crown centre ("spherical normals" -> soft, volumetric look)
            sn = p0 - centre
            sn /= np.linalg.norm(sn)
            sn = sn * 0.7 + nrm * 0.3
            sn /= np.linalg.norm(sn)
            tint = rng.uniform(0.82, 1.08)
            phase = rng.randint(0, 255)
            for tri in ((0, 1, 2), (0, 2, 3)):
                cpos.append([quad[i] for i in tri])
                cnor.append([sn, sn, sn])
                cuv.append([uvq[i] for i in tri])
                sway = int(min(255, max(0, (p0[2] / H) ** 2 * 255)))
                ccol.append([[int(min(255, 200 * tint)), phase, 255, sway]] * 3)
    cpos = np.array(cpos)
    cnor = np.array(cnor)
    w = core.weld(core.to_gltf_axes(cpos.reshape(-1, 3)).reshape(-1, 3, 3),
                  core.to_gltf_axes(cnor.reshape(-1, 3)).reshape(-1, 3, 3), np.array(cuv, dtype=np.float32),
                  np.array(ccol, dtype=np.uint8))
    tex = leaf_texture()
    tex.save(os.path.join(out_dir, name + "_leaves.png"))
    buf = io.BytesIO()
    tex.save(buf, "PNG")
    ti = g.image(name + "_leaves.png", buf.getvalue())
    mi = g.material("leaves", rough=0.8, base_tex=ti, alpha_mode="MASK", alpha_cutoff=0.5, double_sided=True,
                    extras={"role": "leaves"})
    prims.append(dict(pos=w["pos"], nor=w["nor"], idx=w["idx"], uv=w["uv"], col=w["col"], material=mi))
    stats["cards"] = int(len(w["idx"]) // 3)
    mesh = g.mesh(name, prims)
    nid = g.node("body", mesh=mesh)
    g.node(name, children=[nid], root=True, extras=dict(id="props/tree_oak", lod=0, tris=sum(stats.values())))
    total = g.write(os.path.join(out_dir, name + ".glb"))
    print(name, stats, "tris", sum(stats.values()), "glb bytes", total, "blobs", len(blobs))


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    build_oak(out)
    build_oak(out, name="tree_oak_cards_lod1", cards_per_blob=2, card_size=(3.6, 4.8), core_scale=0.7)
