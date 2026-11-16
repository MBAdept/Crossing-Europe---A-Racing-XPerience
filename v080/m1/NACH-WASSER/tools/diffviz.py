"""Old | new | difference mask (red = pixel differs) of two equally sized PNGs, plus the bounding box of the
differences and the share of differing pixels inside given regions.

usage: diffviz.py <old.png> <new.png> <out.jpg> [label_old] [label_new]
"""
import sys
import numpy as np
from PIL import Image, ImageDraw

a_img = Image.open(sys.argv[1]).convert("RGB")
b_img = Image.open(sys.argv[2]).convert("RGB")
out = sys.argv[3]
la = sys.argv[4] if len(sys.argv) > 4 else "alt"
lb = sys.argv[5] if len(sys.argv) > 5 else "neu"
a = np.asarray(a_img, dtype=np.int32)
b = np.asarray(b_img, dtype=np.int32)
m = np.abs(a - b).max(axis=2) > 0
ys, xs = np.nonzero(m)
if len(xs):
    print("differs: %d px, bbox x %d-%d, y %d-%d" % (m.sum(), xs.min(), xs.max(), ys.min(), ys.max()))
    # column histogram in 8 bands: where along x the differences are
    w = a.shape[1]
    bands = [int(m[:, i * w // 8:(i + 1) * w // 8].sum()) for i in range(8)]
    print("per x-band (8):", bands)
    h = a.shape[0]
    rows = [int(m[i * h // 6:(i + 1) * h // 6, :].sum()) for i in range(6)]
    print("per y-band (6):", rows)
else:
    print("identical")
viz = (np.asarray(b_img, dtype=np.float64) * 0.35).astype(np.uint8)
viz[m] = [255, 40, 40]
W = a.shape[1]
canvas = Image.new("RGB", (W * 3 + 12, a.shape[0] + 34), (16, 24, 44))
canvas.paste(a_img, (0, 34))
canvas.paste(b_img, (W + 6, 34))
canvas.paste(Image.fromarray(viz), (2 * W + 12, 34))
d = ImageDraw.Draw(canvas)
d.text((10, 10), la, fill=(255, 255, 255))
d.text((W + 16, 10), lb, fill=(255, 255, 255))
d.text((2 * W + 22, 10), "Unterschied (rot)", fill=(255, 255, 255))
canvas = canvas.resize((canvas.width * 2 // 3, canvas.height * 2 // 3))
canvas.save(out, quality=88)
print(out)
