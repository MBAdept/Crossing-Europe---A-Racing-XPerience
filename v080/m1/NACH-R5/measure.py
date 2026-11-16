#!/usr/bin/env python3
"""measure.py <x0,y0,x1,y1> <png>... : mean RGB and luma of the rectangle in each picture; md5 of each picture."""
import sys, hashlib
from PIL import Image
import numpy as np
x0, y0, x1, y1 = [int(v) for v in sys.argv[1].split(',')]
for p in sys.argv[2:]:
    a = np.asarray(Image.open(p).convert('RGB').crop((x0, y0, x1, y1)), dtype=float).reshape(-1, 3)
    m = a.mean(axis=0)
    print("%5.1f,%5.1f,%5.1f  L %5.1f  %s" % (m[0], m[1], m[2], 0.2126 * m[0] + 0.7152 * m[1] + 0.0722 * m[2],
                                             '/'.join(p.split('/')[-2:])))
