"""Does the dark-end deficit of Modern equal an 8-bit linear framebuffer? Arcade's value a (display) through
q(a) = encode(Q(decode(a) * 255) / 255) with Q = round or floor, compared with Modern's measured mean per bin."""
import os, sys
from PIL import Image
import numpy as np

D = sys.argv[1]


def load(n):
    return np.asarray(Image.open(os.path.join(D, 'standin_%s.png' % n)).convert('RGB')).astype(np.float64)


def dec(d):   # display (0..1) -> linear, the sRGB curve without toe (as Godot's show/unshow)
    return np.where(d > 0, ((d + 0.055) / 1.055) ** 2.4, 0.0)


def enc(x):
    return np.maximum(1.055 * np.power(np.maximum(x, 0.0), 1 / 2.4) - 0.055, 0.0)


def dec_exact(d):
    return np.where(d <= 0.04045, d / 12.92, ((d + 0.055) / 1.055) ** 2.4)


def enc_exact(x):
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(np.maximum(x, 1e-12), 1 / 2.4) - 0.055)


ad = load('nacht_12_spieler_arcade')
al = load('nacht_12_leer_arcade')
mask = np.abs(ad - al).sum(axis=2) > 45
m = mask.copy()
for dy in range(-3, 4):
    for dx in range(-3, 4):
        m &= np.roll(np.roll(mask, dy, 0), dx, 1)
ys, xs = np.nonzero(mask)
y0, y1 = ys.min(), ys.max()
m[int(y0 + (y1 - y0) * 0.45):, :] = False
for hour in (12, 22):
    a = load('nacht_%d_spieler_arcade' % hour)[m] / 255.0
    b = load('nacht_%d_spieler_modern' % hour)[m]
    qr = enc(np.round(dec(a) * 255.0) / 255.0) * 255.0
    qf = enc(np.floor(dec(a) * 255.0) / 255.0) * 255.0
    qre = enc_exact(np.round(dec_exact(a) * 255.0) / 255.0) * 255.0
    print('--- %d Uhr: bin  arcade  modern  q_round  q_floor  q_round_exact' % hour)
    a255 = a * 255.0
    for lo in range(0, 96, 8):
        sel = (a255 >= lo) & (a255 < lo + 8)
        if sel.sum() >= 20:
            print('  %3d..%3d  %6.1f  %6.1f  %6.1f  %6.1f  %6.1f' % (lo, lo + 7, a255[sel].mean(), b[sel].mean(), qr[sel].mean(), qf[sel].mean(), qre[sel].mean()))
    # whole-region means
    print('  mean: arcade %.2f modern %.2f q_round %.2f q_floor %.2f' % (a255.mean(), b.mean(), qr.mean(), qf.mean()))
