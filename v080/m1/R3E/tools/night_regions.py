"""Analyses the night check pictures: day box of the car (Arcade, diff > 45 against the empty frame), the measured
region (top middle) and per-channel means of the night frames there; also the means over the whole day mask and a
magnified crop with the region outlined."""
import os, sys
from PIL import Image, ImageDraw
import numpy as np

D = sys.argv[1]


def load(n):
    return np.asarray(Image.open(os.path.join(D, 'standin_%s.png' % n)).convert('RGB')).astype(np.float64)


def box(a, b):
    d = np.abs(a - b).sum(axis=2)
    m = d > 45
    ys, xs = np.nonzero(m)
    return (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1), m


def lum(img):
    return (0.2126 * img[..., 0] + 0.7152 * img[..., 1] + 0.0722 * img[..., 2]) / 255.0


for k, empty in [('20m', 'leer'), ('60m', 'leer'), ('spieler', 'leer')]:
    ad, al = load('nacht_12_%s_arcade' % k), load('nacht_12_%s_arcade' % empty)
    (x0, y0, x1, y1), mask = box(ad, al)
    w, h = x1 - x0, y1 - y0
    rx0, ry0 = x0 + w * 3 // 10, y0 + h // 10
    rx1, ry1 = rx0 + max(1, w * 2 // 5), ry0 + max(1, h // 4)
    an = load('nacht_22_%s_arcade' % k)
    mn = load('nacht_22_%s_modern' % k)
    ra = an[ry0:ry1, rx0:rx1]
    rm = mn[ry0:ry1, rx0:rx1]
    print('%-8s day box %s  region %s' % (k, (x0, y0, x1, y1), (rx0, ry0, rx1, ry1)))
    print('   region mean RGB arcade %s modern %s  lum %.4f / %.4f (%+.1f %%)' % (
        np.round(ra.reshape(-1, 3).mean(0), 1), np.round(rm.reshape(-1, 3).mean(0), 1), lum(ra).mean(), lum(rm).mean(),
        (lum(rm).mean() - lum(ra).mean()) / lum(ra).mean() * 100))
    la = lum(an)[mask].mean()
    lm = lum(mn)[mask].mean()
    print('   day-mask mean lum arcade %.4f modern %.4f (%+.1f %%), %d px' % (la, lm, (lm - la) / la * 100, mask.sum()))
    # magnified crop with the region
    pad = 10
    cx0, cy0, cx1, cy1 = max(0, x0 - pad), max(0, y0 - pad), x1 + pad, y1 + pad
    s = max(1, int(300 / max(cx1 - cx0, cy1 - cy0)))
    tiles = []
    for img in (an, mn):
        im = Image.fromarray(np.clip(img[cy0:cy1, cx0:cx1] * 2.5, 0, 255).astype(np.uint8))   # brightened x2.5
        im = im.resize(((cx1 - cx0) * s, (cy1 - cy0) * s), Image.NEAREST)
        dr = ImageDraw.Draw(im)
        dr.rectangle([(rx0 - cx0) * s, (ry0 - cy0) * s, (rx1 - cx0) * s - 1, (ry1 - cy0) * s - 1], outline=(0, 255, 0))
        tiles.append(im)
    out = Image.new('RGB', (tiles[0].width * 2 + 6, tiles[0].height), (16, 24, 44))
    out.paste(tiles[0], (0, 0))
    out.paste(tiles[1], (tiles[0].width + 6, 0))
    out.save(os.path.join(D, 'region_%s.png' % k))
