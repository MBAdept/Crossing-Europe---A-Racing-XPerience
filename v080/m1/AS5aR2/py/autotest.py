import sys, time
import numpy as np
from PIL import Image
sys.path.insert(0, sys.argv[0].rsplit("/", 1)[0])
from autotest_src import _gap_alpha_auto
path = sys.argv[1]
px = np.asarray(Image.open(path), dtype=np.float64)
a = px[..., 3] / 255.0
gap = np.abs(a - 102 / 255.0) < 0.01
# mask ~ gaps dilated by 4 texels (bars between gaps)
m = gap.copy()
for _ in range(4):
    mm = m.copy()
    mm[1:] |= m[:-1]; mm[:-1] |= m[1:]; mm[:, 1:] |= m[:, :-1]; mm[:, :-1] |= m[:, 1:]
    m = mm
mask = m & ((a >= 0.5) | gap | (a < 0.5))
mask &= (a > 0.01)
t0 = time.time()
aa = a.copy()
ch = _gap_alpha_auto(aa, mask, gap)
print(path.split("/")[-2], "chosen", ch, "%.1f s" % (time.time() - t0))
im = px.copy(); im[..., 3] = np.round(aa * 255)
Image.fromarray(im.astype(np.uint8), "RGBA").save(sys.argv[2])
