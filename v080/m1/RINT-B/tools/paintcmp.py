#!/usr/bin/env python3
"""Paint of a car in an A/B pair: hue / saturation / value of the paint pixels inside a box.
Paint pixels: saturation >= smin and value >= vmin, hue within +-win deg of the dominant hue of the ARCADE picture
(lamps and glass are left out by that window). Prints both and the differences (value relative, hue in degrees).
usage: paintcmp.py x0,y0,x1,y1 arcade.png modern.png [win=28] [smin=0.25] [vmin=0.12]"""
import colorsys
import sys

import numpy as np
from PIL import Image


def hsv(img, box):
    x0, y0, x1, y1 = box
    a = img[y0:y1, x0:x1].reshape(-1, 3) / 255.0
    mx = a.max(axis=1)
    mn = a.min(axis=1)
    d = mx - mn
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    r, g, b = a[:, 0], a[:, 1], a[:, 2]
    h = np.zeros(len(a))
    m = d > 1e-6
    rc = np.where(m, (mx - r) / np.maximum(d, 1e-6), 0)
    gc = np.where(m, (mx - g) / np.maximum(d, 1e-6), 0)
    bc = np.where(m, (mx - b) / np.maximum(d, 1e-6), 0)
    h = np.where(r == mx, bc - gc, np.where(g == mx, 2.0 + rc - bc, 4.0 + gc - rc))
    h = (h / 6.0) % 1.0 * 360.0
    return h, s, mx, a


box = tuple(int(v) for v in sys.argv[1].split(","))
A = np.asarray(Image.open(sys.argv[2]).convert("RGB")).astype(np.float64)
B = np.asarray(Image.open(sys.argv[3]).convert("RGB")).astype(np.float64)
win = float(sys.argv[4]) if len(sys.argv) > 4 else 28.0
smin = float(sys.argv[5]) if len(sys.argv) > 5 else 0.25
vmin = float(sys.argv[6]) if len(sys.argv) > 6 else 0.12
ha, sa, va, ca = hsv(A, box)
sel = (sa >= smin) & (va >= vmin)
if sel.sum() < 20:
    print("zu wenige Lackpixel in Arcade")
    sys.exit(1)
hist, edges = np.histogram(ha[sel], bins=72, range=(0, 360))
dom = (edges[hist.argmax()] + 2.5)
if len(sys.argv) > 7:
    dom = float(sys.argv[7])           # hue of the paint given by hand


def stats(h, s, v, c, label):
    dh = (h - dom + 180.0) % 360.0 - 180.0
    m = (s >= smin) & (v >= vmin) & (np.abs(dh) <= win)
    n = int(m.sum())
    if n == 0:
        print("%-7s keine Lackpixel" % label)
        return None
    mean_c = c[m].mean(axis=0)
    hh, ss, vv = colorsys.rgb_to_hsv(*mean_c)
    clip = float((c[m].max(axis=1) >= 0.995).mean())
    print("%-7s n=%5d  mittlere Farbe %3.0f/%3.0f/%3.0f  Farbton %5.1f°  Sättigung %.2f  Helligkeit %.3f  am Anschlag %4.1f %%" % (
        label, n, mean_c[0] * 255, mean_c[1] * 255, mean_c[2] * 255, hh * 360.0, ss, vv, clip * 100))
    return hh * 360.0, ss, vv


hb, sb, vb, cb = hsv(B, box)
ra = stats(ha, sa, va, ca, "Arcade")
rb = stats(hb, sb, vb, cb, "Modern")
if ra and rb:
    dh = (rb[0] - ra[0] + 180.0) % 360.0 - 180.0
    print("Differenz: Farbton %+5.1f°  Sättigung %+.2f  Helligkeit %+5.1f %%" % (dh, rb[1] - ra[1], (rb[2] / ra[2] - 1.0) * 100))
