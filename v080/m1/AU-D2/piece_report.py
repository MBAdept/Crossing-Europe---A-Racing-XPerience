"""Loudness per phrase, third-octave balance against a reference, stereo correlation and a spectrogram of a piece.
usage: piece_report.py ROOT file.ogg bpm intro_bars phrase_ids(comma) ref.ogg out.png"""
import os
import sys

ROOT = sys.argv[1]
sys.path.insert(0, os.path.join(ROOT, "tools", "audio", "qc"))
sys.path.insert(0, os.path.join(ROOT, "tools", "audio"))
import numpy as np  # noqa: E402
import qc_lib  # noqa: E402
import music_synth as ms  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

path, bpm, intro, phrases, ref, png = sys.argv[2], float(sys.argv[3]), int(sys.argv[4]), sys.argv[5].split(","), \
    sys.argv[6], sys.argv[7]
SR = 44100
bar = 240.0 / bpm
x, _ = qc_lib.read_audio(path)
r, _ = qc_lib.read_audio(ref)


def lufs(seg):
    return ms.integrated_lufs(seg)


print(f"{os.path.basename(path)}: {len(x)/SR:.1f} s, integrated {lufs(x):.2f} LUFS, TP {qc_lib.true_peak_db(x):.2f}")
# per phrase
t0 = intro * bar
rows = []
for i, pid in enumerate(phrases):
    a = int((t0 + i * 8 * bar) * SR)
    b = int((t0 + (i + 1) * 8 * bar) * SR)
    if b > len(x):
        break
    seg = x[a:b]
    rows.append(f"{pid}:{lufs(seg):.1f}")
print("  intro (count-in + first phrase): %.1f LUFS" % lufs(x[:int(t0 * SR)]))
print("  phrases: " + "  ".join(rows))
# third octaves, normalised to equal loudness
def thirds(y):
    mono = y.mean(axis=1)
    n = 1 << 16
    spec = np.zeros(n // 2 + 1)
    cnt = 0
    for s in range(0, len(mono) - n, n // 2):
        spec += np.abs(np.fft.rfft(mono[s:s + n] * np.hanning(n))) ** 2
        cnt += 1
    spec /= max(cnt, 1)
    f = np.fft.rfftfreq(n, 1 / SR)
    centres = 1000 * 2.0 ** (np.arange(-17, 14) / 3)
    out = []
    for c in centres:
        sel = (f >= c / 2 ** (1 / 6)) & (f < c * 2 ** (1 / 6))
        out.append(10 * np.log10(spec[sel].sum() + 1e-20))
    return centres, np.array(out)
c, tx = thirds(x)
_, tr = thirds(r)
d = (tx - tx.mean()) - (tr - tr.mean())
print("  third octaves against the reference (dB, equal mean): " + " ".join(
    f"{int(cc) if cc < 1000 else str(round(cc/1000,1))+'k'}:{dd:+.1f}" for cc, dd in zip(c, d) if cc in c[::3]))
# stereo
corr = np.corrcoef(x[:, 0], x[:, 1])[0, 1]
side = 10 * np.log10(np.mean((x[:, 0] - x[:, 1]) ** 2) / np.mean((x[:, 0] + x[:, 1]) ** 2))
print(f"  L/R correlation {corr:.3f}, side/mid {side:.1f} dB; crest {qc_lib.true_peak_db(x) - 10*np.log10(np.mean(x**2)):.1f} dB")
# spectrogram with phrase lines
mono = x.mean(axis=1)
n, hop = 4096, 2048
frames = np.array([mono[i:i + n] * np.hanning(n) for i in range(0, len(mono) - n, hop)])
S = 20 * np.log10(np.abs(np.fft.rfft(frames, axis=1)).T + 1e-9)
f = np.fft.rfftfreq(n, 1 / SR)
rows_n = 260
fl = np.geomspace(30, 16000, rows_n)
img = S[np.clip(np.searchsorted(f, fl), 0, len(f) - 1)][::-1]
hi = np.percentile(img, 99.5)
img = np.clip((img - (hi - 75)) / 75.0, 0, 1)
rgb = np.stack([img ** 0.6 * 255, img ** 1.4 * 225, (1 - img) * 70 + img * 30], axis=2).astype(np.uint8)
im = Image.fromarray(rgb).resize((1400, rows_n * 2))
dr = ImageDraw.Draw(im)
total = len(mono) / SR
for i in range(len(phrases) + 1):
    tt = t0 + i * 8 * bar
    if tt < total:
        xx = int(tt / total * 1400)
        dr.line([(xx, 0), (xx, rows_n * 2)], fill=(255, 255, 255), width=1)
        if i < len(phrases):
            dr.text((xx + 3, 3), phrases[i], fill=(255, 255, 255))
im.save(png)
