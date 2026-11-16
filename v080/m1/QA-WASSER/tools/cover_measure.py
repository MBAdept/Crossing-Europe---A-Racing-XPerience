#!/usr/bin/env python3
"""Shares of the debug colours of --gfx-debug=cover,far in a Modern frame (QA-WASSER).

usage: cover_measure.py <frame.png>...
magenta (canvas shows through: a hole), cyan (far-ground plane), yellow (rim). The horizon row is taken as the last
row from the top in which more than half of the pixels are magenta (above it the canvas is the sky); the shares are
of the pixels below it, without the HUD boxes (all pixels are counted; the HUD is drawn opaque in its boxes).
"""
import sys

import numpy as np
from PIL import Image

for f in sys.argv[1:]:
    a = np.asarray(Image.open(f).convert("RGB")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = (r > 200) & (g < 60) & (b > 200)
    cyan = (r < 60) & (g > 200) & (b > 200)
    yel = (r > 200) & (g > 200) & (b < 60)
    h = a.shape[0]
    share = mag.mean(axis=1)
    rows = np.nonzero(share > 0.5)[0]
    hz = int(rows.max()) + 1 if len(rows) else 0
    below = slice(hz, h)
    n = mag[below].size
    yc = np.nonzero(cyan[below].any(axis=1) | yel[below].any(axis=1))[0]
    print("%-36s horizon row %3d | below: magenta %.3f %% (%d px), cyan %.2f %%, yellow %.2f %%, cyan/yellow rows %s" % (
        f.split("/")[-1], hz, 100.0 * mag[below].mean(), int(mag[below].sum()), 100.0 * cyan[below].mean(),
        100.0 * yel[below].mean(), ("%d-%d" % (yc.min() + hz, yc.max() + hz)) if len(yc) else "-"))
