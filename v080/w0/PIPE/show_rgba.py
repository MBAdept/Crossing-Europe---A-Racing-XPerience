"""Composites RGBA images on a neutral background side by side: show_rgba.py out.png in1 in2 ... [--scale N]"""
import sys

from PIL import Image

args = [a for a in sys.argv[1:] if not a.startswith("--")]
scale = 1
for a in sys.argv[1:]:
    if a.startswith("--scale="):
        scale = int(a[8:])
out = args[0]
ims = [Image.open(p).convert("RGBA") for p in args[1:]]
if scale != 1:
    ims = [im.resize((im.width * scale, im.height * scale), Image.NEAREST) for im in ims]
W = sum(im.width for im in ims) + 10 * (len(ims) + 1)
H = max(im.height for im in ims) + 20
sheet = Image.new("RGBA", (W, H), (110, 150, 210, 255))
x = 10
for im in ims:
    sheet.alpha_composite(im, (x, 10))
    x += im.width + 10
sheet.convert("RGB").save(out)
print(out, sheet.size)
