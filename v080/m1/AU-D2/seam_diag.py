"""Where do the two passes over the loop start differ? usage: seam_diag.py master.wav f_body loop_frames bar_frames"""
import sys
import numpy as np

path, fb, lf, bar = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4])
raw = np.fromfile(path, dtype="<f4", offset=44)
x = raw.reshape(-1, 2).astype(np.float64)
n = int(3 * bar)
a = x[fb - int(1 * bar):fb + n]
b = x[fb + lf - int(1 * bar):fb + lf + n]
d = np.abs(a - b).max(axis=1)
lvl = np.abs(a).max(axis=1)
blk = 2205
print("50-ms blocks from one bar before the loop start (dB of max |difference|, dB of max |signal|):")
for i in range(0, len(d), blk):
    t = (i - int(bar)) / 44100
    dd = 20 * np.log10(d[i:i + blk].max() + 1e-12)
    ll = 20 * np.log10(lvl[i:i + blk].max() + 1e-12)
    if i % (blk * 4) == 0 or dd > -60:
        print(f"  {t:+7.3f} s  diff {dd:7.1f}  level {ll:6.1f}")
# spectrum of the difference
seg = (a - b)[int(bar):int(bar) + 32768, 0]
S = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
f = np.fft.rfftfreq(len(seg), 1 / 44100)
top = np.argsort(S)[-8:][::-1]
print("strongest frequencies of the difference:", [round(float(f[k]), 1) for k in top])
