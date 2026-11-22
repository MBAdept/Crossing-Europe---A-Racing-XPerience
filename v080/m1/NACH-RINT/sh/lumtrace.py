"""lumtrace.py <clip.mp4> <t0> <t1> : per frame between t0 and t1 the mean luminance and the share of near-white pixels
(>= 240) of the scene band (rows 25-80 % of the picture, i.e. below the HUD boxes and above the speedometer) of both
halves of an A/B clip (Arcade left, Modern right)."""
import subprocess, sys
import numpy as np

clip, t0, t1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
W, H = 1280, 380
raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-ss', str(t0), '-t', str(t1 - t0), '-i', clip, '-vf',
                      'scale=%d:%d' % (W, H), '-pix_fmt', 'gray', '-f', 'rawvideo', '-'], capture_output=True, check=True).stdout
n = len(raw) // (W * H)
v = np.frombuffer(raw[:n * W * H], dtype=np.uint8).reshape(n, H, W).astype(np.float32)
y0, y1 = int(H * 0.25), int(H * 0.80)
for i in range(n):
    a = v[i, y0:y1, :W // 2]
    m = v[i, y0:y1, W // 2:]
    print('t=%.3f  arcade lum %5.1f white %.3f | modern lum %5.1f white %.3f' % (
        t0 + i / 60.0, a.mean(), (a >= 240).mean(), m.mean(), (m >= 240).mean()))
