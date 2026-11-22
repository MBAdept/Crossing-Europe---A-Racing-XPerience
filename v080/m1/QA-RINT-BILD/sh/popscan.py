"""popscan.py <clip.mp4> : frame-to-frame change of both halves of an A/B clip (Arcade left, Modern right) to find pops
(LOD switches, chunk pops, flicker). Decodes at 640x190 grey via ffmpeg, HUD rows cut (top 25 %, bottom 20 %), and
prints per half: median and 99th percentile of the mean absolute difference, and the frames whose difference exceeds
3x the median of the 15 frames around it and is not matched by the other half (a pop of one renderer only)."""
import subprocess, sys
import numpy as np

clip = sys.argv[1]
W, H = 640, 190
raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', clip, '-vf', 'scale=%d:%d' % (W, H), '-pix_fmt', 'gray',
                      '-f', 'rawvideo', '-'], capture_output=True, check=True).stdout
n = len(raw) // (W * H)
v = np.frombuffer(raw[:n * W * H], dtype=np.uint8).reshape(n, H, W).astype(np.float32)
y0, y1 = int(H * 0.25), int(H * 0.80)
halves = {'arcade': v[:, y0:y1, :W // 2], 'modern': v[:, y0:y1, W // 2:]}
d = {k: np.abs(np.diff(a, axis=0)).mean(axis=(1, 2)) for k, a in halves.items()}
fps = 60.0
TH = float(sys.argv[2]) if len(sys.argv) > 2 else 3.0
print('frames', n)
for k in ('arcade', 'modern'):
    x = d[k]
    print('%-7s diff median %.2f p99 %.2f max %.2f at t=%.2f s' % (k, np.median(x), np.percentile(x, 99), x.max(), (x.argmax() + 1) / fps))
for k, o in (('modern', 'arcade'), ('arcade', 'modern')):
    x, y = d[k], d[o]
    hits = []
    for i in range(len(x)):
        lo, hi = max(0, i - 7), min(len(x), i + 8)
        loc = np.median(x[lo:hi])
        if x[i] > TH * max(loc, 0.3) and not (y[i] > TH * max(np.median(y[lo:hi]), 0.3)):
            hits.append((i + 1, x[i], loc))
    print('%s-only spikes: %d' % (k, len(hits)))
    for f, val, loc in hits[:25]:
        print('   frame %4d t=%.2f s diff %.2f (local median %.2f)' % (f, f / fps, val, loc))
