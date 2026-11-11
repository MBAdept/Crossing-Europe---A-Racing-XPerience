"""Leaf card textures for the card trees and bushes (class "leaves"): an RGBA atlas of leaf clusters. Pure PIL /
numpy, deterministic for a given seed.

One atlas = cols x rows cells. Every card of a crown shows one leaf cluster: twigs with leaves along them, denser
in the middle, on a transparent ground. One cell is the CORE: an opaque leaf mass for the closed inner hull of a
crown (it must never let the sky through). Grass atlases (grass_atlas) hold tufts of blades instead.

Mipmap-safe alpha (contract 4.6.5, leaves.gdshader scissor 0.42): Godot builds the mipmaps with a box filter, so a
thin leaf or blade averages below the scissor a few levels down and the crown thins out with distance. Every
transparent texel near a leaf gets a HALO alpha of 0.28: invisible at full size (below the scissor even after BC3
quantisation - BC3 alpha steps are 1/7 of the block range, a value of 0.36 could come out as 0.43), but in the
averaged texels of the coarser levels it keeps a leaf above the scissor while its share is at least ~20 % instead
of 42 %. coverage() measures that on a simulated mip chain. Colours bleed into every transparent texel (no dark
fringes under bilinear filtering and mipmaps).
"""
import io
import math
import random

import numpy as np
from PIL import Image, ImageDraw

SCISSOR = 0.42          # leaves.gdshader
HALO_ALPHA = 0.28       # below the scissor with margin for BC3 quantisation (max error ~0.07)
HALO_PX = 2             # texels around opaque texels that get the halo


def _hex(h, k=1.0):
    h = h.lstrip("#")
    return tuple(max(0, min(255, int(round(int(h[i:i + 2], 16) * k)))) for i in (0, 2, 4))


def _mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def _leaf_outline(kind, ln, wd, n=24, rng=None):
    """Half outline [(u along the leaf, v across)] of a leaf of length ln and width wd (u from -ln/2 at the stalk
    to +ln/2 at the tip)."""
    pts = []
    teeth = rng.uniform(0.0, 1.0) if rng else 0.5
    for k in range(n + 1):
        t = k / n
        u = (t - 0.5) * ln
        if kind == "lobed":            # oak: rounded lobes, widest beyond the middle
            lobes = 1.0 + 0.30 * math.sin(t * math.pi * (6.0 + teeth * 2.0)) ** 2 - 0.15
            w = wd * 0.5 * math.sin(math.pi * t ** 0.85) ** 0.7 * lobes
        elif kind == "needle":
            w = wd * 0.12 * math.sin(math.pi * t) ** 0.5
        elif kind == "birch":          # triangular-ovate, finely toothed, pointed tip
            w = wd * 0.5 * math.sin(math.pi * t ** 0.62) ** 1.1 * (1.0 + 0.06 * (k % 2))
        elif kind == "lanceolate":     # olive: long and narrow, pointed at both ends
            w = wd * 0.5 * math.sin(math.pi * t) ** 0.8
        else:                          # ovate: beech, hornbeam, bushes
            w = wd * 0.5 * math.sin(math.pi * t ** 0.8) ** 0.9 * (1.0 + 0.04 * (k % 2))
        pts.append((u, max(0.0, w)))
    return pts


