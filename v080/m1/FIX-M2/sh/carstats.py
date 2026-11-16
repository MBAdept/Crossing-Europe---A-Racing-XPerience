#!/usr/bin/env python3
"""QA-M2-BILD: the player car in the vehicle probe pictures – its pixels (picture "player" minus the same view without
the player, "d150a" of the traffic run or "player30" of the car's own run is not usable: other car) and their mean
luminance, saturation and brightest 5 %, Arcade vs Modern.
usage: carstats.py <veh dir> <tag> [<tag> ...]   (tags of runs with the scenes player, player_nobrake, player30)
For each tag: mask = |player_nobrake - player30-without-car| is not available, so the mask is the bottom-centre box where
the chase camera shows the car, restricted to pixels that differ from the empty road picture of the same run
(scene d150a when present, else the car box of player30 mirrored – see below)."""
import colorsys
import os
import sys

import numpy as np
from PIL import Image


def load(p):
    return np.asarray(Image.open(p).convert("RGB")).astype(np.float32) / 255.0


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


d = sys.argv[1]
for tag in sys.argv[2:]:
    p = os.path.join(d, tag + "_player_nobrake.png")
    q = os.path.join(d, tag + "_player30.png")
    if not (os.path.exists(p) and os.path.exists(q)):
        print(tag, "missing pictures")
        continue
    a = load(p)
    b = load(q)   # same view, player hidden, its model 30 m ahead: the near car region is empty road there
    h, w, _ = a.shape
    box = (slice(int(h * 0.55), h), slice(int(w * 0.3), int(w * 0.7)))
    diff = np.abs(a - b).max(axis=2) > 0.06
    m = np.zeros((h, w), bool)
    m[box] = diff[box]
    px = a[m]
    if px.size == 0:
        print(tag, "no car pixels")
        continue
    L = lum(px)
    hsv = np.array([colorsys.rgb_to_hsv(*c) for c in px[:: max(1, len(px) // 4000)]])
    ys, xs = np.nonzero(m)
    print("%-28s px=%6d bbox=[%d,%d,%d,%d] lum mean %.3f p50 %.3f p95 %.3f  sat mean %.2f  value mean %.2f" % (
        tag, m.sum(), xs.min(), ys.min(), xs.max(), ys.max(), L.mean(), np.median(L), np.percentile(L, 95),
        hsv[:, 1].mean(), hsv[:, 2].mean()))
