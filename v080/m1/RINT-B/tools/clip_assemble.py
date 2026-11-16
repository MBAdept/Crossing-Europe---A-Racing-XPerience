#!/usr/bin/env python3
"""Assembles the 20 s A/B clip (RINT-B): finds the first race frame of each Movie-Maker AVI (the first frame that
looks like the race: compared with the last frame of the start sequence of the other mode is not robust, so the first
frame whose top-left HUD region matches the Arcade race HUD), trims both, stacks them side by side with labels and
Modern's sound. usage: clip_assemble.py <dir> [seconds=20]"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image

d = sys.argv[1]
secs = float(sys.argv[2]) if len(sys.argv) > 2 else 20.0
FPS = 30


def frames(avi, n, tag):
    out = os.path.join(d, "f_" + tag)
    os.makedirs(out, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", avi, "-frames:v", str(n), "-vf", "scale=320:180",
                    os.path.join(out, "%04d.png")], check=True)
    return [np.asarray(Image.open(os.path.join(out, f)).convert("L")).astype(np.float64)
            for f in sorted(os.listdir(out))]


fa = frames(os.path.join(d, "arcade.avi"), 240, "arcade")
fm = frames(os.path.join(d, "modern.avi"), 400, "modern")
# HUD box top-left (the clock panel) is drawn identically by both modes once the race shows
hud = (slice(8, 34), slice(4, 66))
ref = fa[min(30, len(fa) - 1)][hud]


def first_race(fr):
    for i, f in enumerate(fr):
        if np.abs(f[hud] - ref).mean() < 6.0:
            return i
    return 0


ia = first_race(fa)
im = first_race(fm)
print("first race frame: arcade %d, modern %d" % (ia, im))
ta = ia / FPS
tm = im / FPS
font = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
label = "drawtext=fontfile=%s:text='%s':x=(w-tw)/2:y=8:fontsize=34:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=8"
filt = ("[0:v]trim=start=%.3f:duration=%.3f,setpts=PTS-STARTPTS,scale=960:540,%s[a];"
        "[1:v]trim=start=%.3f:duration=%.3f,setpts=PTS-STARTPTS,scale=960:540,%s[m];"
        "[a][m]hstack=inputs=2[v];"
        "[1:a]atrim=start=%.3f:duration=%.3f,asetpts=PTS-STARTPTS[au]") % (
    ta, secs, label % (font, "Arcade"), tm, secs, label % (font, "Modern"), tm, secs)
out = os.path.join(d, "kiel_hamburg_start_ab.mp4")
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(d, "arcade.avi"), "-i", os.path.join(d, "modern.avi"),
                "-filter_complex", filt, "-map", "[v]", "-map", "[au]", "-c:v", "libx264", "-preset", "medium",
                "-crf", "23", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", out],
               check=True)
print(out)
