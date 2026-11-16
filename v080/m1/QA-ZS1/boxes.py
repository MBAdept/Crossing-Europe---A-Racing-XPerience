#!/usr/bin/env python3
"""QA-ZS1: per A/B frame pair, the box of the player's paint (blue limousine, rule of check_start_km0.gd) and the box
of the dark start-gate banner, Arcade vs Modern; edges in px and % of Arcade's box.
   boxes.py <prefix> [nn ...]      (pictures <prefix>_arcade_NN.png / <prefix>_modern_NN.png)"""
import sys
import glob
import numpy as np
from PIL import Image

MIN_EDGE = 3


def load(p):
    return np.asarray(Image.open(p).convert("RGB")).astype(np.float32) / 255.0


def bbox(mask, min_edge=MIN_EDGE):
    rows = mask.sum(axis=1)
    cols = mask.sum(axis=0)
    ys = np.nonzero(rows >= min_edge)[0]
    xs = np.nonzero(cols >= min_edge)[0]
    if len(ys) == 0 or len(xs) == 0:
        return None
    return (int(xs[0]), int(ys[0]), int(xs[-1]), int(ys[-1]))


def paint_box(img):
    h, w, _ = img.shape
    x0, x1 = int(w * 0.3), int(w * 0.7)
    y0 = int(0.45 * h) + 40
    sub = img[y0:, x0:x1]
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    import os
    if os.environ.get("PAINT") == "yellow":
        m = (r > 0.6) & (g > 0.45) & (b < 0.35) & (r - b > 0.35)
    else:
        m = (b > 0.35) & (b - r > 0.18) & (b - g > 0.08)
    bb = bbox(m)
    if bb is None:
        return None
    return (bb[0] + x0, bb[1] + y0, bb[2] + x0, bb[3] + y0)


def gate_box(img):
    h, w, _ = img.shape
    x0, x1, y0, y1 = int(w * 0.12), int(w * 0.88), int(h * 0.14), int(h * 0.62)
    sub = img[y0:y1, x0:x1]
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    m = (r < 0.16) & (g < 0.16) & (b < 0.19) & (np.abs(r - b) < 0.07)
    bb = bbox(m, 40)
    if bb is None:
        return None
    return (bb[0] + x0, bb[1] + y0, bb[2] + x0, bb[3] + y0)


def fmt(bb):
    return "-" if bb is None else "%dx%d@(%d,%d)" % (bb[2] - bb[0] + 1, bb[3] - bb[1] + 1, bb[0], bb[1])


def edges(a, m):
    if a is None or m is None:
        return "-"
    wa, ha = a[2] - a[0] + 1, a[3] - a[1] + 1
    d = [m[0] - a[0], m[2] - a[2], m[1] - a[1], m[3] - a[3]]
    return "L%+d R%+d T%+d B%+d px (%+.1f/%+.1f/%+.1f/%+.1f %%)" % (d[0], d[1], d[2], d[3], 100.0 * d[0] / wa,
        100.0 * d[1] / wa, 100.0 * d[2] / ha, 100.0 * d[3] / ha)


def main():
    prefix = sys.argv[1]
    nns = sys.argv[2:] or sorted(p[-6:-4] for p in glob.glob(prefix + "_arcade_[0-9][0-9].png"))
    for nn in nns:
        a = load("%s_arcade_%s.png" % (prefix, nn))
        m = load("%s_modern_%s.png" % (prefix, nn))
        pa, pm = paint_box(a), paint_box(m)
        ga, gm = gate_box(a), gate_box(m)
        print("%s  car A %-18s M %-18s %s" % (nn, fmt(pa), fmt(pm), edges(pa, pm)))
        print("    gate A %-18s M %-18s %s" % (fmt(ga), fmt(gm), edges(ga, gm)))


main()
