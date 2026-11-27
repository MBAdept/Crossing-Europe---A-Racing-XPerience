#!/usr/bin/env python3
"""W6 scratch: frame-to-frame change of a prop_scene dist sheet whose tiles are consecutive frames.
flicker.py <sheet.png> <tile_w> <tile_h>: per row, the share of pixels (luma, excluding the label strip) that change
by more than 24/255 between neighbouring tiles, and the mean absolute luma change of those."""
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("L"); tw, th = int(sys.argv[2]), int(sys.argv[3])
cols, rows = im.width // tw, im.height // th
for r in range(rows):
    out = []
    for c in range(cols - 1):
        a = im.crop((c * tw, r * th, (c + 1) * tw, r * th + th - 24)).getdata()
        b = im.crop(((c + 1) * tw, r * th, (c + 2) * tw, r * th + th - 24)).getdata()
        d = [abs(x - y) for x, y in zip(a, b)]
        big = [x for x in d if x > 24]
        out.append("%.1f %% (%.0f)" % (100.0 * len(big) / len(d), sum(big) / max(1, len(big))))
    print("row %d: %s" % (r, " | ".join(out)))
