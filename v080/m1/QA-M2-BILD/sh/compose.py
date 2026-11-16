#!/usr/bin/env python3
"""QA-M2-BILD: labelled grid of pictures.
usage: compose.py <out.jpg> <scale> <cols> <label=path> [<label=path> ...]
A path "-" leaves the cell empty. scale e.g. 0.5. Missing files are drawn as a grey cell with the label."""
import sys

from PIL import Image, ImageDraw, ImageFont

out = sys.argv[1]
scale = float(sys.argv[2])
cols = int(sys.argv[3])
cells = []
for a in sys.argv[4:]:
    lab, _, p = a.partition("=")
    cells.append((lab, p))
imgs = []
w0 = h0 = 0
for lab, p in cells:
    im = None
    if p and p != "-":
        try:
            im = Image.open(p).convert("RGB")
        except Exception:  # noqa
            im = None
    if im is not None:
        im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
        w0 = max(w0, im.width)
        h0 = max(h0, im.height)
    imgs.append((lab, im))
if w0 == 0:
    w0, h0 = int(1280 * scale), int(720 * scale)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
except Exception:  # noqa
    font = ImageFont.load_default()
bar = 26
rows = (len(imgs) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w0 + (cols - 1) * 4, rows * (h0 + bar) + (rows - 1) * 4), (16, 24, 44))
d = ImageDraw.Draw(sheet)
for i, (lab, im) in enumerate(imgs):
    cx = (i % cols) * (w0 + 4)
    cy = (i // cols) * (h0 + bar + 4)
    d.text((cx + 6, cy + 3), lab, fill=(235, 240, 250), font=font)
    if im is None:
        d.rectangle([cx, cy + bar, cx + w0 - 1, cy + bar + h0 - 1], fill=(70, 70, 70))
    else:
        sheet.paste(im, (cx, cy + bar))
sheet.save(out, quality=88)
print(out)
