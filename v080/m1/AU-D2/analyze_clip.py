"""Measure short music clips: loudness, peak, attack at frame 0, best triad per bar, spectrogram PNG.
usage: analyze_clip.py ROOT BPM out_png_dir file.ogg [file.ogg ...]"""
import os
import sys

ROOT = sys.argv[1]
BPM = float(sys.argv[2])
PNG = sys.argv[3]
sys.path.insert(0, os.path.join(ROOT, "tools", "audio", "music"))
sys.path.insert(0, os.path.join(ROOT, "tools", "audio", "qc"))
import numpy as np  # noqa: E402
import qc_lib  # noqa: E402
import music_lib as mlib  # noqa: E402
from PIL import Image  # noqa: E402

SR = 44100
bar = 4 * 60.0 / BPM
os.makedirs(PNG, exist_ok=True)


def spectrogram(x, path, title_bars):
    mono = x.mean(axis=1)
    n, hop = 2048, 512
    win = np.hanning(n)
    frames = [mono[i:i + n] * win for i in range(0, len(mono) - n, hop)]
    S = np.abs(np.fft.rfft(np.array(frames), axis=1)).T
    S = 20 * np.log10(S + 1e-9)
    f = np.fft.rfftfreq(n, 1 / SR)
    # log-frequency rows 30 Hz .. 16 kHz
    rows = 300
    fl = np.geomspace(30, 16000, rows)
    idx = np.searchsorted(f, fl)
    img = S[np.clip(idx, 0, len(f) - 1)][::-1]
    lo, hi = np.percentile(img, 5), img.max()
    img = np.clip((img - (hi - 80)) / 80.0, 0, 1)
    rgb = np.stack([img ** 0.6 * 255, img ** 1.5 * 230, (1 - img) * 60 + img * 40], axis=2).astype(np.uint8)
    im = Image.fromarray(rgb)
    # bar lines
    a = np.array(im)
    for k in range(1, int(len(mono) / SR / bar) + 1):
        c = int(k * bar * SR / hop)
        if c < a.shape[1]:
            a[:, c] = [255, 255, 255]
    Image.fromarray(a).resize((max(400, a.shape[1]), rows * 2)).save(path)


for p in sys.argv[4:]:
    x, sr = qc_lib.read_audio(p)
    m = qc_lib.measure(x, sr)
    first = 20 * np.log10(np.sqrt(np.mean(x[:2205] ** 2)) + 1e-12)
    peak_t = np.argmax(np.abs(x).max(axis=1)) / sr
    nb = int(len(x) / sr / bar)
    starts = [k * bar for k in range(nb)]
    ch = mlib.chroma_bars(x, starts, bar)
    tri = [mlib.best_triad(c) if c.sum() > 0 else "-" for c in ch]
    # loudness per bar (short)
    lv = []
    for k in range(nb):
        seg = x[int(k * bar * sr):int((k + 1) * bar * sr)]
        lv.append(round(20 * np.log10(np.sqrt(np.mean(seg ** 2)) + 1e-12), 1))
    name = os.path.basename(p)
    print(f"{name}: {len(x)/sr:.2f} s, {m['lufs']} LUFS, TP {m['true_peak_db']} dBTP, first 50 ms {first:.1f} dBFS RMS, "
          f"peak at {peak_t:.2f} s")
    print("   bars:", " ".join(f"{t}({l})" for t, l in zip(tri, lv)))
    spectrogram(x, os.path.join(PNG, name.replace(".ogg", ".png")), nb)
