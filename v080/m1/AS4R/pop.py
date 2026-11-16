"""AS4 scratch: level pop at the switch distance, measured on a prop_scene "lods" picture (tiles lod0@60 | lod1@60 |
lod1@200 | impostor@200, same crop and zoom per row): mean absolute difference of the RGB values (0-255) over the
tile and over the pixels that change at all, share of pixels that change by more than 24, per model row.
   python3 pop.py <stufen.png> <stufen.log> [--tile=360x300]"""
import re
import sys

import numpy as np
from PIL import Image

SRC, LOG = sys.argv[1:3]
args = dict(a[2:].split("=", 1) for a in sys.argv[3:] if a.startswith("--") and "=" in a)
tw, th = (int(v) for v in args.get("tile", "360x300").split("x"))
models = []
for line in open(LOG):
    m = re.match(r"STUFEN (\S+)\s+(.*)", line)
    if m:
        models.append((m.group(1), m.group(2)))
img = np.asarray(Image.open(SRC).convert("RGB"), dtype=np.float64)
for ri, (mid, rest) in enumerate(models):
    a = img[ri * th:(ri + 1) * th - 26, 0:tw]
    b = img[ri * th:(ri + 1) * th - 26, tw:2 * tw]
    d = np.abs(a - b).mean(axis=2)
    if "lod1 fehlt" in rest:
        print("POP %-26s nur eine Stufe" % mid)
        continue
    ch = d > 2.0
    print("POP %-26s lod0->lod1 @60 m: mittlere Abweichung %.2f / 255 im Bild, %.1f in %d geänderten Pixeln, "
          "%.2f %% der Pixel > 24" % (mid, d.mean(), d[ch].mean() if ch.any() else 0.0, int(ch.sum()),
                                     100.0 * float((d > 24).mean())))
