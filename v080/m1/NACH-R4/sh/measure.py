#!/usr/bin/env python3
"""measure.py cone|red|car <png...> – the numbers of QA-R4's B1/B2/B3 on a picture.
cone : median luminance (PIL 'L', 0-255) in x 560-720 / y 380-440, and per row 368-376 the brightest pixel in
       x 420-860 against the median of x 560-720 (Weber contrast, median of the rows)
red  : red-shifted pixels (R > 70, R > 1.5 G, R > 1.5 B) in box x0,y0,x1,y1 (env BOX, default 560,0,720,330)
car  : player car rear x 520-800 / y 520-720: p75 luminance, median HSV saturation of pixels with L > 12
"""
import os
import sys

import numpy as np
from PIL import Image


def lum(path):
    return np.asarray(Image.open(path).convert("L"), dtype=np.float32)


def cone(path):
    L = lum(path)
    med = float(np.median(L[380:441, 560:721]))
    webers = []
    for y in range(368, 377):
        line = float(L[y, 420:861].max())
        asph = float(np.median(L[y, 560:721]))
        webers.append((line - asph) / max(asph, 1.0))
    return "cone_median=%.1f weber_rows=%.2f" % (med, float(np.median(webers)))


def red(path):
    box = [int(v) for v in os.environ.get("BOX", "560,0,720,330").split(",")]
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    x0, y0, x1, y1 = box
    c = a[y0:y1, x0:x1]
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    k = float(os.environ.get("RK", "1.5")); m = (r > float(os.environ.get("RMIN", "70"))) & (r > k * g) & (r > k * b)
    ys = np.nonzero(m.any(axis=1))[0]
    top = int(ys.min()) + y0 if ys.size else -1
    return "red_px=%d topmost_red_row=%d box=%s" % (int(m.sum()), top, box)


def car(path):
    img = Image.open(path).convert("RGB")
    a = np.asarray(img, dtype=np.float32)[520:721, 520:801]
    L = np.asarray(img.convert("L"), dtype=np.float32)[520:721, 520:801]
    hsv = np.asarray(img.convert("HSV"), dtype=np.float32)[520:721, 520:801]
    m = L > 12
    return "car_p75=%.1f sat_median=%.3f n=%d" % (float(np.percentile(L[m], 75)), float(np.median(hsv[..., 1][m]) / 255.0), int(m.sum()))


if __name__ == "__main__":
    fn = {"cone": cone, "red": red, "car": car}[sys.argv[1]]
    for p in sys.argv[2:]:
        print("%-70s %s" % (os.path.basename(p), fn(p)))
