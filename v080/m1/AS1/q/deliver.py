"""Copies the evidence pictures as JPG into the deliver folder: deliver.py <ev dir> <deliver dir>"""
import glob
import os
import sys

from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
total = 0
for f in sorted(glob.glob(os.path.join(src, "[0-9][0-9]_*.png"))):
    im = Image.open(f).convert("RGB")
    out = os.path.join(dst, os.path.basename(f)[:-4] + ".jpg")
    im.save(out, quality=90, optimize=True)
    total += os.path.getsize(out)
    print("%-34s %5d x %5d  %5d kB" % (os.path.basename(out), im.size[0], im.size[1], os.path.getsize(out) // 1024))
print("total %.1f MB" % (total / 1e6))
