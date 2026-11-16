#!/usr/bin/env python3
"""Side-by-side A/B MP4 from two Movie-Maker AVIs (60 fps): trims each to its first race frame (the first frame that is
not the dark loading screen), stacks Arcade | Modern at 960x540 each, labels them.
usage: abclip.py <arcade.avi> <modern.avi> <out.mp4> [seconds]"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

a_avi, m_avi, out = sys.argv[1:4]
secs = float(sys.argv[4]) if len(sys.argv) > 4 else 10.0
FPS = 60


def first_race(avi):
    tmp = tempfile.mkdtemp(dir=os.path.dirname(os.path.abspath(out)))
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", avi, "-frames:v", "240", "-vf", "scale=160:90",
                    os.path.join(tmp, "%04d.png")], check=True)
    idx = 0
    files = sorted(os.listdir(tmp))
    for i, f in enumerate(files):
        im = np.asarray(Image.open(os.path.join(tmp, f)).convert("L")).astype(float)
        if im.mean() > 60.0:      # the loading screen is dark navy (mean ~ 15-25)
            idx = i
            break
    for f in files:
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)
    return idx


ia = int(os.environ["A_OFF"]) if "A_OFF" in os.environ else first_race(a_avi)
im = int(os.environ["M_OFF"]) if "M_OFF" in os.environ else first_race(m_avi)
print("first race frame: arcade %d, modern %d" % (ia, im))
font = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
lab = "drawtext=fontfile=%s:text='%s':x=(w-tw)/2:y=8:fontsize=30:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=8"
filt = ("[0:v]trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS,scale=960:540,%s[a];"
        "[1:v]trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS,scale=960:540,%s[m];[a][m]hstack=inputs=2[v]") % (
    ia, ia + int(secs * FPS), lab % (font, "Arcade"), im, im + int(secs * FPS), lab % (font, "Modern"))
subprocess.run(["nice", "-n", "10", "ffmpeg", "-v", "error", "-y", "-threads", "2", "-i", a_avi, "-i", m_avi,
                "-filter_complex", filt, "-map", "[v]", "-r", str(FPS), "-c:v", "libx264", "-preset", "veryfast",
                "-crf", "23", "-pix_fmt", "yuv420p", "-threads", "2", out], check=True)
print(out)
