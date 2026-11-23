#!/usr/bin/env python3
# red.py <png> [x0 y0 x1 y1]: red aviation-light pixels (r >= 110, r > 1.8 g, r > 1.8 b) in the box (default sky)
import sys
import numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(int)
x0, y0, x1, y1 = map(int, sys.argv[2:6]) if len(sys.argv) > 2 else (0, 150, a.shape[1], 400)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
m = (r >= 110) & (r > 1.8 * g) & (r > 1.8 * b)
box = np.zeros_like(m); box[y0:y1, x0:x1] = True
m &= box
ys, xs = np.nonzero(m)
print(sys.argv[1].split('/')[-1], 'rote px', int(m.sum()), 'bbox', (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())) if len(xs) else None)
