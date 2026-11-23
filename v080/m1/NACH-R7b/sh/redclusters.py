#!/usr/bin/env python3
# redclusters.py <png> [x0 y0 x1 y1]: connected clusters of red aviation-light pixels (QA-R7b measure), largest first
import sys
import numpy as np
from PIL import Image

a = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(float)
x0, y0, x1, y1 = map(int, sys.argv[2:6]) if len(sys.argv) > 5 else (0, 0, a.shape[1], a.shape[0])
r, g, b = a[..., 0], a[..., 1], a[..., 2]
m = (r >= 110) & (r > 1.8 * g) & (r > 1.8 * b)
box = np.zeros_like(m)
box[y0:y1, x0:x1] = True
m &= box
seen = np.zeros_like(m)
out = []
H, W = m.shape
for y, x in zip(*np.nonzero(m)):
    if seen[y, x]:
        continue
    st = [(y, x)]
    seen[y, x] = True
    px = []
    while st:
        cy, cx = st.pop()
        px.append((cy, cx))
        for dy in (-2, -1, 0, 1, 2):
            for dx in (-2, -1, 0, 1, 2):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < H and 0 <= nx < W and m[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    st.append((ny, nx))
    ys = [p[0] for p in px]
    xs = [p[1] for p in px]
    out.append((len(px), min(xs), min(ys), max(xs), max(ys)))
out.sort(reverse=True)
print(sys.argv[1].split("/")[-1], "Summe", int(m.sum()))
for n, xa, ya, xb, yb in out[:8]:
    print(f"  {n:4d} px  x {xa}..{xb}  y {ya}..{yb}  ({xb - xa + 1} x {yb - ya + 1})")