def _tuft(dr, kind, cx, cy, ang, ln, base, lit, rng, S):
    """A tuft of needles (pine: a fan of long thin needles from one point) or a sprig (heather, cypress: a short
    shoot densely set with tiny scale leaves)."""
    w = max(1, S // 300)
    if kind == "needles":
        n = rng.randint(7, 11)
        for j in range(n):
            a = ang + (j / max(1, n - 1) - 0.5) * 1.5 + rng.uniform(-0.12, 0.12)
            l2 = ln * rng.uniform(0.7, 1.0)
            ex, ey = cx + math.cos(a) * l2, cy + math.sin(a) * l2
            dr.line([(cx, cy), (ex, ey)], fill=(_mix(base, lit, 0.6 * j / n)) + (255,), width=w + 1)
        return
    # sprig: a short stem and a dense column of small scale leaves along it
    ca, sa = math.cos(ang), math.sin(ang)
    dr.line([(cx, cy), (cx + ca * ln, cy + sa * ln)], fill=base + (255,), width=w + 1)
    steps = max(4, int(ln / max(2.0, S * 0.006)))
    for j in range(steps):
        t = j / steps
        px, py = cx + ca * ln * t, cy + sa * ln * t
        rr = ln * 0.12 * (1.0 - 0.6 * t) * rng.uniform(0.8, 1.2)
        col = _mix(base, lit, 0.7 * t)
        dr.ellipse([px - rr, py - rr * 0.8, px + rr, py + rr * 0.8], fill=col + (255,))


def _poly(cx, cy, rot, half):
    ca, sa = math.cos(rot), math.sin(rot)
    poly = [(cx + u * ca - v * sa, cy + u * sa + v * ca) for (u, v) in half]
    poly += [(cx + u * ca + v * sa, cy + u * sa - v * ca) for (u, v) in reversed(half)]
    return poly


def species_atlas(a):
    """cluster() parameters from a species' atlas entry (ce3d/veg3d.py SPECIES): the generator's two leaf colours
    `base` (the sprite's leaves material) as the leaf palette, brought to the sprite's mean under the race light by
    `sat` (saturation about the luma) and `gain` (value); `shade` = the colour deep inside a cluster."""
    c1, c2 = a["base"]
    gain = float(a.get("gain", 1.0))
    sat = float(a.get("sat", 1.0))

    tint = tuple(a.get("tint", (1.0, 1.0, 1.0)))

    def adj(rgb, k=1.0):
        y = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
        return "#%02x%02x%02x" % tuple(max(0, min(255, int(round((y + (x - y) * sat) * gain * k * t))))
                                       for x, t in zip(rgb, tint))
    a1, a2 = _hex(c1), _hex(c2)
    cols = [adj(_mix(a1, a2, t)) for t in (0.0, 0.3, 0.55, 0.8, 1.0)]
    cols.append(adj(_mix(a1, a2, 1.0), 1.1))
    out = dict(leaf=a["leaf"], colors=tuple(a.get("colors_extra", ())) + tuple(cols),
               shade=adj(a1, float(a.get("shade_k", 0.5))),
               n_leaves=int(a.get("n_leaves", 340)), leaf_len=tuple(a.get("leaf_len", (0.06, 0.085))),
               fill=float(a.get("fill", 0.93)), twig=a.get("twig", "#3a2c1e"), twig_share=float(a.get("twig_share", 0.2)),
               leaf_w=float(a.get("leaf_w", 0.55)), contrast=float(a.get("contrast", 0.28)),
               sheen=float(a.get("sheen", 0.14)), density_pow=float(a.get("density_pow", 0.62)),
               twigs=int(a.get("twigs", 5)))
    for k in ("flower", "flower_share", "underside", "underside_share", "ball_leaf", "ball_leaves", "fringe"):
        if k in a:
            out[k] = a[k]
    return out


def cluster(size, rng, sp, core=False):
    """One leaf cluster as RGBA image (size x size), drawn at 4x and reduced. sp: species dict (leaf, colors,
    n_leaves, leaf_len (fraction of the cell), fill (radius of the cluster), twig, light, contrast: how much darker
    the deep leaves are, sheen: how much lighter the top ones; optional underside / underside_share: the pale
    underside of some leaves (olive), flower / flower_share: blossoms (heather)). core=True: an opaque leaf mass
    filling the whole cell (the inner hull of a crown). Leaf kinds: lobed (oak), birch, ovate, lanceolate (olive),
    needles (tufts of needles: pine), sprig (tiny scale leaves on short shoots: heather, cypress)."""
    ss = 4
    S = size * ss
    kind = sp["leaf"]
    cols = [_hex(c) for c in sp["colors"]]
    dark = _hex(sp.get("shade", "#1d3311"))
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    c = S / 2.0
    fill = 1.15 if core else sp.get("fill", 0.92)
    contrast = float(sp.get("contrast", 0.45))
    sheen = float(sp.get("sheen", 0.12))
    if core:
        # dark ground: the core never shows holes
        dr.rectangle([0, 0, S, S], fill=_mix(dark, cols[0], 0.5) + (255,))
    # twigs from the centre outwards (leaves sit along them)
    twigs = []
    n_twigs = sp.get("twigs", 5)
    for k in range(n_twigs):
        a = 2 * math.pi * k / n_twigs + rng.uniform(-0.35, 0.35)
        r = S * 0.5 * fill * rng.uniform(0.75, 0.95)
        bend = rng.uniform(-0.35, 0.35)
        pts = []
        for i in range(6):
            t = i / 5
            aa = a + bend * t
            pts.append((c + math.cos(aa) * r * t, c + math.sin(aa) * r * t))
        twigs.append(pts)
        if not core:
            dr.line(pts, fill=_hex(sp.get("twig", "#3a2c1e")) + (255,), width=max(2, S // 140))
    leaves = []
    n = int(sp["n_leaves"] * (1.4 if core else 1.0))
    lmin, lmax = sp.get("leaf_len", (0.075, 0.11))
    # irregular outline of the clump: r(a) = R (1 + low harmonics)
    harm = [(k, rng.uniform(0.04, 0.12) * (3.0 / k), rng.uniform(0, 2 * math.pi)) for k in (2, 3, 5)]

    def rim(a):
        return S * 0.5 * fill * (1.0 + sum(h * math.sin(k * a + p) for (k, h, p) in harm)) / 1.12
    twig_share = sp.get("twig_share", 0.3)
    for i in range(n):
        if rng.random() < twig_share and twigs:
            # along a twig, alternating sides
            tw = twigs[rng.randrange(len(twigs))]
            t = rng.uniform(0.15, 1.0)
            j = min(4, int(t * 5))
            f = t * 5 - j
            px = tw[j][0] + (tw[j + 1][0] - tw[j][0]) * f
            py = tw[j][1] + (tw[j + 1][1] - tw[j][1]) * f
            ang = math.atan2(tw[j + 1][1] - tw[j][1], tw[j + 1][0] - tw[j][0]) + (1 if i % 2 else -1) * rng.uniform(0.5, 1.1)
            ln = S * rng.uniform(lmin, lmax)
            cx, cy = px + math.cos(ang) * ln * 0.45, py + math.sin(ang) * ln * 0.45
        else:
            a = rng.uniform(0, 2 * math.pi)
            rr = rim(a) * rng.uniform(0.0, 1.0) ** sp.get("density_pow", 0.62)
            cx, cy = c + math.cos(a) * rr, c + math.sin(a) * rr
            ang = a + rng.uniform(-1.3, 1.3)
            ln = S * rng.uniform(lmin, lmax)
        # a clump seen from outside is a dome: the leaves in the middle are on top and lit, the rim ones turn away
        rel = min(1.0, math.hypot(cx - c, cy - c) / max(1.0, S * 0.5 * fill))
        depth = min(1.0, max(0.0, (1.0 - rel) ** 0.7 * 0.75 + rng.uniform(0.0, 0.35)))
        leaves.append((depth, cx, cy, ang, ln, rng.choice(cols), rng.uniform(0.88, 1.1)))
    # back to front: deep leaves first and darker (inside the cluster), the top layer lighter
    leaves.sort(key=lambda l: l[0])
    light = sp.get("light", (-0.6, -0.8))         # direction the highlight comes from (image space)
    under = _hex(sp["underside"]) if sp.get("underside") else None
    under_share = float(sp.get("underside_share", 0.0))
    flower = [_hex(f) for f in sp.get("flower", ())]
    flower_share = float(sp.get("flower_share", 0.0))
    for (depth, cx, cy, ang, ln, col, k) in leaves:
        wd = ln * sp.get("leaf_w", 0.55)
        tone = (1.0 - contrast + contrast * depth) * k
        base = _mix(dark, col, min(1.0, tone))
        if under is not None and rng.random() < under_share:
            base = _mix(base, under, 0.55 + 0.3 * depth)       # the pale underside turned up (olive)
        if kind in ("needles", "sprig"):
            _tuft(dr, kind, cx, cy, ang, ln, base, _mix(base, (255, 255, 230), sheen * (0.5 + depth)), rng, S)
            if flower and rng.random() < flower_share:
                fc = rng.choice(flower)
                fl = _mix(fc, (255, 240, 255), sheen * depth)
                for _j in range(rng.randint(3, 6)):
                    fx = cx + math.cos(ang) * ln * rng.uniform(0.1, 0.5) + rng.gauss(0.0, ln * 0.08)
                    fy = cy + math.sin(ang) * ln * rng.uniform(0.1, 0.5) + rng.gauss(0.0, ln * 0.08)
                    rr = ln * rng.uniform(0.05, 0.09)
                    dr.ellipse([fx - rr, fy - rr, fx + rr, fy + rr], fill=_mix(fc, fl, depth) + (255,))
            continue
        half = _leaf_outline(kind, ln, wd, rng=rng)
        dr.polygon(_poly(cx, cy, ang, half), fill=base + (255,))
        # lit half of the leaf: a smaller copy shifted towards the light, lighter
        lift = 0.25 + 0.35 * depth
        lit = _mix(base, (255, 255, 230), sheen + 0.12 * depth)
        sx, sy = light[0] * ln * 0.06, light[1] * ln * 0.06
        dr.polygon(_poly(cx + sx, cy + sy, ang, [(u * 0.78, v * 0.62) for (u, v) in half]),
                   fill=_mix(base, lit, lift) + (255,))
        if kind != "needle" and ln > S * 0.05:
            ca, sa = math.cos(ang), math.sin(ang)
            dr.line([(cx - ca * ln * 0.5, cy - sa * ln * 0.5), (cx + ca * ln * 0.42, cy + sa * ln * 0.42)],
                    fill=_mix(base, dark, 0.35) + (255,), width=max(1, S // 400))
    out = img.resize((size, size), Image.LANCZOS)
    if core:
        a = np.array(out)
        a[:, :, 3] = 255
        out = Image.fromarray(a, "RGBA")
    return out


def ball(size, rng, sp):
    """A leaf ball (AS3): the cap of one crown blob, the texture of a leaf dome (ce3d/veg3d.py _dome_cards). The cell
    centre is the dome's pole, the cell's inscribed circle its rim. Inside `fringe` of the radius an opaque leaf mass
    (leaves on a ground of deeper leaves: no hole, never the sky), beyond it a ragged rim of single leaves pointing
    outwards - the leafy outline of the blob. No light and shade of its own: the dome's normals shade the blob, the
    texture is albedo (deeper leaves only a little darker: `contrast`)."""
    ss = 4
    S = size * ss
    kind = sp["leaf"]
    cols = [_hex(c) for c in sp["colors"]]
    dark = _hex(sp.get("shade", "#1d3311"))
    contrast = float(sp.get("contrast", 0.28))
    sheen = float(sp.get("sheen", 0.14))
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    c = S / 2.0
    R = S * 0.5 * 0.985
    fringe = float(sp.get("fringe", 0.86))
    ground = _mix(dark, cols[0], 0.62)
    rr = R * fringe * 0.98
    dr.ellipse([c - rr, c - rr, c + rr, c + rr], fill=ground + (255,))
    lmin, lmax = sp.get("ball_leaf", (0.028, 0.04))
    n = int(sp.get("ball_leaves", 2200))
    under = _hex(sp["underside"]) if sp.get("underside") else None
    under_share = float(sp.get("underside_share", 0.0))
    flower = [_hex(f) for f in sp.get("flower", ())]
    flower_share = float(sp.get("flower_share", 0.0))
    leaves = []
    for i in range(n):
        a = rng.uniform(0.0, 2.0 * math.pi)
        u = math.sqrt(rng.random())
        # a few leaves beyond the opaque part: the rim gets thinner outwards
        if u * R > rr and rng.random() > 0.45:
            u = rng.uniform(0.0, fringe)
        r = u * R
        cx, cy = c + math.cos(a) * r, c + math.sin(a) * r
        rim = r > rr * 0.92
        ang = rng.uniform(-math.pi, math.pi)
        ln = S * rng.uniform(lmin, lmax) * (0.85 if rim else 1.0)
        depth = rng.random()
        leaves.append((depth, cx, cy, ang, ln, rng.choice(cols), rng.uniform(0.9, 1.08), rim))
    leaves.sort(key=lambda l: l[0])
    light = sp.get("light", (-0.6, -0.8))
    for (depth, cx, cy, ang, ln, col, k, rim) in leaves:
        wd = ln * sp.get("leaf_w", 0.55)
        tone = (1.0 - contrast + contrast * depth) * k
        base = _mix(dark, col, min(1.0, tone))
        if under is not None and rng.random() < under_share:
            base = _mix(base, under, 0.5 + 0.3 * depth)
        if kind in ("needles", "sprig"):
            _tuft(dr, kind, cx, cy, ang, ln * 1.6, base, _mix(base, (255, 255, 230), sheen * (0.5 + depth)), rng, S)
        else:
            half = _leaf_outline(kind, ln, wd, rng=rng)
            dr.polygon(_poly(cx, cy, ang, half), fill=base + (255,))
            lit = _mix(base, (255, 255, 230), sheen + 0.1 * depth)
            sx, sy = light[0] * ln * 0.06, light[1] * ln * 0.06
            dr.polygon(_poly(cx + sx, cy + sy, ang, [(u2 * 0.78, v2 * 0.62) for (u2, v2) in half]),
                       fill=_mix(base, lit, 0.3 + 0.3 * depth) + (255,))
        if flower and rng.random() < flower_share:
            fc = rng.choice(flower)
            for _j in range(rng.randint(2, 5)):
                fx, fy = cx + rng.gauss(0.0, ln * 0.35), cy + rng.gauss(0.0, ln * 0.35)
                fr = ln * rng.uniform(0.12, 0.2)
                dr.ellipse([fx - fr, fy - fr, fx + fr, fy + fr], fill=_mix(fc, (255, 235, 255), sheen * depth) + (255,))
    return img.resize((size, size), Image.LANCZOS)


def grass_tuft(size, rng, sp):
    """A tuft of grass blades (RGBA, size x size), rooted at the bottom middle of the cell."""
    ss = 4
    S = size * ss
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    cols = [_hex(c) for c in sp["colors"]]
    dark = _hex(sp.get("shade", "#24331a"))
    blades = []
    for i in range(sp.get("n_blades", 70)):
        x0 = S * 0.5 + rng.gauss(0.0, S * 0.11)
        h = S * rng.uniform(0.45, 0.97)
        lean = rng.gauss(0.0, 0.32) + (x0 - S * 0.5) / S * 1.4
        w = S * rng.uniform(0.012, 0.022)
        blades.append((rng.random(), x0, h, lean, w, rng.choice(cols)))
    blades.sort(key=lambda b: b[0])
    for (depth, x0, h, lean, w, col) in blades:
        base = _mix(dark, col, 0.45 + 0.55 * depth)
        tip = _mix(base, _hex(sp.get("tip", "#b9b26a")), 0.35 * depth)
        pts_l, pts_r = [], []
        for k in range(9):
            t = k / 8
            x = x0 + lean * h * t * t * 0.9
            y = S - h * t
            ww = w * (1.0 - t) ** 0.8
            pts_l.append((x - ww, y))
            pts_r.append((x + ww, y))
        dr.polygon(pts_l + list(reversed(pts_r)), fill=base + (255,))
        # lighter upper half
        dr.polygon(pts_l[4:] + list(reversed(pts_r[4:])), fill=tip + (255,))
    return img.resize((size, size), Image.LANCZOS)


def halo(img, alpha=HALO_ALPHA, px=HALO_PX, scissor=SCISSOR):
    """Mipmap-safe alpha: transparent texels within px of a visible texel (alpha >= scissor) get alpha `alpha`
    (kept below the scissor). Returns a new image."""
    a = np.array(img).astype(np.float64)
    al = a[:, :, 3] / 255.0
    vis = al >= scissor
    near = vis.copy()
    for _ in range(px):
        g = near.copy()
        g[1:, :] |= near[:-1, :]
        g[:-1, :] |= near[1:, :]
        g[:, 1:] |= near[:, :-1]
        g[:, :-1] |= near[:, 1:]
        near = g
    lift = near & ~vis
    al = np.where(lift, np.maximum(al, alpha), al)
    al = np.where(~vis, np.minimum(al, alpha), al)         # antialiased rims must stay below the scissor too
    a[:, :, 3] = np.round(al * 255.0)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def bleed(img, steps=24, scissor=SCISSOR):
    """Spreads the colour of opaque texels (alpha >= scissor) into the transparent ones (alpha unchanged)."""
    a = np.array(img).astype(np.float64)
    rgb, al = a[:, :, :3], a[:, :, 3:4] / 255.0
    w0 = (al >= scissor).astype(np.float64)
    acc = rgb * w0
    wsum = w0.copy()
    for _ in range(steps):
        acc_n = acc.copy()
        w_n = wsum.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            acc_n += np.roll(acc, (dy, dx), axis=(0, 1))
            w_n += np.roll(wsum, (dy, dx), axis=(0, 1))
        mask = wsum < 1e-3
        acc = np.where(mask, acc_n, acc)
        wsum = np.where(mask, w_n, wsum)
    mean = (rgb * w0).sum(axis=(0, 1)) / max(1e-6, float(w0.sum()))
    out = np.where(wsum > 1e-3, acc / np.maximum(wsum, 1e-3), mean)
    out = np.where(w0 > 0.5, rgb, out)
    res = np.concatenate([np.clip(np.round(out), 0, 255), a[:, :, 3:4]], axis=2).astype(np.uint8)
    return Image.fromarray(res, "RGBA")


def coverage(img, levels=5, scissor=SCISSOR):
    """Share of texels at or above the scissor per mip level of a box-filtered chain (what Godot builds):
    [level 0, 1, ...]. A mipmap-safe texture keeps the share roughly constant."""
    a = np.array(img).astype(np.float64)[:, :, 3] / 255.0
    out = []
    for _ in range(levels):
        out.append(round(float((a >= scissor).mean()), 4))
        h, w = a.shape[0] // 2, a.shape[1] // 2
        if h < 1 or w < 1:
            break
        a = a[:h * 2, :w * 2].reshape(h, 2, w, 2).mean(axis=(1, 3))
    return out


def atlas(sp, size=1024, grid=(4, 4), seed=3, cells="cluster"):
    """RGBA leaf atlas of grid[0] x grid[1] cells for species sp; the LAST cell is the opaque core. cells: "cluster"
    (flat leaf cards) or "ball" (leaf domes, AS3). Returns (PIL image, {"leaf": [uv rects (u0, v0, u1, v1)],
    "core": rect})."""
    rng = random.Random(seed)
    cols, rows = grid
    cw, ch = size // cols, size // rows
    sheet = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rects = []
    for r in range(rows):
        for c in range(cols):
            core = (r == rows - 1 and c == cols - 1)
            if cells == "ball" and not core:
                cl = ball(min(cw, ch), rng, sp)
            else:
                cl = cluster(min(cw, ch), rng, sp, core=core)
            if not core:
                cl = bleed(halo(cl))
            sheet.paste(cl, (c * cw, r * ch))
            # half a texel inside the cell: neighbours never bleed in
            rects.append(((c * cw + 0.5) / size, (r * ch + 0.5) / size, ((c + 1) * cw - 0.5) / size,
                          ((r + 1) * ch - 0.5) / size))
    return sheet, {"leaf": rects[:-1], "core": rects[-1]}


def branch(size, rng, sp):
    """A spruce branch seen from above (AS3, ce3d/veg3d_shapes.py tier cards): the twig runs from the top of the cell
    (the inner end at the trunk) to the bottom (the tip), side twigs leave it forwards and outwards, every twig set
    with short needles; widest in the middle, a ragged tip. RGBA (size x size)."""
    ss = 4
    S = size * ss
    cols = [_hex(c) for c in sp["colors"]]
    dark = _hex(sp.get("shade", "#10200f"))
    contrast = float(sp.get("contrast", 0.28))
    sheen = float(sp.get("sheen", 0.14))
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    cx = S * 0.5
    twig = _hex(sp.get("twig", "#3a2a1c"))
    w = max(1, S // 220)
    twigs = [[(cx + rng.gauss(0.0, S * 0.01), S * 0.02), (cx + rng.gauss(0.0, S * 0.02), S * 0.5),
              (cx + rng.gauss(0.0, S * 0.02), S * 0.97)]]
    n_side = 9
    for k in range(n_side):
        t = 0.12 + 0.8 * k / (n_side - 1)
        y0 = S * t
        x0 = cx + (twigs[0][1][0] - cx) * min(1.0, t * 2.0)
        reach = S * 0.46 * math.sin(math.pi * min(1.0, 0.15 + t * 0.95)) * rng.uniform(0.8, 1.05)
        for side in (-1, 1):
            ang = math.radians(rng.uniform(32.0, 48.0))
            x1 = x0 + side * reach * math.sin(ang)
            y1 = y0 + reach * math.cos(ang)
            twigs.append([(x0, y0), ((x0 + x1) * 0.5, (y0 + y1) * 0.5 + S * 0.01), (x1, y1)])
    for tw in twigs:
        dr.line(tw, fill=twig + (255,), width=w + 1)
    # needles along every twig, both sides, pointing forwards; deeper ones darker
    for tw in twigs:
        for i in range(len(tw) - 1):
            (xa, ya), (xb, yb) = tw[i], tw[i + 1]
            seg = math.hypot(xb - xa, yb - ya)
            n = max(2, int(seg / (S * 0.008)))
            ang = math.atan2(yb - ya, xb - xa)
            for j in range(n):
                f = j / n
                px, py = xa + (xb - xa) * f, ya + (yb - ya) * f
                for side in (-1, 1):
                    a = ang + side * math.radians(rng.uniform(40.0, 70.0))
                    ln = S * rng.uniform(0.03, 0.05)
                    depth = rng.random()
                    col = _mix(dark, rng.choice(cols), min(1.0, (1.0 - contrast + contrast * depth)))
                    col = _mix(col, (255, 255, 230), sheen * depth * 0.6)
                    dr.line([(px, py), (px + math.cos(a) * ln, py + math.sin(a) * ln)], fill=col + (255,), width=w + 1)
    return img.resize((size, size), Image.LANCZOS)


def frond(w, h, rng, sp):
    """A palm frond (AS3, ce3d/veg3d_shapes.py frond strips): the rachis runs up the middle of a w x h cell from the
    base (bottom) to the tip (top); leaflets leave it on both sides, angled towards the tip, long in the middle of
    the frond, short at its ends, drooping a little; darker at the rachis, lighter at their tips. RGBA (w x h)."""
    ss = 3
    W, H = w * ss, h * ss
    cols = [_hex(c) for c in sp["colors"]]
    dark = _hex(sp.get("shade", "#1d3311"))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    cx = W * 0.5
    rachis = _hex(sp.get("twig", "#8a7a3a"))
    n = 52
    for k in range(n):
        t = (k + rng.uniform(0.2, 0.8)) / n
        y0 = H * (1.0 - t * 0.98)
        span = math.sin(math.pi * min(1.0, 0.08 + t * 1.02)) ** 0.6
        for side in (-1, 1):
            ln = W * 0.5 * span * rng.uniform(0.88, 1.04)
            if ln < W * 0.04:
                continue
            ang = math.radians(rng.uniform(24.0, 36.0))       # towards the tip
            droop = rng.uniform(0.0, 0.06)
            x1 = cx + side * ln * math.cos(ang)
            y1 = y0 - ln * math.sin(ang) + ln * droop
            lw = W * rng.uniform(0.034, 0.048)
            col = rng.choice(cols)
            base = _mix(dark, col, 0.78)
            tip = _mix(col, (255, 255, 220), 0.12)
            # a narrow leaflet: polygon along the line, widest a third out
            dx, dy = x1 - cx, y1 - y0
            L = math.hypot(dx, dy)
            ux, uy = dx / L, dy / L
            px, py = -uy, ux
            pts_l, pts_r = [], []
            for j in range(9):
                f = j / 8
                ww = lw * math.sin(math.pi * min(1.0, f * 1.25 + 0.05)) ** 0.8
                xx, yy = cx + dx * f, y0 + dy * f + ln * droop * f * f
                pts_l.append((xx + px * ww, yy + py * ww))
                pts_r.append((xx - px * ww, yy - py * ww))
            dr.polygon(pts_l + list(reversed(pts_r)), fill=base + (255,))
            dr.line([(cx, y0), (cx + dx * 0.9, y0 + dy * 0.9)], fill=_mix(base, tip, 0.5) + (255,), width=max(1, ss))
    dr.line([(cx, H), (cx, H * 0.02)], fill=rachis + (255,), width=max(2, W // 60))
    return img.resize((w, h), Image.LANCZOS)


def special_atlas(kind, sp, size=1024, seed=3):
    """Atlas of the special crowns (AS3): kind "branch" - 4 x 4 cells of spruce branches, the last one the opaque core
    (needle mass of the inner cones); kind "frond" - four palm fronds side by side (cells of size/4 x size).
    Returns (PIL image, {"leaf": [uv rects], "core": rect or None})."""
    rng = random.Random(seed)
    sheet = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rects = []
    core = None
    if kind == "frond":
        cw = size // 4
        for c in range(4):
            sheet.paste(bleed(halo(frond(cw, size, rng, sp))), (c * cw, 0))
            rects.append(((c * cw + 0.5) / size, 0.5 / size, ((c + 1) * cw - 0.5) / size, (size - 0.5) / size))
        return sheet, {"leaf": rects, "core": None}
    cw = size // 4
    for r in range(4):
        for c in range(4):
            last = r == 3 and c == 3
            cl = cluster(cw, rng, sp, core=True) if last else bleed(halo(branch(cw, rng, sp)))
            sheet.paste(cl, (c * cw, r * cw))
            rect = ((c * cw + 0.5) / size, (r * cw + 0.5) / size, ((c + 1) * cw - 0.5) / size, ((r + 1) * cw - 0.5) / size)
            if last:
                core = rect
            else:
                rects.append(rect)
    return sheet, {"leaf": rects, "core": core}


def mixed_atlas(groups, size=512, grid=(2, 2), seed=3):
    """Atlas of leaf-ball cells of several palettes (AS3, heather: flowers and foliage): groups = [(sp, cells)], filled
    in order; the LAST cell is the opaque core in the last palette. Returns (PIL image, {"leaf": all ball rects,
    "groups": [rects of each group], "core": rect})."""
    rng = random.Random(seed)
    cols, rows = grid
    cw, ch = size // cols, size // rows
    sheet = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    plan = [g for g, (sp, n) in enumerate(groups) for _k in range(n)]
    out = {"leaf": [], "groups": [[] for _g in groups]}
    i = 0
    for r in range(rows):
        for c in range(cols):
            core = (r == rows - 1 and c == cols - 1)
            g = plan[min(i, len(plan) - 1)] if not core else len(groups) - 1
            cl = cluster(min(cw, ch), rng, groups[g][0], core=True) if core else bleed(halo(ball(min(cw, ch), rng,
                                                                                                    groups[g][0])))
            sheet.paste(cl, (c * cw, r * ch))
            rect = ((c * cw + 0.5) / size, (r * ch + 0.5) / size, ((c + 1) * cw - 0.5) / size, ((r + 1) * ch - 0.5) / size)
            if core:
                out["core"] = rect
            else:
                out["leaf"].append(rect)
                out["groups"][g].append(rect)
                i += 1
    return sheet, out


def grass_atlas(sp, size=512, grid=(2, 2), seed=5):
    """RGBA atlas of grass tufts. Returns (PIL image, {"leaf": [uv rects]})."""
    rng = random.Random(seed)
    cols, rows = grid
    cw, ch = size // cols, size // rows
    sheet = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rects = []
    for r in range(rows):
        for c in range(cols):
            cl = bleed(halo(grass_tuft(min(cw, ch), rng, sp)))
            sheet.paste(cl, (c * cw, r * ch))
            rects.append(((c * cw + 0.5) / size, (r * ch + 0.5) / size, ((c + 1) * cw - 0.5) / size,
                          ((r + 1) * ch - 0.5) / size))
    return sheet, {"leaf": rects}


def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()
