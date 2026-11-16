#!/usr/bin/env python3
"""paint.py IMG... – luminance and colour of the player car's paint beside its number plate (the plate = the bright
low-saturation blob in the lower middle of the picture); prints mean RGB (0..255) and Rec.709 luminance."""
import sys
import numpy as np
from PIL import Image
for f in sys.argv[1:]:
    img = np.asarray(Image.open(f).convert('RGB')).astype(np.float64)
    h, w, _ = img.shape
    y0, y1, x0, x1 = int(h * 0.72), int(h * 0.97), int(w * 0.38), int(w * 0.62)
    reg = img[y0:y1, x0:x1]
    mx = reg.max(axis=2); mn = reg.min(axis=2)
    mask = (mx > 190) & (mx - mn < 40)
    ys, xs = np.nonzero(mask)
    if len(ys) < 20:
        print(f"{f}: kein Kennzeichen gefunden"); continue
    # the plate: rows/cols with most plate pixels
    py0, py1 = np.percentile(ys, 10), np.percentile(ys, 90)
    px0, px1 = np.percentile(xs, 10), np.percentile(xs, 90)
    py0, py1, px0, px1 = int(py0) + y0, int(py1) + y0, int(px0) + x0, int(px1) + x0
    pw = px1 - px0
    left = img[py0:py1 + 1, max(px0 - int(pw * 0.9), 0):px0 - int(pw * 0.25)]
    right = img[py0:py1 + 1, px1 + int(pw * 0.25):px1 + int(pw * 0.9)]
    s = np.concatenate([left.reshape(-1, 3), right.reshape(-1, 3)])
    med = np.median(s, axis=0)
    lum = (0.2126 * med[0] + 0.7152 * med[1] + 0.0722 * med[2]) / 255.0
    print(f"{f}: Kennzeichen x {px0}-{px1} y {py0}-{py1}; Lack daneben RGB {med.round(0)} Leuchtdichte {lum:.3f}")
