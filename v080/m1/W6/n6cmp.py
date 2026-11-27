#!/usr/bin/env python3
"""N6 scratch: Arcade | Modern before | Modern after for a landmark run, frames 00 and 01 (two rows, 640x360 each)."""
import sys
from PIL import Image
W6, name, out = sys.argv[1], sys.argv[2], sys.argv[3]
rows = []
for n in ("00", "01"):
    ims = [Image.open("%s/ab/%s_%s_%s_%s.png" % (W6, p, name, k, n)).convert("RGB").resize((640, 360), Image.LANCZOS)
           for p, k in (("p", "arcade"), ("p", "modern"), ("n6", "modern"))]
    rows.append(ims)
sheet = Image.new("RGB", (1920, 720))
for r, ims in enumerate(rows):
    for c, im in enumerate(ims):
        sheet.paste(im, (c * 640, r * 360))
sheet.save(out, quality=90)
