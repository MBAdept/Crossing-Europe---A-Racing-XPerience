"""NACH-WASSER measurements on PNG screenshots.

usage:
  measure.py region <png> [x0 x1 y0 y1]      mean luminance (0..255) and share of pixels > 200 in the region
                                             (default: FIX-WASSER-R's pylon region x 500-780, y 150-350)
  measure.py diff <png_a> <png_b>            number of differing pixels, max channel difference, PSNR
"""
import sys
import numpy as np
from PIL import Image


def lum(img):
    a = np.asarray(img.convert("RGB"), dtype=np.float64)
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def region(path, x0=500, x1=780, y0=150, y1=350):
    y = lum(Image.open(path))[y0:y1, x0:x1]
    return y.mean(), float((y > 200).mean())


def diff(pa, pb):
    a = np.asarray(Image.open(pa).convert("RGB"), dtype=np.int32)
    b = np.asarray(Image.open(pb).convert("RGB"), dtype=np.int32)
    if a.shape != b.shape:
        return None
    d = np.abs(a - b)
    n = int((d.max(axis=2) > 0).sum())
    mse = float((d.astype(np.float64) ** 2).mean())
    psnr = float("inf") if mse == 0 else 10.0 * np.log10(255.0 ** 2 / mse)
    return n, int(d.max()), psnr, a.shape[0] * a.shape[1]


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "region":
        args = [int(v) for v in sys.argv[3:7]] if len(sys.argv) >= 7 else []
        for p in [sys.argv[2]]:
            m, s = region(p, *args)
            print("%s  mean %.1f  >200: %.1f %%" % (p.split("/")[-1], m, 100.0 * s))
    elif cmd == "diff":
        r = diff(sys.argv[2], sys.argv[3])
        if r is None:
            print("size differs")
        else:
            n, mx, psnr, tot = r
            print("%s vs %s: %d of %d pixels differ (%.3f %%), max %d/255, PSNR %s" % (
                sys.argv[2].split("/")[-1], sys.argv[3].split("/")[-1], n, tot, 100.0 * n / tot, mx,
                "inf" if psnr == float("inf") else "%.1f dB" % psnr))
