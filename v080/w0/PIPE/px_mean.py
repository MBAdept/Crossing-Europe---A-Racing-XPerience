"""scratch: mean colour of boxes in a picture. usage: px_mean.py img.png name=x,y,w,h ..."""
import sys

import numpy as np
from PIL import Image

im = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(np.float64)
for a in sys.argv[2:]:
    name, box = a.split("=")
    x, y, w, h = [int(v) for v in box.split(",")]
    c = im[y:y + h, x:x + w].reshape(-1, 3)
    m = c.mean(axis=0)
    # mean in linear light, back to sRGB bytes
    lin = ((c / 255.0) ** 2.2).mean(axis=0)
    print("%-22s mean sRGB %5.1f %5.1f %5.1f   linear mean as sRGB %5.1f %5.1f %5.1f" % (
        name, m[0], m[1], m[2], *(255.0 * lin ** (1 / 2.2))))
