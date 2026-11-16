"""Long-term spectrum of every piece in third-octave groups against "Linke Spur" (the style the user confirmed).
usage: band_compare.py ROOT"""
import os
import sys

ROOT = sys.argv[1]
sys.path.insert(0, os.path.join(ROOT, "tools", "audio", "qc"))
import numpy as np  # noqa: E402
import qc_lib  # noqa: E402

SR = 44100
MUS = os.path.join(ROOT, "assets", "audio", "modern", "music")
GROUPS = [("Sub 25–50 Hz", 25, 50), ("Bass 50–100 Hz", 50, 100), ("Grundton 100–250 Hz", 100, 250),
          ("Tiefe Mitten 250–800 Hz", 250, 800), ("Mitten 0,8–2,5 kHz", 800, 2500),
          ("Präsenz 2,5–6 kHz", 2500, 6000), ("Höhen 6–12 kHz", 6000, 12000), ("Luft 12–18 kHz", 12000, 18000)]


def spectrum(name):
    x, sr = qc_lib.read_audio(os.path.join(MUS, name))
    assert sr == SR
    mono = x.mean(axis=1)
    n = 16384
    win = np.hanning(n)
    acc = np.zeros(n // 2 + 1)
    cnt = 0
    for i in range(0, len(mono) - n, n // 2):
        acc += np.abs(np.fft.rfft(mono[i:i + n] * win)) ** 2
        cnt += 1
    return acc / max(cnt, 1)


f = np.fft.rfftfreq(16384, 1.0 / SR)
ref = None
res = {}
for sid in ("linke_spur", "nachtfahrt", "rueckenwind", "zwischenspiel", "titel_remaster"):
    p = spectrum(sid + ".ogg")
    tot = p[(f >= 20) & (f <= 18000)].sum()
    res[sid] = [10 * np.log10(p[(f >= lo) & (f < hi)].sum() / tot) for _n, lo, hi in GROUPS]
print("| Band | Linke Spur (Anteil) | Nachtfahrt | Rückenwind | Zwischenspiel | Titel-Remaster |")
print("|---|---|---|---|---|---|")
for i, (name, _lo, _hi) in enumerate(GROUPS):
    base = res["linke_spur"][i]
    row = [f"{base:.1f} dB".replace(".", ",").replace("-", "−")]
    for sid in ("nachtfahrt", "rueckenwind", "zwischenspiel", "titel_remaster"):
        d = res[sid][i] - base
        row.append(f"{d:+.1f} dB".replace(".", ",").replace("-", "−"))
    print(f"| {name} | " + " | ".join(row) + " |")
