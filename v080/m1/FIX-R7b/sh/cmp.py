#!/usr/bin/env python3
# cmp.py <a.png> <b.png> [x0 y0 x1 y1]: pixel difference and luminance of a box
import sys
import numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(int)
b = np.asarray(Image.open(sys.argv[2]).convert('RGB')).astype(int)
d = np.abs(a - b).max(axis=2)
print('diff px', int((d > 0).sum()), 'max', int(d.max()))
if len(sys.argv) > 3:
    x0, y0, x1, y1 = map(int, sys.argv[3:7])
    for n, im in [('a', a), ('b', b)]:
        box = im[y0:y1, x0:x1]
        L = 0.299 * box[..., 0] + 0.587 * box[..., 1] + 0.114 * box[..., 2]
        print(n, 'mean L %.1f p90 %.1f' % (L.mean(), np.percentile(L, 90)))
