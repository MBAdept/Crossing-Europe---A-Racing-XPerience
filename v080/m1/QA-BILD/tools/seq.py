#!/usr/bin/env python3
"""Consecutive frames of a clip as a zoomed montage (rows of frames), for shimmer / pop inspection.
usage: seq.py <video> <out.png> <start_frame> <count> <x0> <y0> <x1> <y1> <scale> [cols] [step]"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

video, out = sys.argv[1], sys.argv[2]
start, count = int(sys.argv[3]), int(sys.argv[4])
x0, y0, x1, y1 = (int(v) for v in sys.argv[5:9])
scale = float(sys.argv[9])
cols = int(sys.argv[10]) if len(sys.argv) > 10 else 4
step = int(sys.argv[11]) if len(sys.argv) > 11 else 1
tmp = tempfile.mkdtemp(dir=os.path.dirname(os.path.abspath(out)))
sel = "+".join("eq(n\\,%d)" % (start + i * step) for i in range(count))
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", video, "-vf", "select='%s'" % sel, "-vsync", "0",
                os.path.join(tmp, "f%03d.png")], check=True)
files = sorted(f for f in os.listdir(tmp) if f.endswith(".png"))
w = int((x1 - x0) * scale)
h = int((y1 - y0) * scale)
rows = (len(files) + cols - 1) // cols
canvas = Image.new("RGB", (cols * (w + 4), rows * (h + 20)), (16, 24, 44))
d = ImageDraw.Draw(canvas)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 13)
except Exception:
    font = None
for i, f in enumerate(files):
    im = Image.open(os.path.join(tmp, f)).convert("RGB").crop((x0, y0, x1, y1)).resize((w, h), Image.NEAREST)
    cx = (i % cols) * (w + 4)
    cy = (i // cols) * (h + 20)
    canvas.paste(im, (cx, cy + 20))
    d.text((cx + 3, cy + 3), "frame %d" % (start + i * step), fill=(255, 255, 255), font=font)
    os.remove(os.path.join(tmp, f))
os.rmdir(tmp)
canvas.save(out)
print(out, canvas.size, len(files), "frames")
