#!/usr/bin/env python3
"""W6 scratch: contact sheets of the landmark A/B runs. sheet_ab.py <ab_dir> <out_prefix> <tag> [<tag> ...]
One row per run: arcade 00 | modern 00 | arcade 01 | modern 01 (480x270 each), 4 rows per sheet."""
import os, sys
from PIL import Image, ImageDraw
ab, out, tags = sys.argv[1], sys.argv[2], sys.argv[3:]
W, H = 480, 270
for s in range(0, len(tags), 4):
    rows = tags[s:s + 4]
    sheet = Image.new("RGB", (4 * W, len(rows) * H), (20, 20, 30))
    d = ImageDraw.Draw(sheet)
    for r, t in enumerate(rows):
        for c, (kind, n) in enumerate((("arcade", 0), ("modern", 0), ("arcade", 1), ("modern", 1))):
            p = os.path.join(ab, "%s_%s_%02d.png" % (t, kind, n))
            if os.path.isfile(p):
                sheet.paste(Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS), (c * W, r * H))
            d.rectangle((c * W, r * H, c * W + 300, r * H + 16), fill=(0, 0, 0))
            d.text((c * W + 4, r * H + 2), "%s %s %d" % (t, kind, n), fill=(255, 255, 0))
    sheet.save("%s_%d.jpg" % (out, s // 4), quality=88)
    print("%s_%d.jpg" % (out, s // 4), rows)
