"""Leaf card textures for the card trees (class "leaves"): an RGBA atlas of leaf clusters. Pure PIL / numpy.

One atlas = cols x rows clusters; every card of a tree shows one cluster. A cluster is a twig with leaves
around it, denser in the middle, on a transparent ground; the leaf colour bleeds into the transparent
texels so that bilinear filtering and mipmaps show no dark fringes. Deterministic for a given seed.
"""
import io
import math
import random

import numpy as np
from PIL import Image, ImageDraw


def _hex(h, k=1.0):
    h = h.lstrip("#")
    return tuple(max(0, min(255, int(round(int(h[i:i + 2], 16) * k)))) for i in (0, 2, 4))


def _leaf_outline(kind, ln, wd, n=22):
    """Half outline [(u along the leaf, v across)] of a leaf of length ln and width wd."""
    pts = []
    for k in range(n + 1):
        t = k / n
        u = (t - 0.5) * ln
        if kind == "lobed":            # oak: rounded lobes, widest beyond the middle
            w = wd * 0.5 * math.sin(math.pi * t ** 0.85) ** 0.75 * (1.0 + 0.22 * math.sin(t * math.pi * 7.0))
        elif kind == "needle":
            w = wd * 0.12 * math.sin(math.pi * t) ** 0.5
        else:                          # ovate: beech, birch, poplar
            w = wd * 0.5 * math.sin(math.pi * t ** 0.8) ** 0.9
        pts.append((u, max(0.0, w)))
    return pts


def cluster(size, rng, kind, cols, n_leaves, twig="#3a2c1e"):
    """One leaf cluster as RGBA image (size x size), drawn at 4x and reduced."""
    ss = 4
    S = size * ss
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    c = S / 2.0
    # a few twigs from the centre outwards
    for k in range(5):
        a = 2 * math.pi * k / 5 + rng.uniform(-0.4, 0.4)
        r = S * rng.uniform(0.28, 0.42)
        mid = (c + math.cos(a + 0.25) * r * 0.5, c + math.sin(a + 0.25) * r * 0.5)
        end = (c + math.cos(a) * r, c + math.sin(a) * r)
        dr.line([(c, c), mid, end], fill=_hex(twig) + (255,), width=max(2, S // 110))
    leaves = []
    for i in range(n_leaves):
        a = rng.uniform(0, 2 * math.pi)
        rr = S * 0.5 * rng.uniform(0.02, 0.84) ** 0.7
        leaves.append((rr, a, rng.uniform(0.14, 0.2), rng.uniform(0.44, 0.58), a + rng.uniform(-0.8, 0.8),
                       rng.choice(cols), rng.uniform(0.72, 1.12)))
    # back to front: inner leaves first and darker, outer leaves on top
    leaves.sort(key=lambda l: (-l[6], l[0]))
    for depth, (rr, a, ln_f, wd_f, rot, col, k) in enumerate(leaves):
        cx, cy = c + math.cos(a) * rr, c + math.sin(a) * rr
        ln = S * ln_f
        half = _leaf_outline(kind, ln, ln * wd_f)
        ca, sa = math.cos(rot), math.sin(rot)
        poly = [(cx + u * ca - v * sa, cy + u * sa + v * ca) for (u, v) in half]
        poly += [(cx + u * ca + v * sa, cy + u * sa - v * ca) for (u, v) in reversed(half)]
        shade = k * (0.78 + 0.22 * depth / max(1, len(leaves) - 1))
        dr.polygon(poly, fill=_hex(col, shade) + (255,))
        if kind != "needle":
            dr.line([(cx - ca * ln * 0.5, cy - sa * ln * 0.5), (cx + ca * ln * 0.46, cy + sa * ln * 0.46)],
                    fill=_hex(col, shade * 0.72) + (255,), width=max(1, S // 300))
    return img.resize((size, size), Image.LANCZOS)


def bleed(img, steps=24):
    """Spreads the colour of opaque texels into the transparent ones (alpha unchanged)."""
    a = np.array(img).astype(np.float64)
    rgb, al = a[:, :, :3], a[:, :, 3:4] / 255.0
    acc = rgb * al
    wsum = al.copy()
    for _ in range(steps):
        acc_n = acc.copy()
        w_n = wsum.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            acc_n += np.roll(acc, (dy, dx), axis=(0, 1))
            w_n += np.roll(wsum, (dy, dx), axis=(0, 1))
        mask = wsum < 1e-3
        acc = np.where(mask, acc_n, acc)
        wsum = np.where(mask, w_n, wsum)
    mean = (rgb * al).sum(axis=(0, 1)) / max(1e-6, float(al.sum()))
    out = np.where(wsum > 1e-3, acc / np.maximum(wsum, 1e-3), mean)
    res = np.concatenate([np.clip(np.round(out), 0, 255), a[:, :, 3:4]], axis=2).astype(np.uint8)
    return Image.fromarray(res, "RGBA")


def atlas(kind="lobed", colors=("#3d6b25", "#5c8a30", "#4a7a2a", "#6c9a38"), size=512, grid=(2, 2), n_leaves=84,
          seed=3):
    """RGBA atlas (size x size) of grid[0] x grid[1] clusters. Returns (PIL image, [uv rects (u0, v0, u1, v1)])."""
    rng = random.Random(seed)
    cols, rows = grid
    cw, ch = size // cols, size // rows
    sheet = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rects = []
    for r in range(rows):
        for c in range(cols):
            cl = bleed(cluster(min(cw, ch), rng, kind, colors, n_leaves))
            sheet.paste(cl, (c * cw, r * ch))
            # half a texel inside the cell: neighbours never bleed in
            rects.append(((c * cw + 0.5) / size, (r * ch + 0.5) / size, ((c + 1) * cw - 0.5) / size,
                          ((r + 1) * ch - 0.5) / size))
    return sheet, rects


def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()
