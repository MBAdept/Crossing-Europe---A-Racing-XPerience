"""bldlum.py <sheet> <tw>x<th> <label>:r,c ... : luma percentiles (5/25/50/75) and mean of the building pixels of a
tile (sky = blue dominant, grass = green dominant, road grey-blue band and the caption strip excluded)."""
import sys
import numpy as np
from PIL import Image
im = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float32)
tw, th = map(int, sys.argv[2].split("x"))
for spec in sys.argv[3:]:
    lab, rc = spec.split(":")
    r, c = map(int, rc.split(","))
    t = im[r * th:(r + 1) * th - 22, c * tw:(c + 1) * tw]
    R, G, B = t[..., 0], t[..., 1], t[..., 2]
    sky = (B > R + 25) & (B > G + 5)
    grass = (G > R + 12) & (G > B + 8)
    road = (abs(R - G) < 8) & (B > R + 4) & (R < 80) & (B < 110)
    m = ~(sky | grass | road)
    y = 0.2126 * R + 0.7152 * G + 0.0722 * B
    v = y[m]
    if v.size < 50:
        print(lab, "zu wenig Pixel"); continue
    p = np.percentile(v, [5, 25, 50, 75])
    print("%-34s n=%6d  p5 %5.1f  p25 %5.1f  p50 %5.1f  p75 %5.1f  mean %5.1f" % (lab, v.size, p[0], p[1], p[2], p[3], v.mean()))
