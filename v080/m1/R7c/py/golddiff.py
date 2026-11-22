#!/usr/bin/env python3
"""R7c: Modern golden frames of the base (RINT-M2 keep) against mine: share of changed pixels, mean luma, and a sheet
(rows: frame; columns: base | R7c | difference x4).  golddiff.py <base_dir> <mine_dir> <out.jpg>"""
import os
import sys

import numpy as np
from PIL import Image

base, mine, out = sys.argv[1:4]
names = ["modern_start_mittel_00.png", "modern_s2_mittel_00.png", "modern_s3_hoch_00.png", "modern_s4_mittel_00.png",
         "modern_s5_niedrig_00.png", "modern_s1_nacht_00.png"]
rows = []
for n in names:
    a = np.asarray(Image.open(os.path.join(base, n)).convert("RGB")).astype(np.int16)
    b = np.asarray(Image.open(os.path.join(mine, n)).convert("RGB")).astype(np.int16)
    d = np.abs(a - b).max(axis=2)
    la = (0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]).mean()
    lb = (0.2126 * b[..., 0] + 0.7152 * b[..., 1] + 0.0722 * b[..., 2]).mean()
    print("%-28s geändert >8: %5.2f %%  >40: %5.2f %%  Luma %.1f -> %.1f" % (n, 100 * (d > 8).mean(), 100 * (d > 40).mean(), la, lb))
    dif = np.clip(np.abs(a - b) * 4, 0, 255).astype(np.uint8)
    row = np.concatenate([a.astype(np.uint8), b.astype(np.uint8), dif], axis=1)
    rows.append(Image.fromarray(row).resize((1920, 360)))
sheet = Image.new("RGB", (1920, 360 * len(rows)))
for i, r in enumerate(rows):
    sheet.paste(r, (0, 360 * i))
sheet.save(out, quality=85)
