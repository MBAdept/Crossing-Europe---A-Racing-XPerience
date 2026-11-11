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
        else:                          # ovate: beech, hornbeam, bushes
            w = wd * 0.5 * math.sin(math.pi * t ** 0.8) ** 0.9 * (1.0 + 0.04 * (k % 2))
        pts.append((u, max(0.0, w)))
    return pts


def _poly(cx, cy, rot, half):
    ca, sa = math.cos(rot), math.sin(rot)
    poly = [(cx + u * ca - v * sa, cy + u * sa + v * ca) for (u, v) in half]
    poly += [(cx + u * ca + v * sa, cy + u * sa - v * ca) for (u, v) in reversed(half)]
    return poly


def cluster(size, rng, sp, core=False):
    """One leaf cluster as RGBA image (size x size), drawn at 4x and reduced. sp: species dict (leaf, colors,
    n_leaves, leaf_len (fraction of the cell), fill (radius of the cluster), twig, light). core=True: an opaque
    leaf mass filling the whole cell (the inner hull of a crown)."""
    ss = 4
    S = size * ss
    kind = sp["leaf"]
    cols = [_hex(c) for c in sp["colors"]]
    dark = _hex(sp.get("shade", "#1d3311"))
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    c = S / 2.0
    fill = 1.15 if core else sp.get("fill", 0.92)
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
    for (depth, cx, cy, ang, ln, col, k) in leaves:
        wd = ln * sp.get("leaf_w", 0.55)
        half = _leaf_outline(kind, ln, wd, rng=rng)
        tone = (0.55 + 0.45 * depth) * k
        base = _mix(dark, col, min(1.0, tone))
        dr.polygon(_poly(cx, cy, ang, half), fill=base + (255,))
        # lit half of the leaf: a smaller copy shifted towards the light, lighter
        lift = 0.25 + 0.35 * depth
        lit = _mix(base, (255, 255, 230), 0.10 + 0.12 * depth)
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


def bleed(img, steps=24):
    """Spreads the colour of opaque texels into the transparent ones (alpha unchanged)."""
    a = np.array(img).astype(np.float64)
    rgb, al = a[:, :, :3], a[:, :, 3:4] / 255.0
    w0 = (al >= SCISSOR).astype(np.float64)
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


def atlas(sp, size=1024, grid=(4, 4), seed=3):
    """RGBA leaf atlas of grid[0] x grid[1] cells for species sp; the LAST cell is the opaque core.
    Returns (PIL image, {"leaf": [uv rects (u0, v0, u1, v1)], "core": rect})."""
    rng = random.Random(seed)
    cols, rows = grid
    cw, ch = size // cols, size // rows
    sheet = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rects = []
    for r in range(rows):
        for c in range(cols):
            core = (r == rows - 1 and c == cols - 1)
            cl = cluster(min(cw, ch), rng, sp, core=core)
            if not core:
                cl = bleed(halo(cl))
            sheet.paste(cl, (c * cw, r * ch))
            # half a texel inside the cell: neighbours never bleed in
            rects.append(((c * cw + 0.5) / size, (r * ch + 0.5) / size, ((c + 1) * cw - 0.5) / size,
                          ((r + 1) * ch - 0.5) / size))
    return sheet, {"leaf": rects[:-1], "core": rects[-1]}


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
