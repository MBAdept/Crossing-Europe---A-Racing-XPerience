#!/usr/bin/env python3
"""A-29: body brightness of the player car (vehicle probe): car pixels = |player_nobrake - player30| > 0.06 in the
bottom-centre box; body = the upper 55 % of their bounding box, not red (tail lamps), not very dark (glass/tyres).
usage: body.py <veh dir> <tag> [<tag> ...]"""
import colorsys, os, sys
import numpy as np
from PIL import Image
def load(p): return np.asarray(Image.open(p).convert("RGB")).astype(np.float32) / 255.0
d = sys.argv[1]
for tag in sys.argv[2:]:
    a = load(os.path.join(d, tag + "_player_nobrake.png")); b = load(os.path.join(d, tag + "_player30.png"))
    h, w, _ = a.shape
    m = np.zeros((h, w), bool)
    box = (slice(int(h * 0.55), h), slice(int(w * 0.3), int(w * 0.7)))
    m[box] = (np.abs(a - b).max(axis=2) > 0.06)[box]
    ys, xs = np.nonzero(m)
    y0, y1 = np.percentile(ys, 2), np.percentile(ys, 98)
    x0, x1 = np.percentile(xs, 5), np.percentile(xs, 95)
    sel = m.copy(); sel[: int(y0)] = False; sel[int(y0 + 0.55 * (y1 - y0)):] = False
    sel[:, : int(x0)] = False; sel[:, int(x1):] = False
    px = a[sel]
    red = (px[:, 0] > px[:, 1] * 1.6) & (px[:, 0] > 0.25)
    px = px[~red]
    L = 0.2126 * px[:, 0] + 0.7152 * px[:, 1] + 0.0722 * px[:, 2]
    px = px[L > 0.04]; L = L[L > 0.04]
    hsv = np.array([colorsys.rgb_to_hsv(*c) for c in px[:: max(1, len(px) // 3000)]])
    print("%-26s n=%5d lum p50 %.3f p75 %.3f p95 %.3f  sat mean %.2f  hue mean %.0f" % (tag, len(px), np.median(L),
          np.percentile(L, 75), np.percentile(L, 95), hsv[:, 1].mean(), 360 * np.median(hsv[:, 0])))
