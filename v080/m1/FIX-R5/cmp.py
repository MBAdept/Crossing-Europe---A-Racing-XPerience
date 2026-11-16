#!/usr/bin/env python3
"""cmp.py <dir_a> <dir_b> <name>...: per picture identical / differing pixels (> 3 levels) and their bounding box."""
import sys, hashlib, os
import numpy as np
from PIL import Image
a_dir, b_dir = sys.argv[1], sys.argv[2]
for name in sys.argv[3:]:
    pa, pb = os.path.join(a_dir, name + '.png'), os.path.join(b_dir, name + '.png')
    if not (os.path.exists(pa) and os.path.exists(pb)):
        print('%-28s fehlt' % name)
        continue
    if hashlib.md5(open(pa, 'rb').read()).hexdigest() == hashlib.md5(open(pb, 'rb').read()).hexdigest():
        print('%-28s identisch' % name)
        continue
    a = np.asarray(Image.open(pa).convert('RGB'), dtype=int)
    b = np.asarray(Image.open(pb).convert('RGB'), dtype=int)
    d = np.abs(a - b).max(axis=2)
    ys, xs = np.nonzero(d > 3)
    bbox = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())) if len(ys) else None
    print('%-28s anders: %d px > 3, max %d, bbox %s' % (name, len(ys), int(d.max()), bbox))
