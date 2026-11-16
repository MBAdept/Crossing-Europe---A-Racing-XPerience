#!/usr/bin/env python3
"""Frame-to-frame differences of a picture sequence, whole frame and a horizontal band (QA-WASSER).

usage: seq_diff.py <band_y0> <band_y1> <frame.png>... [--strip out.jpg] [--ref <other prefix frames...>]
Prints per consecutive pair: mean |diff| (0-255) of the whole frame and of the band rows, the share of band pixels
changed by more than 24/255, and the largest band change. With --strip writes the band crops stacked vertically.
"""
import sys

import numpy as np
from PIL import Image

args = sys.argv[1:]
strip = None
if "--strip" in args:
    i = args.index("--strip")
    strip = args[i + 1]
    del args[i:i + 2]
y0, y1 = int(args[0]), int(args[1])
files = args[2:]
imgs = [np.asarray(Image.open(f).convert("RGB")).astype(np.int16) for f in files]
print("frames %d, size %dx%d, band rows %d-%d" % (len(imgs), imgs[0].shape[1], imgs[0].shape[0], y0, y1))
for i in range(1, len(imgs)):
    a, b = imgs[i - 1], imgs[i]
    d = np.abs(a - b).max(axis=2)
    band = d[y0:y1]
    print("%-28s -> %-28s whole %5.2f  band %5.2f  band>24: %5.2f %%  band max %3d" % (
        files[i - 1].split("/")[-1], files[i].split("/")[-1], d.mean(), band.mean(), 100.0 * (band > 24).mean(), band.max()))
if strip:
    crops = [Image.open(f).convert("RGB").crop((0, y0, imgs[0].shape[1], y1)) for f in files]
    w = crops[0].width
    h = sum(c.height + 4 for c in crops)
    out = Image.new("RGB", (w, h), (16, 24, 44))
    y = 0
    for c in crops:
        out.paste(c, (0, y))
        y += c.height + 4
    out.save(strip, quality=90)
    print("strip", strip)
