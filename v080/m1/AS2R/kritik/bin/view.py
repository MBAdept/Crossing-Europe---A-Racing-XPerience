"""Quick look: tiles side by side (scratch viewing only).
usage: view.py <batch> <out.png> <width_per_tile> <name>...   game-camera tiles (1280x720 or larger) are cropped to the car."""
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K
from PIL import Image

batch, out, tw = sys.argv[1], sys.argv[2], int(sys.argv[3])
names = sys.argv[4:]
try:
    mt = K.meta(batch)
except Exception:
    mt = {}
ims = []
for n in names:
    if not K.has_tile(n, batch):
        continue
    im = K.tile(n, batch)
    m = mt.get(n, {})
    if m.get("size", [0])[0] >= 1280 and "_g" in n and "rect" in m:
        im, _ = K.crop_rect(im, m["rect"], margin=0.15, aspect=1.6)
    elif im.width >= 1280 and "_g" in n:
        import numpy as np
        a = np.asarray(im).astype(int)
        med = np.median(a, axis=1, keepdims=True)
        mask = (np.abs(a - med).max(axis=2) > 18)
        mask[: int(a.shape[0] * 0.45) + 2] = False
        ys, xs = np.nonzero(mask)
        if len(xs):
            im, _ = K.crop_rect(im, [xs.min(), ys.min(), xs.max(), ys.max()], margin=0.15, aspect=1.6)
    im = im.resize((tw, int(im.height * tw / im.width)), Image.LANCZOS if im.width > tw else Image.NEAREST)
    ims.append(K.caption(im, n, 12))
cols = 4 if len(ims) > 6 else len(ims)
K.grid(ims, max(1, cols)).save(out)
print(out)
