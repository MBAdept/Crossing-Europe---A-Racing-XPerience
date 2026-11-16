"""AS2R: sheet of a probe (jobs_probe.py): both levels at 1x (magnified), their difference, supersampled, clay,
and the silhouette difference.  usage: probe_sheet.py <tile dir> <tag> <dist> <lodA> <lodB> <out.jpg>"""
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K

d, tag, dist, a, b, out = sys.argv[1], sys.argv[2], int(float(sys.argv[3])), sys.argv[4], sys.argv[5], sys.argv[6]


def im(n):
    return Image.open(f"{d}/{n}.png").convert("RGB")


bg = np.asarray(im("empty_day")).astype(int)
A = np.asarray(im(f"{tag}_{dist}_{a}")).astype(int)
B = np.asarray(im(f"{tag}_{dist}_{b}")).astype(int)
car = (np.abs(A - bg).max(axis=2) > 10) | (np.abs(B - bg).max(axis=2) > 10)
dm = np.abs(A - B).max(axis=2)
n = int(car.sum())
ch = int(((dm > 24) & car).sum())
ys, xs = np.nonzero(car)
x0, y0, x1, y1 = xs.min() - 3, ys.min() - 3, xs.max() + 4, ys.max() + 4
k = max(2, int(360 / (y1 - y0)))
print(f"{tag} {dist} m {a}->{b}: {n} car px, {ch} changed = {100.0 * ch / max(n, 1):.1f} %  box {x1 - x0}x{y1 - y0}")


def crop1(arr):
    return Image.fromarray(arr.astype(np.uint8)).crop((x0, y0, x1, y1)).resize(((x1 - x0) * k, (y1 - y0) * k), Image.NEAREST)


diff = np.where(dm > 24, 255, (dm * 4).clip(0, 120))
diff = np.stack([diff] * 3, axis=2)
tiles = [K.caption(crop1(A), f"{a} 1x", 12), K.caption(crop1(B), f"{b} 1x", 12),
         K.caption(crop1(diff), f"Differenz {100.0 * ch / max(n, 1):.1f} %", 12)]
# supersampled 4x: same region * 4
s = 4
box4 = (x0 * s, y0 * s, x1 * s, y1 * s)
size = tiles[0].size
for kind in ("ss4", "clay_ss4"):
    ia = im(f"{tag}_{dist}_{a}_{kind}").crop(box4).resize(size, Image.LANCZOS)
    ib = im(f"{tag}_{dist}_{b}_{kind}").crop(box4).resize(size, Image.LANCZOS)
    da = np.abs(np.asarray(ia).astype(int) - np.asarray(ib).astype(int)).max(axis=2)
    dd = Image.fromarray(np.where(da > 24, 255, (da * 4).clip(0, 120)).astype(np.uint8)).convert("RGB")
    tiles += [K.caption(ia, f"{a} {kind}", 12), K.caption(ib, f"{b} {kind}", 12), K.caption(dd, "Differenz", 12)]
_ma = np.asarray(im(f"{tag}_{dist}_{a}_mask_ss4").crop(box4)).astype(int)
ma = (_ma[:, :, 0] > 150) & (_ma[:, :, 1] < 90) & (_ma[:, :, 2] < 90)
_mb = np.asarray(im(f"{tag}_{dist}_{b}_mask_ss4").crop(box4)).astype(int)
mb = (_mb[:, :, 0] > 150) & (_mb[:, :, 1] < 90) & (_mb[:, :, 2] < 90)
sil = np.zeros(ma.shape + (3,), np.uint8)
sil[ma & mb] = (150, 150, 150)
sil[ma & ~mb] = (230, 40, 40)
sil[~ma & mb] = (40, 90, 240)
print(f"silhouette ss4: only {a} {int((ma & ~mb).sum())} px, only {b} {int((~ma & mb).sum())} px, both {int((ma & mb).sum())}")
tiles.append(K.caption(Image.fromarray(sil).resize(size, Image.NEAREST), f"Umriss: rot nur {a}, blau nur {b}", 12))
sheet = K.grid(tiles, 3)
sheet = K.title(sheet, f"{tag} {dist} m: {a} -> {b}", 18)
K.save_jpg(sheet, out, 90)
print(out)
