"""Pixel-by-pixel transfer of the player's picture (the same cell at the same place in both modes): Modern value as
a function of the Arcade value, per channel, binned - by day and at night. Only pixels of the body (inside the day
mask, away from its edge and from the lamps' rows)."""
import os, sys
from PIL import Image
import numpy as np

D = sys.argv[1]


def load(n):
    return np.asarray(Image.open(os.path.join(D, 'standin_%s.png' % n)).convert('RGB')).astype(np.float64)


ad = load('nacht_12_spieler_arcade')
al = load('nacht_12_leer_arcade')
mask = np.abs(ad - al).sum(axis=2) > 45
# erode the mask by 3 px
m = mask.copy()
for dy in range(-3, 4):
    for dx in range(-3, 4):
        m &= np.roll(np.roll(mask, dy, 0), dx, 1)
ys, xs = np.nonzero(mask)
y0, y1 = ys.min(), ys.max()
# keep the top 45 % of the box (no lamps, no glows)
m[int(y0 + (y1 - y0) * 0.45):, :] = False
print('pixels', m.sum())
for hour in (12, 22):
    a = load('nacht_%d_spieler_arcade' % hour)[m]
    b = load('nacht_%d_spieler_modern' % hour)[m]
    print('--- %d Uhr: Arcade value -> Modern mean (n)' % hour)
    for lo in range(0, 256, 8):
        sel = (a >= lo) & (a < lo + 8)
        if sel.sum() >= 20:
            print('  %3d..%3d  arcade %6.1f  modern %6.1f  diff %+5.1f  (n %d)' % (lo, lo + 7, a[sel].mean(), b[sel].mean(), b[sel].mean() - a[sel].mean(), sel.sum()))
