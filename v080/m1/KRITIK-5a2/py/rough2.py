"""rough2.py <dir> <box x0,y0,x1,y1> [<box> ...]: temporal roughness of frame sequence f_NNN.png inside boxes:
mean |I(t+1) - 2 I(t) + I(t-1)| (luma) and share of pixels with |2nd diff| > 24 (flicker pixels)."""
import sys, glob, os
import numpy as np
from PIL import Image
d = sys.argv[1]
files = sorted(glob.glob(os.path.join(d, "f_*.png")))
L = [np.asarray(Image.open(f).convert("L"), dtype=np.float32) for f in files]
for b in sys.argv[2:]:
    x0, y0, x1, y1 = map(int, b.split(","))
    r, s = [], []
    for i in range(1, len(L) - 1):
        sd = np.abs(L[i + 1][y0:y1, x0:x1] - 2 * L[i][y0:y1, x0:x1] + L[i - 1][y0:y1, x0:x1])
        r.append(sd.mean()); s.append((sd > 24).mean())
    print("ROUGH %s box %s frames %d  mean %.2f  p95 %.2f  flicker-px %.2f %%" % (os.path.basename(d.rstrip('/')), b, len(L), np.mean(r), np.percentile(r, 95), 100 * np.mean(s)))
